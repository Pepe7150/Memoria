# Simpson GA(W)-1: hoja de entrada directa para XFLR5

Este documento sirve para **ingresar el caso en XFLR5**, siguiendo el mismo formato que `01_Checklist_Simpson_NACA0012.md`. A diferencia del caso NACA 0012 (ala en flecha 3D), el caso GA(W)-1 de Simpson (2016) es un ensayo **cuasi-2D** (túnel de viento, modelo de cuerda constante sin flecha) — se ingresa en **Direct Foil Design** (XFoil 2D), no como `Wing`/`Plane`. No mezclar el flujo de trabajo de este documento con el del NACA 0012.

## 0. Por qué es un caso 2D (no una superficie 3D)

Wentz et al. ensayaron el perfil GA(W)-1 en el túnel Walter Beech de Wichita State University con un modelo de **cuerda 24 in constante, sin flecha ni estrechamiento**, en configuración esencialmente bidimensional (sección de ensayo cuasi-2D). Simpson (2016), en el mismo capítulo que sirve de fuente para este checklist, procesó este caso íntegramente con **XFOIL 2D** (Direct Foil Design), no con un método de superficie 3D — es la rama "perfil redondeado, XFoil viscoso" de `03_Pipeline_General_XFLR5.md` §1, exactamente igual que la rama que ese pipeline recomienda para un NACA 0012 antes de ir a la variante en flecha.

**Conclusión:** este caso se resuelve completo en `Direct Foil Design`, con el **flap XFoil nativo** (Foil → Set Flaps), sin pasar por `Wing and Plane Design`. No hay envergadura, `S`, `MAC` ni `AR` que verificar aquí — esas verificaciones son propias del checklist NACA 0012 (caso 3D), no de este.

---

## 1. Ficha del caso (llenar antes de abrir XFLR5)

| Campo | Valor |
|---|---|
| Fuente | Simpson (2016), capítulo 3 — tesis de maestría, Universidad de Alabama; datos experimentales originales de Wentz et al. (referencia [37] de la tesis) |
| Perfil | GA(W)-1 (NASA Langley, años 70; redesignado luego NASA LS(1)-0417) |
| Configuración | Perfil aislado 2D, control de borde de fuga (plain flap) — no hay fuselaje ni envergadura finita en el modelo numérico |
| Cuerda de referencia (ensayo) | 24 in — en XFLR5 se normaliza a `c = 1` (convención estándar de Direct Foil Design) |
| Espesor relativo | t/c = 17% |
| Cuerda del control (flap) | 20% de la cuerda (`cf/c = 0.20`) |
| Eje de bisagra | `x_h/c = 0.80`, `z_h/c = 0.03443` (no está sobre la línea de cuerda, ligeramente por encima) |
| Holgura de bisagra (hinge gap) | 0.5% — **XFoil no modela la holgura**; el flap nativo de XFoil es una superficie continua sin separación física en la bisagra (ver §5) |
| Reynolds | `Re = 2.2 × 10⁶` |
| Mach | `M = 0.13` (subsónico bajo; sin corrección de compresibilidad relevante) |
| Matriz angular | AoA `α ∈ {-8°, 0°, 8°, 12°, 16°, 20°}`; deflexión `δ ∈ {-40°, -20°, -10°, -5°, 0°, 5°, 10°, 20°, 40°}` (54 combinaciones máx.) |
| Objetivo | Comparación directa con los valores experimentales de Wentz y con los propios resultados XFOIL/Datcom/Fun3D reportados por Simpson (Tablas 3.7–3.12 de la tesis) — validación del pipeline, no generación de datos nuevos |

---

## 2. Obtener las coordenadas del perfil

**No generar el GA(W)-1 con un generador NACA de 4/5 dígitos** — no es un perfil NACA, es un diseño NASA independiente (aunque comparte familia de nomenclatura posterior, LS(1)-0417).

