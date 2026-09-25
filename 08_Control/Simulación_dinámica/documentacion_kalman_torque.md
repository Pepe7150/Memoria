# Estimación de Torque vía Fusión Sensorial (Filtro de Kalman)
### Documentación técnica — Banco de Ensayo de Actuadores de Superficie de Control

**Contexto:** este documento cubre el subsistema de estimación de torque del banco de ensayo, desarrollado como parte de la Memoria de Título. El objetivo es estimar el torque que ejerce cada motor (carga aerodinámica emulada y actuador bajo prueba), el torque transmitido por el acople, y el estado angular del conjunto eje/aleta, combinando múltiples sensores mediante un Filtro de Kalman en vez de confiar en una sola medición.

**Estado de este documento:** actualizado tras el cambio de instrumentación (transductor propio en vez de FT05 comercial, sensores Hall en vez de encoders) y la refactorización del código a módulos separados con fail-safes de seguridad.

---

## 1. Evolución del modelo mecánico

El sistema se modeló de forma incremental, de menor a mayor complejidad, verificando en cada etapa antes de avanzar.

### 1.1 Un disco (1 GDL) — validación del enfoque base
Disco con inercia `J_total` unido por un eje elástico a una pared fija (referencia inercial):

```
J·θ'' + c·θ' + k·θ = T
```

Al estar aterrizado a una pared, el sistema es intrínsecamente estable sin necesitar amortiguamiento adicional ni control — sirvió para validar la arquitectura de fusión (Strain Gauge + IMU) antes de escalar a un sistema más realista.

### 1.2 Dos discos (2 GDL) — motores antagónicos
Motor A (aplica la carga) y Motor B (resiste/vence) unidos por el eje de acople, **sin nada atado a tierra**:

```
J_A·θ_A'' + c·(θ_A'-θ_B') + k·(θ_A-θ_B) = T_A
J_B·θ_B'' + c·(θ_B'-θ_A') + k·(θ_B-θ_A) = -T_B
```

Al ser un sistema **libre-libre**, aparece un modo de cuerpo rígido a 0 Hz (nada impide que el conjunto rote en bloque) además del modo de torsión relativa:

```
fn_twist = sqrt(k·(1/J_A + 1/J_B)) / (2π)
```

**Hallazgo importante:** con dos IMUs (una por rotor) y un strain gauge en el acople, el sistema es observable y `T_A`≠`T_B` se puede separar — con una sola IMU en el eje, no (el acople rígido no "delata" cuánto aporta cada lado; se necesita compliance + mediciones en ambos extremos).

### 1.3 Tres discos (2 GDL elásticos + 1 rígido) — configuración final
Motor A — eje/aleta (C) — Motor B, con dos tramos de resorte (`k1` entre A-C, `k2` entre C-B, cada uno con el doble de rigidez del eje completo por ser de mitad de longitud):

```
J_A·θ_A'' + c1·(θ_A'-θ_C') + k1·(θ_A-θ_C) = T_A
J_C·θ_C'' + c1·(θ_C'-θ_A') + k1·(θ_C-θ_A) + c2·(θ_C'-θ_B') + k2·(θ_C-θ_B) = 0
J_B·θ_B'' + c2·(θ_B'-θ_C') + k2·(θ_B-θ_C) = -T_B
```

Frecuencias naturales (vía `eig(K,M)` con `K`/`M` de 3×3, no fórmula cerrada porque el sistema no es simétrico):

| Modo | Frecuencia | Descripción |
|---|---|---|
| Rígido | 0 Hz | Todo el conjunto rota en bloque, sin torsión interna |
| fn1 | **69.2 Hz** | Modo dominante: A y B se mueven de forma significativa (el que de verdad excitan los motores) |
| fn2 | **265.6 Hz** | Modo local de C (por `J_C` pequeño): A y B casi no se mueven, la aleta vibra sola |

"Dominante" no significa que fn2 sea menos real — significa que la forma en que se excita el sistema (torque en A y B, no en C) le mete mucha más energía a fn1 que a fn2.

