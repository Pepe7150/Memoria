# Estimación de Torque y Emulación de Carga Aerodinámica vía Fusión Sensorial (Filtro de Kalman)
### Documentación técnica — Banco de Ensayo de Actuadores de Superficie de Control

**Contexto:** este documento describe la simulación del banco de ensayo desarrollada para la Memoria de Título. El banco emula la carga aerodinámica (momento de bisagra) sobre una aleta mientras un actuador bajo ensayo la mueve, y estima el torque que ejerce cada motor, el torque transmitido por el eje y el estado angular de la aleta combinando varios sensores mediante un Filtro de Kalman.

**Estado del documento (v2, 25-oct-2026):** sincronizado con el código `main.m` + `paso1`…`paso6` + `resultados.csv` de la versión v2. La versión anterior (v1) usaba una rampa de torque de 4 Nm en lazo abierto y controlaba el motor B con la estimación del Kalman; eso cambió (§1). **Los resultados numéricos de v2 están pendientes** (§10.1): no existe aún una salida de corrida de esta versión. Las cifras de v1 se conservan solo como referencia histórica (§10.2).

Estructura: referencia del sistema (§1–§11), limitaciones y decisiones abiertas (§12–§13), bitácora (§14) y guía del código (§15).

---

## 1. Resumen: qué se simula

Tres masas rotatorias unidas por un eje de acero elástico:

```
 Motor A ──(k1,c1)── Aleta C ──(k2,c2)── Motor B
  (J_A)               (J_C)                (J_B)
 EMULA LA CARGA      sin actuador         ACTUADOR BAJO ENSAYO
 aerodinámica        ni sensor de         (servo MG996R):
 H(δ) de la LUT      posición propio      sigue la consigna δ_cmd(t)
```

**Idea del ensayo:** el actuador bajo ensayo (B) mueve la aleta C hacia el ángulo comandado. El motor A aplica, a través del eje, el momento de bisagra que el aire ejercería sobre la aleta a ese ángulo. Como la aleta no tiene sensor de posición propio, A necesita saber `θ_C`: usa la **estimación del Kalman** (`θ̂_C`).

**Qué cambió respecto de v1:**

| Aspecto | v1 | v2 |
|---|---|---|
| Carga de A | Rampa 0→4 Nm en lazo abierto | `T_A = H_LUT(θ̂_C)`, momento de bisagra del CFD evaluado en línea con el ángulo estimado |
| Motor B | PID sobre la estimación del Kalman, objetivo θ_C = 0 | Servo (MG996R) modelado como PID sobre **su propio potenciómetro**, siguiendo `δ_cmd(t)`; **no usa el Kalman** |
| Escala de torque | 4 Nm (A), 3 Nm (B), fail-safe 8 Nm | Aleta de 20×15 cm (geometría del CFD): pico de la LUT ≈ 0.67 Nm; nominales 0.8 Nm; fail-safe 1.2 Nm |
| Tasa del Kalman | 5 kHz | 1 kHz (tasa de adquisición); la planta sigue a 5 kHz |
| Anchos de banda | Hall y corriente 500 Hz | Hall y corriente 200 Hz |
| Fail-safes | Ángulo, velocidad, torque | Se agrega límite de ángulo de aleta (±20°) y, con `failsafe_extra = true`, de torque en el eje (`T_AC`, `T_CB`) y de velocidad de la aleta (`ω_C`) |
| Reproducibilidad | Sin semilla | `rng(semilla)` fija |
| Estudio nuevo | — | `paso6`: desajuste modelo-planta (§11) |

**Escenarios de ensayo** (se elige con `escenario` en `main.m`; 20 s, planta a 5 kHz → 100 000 pasos):

| # | Condición del aire | Consigna `δ_cmd(t)` |
|---|---|---|
| 1 | M = 0.3, AoA = 0° | Rampa lenta 0 → +15° → −15° → 0° (cruza el cero de la carga). Velocidad de rampa ≈ 3.75°/s |
| 2 | M = 0.3, AoA = 10° | Mantener +15° (carga máxima) con escalones: 15° → 10° (8 s) → 15° (12 s) → 5° (16 s) |
| 3 | M = 0.3, AoA = 0° | Barrido senoidal ±5°, 1 → 10 Hz (dinámico), con entrada suave de 1 s |

`main.m` ejecuta con `escenario = 2`. Si la variable no existe, `paso2` usa 1.

**Flujo de señal:**

```
 δ_cmd(t) ─► servo B (PID, potenciómetro) ─► T_B ─┐
                                                  ▼
 θ̂_C ─► LUT H(δ) ─► driver A ─► T_A ─────► PLANTA REAL (6 estados, 5 kHz)
  ▲                                                │
  │                                  sensores (ruido + sesgo + pasa-bajos)
  │                                                │ muestreo a 1 kHz
  └───────────── KALMAN (14 estados) ◄─────────────┘
```

**Verdad vs. estimado:** `x6`, `T_A_true`, `T_B_true` y los sesgos `bias_*_true` son la verdad de la simulación. `x_est` (14 estados) es la estimación. Hoy la estimación cierra un solo lazo: la carga emulada por A. El servo B usa su potenciómetro y los fail-safes (§8.2) leen la verdad.

**Qué se evalúa:** (a) calidad de la estimación (RMSE vs. verdad), (b) seguimiento del ángulo de aleta respecto de la consigna, (c) fidelidad de la carga emulada (`T_A` real vs. `H_LUT(θ_C real)`), (d) sensibilidad a parámetros mal conocidos (§11).

---

## 2. Convenciones y nomenclatura

| Símbolo | Significado | Unidad |
|---|---|---|
| `θ_A, θ_C, θ_B` | Ángulo de Motor A, aleta C y Motor B | rad |
| `ω_A, ω_C, ω_B` | Velocidades angulares correspondientes | rad/s |
| `δ`, `δ_cmd` | Ángulo de la aleta (= `θ_C`) y consigna del ensayo | rad o deg (se indica) |
| `H(δ)` | Momento de bisagra aerodinámico, con signo, en el sentido de `+δ` | Nm |
| `T_A, T_B` | Torque que ejerce cada motor (definido positivo; ver signo abajo) | Nm |
| `T_AC, T_CB` | Torque transmitido por el tramo A–C y por el tramo C–B | Nm |
| `bias_IA, bias_IB` | Sesgo aditivo del sensor de corriente | **A** |
| `bias_IMU`, `bias_SG` | Sesgo del giroscopio; sesgo del strain gauge | rad/s; Nm |
| `x_est` | Vector de estado estimado (14×1) | — |
| `fs_sim`, `fs_kf` | Tasa de la planta (5 kHz) y de sensores/Kalman (1 kHz) | Hz |

