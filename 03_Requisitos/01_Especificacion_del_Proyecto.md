# Especificación del Proyecto

**Estado (28/08/2026):** la reunión de avance de esta fecha ya se realizó (ver `00_Administración/02_Registro_Reuniones_Avance.md`). Los acuerdos que afectan este documento están incorporados como notas puntuales abajo (§5bis, §9); los acuerdos que afectan otros documentos (arquitectura, geometría CFD, viabilidad de la celda de carga) se tratan en sus documentos respectivos, no aquí.

## 1. Descripción del problema

El desarrollo de sistemas de control para misiles y otros vehículos guiados requiere actuadores capaces de mover superficies de control bajo condiciones de carga representativas de su operación. El dimensionamiento de estos actuadores depende directamente de las cargas fluidodinámicas que experimentan dichas superficies durante el vuelo o la navegación.

Aunque actualmente existen herramientas avanzadas de simulación, como la Dinámica de Fluidos Computacional (CFD), que permiten estimar estas cargas, no siempre existe una metodología que permita trasladar dichos resultados al diseño y evaluación experimental de actuadores durante las etapas tempranas del desarrollo.

Como consecuencia, el diseño de bancos de ensayo suele requerir múltiples iteraciones, hipótesis conservadoras o sobredimensionamientos, incrementando el tiempo y los recursos necesarios para el desarrollo de nuevas tecnologías.

En este contexto, resulta de interés desarrollar un banco de ensayos que permita reproducir cargas obtenidas mediante simulación, facilitando el dimensionamiento y la caracterización de actuadores destinados al accionamiento de superficies de control.

## 2. Justificación

El desarrollo de actuadores para superficies de control requiere conocer con suficiente precisión las cargas a las que estarán sometidos durante su operación. En etapas tempranas del diseño, dichas cargas suelen estimarse mediante herramientas de simulación, mientras que la validación experimental normalmente se realiza en fases posteriores del desarrollo, cuando ya existen prototipos físicos.

La posibilidad de disponer de un banco de ensayos capaz de reproducir cargas obtenidas mediante simulación permitiría evaluar el desempeño de diferentes actuadores antes de la construcción de sistemas completos, reduciendo la incertidumbre asociada al proceso de selección y dimensionamiento. Esto favorece un desarrollo más eficiente, disminuye la necesidad de iteraciones de diseño y proporciona información experimental útil para la toma de decisiones.

Desde el punto de vista académico, el desarrollo de una metodología que vincule resultados de simulación CFD con ensayos experimentales constituye una contribución en la integración entre herramientas de simulación numérica y validación física. Además, la arquitectura modular propuesta permitiría adaptar el banco a distintas aplicaciones mediante la actualización de las tablas de cargas, sin requerir modificaciones sustanciales en la plataforma experimental.

Finalmente, el banco de ensayos propuesto puede constituir una plataforma de investigación y docencia para el estudio de actuadores de superficies de control, facilitando futuros trabajos relacionados con vehículos guiados en distintos medios, tales como sistemas aeroespaciales y submarinos.

## 3. Solución Propuesta

Se propone el desarrollo de un banco de ensayos para el dimensionamiento y caracterización de actuadores de superficies de control basado en cargas fluidodinámicas obtenidas mediante simulación CFD.

La metodología contempla la generación de tablas aerodinámicas mediante simulaciones CFD, su posterior procesamiento mediante un software de interpolación y la aplicación de las cargas equivalentes en un banco de ensayos instrumentado. El banco monta, en un mismo eje, un **motor de carga** (que aplica el torque equivalente derivado de CFD), un sensor de torque, el **actuador bajo prueba** y una **aleta física representativa**; esta última no experimenta carga aerodinámica real, sino que sirve como punto de medición del ángulo real alcanzado y como fuente de inercia/dinámica adicional que el actuador debe vencer bajo carga.

La arquitectura propuesta desacopla la simulación numérica del ensayo físico, permitiendo reutilizar el banco para distintas plataformas mediante la sustitución de las tablas de carga correspondientes.

## 4. Objetivo general

Diseñar e implementar un banco de ensayos para el **verificación** **y** **selección** dimensionamiento y caracterización de actuadores **COTS** de superficies de control utilizando cargas fluidodinámicas obtenidas mediante simulación **Computacional**.

## 5. Objetivos específicos

* **Caracterizar** el estado del arte de actuadores, bancos de ensayo y metodologías de simulación computacional relevantes para el proyecto.
* **Desarrollar** una metodología para obtener y procesar cargas fluidodinámicas mediante simulaciones computacionales.
* **Diseñar** la arquitectura mecánica, electrónica, de software y de control de la plataforma experimental.
* **Construir e instrumentar** el banco de ensayos.
* **Validar** la plataforma experimental mediante ensayos con actuadores de superficies de control. 

### 5bis. Propuesta de OE cortos, mapeados a entregable