**Nota de implementación (DRY):** la relación entre el vector de estado mecánico y los torques transmitidos se centralizó en una sola matriz reutilizable:

```
C_torque = [ k1,  c1, -k1, -c1,   0,   0;
              0,   0,  k2,  c2, -k2, -c2]

[T_AC; T_CB] = C_torque * [θ_A; ω_A; θ_C; ω_C; θ_B; ω_B]
```

Se usa igual en la planta real, en el Kalman y en la generación de la señal del transductor — evita tener la misma fórmula repetida (y potencialmente inconsistente) en varios lugares del código.

---

## 2. Instrumentación

**Cambio de instrumentación respecto a la versión anterior de este documento:** se descartó el transductor comercial Forsentek FT05 por costo, y los encoders se reemplazaron por sensores de efecto Hall. Tabla actualizada:

| Sensor | Mide | Ubicación | Notas |
|---|---|---|---|
| Efecto Hall + anillo magnético | Ángulo absoluto (`θ_A`, `θ_B`) | Motor A, Motor B | Reemplaza a los encoders. Ruido de medición: `0.002` (antes `0.001` con encoder) |
| Sensor de corriente + `Kt` | Torque (`T = Kt·I`) | Un motor, cada uno | Sin cambios |
| IMU (gyro) | Velocidad angular de C (`ω_C`) | En C | Sin cambios |
| **Transductor de torque propio** (tubo + strain gauges) | Torque elástico directo (`T_AC`) | Tramo A-C, en línea con el eje | Reemplaza al FT05 comercial |

### 2.1 Transductor de torque propio (reemplaza al FT05)
Se descartó el FT05 comercial por precio. En su lugar se está construyendo un transductor propio: una sección de tubo acoplada en línea al eje, con strain gauges pegados directamente sobre ella (puente de Wheatstone a armar, en vez de un puente ya calibrado de fábrica).

**Implicancia para la documentación de diseño:** al ser un transductor propio, ya no aplican directamente las especificaciones de fábrica del FT05 que se usaron antes (no-repetibilidad ±0.1% R.O., etc.) — esos números deben re-derivarse una vez que el transductor esté construido y calibrado (ej. mediante ensayos de carga conocida y ajuste de curva). El ruido de medición usado en la simulación actual (`noise_strain_std = 0.005`) sigue siendo el valor heredado del FT05 como marcador de posición razonable, pero **debe reemplazarse por datos de calibración reales del transductor propio** antes de usarse para dimensionar el filtro en el banco físico.

Sigue aplicando el mismo punto sobre ancho de banda que con el FT05: un puente de strain gauges pasivo no tiene un ancho de banda "de fábrica" — lo determina la electrónica de acondicionamiento (amplificador + filtro anti-aliasing) que se diseñe, ahora con más razón porque es un diseño propio de punta a punta.

### 2.2 Sensores de efecto Hall (reemplazan a los encoders)
Miden la posición angular absoluta de cada motor (`θ_A`, `θ_B`) leyendo un anillo con imanes solidario al eje — mismo rol funcional que cumplían los encoders antes (posición absoluta, sin deriva), pero por tecnología distinta. Ancho de banda de acondicionamiento: `bw_hall = 500 Hz` (mismo valor numérico que tenía `bw_encoder`).

**Calibración estática modelada:** en el código actual, cada Hall tiene un sesgo de montaje/fabricación fijo (`bias_hallA = 0.05`, `bias_hallB = -0.03`) que se resta explícitamente antes de filtrar (`thA_cal = thA_raw - bias_hallA`) — representa una calibración de fábrica/instalación ya conocida y corregida, por lo que **no** tiene un estado de sesgo dedicado en el Kalman (a diferencia de corriente, IMU y transductor — ver §3). Si en la práctica ese sesgo no se conoce con precisión o puede derivar con el uso, habría que tratarlo igual que los demás (con estado de sesgo estimado en línea), no como una constante restada.

