# Selección Preliminar del Actuador de Carga

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Decisión de arquitectura **cerrada** (electromecánica rotativa). Selección de componentes específicos **preliminar**, consistente con `05_Arquitectura_del_Sistema.md` y `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-04). Sujeta a confirmación final en la etapa de diseño detallado (OE-3) una vez se cuente con valores numéricos definitivos de torque y ancho de banda provenientes de las simulaciones CFD propias del proyecto.

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `02_Requisitos_Funcionales.md`, `03_Requisitos_No_Funcionales.md`, `05_Arquitectura_del_Sistema.md`, `resumen_referencias.md` (Tema 2 y Tema 3).

---

## 1. Objeto de la decisión

El **actuador de carga** es el elemento del banco (subsistema 2.5 de `05_Arquitectura_del_Sistema.md`) que aplica físicamente, sobre el eje del actuador bajo prueba, el torque objetivo generado por el módulo de interpolación (RF-BAN-01, RF-BAN-02). No debe confundirse con el **actuador bajo prueba**, que es un componente externo e intercambiable fuera del alcance de desarrollo del proyecto (ver `01_Especificacion_del_Proyecto.md`, sección "No incluye").

La tecnología del actuador de carga condiciona directamente:
- La interfaz I-03 (Controlador → Banco), aún pendiente de formalizar en `05_Arquitectura_del_Sistema.md`.
- Los valores numéricos de `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-04 ya fijados; RNF-REN-01/02, RNF-PRE-02 aún `[preliminar]`).
- El diseño mecánico (CAD) y electrónico del banco, y por lo tanto toda la ruta crítica del cronograma (Fase C).

## 2. Supuestos de partida

| Supuesto | Valor asumido | Origen |
|---|---|---|
| Rango de torque objetivo | Escala pequeña, ~0,5–2 N·m (demostrador a escala reducida) | RNF-CAR-01, tras revisión a la baja por presupuesto |
| Infraestructura de laboratorio disponible | Alimentación eléctrica estándar + aire comprimido de compresor comercial (máx. 100 psi) | Definido por el usuario |
| Prioridad de diseño | Balance general entre costo, fidelidad dinámica y facilidad de control, sin priorizar un criterio único | Definido por el usuario |
| Presupuesto | Limitado, con preferencia por componentes comerciales (COTS); actuador de referencia ≤ $10.000 CLP, motor de carga ≤ $50.000 CLP | RNF-COS-01, RNF-CAR-01 |
| Ancho de banda dinámico objetivo | ~10 Hz (seguimiento dinámico de carga, no solo validación estática) | Criterio "índice diez-diez" (Tema 2), ver `07_Valores_Referencia_Literatura_Analoga.md` |

## 3. Alternativas evaluadas

### 3.1 Primer nivel: tecnología de actuación

Se evaluaron las tres arquitecturas de actuación de carga identificadas en la revisión de literatura (Tema 2: *Banco de ensayos / simulación de carga sobre actuadores*; Tema 3: *Actuadores para superficies de control*):

1. **Electromecánico** — motor eléctrico (rotativo o lineal) acoplado, directa o indirectamente, al eje del actuador bajo prueba.
2. **Electrohidráulico** — cilindro o motor hidráulico comandado por servoválvula, con bomba y depósito.
3. **Neumático** — cilindro o motor neumático alimentado por el compresor de laboratorio disponible.

| Criterio | Electromecánico | Electrohidráulico | Neumático |
|---|---|---|---|
| Adecuación al rango de torque asumido (~0,5–2 N·m) | Muy buena; motores/servos pequeños cubren el rango con margen | Sobredimensionado para esta escala; la literatura de Tema 2 trata principalmente cargas grandes de alta inercia | Alcanzable, pero con limitaciones de precisión |
| Infraestructura requerida | Solo eléctrica (ya disponible) | Bomba, depósito, válvulas proporcionales, filtrado (no disponible) | Compresor disponible, pero falta acondicionamiento (regulación, secado) |
| Control de fuerza/torque | Lazo cerrado con sensor de torque + corriente de motor; dinámica bien modelable | Ancho de banda alto, pero requiere válvulas servo costosas y mantenimiento especializado | La compresibilidad del aire introduce retardo y no linealidad; dificulta compensar el torque parásito (RF-BAN-02) |
| Costo (RNF-COS-01) | Bajo–medio, componentes COTS | Alto (bomba, válvulas servo, seguridad de presión) | Bajo, pero se diluye si se requieren sensores de precisión adicionales |
| Riesgo de seguridad | Bajo, contenible con límite de corriente y freno | Alto (presión hidráulica, fugas) | Medio |
| Antecedente directo en la literatura del proyecto | Anastasopoulos & Hornung (2018); Oberschwendtner et al. (2022) | Plummer (2007); Yao et al. (2010, 2012); Jiao et al. (2004); Lee & Cho (2001); Nam (2001); Zhao et al. (2024); Jing et al. (2024); Chen et al. (2024) | Sin antecedente directo en la revisión bibliográfica del proyecto |