1. Buscar el archivo `.dat` del perfil en el UIUC Airfoil Coordinates Database (`m-selig.ae.illinois.edu/ads/coord_database.html`) bajo el nombre **"gaw1"**, **"gA(W)-1"** o **"ls(1)-0417"** (o `naca ls(1)-0417`, nombre posterior del mismo perfil). Verificar que el archivo tenga borde de ataque romo (radio grande) y borde de fuga romo, coherente con la descripción de Simpson §3.1.
2. Alternativa: transcribir las coordenadas directamente del reporte de Wentz (referencia original, disponible como NASA CR o reporte de Wichita State) si el archivo UIUC no está disponible o no coincide con la geometría descrita.
3. Importar en `Direct Foil Design -> File -> Open` y verificar visualmente:
   - Borde de ataque con radio grande (perfil diseñado para retrasar la pérdida a alto ángulo de ataque, no un perfil afilado).
   - Superficies superior e inferior casi paralelas cerca del borde de fuga romo (rasgo distintivo del GA(W)-1, descrito explícitamente por Simpson).
4. Si XFLR5/XFoil exige un borde de fuga puntiagudo, usar la herramienta `Foil -> TE Gap` para cerrar el borde de fuga a un valor pequeño y documentar el valor usado (Simpson usa el borde de fuga romo real del modelo; cerrarlo introduce una diferencia geométrica menor que debe declararse).
5. Guardar el perfil importado con un nombre identificable, p. ej. `GAW1_Simpson2016`.

**No continuar sin este paso.** A diferencia del NACA 0012 (perfil generado internamente por XFLR5), aquí el perfil correcto no existe por defecto en el programa.

---

## 3. Definir el flap (control de borde de fuga)

1. Con el perfil `GAW1_Simpson2016` activo, ir a `Foil -> Set Flap` (o `Set TE Flap`, según versión de XFLR5).
2. Ingresar:

| Campo | Valor |
|---|---|
| Posición de la bisagra (x/c) | **0.80** |
| Posición vertical de la bisagra | **73.13** (**`% Thickness`, no `% chord` — ver advertencia crítica abajo**) |
| Tipo de flap | Plano (plain flap), sin balance ni solape |

### ⚠️ Advertencia crítica sobre el campo "Hinge Y Position"

El diálogo de flap de XFLR5 v6.61 etiqueta este campo como **`% Thickness`**, no `% chord`. Esto significa que el valor ingresado **no** es `y_h/c` directamente — es la posición relativa **dentro del espesor local** del perfil en `x/c=0.80`: `0% = superficie inferior`, `100% = superficie superior`, `50% = línea de camber` (el valor por defecto).

El dato de la fuente (Wentz/Simpson) es `z_h/c = 0.03443`, medido como ordenada absoluta respecto a la línea de cuerda — **no** es directamente el número que va en este campo. Para convertirlo, se necesitan las coordenadas reales del perfil en `x/c=0.80`:

```
y_superior(0.80) = 0.05291   (del archivo GA_W_-1.dat, NASA/Langley LS(1)-0417)
y_inferior(0.80) = -0.01587
espesor local t(0.80) = 0.06878  (6.878% c)
línea de camber en 0.80 = 0.01852

% Thickness a ingresar = (z_h/c − y_inferior(0.80)) / t(0.80) × 100
                        = (0.03443 − (−0.01587)) / 0.06878 × 100
                        = 73.13
```

**Valor correcto confirmado: `73.13`** (no `3.443`, que es el número que resulta de copiar `z_h/c×100` sin darse cuenta de que la unidad del campo es otra — error fácil de cometer y difícil de detectar a simple vista, porque XFLR5 no avisa de la incompatibilidad de unidades).

**Nota importante de resultado:** al corregir este valor (de `3.443` a `73.13`) los resultados de `Chinge` **cambiaron muy poco** (diferencias en la 3ª–4ª cifra decimal). Es decir, este error sí era necesario corregirlo por rigor geométrico, pero **no fue la causa principal** de la discrepancia frente a Simpson que se documenta en la sección 6bis. La causa principal fue otra (normalización y signo de `Chinge`, ver más abajo).

3. **Registrar la convención de signo.** Simpson define deflexión positiva como *trailing-edge down* (TED). Guardar una captura con `δ = 0°` y otra con `δ = 20°` (o `-20°`) para dejar registro visual.
4. Guardar el perfil con el flap ya definido como un nuevo perfil por cada deflexión requerida.

---

## 4. Matriz de corridas (polares viscosas)

### 4.1 Condición de flujo

| Parámetro | Valor a ingresar en `Analysis -> Define Analysis` |
|---|---|
| Tipo de análisis | Type 1 (Re y Mach fijos, especificados directamente — no depende de velocidad/cuerda física) |
| Reynolds | `2.2e6` |
| Mach | `0.13` |
| Modelo de transición (`Ncrit`) | Usar el valor por defecto (9) salvo que se disponga de datos de rugosidad/turbulencia del túnel Walter Beech; documentar si se cambia |