| OE   | Redacción propuesta (corta, orientada a logro)                                                                                                        | Entregable asociado (§11)                                  |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| OE-1 | **Caracterizar** el estado del arte de actuadores, bancos de ensayo y metodologías de simulación computacional relevantes para el proyecto. | 1. Documento de especificación y requisitos                |
| OE-2 | **Desarrollar** una metodología para obtener y procesar cargas fluidodinámicas mediante simulaciones computacionales.                          | 2. Metodología de simulación computacional.               |
| OE-3 | **Diseñar** la arquitectura mecánica, electrónica, de software y de control de la plataforma experimental.                                    | 3. Diseño conceptual y detallado                           |
| OE-4 | **Construir e instrumentar** el banco de ensayos.                                                                                                | 4. Sistema experimental construido e instrumentado          |
| OE-5 | **Validar** la plataforma experimental mediante ensayos con actuadores de superficies de control.                                                | 5. Base de datos de resultados / 6. Informe de validación |

## 6. Alcance

El presente proyecto comprende el diseño, implementación y validación de una plataforma experimental destinada al dimensionamiento y caracterización de actuadores para superficies de control, utilizando como referencia cargas fluidodinámicas obtenidas mediante simulaciones CFD.

El desarrollo considera la generación de una metodología para obtener y procesar datos provenientes de simulaciones numéricas, transformándolos en tablas de carga que puedan ser utilizadas por la plataforma experimental para reproducir condiciones representativas de operación. Asimismo, contempla el diseño mecánico, electrónico y de control del banco de ensayos, la integración de sistemas de instrumentación y adquisición de datos, y el desarrollo del software necesario para la gestión de los ensayos.

La plataforma será validada mediante la realización de ensayos experimentales con uno o más actuadores representativos, evaluando su capacidad para aplicar cargas equivalentes, registrar variables de interés y generar información útil para el proceso de dimensionamiento y selección de actuadores.

La arquitectura propuesta se concibe como un sistema modular, permitiendo su adaptación a diferentes aplicaciones mediante la actualización de las tablas de carga obtenidas por simulación, sin requerir modificaciones sustanciales en la plataforma experimental.

### Incluye

* Diseño de la metodología de simulación compurtacional→ banco.
* Desarrollo de tablas de carga.
* Diseño mecánico del banco, incluyendo el montaje del conjunto motor de carga–sensor–actuador bajo prueba–aleta física representativa.
* Diseño electrónico e instrumentación.
* Desarrollo del software de control, incluyendo el recálculo de torque objetivo en tiempo real a partir de la posición angular real de la aleta.
* Construcción del prototipo.
* Validación experimental.
* Caracterización de actuadores.

### No incluye

* Desarrollo del actuador.
* Diseño del avión/misil/torpedo/drone.
* Desarrollo de algoritmos de guiado y navegación.
* Simulación de vuelo en tiempo real.
* Acoplamiento directo entre CFD y el banco de ensayos, entendido como: **no se ejecutan simulaciones CFD durante el ensayo**; la interpolación en tiempo real sobre la tabla de carga ya generada (recálculo según la posición real de la aleta, dentro del dominio ONLINE) no constituye un incumplimiento de esta exclusión.
* Diseño de una superficie de control específica de una plataforma o vehículo real. La **aleta física** montada en el banco es un **elemento representativo de prueba**, de geometría genérica, que no está vinculada al diseño de un misil, torpedo u otro vehículo en particular, ni experimenta carga aerodinámica real (no hay túnel de viento asociado al banco): su función es proporcionar un punto de medición del ángulo real alcanzado por el conjunto actuador–aleta bajo la carga aplicada por el motor de carga.

## 7. Usuarios objetivo

La plataforma experimental propuesta está orientada a usuarios vinculados al desarrollo, investigación y validación de sistemas con superficies de control, particularmente aquellos que requieren evaluar actuadores sometidos a cargas equivalentes a las condiciones de operación esperadas.

### Usuario Principal

Ingenieros e investigadores encargados del diseño y evaluación de actuadores para superficies de control, quienes requieren una herramienta experimental que permita validar el desempeño de estos componentes bajo condiciones de carga representativas obtenidas mediante simulación.

### 1. Centros de investigación y universidades

Corresponden a instituciones dedicadas al estudio de sistemas aeroespaciales, robótica, vehículos autónomos y tecnologías de control. Estos usuarios podrían emplear la plataforma como herramienta experimental para estudiar el comportamiento de actuadores, validar modelos numéricos y desarrollar metodologías de ensayo.

La naturaleza modular del banco permitiría su utilización en distintas líneas de investigación mediante la actualización de las condiciones de carga aplicadas.

### 2. Departamentos de ingeniería y desarrollo de sistemas aeroespaciales

Equipos encargados del diseño preliminar de vehículos guiados o sistemas con superficies de control podrían utilizar la plataforma para evaluar alternativas de actuadores antes de la integración en un prototipo completo.

El banco permitiría reducir incertidumbres asociadas a la selección de componentes, entregando información experimental sobre variables como capacidad de torque, respuesta dinámica, consumo energético y desempeño bajo carga.

