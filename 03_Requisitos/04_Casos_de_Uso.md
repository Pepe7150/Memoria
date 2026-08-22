# Casos de Uso

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

## Actores

| Actor | Descripción |
|---|---|
| **Operador** | Usuario principal del banco (investigador, estudiante o ingeniero). Configura, ejecuta y supervisa los ensayos, e interpreta los resultados. |
| **Sistema de Control** | Actor de sistema: lazo de control automático que aplica y regula el torque objetivo sobre el actuador bajo prueba mediante el motor de carga, y ejecuta las protecciones de seguridad. |
| **Analista CFD** *(externo, offline)* | Genera la tabla de carga aerodinámica mediante simulaciones CFD, fuera del alcance del banco propiamente dicho. Interactúa con el sistema únicamente a través del archivo de tabla de carga (CU-001). |

## Tabla resumen de trazabilidad

| ID | Caso de uso | Actor principal | RF relacionados |
|---|---|---|---|
| CU-001 | Importar tabla de carga aerodinámica | Operador | RF-CFD-01, RF-CFD-02, RF-CFD-04 |
| CU-002 | Configurar un ensayo | Operador | RF-PRO-01 a RF-PRO-04, RF-SWC-01 |
| CU-003 | Ejecutar un ensayo | Operador, Sistema de Control | RF-BAN-01 a RF-BAN-03, RF-BAN-06, RF-INS-01 a RF-INS-05, RF-PRO-06, RF-SWC-02, RF-SWC-03, RF-SWC-05 |
| CU-004 | Detener un ensayo (manual o por falla) | Operador, Sistema de Control | RF-BAN-04, RF-BAN-06, RF-SWC-05, RF-SWC-06 |
| CU-005 | Exportar resultados de un ensayo | Operador | RF-SWC-04 |
| CU-006 | Calibrar el banco (modo manual) | Operador | RF-BAN-05, RF-BAN-07(a), RF-INS-01 |
| CU-007 | Sustituir la tabla de carga para una nueva aplicación | Operador | RF-CFD-03, RF-SIS-01 |
| CU-008 | Cambiar el actuador bajo prueba | Operador | RF-SIS-02 |
| CU-009 | Consultar la bitácora de eventos | Operador | RF-SWC-05 |
| **CU-010** | **Caracterizar el actuador bajo prueba en modo manual (potenciómetros)** | **Operador, Sistema de Control** | **RF-BAN-07(b), RF-INS-01, RF-INS-02, RF-SEG-05 (RNF)** |

---

## CU-001 — Importar tabla de carga aerodinámica

**Actor:** Operador

**Descripción:** El operador carga en el sistema una tabla de carga aerodinámica (CSV/JSON) generada previamente mediante simulaciones CFD, para que el módulo de procesamiento pueda usarla como fuente de datos.

**Precondiciones:**
- Existe un archivo de tabla de carga generado por el Analista CFD y disponible en el sistema de archivos.
- No hay un ensayo en ejecución.

**Flujo principal:**
1. El operador selecciona la opción "Importar tabla de carga" en la interfaz.
2. El operador indica el archivo a importar.
3. El sistema valida la estructura del archivo (columnas de entrada: Mach, ángulo de ataque, deflexión de superficie, velocidad angular de deflexión; columna de salida: torque de charnela).
4. El sistema informa el rango válido de variables (envolvente) contenido en la tabla.
5. El sistema almacena la tabla como fuente disponible para el módulo de procesamiento.

**Flujo alternativo:**
- **3a.** Si el archivo no cumple con el formato esperado, el sistema rechaza la importación y muestra un mensaje de error detallando el problema.

**Resultado esperado:** La tabla de carga queda disponible como fuente de datos válida para la generación de referencias de torque.

**RF relacionados:** RF-CFD-01, RF-CFD-02, RF-CFD-04

---

## CU-002 — Configurar un ensayo

**Actor:** Operador

**Descripción:** El operador define los parámetros de un ensayo a partir de una tabla de carga importada: escenario o maniobra, duración y límites de seguridad.

**Precondiciones:** Existe al menos una tabla de carga importada (CU-001).

