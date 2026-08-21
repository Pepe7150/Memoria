# Requisitos Funcionales

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Convención de ID:** `RF-<SUBSISTEMA>-<NN>`, donde el subsistema corresponde a los bloques de la arquitectura del sistema (`05_Arquitectura_del_Sistema.md`):

| Código | Subsistema                                    |
| ------- | --------------------------------------------- |
| CFD     | Módulo CFD / tablas aerodinámicas (offline) |
| PRO     | Módulo de procesamiento e interpolación     |
| BAN     | Banco / aplicación de carga                  |
| INS     | Instrumentación y adquisición de datos      |
| SWC     | Software de operación y control              |
| SIS     | Requisitos de integración / sistema completo |

**Prioridad:** Alta / Media / Baja.
**Método de verificación** (norma habitual en ingeniería de sistemas): **I**nspección, **A**nálisis, **D**emostración, **P**rueba.
**Objetivo específico (OE)** — referencia a `01_Especificacion_del_Proyecto.md`, sección 5:

- **OE-1:** Analizar el estado del arte (actuadores, bancos, metodologías CFD).
- **OE-2:** Desarrollar la metodología CFD → tablas aerodinámicas.
- **OE-3:** Diseñar la arquitectura mecánica, electrónica y de control.
- **OE-4:** Implementar el software de procesamiento e integración.
- **OE-5:** Construir e instrumentar el banco de ensayos.
- **OE-6:** Validar la plataforma experimental.

---

## Tabla resumen

| ID                  | Requisito                                                                                                                                                                                                                                                                                 | Prioridad      | Verificación | OE trazado            |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------- | --------------------- |
| RF-CFD-01           | El sistema deberá importar tablas de carga aerodinámica (CSV/JSON) generadas por simulaciones CFD offline.                                                                                                                                                                              | Alta           | P             | OE-4                  |
| RF-CFD-02           | El sistema deberá validar la estructura y consistencia de las tablas importadas (variables de entrada: Mach, ángulo de ataque, deflexión de superficie; variable de salida: torque de bisgara), rechazando o señalando archivos mal formados.                                         | Alta           | P             | OE-4                  |
| RF-CFD-03           | El sistema deberá soportar múltiples tablas de carga (distintas configuraciones o aplicaciones) sin requerir modificación del software.                                                                                                                                                | Alta           | D             | OE-3 / OE-4           |
| RF-CFD-04           | El sistema deberá reportar al usuario el rango válido (envolvente de Mach/ángulo/deflexión) contenido en la tabla cargada.                                                                                                                                                            | Media          | P             | OE-4                  |
| RF-PRO-01           | El sistema deberá interpolar el valor de torque objetivo para condiciones intermedias no presentes explícitamente en la tabla cargada.                                                                                                                                                  | Alta           | P             | OE-2 / OE-4           |
| RF-PRO-02           | El sistema deberá permitir seleccionar el método de interpolación a emplear (p. ej. lineal, kriging, splines) de forma configurable.                                                                                                                                                   | Media          | D             | OE-2                  |
| RF-PRO-03           | El sistema deberá generar un perfil temporal de torque objetivo, a partir de una maniobra o escenario de ensayo definido por el usuario, que sirva como referencia inicial y envolvente de validación del ensayo.                                                                       | Alta           | P             | OE-2 / OE-4           |
| RF-PRO-04           | El sistema deberá calcular y reportar una estimación del error de interpolación respecto a los puntos originales de la tabla CFD.                                                                                                                                                      | Media          | A             | OE-2                  |
| RF-PRO-05           | El sistema deberá entregar la referencia de carga generada al módulo de control del banco en un formato y frecuencia compatibles con el lazo de control.                                                                                                                                | Alta           | P             | OE-3 / OE-4           |
| **RF-PRO-06** | **El sistema deberá recalcular el torque objetivo en tiempo real a partir de la posición angular real de la aleta (realimentación, I-10), en lugar de aplicar únicamente el perfil temporal precalculado (RF-PRO-03).**                                                         | **Alta** | **P**   | **OE-3 / OE-4** |
| RF-BAN-01           | El banco deberá aplicar, mediante el motor de carga, sobre el eje del actuador bajo prueba, el torque objetivo entregado por el módulo de procesamiento.                                                                                                                                | Alta           | P             | OE-5 / OE-6           |
| RF-BAN-02           | El banco deberá aplicar el torque objetivo de forma consistente mientras el actuador bajo prueba está en movimiento, minimizando el torque parásito inducido por dicho movimiento mediante una estrategia de compensación activa (p. ej. feedforward o sincronización de velocidad). | Alta           | P             | OE-5 / OE-6           |
| RF-BAN-03           | El banco deberá limitar el torque aplicado a un valor máximo configurable, para proteger al actuador bajo prueba y a la estructura del banco.                                                                                                                                           | Alta           | P             | OE-5                  |
| RF-BAN-04           | El banco deberá detener automáticamente la aplicación de carga ante condiciones de falla, saturación o señales fuera de rango.                                                                                                                                                       | Alta           | D             | OE-5 / OE-6           |
| RF-BAN-05           | El banco deberá permitir la operación manual (torque de referencia fijo) para fines de calibración y puesta en marcha.                                                                                                                                                                 | Media          | D             | OE-5                  |
| **RF-BAN-06** | **El banco deberá detectar condiciones de atasco mutuo (stall) entre el motor de carga y el actuador bajo prueba —torque diferencial sostenido sin cambio de posición de la aleta— y detener automáticamente la aplicación de carga ante dicha condición.**                  | **Alta** | **P**   | **OE-5 / OE-6** |
| RF-INS-01           | El sistema deberá medir el torque efectivamente aplicado sobre el eje del actuador bajo prueba.                                                                                                                                                                                          | Alta           | P             | OE-5                  |
| RF-INS-02           | El sistema deberá medir la posición angular (y/o velocidad) real de la**aleta**, dado que puede diferir de la posición comandada al actuador por holgura o compliance mecánica bajo carga.                                                                                      | Alta           | P             | OE-5                  |
| RF-INS-03           | El sistema deberá adquirir variables eléctricas del actuador bajo prueba (corriente y/o tensión), cuando aplique.                                                                                                                                                                      | Media          | P             | OE-5 / OE-6           |
| RF-INS-04           | El sistema deberá sincronizar temporalmente todas las señales adquiridas (torque, posición, variables eléctricas, referencia objetivo).                                                                                                                                               | Alta           | P             | OE-5                  |
| RF-INS-05           | El sistema deberá registrar las variables medidas junto con la referencia objetivo y una marca de tiempo, durante toda la duración del ensayo.                                                                                                                                          | Alta           | P             | OE-5 / OE-6           |
| RF-SWC-01           | El software deberá proveer una interfaz de usuario para configurar los parámetros de un ensayo (tabla de carga, escenario, duración, límites de seguridad).                                                                                                                           | Alta           | D             | OE-4                  |
| RF-SWC-02           | El software deberá ejecutar el lazo de control que compara el torque objetivo con el torque medido y comanda el motor de carga.                                                                                                                                                          | Alta           | P             | OE-3 / OE-4           |
| RF-SWC-03           | El software deberá visualizar en tiempo real las variables relevantes del ensayo (torque objetivo vs. medido, posición real de la aleta, estado del sistema).                                                                                                                           | Media          | D             | OE-4                  |
| RF-SWC-04           | El software deberá exportar los resultados del ensayo en un formato estructurado y abierto (p. ej. CSV) para su análisis posterior.                                                                                                                                                     | Alta           | P             | OE-6                  |
| RF-SWC-05           | El software deberá registrar eventos, alarmas y errores del sistema durante la ejecución del ensayo (bitácora).                                                                                                                                                                        | Media          | D             | OE-4 / OE-6           |
| RF-SWC-06           | El software deberá permitir detener el ensayo en curso de forma segura, por acción del operador o por activación de una condición de parada.                                                                                                                                          | Alta           | D             | OE-4 / OE-5           |
| RF-SIS-01           | El sistema deberá permitir la sustitución de la tabla de carga (nueva aplicación/plataforma) sin requerir modificaciones en el hardware ni en el software base del banco.                                                                                                              | Alta           | D             | OE-3                  |
| RF-SIS-02           | El sistema deberá permitir la adaptación mecánica del banco a distintos actuadores bajo prueba mediante un acople intercambiable.                                                                                                                                                      | Media          | D             | OE-3 / OE-5           |