**Resultado:** se descartan electrohidráulico y neumático por las razones de la tabla; se confirma **electromecánico**.

### 3.2 Segundo nivel: configuración electromecánica — lineal vs. rotativa

Dentro de la opción electromecánica se evaluaron dos configuraciones concretas:

**(a) Lineal — Actuonix L16-P (evaluado y descartado)**

Se preseleccionó inicialmente un actuador lineal Actuonix L16-P por su bajo costo, aplicando fuerza sobre un brazo de palanca mediante rótulas (rod-end bearings), con torque medido directamente en el eje de charnela (sensor in-line, sin necesidad de convertir fuerza × radio).

*Motivo de descarte:* su velocidad máxima (8 mm/s) resulta incompatible con el seguimiento dinámico de carga a ~10 Hz que exige el criterio "índice diez-diez" identificado en la literatura de Tema 2 (ver `07_Valores_Referencia_Literatura_Analoga.md`, §3). Con esa velocidad, el banco quedaría limitado a validación cuasi-estática, lo que no satisface RF-PRO-06 (recálculo de torque en tiempo real según posición real de la aleta) ni el objetivo de caracterizar el actuador bajo carga dinámica representativa.

**(b) Rotativa — servo DS3218 intervenido (seleccionado)**

Motor de carga: servo DS3218 (~$20.526 CLP), intervenido para acceder al motor DC crudo y comandado por corriente mediante un driver externo (no se usa como servo de posición). Actuador bajo prueba de referencia: servo MG996R (~$5.625 CLP).

- **Mecánica:** eje intermedio de 5 mm de diámetro, acoplado a cada servo mediante acoples flexibles de aluminio, soportado por dos rodamientos tipo pillow block montados en el riel de la bancada. Piezas custom (collares, brazo de torque, soportes de rodamiento) fabricadas por impresión 3D.
- **Medición de torque:** no inline. Se implementa mediante una celda de carga fija al riel, presionada por un brazo de palanca (torque arm) de radio ~4 cm rígidamente sujeto al eje (torque = fuerza medida × radio). Esta configuración fue una decisión explícita de compensar la ausencia de sensor in-line con una geometría de brazo conocida y fija — ver RNF-PRE-04 para la tolerancia de alineación asociada.
- **Ventaja sobre la opción lineal:** un motor rotativo controlado por corriente no tiene la limitación de velocidad lineal del L16-P, permitiendo en principio seguir referencias de torque a mayor ancho de banda, más cercano al objetivo de ~10 Hz.

## 4. Decisión

**Se selecciona la arquitectura electromecánica rotativa**: servo DS3218 intervenido a motor DC crudo, control de torque por corriente, acoplado al actuador bajo prueba (MG996R) mediante eje intermedio de 5 mm con acoples flexibles y rodamientos pillow block, y con sensor de torque no inline (celda de carga sobre brazo de palanca de ~4 cm).

### 4.1 Justificación

- **Restricción dinámica del actuador lineal:** la velocidad máxima del Actuonix L16-P (8 mm/s) resultaba incompatible con el seguimiento de carga a la frecuencia de referencia identificada en la literatura de Tema 2 (~10 Hz, criterio "índice diez-diez"; Nam 2001 y trabajos posteriores de la misma línea). Optar por un motor rotativo evita esta limitación estructural sin cambiar de tecnología de actuación (sigue siendo electromecánica, de bajo costo y riesgo, alineada con RNF-COS-01).
- **Escala del proyecto:** al rango de torque de RNF-CAR-01 (~0,5–2 N·m), un servo pequeño intervenido cubre la carga requerida sin necesidad de infraestructura hidráulica.
- **Antecedente directo en la literatura propia:** Anastasopoulos & Hornung (2018) describen un banco tipo dinamómetro que emula cargas aerodinámicas sobre servoactuadores de UAV mediante un motor de carga aplicando torque en el eje de charnela, con sensores de torque y corriente — es, en escala y objetivo, el antecedente más cercano al banco propuesto en este proyecto. Oberschwendtner et al. (2022), del mismo grupo de investigación, complementa esta referencia con un protocolo de ensayo estático directamente aplicable.
- **Transferencia de las estrategias de control:** las técnicas de compensación de torque parásito y control de fuerza desarrolladas para simuladores de carga electrohidráulicos (Yao et al. 2010, 2012; Nam 2001 — QFT; Lee & Cho 2001 — control difuso) son conceptualmente transferibles a un lazo de corriente/torque electromecánico rotativo.
- **Costo y disponibilidad confirmada:** MG996R y DS3218 son componentes COTS ya cotizados en Chile (Altronics), dentro de los techos de presupuesto definidos (RNF-CAR-01).