**Flujo principal:**
1. El operador selecciona "Nuevo ensayo".
2. El sistema solicita: tabla de carga a usar, escenario o maniobra (secuencia de condiciones Mach/ángulo/deflexión/velocidad angular de deflexión), duración del ensayo, límites de torque/velocidad/posición.
3. El operador ingresa los parámetros solicitados.
4. El sistema valida que los parámetros estén dentro del rango válido de la tabla de carga (CU-001) y de los límites de seguridad del banco.
5. El sistema genera un perfil temporal de torque objetivo mediante interpolación, que sirve como **referencia inicial y envolvente de validación** — el valor efectivamente aplicado durante la ejecución (CU-003) se recalculará en tiempo real según la posición y velocidad angular real de la aleta (RF-PRO-06) — y estima el error de interpolación asociado.
6. El sistema confirma la configuración y deja el ensayo listo para su ejecución.

**Flujo alternativo:**
- **4a.** Si algún parámetro está fuera de rango, el sistema lo señala y solicita su corrección antes de continuar.

**Resultado esperado:** Ensayo configurado, con referencia de carga inicial generada y validada, listo para ejecución (CU-003).

**RF relacionados:** RF-PRO-01, RF-PRO-02, RF-PRO-03, RF-PRO-04, RF-SWC-01

---

## CU-003 — Ejecutar un ensayo

**Actor:** Operador, Sistema de Control

**Descripción:** El operador lanza la ejecución de un ensayo previamente configurado. El motor de carga aplica sobre el eje el torque objetivo, recalculado continuamente a partir de la posición y velocidad angular real de la aleta, mientras el actuador bajo prueba intenta llevarla al ángulo comandado. El sistema de instrumentación mide y registra las variables relevantes.

**Precondiciones:**
- Ensayo configurado (CU-002).
- Actuador bajo prueba montado y conectado al banco, con la aleta física instalada en el mismo eje.
- Condiciones de seguridad verificadas (RNF-SEG-01 a RNF-SEG-03).

**Flujo principal:**
1. El operador inicia la ejecución del ensayo.
2. El sistema mide la posición y velocidad angular real de la aleta y recalcula el torque objetivo correspondiente a partir de la tabla de carga (RF-PRO-06).
3. El sistema de control comienza a aplicar, mediante el motor de carga, el torque objetivo recalculado sobre el eje, compensando el torque parásito inducido por el movimiento del actuador bajo prueba (RF-BAN-02).
4. El sistema de instrumentación mide continuamente el torque aplicado, la posición y velocidad angular real de la aleta y las variables eléctricas del actuador, sincronizando todas las señales adquiridas.
5. El sistema registra las variables medidas junto con la referencia objetivo y una marca de tiempo.
6. El operador visualiza en tiempo real el progreso del ensayo (torque objetivo vs. medido, posición y velocidad real de la aleta, estado del sistema).
7. Los pasos 2 a 5 se repiten en cada ciclo del lazo de control durante toda la duración del ensayo.
8. Al completarse la duración programada, el sistema retira automáticamente el torque aplicado y marca el ensayo como completado.

**Flujos alternativos:**
- **3a.** Si el torque medido o algún parámetro supera los límites configurados, el sistema activa la parada automática de carga y registra el evento → continúa en **CU-004** (detención por falla).
- **3b.** Si el sistema detecta una condición de atasco mutuo (stall) entre el motor de carga y el actuador bajo prueba —torque diferencial sostenido sin cambio de posición de la aleta, RF-BAN-06— el sistema activa la parada automática de carga y registra el evento → continúa en **CU-004** (detención por falla).
- **6a.** El operador puede detener manualmente el ensayo en cualquier momento → continúa en **CU-004** (detención manual).

**Resultado esperado:** Conjunto de datos del ensayo (torque objetivo, torque medido, posición y velocidad real de la aleta, variables eléctricas, eventos) registrado y disponible para su exportación (CU-005).

**RF relacionados:** RF-BAN-01, RF-BAN-02, RF-BAN-03, RF-BAN-06, RF-INS-01, RF-INS-02, RF-INS-03, RF-INS-04, RF-INS-05, RF-PRO-06, RF-SWC-02, RF-SWC-03, RF-SWC-05

---