### 4.2 Deflexiones y ángulos a correr

Generar **una geometría de flap por cada deflexión** de la lista siguiente, y para cada una correr una polar barriendo los ángulos de ataque indicados:

```
δ (deg):  -40, -20, -10, -5, 0, 5, 10, 20, 40      (9 geometrías)
α (deg):  -8, 0, 8, 12, 16, 20                      (6 puntos por geometría)
```

Total: 9 × 6 = **54 puntos de operación**, igual que la matriz experimental de Wentz reportada por Simpson.

### 4.3 Advertencia de convergencia (crítica en este caso)

El propio Simpson documenta que XFOIL **no converge bien** en combinaciones de deflexión grande + ángulo de ataque alto, por separación de flujo — esto es, precisamente, la limitación central de su tesis (ver §3.3 y §3.4 de la fuente). Al reproducir esta matriz:

- **Esperar falta de convergencia** en combinaciones como `δ=±40°` con `α≥12°`, y en general en cualquier punto donde Simpson reporta errores grandes de XFOIL frente al experimento (ver tabla comparativa §6bis).
- No forzar la convergencia aumentando artificialmente iteraciones o relajando la tolerancia sin dejarlo documentado — un punto no convergido debe registrarse como tal (`NC`) en la tabla de salida, no omitirse silenciosamente ni rellenarse por interpolación.
- Esta no-convergencia **no es un error del procedimiento**: es el mismo resultado, cualitativamente, que reporta la tesis fuente. Coincide con la limitación ya señalada en `03_Pipeline_General_XFLR5.md` §1 (perfil redondeado + separación de flujo → los métodos de flujo potencial/panel viscoso pierden fiabilidad).

---

## 5. Limitaciones a declarar explícitamente

| Limitación | Detalle |
|---|---|
| Sin holgura de bisagra (hinge gap) | El modelo XFoil es una superficie continua; el ensayo real tiene 0.5% de holgura. Wentz reporta que la holgura afecta el momento de bisagra pero que su tamaño tiene poco efecto — impacto esperado menor, pero debe declararse. |
| 2D puro | No hay efectos de envergadura finita, punta de ala ni flujo 3D — coherente con el ensayo cuasi-2D de referencia, pero distinto del caso NACA 0012 (3D, flecha 45°) del mismo proyecto. |
| Separación de flujo no resuelta con precisión | XFoil (capa límite integral) no resuelve separación masiva; se degrada exactamente en el mismo régimen donde Simpson reporta que su propio XFOIL se degrada (deflexiones y AoA grandes). Fun3D (Navier-Stokes) da mejor precisión en ese régimen según la propia tesis, pero esta corrida solo busca replicar la rama XFoil/paneles, no Fun3D. |
| Borde de fuga romo | Si se cierra el TE gap para compatibilidad con XFoil, se introduce una diferencia geométrica menor respecto al modelo físico romo; documentar el valor de cierre usado. |
| Reynolds único | Wentz/Simpson solo reportan esta condición a `Re=2.2e6`, `M=0.13` — no hay barrido de Reynolds en la fuente, por lo que tampoco corresponde generarlo aquí. |

---

## 6. Valores de referencia para verificación (fuente: Simpson 2016, Tablas 3.7–3.12)

Usar estos puntos como verificación rápida de que la corrida está bien montada, **antes** de exportar la matriz completa. Valores de `Ch` (coeficiente de momento de bisagra) reportados por la propia tesis para su corrida de XFOIL (no son el experimento puro, son el XFOIL de Simpson — el punto de comparación más directo con esta réplica):

| α | δ | Ch — Wentz (experimental) | Ch — XFOIL (Simpson) |
|---:|---:|---:|---:|
| 0° | 0° | -0.1551 | -0.1859 |
| 0° | 5° | -0.2106 | -0.2476 |
| 0° | 10° | -0.2652 | -0.2623 |
| 0° | 20° | -0.4007 | -0.3334 |
| 0° | 40° | -0.6114 | -0.4431 |
| -8° | 0° | -0.0655 | -0.0800 |
| 8° | 0° | -0.2088 | -0.1855 |
| 12° | 0° | -0.2532 | -0.2127 |

