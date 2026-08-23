
# Registro de Reuniones de Avance

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Objetivo de este documento:** llevar trazabilidad de las preguntas planteadas a los profesores guía (Bernardo Hernández, Frank Tinnap) en cada reunión de avance, y de los acuerdos/respuestas obtenidos, de modo que las decisiones de diseño puedan citarse con fecha y contexto en el resto de la documentación del proyecto.

---

## Reunión 21/08/2026 — Avance I

**Estado:** Completada. Acuerdos ya incorporados en la documentación del proyecto.

**Acuerdos:**

1. Se amplían los objetivos específicos de OE-1 a OE-6 (ver `01_Especificacion_del_Proyecto.md`, §5).
2. Se agrega la **velocidad de deflexión angular** como una cuarta dimensión de la superficie de respuesta CFD (junto a Mach, ángulo, deflexión) — impacta directamente la definición de la matriz de casos CFD (Fase B1 del cronograma) y la lista de pendientes analíticamente resolubles del proyecto.
3. Se agrega un **panel de potenciómetros manual** como interfaz de entrada: I-11 (condición de vuelo) e I-12 (comando del actuador bajo prueba) — ver `05_Arquitectura_del_Sistema.md`.
4. Se especifica el **objeto de estudio**, de momento sería la aleta de Nalci & Kayran. Podría cambiar a uno que se esté trabajando en el laboratorio, propuesto por los profesores.
5. Se inicia con **flujo potencial** como plan b. Lo cual deja de lado los efectos transientes, a preguntar en la siguiente reunión.

---

## Reunión 28/08/2026

**Estado:** Pendiente. Preguntas preparadas a partir del trabajo de la semana (análisis de flujo potencial en XFLR5).

**Preguntas a plantear:**

1. **Degeneración AoA/deflexión en modelo de aleta aislada.** Al no incluir fuselaje ni otra geometría de referencia en el modelo (ni en XFLR5 ni, previsiblemente, en la CFD propia dado que el alcance del proyecto excluye modelar el vehículo/misil completo), el modelo no puede distinguir entre ángulo de ataque del vehículo y deflexión de la aleta — son la misma variable física vista desde dos marcos de referencia distintos, y solo se separan cuando existe un tercer objeto (el fuselaje) contra el cual medir cada ángulo por separado. ¿Confirman que la matriz de casos CFD debe parametrizarse con un **único ángulo total** (no AoA y deflexión por separado)?
2. **Relacionado:** si en algún momento se requiere la separación real AoA/deflexión (p. ej. para un caso de uso específico del contexto de aplicación que estén evaluando), esto implicaría modelar el vehículo completo (fuselaje incluido), lo cual excede el alcance actual del proyecto (`01_Especificacion_del_Proyecto.md`, "No incluye": *"Diseño del misil o torpedo"*). ¿Se mantiene la aleta aislada como supuesto de modelado, o se prevé incorporar geometría de fuselaje en algún momento?
3. **Confirmación sobre el posible cambio de objeto de diseño hacia un proyecto UAV del laboratorio** (mencionado informalmente por los profesores): de concretarse, ¿qué pasa con el trabajo ya avanzado sobre la geometría de referencia de Nalci & Kayran (perfil doble cuña, escala, valores de XFLR5)? ¿Se reemplaza íntegramente, o se mantiene como ejercicio metodológico documentado mientras se define la nueva geometría de referencia?
4. **Alcance de XFLR5 como fuente de datos de contingencia.** Se confirmó que XFLR5 (análisis de polares estático/cuasi-estacionario) solo puede proveer 2 de las 4 dimensiones acordadas en el punto 2 del Avance I (Mach y ángulo total — no AoA/deflexión por separado, no velocidad de deflexión angular, que requiere CFD no estacionaria). ¿Es aceptable usar un dataset de XFLR5 con estas 2 dimensiones como plan de contingencia/prueba del pipeline de software, dejando explícito que no reemplaza la caracterización CFD completa?

**Respuestas / acuerdos (a completar después de la reunión):**

_Pendiente — completar tras la reunión del 28/08/2026._

---

## Cómo usar este documento

- Cada reunión se documenta como una nueva sección, con fecha en el título.
- Las preguntas se listan **antes** de la reunión (para preparación); las respuestas/acuerdos se agregan **después**, en la misma sección.
- Cuando un acuerdo de reunión cambia una decisión ya documentada en otro archivo del proyecto (RF, RNF, arquitectura, geometría), se debe:
  1. Registrar el acuerdo aquí con la fecha.
  2. Actualizar el documento afectado, citando esta reunión como origen del cambio (p. ej. *"Actualizado según acuerdo de Reunión de Avance 28/08/2026, ver `00_Administración/02_Registro_Reuniones_Avance.md`"*).
