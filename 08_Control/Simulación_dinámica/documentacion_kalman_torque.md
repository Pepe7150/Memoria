# Estimación de Torque vía Fusión Sensorial (Filtro de Kalman)
### Documentación técnica — Banco de Ensayo de Actuadores de Superficie de Control

**Contexto:** este documento describe el subsistema de estimación de torque del banco de ensayo, desarrollado como parte de la Memoria de Título. El objetivo es estimar el torque que ejerce cada motor (carga aerodinámica emulada y actuador bajo prueba), el torque transmitido por el acople y el estado angular del conjunto eje/aleta, combinando varios sensores mediante un Filtro de Kalman en lugar de confiar en una sola medición.

**Estado del documento (17-oct-2026):** sincronizado con la versión modular actual del código (`main.m` + `paso1`…`paso5`) y con una corrida de referencia (§9). El documento tiene dos partes: la **referencia** (§1–§9), que describe el sistema tal como está hoy, y la **bitácora** (§12), que conserva el historial de depuración. Los puntos pendientes están en §10 y §11.

---

## 1. Resumen: qué se simula

Se simula un banco con tres masas rotatorias unidas por un eje de acero elástico:

```
 Motor A ──(k1,c1)── Aleta C ──(k2,c2)── Motor B
  (J_A)               (J_C)                (J_B)
 aplica carga      sin actuador           resiste / controla
 (lazo abierto)    (sin sensor de pos.)   (PID de posición)
```

**Escenario de prueba (20 s, paso de 0.2 ms = 5 kHz, 100 000 pasos):**

1. Motor A recibe un torque de referencia en lazo abierto: 0 Nm hasta t = 1 s, rampa lineal a 4 Nm entre 1 s y 4 s, y 4 Nm constante hasta el final.
2. Motor B ejecuta un PID que mantiene la posición de la aleta C en 0 rad. El PID no lee la planta: lee la **estimación del Kalman**.
3. Todos los sensores tienen ruido, filtro pasa-bajos y sesgo (algunos con sesgo que varía en el tiempo).
4. Una capa de fail-safes corta los torques si se excede algún límite físico.
5. Al final se compara lo estimado con la "verdad" de la simulación y se reportan RMSE y mejora respecto del sensor crudo.

**Flujo de señal:**

```
 T_A_ref ─► driver A ─► T_A ──┐
                              ▼
                      ┌──────────────┐   Hall A, Hall B, corrientes,
                      │ PLANTA REAL  │──► IMU (en C), strain gauge (A-C)
                      │ (6 estados)  │        │ (ruido + sesgo + pasa-bajos)
                      └──────────────┘        ▼
                              ▲        ┌──────────────┐
 I_B ◄─ driver B ◄─ PID ◄─────┼────────│ KALMAN (14)  │
        (T_B_cmd)   (θ̂_C, ω̂_C)        └──────────────┘
```

**Separación "verdad" / "estimado":** `x6` (planta de 6 estados), `T_A_true`, `T_B_true` y los sesgos `bias_*_true` son la verdad de la simulación. `x_est` (14 estados) es lo único que el controlador y las métricas "Kalman" usan como estimación. Los fail-safes (§7.2) todavía leen la verdad, no la estimación (ver §10).

---

## 2. Convenciones y nomenclatura

| Símbolo | Significado | Unidad |
|---|---|---|
| `θ_A, θ_C, θ_B` | Ángulo de Motor A, aleta C y Motor B | rad |
| `ω_A, ω_C, ω_B` | Velocidades angulares correspondientes | rad/s |
| `T_A, T_B` | Torque que ejerce cada motor (siempre se define positivo) | Nm |
| `T_AC, T_CB` | Torque transmitido por el tramo A–C y por el tramo C–B | Nm |
| `bias_IA, bias_IB` | Sesgo aditivo del sensor de corriente | **A** |
| `bias_IMU` | Sesgo del giroscopio | rad/s |
| `bias_SG` | Sesgo del strain gauge | Nm |
| `x_est` | Vector de estado estimado (14×1) | — |

**Convención de signo:** `T_A` empuja a A en sentido positivo y `T_B` entra a la ecuación de B como `-T_B` (B "resiste"). El controlador de B debe respetar esa convención; un error aquí produce realimentación positiva (§12.2).

