# Requisitos No Funcionales

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Convención de ID:** `RNF-<CATEGORÍA>-<NN>`.
**Prioridad:** Alta / Media / Baja.
**Método de verificación:** **I**nspección, **A**nálisis, **D**emostración, **P**rueba.
**OE** = Objetivo específico trazado (ver `02_Requisitos_Funcionales.md` para la lista completa).

---

## Tabla resumen

| ID | Requisito | Categoría | Prioridad | Verificación | OE trazado |
|---|---|---|---|---|---|
| RNF-REN-01 | El lazo de control de aplicación de torque deberá ejecutarse a una frecuencia mínima de **[a definir, según ancho de banda del actuador bajo prueba]** para representar adecuadamente su dinámica. | Desempeño | Alta | P | OE-3 |
| RNF-REN-02 | La latencia entre la medición de una variable y la actualización de la referencia de control no deberá superar **[a definir]**. | Desempeño | Media | P | OE-3 |
| RNF-PRE-01 | El error de interpolación de la tabla de carga respecto a los datos CFD originales no deberá superar **[a definir, p. ej. 5 %]** en el rango de validación. | Precisión | Alta | A | OE-2 |
| RNF-PRE-02 | El sistema de medición de torque deberá tener una incertidumbre menor a **[a definir, % del fondo de escala]**. | Precisión | Alta | P | OE-5 |
| RNF-PRE-03 | El sistema de medición de posición angular deberá tener una resolución menor a **[a definir]**. | Precisión | Media | P | OE-5 |
| RNF-CNF-01 | El banco deberá completar una campaña de ensayos de duración **[a definir]** sin fallas atribuibles al sistema de control o de adquisición. | Confiabilidad | Media | D | OE-6 |
| RNF-CNF-02 | Ante pérdida de comunicación entre módulos, el sistema deberá llevar el banco a un estado seguro (sin aplicación de torque). | Confiabilidad | Alta | P | OE-5 |
| RNF-SEG-01 | El banco deberá contar con un mecanismo de parada de emergencia físico, independiente del software de control. | Seguridad | Alta | I | OE-5 |
| RNF-SEG-02 | El software deberá implementar límites configurables de torque, velocidad y posición para proteger al actuador bajo prueba y a la estructura del banco. | Seguridad | Alta | P | OE-4 / OE-5 |
| RNF-SEG-03 | El diseño eléctrico y mecánico del banco deberá cumplir con prácticas de seguridad de laboratorio aplicables (protecciones eléctricas, resguardos mecánicos). | Seguridad | Alta | I | OE-5 |
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
- **RNF-MOD-01/02** formalizan el requisito explícito de la especificación: *"la arquitectura modular propuesta permitiría adaptar el banco a distintas aplicaciones mediante la actualización de las tablas de cargas, sin requerir modificaciones sustanciales en la plataforma experimental"*.
- **RNF-COS-01** responde directamente al **riesgo #5** ("Disponibilidad limitada de recursos para fabricación y validación"), cuya mitigación propuesta es priorizar componentes comerciales de bajo costo.
- **RNF-PRE-xxx** deberá refinarse una vez seleccionados los sensores candidatos; la literatura del **Tema 5** (Ewald 2000; Yu et al. 2022; Jubair et al. 2025) da órdenes de magnitud típicos de incertidumbre en balanzas de torque/galgas extensométricas que sirven de referencia para fijar estos valores.
- **RNF-REN-01/02** son los requisitos más dependientes del actuador finalmente seleccionado: el ancho de banda dinámico del actuador bajo prueba condiciona la frecuencia mínima de actualización del lazo de carga (ver Tema 2, en particular Yao et al. 2010 sobre compensación de torque excedente en tiempo real).

## Pendiente / a definir en próxima iteración

Los campos marcados **[a definir]** requieren un valor numérico concreto. Se recomienda completarlos en dos etapas:

1. **Etapa de estado del arte (OE-1):** usar rangos típicos reportados en la literatura de Temas 2 y 5 como primera aproximación (p. ej. frecuencias de lazo de control de simuladores de carga electrohidráulicos, incertidumbres típicas de balanzas de torque).
2. **Etapa de diseño preliminar (OE-2/OE-3):** ajustar los valores una vez definido el actuador de referencia y el rango de cargas obtenido de las simulaciones CFD propias del proyecto.
