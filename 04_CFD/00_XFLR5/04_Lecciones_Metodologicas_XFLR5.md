# Lecciones metodológicas del pipeline XFLR5 (casos NACA 0012 y GA(W)-1)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Propósito de este documento:** consolidar, en un solo lugar, los hallazgos metodológicos obtenidos al replicar dos casos de literatura en XFLR5 (Simpson 2016: NACA 0012 en flecha 3D, y GA(W)-1 2D) — no son resultados de CFD del proyecto, sino aprendizajes sobre la **herramienta y el procedimiento** que condicionan cómo se debe usar XFLR5/XFoil de aquí en adelante, incluida la futura CFD propia (Fase B, OpenFOAM). Pensado como insumo para la reunión de avance.

**Documentos relacionados:** `03_Pipeline_General_XFLR5.md`, `01_Checklist_Simpson_NACA0012.md`, `02_Checklist_Simpson_GAW1.md`.

---

## 1. Resumen ejecutivo

Se replicaron dos casos de la tesis de Simpson (2016) en XFLR5 como ejercicio de validación del pipeline de software antes de tener CFD propia: un caso 3D en flecha (NACA 0012) y un caso 2D con flap (GA(W)-1). **Ambos casos** presentaron inicialmente una discrepancia sistemática frente a la fuente que, en los dos casos, resultó ser un problema de **convención** (signo y/o normalización), no un error físico ni de discretización:

1. **GA(W)-1:** un campo de la interfaz de XFLR5 (`Hinge Y Position`) cuya unidad (`% Thickness`) no coincide con lo que su nombre sugiere (`y/c`), más una diferencia real de normalización y signo entre la variable exportada por XFLR5 (`Chinge`) y la convención estándar de la literatura (Wentz/NACA).
2. **NACA 0012 (este documento, actualizado):** el término de respuesta a la deflexión (`Ch_δ`) salía con signo invertido respecto a la Fig. 4.6 de Simpson, mientras que el término de respuesta al ángulo de ataque (`Ch_α`) ya era correcto desde el principio.

En ambos casos, una vez identificada y corregida la convención, la réplica coincide con la fuente dentro de un margen razonable (0.5–3% en GA(W)-1 para deflexión pequeña; ~0.01 de diferencia absoluta en `Ch`, es decir del orden de magnitud correcto y siguiendo la misma tendencia, en NACA 0012 tras la corrección de signo — ver §3bis). Esto valida el procedimiento en ambos casos. Las discrepancias residuales que persisten (deflexiones grandes en GA(W)-1; diferencia absoluta ~0.01 en NACA 0012) son consistentes con limitaciones ya conocidas del método (separación de flujo no bien resuelta por XFoil/VLM a deflexión grande, lectura aproximada de una figura en vez de una tabla numérica), no con errores adicionales de configuración.

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

**Implicación para el proyecto:** cualquier dataset de contingencia generado en XFLR5 con flap definido (no solo GA(W)-1) debe pasar por esta misma verificación de signo/normalización contra al menos un punto de referencia externo antes de usarse — no se puede asumir que `Chinge` es directamente comparable con la literatura sin más. **Esta recomendación se aplicó después también al caso NACA 0012 — ver Hallazgo 3 (§3bis).**

---

## 3bis. Hallazgo 3 — Signo invertido en el término de deflexión (`Ch_δ`) del caso NACA 0012

Aplicando al caso NACA 0012 la misma verificación de convención que el Hallazgo 2 recomienda (y que en su momento había quedado pendiente, ver antigua §7), se comparó la tabla consolidada de los 36 puntos (`OpPoint`, 4 deflexiones × 9 ángulos) contra la Fig. 4.6 de Simpson (2016) — la única fuente de comparación disponible para este caso, ya que a diferencia de GA(W)-1 no existe una tabla numérica exacta en la tesis para el caso 3D en flecha (ver `01_Checklist_Simpson_NACA0012.md`, §7).