---

## 3. Modelo mecánico

### 3.1 Configuración final: tres discos, dos tramos elásticos

```
J_A·θ_A'' + b_A·θ_A' + c1·(θ_A'-θ_C') + k1·(θ_A-θ_C) = T_A
J_C·θ_C'' + c1·(θ_C'-θ_A') + k1·(θ_C-θ_A) + c2·(θ_C'-θ_B') + k2·(θ_C-θ_B) = 0
J_B·θ_B'' + b_B·θ_B' + c2·(θ_B'-θ_C') + k2·(θ_B-θ_C) = -T_B
```

Con `b_A`, `b_B` fricción viscosa de rodamiento de cada motor. La aleta C no tiene fricción propia ni carga externa.

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
| Torque nominal (solo para el modelo térmico) | 4 Nm (A), 3 Nm (B) | |

### 3.2 Frecuencias naturales

Se calculan con `eig(K, M)` sobre el modelo sin amortiguamiento (`M = diag(J_A, J_C, J_B)`; `K` y `M` son simétricas, pero con 3 GDL no hay fórmula cerrada simple):

| Modo | Frecuencia (corrida) | Descripción |
|---|---|---|
| Rígido | 0 Hz | Todo el conjunto rota en bloque. No hay resorte a tierra. |
| `fn1` | **69.18 Hz** | Modo dominante: A y B se mueven de forma significativa. |
| `fn2` | **265.58 Hz** | Modo local de C (por su `J_C` pequeño): A y B casi no se mueven. |

"Dominante" no significa que `fn2` sea menos real: como los motores excitan A y B (no C), `fn1` recibe mucha más energía que `fn2`.

### 3.3 Matriz `C_torque` (DRY)

La relación entre el estado mecánico y los torques transmitidos está centralizada:

```
[T_AC; T_CB] = C_torque · [θ_A; ω_A; θ_C; ω_C; θ_B; ω_B]

C_torque = [ k1,  c1, -k1, -c1,   0,   0;
              0,   0,  k2,  c2, -k2, -c2]
```

Se usa en la planta, en el Kalman (estado `strain_filt`) y en la generación de la señal del strain gauge, para no repetir (y desincronizar) la fórmula.

**Supuesto de modelado:** `T_AC` incluye el término viscoso `c1·(ω_A-ω_C)`. Un strain gauge real mide solo la deformación elástica (`k1·Δθ`). Con `c1` pequeño la diferencia es mínima, pero es una simplificación.

### 3.4 Planta discreta

`Ac6`/`Bc6` se discretizan con `ss(...)` y `c2d(..., 'zoh')` (Control System Toolbox). La entrada de la planta es `[T_A_true; T_B_true]`.

---

## 4. Instrumentación y modelo de sensores

### 4.1 Tabla de sensores

| Sensor | Mide | Ubicación | Ruido (σ) | Ancho de banda | Sesgo |
|---|---|---|---|---|---|
| Hall + anillo magnético | `θ_A`, `θ_B` | Motores A y B | 0.002 rad | 500 Hz | Fijo (0.05 y −0.03 rad), **calibrado y restado** |
| Sensor de corriente + `Kt` | `T = Kt·I` | Cada motor | 0.03 A | 500 Hz | **Gauss-Markov** (σ_b 0.15 A y 0.12 A) |
| IMU (giroscopio) | `ω_C` | Aleta C | 0.02 rad/s | 150 Hz | **Gauss-Markov** (σ_b 0.25 rad/s) + g-sensitivity |
| Transductor propio (tubo + strain gauges) | `T_AC` | Tramo A–C | 0.005 Nm | 30 Hz | **Gauss-Markov** (σ_b 0.20 Nm) |

Todos los canales pasan por un filtro pasa-bajos discreto de primer orden: `y[i] = y[i-1] + α·(raw − y[i-1])`, con `α = dt/(τ+dt)` y `τ = 1/(2π·BW)`.

### 4.2 Sesgos dinámicos (Gauss-Markov / Ornstein-Uhlenbeck)

Corriente, IMU y strain gauge tienen un sesgo que varía lentamente y revierte a cero:

