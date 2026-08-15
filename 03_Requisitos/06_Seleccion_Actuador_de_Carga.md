# Selección Preliminar del Actuador de Carga

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Decisión preliminar (Fase A del cronograma, tarea crítica). Sujeta a confirmación en la etapa de diseño detallado (OE-3) una vez se cuente con valores numéricos definitivos de torque y ancho de banda provenientes de las simulaciones CFD propias del proyecto.

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `02_Requisitos_Funcionales.md`, `03_Requisitos_No_Funcionales.md`, `05_Arquitectura_del_Sistema.md`, `resumen_referencias.md` (Tema 2 y Tema 3).

---

## 1. Objeto de la decisión

El **actuador de carga** es el elemento del banco (subsistema 2.5 de `05_Arquitectura_del_Sistema.md`) que aplica físicamente, sobre el eje del actuador bajo prueba, el torque objetivo generado por el módulo de interpolación (RF-BAN-01, RF-BAN-02). No debe confundirse con el **actuador bajo prueba**, que es un componente externo e intercambiable fuera del alcance de desarrollo del proyecto (ver `01_Especificacion_del_Proyecto.md`, sección "No incluye").

La tecnología del actuador de carga condiciona directamente:
- La interfaz I-03 (Controlador → Banco), actualmente marcada "por definir" en `05_Arquitectura_del_Sistema.md`.
- Los valores numéricos pendientes en `03_Requisitos_No_Funcionales.md` (RNF-REN-01, RNF-REN-02, RNF-PRE-02, RNF-COS-01).
- El diseño mecánico (CAD) y electrónico del banco, y por lo tanto toda la ruta crítica del cronograma (Fase C).

## 2. Supuestos de partida

Estos supuestos se adoptan como punto de partida para esta decisión preliminar y deberán confirmarse con datos propios de la CFD del proyecto:

| Supuesto | Valor asumido | Origen |
|---|---|---|
| Rango de torque objetivo | Escala pequeña, del orden de <10 N·m (superficie de control tipo UAV/misil pequeño) | Definido por el usuario para acotar esta decisión |
| Infraestructura de laboratorio disponible | Alimentación eléctrica estándar + aire comprimido de compresor comercial (máx. 100 psi) | Definido por el usuario |
| Prioridad de diseño | Balance general entre costo, fidelidad dinámica y facilidad de control, sin priorizar un criterio único | Definido por el usuario |
| Presupuesto | Limitado, con preferencia por componentes comerciales (COTS) | RNF-COS-01 |

## 3. Alternativas evaluadas

Se evaluaron las tres arquitecturas de actuación de carga identificadas en la revisión de literatura (Tema 2: *Banco de ensayos / simulación de carga sobre actuadores*; Tema 3: *Actuadores para superficies de control*):

1. **Electromecánico** — motor eléctrico (BLDC o servo AC) con reductor, acoplado directamente al eje del actuador bajo prueba.
2. **Electrohidráulico** — cilindro o motor hidráulico comandado por servoválvula, con bomba y depósito.
3. **Neumático** — cilindro o motor neumático alimentado por el compresor de laboratorio disponible.

### 3.1 Tabla comparativa

| Criterio | Electromecánico | Electrohidráulico | Neumático |
|---|---|---|---|
| Adecuación al rango de torque asumido (<10 N·m) | Muy buena; motores pequeños con reductor cubren el rango con margen | Sobredimensionado para esta escala; la literatura de Tema 2 trata principalmente cargas grandes de alta inercia | Alcanzable, pero con limitaciones de precisión |
| Infraestructura requerida | Solo eléctrica (ya disponible) | Bomba, depósito, válvulas proporcionales, filtrado (no disponible) | Compresor disponible, pero falta acondicionamiento (regulación, secado) |
| Control de fuerza/torque | Lazo cerrado con sensor de torque + corriente de motor; dinámica bien modelable | Ancho de banda alto, pero requiere válvulas servo costosas y mantenimiento especializado | La compresibilidad del aire introduce retardo y no linealidad; dificulta compensar el torque parásito (RF-BAN-02) |
| Costo (RNF-COS-01) | Bajo–medio, componentes COTS | Alto (bomba, válvulas servo, seguridad de presión) | Bajo, pero se diluye si se requieren sensores de precisión adicionales |
| Riesgo de seguridad | Bajo, contenible con límite de corriente y freno | Alto (presión hidráulica, fugas) | Medio |
| Antecedente directo en la literatura del proyecto | Anastasopoulos & Hornung (2018); Oberschwendtner et al. (2022) | Plummer (2007); Yao et al. (2010, 2012); Jiao et al. (2004); Lee & Cho (2001); Nam (2001); Zhao et al. (2024); Jing et al. (2024); Chen et al. (2024) | Sin antecedente directo en la revisión bibliográfica del proyecto |

## 4. Decisión