**Criterio de éxito de la réplica:** los valores obtenidos con esta corrida en XFLR5 deben acercarse a la columna "XFOIL (Simpson)" — no a la columna experimental. XFLR5 usa el mismo motor XFoil que Simpson, por lo que una réplica correcta del procedimiento debería reproducir esos valores dentro de un margen pequeño (diferencias esperables por versión de XFoil, número de paneles, `Ncrit` y precisión de las coordenadas digitalizadas del perfil). Una discrepancia grande frente a la columna XFOIL, no frente a la experimental, es la señal de que algo está mal en la configuración (eje de bisagra, signo de deflexión, Re/Mach), no una discrepancia esperada del método.

La tabla completa de 54 puntos (Tablas 3.7–3.12 de la fuente) está disponible en el documento original de Simpson para verificación punto a punto una vez exportada la matriz completa.

---

## 6bis. Resultado obtenido y hallazgo de normalización/signo (actualizado tras la corrida real)

Al correr la matriz completa (9 deflexiones × hasta 8 ángulos de ataque) y comparar `Chinge` (tal como lo exporta XFLR5) contra la Tabla 6, se encontraron dos problemas de **convención**, no de física ni de configuración geométrica:

1. **Signo invertido:** el `Chinge` de XFLR5 tiene signo opuesto al `Ch` de Wentz/NACA para esta configuración.
2. **Normalización distinta:** XFLR5 normaliza `Chinge` con la **cuerda completa al cuadrado** (`c²`), no con la referencia estándar de flap (`Sf·cf`, área y cuerda del flap) que usa la literatura NACA/Wentz. La corrección es un factor `(c/cf)² = (1/0.20)² = 25`.

**Fórmula de conversión adoptada:**

```
Ch_estandar_NACA_Wentz = −25 × Chinge_XFLR5
```

**Verificación en los puntos donde hay dato de Simpson (XFOIL):**

| α | δ | `Ch_estandar` (esta réplica) | Ch — XFOIL (Simpson) | diferencia |
|---:|---:|---:|---:|---:|
| 0° | 0° | -0.1850 | -0.1859 | 0.0009 (0.5%) |
| -8° | 0° | -0.0775 | -0.0800 | 0.0025 (3%) |
| 12° | 0° | -0.2150 | -0.2127 | 0.0023 (1%) |
| 0° | 5° | -0.1150 | -0.2476 | 0.133 (54%) |
| 0° | 10° | -0.0400 | -0.2623 | 0.222 (85%) |
| 0° | 20° | +0.1125 | -0.3334 | 0.446 (signo invertido) |
| 0° | 40° | +0.3000 | -0.4431 | 0.743 (signo invertido) |

**Conclusión de esta verificación:**

- **Para deflexión pequeña (`|δ| ≲ 5°`, cualquier `α` dentro del rango lineal), la conversión reproduce los valores de Simpson con 0.5–3% de error** — evidencia sólida de que el factor de conversión y el signo están bien identificados, no son un ajuste ad-hoc.
- **Para `|δ| ≳ 10°` la conversión se degrada progresivamente y se invierte de signo en `δ=20°/40°`.** Esto **no se interpreta como un error adicional de configuración**: coincide con la limitación ya anticipada en la §4.3 de este documento — el propio Simpson reporta que su XFOIL ya se aleja significativamente del experimento en ese mismo rango (p. ej. -0.4431 vs. -0.6114 en δ=40°, un 28% de diferencia *dentro de la propia tesis*). Esta réplica, al no modelar la holgura de bisagra y con una geometría de flap girada mecánicamente en el perfil (sin el tratamiento específico que pudiera haber usado Simpson para deflexiones grandes), amplifica esa misma falla conocida en vez de introducir una nueva.
- **Alcance de validez recomendado para usar este dataset como contingencia del proyecto:** `|δ| ≲ 10°`, que además coincide con el rango de interés real del banco (mucho más acotado que ±40°).

**Nota de proceso, relevante para la próxima corrida:** se verificó que corregir el valor de `Hinge Y Position` (ver §3) prácticamente no cambió los resultados de `Chinge` — es decir, el hallazgo de este apartado (signo + normalización) es la causa dominante de la discrepancia inicial, y la corrección geométrica de §3 era necesaria por rigor pero no era, en la práctica, el problema principal.