```
b[i] = b[i-1]·exp(-dt/τ_b) + σ_b·sqrt(1 - exp(-2·dt/τ_b))·randn
```

| Canal | `τ_b` | `σ_b` | Valor inicial |
|---|---|---|---|
| Corriente A | 12 s | 0.15 A | 0.10 A |
| Corriente B | 12 s | 0.12 A | −0.08 A |
| IMU | 8 s | 0.25 rad/s | 0.20 rad/s |
| Strain gauge | 10 s | 0.20 Nm | 0.15 Nm |

Con `τ_b` de 8–12 s y una simulación de 20 s, cada sesgo recorre solo 1.7–2.5 constantes de tiempo: la corrida es corta para ver el comportamiento estadístico completo.

### 4.3 Hall: calibración estática

Los Hall tienen un sesgo de montaje fijo que se resta antes de filtrar (`thA_cal = thA_raw − bias_hallA`). Representa una calibración ya conocida, por eso **no hay estado de sesgo de Hall en el Kalman**. Si en el banco real ese sesgo no se conoce con precisión o deriva, debe tratarse como los demás sesgos (estado estimado en línea).

### 4.4 IMU: excentricidad y g-sensitivity

La IMU está a `r_imu = 5 mm` del eje. Un giroscopio MEMS filtra una fracción de la aceleración lineal a su salida angular:

```
error_gsens = g_sens_imu · (ω_C² · r_imu) / g
```

con `g_sens_imu = 0.05 °/s por g` (valor **típico**, no el de la IMU real: reemplazar con el datasheet). El código modela solo la aceleración centrípeta; no incluye la tangencial (`α·r`), que podría ser mayor con ω pequeño y vibración alta. Con ω_C controlado cerca de 0, el efecto es despreciable frente al sesgo y al ruido. El Kalman **no** modela esta perturbación.

### 4.5 Transductor de torque propio

Se descartó el FT05 comercial por costo. El transductor propio (tubo en línea con el eje, strain gauges directos, puente de Wheatstone por armar) no tiene especificaciones de fábrica. Su ancho de banda lo define la electrónica de acondicionamiento que se diseñe. El valor `noise_strain_std = 0.005 Nm` es un marcador heredado del FT05 y **debe reemplazarse por datos de calibración reales** antes de dimensionar el filtro en el banco físico.

### 4.6 Decisión de diseño: un solo tramo instrumentado

El transductor está solo en el tramo A–C. `θ_C` y `T_CB` se infieren del modelo. Se justifica porque la aleta no recibe carga externa propia. Si eso cambiara, un segundo transductor en C–B sería necesario: con un solo tramo medido, un torque externo no modelado en C es indistinguible de un error de calibración de `k`/`c`.

---

## 5. Actuación y modelo térmico

- **Driver (200 Hz):** `T_A` real = `T_A_ref` filtrado; `I_B` real = `I_B_ref` filtrado. El Kalman **no** modela esta dinámica: trata `T_A` y `T_B` como paseo aleatorio.
- **Torque de B:** `T_B_true = Kt_B_actual · I_B_true`. Motor A: `I_A_true = T_A_true / Kt_A_actual`.
- **Modelo térmico:** un proxy de calentamiento (`I²`, constante de tiempo 10 s, acelerada y no física) degrada `Kt_actual = Kt·(1 − kt_drift·heat)`.
- **Estado actual: la deriva de `Kt` está APAGADA** (`kt_drift_A = kt_drift_B = 0` en `paso4`). El modelo térmico se calcula pero no afecta la simulación. Para reactivarla, asignar un valor positivo (en la bitácora, §12.3, se usó una degradación de hasta 8%).
- No hay saturación de corriente ni de torque en los actuadores, solo los fail-safes de §7.2.

---

## 6. Filtro de Kalman

### 6.1 Estados (14)

```
x = [θ_A, ω_A, θ_C, ω_C, θ_B, ω_B,   T_A, T_B,   gyro_filt, strain_filt,   bIA, bIB, bIMU, bSG]
     |--- mecánico (1-6) ---------|  |7-8|       |------ 9-10 ---------|   |------ 11-14 -------|
```

