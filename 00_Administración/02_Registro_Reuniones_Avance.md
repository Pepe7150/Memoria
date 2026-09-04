# Registro de Reuniones de Avance

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Objetivo de este documento:** llevar trazabilidad de las preguntas planteadas a los profesores guía (Bernardo Hernández, Frank Tinnap) en cada reunión de avance, y de los acuerdos/respuestas obtenidos, de modo que las decisiones de diseño puedan citarse con fecha y contexto en el resto de la documentación del proyecto.

---

## Reunión 21/08/2026

**Estado:** Completada. Acuerdos ya incorporados en la documentación del proyecto.

**Acuerdos:**

1. Se amplían los objetivos específicos de OE-1 a OE-6 (ver `01_Especificacion_del_Proyecto.md`, §5).
2. Se agrega la **velocidad de deflexión angular** como una cuarta dimensión de la superficie de respuesta CFD (junto a Mach, ángulo, deflexión) — impacta directamente la definición de la matriz de casos CFD (Fase B1 del cronograma) y la lista de pendientes analíticamente resolubles del proyecto.
3. Se agrega un **panel de potenciómetros manual** como interfaz de entrada: I-11 (condición de vuelo) e I-12 (comando del actuador bajo prueba) — ver `05_Arquitectura_del_Sistema.md`.
4. Se realizan ejercicios de flujo potencial con distintos objetos de estudio. Disponible en la carpeta 00_XFLR5.

---

## Reunión 28/08/2026

**Estado:** Completada. Acuerdos incorporados progresivamente en la documentación del proyecto (ver notas de propagación en cada punto, y el resumen consolidado al inicio de este documento).

**Preguntas a plantear:**

1. **Degeneración AoA/deflexión en modelo de aleta aislada.** Al no incluir fuselaje ni otra geometría de referencia en el modelo (ni en XFLR5 ni, previsiblemente, en la CFD propia dado que el alcance del proyecto excluye modelar el vehículo/misil completo), el modelo no puede distinguir entre ángulo de ataque del vehículo y deflexión de la aleta — son la misma variable física vista desde dos marcos de referencia distintos, y solo se separan cuando existe un tercer objeto (el fuselaje) contra el cual medir cada ángulo por separado. ¿Confirman que la matriz de casos CFD debe parametrizarse con un **único ángulo total** (no AoA y deflexión por separado)?
2. **Relacionado:** si en algún momento se requiere la separación real AoA/deflexión (p. ej. para un caso de uso específico del contexto de aplicación que estén evaluando), esto implicaría modelar el vehículo completo (fuselaje incluido), lo cual excede el alcance actual del proyecto (`01_Especificacion_del_Proyecto.md`, "No incluye": *"Diseño del misil o torpedo"*). ¿Se mantiene la aleta aislada como supuesto de modelado, o se prevé incorporar geometría de fuselaje en algún momento?
3. **Confirmación sobre el posible cambio de objeto de diseño hacia un proyecto UAV del laboratorio** (mencionado informalmente por los profesores): de concretarse, ¿qué pasa con el trabajo ya avanzado sobre la geometría de referencia de Nalci & Kayran (perfil doble cuña, escala, valores de XFLR5)? ¿Se reemplaza íntegramente, o se mantiene como ejercicio metodológico documentado mientras se define la nueva geometría de referencia?
4. **Alcance de XFLR5 como fuente de datos de contingencia.** Se confirmó que XFLR5 (análisis de polares estático/cuasi-estacionario) solo puede proveer 2 de las 4 dimensiones acordadas en el punto 2 del Avance I (Mach y ángulo total — no AoA/deflexión por separado, no velocidad de deflexión angular, que requiere CFD no estacionaria). ¿Es aceptable usar un dataset de XFLR5 con estas 2 dimensiones como plan de contingencia/prueba del pipeline de software, dejando explícito que no reemplaza la caracterización CFD completa?
5. **Altitud como variable de entrada — ausente de la especificación actual.** Se detectó que la tabla de carga (RF-CFD-02) no incluye la altitud como variable de entrada (solo Mach, AoA, deflexión), aunque el momento de bisagra sí depende de la altitud a igual Mach (vía la presión dinámica). En el modelo de flujo potencial (XFLR5) esto se resuelve analíticamente sin necesidad de nuevas corridas — pero en la CFD viscosa propia (Fase B), el número de Reynolds sí depende de la altitud y podría introducir una dependencia real, no solo de escala, en el coeficiente de momento. **¿El banco debe representar múltiples altitudes de operación, o se fija una condición de referencia única (p. ej. nivel del mar) para todo el proyecto?** Respuesta preliminar propia: sí debería considerarse (al menos como verificación de que el efecto es solo de escala y no de forma), pero se quiere confirmar con los profesores antes de comprometer la arquitectura de la tabla de carga.
6. **La corriente si controla el torque de motores DC.** En la reunión anterior se señaló que no se puede controlar el torque directamente de un motor DC, pero si se puede. Al aumentar el voltaje es que suben los rpm.
7. **Diagramas de las alternativas de arquitectura física.** Se tienen los diagramas de ambas alternativas y sus variantes internas.