### 2.3 Decisión de diseño que se mantiene: instrumentación de un solo tramo
El strain gauge/transductor sigue ubicado en el tramo A-C únicamente. `θ_C` y `T_CB` (tramo C-B) **no tienen sensor directo** — se infieren completamente del modelo. Justificación (confirmada con el usuario): la aleta nunca recibe carga externa propia, por lo que el sistema es observable sin instrumentar ambos tramos. Si eso cambiara, un segundo transductor en C-B sería necesario, no opcional (con solo un tramo medido, un torque externo no modelado en C es indistinguible de un error de calibración de `k`/`c`).

---

## 3. Arquitectura del Filtro de Kalman (evolución)

### 3.1 Motivación de cada bloque de estados
El diseño actual usa **14 estados** (antes 12 — se agregaron sesgos dedicados para IMU y transductor):

```
x = [θ_A, ω_A, θ_C, ω_C, θ_B, ω_B,   T_A, T_B,   gyro_filt, strain_filt,   biasIA, biasIB, biasIMU, biasSG]
     |--------- mecánico (1-6) ---|  |7-8|       |---- 9-10 ----------|   |----------- 11-14 -----------|
```

| Bloque | Estados | Por qué existe |
|---|---|---|
| Mecánico | `θ_A,ω_A,θ_C,ω_C,θ_B,ω_B` | Ecuación de Newton exacta del sistema de 3 discos |
| Torque | `T_A, T_B` | Incógnitas a estimar; modelo de paseo aleatorio (no se conocen a priori) |
| Retardo de sensor | `gyro_filt, strain_filt` | Compensar el pasa-bajos físico de la IMU y el transductor (ver §4.4) — **el hallazgo de mayor impacto de esta etapa** |
| Sesgo de corriente | `biasIA, biasIB` | Deriva de `Kt` (ver §4.3) — el sensor de corriente por sí solo no puede detectarla |
| Sesgo de IMU y transductor | `biasIMU, biasSG` | **Nuevo:** antes solo se modelaba sesgo en los canales de corriente; ahora también se estima un sesgo propio de montaje/calibración para la IMU y el transductor, en vez de asumir que llegan sin sesgo |

Cada sensor mide exactamente la combinación de estados que le corresponde físicamente (matriz `H`):

- Hall A → `θ_A` (con sesgo ya calibrado/restado antes de entrar al filtro, ver §2.2)
- Hall B → `θ_B` (ídem)
- Corriente A → `T_A + biasIA`
- Corriente B → `T_B + biasIB`
- IMU → `gyro_filt + biasIMU` (versión retrasada de `ω_C`, más su propio sesgo)
- Transductor → `strain_filt + biasSG` (versión retrasada de `T_AC`, más su propio sesgo)

### 3.2 Discretización
La planta real (`Ac6`/`Bc6`) ahora se discretiza con las funciones del Control System Toolbox (`ss(...)`, `c2d(..., 'zoh')`) en vez del truco manual de matriz aumentada con `expm` usado antes — mismo resultado (discretización exacta con entrada, ZOH), código más simple al asumir que el toolbox está disponible. El modelo interno del Kalman (`Ac14`, sin entrada conocida) se sigue discretizando con `expm(Ac14*dt_sim)` directamente, que sigue siendo la forma correcta para eso.

### 3.3 Verificación formal de observabilidad (nuevo)
Se agregó una verificación explícita con `obsv()`:

```matlab
O_mat = obsv(Adk, H);
rank_O = rank(O_mat);
cond_O = cond(O_mat);
```

Esto reemplaza el razonamiento informal que se venía haciendo a mano (§1.2: "con una sola IMU no es observable, con dos sí") por una comprobación numérica directa cada vez que cambian los parámetros del modelo — recomendado revisar `rank_O == nx` (observabilidad completa) y vigilar que `cond_O` no crezca de forma descontrolada (mala condición numérica, señal de que algún estado es casi indistinguible de otro incluso si el rango es completo).