### 4.2 Riesgos y limitaciones de esta decisión

- El rango de torque de RNF-CAR-01 (~0,5–2 N·m) es una hipótesis de partida basada en presupuesto y componentes COTS disponibles, no un valor confirmado por CFD propia; si las simulaciones del proyecto arrojan cargas significativamente mayores, esta decisión debe revisarse.
- La medición de torque **no inline** (celda de carga + brazo de palanca) introduce dependencia de la geometría del brazo: cualquier error en el radio efectivo (deformación de la pieza impresa en 3D bajo carga, desalineamiento) se traduce directamente en error de torque medido. Esto motiva la verificación de resistencia del brazo impreso en 3D bajo el torque pico (ver `05_Arquitectura_del_Sistema.md`, §5, supuesto 9) y la tolerancia de alineación de RNF-PRE-04.
- No se ha caracterizado aún el ancho de banda dinámico real alcanzable con el DS3218 intervenido controlado por corriente; los valores de RNF-REN-01/02 siguen siendo `[preliminar]`, extrapolados de Anastasopoulos & Hornung (2018), una fuente de escala de torque mayor (decenas de N·m) aunque de objetivo comparable.
- La intervención del DS3218 (acceso al motor DC crudo) es en sí misma un riesgo de fabricación/reproducibilidad: si resulta impracticable, la especificación ya registra una alternativa de respaldo (control por posición límite del servo intacto, opción "b" en `03_Requisitos_No_Funcionales.md`), pendiente de confirmación con el profesor guía.

## 5. Impacto sobre otros documentos del proyecto

| Documento | Estado |
|---|---|
| `05_Arquitectura_del_Sistema.md` | **Ya actualizado**: §2.5 describe la implementación mecánica (eje de 5 mm, acoples flexibles, rodamientos pillow block, celda de carga + brazo de palanca) y §7 registra el rango de torque preliminar. **Pendiente:** la interfaz I-03 (tabla §3) sigue marcada "por definir"; debe formalizarse como comando de corriente al driver del motor DC del DS3218 intervenido. |
| `03_Requisitos_No_Funcionales.md` | **Ya actualizado**: RNF-CAR-01 y RNF-PRE-04 fijan valores concretos consistentes con esta decisión. **Pendiente:** RNF-REN-01/02 y RNF-PRE-02 siguen `[a definir]`/`[preliminar]`, a la espera de datos propios del motor DC intervenido y del sensor de torque específico. |
| `02_Requisitos_Funcionales.md` | Sin cambios de fondo; RF-BAN-01 a RF-BAN-06 son agnósticos a la tecnología de actuación y siguen aplicando directamente. |
| `01_Cronograma.md` | La tarea crítica "Selección preliminar de actuador de carga" (Fase A) puede marcarse como completada a nivel de arquitectura; esto desbloquea en paralelo el diseño mecánico (C1), la definición de casos de simulación CFD (B1) y el cierre de RF/RNF (A3). |

## 6. Próximos pasos

