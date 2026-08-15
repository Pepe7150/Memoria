# Valores de Referencia de Literatura Análoga

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Objetivo de este documento:** proveer, a partir de literatura análoga (bancos de ensayo y simuladores de carga a escala comparable), valores numéricos orientativos para los campos marcados "[a definir]" en `03_Requisitos_No_Funcionales.md`, mientras no se cuenta con datos propios de CFD ni con el actuador de carga finalmente seleccionado.

**Estado:** Valores **preliminares de planificación**, no requisitos cerrados. Deben confirmarse en la etapa de diseño detallado (OE-2/OE-3), una vez definidos el actuador de carga específico (ver `06_Seleccion_Actuador_de_Carga.md`) y el rango de cargas obtenido de la CFD propia del proyecto.

---

## 1. Criterio de selección de la literatura análoga

Se priorizaron fuentes que comparten la escala asumida para el proyecto (torque <10 N·m, superficie de control tipo UAV/misil pequeño) por sobre la literatura de Tema 2 orientada a simuladores de carga electrohidráulicos de gran escala (cientos a miles de N·m), que se mantiene como referencia de método de control pero no de magnitud. La fuente más cercana en escala y objetivo, ya identificada en `resumen_referencias.md` (Tema 2), es:

> **Anastasopoulos, L., & Hornung, M. (2018).** *Design of a Real-Time Test Bench for UAV Servo Actuators.* AIAA AVIATION Forum, AIAA 2018-3735.

Se revisó el texto completo de este trabajo (no solo el resumen ya incluido en la revisión de literatura) específicamente para extraer los valores numéricos de torque, ancho de banda e incertidumbre de instrumentación que reporta, por ser el antecedente que más se aproxima al banco propuesto en este proyecto (motor de carga actuando sobre el eje de charnela de un servoactuador, con sensor de torque, sensor de corriente y encoder).

## 2. Valores extraídos de Anastasopoulos & Hornung (2018)

### 2.1 Rango de torque

| Elemento | Torque continuo | Torque pico |
|---|---|---|
| Actuador UAV bajo prueba (airbrake) | 5,9 N·m | 19,6 N·m |
| Motor de carga (load motor) | 8,4 N·m | 21,3 N·m |

El motor de carga se dimensionó con un margen de aproximadamente 1,1–1,4× sobre el torque continuo/pico del actuador bajo prueba, más un momento de inercia de rotor de 6,2·10⁻⁵ kg·m². Este orden de magnitud (decenas de N·m como techo, unidades a bajas decenas como rango típico de operación) es consistente con la hipótesis de "escala pequeña, <10 N·m" adoptada en `06_Seleccion_Actuador_de_Carga.md`, aunque conviene notar que el torque pico del motor de carga supera ese valor — es decir, **el margen de diseño típico en la literatura análoga excede el valor nominal de operación en 2–4×**.

### 2.2 Sensor de torque (clases disponibles y su incertidumbre)

| Rango del sensor | Incertidumbre reportada | Incertidumbre relativa (% del fondo de escala) |
|---|---|---|
| ±5 N·m | 0,005 N·m | 0,1 % FE |
| ±10 N·m | 0,01 N·m | 0,1 % FE |
| ±20 N·m | 0,02 N·m | 0,1 % FE |

Los tres rangos mantienen consistentemente ≈0,1 % del fondo de escala, un valor de referencia útil para RNF-PRE-02.

### 2.3 Ancho de banda / frecuencias de control

| Señal / lazo | Frecuencia reportada |
|---|---|
| Muestreo cíclico de sensores (torque, corriente, tensión) | 200 Hz (hasta 1000 Hz factible según los autores) |
| Generación de señal de comando al actuador (PPM, vía FPGA) | 333 Hz |
| Lectura de posición (encoder, vía FPGA) | 40 Hz |
| Frecuencias de ensayo transitorio (conmutación de posición) | 2, 4, 6, 8, 10 Hz |
| Escalón de carga estática | incrementos de 1 N·m cada 3 s |

### 2.4 Otras magnitudes de instrumentación reportadas

| Variable | Rango | Incertidumbre |
|---|---|---|
| Corriente eléctrica | ±15 A | 0,12 A (0,8 % FE) |
| Tensión | ±10 V | 0,06 V (0,6 % FE) |
| Posición angular (encoder óptico integrado, Modo A/B) | ±180° | 5,6·10⁻³ ° |
| Posición angular (encoder externo, Modo C) | ±180° | 0,35° |
| Velocidad angular | ±3000 °/s | 8,8·10⁻³ °/s |

## 3. Ancho de banda de control de fuerza/torque en simuladores de carga aerodinámica (Tema 2)

Independientemente de la escala, la literatura de simuladores de carga electrohidráulicos revisada en Tema 2 converge repetidamente sobre un mismo criterio de diseño para el lazo de fuerza/torque, conocido informalmente como **"índice diez-diez" (double-ten index)**: el sistema debe mantener un error de amplitud menor al 10 % y un retardo de fase menor a 10° hasta una frecuencia de referencia de **10 Hz**. Este criterio aparece explícitamente asociado al diseño QFT del lazo de fuerza de Nam (2001) — ya incluido en `resumen_referencias.md`, Tema 2, referencia 7 — y es citado de forma recurrente en trabajos posteriores de la misma línea (Yao et al., Jing et al., Zhao et al., ya incluidos en Tema 2).