### 3. Empresas de desarrollo tecnológico e ingeniería aplicada

Empresas dedicadas al diseño de vehículos autónomos, sistemas aeroespaciales, robótica o plataformas móviles podrían utilizar una herramienta de este tipo durante etapas tempranas de desarrollo, disminuyendo la necesidad de construir prototipos completos para validar componentes individuales.

### 4. Laboratorios de docencia avanzada

La plataforma también puede ser utilizada como recurso académico para la formación de estudiantes en áreas como:

diseño mecánico,
instrumentación,
adquisición de datos,
sistemas electromecánicos,
simulación CFD,
validación experimental.

## 8. Contexto de aplicación

El desarrollo de vehículos guiados y sistemas con superficies de control requiere la integración de múltiples subsistemas, dentro de los cuales los actuadores cumplen un rol fundamental al permitir el movimiento preciso de las superficies responsables de modificar la trayectoria del vehículo. El correcto dimensionamiento de estos componentes depende de la capacidad de estimar y validar las cargas a las que estarán sometidos durante las condiciones de operación.

En las etapas iniciales de diseño, las cargas aerodinámicas suelen obtenerse mediante herramientas de simulación numérica, particularmente mediante Dinámica de Fluidos Computacional (CFD). Estas metodologías permiten estimar los esfuerzos y momentos generados sobre las superficies de control bajo diferentes condiciones de operación, proporcionando información relevante para la selección preliminar de actuadores.

Sin embargo, la transición desde resultados numéricos hacia la validación experimental presenta desafíos, debido a que los ensayos de sistemas completos requieren prototipos de mayor complejidad y recursos elevados. En este contexto, surge la necesidad de disponer de plataformas experimentales capaces de reproducir condiciones de carga representativas sobre componentes individuales, permitiendo evaluar su desempeño antes de la integración del sistema completo.

La plataforma propuesta se enmarca dentro de las etapas tempranas de desarrollo de sistemas aeroespaciales y vehículos guiados, donde la reducción de incertidumbre en la selección y caracterización de componentes resulta fundamental para disminuir tiempos de desarrollo y mejorar la confiabilidad del diseño.

Además, debido a su arquitectura modular, la aplicación de la plataforma no se limita exclusivamente a un tipo específico de vehículo, pudiendo adaptarse a distintos sistemas que empleen superficies de control accionadas, tales como vehículos aéreos no tripulados, vehículos guiados, sistemas aeroespaciales experimentales y otras aplicaciones donde sea necesario evaluar actuadores sometidos a cargas externas variables.

## 9. Hipótesis de trabajo

La implementación de un banco de ensayos basado en cargas fluidodinámicas equivalentes permitirá evaluar experimentalmente actuadores de superficies de control, proporcionando parámetros de desempeño que pueden ser utilizados como apoyo al proceso de dimensionamiento y selección de estos componentes.

**Nota metodológica (acuerdo 28/08/2026):** los profesores guía enfatizaron explícitamente "no casarse con la CFD" como fuente única de validación de esta hipótesis. Esto es consistente con el principio ya formalizado en `00_Principios_Metodologicos.md` ("hacer que funcione antes de que funcione bien") y con el uso del dataset de contingencia XFLR5: la hipótesis se sostiene con evidencia CFD propia cuando esté disponible, pero no depende exclusivamente de ella para avanzar en las demás fases del proyecto.

## 10. Riesgos

El desarrollo de una plataforma experimental para el dimensionamiento y caracterización de actuadores presenta diversos riesgos asociados a la integración entre simulación numérica, diseño experimental e implementación física. La identificación temprana de estos riesgos permite establecer estrategias de mitigación que favorezcan el cumplimiento de los objetivos del proyecto.

### 1. Incertidumbre en la obtención de cargas fluidodinámicas

**Descripción:**
Los resultados obtenidos mediante simulaciones CFD dependen de la correcta definición del modelo numérico, las condiciones de operación y los modelos físicos utilizados. Una representación inadecuada del fenómeno puede generar cargas que no sean representativas de las condiciones reales de operación.

**Impacto:**
Las cargas utilizadas como referencia para los ensayos podrían presentar errores, afectando la validez de la caracterización experimental de los actuadores.

**Mitigación:**
Establecer una metodología de simulación validada, definir adecuadamente los parámetros de entrada y realizar análisis de sensibilidad sobre las variables más influyentes.

---

### 2. Dificultad en la reproducción experimental de las cargas objetivo

**Descripción:**
La transformación de cargas aerodinámicas obtenidas mediante CFD hacia un sistema físico puede presentar diferencias debido a limitaciones mecánicas, dinámicas o de control del banco de ensayos. En particular, al enfrentar dos motores en un mismo eje (motor de carga vs. actuador bajo prueba), el movimiento del actuador induce un torque parásito sobre el motor de carga que puede degradar la fidelidad del torque aplicado; adicionalmente, ambos motores pueden llegar a oponerse de forma sostenida (atasco mutuo).