**Convención de signo:** `T_A` empuja a A en sentido positivo. `T_B` entra a la ecuación de B como `-T_B`, de modo que `T_B_cmd = −(PID)` empuja a B hacia la consigna. **Signo de la carga:** `H(δ)` es negativo para `δ` positivo (momento restaurador): para `δ = +15°`, `T_A < 0` se opone al movimiento que impone B.

---

## 3. Modelo mecánico

### 3.1 Tres discos, dos tramos elásticos

```
J_A·θ_A'' + b_A·θ_A' + c1·(θ_A'-θ_C') + k1·(θ_A-θ_C) = T_A
J_C·θ_C'' + c1·(θ_C'-θ_A') + k1·(θ_C-θ_A) + c2·(θ_C'-θ_B') + k2·(θ_C-θ_B) = 0
J_B·θ_B'' + b_B·θ_B' + c2·(θ_B'-θ_C') + k2·(θ_B-θ_C) = -T_B
```

`b_A`, `b_B` son fricción viscosa de rodamiento. La aleta C no tiene fricción propia ni carga externa en el modelo mecánico: la carga aerodinámica entra por `T_A` (no como torque directo sobre C).

**Parámetros (`paso1`):**

| Parámetro | Valor | Nota |
|---|---|---|
| Eje: diámetro `d`, longitud `L` | 5 mm, 150 mm | Acero, `G = 79.3 GPa` |
| `J_polar = π·d⁴/32` | 6.14·10⁻¹¹ m⁴ | |
| `k_full = G·J_polar/L` | ≈ 32.4 Nm/rad | Eje completo |
| `k1 = k2 = 2·k_full` | 64.88 Nm/rad | Cada tramo mide L/2 |
| `c_full` → `c1 = c2` | 0.05 → 0.10 Nms/rad | Mismo escalado que la rigidez |
| `J_A, J_B, J_C` | 4·10⁻⁴, 3·10⁻⁴, 5·10⁻⁵ kg·m² | |
| `b_A = b_B` | 0.02 Nms/rad | |
| `Kt_A, Kt_B` | 0.06, 0.05 Nm/A | |
| `T_nom_A = T_nom_B` | 0.8 Nm | Solo para el modelo térmico (hoy sin efecto, §6.3) |

### 3.2 Frecuencias naturales

Con `eig(K, M)` sobre el modelo sin amortiguamiento (`M = diag(J_A, J_C, J_B)`; `K` y `M` son simétricas, pero con 3 GDL no hay fórmula cerrada simple):

| Modo | Frecuencia | Descripción |
|---|---|---|
| Rígido | 0 Hz | Todo el conjunto rota en bloque. No hay resorte a tierra. |
| `fn1` | **69.18 Hz** | Modo dominante: A y B se mueven de forma significativa. |
| `fn2` | **265.58 Hz** | Modo local de C (por su `J_C` pequeño): A y B casi no se mueven. |

### 3.3 Matriz `C_torque`

```
[T_AC; T_CB] = C_torque · [θ_A; ω_A; θ_C; ω_C; θ_B; ω_B]

C_torque = [ k1,  c1, -k1, -c1,   0,   0;
              0,   0,  k2,  c2, -k2, -c2]
```

Se usa en la planta, en el Kalman (estado `strain_filt`) y en la señal del strain gauge. **Supuesto:** `T_AC` incluye el término viscoso `c1·(ω_A-ω_C)`; un strain gauge real mide solo la deformación elástica (`k1·Δθ`). Con `c1` pequeño, la diferencia es mínima.

### 3.4 Planta discreta: nominal y "verdadera"

`Ac6`/`Bc6` se discretizan a `dt_sim = 0.2 ms` con `ss` + `c2d(…,'zoh')`. El código distingue dos versiones:

- **Nominal** (`Ad6`, `Bd6`, `C_torque`): la que supone el Kalman.
- **Verdadera** (`Ad6_true`, `Bd6_true`, `C_torque_true`, `fac_Kt_A`, `fac_Kt_B`): la que integra el bucle. En la corrida normal son idénticas a la nominal. `paso6` las perturba (§11).

---

## 4. Instrumentación y modelo de sensores

### 4.1 Tabla de sensores

| Sensor | Mide | Ubicación | Ruido (σ) | Ancho de banda | Sesgo |
|---|---|---|---|---|---|
| Hall + anillo magnético | `θ_A`, `θ_B` | Motores A y B | 0.002 rad | **200 Hz** | Fijo (0.05 y −0.03 rad), **calibrado y restado** |
| Sensor de corriente + `Kt` | `T = Kt·I` | Cada motor | 0.03 A | **200 Hz** | **Gauss-Markov** (σ_b 0.15 A y 0.12 A) |
| IMU (giroscopio) | `ω_C` | Aleta C | 0.02 rad/s | 150 Hz | **Gauss-Markov** (σ_b 0.25 rad/s) + g-sensitivity |
| Transductor propio (tubo + strain gauges) | `T_AC` | Tramo A–C | 0.005 Nm | 30 Hz | **Gauss-Markov** (σ_b 0.20 Nm) |
| Potenciómetro del servo | `θ_B` | Servo B | 0.0005 rad | — | Sin sesgo. **No entra al Kalman**: lo usa solo el PID del servo |

Los canales del Kalman pasan por un filtro pasa-bajos discreto de primer orden: `y[i] = y[i-1] + α·(raw − y[i-1])`, con `α = dt/(τ+dt)` y `τ = 1/(2π·BW)`. Los anchos de banda de Hall y corriente se bajaron de 500 a 200 Hz porque el Nyquist de `fs_kf = 1 kHz` es 500 Hz.

### 4.2 Cadena de muestreo