## CU-004 — Detener un ensayo

**Actor:** Operador, Sistema de Control

**Descripción:** El ensayo en ejecución se detiene de forma segura, ya sea por decisión del operador o por activación automática de una condición de falla, atasco mutuo o límite de seguridad.

**Precondiciones:** Existe un ensayo en ejecución (CU-003).

**Flujo principal (detención manual):**
1. El operador selecciona "Detener ensayo".
2. El sistema de control reduce a cero el torque aplicado por el motor de carga, de forma controlada.
3. El sistema detiene la adquisición y cierra el registro de datos del ensayo.
4. El sistema informa al operador el estado final del ensayo (completo/incompleto).

**Flujo alternativo (detención automática por falla o atasco mutuo):**
- **1a.** El sistema de control detecta una condición fuera de rango, de falla, o de atasco mutuo (stall) entre el motor de carga y el actuador bajo prueba.
- **2a.** El sistema retira automáticamente el torque aplicado y lleva el banco a un estado seguro.
- **3a.** El sistema registra el evento/alarma correspondiente en la bitácora, indicando la causa específica (falla, saturación o atasco mutuo).
- **4a.** El sistema notifica al operador la causa de la detención.

**Resultado esperado:** El banco queda en estado seguro (sin torque aplicado) y el evento de detención queda documentado en la bitácora.

**RF relacionados:** RF-BAN-04, RF-BAN-06, RF-SWC-05, RF-SWC-06
**RNF relacionados:** RNF-SEG-01, RNF-SEG-02, RNF-SEG-04, RNF-CNF-02

---

## CU-005 — Exportar resultados de un ensayo

**Actor:** Operador

**Descripción:** El operador exporta los datos registrados durante un ensayo para su análisis posterior (p. ej. en Python) o para incorporarlos al informe de validación experimental.

**Precondiciones:** Existe al menos un ensayo completado o detenido (CU-003/CU-004) con datos registrados.

**Flujo principal:**
1. El operador selecciona el ensayo a exportar.
2. El operador elige el formato de exportación (CSV).
3. El sistema genera el archivo con las variables registradas, la referencia objetivo y la configuración utilizada en el ensayo.
4. El sistema confirma la exportación exitosa e indica la ubicación del archivo generado.

**Resultado esperado:** Archivo de resultados disponible fuera del sistema, trazable a la configuración del ensayo que lo generó.

**RF relacionados:** RF-SWC-04
**RNF relacionados:** RNF-DOC-01

---

## CU-006 — Calibrar el banco (modo manual)

**Actor:** Operador

**Descripción:** Antes de una campaña de ensayos, el operador opera el banco en modo manual (torque de referencia fijo aplicado por el motor de carga, y opcionalmente condiciones de vuelo simuladas fijadas por potenciómetro) para verificar la correcta respuesta del sistema de aplicación de carga y de los sensores.

**Precondiciones:** Banco energizado, sin ensayo automático en curso.

**Flujo principal:**
1. El operador selecciona "Modo manual / calibración".
2. El operador ingresa un valor de torque de referencia fijo, dentro de los límites de seguridad del banco — **o bien** fija las condiciones de vuelo simuladas (Mach, ángulo de ataque) mediante los potenciómetros correspondientes (I-11), dejando que el módulo de interpolación calcule el torque de referencia a partir de esos valores y de la deflexión real medida.
3. El sistema aplica dicho torque mediante el motor de carga y muestra en tiempo real el torque medido.
4. El operador compara la referencia aplicada con la medición y, si corresponde, ajusta la calibración del sensor de torque.
5. El operador finaliza el modo manual.

**Flujo alternativo:**
- **2a.** Si el operador usa los potenciómetros de Mach/ángulo de ataque (I-11) en lugar de un torque fijo, el sistema muestra también los valores manuales activos junto con el torque calculado, para que quede claro que el torque no es una referencia arbitraria sino el resultado de la tabla de carga evaluada en esas condiciones.

**Resultado esperado:** Sistema de aplicación de carga y sensores verificados/calibrados, en condiciones de iniciar ensayos automáticos.

**RF relacionados:** RF-BAN-05, RF-BAN-07(a), RF-INS-01
**RNF relacionados:** RNF-PRE-02