**Impacto:**
La plataforma podría no representar adecuadamente las condiciones de carga esperadas, reduciendo la utilidad de los ensayos. Un atasco mutuo no detectado podría además dañar el actuador bajo prueba o la estructura del banco.

**Mitigación:**
Definir una arquitectura de aplicación de carga adecuada, incorporar instrumentación para verificar las condiciones aplicadas y realizar procesos de calibración experimental. Específicamente, se adopta: (a) una estrategia de compensación activa del torque parásito (feedforward o sincronización de velocidad, ver Tema 2 de la revisión de literatura), y (b) una protección de atasco mutuo que detiene automáticamente la aplicación de carga ante torque diferencial sostenido sin cambio de posición de la aleta (RF-BAN-06 / RNF-SEG-04).

---

### 3. Limitaciones en la selección de componentes del banco

**Descripción:**
La selección de elementos mecánicos, actuadores auxiliares, sensores y sistemas electrónicos puede presentar restricciones asociadas a disponibilidad, capacidad o compatibilidad entre componentes.

**Impacto:**
Puede ser necesario modificar el diseño inicial del banco o reducir las capacidades esperadas de la plataforma.

**Mitigación:**
Realizar una etapa previa de especificación de requerimientos y selección de componentes comerciales disponibles, considerando márgenes adecuados de operación.

---

### 4. Complejidad del desarrollo del sistema de control e instrumentación

**Descripción:**
La integración entre sensores, adquisición de datos y control de la aplicación de carga puede requerir un nivel de desarrollo superior al inicialmente estimado. El recálculo del torque objetivo en tiempo real a partir de la posición angular real de la aleta (en lugar de un perfil temporal fijo) añade complejidad adicional al lazo de control respecto a un esquema de referencia precalculada.

**Impacto:**
Retrasos en la implementación o reducción de las capacidades de automatización del banco.

**Mitigación:**
Diseñar una arquitectura modular, utilizar plataformas de desarrollo conocidas y priorizar las funcionalidades necesarias para la validación experimental.

---

### 5. Disponibilidad limitada de recursos para fabricación y validación

**Descripción:**
La construcción del prototipo puede verse condicionada por disponibilidad de equipamiento, materiales, componentes electrónicos o infraestructura de laboratorio.

**Impacto:**
Retrasos en la fabricación, integración y ejecución de ensayos experimentales.

**Mitigación:**
Priorizar un diseño de bajo costo y modular, utilizando componentes comerciales cuando sea posible y planificando alternativas de fabricación.

---

### 6. Validación experimental insuficiente

**Descripción:**
La cantidad de ensayos realizados o la disponibilidad de actuadores representativos puede limitar la evaluación completa de la plataforma.

**Impacto:**
La validación podría demostrar únicamente la funcionalidad básica del banco, sin cubrir todo el rango de aplicaciones previsto.

**Mitigación:**
Definir criterios de validación claros y seleccionar ensayos representativos que permitan evaluar las capacidades principales del sistema.

## 11. Entregables

El desarrollo de la plataforma experimental contempla la generación de entregables asociados al diseño, implementación y validación del sistema propuesto. Estos permiten verificar el cumplimiento de los objetivos planteados y documentar la metodología desarrollada.

### 1. Documento de especificación y requisitos de la plataforma experimental

Documento que establece los requerimientos funcionales y técnicos del banco de ensayos, considerando las capacidades necesarias para la aplicación de cargas equivalentes, instrumentación, adquisición de datos y evaluación de actuadores.

### 2. Metodología de generación y procesamiento de cargas fluidodinámicas

Metodología documentada para la obtención de cargas mediante simulaciones CFD, incluyendo la definición de condiciones de operación, procesamiento de resultados y generación de tablas de carga utilizables por la plataforma experimental.

### 3. Diseño conceptual y detallado del banco de ensayos

Conjunto de documentos de diseño mecánico, electrónico y de integración de la plataforma experimental, incluyendo modelos CAD, planos, selección de componentes y arquitectura general del sistema.

### 4. Sistema experimental construido e instrumentado

Prototipo físico del banco de ensayos implementado con los elementos mecánicos, actuadores de carga, sensores, sistemas electrónicos y elementos necesarios para la ejecución de pruebas experimentales.

### 5. Software de operación, control y adquisición de datos

Herramienta informática desarrollada para la gestión de los ensayos, incluyendo la interpretación de tablas de carga, generación de referencias, comunicación con el sistema experimental y registro de variables medidas.

### 6. Base de datos de resultados experimentales

Conjunto de datos obtenidos durante los ensayos de validación, incluyendo mediciones relevantes del comportamiento de los actuadores bajo diferentes condiciones de carga.

### 7. Informe de validación experimental de la plataforma

Documento que presenta los resultados obtenidos durante las pruebas experimentales, evaluando la capacidad del banco para reproducir cargas objetivo y generar información útil para la caracterización y apoyo al dimensionamiento de actuadore