Los sensores se simulan y filtran a 5 kHz. El Kalman los **muestrea cada `decim = 5` pasos** (1 kHz, `dt_kf = 1 ms`). Entre actualizaciones, `x_est` se mantiene constante (retención de orden cero), de modo que el control de A usa un `θ̂_C` con hasta 1 ms de antigüedad. El valor `fs_kf = 1 kHz` es provisorio: ajustar a la tasa de adquisición real medida.

### 4.3 Sesgos dinámicos (Gauss-Markov / Ornstein-Uhlenbeck)

```
b[i] = b[i-1]·exp(-dt/τ_b) + σ_b·sqrt(1 - exp(-2·dt/τ_b))·randn
```

| Canal | `τ_b` | `σ_b` | Valor inicial |
|---|---|---|---|
| Corriente A | 12 s | 0.15 A | 0.10 A |
| Corriente B | 12 s | 0.12 A | −0.08 A |
| IMU | 8 s | 0.25 rad/s | 0.20 rad/s |
| Strain gauge | 10 s | 0.20 Nm | 0.15 Nm |

Con `τ_b` de 8–12 s y simulaciones de 20 s, cada sesgo recorre solo ~1.7–2.5 constantes de tiempo.

### 4.4 Hall: calibración estática

El sesgo fijo de los Hall se resta antes de filtrar (`thA_cal = thA_raw − bias_hallA`). Representa una calibración ya conocida, por eso **no hay estado de sesgo de Hall en el Kalman**. Si en el banco real ese sesgo no se conoce o deriva, debe tratarse como los demás.

### 4.5 IMU: excentricidad y g-sensitivity

La IMU está a `r_imu = 5 mm` del eje y filtra una fracción de la aceleración centrípeta a su salida angular:

```
error_gsens = g_sens_imu · (ω_C² · r_imu) / g,   g_sens_imu = 0.05 °/s por g
```

El `0.05 °/s/g` es un valor **típico**, no el de la IMU real (reemplazar con el datasheet). No se modela la aceleración tangencial (`α·r`), y el Kalman no modela esta perturbación.

### 4.6 Transductor de torque propio

Se descartó el FT05 comercial por costo. El transductor propio (tubo en línea con el eje, strain gauges directos, puente de Wheatstone por armar) no tiene especificaciones de fábrica: su ancho de banda lo define la electrónica de acondicionamiento. `noise_strain_std = 0.005 Nm` es un marcador heredado del FT05 y **debe reemplazarse por datos de calibración**.

### 4.7 Decisión de diseño: un solo tramo instrumentado

El transductor está solo en A–C. `θ_C` y `T_CB` se infieren del modelo. Esto es razonable mientras la aleta no reciba otra carga externa que la aplicada por A: un torque no modelado en C es indistinguible de un error de calibración de `k`/`c` con un solo tramo medido. Nota: en v2 la carga aerodinámica la aplica A por el eje, por lo que sí está dentro del modelo.

---

## 5. Escenarios y carga aerodinámica (LUT del CFD)

### 5.1 `resultados.csv`

Malla completa de 315 casos: **7 deflexiones** (δ = −15° a +15°, paso 5°) × **5 Mach** (0.10 a 0.30, paso 0.05) × **9 ángulos de ataque** (−4° a 12°, paso 2°). Columnas: `delta_deg, mach, aoa_deg, Cl, Cd, CmPitch, ChHinge, HingeMoment_Nm`. El código verifica que la malla esté completa y que `M_test` y `aoa_test` caigan dentro de su rango.

### 5.2 Reconstrucción del momento de bisagra

El código **no usa** la columna `HingeMoment_Nm` (calculada para la geometría del CFD). Usa el coeficiente adimensional `ChHinge` y lo redimensiona con la geometría y el aire del banco:

```
H(δ) = Ch(δ; M_test, AoA_test) · q · c² · b
q = ½·ρ·(M·a)²,   ρ = 1.225 kg/m³, a = 340.3 m/s (ISA, nivel del mar)
c = 0.20 m, b = 0.15 m  (aleta de 20×15 cm, la misma del CFD)
```

- Interpolación lineal en (M, AoA) para cada δ de la malla y luego **`pchip` en δ**. Fuera de ±15° el valor se satura (se mantiene el de ±15°).
- Para M = 0.3, `q ≈ 6384 Pa`.
- Se asume que `Ch` normaliza con `c²·b`. Esto es coherente con la columna `HingeMoment_Nm` del CSV, cuyo cociente respecto de `ChHinge·q` es constante (6.0·10⁻³ m³ = 0.20² · 0.15). El banco usa la misma geometría, así que **la carga emulada coincide con `HingeMoment_Nm`**. `paso2` lo verifica al cargar el CSV y emite un `warning` si `c_real²·b_real` difiere de la referencia del CFD (con una aleta de 15×15 cm los momentos serían ≈ 56 % de los del CSV, con pico ≈ 0.38 Nm).
- El barrido CFD se corrió con la viscosidad escalada para una cuerda de 0.20 m (Re = 4.5·10⁵ a 1.4·10⁶), igual que la cuerda del banco, así que no hay desajuste de Reynolds.

### 5.3 Carga resultante (M = 0.3, valores en los nodos de la malla)

| δ (deg) | H, AoA = 0° (Nm) | H, AoA = 10° (Nm) |
|---|---|---|
| −15 | +0.575 | +0.408 |
| −10 | +0.411 | +0.204 |
| −5 | +0.213 | +0.002 |
| 0 | +0.004 | −0.175 |
| +5 | −0.214 | −0.328 |
| +10 | −0.410 | −0.480 |
| +15 | −0.564 | **−0.670** |

El pico de la LUT en los escenarios es ≈ 0.67 Nm (AoA = 10°, δ = +15°). Alrededor de δ = 0 y AoA = 0° la pendiente es ≈ -2.4 Nm/rad: un resorte aerodinámico restaurador, débil frente a la rigidez del eje (64.9 Nm/rad por tramo). En AoA = 10° la carga no se anula en δ = 0.

### 5.4 Chequeo de la consigna

