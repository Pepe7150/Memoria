# Lecciones metodológicas del pipeline XFLR5 (casos NACA 0012 y GA(W)-1)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Propósito de este documento:** consolidar, en un solo lugar, los hallazgos metodológicos obtenidos al replicar dos casos de literatura en XFLR5 (Simpson 2016: NACA 0012 en flecha 3D, y GA(W)-1 2D) — no son resultados de CFD del proyecto, sino aprendizajes sobre la **herramienta y el procedimiento** que condicionan cómo se debe usar XFLR5/XFoil de aquí en adelante, incluida la futura CFD propia (Fase B, OpenFOAM). Pensado como insumo para la reunión de avance.

**Documentos relacionados:** `03_Pipeline_General_XFLR5.md`, `01_Checklist_Simpson_NACA0012.md`, `02_Checklist_Simpson_GAW1.md`.

---

## 1. Resumen ejecutivo

Se replicaron dos casos de la tesis de Simpson (2016) en XFLR5 como ejercicio de validación del pipeline de software antes de tener CFD propia: un caso 3D en flecha (NACA 0012) y un caso 2D con flap (GA(W)-1). El segundo caso, al comparar contra los valores de la propia tesis, arrojó inicialmente una discrepancia grande e inconsistente (factores de 15× a 150× según el punto, con inversiones de signo) que **no correspondía a error físico ni de discretización**, sino a dos causas identificables y corregibles:

1. Un campo de la interfaz de XFLR5 (`Hinge Y Position`) cuya unidad (`% Thickness`) no coincide con lo que su nombre sugiere (`y/c`) — fácil de configurar mal sin que el programa lo advierta.
2. Una diferencia real de **convención** entre la variable que exporta XFLR5 (`Chinge`) y la convención estándar de la literatura aeronáutica (Wentz/NACA) — tanto en signo como en normalización.

Una vez corregidas ambas causas, la réplica coincide con la fuente dentro de 0.5–3% en el rango de deflexión pequeña (`|δ| ≲ 5°`), lo que valida el procedimiento. La discrepancia que persiste en deflexiones grandes (`|δ| ≳ 20°`) es consistente con una limitación ya documentada por el propio Simpson (separación de flujo no resuelta bien por XFoil), no con un error de esta réplica.

---

## 2. Hallazgo 1 — Unidades de la interfaz de XFLR5 no siempre coinciden con el nombre del campo

Al definir el flap del GA(W)-1 (eje de bisagra en `x/c=0.80`, `y_h/c=0.03443` según Wentz/Simpson), el campo `Hinge Y Position` del diálogo de flap de XFLR5 **no está en `% chord`, sino en `% Thickness`** — la posición relativa dentro del espesor local del perfil en esa `x` (`0%`=superficie inferior, `100%`=superficie superior, `50%`=línea de camber).

Copiar directamente `0.03443 → 3.443` en ese campo (asumiendo que la unidad era `%chord`) ubica la bisagra en un punto geométricamente muy distinto al pretendido — casi pegada a la superficie inferior, en vez de por encima de la línea de camber como corresponde. El valor correcto, derivado de las coordenadas reales del perfil (`GA_W_-1.dat`) en `x/c=0.80` (`y_superior=0.05291`, `y_inferior=-0.01587`, espesor local `=0.06878`), es:

```
% Thickness = (z_h/c − y_inferior) / espesor_local × 100 = 73.13
```

**Dato relevante para el proceso, no solo para el resultado:** al corregir este valor, los resultados de `Chinge` cambiaron muy poco (3ª–4ª cifra decimal). Es decir, **este error era necesario corregirlo por rigor geométrico, pero no fue la causa dominante** de la discrepancia observada — la causa dominante fue el Hallazgo 2. Esto es en sí mismo una lección: **conviene aislar y corregir un problema a la vez, y volver a comparar contra la referencia después de cada corrección**, en vez de asumir que el primer error encontrado explica toda la discrepancia.

**Recomendación general:** antes de confiar en cualquier campo de XFLR5 cuyo nombre sea ambiguo o abreviado, verificar la unidad real (aquí, revisando el código fuente público de XFLR5) en vez de asumirla por el nombre visible en la interfaz.

---

## 3. Hallazgo 2 — La variable `Chinge` de XFLR5 no sigue la convención NACA/Wentz

Comparando la matriz completa contra los valores de Simpson (Tablas 3.7–3.12), se encontraron dos diferencias sistemáticas de convención, confirmadas empíricamente:

| Diferencia | Detalle |
|---|---|
| **Signo** | `Chinge` (XFLR5) tiene signo opuesto a `Ch` (Wentz/NACA) para esta configuración de flap. |
| **Normalización** | XFLR5 normaliza con la **cuerda completa al cuadrado** (`c²`); la convención NACA/Wentz normaliza con la referencia del flap (`Sf·cf`, área y cuerda del flap). Factor de corrección: `(c/cf)² = (1/0.20)² = 25`. |

**Conversión adoptada:** `Ch_estandar = −25 × Chinge_XFLR5`.

**Verificación:** en deflexión pequeña (`δ=0°`, distintos `α`) la conversión reproduce los valores de la propia tesis con 0.5–3% de error — evidencia de que el factor y el signo están bien identificados, no ajustados a posteriori para que "calzaran". En deflexión grande (`|δ|≥20°`) la conversión se degrada y hasta invierte de signo; esto coincide con que el propio Simpson reporta que su XFOIL ya diverge ~28% del experimento en ese mismo rango (separación de flujo no resuelta por el método de capa límite integral) — un efecto ya anticipado en el checklist antes de correr la matriz (§4.3), no una sorpresa.