# Especificación del Proyecto

## 1. Descripción del problema

El desarrollo de sistemas de control para misiles y otros vehículos guiados requiere actuadores capaces de mover superficies de control bajo condiciones de carga representativas de su operación. El dimensionamiento de estos actuadores depende directamente de las cargas fluidodinámicas que experimentan dichas superficies durante el vuelo o la navegación.

Aunque actualmente existen herramientas avanzadas de simulación, como la Dinámica de Fluidos Computacional (CFD), que permiten estimar estas cargas, no siempre existe una metodología que permita trasladar dichos resultados al diseño y evaluación experimental de actuadores durante las etapas tempranas del desarrollo.

Como consecuencia, el diseño de bancos de ensayo suele requerir múltiples iteraciones, hipótesis conservadoras o sobredimensionamientos, incrementando el tiempo y los recursos necesarios para el desarrollo de nuevas tecnologías.

En este contexto, resulta de interés desarrollar un banco de ensayos que permita reproducir cargas obtenidas mediante simulación, facilitando el dimensionamiento y la caracterización de actuadores destinados al accionamiento de superficies de control.

## 2. Justificación

El desarrollo de actuadores para superficies de control requiere conocer con suficiente precisión las cargas a las que estarán sometidos durante su operación. En etapas tempranas del diseño, dichas cargas suelen estimarse mediante herramientas de simulación, mientras que la validación experimental normalmente se realiza en fases posteriores del desarrollo, cuando ya existen prototipos físicos.

La posibilidad de disponer de un banco de ensayos capaz de reproducir cargas obtenidas mediante simulación permitiría evaluar el desempeño de diferentes actuadores antes de la construcción de sistemas completos, reduciendo la incertidumbre asociada al proceso de selección y dimensionamiento. Esto favorece un desarrollo más eficiente, disminuye la necesidad de iteraciones de diseño y proporciona información experimental útil para la toma de decisiones.

Desde el punto de vista académico, el desarrollo de una metodología que vincule resultados de simulación CFD con ensayos experimentales constituye una contribución en la integración entre herramientas de simulación numérica y validación física. Además, la arquitectura modular propuesta permitiría adaptar el banco a distintas aplicaciones mediante la actualización de las tablas de cargas, sin requerir modificaciones sustanciales en la plataforma experimental.

Finalmente, el banco de ensayos propuesto puede constituir una plataforma de investigación y docencia para el estudio de actuadores de superficies de control, facilitando futuros trabajos relacionados con vehículos guiados en distintos medios, tales como sistemas aeroespaciales y submarinos.

## 3. Solución Propuesta

Se propone el desarrollo de un banco de ensayos para el dimensionamiento y caracterización de actuadores de superficies de control basado en cargas fluidodinámicas obtenidas mediante simulación CFD.

La metodología contempla la generación de tablas aerodinámicas mediante simulaciones CFD, su posterior procesamiento mediante un software de interpolación y la aplicación de las cargas equivalentes en un banco de ensayos instrumentado. El banco monta, en un mismo eje, un **motor de carga** (que aplica el torque equivalente derivado de CFD), un sensor de torque, el **actuador bajo prueba** y una **aleta física representativa**; esta última no experimenta carga aerodinámica real, sino que sirve como punto de medición del ángulo real alcanzado y como fuente de inercia/dinámica adicional que el actuador debe vencer bajo carga.

La arquitectura propuesta desacopla la simulación numérica del ensayo físico, permitiendo reutilizar el banco para distintas plataformas mediante la sustitución de las tablas de carga correspondientes.

## 4. Objetivo general

Diseñar e implementar un banco de ensayos para el **verificación** **y** **selección** dimensionamiento y caracterización de actuadores **COTS** de superficies de control utilizando cargas fluidodinámicas obtenidas mediante simulación **Computacional**.

## 5. Objetivos específicos