`paso2` calcula `omega_cmd = diff(delta_cmd)/dt` y emite un `warning` si supera `w_servo_max = 6.16 rad/s` (0.17 s/60° a 4.8 V, **verificar con datasheet**). Es solo un aviso: el servo del modelo **no limita** su velocidad. Las consignas actuales no lo disparan: el escenario 3 llega a ≈ 5.5 rad/s (89 % del límite) al final del barrido.

---

## 6. Actuación

### 6.1 Motor A: emulador de carga

```
T_A_cmd = H_LUT(θ̂_C [deg])        (con la última estimación del Kalman)
T_A     = filtro de 200 Hz de (fac_Kt_A · T_A_cmd)
I_A     = T_A / Kt_A_actual
```

La corriente se comanda con `Kt` nominal; si el `Kt` real difiere (`fac_Kt_A ≠ 1`), el torque real sale escalado y la corriente medida no lo refleja. Eso es lo que `paso6` explota (§11).

### 6.2 Motor B: actuador bajo ensayo (MG996R)

El lazo interno del servo se modela como un PID de torque sobre su **propio potenciómetro**:

```
pot_raw    = θ_B + ruido (σ = 0.5 mrad)                  (medición del paso anterior)
ω_srv      = derivada de pot_raw filtrada (τ_d = 10 ms)
e          = δ_cmd − pot_raw
T_B_cmd    = −( Kp·e + Ki·∫e + Kd·(ω_cmd − ω_srv) ),   Kp=5, Ki=20, Kd=0.05   (provisorios)
T_B_cmd    ← saturado a ±T_B_max = ±1.0 Nm
I_B_ref    = T_B_cmd / Kt_B  →  filtro de 200 Hz  →  T_B = Kt_B_actual · I_B
```

La integral está acotada a ±10 (anti-windup). Las ganancias, `T_B_max` (~1 Nm de bloqueo) y `w_servo_max` están marcados en el código como **provisorios / por verificar** con el datasheet del servo. El Kalman estima `T_B`, pero **no interviene** en este lazo. Con la aleta de 20×15 cm el pico de la carga (0.67 Nm) es ≈ 67 % de `T_B_max`: si el torque de bloqueo real del servo es menor, el margen se reduce.

### 6.3 Modelo térmico

Un proxy de calentamiento (`I²/I_rated²`, constante de 10 s, acelerada, no física) podría degradar `Kt_actual = Kt·fac·(1 − kt_drift·heat)`. **La deriva está apagada** (`kt_drift_A = kt_drift_B = 0`): el modelo térmico se calcula pero no afecta la simulación. `I_rated = T_nom/Kt`.

### 6.4 Lo que no está modelado

No hay dinámica interna del servo (engranajes, backlash, zona muerta), ni saturación de corriente de A. La saturación de B existe (±`T_B_max`), y actúa antes que el fail-safe de torque (§8.2).

---

## 7. Filtro de Kalman

### 7.1 Estados (14)

```
x = [θ_A, ω_A, θ_C, ω_C, θ_B, ω_B,   T_A, T_B,   gyro_filt, strain_filt,   bIA, bIB, bIMU, bSG]
     |--- mecánico (1-6) ---------|  |7-8|       |------ 9-10 ---------|   |------ 11-14 -------|
```

| Bloque | Estados | Modelo |
|---|---|---|
| Mecánico | 1–6 | Dinámica exacta de 3 discos, con `T_A`, `T_B` como entradas (`Ac14(1:6,7:8) = Bc6`) |
| Torques | 7–8 | Paseo aleatorio: se desconocen a priori. Con la carga de la LUT, `T_A` **no** es constante, por lo que el paseo aleatorio es una aproximación más fuerte que en v1 |
| Retardo de sensor | 9–10 | `gyro_filt' = (ω_C − gyro_filt)/τ_imu`; `strain_filt' = (T_AC − strain_filt)/τ_sg` |
| Sesgos | 11–14 | Gauss-Markov: `b' = −b/τ_b` |

### 7.2 Matriz de medición `H`

| Medición | Combinación de estados |
|---|---|
| Hall A | `θ_A` |
| Hall B | `θ_B` |
| Corriente A (`Kt_A·I_A`) | `T_A + Kt_A·bIA` |
| Corriente B (`Kt_B·I_B`) | `T_B + Kt_B·bIB` |
| IMU | `gyro_filt + bIMU` |
| Transductor | `strain_filt + bSG` |

Los sesgos de corriente están en **amperes**; `H` los multiplica por `Kt`.

### 7.3 Discretización y sintonía

El filtro corre a `dt_kf = 1 ms`: `Adk = expm(Ac14·dt_kf)`. Los valores de `Q` calibrados originalmente a 0.2 ms se escalan por `qs = dt_kf/dt_sim = 5` para conservar la misma densidad espectral por segundo.

`Q` (diagonal, en el orden de los 14 estados):

| Estados | Expresión | Valor |
|---|---|---|
| `θ_A, θ_C, θ_B` | `1e-10·qs` | 5·10⁻¹⁰ |
| `ω_A, ω_C, ω_B` | `5e-5·qs` | 2.5·10⁻⁴ |
| `T_A, T_B` | `0.01·dt_kf` | 1·10⁻⁵ |
| `gyro_filt, strain_filt` | `1e-8·qs` | 5·10⁻⁸ |
| Sesgos | `q_b·dt_kf`, `q_b = 2σ_b²/τ_b` | IA 3.75·10⁻⁶, IB 2.4·10⁻⁶, IMU 1.56·10⁻⁵, SG 8·10⁻⁶ |

`R` (diagonal) es la varianza del ruido blanco tras el filtro de primer orden, calculada con el paso de la planta: `var = σ²·α/(2−α)`; `R = diag(var_hall, var_hall, Kt_A²·var_IA, Kt_B²·var_IA, var_imu, var_sg)`. El canal B reutiliza `var_IA`.

**Supuesto:** tras el filtro, el ruido está correlacionado en el tiempo (sobre todo el del transductor, cuyo `τ` ≈ 5 ms supera el periodo de muestreo de 1 ms), pero el Kalman lo trata como blanco.

### 7.4 Ganancia estacionaria y actualización