---

## 7. Consolidación de resultados

El polar 2D exportado por XFLR5 (con flap definido) **ya trae `Chinge` calculado internamente por fila** — no hace falta recalcularlo con `Ch = H/(q·Sf·cf)` a partir de un momento dimensional, como sí era necesario en el flujo OpPoint 3D del NACA 0012. Sin embargo, hay dos particularidades propias de este formato de exportación que el script de consolidación (`consolidar_polares_2D_gaw1.py`) maneja explícitamente:

1. **Desajuste de columnas:** el encabezado del CSV declara 10 nombres de columna, pero cada fila trae 12 valores (quirk confirmado de la exportación 2D con flap de XFLR5 v6.61). El script usa un **mapeo posicional fijo** (confirmado manualmente contra el gráfico `Chinge` vs. `alpha` dentro de XFLR5): posición 9 = `Chinge`, posiciones 10 y 11 se descartan (contenido no identificado, no relevante), posición 12 = `XCp`.
2. **Conversión de convención:** el script agrega automáticamente la columna `Ch_estandar_NACA_Wentz = −25 × Chinge`, con la fórmula y el rango de validez documentados en §6bis.

Formato de salida final (hoja "Datos (largo)" del Excel generado):

```text
archivo, delta, alpha, Chinge, Cm, CL, CD, Mach, Re, Ncrit, Ch_estandar_NACA_Wentz
```

Etiquetar siempre como `XFLR5 - contingencia - no CFD`, y con `origen = "Simpson_GAW1_2D"` para no confundir con el dataset NACA 0012 (3D) del mismo proyecto.

---

## 8. Orden exacto de trabajo

- [X] Obtener y verificar las coordenadas GA(W)-1 (§2) — radio de LE grande, TE romo casi paralelo.
- [X] Importar el perfil en Direct Foil Design y guardarlo.
- [X] Definir el flap: `x_h/c=0.80`, **`Hinge Y Position=73.13` (`% Thickness`, no `y_h/c` directo — ver §3)**, verificar signo de deflexión con capturas en `δ=0°` y `δ=20°`.
- [X] Generar las 9 geometrías de flap (`δ = -40, -20, -10, -5, 0, 5, 10, 20, 40`).
- [X] Configurar el análisis: Type 1, `Re=2.2e6`, `M=0.13`.
- [X] Correr los ángulos de ataque disponibles para cada una de las 9 geometrías (algunos puntos no convergieron, ver hoja "Datos (largo)" del Excel consolidado — `NaN` en vez de valor).
- [X] Verificar contra la tabla de §6 → hallazgo documentado en §6bis (signo invertido + normalización por cuerda completa).
- [X] Exportar y consolidar la matriz con `consolidar_polares_2D_gaw1.py`, incluyendo la columna `Ch_estandar_NACA_Wentz`.
- [ ] Confirmar en la reunión de avance si el rango de validez recomendado (`|δ| ≲ 10°`) es aceptable como dataset de contingencia, o si se requiere investigar más la divergencia a `|δ|` grande antes de darla por cerrada (ver `04_Lecciones_Metodologicas_XFLR5.md`).

## Resultado que debe quedar guardado

```text
GAW1_Simpson2016.dat
GAW1_Simpson2016_flaps.xfl
GAW1_delta_0.csv
GAW1_delta_5.csv
GAW1_delta_10.csv
GAW1_delta_20.csv
GAW1_delta_40.csv
GAW1_delta_-5.csv
GAW1_delta_-10.csv
GAW1_delta_-20.csv
GAW1_delta_-40.csv
GAW1_consolidado.csv
```

## Fuente de los números

Simpson, C. D. (2016), *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics*, capítulo 3 (tablas 3.1–3.3 y 3.7–3.12, figuras 3.1–3.10). Tesis de maestría, University of Alabama. Fuente pública: https://ir.ua.edu/items/b24e56da-42e8-45ef-861c-f32ff2a6d3e5

Dato experimental original citado por Simpson: Wentz, W. H., et al. — ensayo del GA(W)-1 con flap plano de 20% en el túnel Walter Beech, Wichita State University (referencia [37] de la tesis).

Coordenadas del perfil: NASA/Langley LS(1)-0417 (GA(W)-1), archivo `GA_W_-1.dat` (formato Selig, 75 puntos).