* **Analizar** el estado del arte de los actuadores electromecánicos para superficies de control y de los bancos de ensayo tipo dinamómetro de escala comparable (motor de carga + sensor de torque + actuador bajo prueba), así como las metodologías de obtención de cargas mediante CFD —incluyendo métodos de predicción de momento de bisagra, estrategias de reducción del número de simulaciones necesarias (muestreo adaptativo, modelos sustitutos (surrogate models) tipo kriging/splines) y técnicas de interpolación multidimensional—, con el fin de establecer los requisitos de diseño de la plataforma experimental.
* **Desarrollar** una metodología para obtener y procesar cargas fluidodinámicas mediante simulaciones CFD, considerando explícitamente como variables de entrada el número de Mach, el ángulo de ataque, la deflexión angular de la superficie de control **y su velocidad angular de deflexión**, y como variable de salida el torque de bisagra resultante, generando tablas aerodinámicas multidimensionales utilizables en el banco de ensayos.
* **Diseñar** la arquitectura mecánica, electrónica y de control de la plataforma experimental para aplicar las cargas equivalentes sobre actuadores de superficies de control, incluyendo (a) la instrumentación necesaria para medir en tiempo real tanto la posición angular como la velocidad angular real de la aleta, y (b) una interfaz de entradas manuales mediante potenciómetros físicos que permita al operador fijar, en modo manual, los valores de las variables de entrada de la tabla de carga (p. ej. velocidad de flujo/Mach, ángulo de ataque) de forma independiente del lazo de realimentación automático.
* **Implementar** el software de procesamiento e integración encargado de interpretar las tablas de carga multidimensionales (Mach, ángulo de ataque, deflexión, velocidad angular de deflexión), leer las entradas provistas por el panel de potenciómetros en modo manual, y suministrar las referencias de torque necesarias para la ejecución de los ensayos.
* **Construir e instrumentar** el banco de ensayos, incorporando los sensores (torque, posición y velocidad angular de la aleta, variables eléctricas del actuador) y los sistemas de adquisición de datos necesarios para la caracterización experimental de los actuadores, junto con el panel de potenciómetros de entrada manual.
* **Validar** la plataforma experimental mediante ensayos con actuadores de superficies de control, evaluando su capacidad para reproducir las cargas objetivo —incluyendo condiciones con velocidad angular de deflexión variable— y generar información útil para el dimensionamiento.

## 6. Alcance

El presente proyecto comprende el diseño, implementación y validación de una plataforma experimental destinada al dimensionamiento y caracterización de actuadores para superficies de control, utilizando como referencia cargas fluidodinámicas obtenidas mediante simulaciones CFD.

El desarrollo considera la generación de una metodología para obtener y procesar datos provenientes de simulaciones numéricas, transformándolos en tablas de carga que puedan ser utilizadas por la plataforma experimental para reproducir condiciones representativas de operación. Asimismo, contempla el diseño mecánico, electrónico y de control del banco de ensayos, la integración de sistemas de instrumentación y adquisición de datos, y el desarrollo del software necesario para la gestión de los ensayos.

La plataforma será validada mediante la realización de ensayos experimentales con uno o más actuadores representativos, evaluando su capacidad para aplicar cargas equivalentes, registrar variables de interés y generar información útil para el proceso de dimensionamiento y selección de actuadores.

La arquitectura propuesta se concibe como un sistema modular, permitiendo su adaptación a diferentes aplicaciones mediante la actualización de las tablas de carga obtenidas por simulación, sin requerir modificaciones sustanciales en la plataforma experimental.

### Incluye

* Diseño de la metodología CFD → banco.
* Desarrollo de tablas de carga.
* Diseño mecánico del banco, incluyendo el montaje del conjunto motor de carga–sensor–actuador bajo prueba–aleta física representativa.
* Diseño electrónico e instrumentación.
* Desarrollo del software de control, incluyendo el recálculo de torque objetivo en tiempo real a partir de la posición angular real de la aleta.
* Construcción del prototipo.
* Validación experimental.
* Caracterización de actuadores.

### No incluye

* Desarrollo del actuador.
* Diseño del avión/misil/torpedo/drone.
* Desarrollo de algoritmos de guiado y navegación.
* Simulación de vuelo en tiempo real.
* Acoplamiento directo entre CFD y el banco de ensayos, entendido como: **no se ejecutan simulaciones CFD durante el ensayo**; la interpolación en tiempo real sobre la tabla de carga ya generada (recálculo según la posición real de la aleta, dentro del dominio ONLINE) no constituye un incumplimiento de esta exclusión.
* Diseño de una superficie de control específica de una plataforma o vehículo real. La **aleta física** montada en el banco es un **elemento representativo de prueba**, de geometría genérica, que no está vinculada al diseño de un misil, torpedo u otro vehículo en particular, ni experimenta carga aerodinámica real (no hay túnel de viento asociado al banco): su función es proporcionar un punto de medición del ángulo real alcanzado por el conjunto actuador–aleta bajo la carga aplicada por el motor de carga.

## 7. Usuarios objetivo

La plataforma experimental propuesta está orientada a usuarios vinculados al desarrollo, investigación y validación de sistemas con superficies de control, particularmente aquellos que requieren evaluar actuadores sometidos a cargas equivalentes a las condiciones de operación esperadas.

### Usuario Principal

Ingenieros e investigadores encargados del diseño y evaluación de actuadores para superficies de control, quienes requieren una herramienta experimental que permita validar el desempeño de estos componentes bajo condiciones de carga representativas obtenidas mediante simulación.

### 1. Centros de investigación y universidades

Corresponden a instituciones dedicadas al estudio de sistemas aeroespaciales, robótica, vehículos autónomos y tecnologías de control. Estos usuarios podrían emplear la plataforma como herramienta experimental para estudiar el comportamiento de actuadores, validar modelos numéricos y desarrollar metodologías de ensayo.

La naturaleza modular del banco permitiría su utilización en distintas líneas de investigación mediante la actualización de las condiciones de carga aplicadas.