`K_kalman_steady` se obtiene una sola vez iterando 500 veces la ecuación de Riccati con `Adk`, `Q`, `R` (a 1 kHz) y se usa fija. Cada 5 pasos de la planta: `x_pred = Adk·x_est`, `x_est = x_pred + K·(z − H·x_pred)`. Entre actualizaciones se mantiene la última estimación.

### 7.5 Condiciones iniciales

`x_est` arranca en cero para los 14 estados, mientras los sesgos verdaderos arrancan en los valores de §4.3.

### 7.6 Observabilidad

`rank(obsv(Adk,H))` y `cond(...)` se calculan al cargar `paso3`. En v1 (a 0.2 ms) dieron rango 14/14 y condición 9.0·10⁵. **Con `dt_kf = 1 ms` hay que recalcularlos** (pendiente de una corrida v2). El chequeo es indicativo: `Adk` queda cerca de la identidad y rango/condición son numéricamente delicados. Un rango completo tampoco garantiza que cada estado se estime bien en la práctica (§10.2, sesgo de corriente B en v1).

---

## 8. Control y fail-safes

### 8.1 Lazos de control

| Lazo | Mide | Actúa sobre | Usa el Kalman |
|---|---|---|---|
| Servo B (PID) | Potenciómetro (`θ_B` + ruido) | `T_B` | No |
| Emulación de carga (A) | `θ̂_C` | `T_A` vía LUT | **Sí** |

El único acople entre estimador y planta es la carga de A. Un error en `θ̂_C` produce un error de carga, que a su vez excita la planta; el lazo A–Kalman funciona como un resorte aerodinámico débil (pendiente ≈ −1.4 Nm/rad) con un retardo de hasta 1 ms. **No hay un análisis de estabilidad de este lazo** ni de las ganancias del servo (§13). El análisis de autovalores de §14.2 corresponde a la arquitectura v1.

### 8.2 Fail-safes

Capa de protección separada. Cada paso revisa el estado del paso anterior:

| Límite | Valor | Variables revisadas |
|---|---|---|
| Ángulo de rotores | ±135° | `θ_A`, `θ_B` |
| Ángulo de aleta | **±20°** (`max_fin_deg`, a diseñar con topes mecánicos) | `θ_C` |
| Velocidad angular | ±1000 RPM | `ω_A`, `ω_B` |
| Torque de los motores | **±1.2 Nm** (`max_torque_Nm`; mayor que `T_B_max` = 1.0 Nm; ≈ 1.8× el pico de la LUT) | `T_A_true`, `T_B_true` |
| Torque en el eje (`failsafe_extra`) | **±1.2 Nm** (`max_shaft_torque_Nm`) | `T_AC`, `T_CB` |
| Velocidad de la aleta (`failsafe_extra`) | **±18.5 rad/s** (`max_omega_fin_rads` = 3 × `w_servo_max`) | `ω_C` |

Al dispararse: `system_fault = true`, se registran `fault_time` y `fault_reason`; el comando y el torque de A pasan a 0 de inmediato; la referencia de corriente de B pasa a 0 (`I_B` decae por el filtro del driver); **la planta sigue evolucionando** (los rotores giran por inercia); la falla es **permanente**; los gráficos marcan el instante.

**Limitaciones:** (a) leen el estado verdadero, no la estimación; (b) los límites de `ω_C` y de torque en el eje son heurísticos (el de `ω_C` es 3× la velocidad máxima del servo; el de `T_AC`/`T_CB` coincide con el de los motores); (c) `failsafe_extra = false` restituye el comportamiento anterior (sin vigilar `T_AC`, `T_CB`, `ω_C`). La inconsistencia anterior entre `max_torque_Nm` (0.8 Nm) y `T_B_max` (1.0 Nm) quedó resuelta: el fail-safe (1.2 Nm) es mayor que la saturación del servo, de modo que esta actúa primero.

---

## 9. Regla heurística de ancho de banda

Se compara cada ancho de banda con la frecuencia relevante, exigiendo un margen ≥ 5×:

| Categoría | Referencia | Valor | Resultado esperado |
|---|---|---|---|
| Driver (200 Hz) vs lazo de B `sqrt(Kp/J_B)/(2π)` | Con `Kp = 5` | 20.55 Hz → umbral 103 Hz | OK |
| Filtro de corriente (200 Hz) vs `fn1` | 5·`fn1` = 346 Hz | 200 Hz < 346 Hz | **ALERTA** |
| Hall (200 Hz) vs `fn1` | 5·`fn1` = 346 Hz | 200 Hz < 346 Hz | No se imprime, pero tampoco cumple |
| IMU y transductor (en C) | RMSE de seguimiento | — | Su retardo está modelado en el Kalman (§7.1) |

Las filas "esperado" se deducen de la configuración; confirmar con la salida de `paso5`. En v1 el filtro de corriente (500 Hz) cumplía; **al bajar a 200 Hz la regla de 5×`fn1` deja de cumplirse**. La fórmula del lazo de B es una heurística gruesa: ignora el acople con A y C y el término derivativo. Con 20.5 Hz queda solo ~3.4× por debajo de `fn1`.

---

## 10. Resultados

### 10.1 Corridas v2.1 (aleta de 20×15 cm)

Resultados de `paso5` por escenario (semilla 1, planta a 5 kHz, Kalman a 1 kHz). **Se obtuvieron con GNU Octave 8.4**: en MATLAB las cifras cambian ligeramente porque el generador de números aleatorios es distinto; conviene repetir las corridas en MATLAB antes de citarlas como definitivas.

