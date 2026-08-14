# Casos de Uso

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

## Actores

| Actor | Descripción |
|---|---|
| **Operador** | Usuario principal del banco (investigador, estudiante o ingeniero). Configura, ejecuta y supervisa los ensayos, e interpreta los resultados. |
| **Sistema de Control** | Actor de sistema: lazo de control automático que aplica y regula el torque objetivo sobre el actuador bajo prueba, y ejecuta las protecciones de seguridad. |
| **Analista CFD** *(externo, offline)* | Genera la tabla de carga aerodinámica mediante simulaciones CFD, fuera del alcance del banco propiamente dicho. Interactúa con el sistema únicamente a través del archivo de tabla de carga (CU-001). |

## Tabla resumen de trazabilidad

| ID | Caso de uso | Actor principal | RF relacionados |
|---|---|---|---|
| CU-001 | Importar tabla de carga aerodinámica | Operador | RF-CFD-01, RF-CFD-02, RF-CFD-04 |
| CU-002 | Configurar un ensayo | Operador | RF-PRO-01 a RF-PRO-04, RF-SWC-01 |
| CU-003 | Ejecutar un ensayo | Operador, Sistema de Control | RF-BAN-01 a RF-BAN-03, RF-INS-01 a RF-INS-05, RF-SWC-02, RF-SWC-03, RF-SWC-05 |
| CU-004 | Detener un ensayo (manual o por falla) | Operador, Sistema de Control | RF-BAN-04, RF-SWC-05, RF-SWC-06 |
| CU-005 | Exportar resultados de un ensayo | Operador | RF-SWC-04 |
| CU-006 | Calibrar el banco (modo manual) | Operador | RF-BAN-05, RF-INS-01 |
| CU-007 | Sustituir la tabla de carga para una nueva aplicación | Operador | RF-CFD-03, RF-SIS-01 |
| CU-008 | Cambiar el actuador bajo prueba | Operador | RF-SIS-02 |
| CU-009 | Consultar la bitácora de eventos | Operador | RF-SWC-05 |

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
3. El sistema valida la estructura del archivo (columnas de entrada: Mach, ángulo de ataque, deflexión de superficie; columna de salida: torque de charnela).
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
2. El sistema solicita: tabla de carga a usar, escenario o maniobra (secuencia de condiciones Mach/ángulo/deflexión), duración del ensayo, límites de torque/velocidad/posición.
3. El operador ingresa los parámetros solicitados.
4. El sistema valida que los parámetros estén dentro del rango válido de la tabla de carga (CU-001) y de los límites de seguridad del banco.
5. El sistema genera el perfil temporal de torque objetivo mediante interpolación, y estima el error de interpolación asociado.
6. El sistema confirma la configuración y deja el ensayo listo para su ejecución.

**Flujo alternativo:**
- **4a.** Si algún parámetro está fuera de rango, el sistema lo señala y solicita su corrección antes de continuar.

**Resultado esperado:** Ensayo configurado, con referencia de carga generada y validada, listo para ejecución (CU-003).

**RF relacionados:** RF-PRO-01, RF-PRO-02, RF-PRO-03, RF-PRO-04, RF-SWC-01

---

## CU-003 — Ejecutar un ensayo

**Actor:** Operador, Sistema de Control

**Descripción:** El operador lanza la ejecución de un ensayo previamente configurado. El sistema de control aplica el torque objetivo sobre el actuador bajo prueba, mientras el sistema de instrumentación mide y registra las variables relevantes.

**Precondiciones:**
- Ensayo configurado (CU-002).
- Actuador bajo prueba montado y conectado al banco.
- Condiciones de seguridad verificadas (RNF-SEG-01 a RNF-SEG-03).

**Flujo principal:**
1. El operador inicia la ejecución del ensayo.
2. El sistema de control comienza a aplicar el torque objetivo del perfil generado sobre el eje del actuador, compensando el torque parásito inducido por el movimiento del propio actuador.
3. El sistema de instrumentación mide continuamente el torque aplicado, la posición angular y las variables eléctricas del actuador, sincronizando todas las señales adquiridas.
4. El sistema registra las variables medidas junto con la referencia objetivo y una marca de tiempo.
5. El operador visualiza en tiempo real el progreso del ensayo (torque objetivo vs. medido, posición, estado del sistema).
6. Al completarse la duración programada, el sistema retira automáticamente el torque aplicado y marca el ensayo como completado.

**Flujos alternativos:**
- **2a.** Si el torque medido o algún parámetro supera los límites configurados, el sistema activa la parada automática de carga y registra el evento → continúa en **CU-004** (detención por falla).
- **5a.** El operador puede detener manualmente el ensayo en cualquier momento → continúa en **CU-004** (detención manual).