1. ~~Formalizar la interfaz I-03~~ — **Completado.** Ver `05_Arquitectura_del_Sistema.md` §3 e I-03: PWM desde microcontrolador → driver H-bridge → motor DC intervenido, lazo de corriente cerrado en software.
2. ~~Seleccionar driver de corriente y plataforma de microcontrolador~~ — **Completado.** Ver §6.1.
3. **Caracterizar o conseguir datasheet del motor DC crudo** dentro del DS3218 una vez intervenido (corriente nominal/de stall, curva torque–velocidad, constante eléctrica), necesario para cerrar RNF-REN-01/02 con valores propios. El dato de corriente de stall a nivel de servo completo (~1,8–2 A a 6–7 V) ya está disponible por datasheet del fabricante y se usó para dimensionar el driver (§6.1); falta caracterizar el comportamiento específico una vez intervenido (bypaseado el potenciómetro/controlador interno).
4. ~~Seleccionar celda de carga concreta~~ — **Completado.** Ver §6.2: Altronics LC-10KG-HX711.
5. **Confirmar con el profesor guía** la estrategia de control de torque (corriente vía intervención del DS3218, opción (a)) frente a la alternativa de respaldo (posición límite del servo intacto, opción (b)).
6. **Verificar resistencia mecánica** del brazo de torque y los collares impresos en 3D frente al torque pico (~2 N·m), antes de la validación experimental.
7. **Verificar experimentalmente la incertidumbre de torque de extremo a extremo** (celda + brazo + calibración conjunta), ya que la precisión de 0,02% FE de la celda (§6.2) es solo la especificación del componente aislado.
8. Confirmar/ajustar el rango de torque de RNF-CAR-01 una vez disponibles resultados propios de CFD.

### 6.1 Preselección de componentes electrónicos (driver, sensor de corriente, microcontrolador)