| Métrica | Esc. 1 (rampa ±15°, AoA 0°) | Esc. 2 (carga máx., AoA 10°) | Esc. 3 (barrido ±5°, 1→10 Hz) |
|---|---|---|---|
| Rango / condición de observabilidad | 14/14 · 1.70·10⁵ | 14/14 · 1.70·10⁵ | 14/14 · 1.70·10⁵ |
| RMSE sesgos IA / IB (A), IMU (rad/s), SG (Nm) | 0.029 / 0.034 / 0.015 / 0.006 | 0.029 / 0.034 / 0.016 / 0.006 | 0.032 / 0.034 / 0.063 / 0.007 |
| RMSE `θ_A` / `θ_B` (rad), crudo → Kalman | 6.7·10⁻⁴ → 2.2·10⁻⁴ / 6.7·10⁻⁴ → 2.2·10⁻⁴ | 6.7·10⁻⁴ → 2.5·10⁻⁴ / 6.8·10⁻⁴ → 2.5·10⁻⁴ | 1.5·10⁻³ → 2.2·10⁻³ / 1.6·10⁻³ → 2.3·10⁻³ |
| RMSE `θ_C` Kalman (rad) | 2.2·10⁻⁴ | 2.5·10⁻⁴ | 2.25·10⁻³ |
| RMSE `ω_C` (rad/s), crudo → Kalman | 0.343 → 0.016 | 0.343 → 0.017 | 0.354 → 0.095 |
| RMSE `T_A` / `T_B` (mNm), crudo → Kalman | 3.6 → 1.9 / 2.3 → 2.3 | 3.7 → 2.1 / 2.3 → 2.4 | 5.0 → 5.7 / 3.5 → 4.6 |
| RMSE `T_AC` (mNm), crudo → Kalman; `T_CB` Kalman | 105.7 → 1.8; 1.8 | 105.4 → 2.0; 2.0 | 106.6 → 5.8; 5.4 |
| Seguimiento `θ_C` real vs consigna (RMSE; error máx., deg) | 0.45; 0.83 | 0.62; 1.88 | 1.09; 1.75 |
| Carga emulada: RMSE `T_A` vs `H_LUT(θ_C real)` (mNm) | 0.5 | 1.1 | 9.6 |
| `max |T_B|`, `max |T_AC|` (Nm) | 0.556, 0.552 | 0.654, 0.649 | 0.161, 0.146 |
| Fail-safe | Sin disparo | Sin disparo | Sin disparo |

**Lectura:**

- En los escenarios 1 y 2 (cuasi-estáticos) el Kalman mejora claramente la posición y velocidad de la aleta y el torque del eje: `T_AC` baja de ≈ 105 mNm (strain gauge crudo, dominado por su sesgo) a ≈ 2 mNm. El torque de B no mejora respecto de la corriente cruda.
- En el escenario 3 (dinámico, hasta 10 Hz) **el Kalman empeora** `θ_A`, `θ_B`, `T_A` y `T_B` respecto de la medición directa (−47 % a −50 % en posición; −15 % y −32 % en torque), aunque sigue mejorando `T_AC` (mejora de 94.6 %) y `ω_C` (73 %). Causa no verificada: el modelo de paseo aleatorio para `T_A` y `T_B` (§7.3) no sigue variaciones rápidas, por lo que la sintonía de `Q` es candidata a revisión para uso dinámico.
- En el escenario 2, `max |T_B|` = 0.654 Nm, ≈ 65 % de la saturación del servo (1.0 Nm, provisoria).
- La alerta de ancho de banda del filtro de corriente (200 Hz < 5×`fn1`) persiste (§9).

Para la tabla de desajuste de parámetros ver §11.


### 10.2 Referencia histórica: v1 (rampa de 4 Nm, sin LUT, Kalman a 5 kHz)

**No son comparables con v2:** cambiaron la escala de torque, el control de B, la tasa del Kalman y los anchos de banda. Se conservan como antecedente.

| Variable | RMSE crudo | RMSE Kalman | Mejora |
|---|---|---|---|
| `θ_A`, `θ_B` | 0.00098, 0.00097 rad | 0.00023, 0.00023 rad | 76.6 %, 76.9 % |
| `θ_C` | N/A | 0.00022 rad | — |
| `ω_A`, `ω_B` | N/A | 0.0165, 0.0182 rad/s | — |
| `ω_C` | 0.3127 rad/s | 0.0177 rad/s | 94.4 % |
| `T_A` | 0.0119 Nm | 0.0033 Nm | 72.7 % |
| `T_B` | 0.0034 Nm | 0.0034 Nm | 0.01 % |
| `T_AC` | 0.2365 Nm | 0.0032 Nm | 98.7 % |
| `T_CB` | N/A | 0.0032 Nm | — |
| Sesgos (RMSE) | IA 0.0522 A, IB 0.0609 A, IMU 0.0172 rad/s, SG 0.0060 Nm | | |
| Observabilidad | rango 14/14, condición 9.0·10⁵ | | |

**Lectura (v1):** el mayor aporte fue en `T_AC` y `ω_C`, cuyos sensores en C tenían sesgo grande y retardo apreciable. `T_B` no mejoró respecto de "solo corriente": su error (0.0034 Nm) coincide con `Kt_B·RMSE(bIB)`. Hipótesis (no verificada): `T_B` y `bIB` casi no se separan en la práctica, por lo que conviene revisar la covarianza estacionaria `P_temp` de los estados 8 y 12. Que se repita en v2 está por verse.

---

## 11. Estudio de desajuste de parámetros (`paso6`)

**Pregunta:** ¿cuánto se degradan la estimación y la carga emulada si `k`, `J`, `Kt` o `c` reales difieren de los que supone el filtro? Sirve para decidir qué parámetros medir primero cuando llegue el hardware.

**Método:** el Kalman conserva los parámetros nominales (`paso1`); solo se perturba la planta verdadera (`Ad6_true`, `Bd6_true`, `C_torque_true`, `fac_Kt_A`, `fac_Kt_B`, discretizada con ZOH exacto vía `expm`). El factor de `Kt` hace que el torque real difiera del que infiere la corriente medida.

| Parámetro | Factor |
|---|---|
| `k` (ambos tramos), `J_A`, `J_B`, `J_C`, `Kt_A`, `Kt_B`, `c` (ambos tramos) | 7 factores multiplicativos |

**Configuración** (al inicio de `paso6`): `d_pct = 0.30` (±30 %), `escenario = 3`, y dos modos:

- `d_modo = 1`, **uno a uno**: cada parámetro a (1 ± `d_pct`) con el resto nominal; `d_nsem = 3` semillas por caso; `d_sel` elige los parámetros incluidos.
- `d_modo = 2`, **Monte Carlo**: los siete a la vez, factor uniforme en [1−`d_pct`, 1+`d_pct`]; `d_nmc = 20` realizaciones.

