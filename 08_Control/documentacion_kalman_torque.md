# Estimación de Torque vía Fusión Sensorial (Filtro de Kalman)
### Documentación técnica — Banco de Ensayo de Actuadores de Superficie de Control

**Contexto:** este documento cubre el subsistema de estimación de torque del banco de ensayo, desarrollado como parte de la Memoria de Título. El objetivo es estimar el torque que ejerce cada motor (carga aerodinámica emulada y actuador bajo prueba), el torque transmitido por el acople, y el estado angular del conjunto eje/aleta, combinando múltiples sensores mediante un Filtro de Kalman en vez de confiar en una sola medición.

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

---

## 2. Instrumentación

| Sensor | Mide | Ubicación |
|---|---|---|
| Encoder | Ángulo absoluto (`θ_A`, `θ_B`) | Un motor, sin deriva |
| Sensor de corriente + `Kt` | Torque (`T = Kt·I`) | Un motor, cada uno |
| IMU (gyro) | Velocidad angular relativa del acople (`ω_A - ω_B`, o solo `ω_C` según la variante) | Eje de acople / C |
| Transductor de torque **Forsentek FT05** (0–5 Nm) | Torque elástico directo (`T_AC`) | Tramo A-C |

**Sobre el FT05 (dato real de fabricante, no supuesto):** es un puente de strain gauges *pasivo* (salida 1.0 mV/V) — el fabricante no publica un ancho de banda propio; el límite real lo impone la electrónica de acondicionamiento (amplificador + filtro anti-aliasing) que se diseñe, no el transductor. Specs de precisión usadas para el modelo de ruido:
- No-repetibilidad: ±0.1% R.O. → **0.005 Nm** (modelo 5 Nm) — usado como ruido de medición (R)
- No-linealidad: ±0.2% R.O. → 0.01 Nm — es un error **sistemático** (no ruido blanco); se documenta pero no se modela como R (mismo patrón que el sesgo de `Kt`, ver §4.3)

**Decisión de diseño documentada:** el strain gauge/transductor se ubicó en el tramo A-C únicamente. `θ_C` y `T_CB` (tramo C-B) **no tienen sensor directo** — se infieren completamente del modelo. Justificación: se confirmó con el usuario que la aleta nunca recibe carga externa propia, por lo que el sistema es observable sin instrumentar ambos tramos. Si en algún momento la aleta pudiera recibir carga externa (ej. aerodinámica directa sobre C), un segundo strain gauge en C-B sería necesario, no opcional (con solo un tramo medido, un torque externo no modelado en C es indistinguible de un error de calibración de `k`/`c`).

---

## 3. Arquitectura del Filtro de Kalman (evolución)

### 3.1 Motivación de cada bloque de estados
El diseño final usa **12 estados**:

```
x = [θ_A, ω_A, θ_C, ω_C, θ_B, ω_B, T_A, T_B, biasA, biasB, gyro_filt, strain_filt]
```

| Bloque | Estados | Por qué existe |
|---|---|---|
| Mecánico | `θ_A,ω_A,θ_C,ω_C,θ_B,ω_B` | Ecuación de Newton exacta del sistema de 3 discos |
| Torque | `T_A, T_B` | Incógnitas a estimar; modelo de paseo aleatorio (no se conocen a priori) |
| Sesgo de calibración | `biasA, biasB` | Deriva de `Kt` (ver §4.3) — el sensor de corriente por sí solo no puede detectarla |
| Retardo de sensor | `gyro_filt, strain_filt` | Compensar el pasa-bajos físico de la IMU y el transductor (ver §4.4) — **el hallazgo más importante de esta etapa** |

Cada sensor mide exactamente la combinación de estados que le corresponde físicamente (matriz `H`), no un "torque genérico":

- Encoder A → `θ_A` · Encoder B → `θ_B`
- Corriente A → `T_A + biasA` · Corriente B → `T_B + biasB`
- IMU → `gyro_filt` (versión retrasada de `ω_C`, no `ω_C` directo)
- Transductor → `strain_filt` (versión retrasada de `T_AC`, no `T_AC` directo)

### 3.2 Discretización
Se usa `expm(A·dt)` (matriz exponencial, discretización **exacta**), no la aproximación de Euler (`I + A·dt`). Con el modo local de C en el orden de cientos de Hz, Euler dejó de ser numéricamente estable a los `dt` usados; `expm` es estable sin importar el paso de tiempo.

---

## 4. Problemas encontrados y su resolución (bitácora técnica)

Documentado en detalle porque el proceso de depuración es en sí mismo parte del aporte metodológico del trabajo.