---

## CU-007 — Sustituir la tabla de carga para una nueva aplicación

**Actor:** Operador

**Descripción:** El operador reemplaza o añade una tabla de carga correspondiente a una nueva aplicación o plataforma (p. ej. otra geometría de superficie de control), aprovechando la arquitectura modular del banco, sin requerir modificaciones de hardware ni de software.

**Precondiciones:**
- Nueva tabla de carga generada y validada externamente mediante CFD.
- Banco sin ensayo en ejecución.

**Flujo principal:**
1. El operador importa la nueva tabla de carga (CU-001).
2. El sistema la registra como una fuente adicional disponible, sin afectar las tablas previamente importadas.
3. El operador selecciona la nueva tabla al configurar un ensayo (CU-002).

**Resultado esperado:** El banco opera con la nueva tabla de carga sin requerir cambios en el hardware ni en el software base, evidenciando la modularidad de la arquitectura.

**RF relacionados:** RF-CFD-03, RF-SIS-01
**RNF relacionados:** RNF-MOD-01, RNF-MOD-02

---

## CU-008 — Cambiar el actuador bajo prueba

**Actor:** Operador

**Descripción:** El operador retira el actuador actualmente montado en el banco (con su aleta) y monta un conjunto distinto mediante el acople intercambiable, para caracterizar un nuevo actuador candidato.

**Precondiciones:** Banco detenido y en estado seguro (sin torque aplicado).

**Flujo principal:**
1. El operador detiene cualquier ensayo en curso, si aplica (CU-004).
2. El operador desmonta el actuador actual (y la aleta) del acople del banco.
3. El operador monta el nuevo actuador bajo prueba y su aleta, y verifica sus conexiones eléctricas/mecánicas, la alineación del conjunto y la instrumentación asociada.
4. El operador ejecuta el modo manual de calibración para verificar la correcta integración (CU-006).
5. El operador queda en condiciones de configurar un nuevo ensayo (CU-002).

**Resultado esperado:** Nuevo actuador integrado al banco y listo para ser caracterizado, sin modificaciones a la plataforma experimental más allá del acople.

**RF relacionados:** RF-SIS-02
**RNF relacionados:** RNF-SEG-01, RNF-SEG-03, RNF-PRE-04

---

## CU-009 — Consultar la bitácora de eventos

**Actor:** Operador

**Descripción:** El operador revisa el historial de eventos, alarmas y errores registrados por el sistema, para diagnosticar el comportamiento del banco durante uno o varios ensayos.

**Precondiciones:** Existen eventos registrados en el sistema.

**Flujo principal:**
1. El operador selecciona "Ver bitácora".
2. El sistema muestra la lista de eventos (marca de tiempo, tipo, descripción), filtrable por ensayo o rango de fechas.
3. El operador revisa los eventos de interés.

**Resultado esperado:** El operador cuenta con información de diagnóstico sobre el comportamiento del sistema, útil tanto para depuración como para el informe de validación experimental.

**RF relacionados:** RF-SWC-05
**RNF relacionados:** RNF-DOC-01

---

## CU-010 — Caracterizar el actuador bajo prueba en modo manual (potenciómetros)

**Actor:** Operador, Sistema de Control

**Descripción:** El operador fija, mediante el potenciómetro de ángulo objetivo (I-12), una deflexión que se comanda **directamente** al actuador bajo prueba, análogo a un probador de servo manual, mientras el motor de carga sigue aplicando el torque calculado por el módulo de interpolación (ya sea desde un escenario programado o desde los potenciómetros de condiciones de vuelo, I-11). El sistema mide si la aleta efectivamente alcanza el ángulo comandado y con qué error/retardo, generando el dato de caracterización central del actuador bajo prueba. A diferencia de CU-003, aquí el comando de posición no proviene de una maniobra precalculada (RF-PRO-03) sino de la acción manual y en tiempo real del operador sobre la perilla.

**Precondiciones:**
- Actuador bajo prueba montado y conectado al banco (CU-008), con la aleta física instalada en el mismo eje.
- Banco en modo manual (ver CU-006), con el motor de carga aplicando un torque de referencia (fijo o calculado desde I-11).
- Condiciones de seguridad verificadas (RNF-SEG-01 a RNF-SEG-03, RNF-SEG-05).