| Componente | Modelo seleccionado | Justificación |
|---|---|---|
| Driver H-bridge | **BTS7960** (módulo COTS, disponible en varias tiendas chilenas, ~$6.000–12.000 CLP) | Soporta hasta 43 A, muy por encima de la corriente de stall del DS3218 (~1,8–2 A a 6–7 V según datasheet de fabricante). El margen amplio protege específicamente ante la condición de atasco mutuo (RF-BAN-06): durante la ventana de detección de stall, el driver no se satura ni sufre daño térmico aunque el motor esté forzado de forma sostenida. Es además el driver más disponible/documentado a esta escala de corriente en el mercado chileno. |
| Sensor de corriente | **INA219** (I2C, ADC de 12 bits, rango 0–3,2 A, resolución ~0,8 mA, 1 % de precisión), disponible en Altronics | Preferido sobre ACS712 porque los módulos ACS712 disponibles en Chile son típicamente de 20 A de rango, lo que da muy baja resolución efectiva a los ~2 A que maneja este motor. El INA219 está dimensionado para corrientes pequeñas y se integra por I2C (sin ocupar un canal ADC dedicado del microcontrolador). Al estar disponible en Altronics, consolida la compra con el DS3218 y el MG996R, reduciendo el riesgo de lead time de proveedores (riesgo #5 de la especificación del proyecto). |
| Microcontrolador | **ESP32 DevKitC-V4** (Altronics, ~$7.990 CLP) | Doble núcleo a 240 MHz con periférico PWM por hardware (LEDC), con margen amplio sobre la frecuencia de lazo preliminar de RNF-REN-01 (~100–200 Hz). I2C nativo para el INA219, GPIO suficiente para encoder y celda de carga, bajo costo (permite tener unidad de respaldo sin impacto relevante en presupuesto), y ampliamente documentado. |

**Nota:** esta preselección resuelve el "qué" (modelo/tecnología) pero no reemplaza la validación experimental del ancho de banda real del lazo de corriente en software (ver `05_Arquitectura_del_Sistema.md` §5, supuesto 10) ni la caracterización eléctrica del motor DC intervenido (ítem 3 de esta sección).

### 6.2 Selección de celda de carga (sensor de torque, I-04)

**Cálculo de fuerza requerida:** con el brazo de palanca de ~4 cm (RNF-CAR-01), el torque pico (~2 N·m) se traduce en F = T/r = 2/0,04 = **50 N ≈ 5,1 kgf**. El rango de operación continua (0,5–1 N·m) equivale a ~12,5–25 N (~1,3–2,5 kgf).

Altronics ofrece celdas de carga tipo barra (75×12×12 mm, aluminio, montaje en voladizo) con módulo HX711 (ADC de 24 bits) incluido, al **mismo precio ($7.214 CLP) en los rangos de 1, 5, 10 y 20 kg** — sin penalización de costo por elegir un rango mayor, por lo que la decisión es puramente de margen mecánico y resolución efectiva:

| Rango candidato | Fuerza pico (50 N) como % de fondo de escala | Evaluación |
|---|---|---|
| 5 kg (49 N) | ~102 % | Descartado: el torque pico ya excede la capacidad nominal; operar repetidamente ahí degrada la celda por fatiga, aunque la sobrecarga de seguridad (150%) la tolere puntualmente. |
| **10 kg (98,1 N)** | **~51 %** | **Seleccionado.** Margen ~2× sobre el pico; la sobrecarga de seguridad (150% → 147 N ≈ 5,9 N·m) cubre transitorios antes de que actúe la protección de atasco mutuo (RF-BAN-06). |
| 20 kg (196 N) | ~25 % | Descartado: diluye demasiado la señal en el rango de operación continua (12,5–25 N caería en solo ~6–13% de fondo de escala), empeorando la resolución efectiva justo donde el banco opera la mayor parte del tiempo. |

**Modelo seleccionado: Altronics LC-10KG-HX711** (SKU 61740064, $7.214 CLP, con módulo HX711 incluido). Especificación de fábrica: precisión 0,02% FE, sobrecarga de seguridad 150%. Esto equivale a una incertidumbre nominal de ~0,0008 N·m (0,02% de 98,1 N × 0,04 m) — muy por debajo del objetivo preliminar de RNF-PRE-02 (≤0,5% FE) y mejor que el óptimo observado en Anastasopoulos & Hornung (2018), 0,1% FE. La geometría de barra en voladizo (un extremo fijo, el otro recibe la carga) es directamente compatible con la implementación ya descrita en `05_Arquitectura_del_Sistema.md` §2.5: celda fija al riel, presionada por el brazo de torque.

**Advertencia:** la precisión de 0,02% FE es la especificación del componente aislado, no la incertidumbre de medición de torque de extremo a extremo. Esta última depende también de la tolerancia del radio efectivo del brazo de palanca (impreso en 3D, ver RNF-PRE-04) y de la calibración conjunta celda+brazo, que deben verificarse experimentalmente antes de reportar un valor definitivo de RNF-PRE-02.

---

## Referencias citadas en esta decisión

- Anastasopoulos, L., & Hornung, M. (2018). *Design of a Real-Time Test Bench for UAV Servo Actuators.* AIAA AVIATION Forum, AIAA 2018-3735. DOI: 10.2514/6.2018-3735
- Oberschwendtner, S., Teubl, D., & Hornung, M. (2022). *Static Test Procedure for Electromechanical Actuators for UAV Applications.* AIAA AVIATION Forum. DOI: 10.2514/6.2022-3705
- Plummer, A. R. (2007). *Control Techniques for Structural Testing: A Review.* Proc. IMechE Part I: J. Systems and Control Engineering, 221(2), 139–169. DOI: 10.1243/09596518JSCE295
- Yao, J., Jiao, Z., Shang, Y., & Huang, C. (2010). *Adaptive Nonlinear Optimal Compensation Control for Electro-Hydraulic Load Simulator.* Chinese Journal of Aeronautics, 23(6), 720–733. DOI: 10.1016/S1000-9361(09)60274-3
- Yao, J., Jiao, Z., & Yao, B. (2012). *Robust Control for Static Loading of Electrohydraulic Load Simulator with Friction Compensation.* Chinese Journal of Aeronautics, 25(6), 954–962. DOI: 10.1016/S1000-9361(11)60466-0
- Jiao, Z., Gao, J., Hua, Q., & Wang, S. (2004). *The Velocity Synchronizing Control on the Electro-Hydraulic Load Simulator.* Chinese Journal of Aeronautics, 17(1), 39–46. DOI: 10.1016/S1000-9361(11)60201-6
- Lee, S. Y., & Cho, H. S. (2001). *A Fuzzy Controller for an Aeroload Simulator Using Phase Plane Method.* IEEE Transactions on Control Systems Technology, 9(6), 791–801. DOI: 10.1109/87.960340
- Nam, Y. (2001). *QFT Force Loop Design for the Aerodynamic Load Simulator.* IEEE Transactions on Aerospace and Electronic Systems, 37(4), 1384–1392. DOI: 10.1109/7.976972
- Zhao, Y., Qiu, C., Huang, J., Tan, Q., Sun, S., & Gong, Z. (2024). *Terminal Sliding Mode Force Control Based on Modified Fast Double-Power Reaching Law for Aerospace Electro-Hydraulic Load Simulator of Large Loads.* Actuators, 13(4), 145. DOI: 10.3390/act13040145
- Jing, C., Zhang, H., Hui, Y., Zhang, L., & Xu, H. (2024). *Adaptive Robust Disturbance Rejection Backstepping Control of a Novel Friction Electro-Hydraulic Load Simulator.* Ain Shams Engineering Journal, 15(12), 103092. DOI: 10.1016/j.asej.2024.103092
- Chen, Z., Yan, H., Zhang, P., Shan, J., & Li, J. (2024). *Adaptive NN Force Loading Control of Electro-Hydraulic Load Simulator.* Actuators, 13(12), 471. DOI: 10.3390/act13120471
