# Requisitos No Funcionales

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Convención de ID:** `RNF-<CATEGORÍA>-<NN>`. Categorías: REN (Desempeño), PRE (Precisión), CNF (Confiabilidad), SEG (Seguridad), USA (Usabilidad), MAN (Mantenibilidad), MOD (Modularidad), COS (Costo), DOC (Documentación), **CAR (Capacidad de carga)**.
**Prioridad:** Alta / Media / Baja.
**Método de verificación:** **I**nspección, **A**nálisis, **D**emostración, **P**rueba.
**OE** = Objetivo específico trazado (ver `02_Requisitos_Funcionales.md` para la lista completa).

---

## Tabla resumen

| ID | Requisito | Categoría | Prioridad | Verificación | OE trazado |
|---|---|---|---|---|---|
| RNF-REN-01 | El lazo de control de aplicación de torque deberá ejecutarse a una frecuencia mínima de **[a definir, según ancho de banda del conjunto actuador + aleta]** para representar adecuadamente su dinámica. Referencia preliminar de literatura: el actuador debe sostener una velocidad de deflexión de hasta **~300 °/s bajo torque máximo** (Nalci & Kayran, 2014); la frecuencia del lazo debe ser suficiente para resolver esa dinámica sin degradarla. | Desempeño | Alta | P | OE-3 |
| **RNF-CAR-01** | **El motor de carga y el sensor de torque deberán dimensionarse para un rango de torque continuo de referencia de ~0,5–1 N·m y un torque pico de hasta ~2 N·m, acorde a los candidatos comerciales identificados (actuador de referencia MG996R, ~1 N·m de bloqueo; motor de carga DS3218, ~1,8–2,1 N·m de bloqueo), dentro de los techos de presupuesto definidos (actuador ≤ $10.000 CLP, motor de carga ≤ $50.000 CLP). El sensor de torque se implementa como celda de carga sobre un brazo de palanca de radio supuesto de 4 cm (torque = fuerza medida × radio), lo que da un rango de medición de hasta ~2 N·m, coherente con el torque pico definido. Rango revisado a la baja respecto a la estimación inicial de literatura (~5–8 N·m); el banco opera, por restricción de presupuesto, como demostrador a escala reducida y no como representación a escala real de una aleta de misil. A confirmar/ajustar con las simulaciones CFD propias del proyecto.** | **Capacidad de carga** | **Alta** | **A** | **OE-2 / OE-3** |
| RNF-REN-02 | La latencia entre la medición de una variable y la actualización de la referencia de control no deberá superar **[a definir]**. | Desempeño | Media | P | OE-3 |
| **RNF-REN-03** | **La frecuencia natural del conjunto motor de carga–sensor–actuador–aleta deberá mantener un margen mínimo respecto a la frecuencia de corte del lazo de control [a definir], para evitar acoplamiento dinámico o resonancia no deseada.** | **Desempeño** | **Alta** | **A** | **OE-3** |
| RNF-PRE-01 | El error de interpolación de la tabla de carga respecto a los datos CFD originales no deberá superar **[a definir, p. ej. 5 %]** en el rango de validación. | Precisión | Alta | A | OE-2 |
| RNF-PRE-02 | El sistema de medición de torque deberá tener una incertidumbre menor a **[a definir, % del fondo de escala]**. | Precisión | Alta | P | OE-5 |
| RNF-PRE-03 | El sistema de medición de posición angular de la **aleta** deberá tener una resolución menor a **[a definir]**, suficiente para distinguir el ángulo real del ángulo comandado ante holgura o compliance mecánica. | Precisión | Media | P | OE-5 |
| **RNF-PRE-04** | **El montaje en serie motor de carga–sensor–actuador–aleta deberá cumplir una tolerancia de alineación/concentricidad [a definir] para evitar cargas parásitas radiales o de flexión sobre el sensor de torque. Implementación: eje intermedio de 5 mm de diámetro (estándar), acoplado a cada servo mediante acoples flexibles de aluminio 5 mm, y soportado por dos rodamientos tipo pillow block montados en el riel de la bancada.** | **Precisión** | **Alta** | **I** | **OE-5** |
| RNF-CNF-01 | El banco deberá completar una campaña de ensayos de duración **[a definir]** sin fallas atribuibles al sistema de control o de adquisición. | Confiabilidad | Media | D | OE-6 |
| RNF-CNF-02 | Ante pérdida de comunicación entre módulos, el sistema deberá llevar el banco a un estado seguro (sin aplicación de torque). | Confiabilidad | Alta | P | OE-5 |
| RNF-SEG-01 | El banco deberá contar con un mecanismo de parada de emergencia físico, independiente del software de control. | Seguridad | Alta | I | OE-5 |
| RNF-SEG-02 | El software deberá implementar límites configurables de torque, velocidad y posición para proteger al actuador bajo prueba y a la estructura del banco. | Seguridad | Alta | P | OE-4 / OE-5 |
| RNF-SEG-03 | El diseño eléctrico y mecánico del banco deberá cumplir con prácticas de seguridad de laboratorio aplicables (protecciones eléctricas, resguardos mecánicos). | Seguridad | Alta | I | OE-5 |
| **RNF-SEG-04** | **El sistema deberá detener automáticamente la aplicación de carga ante una condición de atasco mutuo (stall) entre el motor de carga y el actuador bajo prueba, según el umbral de torque diferencial sostenido y el timeout definidos en RF-BAN-06.** | **Seguridad** | **Alta** | **P** | **OE-5 / OE-6** |
| RNF-USA-01 | La interfaz de operación deberá permitir configurar y lanzar un ensayo estándar sin requerir conocimientos de programación por parte del operador. | Usabilidad | Media | D | OE-4 |
| RNF-USA-02 | La configuración de un nuevo ensayo (a partir de una tabla de carga ya validada) no deberá tomar más de **[a definir, p. ej. 15 min]**. | Usabilidad | Baja | D | OE-4 |
| RNF-MAN-01 | El software deberá estructurarse en módulos independientes (importación de tablas, interpolación, control, adquisición, registro) con interfaces bien definidas entre ellos. | Mantenibilidad | Alta | I | OE-3 |
| RNF-MAN-02 | El código fuente deberá estar documentado y bajo control de versiones para facilitar su mantenimiento y extensión futura. | Mantenibilidad | Media | I | OE-3 / OE-4 |
| RNF-MOD-01 | La arquitectura deberá desacoplar el módulo de simulación CFD (offline) del módulo de banco de ensayos (online), comunicándose exclusivamente mediante archivos de tabla de carga (CSV/JSON). | Modularidad | Alta | I | OE-3 |
| RNF-MOD-02 | El banco deberá poder adaptarse a una nueva aplicación (nuevo vehículo o superficie de control) mediante la sola actualización de la tabla de carga, sin modificaciones sustanciales de hardware. | Modularidad | Alta | D | OE-3 |
| RNF-COS-01 | El costo total de los componentes del prototipo deberá ajustarse al presupuesto disponible para el proyecto de tesis, priorizando componentes comerciales (COTS). | Costo | Media | A | OE-5 |
| RNF-DOC-01 | Cada ensayo ejecutado deberá quedar documentado con la configuración utilizada (tabla de carga, parámetros, fecha, operador) de forma trazable a sus resultados. | Documentación | Media | I | OE-6 |
| RNF-DOC-02 | El diseño mecánico, electrónico y de software del banco deberá quedar documentado con un nivel de detalle que permita su reproducción (planos, esquemáticos, código). | Documentación | Media | I | OE-3 / OE-5 |