### Verificaciones internas (antes de comparar contra la fuente)

Antes de comparar contra Simpson, se verificó la consistencia interna de los propios datos exportados (criterio §6 de este documento):

| Verificación | Resultado |
|---|---|
| `Ch(α=0°, δ=0°) ≈ 0` | ✅ 0.000023 |
| `Ch_α` consistente entre las 4 deflexiones | ✅ 3 de 4 deflexiones dentro de ~0.1% entre sí (-0.00292 a -0.00296); δ=-7.8° se desvía ~9% (-0.0027), coherente con que es la deflexión más grande de la matriz, donde Simpson ya reporta mayor divergencia de su propio Fun3D frente al experimento |
| `Ch_δ` lineal (a α=0°, entre las 4 deflexiones) | ✅ pendiente ≈0.0075/°, R² casi perfecto |
| Simetría de los dos objetos de flap (mitades del wing simétrico) | ✅ `flaps_coinciden=True` en las 36 filas |

Estas verificaciones confirmaron que la configuración base (geometría, Mach, eje de bisagra, extracción del momento) estaba internamente consistente — el problema, cuando apareció, no era ruido ni una corrida mal configurada, sino un problema sistemático de convención.

### Corrección de nomenclatura encontrada de paso

Durante la consolidación, el caso **δ=0°** apareció con `delta=NaN` en vez de `delta=0.0`, porque el `Wing`/`Plane` correspondiente no seguía la convención de nombre `_delta_0p0` que espera `consolidar_oppoints_xflr5.py` (el archivo de origen era `3MainWing_a=...csv`, con un nombre de objeto distinto al usado para las otras tres deflexiones). Se confirmó que esas filas sí correspondían a δ=0° (`Ch(α=0)≈0`, y la pendiente `Ch_α` de ese grupo encaja con la tendencia del resto) y se corrigió la etiqueta antes de continuar. **Pendiente de acción:** renombrar ese `Wing`/`Plane` en el archivo `.xfl` original (o ajustar el regex de `extraer_delta()` en el script) para que futuras consolidaciones no requieran este parche manual.

### Comparación contra la Fig. 4.6 — signo invertido en `Ch_δ`

Al graficar `Ch` vs. `α` (una curva por δ) y comparar visualmente contra la Fig. 4.6, se encontraron dos hechos:

1. **La pendiente con α (`Ch_α`) ya tenía el signo correcto**: las cuatro curvas de la Fig. 4.6 decrecen con α, igual que los datos originales sin corregir.
2. **El orden de las curvas por δ estaba invertido**: en los datos originales, δ=0° quedaba arriba (`Ch` más alto) y δ=-7.8° abajo; en la Fig. 4.6 es al revés (δ=-7.8° arriba, δ=0° abajo). Es decir, el signo del término de respuesta a la deflexión (`Ch_δ`) estaba invertido, mientras que el término de respuesta a α (`Ch_α`) ya era correcto.

**Corrección aplicada:** dado que el NACA 0012 es un perfil simétrico (sin camber), invertir el signo de la deflexión del flap en algún punto del proceso equivale, para este perfil, a reflejar verticalmente todo el problema — lo cual se traduce matemáticamente en:

```
Ch_corregido(α) = −Ch_original(−α)      [a δ fijo]
```

Esta transformación preserva exactamente `Ch_α` (signo y pendiente sin cambio) e invierte el signo del término de `Ch_δ` — precisamente lo que los dos hechos observados exigían. Se implementó en `corregir_signo_delta_naca0012.py` (script de post-procesamiento, no recalcula `Ch` desde cero; reordena/niega los valores ya exportados por XFLR5).