**Implicación para el proyecto:** cualquier dataset de contingencia generado en XFLR5 con flap definido (no solo GA(W)-1) debe pasar por esta misma verificación de signo/normalización contra al menos un punto de referencia externo antes de usarse — no se puede asumir que `Chinge` es directamente comparable con la literatura sin más.

---

## 4. Diferencia de flujo de trabajo según el tipo de caso (2D vs. 3D)

Los dos casos replicados exigieron **procedimientos y scripts de exportación distintos** dentro del mismo programa, por tratarse de dos modos de análisis distintos:

| | NACA 0012 (Simpson) | GA(W)-1 (Simpson) |
|---|---|---|
| Naturaleza del ensayo de referencia | Estabilizador 3D en flecha (45°) | Perfil 2D, cuerda constante, sin flecha |
| Módulo de XFLR5 | `Wing and Plane Design` (VLM2 + polares 2D) | `Direct Foil Design` (XFoil 2D directo) |
| Formato de exportación usado | Punto de Operación (`OpPoint`) individual, con momento de flap dimensional | Polar completo, con `Chinge` ya adimensionalizado por fila |
| Cálculo de `Ch` | Manual: `Ch = H/(q·Sf·cf)` a partir del momento dimensional exportado | Ya viene calculado por XFLR5 (una vez corregida la convención, Hallazgo 2) |
| Script de consolidación | `consolidar_oppoints_xflr5.py` | `consolidar_polares_2D_gaw1.py` (no es el mismo script, ni una simple variante de parámetros) |

**Lección:** no existe un único pipeline de exportación/consolidación válido para "cualquier caso de XFLR5" — el tipo de geometría de referencia (2D vs. 3D) determina el módulo del programa a usar y, en consecuencia, el formato de archivo y el script de procesamiento. Esto es relevante para `03_Pipeline_General_XFLR5.md` (que ya distingue ramas de análisis, pero conviene reforzar esta distinción específica de exportación).

---

## 5. Un desajuste adicional, propio del formato de exportación 2D con flap

Independiente de los dos hallazgos anteriores: el CSV de polar 2D con flap de XFLR5 v6.61 declara **10 nombres de columna en el encabezado, pero cada fila trae 12 valores**. Un lector de CSV ingenuo (o `pandas` por defecto) asigna los 12 valores a los 10 nombres de forma posicional silenciosa, desplazando todas las columnas sin ningún error visible — la primera versión del script de consolidación produjo así una tabla con `Chinge` corrido de columna sin que nada indicara el problema.

**Corrección aplicada:** el script ahora usa un mapeo posicional fijo, confirmado manualmente contra el gráfico `Chinge` vs. `alpha` dentro de XFLR5 (columna 9 = `Chinge`; columnas 10 y 11 se descartan por contenido no identificado y no relevante; columna 12 = `XCp`), y **valida el número de campos por fila antes de procesar**, deteniéndose con un error explícito si el formato cambia.

**Lección general, más allá de este caso puntual:** cualquier script de consolidación de exportaciones de XFLR5 (o de cualquier herramienta externa) debería **validar la estructura de los datos antes de confiar en los nombres de columna declarados**, precisamente porque este tipo de desajuste no es detectable a simple vista y puede pasar a la tabla final sin ningún síntoma aparente (los números "se ven" razonables, solo están mal etiquetados).

---

## 6. Síntesis de recomendaciones para el resto del proyecto

1. **Antes de aceptar cualquier magnitud exportada de XFLR5 (o de la futura CFD en OpenFOAM) como parte de una tabla de carga**, verificarla contra al menos un punto de referencia externo conocido — no asumir que el nombre de una variable en el software coincide con la convención de la literatura.
2. **Corregir un problema a la vez y re-verificar después de cada corrección** (como se hizo aquí con `Hinge Y Position` primero, y con signo/normalización después) — permite aislar cuál corrección realmente explica la discrepancia, en vez de darlas todas por buenas sin evidencia.
3. **Los scripts de consolidación deben fallar de forma explícita ante un formato inesperado** (conteo de columnas, encabezados, etc.), no asignar datos por posición "a ciegas".
4. **El rango de validez de un dataset de contingencia debe declararse explícitamente** (aquí, `|δ| ≲ 10°`) en vez de presentar la matriz completa como igualmente confiable en todo su rango — la divergencia en deflexión grande es un resultado legítimo a documentar, no un defecto a ocultar.
5. Estos hallazgos son específicos de XFLR5/XFoil (interfaz, convenciones de exportación) y no necesariamente se trasladan a OpenFOAM — pero el **principio de verificación contra referencia externa antes de confiar en una magnitud exportada por cualquier software** sí aplica igual en la Fase B (CFD propia).

---

## 7. Estado de los dos casos de contingencia al cierre de este documento

| Caso | Estado | Rango de validez recomendado |
|---|---|---|
| NACA 0012 (Simpson) | Corrido, pendiente de la misma verificación sistemática de signo/normalización que se aplicó aquí a GA(W)-1 (no se ha repetido explícitamente ese chequeo sobre este caso) | Por confirmar |
| GA(W)-1 (Simpson) | Corrido y verificado contra la fuente | `|δ| ≲ 10°` (0.5–3% de error frente a Simpson en ese rango) |

**Pendiente sugerido:** aplicar la misma verificación de signo/normalización (Hallazgo 2) al caso NACA 0012 antes de darlo por validado — no hay garantía de que el momento de flap exportado en el flujo `OpPoint` 3D use la misma convención que se asumió al calcular `Ch = H/(q·Sf·cf)` manualmente en ese caso.