### 3.4 Ganancia de Kalman en régimen permanente, precalculada (nuevo)
En vez de recalcular la ecuación de Riccati (predicción + corrección de covarianza) en cada paso de los 20 segundos de simulación, la ganancia `K` se itera hasta convergencia **una sola vez, antes del bucle principal** (500 iteraciones de la ecuación de Riccati), y esa ganancia fija (`K_kalman_steady`) es la que se usa dentro del bucle:

```matlab
for iter = 1:500
    P_pred = Adk*P_temp*Adk' + Q;
    S = H*P_pred*H' + R;
    K_kalman_steady = (P_pred*H') / S;
    P_temp = (eye(nx) - K_kalman_steady*H)*P_pred;
end
```

Esto es válido porque `Q`/`R` son constantes en el tiempo (no hay mediciones faltantes ni cambios de sintonía a mitad de simulación) — el filtro converge a una ganancia estacionaria y usarla fija ahorra cómputo significativo en una simulación de 20s a 5kHz (100,000 pasos) sin cambiar el resultado en régimen permanente. **Costo:** se pierde la respuesta transitoria de la ganancia durante el arranque (los primeros pasos, cuando el filtro normalmente "aprende" más rápido con una ganancia más alta) — irrelevante para evaluar desempeño en régimen permanente, pero a tener en cuenta si en algún momento interesa específicamente el comportamiento de arranque del filtro.

---

## 4. Problemas encontrados y su resolución (bitácora técnica)

Documentado en detalle porque el proceso de depuración es en sí mismo parte del aporte metodológico del trabajo.

### 4.1 Explosión numérica por modo de cuerpo rígido
**Síntoma:** con solo fricción de rodamiento, `θ`/`ω` del sistema libre-libre alcanzaban miles de rad y rad/s.
**Causa:** un desbalance sostenido de torque (`T_A ≠ T_B`) se integra sin límite en el modo de cuerpo rígido (0 Hz, sin resorte a tierra).
**Solución real:** reconocer que Motor B necesita un **lazo de control de posición real** (PID), no un perfil de torque abierto e independiente de la posición.

### 4.2 Inestabilidad del lazo de control (error de signo)
**Síntoma:** el sistema explotaba a valores como `10^302` incluso con ganancias muy conservadoras.
**Diagnóstico:** se armó la matriz de estado completa en lazo cerrado (mecánica + retardo del driver + PID) y se calcularon sus autovalores — equivalente numérico de un root locus. La parte real de un polo crecía **linealmente con `Kp`** desde el primer valor probado — firma característica de error de signo, no de mala sintonía.
**Causa real:** en la ecuación de Newton, `T_B` entra como `-T_B` (B "resiste"); el controlador no respetó esa convención, resultando en realimentación positiva.
**Ganancias verificadas en esa etapa:** `Kp=2, Ki=2, Kd=0.1` (ancho de banda nominal ~13 Hz, ~5× por debajo de `fn1`).
**⚠️ Pendiente de re-verificación:** las ganancias actuales en el código son `Kp_pos=1, Ki_pos=5, Kd_pos=0.5` — distintas a las últimas verificadas por autovalores. Además, el controlador de B **ahora regula sobre la estimación de C del Kalman** (`x_est(3)`, `x_est(4)`), no sobre el estado verdadero de B como en la versión analizada (ver §4.6, cambio nuevo) — el análisis de autovalores anterior no cubre esta arquitectura. Se recomienda repetir el análisis de estabilidad en lazo cerrado con la configuración actual antes de llevarlo a hardware.