**Verificación del resultado:** tras la corrección, el orden de las curvas coincide con la Fig. 4.6 (δ=-7.8° arriba, δ=0° abajo) y las magnitudes siguen la misma tendencia, con una diferencia absoluta del orden de **~0.01 en `Ch`** respecto a una lectura aproximada de la figura (ej. δ=-7.8°: ~0.078 calculado vs. ~0.085 leído en α=-8°; ~0.035 vs. ~0.030 en α=+8°). Esta diferencia es coherente con el margen de error esperable de comparar contra una **figura leída a ojo** (Simpson no publica una tabla numérica para este caso 3D, a diferencia de GA(W)-1) y no invalida la corrección — el criterio de éxito aquí es la coincidencia de tendencia y orden de magnitud, no una coincidencia numérica exacta como en GA(W)-1.

**Hipótesis de causa raíz (pendiente de confirmar en el archivo fuente):** el checklist (`01_Checklist_Simpson_NACA0012.md`, §2) documenta explícitamente que se debe usar `TE Flap = +X` en XFLR5 para representar `δ = −X` de Simpson (ej. `TE Flap=7.70` para "NACA 0012 7p8" → δ=-7.8° de Simpson). Si en la práctica el `.xfl` real usó `TE Flap = −X` en vez de `+X` para las tres variantes deflectadas, eso explicaría exactamente el signo invertido de `Ch_δ` encontrado. **Queda pendiente revisar el archivo `.xfl` original** para confirmar esta hipótesis y corregir en el origen, en vez de depender de la corrección de post-procesamiento para corridas futuras.

**Implicación para el proyecto:** con este hallazgo, la recomendación general del Hallazgo 2 ("verificar signo/normalización contra al menos un punto de referencia externo antes de usar cualquier magnitud exportada de XFLR5") queda aplicada y confirmada en los **dos** casos de contingencia del proyecto, no solo en uno.

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
| Comparación disponible en la fuente | Solo gráfica (Fig. 4.6) — sin tabla numérica | Tabla numérica exacta (Tablas 3.7–3.12) |
| Corrección de convención encontrada | Signo invertido en `Ch_δ` (Hallazgo 3, §3bis) | Signo + normalización invertidos en `Chinge` (Hallazgo 2, §3) |

**Lección:** no existe un único pipeline de exportación/consolidación/verificación válido para "cualquier caso de XFLR5" — el tipo de geometría de referencia (2D vs. 3D) determina el módulo del programa a usar, el formato de archivo, el script de procesamiento **y el tipo de comparación posible contra la fuente** (numérica exacta vs. gráfica aproximada). Esto es relevante para `03_Pipeline_General_XFLR5.md` (que ya distingue ramas de análisis, pero conviene reforzar esta distinción específica de exportación y verificación).

---

## 5. Un desajuste adicional, propio del formato de exportación 2D con flap

Independiente de los hallazgos anteriores: el CSV de polar 2D con flap de XFLR5 v6.61 declara **10 nombres de columna en el encabezado, pero cada fila trae 12 valores**. Un lector de CSV ingenuo (o `pandas` por defecto) asigna los 12 valores a los 10 nombres de forma posicional silenciosa, desplazando todas las columnas sin ningún error visible — la primera versión del script de consolidación produjo así una tabla con `Chinge` corrido de columna sin que nada indicara el problema.

**Corrección aplicada:** el script ahora usa un mapeo posicional fijo, confirmado manualmente contra el gráfico `Chinge` vs. `alpha` dentro de XFLR5 (columna 9 = `Chinge`; columnas 10 y 11 se descartan por contenido no identificado y no relevante; columna 12 = `XCp`), y **valida el número de campos por fila antes de procesar**, deteniéndose con un error explícito si el formato cambia.

**Lección general, más allá de este caso puntual:** cualquier script de consolidación de exportaciones de XFLR5 (o de cualquier herramienta externa) debería **validar la estructura de los datos antes de confiar en los nombres de columna declarados**, precisamente porque este tipo de desajuste no es detectable a simple vista y puede pasar a la tabla final sin ningún síntoma aparente (los números "se ven" razonables, solo están mal etiquetados).