**Respuestas / acuerdos:**

1. A lo mejor es mejor que funcione a que funcione bien. Primero tiene que existir y después si se puede que funcione bien. Aquí calza bien lo del flujo potencial.
2. Ala con flap, Aoa y deflexión separados.
3. No casarse con CFD.
4. Parece que la celda de carga no es viable porque no permite cambio de angulo, puede ser con torquimetro o strain gauges.
5. Que cada OE tenga un entregable relacionado.
6. Revisar los OE, quedaron muy largos y deben ser algo que se quiere lograr, no solo un plan de trabajo.
7. Hablar con Tapia electrónicos, Lanziotti o vicuña.

## Reunión 04/09/2026

**Estado:** Por realizar (viernes).

**Contexto de entrada a esta reunión:** toda la documentación del proyecto (`03_Requisitos/`, `04_CFD/`, `05_Diseño_Mecánico/`, `01_Documentos_Memoria/`) fue revisada y actualizada para reflejar consistentemente los acuerdos de la reunión del 28/08/2026 (ver resumen de propagación al inicio de este documento). Los puntos que siguen abajo son, en su mayoría, continuaciones directas de los pendientes que esa propagación dejó abiertos — no preguntas nuevas sin relación con lo ya acordado.

**Preguntas a plantear:**

1. **Cierre de la reevaluación del sensor de torque (acuerdo #4).** ¿Se define ya una dirección concreta (torquímetro inline, strain gauges sobre el eje, o un ajuste al esquema de brazo de palanca que resuelva el problema del ángulo variable)? De esto depende poder cerrar RNF-CAR-01, RNF-PRE-02, RNF-PRE-04 y continuar con `09_Verificacion_Mecanica_Brazo_Torque.md`*Yo recomiendo las strain gauges porque el brazo con celda de carga no permite la variación de ángulo y el torquímtero inline es muy caro. `10_Estrategia_estimacion_torque.md`*
2. **Relacionado con lo anterior:** ¿la decisión de sensor de torque es independiente de la reevaluación de arquitectura de motor de carga (A/B/C), o están acopladas? (pregunta ya registrada en `Comparacion_Alternativas_Arquitectura_Fisica.md` §5, punto 5).   					*Creo que van acoplados pues si descartamos la celda de carga tendría que ser descartada la opción C.*
3. **Cierre de la reevaluación de arquitectura física del motor de carga (A/B/C).** ¿Hay avance desde la matriz de decisión ponderada (`Matriz_Decision_Arquitectura_Banco.xlsx`)? En particular, la pregunta 3 de la reunión anterior sobre si vale la pena medir experimentalmente el ancho de banda de la Opción A actual antes de decidir un cambio de arquitectura.
4. **Geometría de referencia CFD (Simpson vs. Nalci & Kayran) — confirmación.** El proyecto ya adoptó a Simpson (2016), NACA 0012 con flap, como geometría de referencia activa (`04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md`, reescrito 28/08). ¿Los profesores están de acuerdo con este reemplazo tal como quedó documentado, o falta algún ajuste? 			*Si están de acuerdo de que el objeto de estudio sea el perfil NACA 0012.*
5. **Cálculo del momento de bisagra dimensional para Simpson.** Es el paso que bloquea cerrar el factor de escala λ del banco (ver `01_Geometria_Aleta_Referencia.md` §5, pendiente ítems 1–2) y, en cascada, rehacer la matriz de casos CFD de Fase B1. ¿Se prioriza este cálculo antes de la próxima iteración, dado que bloquea varias otras tareas?
6. **Altitud como variable de entrada (pregunta 5 de la reunión del 28/08, sin acuerdo registrado).** Se repite explícitamente porque quedó pendiente: ¿el banco debe representar múltiples altitudes de operación, o se fija una condición única (nivel del mar)?							*Preguntar algún contexto coherente al profesor tinnapp*
7. **Validación de la propuesta de OE cortos (§5bis de `01_Especificacion_del_Proyecto.md`).** Redactada conforme a los acuerdos #5 y #6 de la reunión anterior (cada OE con entregable asociado, redacción orientada a logro). ¿Se aprueba esta versión para reemplazar la redacción larga actual, o requiere ajustes?
8. **Reunión con Tapia (electrónicos), Lanziotti o Vicuña** (acuerdo #7 de la reunión anterior) — ¿ya se coordinó o sigue pendiente? No pude porque estuve muy enfermo.

**Respuestas / acuerdos (a completar después de la reunión):**

*(pendiente)*

## Cómo usar este documento

* Cada reunión se documenta como una nueva sección, con fecha en el título.
* Las preguntas se listan **antes** de la reunión (para preparación); las respuestas/acuerdos se agregan  **después** , en la misma sección.
