# Matriz de Casos CFD — Fase B1 (Definición de casos de simulación)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Propuesta de trabajo, **no cerrada**. Depende de dos confirmaciones pendientes con los profesores guía (reunión 28/08/2026): (a) si el ángulo se parametriza como único o como AoA+deflexión separados, y (b) si se fija una única altitud de referencia o se representan varias. Este documento asume, como hipótesis de trabajo, la opción más simple de cada una (ángulo único, nivel del mar) — **no las da por confirmadas**.

**Documentos relacionados:** `01_Cronograma.md` (Fase B, ruta crítica), `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md`, `04_CFD/00_XFLR5/02_Valores_Referencia_XFLR5.md`, `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-REN-01), `02_Requisitos_Funcionales.md` (RF-CFD-02), `00_Administración/02_Registro_Reuniones_Avance.md`.

---

## 1. Objetivo

Definir el conjunto concreto de corridas CFD (Fase B, OpenFOAM) necesarias para generar la tabla de carga, minimizando el número de simulaciones sin dejar de cubrir las tres dimensiones acordadas en el Avance I (Mach, ángulo, velocidad angular de deflexión). Un factorial completo ingenuo (p. ej. 3 Mach × 7 ángulos × 5 velocidades angulares = 105 corridas) es inviable frente al presupuesto de 21 días de la Fase B (`01_Cronograma.md`) — la literatura de Tema 1 (Allen & Ghoreyshi 2018; Ghoreyshi et al. 2010) existe precisamente para evitar ese factorial.

---

## 2. Punto crítico previo: acoplamiento entre la escala (λ) y el Reynolds de la CFD viscosa

A diferencia de XFLR5 (paneles 3D, flujo potencial invíscido — donde `Cm`/`Ch` son independientes del tamaño físico del modelo), la CFD propia es **viscosa**. Esto significa que el número de Reynolds de cada corrida depende de la cuerda física real, es decir, del factor de escala `λ` — que todavía está **pendiente** (rango de trabajo λ≈0.49–0.77, ver `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` §5).

Hay un acoplamiento circular: no se puede fijar la matriz CFD (que necesita Reynolds, que depende de λ) sin antes tener un valor de λ; pero λ se termina de confirmar precisamente verificando que el torque resultante de la CFD caiga en el rango de RNF-CAR-01. **Propuesta para romper el ciclo sin bloquear el cronograma:**

1. Ejecutar la matriz completa a un **λ nominal de partida** = 0.63 (punto medio del rango 0.49–0.77).
2. Verificar, con los primeros resultados, si el torque de bisagra cae dentro de RNF-CAR-01 (~0,5–2 N·m). Si sí, λ=0.63 se confirma y no hay que rehacer nada.
3. Si no cae en rango, **no es necesario rehacer toda la matriz**: dado que a igual Mach el torque escala con `λ³` (Barlow, Rae & Pope, 1999, ya usado en `02_Valores_Referencia_XFLR5.md` §5), se puede reescalar analíticamente el resultado a un λ distinto **siempre que el Reynolds de la corrida original y del λ ajustado no difieran lo suficiente como para cambiar el coeficiente `Cm`/`Ch`** (a diferencia de XFLR5, aquí sí hay que verificar esto, no asumirlo).
4. Recomendación concreta: correr 2–3 puntos de control a distintos Reynolds (equivalentes a λ=0.49 y λ=0.77) **solo para el caso más exigente** (Mach 0.6, β=15°) antes de comprometer toda la matriz al λ nominal — si el coeficiente no cambia significativamente entre esos Reynolds, se valida que el atajo de escalado analítico (paso 3) es aplicable y el resto de la matriz puede correrse a λ=0.63 sin repetir.

**Nota (ampliada tras discutir el efecto de agregar altitud, ver §6.2):** conviene extender este mismo chequeo de sensibilidad a Reynolds para que cubra también el rango de Reynolds asociado a la envolvente de altitud (0–5000 m, `01_Geometria_Aleta_Referencia.md` §3), no solo el rango de λ. Es la misma verificación física (¿`Cm`/`Ch` cambia con Reynolds en este régimen?), y resolverla una sola vez para el rango de Reynolds combinado (λ × altitud) evita tener que repetir el chequeo si la reunión del 28/08 agrega la altitud como variable — ver §6.2 para el impacto en el tamaño de la matriz si este chequeo **no** confirma insensibilidad a Reynolds.

Este paso (verificación de sensibilidad a Reynolds) es, en la práctica, el primer conjunto de corridas a ejecutar, antes de la matriz completa.

---

## 3. Dimensiones de la matriz

| Dimensión | Estado | Rango propuesto | Origen |
|---|---|---|---|
| Mach | Cerrado (alineado con XFLR5 ya validado) | 0,4 / 0,5 / 0,6 | Envolvente de diseño Nalci & Kayran (2014); mismos puntos que `02_Valores_Referencia_XFLR5.md`, permite comparación directa |
| Ángulo total | **Hipótesis de trabajo, pendiente de confirmar 28/08** | 0°, ±5°, ±10°, ±15° | Rango de Nalci & Kayran (±15°); si se confirma que AoA y deflexión deben separarse, esta dimensión se duplica (ver §6) |
| Velocidad angular de deflexión | Nueva (Avance I) — requiere CFD no estacionaria | 0°/s (cuasi-estático), ~100°/s, ~300°/s | ~300°/s es la referencia de diseño bajo torque máximo (Nalci & Kayran 2014, usado en RNF-REN-01) |
| Altitud | **Pendiente (pregunta 5, reunión 28/08)** | Nivel del mar (hipótesis) | Ver `00_Administración/02_Registro_Reuniones_Avance.md` |
| Reynolds / λ | **Pendiente**, ver §2 | λ nominal = 0,63 (a validar) | Acoplamiento con RNF-CAR-01 |

---

## 4. Estrategia de muestreo (para no explotar el número de corridas)

### 4.1 Corridas estáticas (velocidad angular ≈ 0) — caracterizan Mach × ángulo

- **Explotar la antisimetría** ya verificada en XFLR5 (`02_Valores_Referencia_XFLR5.md` §2: error relativo <0,2% en `M(-β)≈-M(β)`) como hipótesis de ahorro: correr solo el lado positivo (0°, 5°, 10°, 15°) por Mach, y verificar con **un único punto negativo de control** (β=-15°) por Mach — no asumir la antisimetría sin verificarla también en régimen viscoso, dado que la separación de flujo puede introducir asimetrías que el flujo potencial no captura.
- Por Mach: 4 puntos principales + 1 punto de verificación = 5 corridas.
- Total estático: **3 Mach × 5 = 15 corridas** (RANS estacionario).

### 4.2 Corridas dinámicas (maniobra forzada) — caracterizan la dependencia con la velocidad angular

En vez de un punto fijo por combinación (Mach, ángulo, velocidad angular) — que sí sería un factorial caro — replicar el enfoque de **maniobra prescrita** de Allen & Ghoreyshi (2018) y Ghoreyshi et al. (2010): una sola corrida no estacionaria, con el ángulo variando en rampa/sinusoide a una tasa controlada, permite extraer la dependencia con la velocidad angular en todo el rango angular barrido, sin repetir una corrida estática por cada punto.

- Por Mach: 2 corridas dinámicas — una a velocidad angular moderada (~100°/s) y una a la velocidad de referencia de diseño (~300°/s), cada una barriendo el rango angular completo (±15°) en una sola corrida tiempo-exacta.
- Total dinámico: **3 Mach × 2 = 6 corridas** (malla móvil, más costosas por corrida que las estáticas).

### 4.3 Total propuesto

| Tipo | N° de corridas | Costo relativo por corrida |
|---|---|---|
| Estáticas (§4.1) | 15 | Bajo (RANS estacionario) |
| Dinámicas (§4.2) | 6 | Alto (malla móvil, no estacionario) |
| Verificación Reynolds/λ (§2) | 2–3 (solo en el caso más exigente) | Medio |
| **Total** | **~23–24** | — |

Comparado con el factorial ingenuo (105 corridas), esta propuesta reduce el número en ~75%, concentrando el costo computacional en las 6 corridas dinámicas — que son, de todas formas, las que aportan la dimensión genuinamente nueva del proyecto (velocidad angular).

---

## 5. Contraste con el cronograma

El cronograma (`01_Cronograma.md`) asigna 21 días a "Ejecución de simulaciones CFD" y ya advierte que es una estimación optimista. Con ~24 corridas, de las cuales 6 son no estacionarias con malla móvil (las más lentas de converger), **21 días es razonable solo si las corridas estáticas convergen rápido** (horas, no días) y las 6 dinámicas no requieren más de 1–2 días cada una. Si el mallado o la convergencia toman más de lo esperado — el riesgo #2 ya identificado en el cronograma —, las 6 corridas dinámicas son las que primero absorberían el atraso. Vale la pena informar esto explícitamente al validar el cronograma con los profesores.

---

## 6. Qué pasa si se confirma que AoA y deflexión deben separarse, y/o se agrega altitud (28/08)

Si en la reunión se determina que el modelo de aleta aislada **sí** requiere distinguir AoA de deflexión (lo que, según `01_Geometria_Aleta_Referencia.md` §6, exigiría modelar el fuselaje — fuera del alcance actual del proyecto), y/o que la altitud debe representarse como variable en vez de fijarse en nivel del mar (pregunta 5, reunión 28/08), esta matriz debe leerse como **provisional**. El efecto sobre el número de corridas es **multiplicativo, no aditivo**, en ambos casos:

### 6.1 Separar AoA y deflexión

"Ángulo total" deja de ser un barrido en línea (5 puntos por Mach en las corridas estáticas) y pasa a ser una **grilla 2D** (AoA × deflexión):

| Puntos de AoA agregados | Estáticas (3 Mach × AoA × 5 deflexión) | Dinámicas (3 Mach × AoA × 2 vel. angular) | Factor vs. matriz actual (§4.3) |
|---|---|---|---|
| 3 (p. ej. -5°, 0°, 5°) | 45 | 18 | ~×2,8 |
| 5 (p. ej. -10° a 10°) | 75 | 30 | ~×4,5 |

### 6.2 Agregar altitud como dimensión

A diferencia de XFLR5 (invíscido, donde la altitud se extiende analíticamente sin nuevas corridas — `03_Pipeline_General_XFLR5.md` §9), en CFD viscosa **el Reynolds depende de la altitud a igual Mach**, por lo que en principio cada altitud nueva exige repetir toda la matriz — un multiplicador tan directo como el de AoA (§6.1).

**Salida análoga a la ya propuesta para λ en §2:** si el chequeo de sensibilidad a Reynolds (§2) se extiende a cubrir también el rango de Reynolds que abarca la envolvente de altitud (0–5000 m, ya registrada en `01_Geometria_Aleta_Referencia.md` §3) y confirma que `Cm`/`Ch` no cambia significativamente en ese rango, la altitud se puede **absorber analíticamente** (igual que λ) con solo 2–3 corridas de verificación adicionales, en vez de duplicar/triplicar toda la matriz. Esto convierte el chequeo de §2 en una decisión que condiciona tanto λ como altitud — vale la pena ampliarlo desde ahora, no tratarlo como dos verificaciones separadas.

### 6.3 Escenarios combinados (referencia rápida para la reunión)

| Escenario | Factor por AoA | Factor por altitud | Total aprox. (vs. ~23-24 de §4.3) |
|---|---|---|---|
| Mínimo — altitud absorbida analíticamente (verificada) | ×2,8 (3 pts. AoA) | ×1 (solo +2-3 corridas de chequeo) | ~65-68 |
| Intermedio — altitud como 2 puntos completos | ×2,8 (3 pts. AoA) | ×2 | ~129 |
| Máximo — altitud como 3 puntos completos | ×4,5 (5 pts. AoA) | ×3 | ~317 |

La brecha entre "altitud absorbida" y "altitud completa" (65 vs. 317) es mucho mayor que la que introduce por sí sola la separación de AoA/deflexión — el resultado del chequeo de Reynolds extendido (§2/§6.2) es, en la práctica, la decisión individual que más determina el tamaño final de la matriz.

**Este documento no intenta anticipar la matriz extendida definitiva** — se actualizará con los valores concretos de AoA/altitud una vez resueltas ambas preguntas en la reunión del 28/08.

---

## 7. Impacto sobre otros documentos del proyecto

| Documento | Impacto |
|---|---|
| `01_Cronograma.md` | Esta propuesta (~23–24 corridas) da un número concreto para validar o ajustar la duración de 21 días asignada a la Fase B |
| `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` §5 | El paso de verificación de sensibilidad a Reynolds (§2 de este documento) es el primer paso concreto para cerrar λ |
| `00_Administración/02_Registro_Reuniones_Avance.md` | Las preguntas 1, 2 y 5 ya registradas siguen siendo las que condicionan si esta matriz se mantiene o se extiende (§6) |
| `03_Requisitos_No_Funcionales.md` (RNF-CAR-01) | El resultado de la verificación de sensibilidad a Reynolds (§2) es la primera confirmación real de si λ=0,63 es válido |

---

## 8. Próximos pasos

1. Confirmar con los profesores (28/08) las dos preguntas abiertas (ángulo único vs. AoA+deflexión; altitud única vs. múltiple) antes de comprometer la malla definitiva.
2. Ejecutar las 2–3 corridas de verificación de sensibilidad a Reynolds (§2) como primer paso, antes de la matriz completa.
3. Confirmar λ=0,63 como valor nominal, o ajustar según el resultado del paso anterior.
4. Ejecutar las 15 corridas estáticas (§4.1).
5. Ejecutar las 6 corridas dinámicas (§4.2), dejando margen en el cronograma dado que son las de mayor riesgo de atraso (§5).
6. Actualizar este documento con el número final de corridas ejecutadas y cualquier ajuste al esquema de muestreo.

---

## 9. Referencias citadas en esta propuesta

- Allen, J. D., Ghoreyshi, M., Jirasek, A., & Satchell, M. (2018). *Aerodynamic Loads Identification and Modeling of UCAV Configurations with Control Surfaces Using Prescribed CFD Maneuvers.* AIAA Paper 2018-2999. DOI: 10.2514/6.2018-2999
- Ghoreyshi, M., Vallespin, D., Da Ronch, A., Badcock, K. J., Vos, J., & Hitzel, S. (2010). *Simulation of Aircraft Manoeuvres Based on Computational Fluid Dynamics.* AIAA Atmospheric Flight Mechanics Conference. DOI: 10.2514/6.2010-8239
- Barlow, J. B., Rae, W. H., & Pope, A. (1999). *Low-Speed Wind Tunnel Testing* (3rd ed.). John Wiley & Sons.
- Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA 2014-2055. DOI: 10.2514/6.2014-2055