Es importante notar que este criterio se reporta consistentemente **tanto en simuladores de gran escala (cientos–miles de N·m) como en el banco de pequeña escala de Anastasopoulos & Hornung** (que usa frecuencias de ensayo de hasta 10 Hz) — es decir, el valor de 10 Hz parece responder más al rango de frecuencias de maniobra aerodinámica relevante (deflexión de superficies de control) que a la magnitud del torque, lo que da cierta confianza para extrapolarlo también al banco de este proyecto.

## 4. Propuesta de valores preliminares para RNF pendientes

| ID | Requisito | Valor propuesto (preliminar) | Justificación / origen |
|---|---|---|---|
| RNF-REN-01 | Frecuencia mínima del lazo de control de torque | **≥ 100–200 Hz** | Margen de ~10–20× sobre el ancho de banda de torque objetivo (10 Hz, "índice diez-diez"), consistente con la frecuencia de muestreo de sensores (200 Hz) reportada por Anastasopoulos & Hornung (2018) para un banco de escala comparable |
| RNF-REN-02 | Latencia máxima medición → actualización de referencia | **≤ 5–10 ms** | Corresponde al período de un lazo ejecutándose a 100–200 Hz; coherente con la arquitectura EtherCAT/FPGA reportada en la misma fuente |
| RNF-PRE-01 | Error de interpolación de la tabla de carga vs. datos CFD originales | **≤ 5 %** (valor conservador; casos favorables en literatura de Tema 1/4 reportan <1 %) | Sinha et al. (2022, Tema 1) reportan errores de interpolación <1 % con un modelo de orden reducido tipo POD para bases de datos aerodinámicas de misiles; se propone 5 % como margen conservador para un primer método de interpolación (p. ej. lineal) antes de optimizar |
| RNF-PRE-02 | Incertidumbre del sistema de medición de torque | **≤ 0,5 % del fondo de escala** (referencia óptima observada: 0,1 % FE) | Basado en las tres clases de sensor de torque reportadas por Anastasopoulos & Hornung (2018); se propone un valor algo más conservador que el óptimo reportado (0,1 %) para dar margen a componentes COTS de menor costo, alineado con RNF-COS-01 |
| RNF-PRE-03 | Resolución del sistema de medición de posición angular | **≤ 0,1°** | Intermedio entre la resolución del encoder integrado en el motor de carga (5,6·10⁻³°, alta gama) y la del encoder externo económico (0,35°) reportados en la misma fuente; valor alcanzable con encoders incrementales COTS de gama media |

**Advertencia sobre el uso de estos valores:** todos están extrapolados de un solo antecedente de escala comparable (Anastasopoulos & Hornung, 2018) más el criterio de diseño transversal de Tema 2 ("índice diez-diez"). No reemplazan un análisis de requisitos propio basado en (a) el ancho de banda dinámico real del actuador bajo prueba que se seleccione, y (b) el contenido en frecuencia de las cargas obtenidas de la CFD del proyecto. Se recomienda tratarlos como punto de partida para dimensionar componentes candidatos (Paso 2 de los próximos pasos), no como valores definitivos de RNF hasta la etapa de diseño detallado.

## 5. Impacto sobre otros documentos del proyecto

- `03_Requisitos_No_Funcionales.md`: reemplazar los campos "[a definir]" de RNF-REN-01, RNF-REN-02, RNF-PRE-01, RNF-PRE-02 y RNF-PRE-03 por los valores preliminares de la sección 4, dejando explícita su naturaleza provisional (p. ej. "[preliminar, ver `07_Valores_Referencia_Literatura_Analoga.md`]").
- `resumen_referencias.md` / `referencias_bibliograficas.bib`: no se añaden referencias nuevas; los valores provienen íntegramente de fuentes ya catalogadas en Tema 1 (Sinha et al. 2022) y Tema 2 (Anastasopoulos & Hornung 2018; Nam 2001), consultadas ahora en mayor profundidad para extraer cifras específicas.

## 6. Próximo paso sugerido

Con estos valores ya disponibles, corresponde continuar con el **Paso 2** (actualizar `03_Requisitos_No_Funcionales.md` con estos valores preliminares) y, en paralelo o a continuación, el **Paso 3** (actualizar la interfaz I-03 en `05_Arquitectura_del_Sistema.md`), quedando el **Paso 4** (preselección de modelos COTS concretos de motor/reductor/sensor) como el que más se beneficia de tener ya cerrados los pasos anteriores.

## 7. Referencias citadas en este documento

- Anastasopoulos, L., & Hornung, M. (2018). *Design of a Real-Time Test Bench for UAV Servo Actuators.* AIAA AVIATION Forum, AIAA 2018-3735. DOI: 10.2514/6.2018-3735
- Nam, Y. (2001). *QFT Force Loop Design for the Aerodynamic Load Simulator.* IEEE Transactions on Aerospace and Electronic Systems, 37(4), 1384–1392. DOI: 10.1109/7.976972
- Sinha, A., Kumar, R., & Umakant, J. (2022). *Reduced-Order Model for Efficient Generation of a Subsonic Missile's Aerodynamic Database.* The Aeronautical Journal, 126(1303), 1546–1567. DOI: 10.1017/aer.2022.4