---

## Notas de trazabilidad y justificación

- **RNF-SEG-xxx** responde al **riesgo #4** de la especificación ("Complejidad del desarrollo del sistema de control e instrumentación") y a buenas prácticas de bancos de ensayo dinámicos descritas en Plummer (2007, Tema 2).
- **RNF-SEG-04** es nueva: cubre específicamente el riesgo del esquema de dos motores enfrentados (motor de carga vs. actuador bajo prueba), que no estaba contemplado cuando el banco se concebía sobre un eje sin actuación externa.
- **RNF-PRE-04** y **RNF-REN-03** son nuevas: derivan del montaje físico en un solo eje (motor de carga–sensor–actuador–aleta) definido en la revisión de arquitectura mecánica. Sin margen de alineación y de frecuencia natural, el sensor de torque puede registrar cargas espurias y el lazo de control puede excitar modos no deseados del conjunto.
- **RNF-MOD-01/02** formalizan el requisito explícito de la especificación: *"la arquitectura modular propuesta permitiría adaptar el banco a distintas aplicaciones mediante la actualización de las tablas de cargas, sin requerir modificaciones sustanciales en la plataforma experimental"*.
- **RNF-COS-01** responde directamente al **riesgo #5** ("Disponibilidad limitada de recursos para fabricación y validación"), cuya mitigación propuesta es priorizar componentes comerciales de bajo costo.
- **RNF-PRE-xxx** deberá refinarse una vez seleccionados los sensores candidatos; la literatura del **Tema 5** (Ewald 2000; Yu et al. 2022; Jubair et al. 2025) da órdenes de magnitud típicos de incertidumbre en balanzas de torque/galgas extensométricas que sirven de referencia para fijar estos valores.
- **RNF-REN-01/02/03** son los requisitos más dependientes del actuador finalmente seleccionado: el ancho de banda dinámico del conjunto actuador+aleta condiciona la frecuencia mínima de actualización del lazo de carga (ver Tema 2, en particular Yao et al. 2010 sobre compensación de torque excedente en tiempo real).
- **RNF-CAR-01** fija el rango de torque para dimensionar el motor de carga y el actuador de referencia. La estimación inicial (5–8 N·m), triangulada desde literatura de escala misil/UAV (Nalci & Kayran 2014; Anastasopoulos & Hornung 2018), se **revisó a la baja (~0,5–2 N·m)** tras fijar los techos de presupuesto (actuador de referencia ≤ $10.000 CLP, motor de carga ≤ $50.000 CLP) y verificar candidatos comerciales reales disponibles en Chile (MG996R como actuador de referencia, ~$5.625 CLP; DS3218 como motor de carga, ~$20.526 CLP, dejando margen del presupuesto para sensor de torque, driver y acople mecánico). Esto implica que el banco es, en esta iteración, un **demostrador a escala reducida** — no representa magnitudes de carga de una aleta de misil a escala real — lo cual debe quedar explícito en la Especificación del Proyecto y en el informe final.