**Se selecciona preliminarmente una arquitectura electromecánica**: motor eléctrico (BLDC o servo AC) con reductor, acoplado al eje del actuador bajo prueba mediante el acople intercambiable de RF-SIS-02, con sensor de torque in-line y encoder de posición para realimentación del lazo de control.

### 4.1 Justificación

- **Escala del proyecto:** a un rango de torque del orden de <10 N·m, un motor pequeño con reductor cubre la carga requerida sin necesidad de construir la infraestructura hidráulica (bomba, servoválvulas, depósito) que la mayor parte de la literatura de Tema 2 asume como ya disponible para cargas aeroespaciales de mayor magnitud.
- **Infraestructura disponible:** la alimentación eléctrica ya está disponible; el aire comprimido a 100 psi no se descarta, pero se reserva para funciones auxiliares (p. ej. freno de emergencia neumático) y no como actuador de carga principal, dado que la compresibilidad del aire complica precisamente el problema central identificado en el riesgo #2 de la especificación del proyecto ("Dificultad en la reproducción experimental de las cargas objetivo").
- **Antecedente directo en la literatura propia:** Anastasopoulos & Hornung (2018) describen un banco tipo dinamómetro que emula cargas aerodinámicas sobre servoactuadores de UAV mediante un motor de carga aplicando torque en el eje de charnela, con sensores de torque y corriente — es, en escala y objetivo, el antecedente más cercano al banco propuesto en este proyecto. Oberschwendtner et al. (2022), del mismo grupo de investigación, complementa esta referencia con un protocolo de ensayo estático directamente aplicable.
- **Transferencia de las estrategias de control:** las técnicas de compensación de torque parásito y control de fuerza desarrolladas para simuladores de carga electrohidráulicos (Yao et al. 2010, 2012; Nam 2001 — QFT; Lee & Cho 2001 — control difuso) son conceptualmente transferibles a un lazo de corriente/torque electromecánico. No se pierde la base teórica de Tema 2 al optar por esta tecnología; solo cambia el actuador que ejecuta el comando.
- **Costo y riesgo:** una solución electromecánica es la de menor costo y menor riesgo de seguridad de laboratorio entre las tres alternativas, alineada con RNF-COS-01 y con la prioridad de balance general indicada para esta decisión.

### 4.2 Riesgos y limitaciones de esta decisión preliminar

- El rango de torque asumido (<10 N·m) es una hipótesis de partida, no un valor confirmado por CFD propia; si las simulaciones del proyecto arrojan cargas significativamente mayores, esta decisión debe revisarse.
- No se ha evaluado aún el ancho de banda dinámico requerido (ligado a RNF-REN-01), que depende del actuador bajo prueba finalmente considerado y puede favorecer o penalizar la opción electromecánica frente a la electrohidráulica si se requieren frecuencias muy altas de actualización de carga.
- La selección de motor, reductor y sensor de torque específicos (modelos COTS con datasheet) queda pendiente y depende del valor numérico de torque máximo que se defina.

## 5. Impacto sobre otros documentos del proyecto

| Documento | Actualización sugerida |
|---|---|
| `05_Arquitectura_del_Sistema.md` | Interfaz I-03: cambiar de "por definir" a "comando eléctrico a driver de motor (analógico o bus de tiempo real — CAN/EtherCAT, a definir en diseño electrónico)". Actualizar sección 5 (Supuestos de diseño, punto 3) y sección 7 (Pendiente) para reflejar la arquitectura electromecánica seleccionada. |
| `03_Requisitos_No_Funcionales.md` | RNF-REN-01/02, RNF-PRE-02: mantener como "[a definir]" hasta contar con datasheet de motor/sensor específicos, pero acotar el rango de búsqueda a componentes electromecánicos de baja potencia. |
| `02_Requisitos_Funcionales.md` | Sin cambios de fondo; RF-BAN-01 a RF-BAN-05 son agnósticos a la tecnología de actuación y siguen aplicando directamente. |
| `01_Cronograma.md` | La tarea crítica "Selección preliminar de actuador de carga" (Fase A) puede marcarse como completada; esto desbloquea en paralelo el diseño mecánico (C1), la definición de casos de simulación CFD (B1) y el cierre de RF/RNF (A3). |

## 6. Próximos pasos

1. Definir el torque máximo y el ancho de banda objetivo, a partir de una primera estimación CFD (aunque sea gruesa) o de valores de literatura análoga (misil/UAV pequeño).
2. Preseleccionar modelos COTS concretos de motor, reductor y sensor de torque, con datasheet.
3. Actualizar la interfaz I-03 en `05_Arquitectura_del_Sistema.md` conforme a la sección 5 de este documento.
4. Cerrar los valores numéricos pendientes de RNF-REN-01, RNF-REN-02 y RNF-PRE-02 en `03_Requisitos_No_Funcionales.md`.

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