**Flujo principal:**
1. El operador gira el potenciómetro de ángulo objetivo (I-12) hasta el valor deseado.
2. El sistema envía dicho valor como comando de posición directo al actuador bajo prueba, respetando los límites de RNF-SEG-02/RNF-SEG-05.
3. El actuador bajo prueba intenta alcanzar el ángulo comandado, venciendo el torque de carga aplicado simultáneamente por el motor de carga.
4. El sistema de instrumentación mide la posición angular real de la aleta (RF-INS-02) y la registra junto con el ángulo comandado por el potenciómetro y una marca de tiempo.
5. El operador visualiza en tiempo real la comparación entre ángulo comandado (I-12) y ángulo logrado (I-10/RF-INS-02).
6. El operador repite los pasos 1 a 5 para distintos ángulos objetivo y/o distintas condiciones de carga (variando I-11), construyendo así un conjunto de puntos de caracterización del actuador.

**Flujo alternativo:**
- **3a.** Si el sistema detecta una condición de atasco mutuo (stall) o de límite de seguridad, se activa la parada automática de carga (RF-BAN-06/RNF-SEG-04) → continúa en **CU-004**.

**Resultado esperado:** Conjunto de datos (ángulo comandado por potenciómetro, ángulo real logrado, torque aplicado, variables eléctricas) que caracteriza la capacidad del actuador bajo prueba de alcanzar ángulos objetivo bajo distintas condiciones de carga, sin depender de una maniobra CFD precalculada.

**RF relacionados:** RF-BAN-07(b), RF-INS-01, RF-INS-02, RF-INS-04, RF-INS-05
**RNF relacionados:** RNF-SEG-02, RNF-SEG-05, RNF-PRE-03, RNF-PRE-06, RNF-DOC-01

---

## Notas de cobertura

- Los casos de uso cubren la totalidad de los RF definidos en `02_Requisitos_Funcionales.md`, con excepción de RF-CFD-01/02/04 (cubiertos íntegramente por CU-001) y RF-PRO-05 (interno al sistema, no visible como interacción directa del operador; se manifiesta como parte del flujo interno de CU-002/CU-003).
- CU-003 es el caso de uso central del sistema en su modo **automático**: integra banco (RF-BAN), instrumentación (RF-INS), recálculo de torque por posición y velocidad (RF-PRO-06) y software de control (RF-SWC) en una sola ejecución, reflejando el flujo completo de la arquitectura (`05_Arquitectura_del_Sistema.md`).
- **CU-010 (nuevo, acuerdos de Avance I)** es el caso de uso análogo en **modo manual**: cubre específicamente RF-BAN-07(b) (comando directo de ángulo objetivo vía potenciómetro I-12) y formaliza el mecanismo concreto por el cual el proyecto genera el dato "ángulo comandado vs. ángulo logrado" que sustenta la caracterización del actuador (OE-6). Se diferencia de CU-006 en que CU-006 cubre principalmente la calibración del sensor de torque y el uso de los potenciómetros de condiciones de vuelo (I-11); CU-010 se centra en el potenciómetro de ángulo objetivo (I-12) y en el ciclo repetido de comando-medición-registro que constituye una campaña de caracterización.
- CU-007 y CU-008 son los casos de uso que demuestran explícitamente el **objetivo específico OE-3** (arquitectura modular) y forman parte de los criterios de validación (OE-6) que deberían incluirse en el informe final: mostrar que cambiar de aplicación o de actuador no requiere modificar el banco.
- Queda pendiente definir si se requiere un caso de uso de **gestión de usuarios/perfiles** en caso de que el banco se destine también a uso docente (mencionado en el Alcance del proyecto); no se incluyó aquí por no existir un RF explícito que lo respalde todavía.
- Queda pendiente definir, en el diseño detallado del Controlador, si el potenciómetro de ángulo objetivo (I-12, CU-010) puede activarse como *override* momentáneo durante un ensayo automático en curso (CU-003) o si es estrictamente exclusivo de una sesión en modo manual — ver `05_Arquitectura_del_Sistema.md` §7.