**Métricas por caso** (promedio sobre semillas): RMSE de la estimación Kalman de `T_AC`, `T_A`, `T_B` (mNm) y `θ_C` (deg); RMSE de la carga emulada (`T_A` real vs `H_LUT(θ_C real)`, mNm); RMSE del seguimiento de consigna (deg); y número de fail-safes. En modo 1 imprime un **ranking de sensibilidad** (peor caso de cada parámetro / nominal) basado solo en el RMSE de `T_AC`. Guarda `desajuste_esc<N>.mat`.

**Uso:** ejecutar `paso6_desajuste_parametros.m` directamente (hace su propio `clc; clear; close all`, no se llama desde `main.m`). Cada corrida tarda lo mismo que `main.m` (decenas de segundos): con la configuración por defecto de modo 1, hay 15 casos × 3 semillas = 45 corridas. **Resultados: pendientes.**

---

## 12. Limitaciones y supuestos de la simulación

1. Los fail-safes leen el estado verdadero (§8.2).
2. El Kalman no modela: dinámica de los drivers, g-sensitivity de la IMU, filtros de Hall y corriente, deriva de `Kt` ni la dependencia de `T_A` con `θ_C` (la carga de la LUT); `T_A` es un paseo aleatorio.
3. Sesgo de corriente aditivo con reversión a cero: no representa una pérdida de `Kt`, que es multiplicativa y persistente (el `fac_Kt` de `paso6` sí la representa, pero estático).
4. **Decimación sin antialiasing adicional:** los sensores se filtran con pasa-bajos de primer orden (≥150 Hz) y se muestrean a 1 kHz. A 500 Hz (Nyquist) un filtro de 200 Hz atenúa solo ~8.6 dB; el aliasing no está modelado.
5. **Parámetros de sensor sin reescalar:** al pasar a la escala de la LUT (≈0.67 Nm) se cambiaron `T_nom`, `T_B_max` y los fail-safes, pero no el ruido ni los sesgos. El `σ_b` del transductor (0.20 Nm) es ≈ 30 % del pico de la carga y el sesgo de corriente A (0.15 A·0.06 Nm/A = 9 mNm) pesa mucho más que en v1. Decidir si son realistas para el hardware real.
6. LUT: carga **cuasi-estática** (sin histéresis ni efectos no estacionarios), AoA y Mach constantes durante el ensayo, `Ch` interpolado linealmente en (M, AoA), saturado fuera de ±15°.
7. Servo B: sin dinámica interna, backlash ni zona muerta; PID de torque con ganancias provisorias; la velocidad máxima solo emite un aviso.
8. Constante térmica de 10 s acelerada, sin efecto mientras `kt_drift = 0`.
9. Ganancia de Kalman fija (no se simula el arranque).
10. Cada resultado es de una realización con semilla fija; para citar cifras con dispersión se necesitan varias semillas (como hace `paso6` en modo 1).

## 13. Decisiones abiertas y recomendaciones para el banco físico

**Decisiones abiertas del código:**

- Decidir si el filtro de corriente y el Hall (200 Hz) quedan así (la regla 5×`fn1` no se cumple) o se sube el `fs_kf`/ancho de banda.
- Decidir si se reescalan los ruidos y sesgos a la escala de la LUT (§12, punto 5).
- Validar los límites de `T_AC`, `T_CB` y `ω_C` (heurísticos) y decidir si `failsafe_extra` queda activo.
- Confirmar la geometría de referencia del CFD (`c²·b = 6.0e-3 m³`) frente a la del banco (§5.2).
- ¿Quedan apagadas la deriva de `Kt` y los parámetros de servo provisorios?

**Recomendaciones:**

1. **Analizar la estabilidad del lazo de carga A–Kalman** y verificar las ganancias del servo con la arquitectura actual (los autovalores de v1 no aplican).
2. Verificar con datasheet `T_B_max`, `w_servo_max`, y la g-sensitivity y el ODR reales de la IMU (`fs_kf`).
3. Calibrar el transductor propio con cargas conocidas y reemplazar `noise_strain_std`.
4. Caracterizar el retardo real de cada cadena de sensor y modelarlo en el Kalman como en §7.1.
5. Usar los resultados de `paso6` para elegir qué medir primero (rigidez del eje, `Kt`, inercias).
6. Verificar la observabilidad práctica (covarianza estacionaria de los estados de sesgo), no solo el rango.
7. Definir un procedimiento de rearme tras un fail-safe: hoy es permanente.
8. Considerar un segundo transductor en C–B si la aleta puede recibir carga externa propia.

---

## 14. Bitácora técnica (historial de depuración)

Se conserva como historial; los valores corresponden a las versiones indicadas, no a la actual.

### 14.1 Explosión numérica por modo de cuerpo rígido (v0)
**Síntoma:** con solo fricción de rodamiento, el sistema libre-libre alcanzaba miles de rad. **Causa:** un desbalance sostenido (`T_A ≠ T_B`) se integra sin límite en el modo de cuerpo rígido (0 Hz). **Solución:** B necesita un lazo de posición real (PID), no un perfil de torque abierto.

### 14.2 Inestabilidad del lazo de control (error de signo) (v0–v1)
**Síntoma:** el sistema explotaba a ~10³⁰² incluso con ganancias conservadoras. **Diagnóstico:** matriz de lazo cerrado (mecánica + driver + PID) con sus autovalores; la parte real de un polo crecía linealmente con `Kp`: firma de error de signo. **Causa:** `T_B` entra como `-T_B` y el controlador no respetaba esa convención. **Ganancias verificadas entonces:** `Kp=2, Ki=2, Kd=0.1`, con control sobre el estado verdadero de B. **Vigencia:** no hay verificación para v2.

### 14.3 Deriva térmica de `Kt` (v1 temprana)
Se implementó un calentamiento simple que degradaba `Kt` hasta 8 % con sesgos como paseo aleatorio, con mejoras de 70–95 % sobre "solo corriente". Hoy la deriva está apagada y los sesgos son Gauss-Markov (§6.3, §4.3): esas cifras ya no aplican.