## Pendiente / a definir en próxima iteración

Los campos marcados **[a definir]** requieren un valor numérico concreto. Se recomienda completarlos en dos etapas:

1. **Etapa de estado del arte (OE-1):** usar rangos típicos reportados en la literatura de Temas 2 y 5 como primera aproximación (p. ej. frecuencias de lazo de control de simuladores de carga electrohidráulicos, incertidumbres típicas de balanzas de torque). **Ya completado para el rango de torque y velocidad de referencia (RNF-CAR-01, RNF-REN-01)** — ver nota de trazabilidad arriba.
2. **Etapa de diseño preliminar (OE-2/OE-3):** ajustar los valores una vez definido el actuador de referencia, el motor de carga y el rango de cargas obtenido de las simulaciones CFD propias del proyecto. La tolerancia de alineación (RNF-PRE-04) y el margen de resonancia (RNF-REN-03) requieren además conocer la inercia real de la aleta seleccionada. El rango preliminar de RNF-CAR-01 debe confirmarse o reemplazarse con datos propios en esta etapa.

3. **Decisión preliminar de estrategia de control de torque del motor de carga:** se opta, preliminarmente, por **intervenir el servo DS3218 para acceder al motor DC crudo** y comandarlo por corriente con un driver externo (opción (a)), dado que es la alternativa técnicamente consistente con RF-BAN-01/RF-BAN-02 (control de torque real, no de posición). Se mantiene registrada la alternativa **(b)** — usar el servo intacto en un esquema de comando de posición límite — como opción de respaldo más simple si la intervención del servo resulta impracticable. Ambas opciones, y la decisión final, quedan sujetas a confirmación con el profesor guía. Esta decisión condiciona el diseño del Controlador (sección 2.4 de `05_Arquitectura_del_Sistema.md`) y la interfaz I-03.