### 4.1 Explosión numérica por modo de cuerpo rígido
**Síntoma:** con solo fricción de rodamiento, `θ`/`ω` del sistema libre-libre alcanzaban miles de rad y rad/s.
**Causa:** un desbalance sostenido de torque (`T_A ≠ T_B`) se integra sin límite en el modo de cuerpo rígido (0 Hz, sin resorte a tierra).
**Solución real:** no fue agregar switches de fin de carrera (protección de emergencia, no debería activarse en operación normal) — fue reconocer que Motor B necesita un **lazo de control de posición real** (PID), no un perfil de torque abierto e independiente de la posición.

### 4.2 Inestabilidad del lazo de control (error de signo)
**Síntoma:** el sistema explotaba a valores como `10^302` incluso con ganancias muy conservadoras.
**Diagnóstico:** se armó la matriz de estado completa en lazo cerrado (mecánica + retardo del driver + PID, 8×8) y se calcularon sus autovalores — equivalente numérico de un root locus. La parte real de un polo crecía **linealmente con `Kp`** desde el primer valor probado — firma característica de error de signo, no de mala sintonía.
**Causa real:** en la ecuación de Newton, `T_B` entra como `-T_B` (B "resiste"); el controlador no respetó esa convención, resultando en realimentación positiva.
**Ganancias finales** (verificadas por barrido de miles de combinaciones vía autovalores): `Kp=2, Ki=2, Kd=0.1` — ancho de banda nominal ~13 Hz, ~5× por debajo de `fn1` (69.2 Hz).

### 4.3 Deriva térmica de `Kt` — motivación para el sesgo de calibración
**Hipótesis del usuario:** el modelo `T=Kt·I` es exacto en la simulación; en la realidad `Kt` se degrada con la temperatura, y ahí la fusión debería mostrar una ventaja real sobre "solo corriente" que la simulación idealizada no capturaba.
**Implementación:** modelo de calentamiento simple (proxy de `I²` con constante de tiempo térmica) degradando `Kt` real hasta 8%; la estimación "solo corriente" sigue usando `Kt` nominal (no puede saber la degradación real). Se agregaron estados `biasA`/`biasB` (paseo aleatorio **mucho más lento** que `T_A`/`T_B`, para no confundir deriva de calibración con cambio real de torque).
**Resultado:** mejoras de 70-95% del Kalman sobre "solo corriente" una vez presente la deriva — confirmando la hipótesis.
**Efecto colateral explicado:** Motor A (lazo abierto) muestra sesgo que se estabiliza cuando el calentamiento satura; Motor B (lazo cerrado) muestra corriente **creciente**, porque el controlador compensa la pérdida de `Kt` con más corriente para sostener el mismo torque real — patrón real de "corriente creciente como indicador de desgaste de actuador".
**Nota de escala de tiempo:** la constante térmica usada (10 s) es una versión acelerada, no física (constantes reales de bobinados son de minutos) — necesaria para que el efecto sea visible en una ventana de simulación corta; documentado explícitamente como tal en el código.

### 4.4 `omega_C` no mejoraba con Kalman — el hallazgo más importante
**Síntoma:** el RMSE de `omega_C` prácticamente no bajaba al fusionar (~0.4% de mejora).
**Primer diagnóstico (descartado):** se sospechó mala sintonía de `Q`. Se barrió `q_omega` en 7 órdenes de magnitud — el RMSE se mantuvo plano. Se descartó como problema de sintonía.
**Segundo diagnóstico (correcto):** se comparó el efecto de (a) bajar el ruido del gyro 20× — sin cambio — vs (b) subir su ancho de banda — mejora de 6×. Eso identificó el error como **retardo de fase, no ruido**.
**Causa raíz:** los pasa-bajos de los sensores (IMU, transductor) estaban modelados en la simulación de señales, pero la matriz `H` del Kalman apuntaba directo a `ω_C`/`T_AC`, como si la medición fuera instantánea. El filtro no podía compensar un retardo que no sabía que existía.
**Solución:** estados adicionales `gyro_filt`/`strain_filt` que modelan explícitamente la dinámica del propio pasa-bajos (`y_f' = (x_real - y_f)/τ`), con `H` apuntando a estos estados en vez de a la variable física directa.
**Resultado verificado:** mejora de `omega_C` de ~0% a **~94%**.
**Lección general para el resto del filtro:** cualquier sensor cuya salida pase por un filtro analógico/digital con retardo apreciable frente a la dinámica de interés debería modelarse así — no solo la IMU de C.