| Bloque | Estados | Modelo |
|---|---|---|
| Mecánico | 1–6 | Newton exacto del sistema de 3 discos, con `T_A`, `T_B` como entradas (`Ac14(1:6,7:8) = Bc6`) |
| Torques | 7–8 | Paseo aleatorio: se desconocen a priori |
| Retardo de sensor | 9–10 | `gyro_filt' = (ω_C − gyro_filt)/τ_imu`; `strain_filt' = (T_AC − strain_filt)/τ_sg`. Modelan el pasa-bajos de IMU y transductor |
| Sesgos | 11–14 | Gauss-Markov: `b' = −b/τ_b` (diagonal de `Ac14`) |

### 6.2 Matriz de medición `H`

| Medición | Combinación de estados |
|---|---|
| Hall A | `θ_A` |
| Hall B | `θ_B` |
| Corriente A (`Kt_A·I_A`) | `T_A + Kt_A·bIA` |
| Corriente B (`Kt_B·I_B`) | `T_B + Kt_B·bIB` |
| IMU | `gyro_filt + bIMU` |
| Transductor | `strain_filt + bSG` |

Los sesgos de corriente están en **amperes**; por eso `H` los multiplica por `Kt`.

### 6.3 Sintonía de `Q` y `R`

`Q` (diagonal, en el orden de los 14 estados):

| Estados | Valor |
|---|---|
| `θ_A, θ_C, θ_B` | `1e-10` |
| `ω_A, ω_C, ω_B` | `5e-5` |
| `T_A, T_B` | `0.01·dt = 2e-6` |
| `gyro_filt, strain_filt` | `1e-8` |
| Sesgos | `q_b·dt`, con `q_b = 2σ_b²/τ_b`: IA ≈ 7.5e-7, IB ≈ 4.8e-7, IMU ≈ 3.1e-6, SG ≈ 1.6e-6 |

`R` (diagonal) se calcula como la varianza del ruido blanco tras pasar por el filtro de primer orden del sensor:

```
var = σ² · α / (2 − α)
R = diag(var_hall, var_hall, Kt_A²·var_IA, Kt_B²·var_IA, var_imu, var_sg)
```

(El canal B reutiliza `var_IA`: ambos sensores de corriente tienen el mismo ruido.)

**Supuesto:** tras el filtro el ruido ya no es blanco (está correlacionado en el tiempo), pero el Kalman lo trata como si lo fuera. Es una aproximación habitual.

### 6.4 Discretización y ganancia estacionaria

El modelo del Kalman (`Ac14`, sin entrada conocida) se discretiza con `Adk = expm(Ac14·dt)`. La ganancia `K_kalman_steady` se obtiene **una sola vez**, iterando 500 veces la ecuación de Riccati antes del bucle principal, y se usa fija:

```matlab
for iter = 1:500
    P_pred = Adk*P_temp*Adk' + Q;
    S = H*P_pred*H' + R;
    K_kalman_steady = (P_pred*H') / S;
    P_temp = (eye(nx) - K_kalman_steady*H)*P_pred;
end
```

Es válido porque `Q`/`R` son constantes (sin mediciones faltantes ni cambios de sintonía). **Costo:** no se reproduce el transitorio de arranque de la ganancia. Esto es irrelevante para régimen permanente, pero importa si se quiere estudiar el arranque.

### 6.5 Condiciones iniciales

`x_est` arranca en cero para los 14 estados, mientras que los sesgos verdaderos arrancan en los valores de §4.2. El transitorio inicial de la estimación de sesgos viene de ahí.

### 6.6 Observabilidad

```matlab
O_mat = obsv(Adk, H);  rank_O = rank(O_mat);  cond_O = cond(O_mat);
```

Resultado de la corrida de referencia: **rango 14/14, condición 9.0·10⁵**. El rango completo indica observabilidad. Pero con `dt = 0.2 ms`, `Adk` queda muy cerca de la identidad, de modo que rango y condición son numéricamente delicados: este chequeo es indicativo, no una prueba. Un rango completo tampoco garantiza que cada estado se estime bien en la práctica (ver §9.3, sesgo de corriente B).

---

## 7. Control y fail-safes