---

## Notas de trazabilidad y justificación

- **RF-CFD-xxx / RF-PRO-xxx** materializan directamente el flujo *"CFD → Base de datos aerodinámica → Software de procesamiento"* de `05_Arquitectura_del_Sistema.md` y los requisitos originales RF-001/RF-002 del borrador. La literatura del **Tema 1** (Da Ronch et al. 2011; Ghoreyshi et al. 2010) y del **Tema 4** (Mackman et al. 2013; de Visser et al. 2008–2010) respalda tanto el formato de tabla como los métodos de interpolación mencionados en RF-PRO-02.
- **RF-PRO-06** es nuevo: refleja la decisión de que el torque objetivo depende de la deflexión real de la aleta (variable de la tabla CFD), no solo del tiempo. Introduce la interfaz I-10 (instrumentación → interpolación) en la arquitectura.
- **RF-BAN-02** responde explícitamente al **riesgo #2** de la especificación ("Dificultad en la reproducción experimental de las cargas objetivo") y a la línea de literatura del **Tema 2** sobre torque/fuerza parásita en simuladores de carga (Plummer 2007; Yao et al. 2010/2012; Anastasopoulos & Hornung 2018).
- **RF-BAN-06** es nuevo: cubre el caso específico de un esquema con dos motores enfrentados (motor de carga vs. actuador bajo prueba), donde ambos pueden forzarse mutuamente de forma sostenida sin que la aleta se mueva. No estaba cubierto por RF-BAN-04 (fallas/saturación genéricas).
- **RF-INS-02** se reformuló: antes medía la posición del actuador; ahora mide la posición real de la **aleta**, que es la magnitud relevante para evaluar si el actuador logra el ángulo comandado bajo carga (ver OE-6 y CU-003).
- **RF-INS-xxx** se apoya en el **Tema 5** (instrumentación y balanzas de galgas extensométricas) y en particular en ElSaid et al. (2019), la referencia conceptualmente más cercana al banco completo (comando + medición + simulación de carga).
- **RF-SWC-xxx** recoge el **Tema 6**, priorizando una arquitectura de software modular (Zuluaga et al. 2022; Gomaa 2016) y desacoplada del control de tiempo real.
- **RF-SIS-01/02** formalizan explícitamente la modularidad exigida en el Alcance ("actualización de las tablas de carga, sin requerir modificaciones sustanciales en la plataforma experimental").

## Pendiente / a definir en próxima iteración

- Valores numéricos concretos (frecuencia de interpolación, formato exacto de archivo, rango de torque) dependerán de la selección preliminar del actuador y del rango de cargas obtenido en la etapa CFD — corresponde a OE-1 y OE-2.
- Umbral concreto de torque diferencial sostenido y timeout para la detección de atasco mutuo (RF-BAN-06) — a definir junto con RNF-SEG-04.
- Falta desarrollar el detalle de **RF-SWC** relativo a manejo de múltiples usuarios/perfiles, si aplica al contexto docente (Alcance, sección "Laboratorios de docencia avanzada").