### 4.5 "Ancho de banda del Kalman" — qué es y qué no es
Se exploró si tenía sentido resumir el desempeño conjunto de sensores fusionados como un solo "ancho de banda del estimador" vía los polos de la matriz de lazo cerrado del observador (`(I-KH)·A`). **Conclusión:** es válido como concepto, pero mezclar en una sola cifra los polos rápidos (mecánica) con los deliberadamente lentos (deriva de `Kt`) no produce un número honesto ni útil. La forma correcta de evaluar si la fusión en C tiene ancho de banda adecuado es el RMSE de seguimiento (§4.4), no un polo aislado de una lista mixta.

---

## 5. Regla heurística de ancho de banda (versión final)

Regla usada en vez de análisis espectral (por decisión de alcance del proyecto): comparar cada ancho de banda de hardware contra la frecuencia natural relevante, con margen ≥5×. Refinada para distinguir tres categorías en vez de comparar todo contra el modo más exigente:

| Categoría | Referencia | Razonamiento |
|---|---|---|
| Actuación (driver) | Ancho de banda del lazo de control (~13 Hz), no `fn_max` | No se intenta excitar ni `fn1` ni `fn2` directamente; solo hace falta soportar el lazo de posición diseñado |
| Sensores en los extremos (encoders, corriente) | `fn1` (69.2 Hz) | Al estar en A/B (masas grandes), son poco sensibles al modo local de C |
| Sensores en C (IMU, transductor) | Evaluación conjunta vía RMSE de seguimiento, no BW individual | Ver §4.4 y §4.5 — la fusión con retardo modelado no queda limitada al menor de los dos sensores por separado |

**Resultado de la evaluación con los parámetros finales:** driver, encoders y filtro de corriente satisfacen el margen 5× sin problema; el transductor/IMU de C se evalúan por desempeño de la fusión, no por BW aislado, y esa fusión sí resuelve la dinámica rápida una vez modelado el retardo de sensor.

---

## 6. Métricas finales (referencia)

Con la configuración final (ganancias PID corregidas, deriva de `Kt` activa, retardo de sensores modelado):

- **T_A, T_B:** mejora sustancial del Kalman sobre "solo corriente" (70-95%) — atribuible casi enteramente a la corrección de la deriva de `Kt`, no a suavizado de ruido (el sensor de corriente ya es preciso por sí solo cuando `Kt` es exacto).
- **T_AC (torque transmitido, con sensor directo):** mejora fuerte y consistente en todas las iteraciones (~85-95%) gracias al FT05 (más preciso que el valor de ruido inicial supuesto) y al modelo de retardo.
- **T_CB (sin sensor directo):** completamente inferido; su RMSE valida indirectamente la calidad del modelo mecánico.
- **θ_C, ω_C:** con el retardo de sensor modelado, ambos mejoran sustancialmente (`ω_C`: ~94%); antes de ese fix, la mejora era casi nula pese a sintonía correcta de `Q`/`R`.

---

## 7. Recomendaciones para la implementación física

1. **Diseñar la electrónica de acondicionamiento del FT05** con un ancho de banda deliberado (no hay límite de fábrica) — coherente con si se quiere resolver `fn1` únicamente o también el modo local de C (`fn2`).
2. **Caracterizar el retardo real de cada cadena de sensor** (constantes de tiempo de amplificadores/filtros anti-aliasing reales) y modelarlas explícitamente en el Kalman como se hizo en §4.4 — es la mejora de mayor impacto encontrada en todo este proceso.
3. **Verificar el signo de la convención de torque** de cualquier lazo de control antes de probarlo en el banco físico (§4.2) — un análisis de autovalores en lazo cerrado es rápido de hacer y evita comportamiento inestable en hardware real.
4. **Considerar un segundo transductor de torque en el tramo C-B** si existe cualquier posibilidad de que la aleta reciba carga externa propia (no solo transmitida desde los motores) — con un solo tramo instrumentado, esa situación sería indistinguible de un error de calibración mecánica.
5. **Validar la constante térmica real** de los motores elegidos si se quiere usar la detección de deriva de `Kt` (`biasA`/`biasB`) en el banco físico — el valor usado en la simulación es acelerado para fines de demostración, no una medición real.

---

## 8. Archivo de referencia

Script MATLAB: `simulacion_torsion_tres_discos.m` — implementa el modelo de 3 discos, el controlador PID de Motor B, la deriva térmica de `Kt`, y el Kalman de 12 estados descritos en este documento. Comentado en línea con las mismas justificaciones de esta documentación.