### 7.1 Control de Motor B

PID de posición sobre la **estimación del Kalman** (no sobre la verdad), con objetivo `theta_C_target = 0`:

```
e = 0 − θ̂_C
T_B_cmd = −( Kp·e + Ki·∫e + Kd·(0 − ω̂_C) ),  Kp = 1, Ki = 5, Kd = 0.5
I_B_ref = T_B_cmd / Kt_B
```

La integral está acotada a ±10 (anti-windup por saturación). El controlador usa la estimación del paso anterior.

Esto es más representativo del banco real (donde nunca se accede al estado verdadero), pero acopla estimador y control: un error de estimación se realimenta a la planta. El análisis de autovalores de §12.2 **no cubre** esta arquitectura ni las ganancias actuales (ver §11).

### 7.2 Fail-safes

Capa de protección separada del lazo de control. Cada paso revisa el estado del paso anterior:

| Límite | Valor | Variables revisadas |
|---|---|---|
| Ángulo | ±135° | `θ_A`, `θ_B` |
| Velocidad angular | ±1000 RPM | `ω_A`, `ω_B` |
| Torque | ±8.0 Nm | `T_A_true`, `T_B_true` |

Al dispararse, `system_fault = true` y se registran `fault_time` y `fault_reason`. A partir de ahí:

- el comando de A y el torque de A pasan a 0 de inmediato; la referencia de corriente de B pasa a 0, pero `I_B` decae según el filtro del driver;
- **la planta sigue evolucionando**: los rotores no se detienen, giran por inercia con su fricción;
- la falla es **permanente** durante el resto de la simulación (sin rearme);
- los gráficos marcan el instante con una línea vertical.

**Limitaciones actuales:** (a) los fail-safes leen el estado verdadero, no la estimación ni sensores; (b) el límite de torque no revisa `T_AC` ni `T_CB`; (c) no se vigilan `θ_C` ni `ω_C`.

El diseño es de dos capas: el PID mantiene el sistema en rango en operación normal; los fail-safes (y en el banco real, los fines de carrera) son protección de emergencia, no el mecanismo de control.

---

## 8. Regla heurística de ancho de banda

En lugar de un análisis espectral (decisión de alcance), se compara cada ancho de banda con la frecuencia relevante, con margen ≥ 5×:

| Categoría | Referencia | Razonamiento |
|---|---|---|
| Driver | Lazo de control `sqrt(Kp/J_B)/(2π)` ≈ **9.19 Hz** (con `Kp = 1`) | Solo hace falta soportar el lazo de posición diseñado |
| Corriente (y Hall) | `fn1` = 69.18 Hz | Están en A/B (masas grandes), poco sensibles al modo local de C |
| IMU y transductor (en C) | RMSE de seguimiento, no BW individual | Su retardo está modelado en el Kalman (§6.1) |

`paso5` solo verifica automáticamente el driver y el filtro de corriente; el Hall (500 Hz > 5·`fn1`) cumple la regla pero no se imprime. El transductor (30 Hz) está **por debajo de `fn1`**: se compensa modelando su retardo, no es una limitación ignorada.

---

## 9. Resultados de la corrida de referencia

**Condiciones:** configuración de §3–§7 (deriva de `Kt` apagada), una sola corrida, sin semilla del generador aleatorio (`rng`): las cifras cambian algo en cada ejecución. No se disparó ningún fail-safe.

### 9.1 Estimación de sesgos

| Sesgo | RMSE de estimación | Referencia (`σ_b`) |
|---|---|---|
| Corriente A | 0.0522 A | 0.15 A |
| Corriente B | 0.0609 A | 0.12 A |
| IMU | 0.0172 rad/s | 0.25 rad/s |
| Strain gauge | 0.0060 Nm | 0.20 Nm |

### 9.2 Estados y torques