### 4.3 Deriva térmica de `Kt` — motivación para el sesgo de calibración
**Hipótesis del usuario:** el modelo `T=Kt·I` es exacto en la simulación; en la realidad `Kt` se degrada con la temperatura, y ahí la fusión debería mostrar una ventaja real sobre "solo corriente" que la simulación idealizada no capturaba.
**Implementación:** modelo de calentamiento simple (proxy de `I²` con constante de tiempo térmica) degradando `Kt` real hasta 8%; la estimación "solo corriente" sigue usando `Kt` nominal (no puede saber la degradación real). Se agregaron estados de sesgo (paseo aleatorio **mucho más lento** que `T_A`/`T_B`, para no confundir deriva de calibración con cambio real de torque).
**Resultado:** mejoras de 70-95% del Kalman sobre "solo corriente" una vez presente la deriva — confirmando la hipótesis.
**Efecto colateral explicado:** Motor A (lazo abierto) muestra sesgo que se estabiliza cuando el calentamiento satura; Motor B (lazo cerrado) muestra corriente **creciente**, porque el controlador compensa la pérdida de `Kt` con más corriente para sostener el mismo torque real — patrón real de "corriente creciente como indicador de desgaste de actuador".
**Nota de escala de tiempo:** la constante térmica usada (10 s) es una versión acelerada, no física (constantes reales de bobinados son de minutos) — necesaria para que el efecto sea visible en una ventana de simulación corta; documentado explícitamente como tal en el código.

### 4.4 `omega_C` no mejoraba con Kalman — el hallazgo más importante
**Síntoma:** el RMSE de `omega_C` prácticamente no bajaba al fusionar (~0.4% de mejora).
**Primer diagnóstico (descartado):** se sospechó mala sintonía de `Q`. Se barrió `q_omega` en 7 órdenes de magnitud — el RMSE se mantuvo plano. Se descartó como problema de sintonía.
**Segundo diagnóstico (correcto):** se comparó el efecto de (a) bajar el ruido del gyro 20× — sin cambio — vs (b) subir su ancho de banda — mejora de 6×. Eso identificó el error como **retardo de fase, no ruido**.
**Causa raíz:** los pasa-bajos de los sensores (IMU, transductor) estaban modelados en la simulación de señales, pero la matriz `H` del Kalman apuntaba directo a `ω_C`/`T_AC`, como si la medición fuera instantánea. El filtro no podía compensar un retardo que no sabía que existía.
**Solución:** estados adicionales `gyro_filt`/`strain_filt` que modelan explícitamente la dinámica del propio pasa-bajos (`y_f' = (x_real - y_f)/τ`), con `H` apuntando a estos estados en vez de a la variable física directa. Esta solución **se mantiene igual** en la versión actual del código (estados 9-10).
**Resultado verificado:** mejora de `omega_C` de ~0% a **~94%**.
**Lección general:** cualquier sensor cuya salida pase por un filtro analógico/digital con retardo apreciable frente a la dinámica de interés debería modelarse así.

### 4.5 "Ancho de banda del Kalman" — qué es y qué no es
Se exploró si tenía sentido resumir el desempeño conjunto de sensores fusionados como un solo "ancho de banda del estimador" vía los polos de la matriz de lazo cerrado del observador (`(I-KH)·A`). **Conclusión:** es válido como concepto, pero mezclar en una sola cifra los polos rápidos (mecánica) con los deliberadamente lentos (deriva de `Kt`) no produce un número honesto ni útil. La forma correcta de evaluar si la fusión en C tiene ancho de banda adecuado es el RMSE de seguimiento, no un polo aislado de una lista mixta.

### 4.6 Cambio de arquitectura: el control ahora cierra el lazo a través del propio Kalman (nuevo, importante)
**Qué cambió:** en la versión anterior, el controlador PID de Motor B leía el estado **verdadero** de la planta (`x6`, la simulación, no el filtro) para decidir qué torque aplicar — un supuesto "de laboratorio" (acceso a la verdad, no disponible en hardware real). En el código actual, el controlador lee la **estimación del Kalman** (`x_est(3)` = `θ_C` estimado, `x_est(4)` = `ω_C` estimado), y además ahora el objetivo de control es la posición de **C** (`theta_C_target`), no la de B directamente.

**Por qué es un cambio importante:** esto es mucho más representativo de cómo funcionaría el banco físico real — ahí nunca hay acceso al estado verdadero, solo a lo que el filtro estima a partir de los sensores. Es un paso necesario antes de llevar esto a hardware.