**Resultado esperado:** Conjunto de datos del ensayo (torque objetivo, torque medido, posición, variables eléctricas, eventos) registrado y disponible para su exportación (CU-005).

**RF relacionados:** RF-BAN-01, RF-BAN-02, RF-BAN-03, RF-INS-01, RF-INS-02, RF-INS-03, RF-INS-04, RF-INS-05, RF-SWC-02, RF-SWC-03, RF-SWC-05

---

## CU-004 — Detener un ensayo

**Actor:** Operador, Sistema de Control

**Descripción:** El ensayo en ejecución se detiene de forma segura, ya sea por decisión del operador o por activación automática de una condición de falla o límite de seguridad.

**Precondiciones:** Existe un ensayo en ejecución (CU-003).

**Flujo principal (detención manual):**
1. El operador selecciona "Detener ensayo".
2. El sistema de control reduce el torque aplicado a cero de forma controlada.
3. El sistema detiene la adquisición y cierra el registro de datos del ensayo.
4. El sistema informa al operador el estado final del ensayo (completo/incompleto).

**Flujo alternativo (detención automática por falla):**
- **1a.** El sistema de control detecta una condición fuera de rango o de falla.
- **2a.** El sistema retira automáticamente el torque aplicado y lleva el banco a un estado seguro.
- **3a.** El sistema registra el evento/alarma correspondiente en la bitácora.
- **4a.** El sistema notifica al operador la causa de la detención.

**Resultado esperado:** El banco queda en estado seguro (sin torque aplicado) y el evento de detención queda documentado en la bitácora.

**RF relacionados:** RF-BAN-04, RF-SWC-05, RF-SWC-06
**RNF relacionados:** RNF-SEG-01, RNF-SEG-02, RNF-CNF-02

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

**Descripción:** Antes de una campaña de ensayos, el operador opera el banco en modo manual (torque de referencia fijo) para verificar la correcta respuesta del sistema de aplicación de carga y de los sensores.

**Precondiciones:** Banco energizado, sin ensayo automático en curso.

**Flujo principal:**
1. El operador selecciona "Modo manual / calibración".
2. El operador ingresa un valor de torque de referencia fijo, dentro de los límites de seguridad del banco.
3. El sistema aplica dicho torque y muestra en tiempo real el torque medido.
4. El operador compara la referencia aplicada con la medición y, si corresponde, ajusta la calibración del sensor de torque.
5. El operador finaliza el modo manual.

**Resultado esperado:** Sistema de aplicación de carga y sensores verificados/calibrados, en condiciones de iniciar ensayos automáticos.

**RF relacionados:** RF-BAN-05, RF-INS-01
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

**Descripción:** El operador retira el actuador actualmente montado en el banco y monta uno distinto mediante el acople intercambiable, para caracterizar un nuevo actuador candidato.

**Precondiciones:** Banco detenido y en estado seguro (sin torque aplicado).

**Flujo principal:**
1. El operador detiene cualquier ensayo en curso, si aplica (CU-004).
2. El operador desmonta el actuador actual del acople del banco.
3. El operador monta el nuevo actuador bajo prueba y verifica sus conexiones eléctricas/mecánicas y la instrumentación asociada.
4. El operador ejecuta el modo manual de calibración para verificar la correcta integración (CU-006).
5. El operador queda en condiciones de configurar un nuevo ensayo (CU-002).

**Resultado esperado:** Nuevo actuador integrado al banco y listo para ser caracterizado, sin modificaciones a la plataforma experimental más allá del acople.

**RF relacionados:** RF-SIS-02
**RNF relacionados:** RNF-SEG-01, RNF-SEG-03

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

## Notas de cobertura

- Los casos de uso cubren la totalidad de los RF definidos en `02_Requisitos_Funcionales.md`, con excepción de RF-CFD-01/02/04 (cubiertos íntegramente por CU-001) y RF-PRO-05 (interno al sistema, no visible como interacción directa del operador; se manifiesta como parte del flujo interno de CU-002/CU-003).
- CU-003 es el caso de uso central del sistema: integra banco (RF-BAN), instrumentación (RF-INS) y software de control (RF-SWC) en una sola ejecución, reflejando el flujo completo de la arquitectura (`05_Arquitectura_del_Sistema.md`).
- CU-007 y CU-008 son los casos de uso que demuestran explícitamente el **objetivo específico OE-3** (arquitectura modular) y forman parte de los criterios de validación (OE-6) que deberían incluirse en el informe final: mostrar que cambiar de aplicación o de actuador no requiere modificar el banco.
- Queda pendiente definir si se requiere un caso de uso de **gestión de usuarios/perfiles** en caso de que el banco se destine también a uso docente (mencionado en el Alcance del proyecto); no se incluyó aquí por no existir un RF explícito que lo respalde todavía.