| Variable | RMSE crudo | RMSE Kalman | Mejora |
|---|---|---|---|
| `θ_A` | 0.00098 rad | 0.00023 rad | 76.6 % |
| `θ_B` | 0.00097 rad | 0.00023 rad | 76.9 % |
| `θ_C` | N/A (sin sensor) | 0.00022 rad | — |
| `ω_A`, `ω_B` | N/A (sin sensor) | 0.0165, 0.0182 rad/s | — |
| `ω_C` | 0.3127 rad/s | 0.0177 rad/s | 94.4 % |
| `T_A` | 0.0119 Nm | 0.0033 Nm | 72.7 % |
| `T_B` | 0.0034 Nm | 0.0034 Nm | **0.01 %** |
| `T_AC` | 0.2365 Nm | 0.0032 Nm | 98.7 % |
| `T_CB` | N/A (sin sensor) | 0.0032 Nm | — |

### 9.3 Interpretación

- **Mejor caso — `T_AC` y `ω_C`:** los sensores en C tienen sesgo grande y retardo apreciable (IMU 150 Hz, transductor 30 Hz). El modelo de retardo y la estimación de sesgo explican mejoras de 94–99 %. Este sigue siendo el hallazgo de mayor impacto (§12.4).
- **`T_A`:** mejora de 72.7 %, atribuible a la corrección del sesgo de corriente y al filtrado de ruido (la deriva de `Kt` está apagada, así que ya no es la causa, a diferencia de lo que decía la versión anterior del documento).
- **`T_B` sin mejora:** el Kalman no mejora a "solo corriente" (0.01 %). El error de `T_B` (0.0034 Nm) coincide con `Kt_B·RMSE(bIB) = 0.05·0.061 ≈ 0.003 Nm`, y el RMSE del sesgo B (0.061 A) es del orden del propio sesgo. **Hipótesis, no verificada:** pese al rango completo, `T_B` y `bIB` casi no se separan en la práctica, porque el sesgo equivale a unos 3–6 mNm, por debajo de lo que la dinámica puede discriminar con B en lazo cerrado. Para confirmarlo, revisar la covarianza estacionaria `P_temp` de los estados 8 y 12. En términos absolutos el error es pequeño (≈ 0.1 % de los 4 Nm del ensayo).
- **Sesgos de corriente:** se estiman peor (RMSE 35–51 % de `σ_b`) que los de IMU (7 %) y transductor (3 %). Los primeros solo se observan a través del torque; los segundos tienen un sensor dedicado en el mismo canal.
- **Posiciones:** `θ_C` (sin sensor) se estima con el mismo error (≈ 0.0002 rad) que las posiciones medidas, lo que apoya la calidad del modelo mecánico.
- **Lazo de control:** ancho de banda 9.19 Hz; el driver (200 Hz) y el filtro de corriente (500 Hz) cumplen la regla de 5×.

---

## 10. Limitaciones y supuestos de la simulación

1. Fail-safes basados en el estado verdadero (§7.2).
2. El Kalman no modela: dinámica del driver, g-sensitivity de la IMU, filtros de Hall y de corriente, ni la deriva de `Kt`.
3. Sesgo de corriente aditivo y con reversión a cero: no representa bien una pérdida de `Kt`, que es multiplicativa (proporcional al torque) y persistente. Si se reactiva `kt_drift`, conviene modelarlo como un factor multiplicativo o como un estado propio.
4. Constante térmica de 10 s acelerada, solo con fines de demostración.
5. Sin saturación de actuadores ni mediciones faltantes.
6. Ganancia de Kalman fija (no se simula el arranque).
7. Resultados de una sola corrida sin semilla: faltan varias corridas (Monte Carlo) para citar cifras con su dispersión.

## 11. Decisiones abiertas y recomendaciones para el banco físico

**Decisiones abiertas del código:**

- ¿Incluir `T_AC` y `T_CB` (y quizá `θ_C`, `ω_C`) en el fail-safe de torque/ángulo/velocidad?
- ¿Dejar la deriva de `Kt` apagada como caso base, o reactivarla y rediseñar el sesgo (limitación 3)?
- Fijar `rng(semilla)` al inicio de `main.m` para reproducibilidad.

**Recomendaciones:**