### 14.4 `omega_C` no mejoraba con Kalman: el hallazgo más importante
**Síntoma:** el RMSE de `omega_C` casi no bajaba (~0.4 %). **Primer diagnóstico (descartado):** mala sintonía de `Q` (barrido de 7 órdenes sin cambio). **Diagnóstico correcto:** bajar el ruido del gyro 20× no cambiaba nada; subir su ancho de banda mejoraba 6×: el error era **retardo de fase, no ruido**. **Causa raíz:** los pasa-bajos de IMU y transductor estaban en la simulación pero `H` apuntaba directo a `ω_C`/`T_AC`. **Solución:** estados `gyro_filt`/`strain_filt` (§7.1). **Resultado:** de ~0 % a ~94 % en v1. **Lección:** todo sensor con retardo apreciable frente a la dinámica de interés debe modelarse así.

### 14.5 "Ancho de banda del Kalman"
Resumir el desempeño con los polos de `(I−KH)·A` mezcla polos rápidos (mecánica) con lentos (sesgos) y no produce una cifra útil. Se evalúa con RMSE de seguimiento.

### 14.6 Evolución v1 → v2
- **Escala y carga:** de una rampa de 4 Nm a la carga de bisagra del CFD (LUT, ≈0.67 Nm con la aleta de 20×15 cm) evaluada con `θ̂_C`; parámetros de torque y fail-safes reescalados.
- **Actuador B:** de motor controlado con el Kalman a servo MG996R con su potenciómetro, con saturación de torque.
- **Escenarios:** tres consignas (rampa, escalones con carga máxima, barrido senoidal).
- **Tasa:** planta a 5 kHz, sensores y Kalman a 1 kHz; `Q` reescalada; Hall y corriente a 200 Hz.
- **Seguridad:** límite de ángulo de aleta y de torque rebajados.
- **Reproducibilidad:** `rng(semilla)`.
- **Nuevo estudio:** `paso6` (desajuste de parámetros) y la separación planta nominal/verdadera.
- **v2.1 (aleta 20×15 cm):** `c = 0.20 m`, `b = 0.15 m`, igual a la geometría del CFD (verificada contra `HingeMoment_Nm` en `paso2`); torques reescalados (pico 0.67 Nm, `T_nom` 0.8 Nm, fail-safe 1.2 Nm mayor que `T_B_max`); fail-safes de `T_AC`, `T_CB` y `ω_C` (`failsafe_extra`).

### 14.7 Evolución del modelo mecánico (resumen)
1. **Un disco (1 GDL):** `J·θ'' + c·θ' + k·θ = T`, aterrizado a una pared. Valida la arquitectura de fusión (strain gauge + IMU).
2. **Dos discos (2 GDL), libre-libre:** aparece el modo rígido (0 Hz) y el modo de torsión `fn = sqrt(k·(1/J_A + 1/J_B))/(2π)`. Con dos IMUs (una por rotor) y un strain gauge, `T_A ≠ T_B` es separable; con una sola IMU en el eje, no.
3. **Tres discos (configuración final, §3).**

---

## 15. Estructura del código y cómo ejecutarlo

| Archivo | Contenido |
|---|---|
| `main.m` | `clc; clear; close all;`, `paso1`, define `escenario`, luego `paso2`…`paso5` |
| `paso1_parametros_sistema.m` | Parámetros mecánicos, eléctricos y de escala de torque, fail-safes, parámetros del servo, IMU excéntrica, frecuencias naturales, anchos de banda, sesgos Gauss-Markov |
| `paso2_perfiles_y_deriva.m` | Tiempos y tasas, semilla, escenario y consigna, lectura de la LUT y construcción de `H_lut_deg`, constantes del driver y térmica |
| `paso3_modelo_y_kalman.m` | Planta de 6 estados (nominal y "true"), modelo de 14 estados, `H`, `Q`, `R`, ruido y sesgos de sensores, constantes de filtros, observabilidad, ganancia estacionaria |
| `paso4_bucle_simulacion.m` | Bucle: fail-safes, carga de A por LUT, servo B, planta, sensores, Kalman a 1 kHz |
| `paso5_graficos_y_metricas.m` | 5 figuras, RMSE y mejora, seguimiento de consigna y carga, evaluación de ancho de banda, estado de fail-safes |
| `paso6_desajuste_parametros.m` | Estudio de desajuste (§11); independiente de `main.m` |
| `resultados.csv` | LUT del CFD (§5.1); debe estar en la carpeta de trabajo |

**Cómo ejecutar:** correr `main.m` (elegir `escenario` dentro). Los pasos comparten workspace y dependen unos de otros. `paso1` hace `clearvars`, por eso `escenario` se define **después** de `paso1`.

**Requisitos:** Control System Toolbox (`ss`, `c2d`, `obsv`); `rmse` (verificar de qué toolbox viene en tu versión); `readmatrix`, `interp2`, `pchip` y `xline` (R2018b o posterior).

**Figuras:**
1. Torque de Motor A y B: real, "solo corriente" y Kalman.
2. Flexión torsional de los dos tramos del eje.
3. Cinemática de la aleta C: `θ_C` y `ω_C` (real, IMU, Kalman).
4. Seguimiento de los cuatro sesgos Gauss-Markov.
5. **Seguimiento de consigna** (`δ_cmd`, `θ_C` real y Kalman) **y carga emulada** (`H_LUT(θ_C real)`, `T_A` real, `T_A` Kalman).

**Métricas:** "RMSE crudo" es el RMSE entre la salida filtrada del sensor (convertida a la variable física) y la verdad; "RMSE Kalman", el de la estimación; "Mejora" = (crudo − Kalman)/crudo. Se omiten las variables sin sensor directo. Se agrega un bloque de seguimiento y carga emulada (RMSE y error máximo del ángulo respecto de la consigna; RMSE de `T_A` real frente a `H_LUT(θ_C real)`; `max|T_B|`; `max|T_AC|`).

**Pendientes en el código (solo texto, no afectan resultados):** las etiquetas de `paso5` dicen "Estimación Kalman de Kt y Bias" y "Solo corriente (Kt nominal)", pero el filtro estima un sesgo aditivo, no `Kt`; el encabezado de `paso4` y el nombre de `paso2` ("…y deriva") están desactualizados; `T_trans_prev` en `paso4` no se usa; el comentario de `paso2` dice "escalones de 5°" pero el último escalón del escenario 2 es de 10°.