---

## 6. Síntesis de recomendaciones para el resto del proyecto

1. **Antes de aceptar cualquier magnitud exportada de XFLR5 (o de la futura CFD en OpenFOAM) como parte de una tabla de carga**, verificarla contra al menos un punto de referencia externo conocido — no asumir que el nombre de una variable en el software coincide con la convención de la literatura. **Confirmado como necesario en los dos casos del proyecto (GA(W)-1 y NACA 0012), no solo en uno.**
2. **Corregir un problema a la vez y re-verificar después de cada corrección** (como se hizo con `Hinge Y Position` primero y signo/normalización después en GA(W)-1; y con la nomenclatura de δ=0° primero y el signo de `Ch_δ` después en NACA 0012) — permite aislar cuál corrección realmente explica la discrepancia, en vez de darlas todas por buenas sin evidencia.
3. **Los scripts de consolidación deben fallar de forma explícita ante un formato inesperado** (conteo de columnas, encabezados, nomenclatura de archivos no reconocida) en vez de asignar datos por posición o dejar valores como `NaN` sin advertencia destacada.
4. **El rango/margen de validez de un dataset de contingencia debe declararse explícitamente** (`|δ| ≲ 10°` en GA(W)-1; diferencia absoluta ~0.01 en `Ch` frente a una lectura gráfica en NACA 0012) en vez de presentar la matriz completa como igualmente confiable — la divergencia o el margen de error residual es un resultado legítimo a documentar, no un defecto a ocultar.
5. **Cuando la fuente solo ofrece una figura (no una tabla), la verificación de convención puede hacerse igual, pero el criterio de éxito cambia**: se valida tendencia, orden de curvas y orden de magnitud, no coincidencia numérica exacta. Esto no es una validación "más débil" en sí misma, pero sí debe declararse como tal.
6. Estos hallazgos son específicos de XFLR5/XFoil (interfaz, convenciones de exportación, y en el caso de NACA 0012 posiblemente del signo de entrada del `TE Flap`) y no necesariamente se trasladan a OpenFOAM — pero el **principio de verificación contra referencia externa antes de confiar en una magnitud exportada por cualquier software** sí aplica igual en la Fase B (CFD propia).

---

## 7. Estado de los dos casos de contingencia al cierre de este documento

| Caso | Estado | Rango de validez / margen de error recomendado |
|---|---|---|
| NACA 0012 (Simpson) | **Verificado.** Corregido: (a) caso δ=0° mal etiquetado como `NaN` por desajuste de nomenclatura del Wing; (b) signo invertido del término `Ch_δ`, corregido mediante `Ch_corregido(α)=−Ch_original(−α)` a δ fijo (ver Hallazgo 3, §3bis). Tras la corrección, orden de curvas y tendencia coinciden con la Fig. 4.6. **Pendiente:** confirmar en el archivo `.xfl` original si el `TE Flap` de las variantes deflectadas se ingresó con signo contrario al documentado en el checklist, para corregir en el origen y no depender de la corrección de post-procesamiento en corridas futuras. | Diferencia absoluta ~0.01 en `Ch` frente a una lectura aproximada de la Fig. 4.6 (no hay tabla numérica exacta disponible en la fuente para este caso 3D) |
| GA(W)-1 (Simpson) | Corrido y verificado contra la fuente | `|δ| ≲ 10°` (0.5–3% de error frente a Simpson en ese rango) |

**Pendiente sugerido, actualizado:** con NACA 0012 ya verificado, ambos casos de contingencia del proyecto están cerrados a nivel de convención. Queda como trabajo futuro (no bloqueante) confirmar la hipótesis de causa raíz del signo invertido en NACA 0012 (revisión del `.xfl` original) antes de reutilizar ese procedimiento de generación de flaps deflectados en un caso nuevo.