1. **Re-verificar la estabilidad del lazo** con autovalores usando `Kp=1, Ki=5, Kd=0.5` y la arquitectura observador-en-el-lazo (§7.1). La última verificación (§12.2) usó `Kp=2, Ki=2, Kd=0.1` y estado verdadero. El principio de separación no aplica automáticamente con ganancia fija y fail-safes no lineales.
2. **Calibrar el transductor propio** con cargas conocidas y reemplazar `noise_strain_std`.
3. **Diseñar la electrónica de acondicionamiento** (transductor y Hall) con un ancho de banda deliberado.
4. **Caracterizar el retardo real de cada cadena de sensor** y modelarlo en el Kalman como en §6.1.
5. **Definir un procedimiento de rearme tras un fail-safe**: hoy la falla es permanente.
6. **Considerar un segundo transductor en C–B** si la aleta puede recibir carga externa propia.
7. **Validar la constante térmica real** de los motores y la **g-sensitivity real** de la IMU (datasheet).
8. **Verificar la observabilidad práctica** (covarianza estacionaria de los estados de sesgo), no solo el rango (§6.6, §9.3).

---

## 12. Bitácora técnica (historial de depuración)

El proceso de depuración es parte del aporte metodológico del trabajo. Esta sección se conserva como historial; los valores citados corresponden a las versiones indicadas, no a la actual.

### 12.1 Explosión numérica por modo de cuerpo rígido
**Síntoma:** con solo fricción de rodamiento, `θ`/`ω` del sistema libre-libre alcanzaban miles de rad y rad/s.
**Causa:** un desbalance sostenido (`T_A ≠ T_B`) se integra sin límite en el modo de cuerpo rígido (0 Hz).
**Solución:** Motor B necesita un lazo de control de posición real (PID), no un perfil de torque abierto.

### 12.2 Inestabilidad del lazo de control (error de signo)
**Síntoma:** el sistema explotaba a valores de orden 10³⁰² incluso con ganancias conservadoras.
**Diagnóstico:** se armó la matriz de lazo cerrado (mecánica + driver + PID) y se calcularon sus autovalores. La parte real de un polo crecía linealmente con `Kp`: firma de error de signo, no de sintonía.
**Causa:** `T_B` entra como `-T_B` en la ecuación de Newton y el controlador no respetaba esa convención (realimentación positiva).
**Ganancias verificadas en esa etapa:** `Kp=2, Ki=2, Kd=0.1` (ancho de banda ~13 Hz), con control sobre el estado verdadero de B.
**Pendiente:** no hay verificación para la configuración actual (§11, punto 1).

### 12.3 Deriva térmica de `Kt` (versión anterior)
**Hipótesis:** `T = Kt·I` es exacto en simulación, pero en la realidad `Kt` se degrada con la temperatura, y ahí la fusión debería superar a "solo corriente".
**Implementación entonces:** calentamiento simple (proxy de `I²`, constante de 10 s) degradando `Kt` hasta 8 %, con estados de sesgo como paseo aleatorio lento.
**Resultado entonces:** mejoras de 70–95 % sobre "solo corriente". Motor A mostraba un sesgo que se estabilizaba; Motor B mostraba corriente creciente (el control compensaba la pérdida de `Kt`), patrón útil como indicador de desgaste.
**Estado actual:** la deriva está apagada y los sesgos son Gauss-Markov (§4.2, §5). Las cifras de esa etapa ya no aplican.

### 12.4 `omega_C` no mejoraba con Kalman — el hallazgo más importante
**Síntoma:** el RMSE de `omega_C` casi no bajaba al fusionar (~0.4 %).
**Primer diagnóstico (descartado):** mala sintonía de `Q`. Se barrió `q_omega` en 7 órdenes de magnitud sin cambio.
**Diagnóstico correcto:** bajar el ruido del gyro 20× no cambió nada; subir su ancho de banda mejoró 6×. El error era **retardo de fase, no ruido**.
**Causa raíz:** los pasa-bajos de IMU y transductor estaban en la simulación de señales, pero `H` apuntaba directo a `ω_C`/`T_AC` como si la medición fuera instantánea.
**Solución:** estados `gyro_filt`/`strain_filt` que modelan el pasa-bajos (§6.1). Se mantiene en la versión actual.
**Resultado:** `omega_C` de ~0 % a ~94 % (confirmado en la corrida actual: 94.4 %).
**Lección:** todo sensor con retardo apreciable frente a la dinámica de interés debe modelarse así.