### 2. Departamentos de ingeniería y desarrollo de sistemas aeroespaciales

Equipos encargados del diseño preliminar de vehículos guiados o sistemas con superficies de control podrían utilizar la plataforma para evaluar alternativas de actuadores antes de la integración en un prototipo completo.

El banco permitiría reducir incertidumbres asociadas a la selección de componentes, entregando información experimental sobre variables como capacidad de torque, respuesta dinámica, consumo energético y desempeño bajo carga.

### 3. Empresas de desarrollo tecnológico e ingeniería aplicada

Empresas dedicadas al diseño de vehículos autónomos, sistemas aeroespaciales, robótica o plataformas móviles podrían utilizar una herramienta de este tipo durante etapas tempranas de desarrollo, disminuyendo la necesidad de construir prototipos completos para validar componentes individuales.

### 4. Laboratorios de docencia avanzada

La plataforma también puede ser utilizada como recurso académico para la formación de estudiantes en áreas como:

diseño mecánico,
instrumentación,
adquisición de datos,
sistemas electromecánicos,
simulación CFD,
validación experimental.

## 8. Contexto de aplicación

El desarrollo de vehículos guiados y sistemas con superficies de control requiere la integración de múltiples subsistemas, dentro de los cuales los actuadores cumplen un rol fundamental al permitir el movimiento preciso de las superficies responsables de modificar la trayectoria del vehículo. El correcto dimensionamiento de estos componentes depende de la capacidad de estimar y validar las cargas a las que estarán sometidos durante las condiciones de operación.

En las etapas iniciales de diseño, las cargas aerodinámicas suelen obtenerse mediante herramientas de simulación numérica, particularmente mediante Dinámica de Fluidos Computacional (CFD). Estas metodologías permiten estimar los esfuerzos y momentos generados sobre las superficies de control bajo diferentes condiciones de operación, proporcionando información relevante para la selección preliminar de actuadores.

Sin embargo, la transición desde resultados numéricos hacia la validación experimental presenta desafíos, debido a que los ensayos de sistemas completos requieren prototipos de mayor complejidad y recursos elevados. En este contexto, surge la necesidad de disponer de plataformas experimentales capaces de reproducir condiciones de carga representativas sobre componentes individuales, permitiendo evaluar su desempeño antes de la integración del sistema completo.

La plataforma propuesta se enmarca dentro de las etapas tempranas de desarrollo de sistemas aeroespaciales y vehículos guiados, donde la reducción de incertidumbre en la selección y caracterización de componentes resulta fundamental para disminuir tiempos de desarrollo y mejorar la confiabilidad del diseño.

Además, debido a su arquitectura modular, la aplicación de la plataforma no se limita exclusivamente a un tipo específico de vehículo, pudiendo adaptarse a distintos sistemas que empleen superficies de control accionadas, tales como vehículos aéreos no tripulados, vehículos guiados, sistemas aeroespaciales experimentales y otras aplicaciones donde sea necesario evaluar actuadores sometidos a cargas externas variables.

## 9. Hipótesis de trabajo

La implementación de un banco de ensayos basado en cargas fluidodinámicas equivalentes permitirá evaluar experimentalmente actuadores de superficies de control, proporcionando parámetros de desempeño que pueden ser utilizados como apoyo al proceso de dimensionamiento y selección de estos componentes.

## 10. Riesgos

El desarrollo de una plataforma experimental para el dimensionamiento y caracterización de actuadores presenta diversos riesgos asociados a la integración entre simulación numérica, diseño experimental e implementación física. La identificación temprana de estos riesgos permite establecer estrategias de mitigación que favorezcan el cumplimiento de los objetivos del proyecto.

### 1. Incertidumbre en la obtención de cargas fluidodinámicas

**Descripción:**
Los resultados obtenidos mediante simulaciones CFD dependen de la correcta definición del modelo numérico, las condiciones de operación y los modelos físicos utilizados. Una representación inadecuada del fenómeno puede generar cargas que no sean representativas de las condiciones reales de operación.

**Impacto:**
Las cargas utilizadas como referencia para los ensayos podrían presentar errores, afectando la validez de la caracterización experimental de los actuadores.

**Mitigación:**
Establecer una metodología de simulación validada, definir adecuadamente los parámetros de entrada y realizar análisis de sensibilidad sobre las variables más influyentes.

---

### 2. Dificultad en la reproducción experimental de las cargas objetivo

**Descripción:**
La transformación de cargas aerodinámicas obtenidas mediante CFD hacia un sistema físico puede presentar diferencias debido a limitaciones mecánicas, dinámicas o de control del banco de ensayos. En particular, al enfrentar dos motores en un mismo eje (motor de carga vs. actuador bajo prueba), el movimiento del actuador induce un torque parásito sobre el motor de carga que puede degradar la fidelidad del torque aplicado; adicionalmente, ambos motores pueden llegar a oponerse de forma sostenida (atasco mutuo).