**Riesgo nuevo que introduce, no analizado todavía:** ahora el lazo de control y el estimador están acoplados — un error de estimación (especialmente durante el transitorio inicial, antes de que el Kalman converja) se retroalimenta directamente a la planta a través del controlador. El análisis de estabilidad de §4.2 asumía realimentación de estado verdadero; **no cubre esta arquitectura observador+controlador acoplados**. En control clásico esto se relaciona con el principio de separación (que bajo ciertas condiciones lineales garantiza que controlador y observador se pueden diseñar/verificar por separado), pero con la ganancia de Kalman fija en régimen permanente (§3.4) y los fail-safes no lineales (§4.7) activos, esa garantía no aplica automáticamente y debería verificarse explícitamente antes de hardware.

### 4.7 Fail-safes de seguridad (nuevo — resuelve una discusión anterior)
Se agregó una capa de protección explícita, separada del lazo de control normal, que corta torques a cero si se exceden límites físicos:

| Límite | Valor | Acción |
|---|---|---|
| Ángulo | `±135°` (`θ_A` o `θ_B`) | `system_fault = true`, corta torques |
| Velocidad angular | `±1000 RPM` (`ω_A` o `ω_B`) | ídem |
| Torque | `±8.0 Nm` (`T_A`, `T_B`, `T_AC` o `T_CB`) | ídem |

Una vez disparado (`system_fault`), el sistema queda en falla para el resto de la simulación (torques a cero, motor A y B detenidos) y se registra el instante y la causa (`fault_time`, `fault_reason`) — los gráficos marcan ese instante con una línea vertical.

**Esto es exactamente la distinción que se discutió antes:** los switches de fin de carrera son una protección de emergencia, no el mecanismo de control normal — y así es como está implementado ahora: el PID (§4.6) es responsable de mantener el sistema dentro de rango en operación normal, y los fail-safes son una capa aparte que solo actúa si el control falla o el sistema se comporta de forma inesperada. Es el diseño correcto en dos capas.

---

## 5. Regla heurística de ancho de banda (versión final)

Regla usada en vez de análisis espectral (por decisión de alcance del proyecto): comparar cada ancho de banda de hardware contra la frecuencia natural relevante, con margen ≥5×, distinguiendo tres categorías en vez de comparar todo contra el modo más exigente:

| Categoría | Referencia | Razonamiento |
|---|---|---|
| Actuación (driver) | Ancho de banda del lazo de control (`sqrt(Kp_pos/J_B)/(2π)`), no `fn_max` | No se intenta excitar ni `fn1` ni `fn2` directamente; solo hace falta soportar el lazo de posición diseñado |
| Sensores en los extremos (Hall, corriente) | `fn1` (69.2 Hz) | Al estar en A/B (masas grandes), son poco sensibles al modo local de C |
| Sensores en C (IMU, transductor) | Evaluación conjunta vía RMSE de seguimiento, no BW individual | Ver §4.4 y §4.5 — la fusión con retardo modelado no queda limitada al menor de los dos sensores por separado |

**Nota:** con `Kp_pos=1` (valor actual, distinto al `Kp_pos=2` usado cuando se derivó la tabla de resultados de §6), el ancho de banda nominal del lazo de control cambia (`sqrt(1/J_B)/(2π) ≈ 9.2 Hz` en vez de ~13 Hz) — la evaluación de `bw_driver` contra este valor sigue siendo válida en la misma lógica, pero el número debe releerse de la salida actual del script, no asumirse igual al de iteraciones anteriores.

---

## 6. Métricas finales (referencia, última corrida verificada con la arquitectura de §4.6 y §4.7 pendiente de una nueva revisión completa)

Con la configuración usada al cerrar cada etapa de esta bitácora:

