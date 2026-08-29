# Principios Metodológicos del Proyecto

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Origen:** Reunión de Avance del 28/08/2026, recomendación del profesor Frank Tinnap. Ver `00_Administración/02_Registro_Reuniones_Avance.md`, punto 1.

**Propósito de este documento:** dejar explícito un principio de desarrollo que hasta ahora se ha aplicado de forma implícita en varias decisiones del proyecto, para que guíe conscientemente las decisiones que aún quedan pendientes (arquitectura física, método de medición de torque, matriz de casos CFD).

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `04_CFD/00_XFLR5/03_Pipeline_General_XFLR5.md`, `04_CFD/01_Casos/03_Matriz_Casos_CFD_FaseB1.md`, `00_Administración/01_Cronograma.md`.

---

## 1. El principio

Para sistemas de ingeniería con múltiples subsistemas interdependientes (como este banco: CFD → tabla de carga → interpolación → aplicación de torque → instrumentación → control), es preferible **primero tener un sistema completo que funcione de forma imperfecta, y luego mejorarlo iterativamente**, en lugar de optimizar un subsistema aislado hasta un estándar alto antes de que el sistema completo exista y se haya probado de punta a punta.

Formulado de forma operativa para este proyecto:

> Ante una decisión de diseño con incertidumbre no resuelta, se prefiere una primera versión simple, barata y con limitaciones declaradas que permita cerrar el lazo completo del sistema (todas las etapas, aunque sea con datos o componentes provisionales), por sobre invertir tiempo en perfeccionar una sola etapa antes de saber si el resto del sistema la necesita tal como se la está diseñando.

**Por qué importa especialmente en este proyecto:** el banco tiene una cadena larga con siete subsistemas (`05_Arquitectura_del_Sistema.md` §2) y varias incertidumbres que solo se resuelven con datos propios (rango de torque real, ancho de banda dinámico, factor de escala λ). Optimizar un eslabón — por ejemplo, buscar el método de interpolación óptimo, o cerrar la escala CFD con precisión antes de tener ninguna corrida — sin haber verificado que el resto de la cadena funciona, arriesga invertir esfuerzo en un componente que después cambia de todas formas cuando aparece un dato real o una restricción de otro subsistema (como ya ocurrió con la celda de carga, ver punto 4 de la reunión).

## 2. Aplicaciones ya existentes de este principio (evidencia retroactiva)

Antes de esta reunión, el proyecto ya había aplicado este principio sin nombrarlo. Vale la pena reconocerlo explícitamente, porque respalda que no es solo una idea nueva sino una práctica que ya ha dado resultado:

| Decisión ya tomada | Cómo aplica el principio |
|---|---|
| **Dataset de contingencia XFLR5** (`04_CFD/00_XFLR5/`) | En vez de esperar a tener la CFD viscosa propia (Fase B, aún no ejecutada) para poder probar el software de interpolación y control, se generó un dataset de flujo potencial — con limitaciones declaradas explícitamente (sin viscosidad, 2D en vez de 3D, sin velocidad angular) — que permite ejercitar el pipeline completo *ahora*. El objetivo no es que el dato sea correcto; es que el sistema completo (lectura de tabla → interpolación → referencia de torque) exista y se pueda probar. |
| **λ nominal de partida = 0,63** (`04_CFD/01_Casos/03_Matriz_Casos_CFD_FaseB1.md` §2) | En vez de bloquear toda la matriz de casos CFD hasta cerrar el factor de escala con precisión, se propone correr con un valor razonable de partida, verificar si el torque resultante cae en rango, y solo si no cae, reescalar analíticamente (aprovechando que el torque escala con λ³) en vez de repetir las corridas. Evita que una incertidumbre en una sola variable bloquee todo el avance de la Fase B. |
| **Preselección de componentes electrónicos antes de caracterizar el motor DC crudo** (`06_Seleccion_Actuador_de_Carga.md` §6.1) | Se seleccionaron BTS7960, INA219 y ESP32 con márgenes amplios sobre los valores de datasheet disponibles, sin esperar a la caracterización experimental completa del motor DC intervenido (que sigue pendiente). Permite avanzar la compra y el diseño electrónico en paralelo a una incertidumbre que se resolverá después. |

## 3. Cómo aplicar el principio hacia adelante

Para las decisiones que siguen abiertas, el principio sugiere un orden de prioridad:

1. **Cerrar el lazo completo primero**, aunque sea con la versión más simple de cada eslabón (p. ej., método de interpolación lineal antes que kriging; primer valor razonable de arquitectura física antes que la óptima).
2. **Declarar explícitamente las limitaciones** de la versión provisional (siguiendo la práctica ya usada en los documentos de XFLR5), en vez de presentarla como si fuera definitiva.
3. **Mejorar de forma iterativa** una vez que el sistema completo ya corrió al menos una vez de punta a punta — priorizando el eslabón que el propio sistema, ya en funcionamiento, muestre como el más limitante (no el que parezca más importante en abstracto antes de probarlo).

Este orden es coherente con la matriz de decisión ya usada para la reevaluación de arquitectura física (`Comparacion_Alternativas_Arquitectura_Fisica.md`): la opción actual (A) se mantiene como referencia mientras no haya evidencia de que otra alternativa resuelve un problema que el sistema, corriendo, demuestre ser real — no se cambia de arquitectura de forma preventiva sin ese dato.

## 4. Límite del principio — no es una excusa para omitir rigor

Este principio no reemplaza la verificación técnica ni el rigor de diseño ya aplicado en el proyecto (p. ej., el análisis de resistencia mecánica del brazo de torque, o las verificaciones de sanidad del pipeline XFLR5). Aplica específicamente a la **secuencia de trabajo entre subsistemas** — qué se resuelve primero y con qué nivel de detalle — no a la calidad del análisis dentro de cada subsistema una vez que se decide abordarlo. Una versión "que funciona mal" del sistema completo debe seguir siendo una versión con sus limitaciones bien entendidas y declaradas, no una versión descuidada.

## 5. Impacto sobre otros documentos del proyecto

| Documento | Impacto sugerido |
|---|---|
| `01_Especificacion_del_Proyecto.md` | Podría incorporarse una referencia breve a este principio en la sección de metodología/solución propuesta (§3), citando este documento. |
| `00_Administración/01_Cronograma.md` | El principio respalda explícitamente la lógica de paralelización ya presente en el cronograma (p. ej., avanzar software mientras se espera la llegada de componentes). |
| `04_CFD/01_Casos/03_Matriz_Casos_CFD_FaseB1.md` | El §2 (λ nominal de partida) puede citar este documento como el principio metodológico que lo respalda, en vez de justificarse solo por razones de cronograma. |

## Referencia

Recomendación verbal del profesor Frank Tinnap, Reunión de Avance, 28/08/2026 (`00_Administración/02_Registro_Reuniones_Avance.md`).