**Impacto:**
La plataforma podría no representar adecuadamente las condiciones de carga esperadas, reduciendo la utilidad de los ensayos. Un atasco mutuo no detectado podría además dañar el actuador bajo prueba o la estructura del banco.

**Mitigación:**
Definir una arquitectura de aplicación de carga adecuada, incorporar instrumentación para verificar las condiciones aplicadas y realizar procesos de calibración experimental. Específicamente, se adopta: (a) una estrategia de compensación activa del torque parásito (feedforward o sincronización de velocidad, ver Tema 2 de la revisión de literatura), y (b) una protección de atasco mutuo que detiene automáticamente la aplicación de carga ante torque diferencial sostenido sin cambio de posición de la aleta (RF-BAN-06 / RNF-SEG-04).

---

### 3. Limitaciones en la selección de componentes del banco

**Descripción:**
La selección de elementos mecánicos, actuadores auxiliares, sensores y sistemas electrónicos puede presentar restricciones asociadas a disponibilidad, capacidad o compatibilidad entre componentes.

**Impacto:**
Puede ser necesario modificar el diseño inicial del banco o reducir las capacidades esperadas de la plataforma.

**Mitigación:**
Realizar una etapa previa de especificación de requerimientos y selección de componentes comerciales disponibles, considerando márgenes adecuados de operación.

---

### 4. Complejidad del desarrollo del sistema de control e instrumentación

**Descripción:**
La integración entre sensores, adquisición de datos y control de la aplicación de carga puede requerir un nivel de desarrollo superior al inicialmente estimado. El recálculo del torque objetivo en tiempo real a partir de la posición angular real de la aleta (en lugar de un perfil temporal fijo) añade complejidad adicional al lazo de control respecto a un esquema de referencia precalculada.

**Impacto:**
Retrasos en la implementación o reducción de las capacidades de automatización del banco.

**Mitigación:**
Diseñar una arquitectura modular, utilizar plataformas de desarrollo conocidas y priorizar las funcionalidades necesarias para la validación experimental.

---

### 5. Disponibilidad limitada de recursos para fabricación y validación

**Descripción:**
La construcción del prototipo puede verse condicionada por disponibilidad de equipamiento, materiales, componentes electrónicos o infraestructura de laboratorio.

**Impacto:**
Retrasos en la fabricación, integración y ejecución de ensayos experimentales.

**Mitigación:**
Priorizar un diseño de bajo costo y modular, utilizando componentes comerciales cuando sea posible y planificando alternativas de fabricación.

---

### 6. Validación experimental insuficiente

**Descripción:**
La cantidad de ensayos realizados o la disponibilidad de actuadores representativos puede limitar la evaluación completa de la plataforma.

**Impacto:**
La validación podría demostrar únicamente la funcionalidad básica del banco, sin cubrir todo el rango de aplicaciones previsto.

**Mitigación:**
Definir criterios de validación claros y seleccionar ensayos representativos que permitan evaluar las capacidades principales del sistema.

## 11. Entregables

El desarrollo de la plataforma experimental contempla la generación de entregables asociados al diseño, implementación y validación del sistema propuesto. Estos permiten verificar el cumplimiento de los objetivos planteados y documentar la metodología desarrollada.

### 1. Documento de especificación y requisitos de la plataforma experimental

Documento que establece los requerimientos funcionales y técnicos del banco de ensayos, considerando las capacidades necesarias para la aplicación de cargas equivalentes, instrumentación, adquisición de datos y evaluación de actuadores.

### 2. Metodología de generación y procesamiento de cargas fluidodinámicas

Metodología documentada para la obtención de cargas mediante simulaciones CFD, incluyendo la definición de condiciones de operación, procesamiento de resultados y generación de tablas de carga utilizables por la plataforma experimental.

### 3. Diseño conceptual y detallado del banco de ensayos

Conjunto de documentos de diseño mecánico, electrónico y de integración de la plataforma experimental, incluyendo modelos CAD, planos, selección de componentes y arquitectura general del sistema.

### 4. Sistema experimental construido e instrumentado

Prototipo físico del banco de ensayos implementado con los elementos mecánicos, actuadores de carga, sensores, sistemas electrónicos y elementos necesarios para la ejecución de pruebas experimentales.

### 5. Software de operación, control y adquisición de datos

Herramienta informática desarrollada para la gestión de los ensayos, incluyendo la interpretación de tablas de carga, generación de referencias, comunicación con el sistema experimental y registro de variables medidas.

### 6. Base de datos de resultados experimentales

Conjunto de datos obtenidos durante los ensayos de validación, incluyendo mediciones relevantes del comportamiento de los actuadores bajo diferentes condiciones de carga.

### 7. Informe de validación experimental de la plataforma

Documento que presenta los resultados obtenidos durante las pruebas experimentales, evaluando la capacidad del banco para reproducir cargas objetivo y generar información útil para la caracterización y apoyo al dimensionamiento de actuadores.