### 12.5 "Ancho de banda del Kalman"
Se exploró resumir el desempeño con los polos de `(I−KH)·A`. Es válido como concepto, pero mezclar polos rápidos (mecánica) con lentos (sesgos) no produce una cifra útil. Se evalúa con RMSE de seguimiento.

### 12.6 Cambios de arquitectura relevantes
- **Instrumentación:** transductor propio en lugar del FT05 comercial; Hall en lugar de encoders (ruido 0.002 vs 0.001 rad).
- **Estados:** de 12 a 14 (sesgos propios para IMU y transductor); luego los sesgos pasaron a Gauss-Markov y a unidades de corriente.
- **Control:** de leer el estado verdadero a leer la estimación del Kalman, con objetivo en la posición de C.
- **Seguridad:** fail-safes de ángulo, velocidad y torque.
- **Código:** de un solo archivo a módulos (§13); `ss`/`c2d` en lugar de matriz aumentada con `expm` para la planta; ganancia de Kalman estacionaria precalculada.
- **Física de la IMU:** excentricidad radial y g-sensitivity.

### 12.7 Evolución del modelo (resumen)
1. **Un disco (1 GDL):** `J·θ'' + c·θ' + k·θ = T`, aterrizado a una pared. Valida la arquitectura de fusión (strain gauge + IMU).
2. **Dos discos (2 GDL), libre-libre:** aparece el modo rígido a 0 Hz y el modo de torsión `fn = sqrt(k·(1/J_A + 1/J_B))/(2π)`. Hallazgo: con dos IMUs (una por rotor) y un strain gauge, `T_A ≠ T_B` es separable; con una sola IMU en el eje, no.
3. **Tres discos (configuración final, §3).**

---

## 13. Estructura del código y cómo ejecutarlo

| Archivo | Contenido |
|---|---|
| `main.m` | Orquesta la corrida: `clc; clear; close all;` y llama a los 5 pasos en orden |
| `paso1_parametros_sistema.m` | Parámetros mecánicos y eléctricos, IMU excéntrica, frecuencias naturales, anchos de banda, parámetros de sesgo Gauss-Markov |
| `paso2_perfiles_y_deriva.m` | Tiempo de simulación, perfil de `T_A_ref`, constantes del driver y térmica |
| `paso3_modelo_y_kalman.m` | Planta de 6 estados, modelo de 14 estados, `H`, `Q`, `R`, ruido y sesgos de sensores, constantes de los filtros de sensor, observabilidad, ganancia estacionaria |
| `paso4_bucle_simulacion.m` | Bucle principal: fail-safes, PID de B (vía Kalman), planta, generación de sensores, actualización del Kalman |
| `paso5_graficos_y_metricas.m` | 4 figuras, RMSE y mejora por variable, evaluación de ancho de banda, estado de fail-safes |

**Cómo ejecutar:** correr `main.m`. Los pasos comparten el workspace y dependen unos de otros: no se pueden ejecutar de forma aislada ni en otro orden.

**Requisitos:** Control System Toolbox (`ss`, `c2d`, `obsv`); la función `rmse` (verificar de qué toolbox viene en tu versión de MATLAB); `xline` (R2018b o posterior).

**Figuras generadas:**
1. Torque de Motor A y B: real, "solo corriente" y Kalman.
2. Flexión torsional de los dos tramos del eje (`Δθ_AC`, `Δθ_CB`).
3. Cinemática de la aleta C: `θ_C` (sin sensor) y `ω_C` (real, IMU, Kalman).
4. Seguimiento de los cuatro sesgos Gauss-Markov (real vs. estimado).

**Métricas:** "RMSE crudo" es el RMSE entre la salida filtrada del sensor (convertida a la variable física) y la verdad. "RMSE Kalman" es el de la estimación. "Mejora" = (crudo − Kalman)/crudo. Se omiten las variables sin sensor directo.

**Notas sobre textos del script:** algunas etiquetas de `paso5` dicen "Estimación Kalman de Kt y Bias" y "Solo corriente (Kt nominal)"; el filtro no estima `Kt`, estima un sesgo aditivo de corriente. Conviene corregir esas etiquetas para que coincidan con este documento.