- **T_A, T_B:** mejora sustancial del Kalman sobre "solo corriente" (70-95%) — atribuible casi enteramente a la corrección de la deriva de `Kt`, no a suavizado de ruido.
- **T_AC (torque transmitido, con sensor directo):** mejora fuerte y consistente (~85-95%) gracias al modelo de retardo y a un transductor de bajo ruido.
- **T_CB (sin sensor directo):** completamente inferido; su RMSE valida indirectamente la calidad del modelo mecánico.
- **θ_C, ω_C:** con el retardo de sensor modelado, ambos mejoran sustancialmente (`ω_C`: ~94%).

**Nota:** estas cifras se midieron con la arquitectura de control por estado verdadero (antes de §4.6) y con el FT05 (antes de §2.1/§2.2). Deberían re-confirmarse con una corrida de la versión modular actual antes de citarlas como resultado final en el informe de la Memoria.

---

## 7. Recomendaciones para la implementación física

1. **Calibrar el transductor propio** (tubo + strain gauges) con cargas conocidas antes de reemplazar el valor de ruido heredado del FT05 (`noise_strain_std = 0.005`) — ese número ya no describe el sensor que realmente se va a usar.
2. **Diseñar la electrónica de acondicionamiento** (del transductor propio y de los Hall) con un ancho de banda deliberado — ninguno de los dos trae un límite de fábrica que lo defina por ti.
3. **Caracterizar el retardo real de cada cadena de sensor** y modelarlo explícitamente en el Kalman como en §4.4 — sigue siendo la mejora de mayor impacto encontrada en todo este proceso.
4. **Re-verificar la estabilidad del lazo de control con autovalores** (§4.2) usando las ganancias actuales (`Kp=1, Ki=5, Kd=0.5`) **y** la arquitectura observador-en-el-lazo de §4.6 — el análisis anterior no cubre ninguna de las dos cosas tal como están ahora.
5. **Decidir el criterio de recuperación tras un fail-safe** (§4.7): el código actual deja el sistema en falla permanente por el resto de la simulación una vez disparado un límite — en el banco físico probablemente se necesite un procedimiento de reset/rearme explícito, no solo detección.
6. **Considerar un segundo transductor de torque en el tramo C-B** si existe cualquier posibilidad de que la aleta reciba carga externa propia — con un solo tramo instrumentado, esa situación sería indistinguible de un error de calibración mecánica.
7. **Validar la constante térmica real** de los motores elegidos si se quiere usar la detección de deriva de `Kt` en el banco físico — el valor usado en la simulación es acelerado para fines de demostración.

---

## 8. Estructura del código (modular)

El script se reorganizó de un solo archivo a una secuencia de módulos ejecutados por `main.m`, con el objetivo explícito de facilitar la identificación de errores por etapa y evitar duplicación de código (DRY, ej. la matriz `C_torque` de §1.3 reutilizada en planta, Kalman y sensores):

| Archivo | Contenido |
|---|---|
| `main.m` | Orquesta la corrida completa (`clc;clear;close all;` + llama a los 5 pasos en orden) |
| `paso1_parametros_sistema.m` | Parámetros mecánicos/eléctricos, frecuencias naturales, anchos de banda de hardware |
| `paso2_perfiles_y_deriva.m` | Configuración temporal, perfil de torque de referencia de Motor A, constantes de tiempo de driver y térmica |
| `paso3_modelo_y_kalman.m` | Matrices de planta y del Kalman (14 estados), `H`, `Q`, `R`, análisis de observabilidad, ganancia estacionaria precalculada |
| `paso4_bucle_simulacion.m` | Bucle cerrado de tiempo real: fail-safes, control PID de B (vía estimación del Kalman), planta, generación de sensores, actualización del Kalman |
| `paso5_graficos_y_metricas.m` | Gráficos (marcando el instante de fail-safe si ocurre), RMSE y mejora porcentual por variable, evaluación de ancho de banda |

**Nota:** el reporte de métricas ahora usa la función `rmse()` nativa de MATLAB (Statistics and Machine Learning Toolbox) en vez de una función anónima propia — consistente con el uso de `ss`/`c2d`/`obsv` del Control System Toolbox en `paso3`, asumiendo que ambos toolboxes están disponibles en el entorno de trabajo.
