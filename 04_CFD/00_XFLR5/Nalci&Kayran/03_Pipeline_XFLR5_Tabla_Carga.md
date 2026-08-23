# Pipeline: Geometría → XFLR5 → Tabla de Carga de Contingencia

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Objetivo de este documento:** dejar registrado, paso a paso, el procedimiento completo para generar valores de referencia de momento de bisagra en XFLR5 a partir de una geometría de referencia — de modo que sea reproducible sin tener que reconstruir el razonamiento desde cero, tanto si se repite para la geometría actual (Nalci & Kayran) como si se repite para una geometría nueva (p. ej. si el objeto de diseño cambia a UAV, ver `01_Casos/01_Geometria_Aleta_Referencia.md` §9).

**Estado:** Pipeline probado end-to-end con la geometría de Nalci & Kayran (2014). Genera un dataset de **contingencia** (no CFD) en 2 dimensiones (Mach, ángulo total).

**Documentos relacionados:** `01_Casos/01_Geometria_Aleta_Referencia.md`, `02_Valores_Referencia_XFLR5.md`, `00_Administración/02_Registro_Reuniones_Avance.md`.

---

## 0. Cuándo usar este pipeline

- Para obtener un **tercer punto de comparación** (junto a literatura y CFD propia) del momento de bisagra, con bajo costo computacional.
- Para generar un **dataset de contingencia** que permita probar el software de interpolación/control (RF-PRO-01/02, RF-SWC-02) antes de que la CFD propia del proyecto esté lista.
- **No usar** como sustituto de la caracterización CFD final del proyecto — ver limitaciones en §7.

## 1. Generar las coordenadas del perfil (Python)

**Script:** `generar_perfil_doble_cuna.py`

- Define t/c en raíz y punta (para Nalci & Kayran: 4/156 y 2.2/78), y la posición del quiebre de espesor máximo (`X_TMAX`, default 0.5 = 50% cuerda).
- Genera dos archivos `.dat` en formato Selig (TE→LE→TE), normalizados a cuerda=1: `aleta_raiz.dat`, `aleta_punta.dat`.
- Verifica automáticamente que el espesor máximo generado coincida con el t/c nominal (chequeo de sanidad incluido en el script).

**Si se repite con otra geometría:** solo cambiar `TC_RAIZ`, `TC_PUNTA`, `X_TMAX` (si el perfil deja de ser doble cuña, hay que rehacer la función `espesor_doble_cuna` del script — no es directamente reutilizable para otro tipo de perfil, p. ej. NACA).

## 2. Importar el perfil en XFLR5

1. `Direct Foil Design` → `File` → `Open` → cargar cada `.dat` (raíz y punta quedan como dos perfiles separados en el proyecto).
2. No es necesario correr análisis viscoso de XFoil sobre el perfil en este paso — el análisis relevante se hace en 3D (paso 4).

## 3. Construir la geometría 3D — objeto `Wing` aislado

**Punto crítico:** usar `Define (Advanced users)` con **`isFin = true`**, NO crear un objeto `Plane`. Un `Plane` siempre asume dos semi-alas simétricas respecto a un fuselaje central — no se puede desactivar esa duplicación aunque se desmarque "Symmetric". Un `Wing` con `isFin=true` permite una superficie verdaderamente aislada.

**Tabla de secciones** (raíz y punta):

| Sección | Y (mm) | Chord (mm) | Offset (mm) | Dihedral (°) | Foil |
|---|---|---|---|---|---|
| Raíz | 0 | c_raíz | 0 | 0 | aleta_raiz |
| Punta | envergadura | c_punta | envergadura × tan(flecha LE) | — | aleta_punta |

Para Nalci & Kayran: Y=150mm, Chord=78mm, Offset=150×tan(27.5°)≈78.1mm.

**Twist:** 0° en ambas secciones (sin alabeo geométrico documentado en la referencia).

**Pestaña Inertia:**
- `Mass`: cualquier valor no nulo (no afecta el resultado del polar estático — solo se usa en análisis de estabilidad dinámica, que no corresponde aquí).
- `X_cog`: posición del **eje de bisagra** (para Nalci & Kayran: 50% de la cuerda de raíz = 78 mm desde el LE de la raíz, mismo origen que la geometría del wing). **Este es el punto de referencia real del momento `Cm` reportado por el polar** — verificar con una prueba de un punto (correr con dos valores de X_cog distintos; si `Cm` cambia, confirma que el CoG sí es la referencia usada).
- `Z_cog`: 0 (perfil simétrico sin curvatura).

**Verificación de geometría:** revisar que el área de planta (`S`) y la cuerda media aerodinámica (`c̄`/MAC) reportados por XFLR5 coincidan con el cálculo analítico:
```
S = envergadura × (c_raíz + c_punta)/2
MAC = (2/3)·c_raíz·(1+λ_taper+λ_taper²)/(1+λ_taper)
```
(`λ_taper` = razón de estrechamiento, no confundir con el factor de escala del banco). Si no coincide, revisar unidades y filas de la tabla de secciones antes de continuar — un error aquí se propaga silenciosamente a todos los resultados dimensionales.

## 4. Configurar y correr el análisis

- **Tipo de análisis:** paneles 3D (`3D Panels`), **no VLM** — VLM reduce el perfil a su línea media y ANULA el efecto del espesor doble cuña que se generó en el paso 1.
- **Polar Type:** Type 1 (Fixed speed). Por el flag `isFin`, el ángulo barrido puede aparecer etiquetado como "alpha" o "beta" según la versión — en cualquier caso corresponde al ángulo total de incidencia de la aleta (deflexión, ver limitación de §7).
- **Condición atmosférica:** fijar por Altitud + Temperatura (no por densidad directa). Recomendado: 0 m, 15°C (ISA estándar, ρ=1.225 kg/m³, a=340.3 m/s) — evitar combinaciones no realistas (p. ej. 15°C a 5000 m).
- **Velocidad:** convertir cada Mach objetivo a m/s con `V = Mach × a`.
- **Rango angular:** definir según el límite físico de la referencia (para Nalci & Kayran: ±15°, ver Tabla 2 de la tesis).
- **Límite de 100 puntos (XFLR5 v6.61):** si `rango_total / Δ > 100`, dividir en 2+ sub-corridas (p. ej. -15° a 0° y 0.25° a 15°) — XFLR5 las concatena automáticamente en el mismo polar si se mantienen los demás parámetros idénticos.

## 5. Exportar y consolidar

1. Exportar cada polar (uno por Mach) a Excel/CSV.
2. Consolidar con un script Python (leer con `header=6` dado el formato de exportación de XFLR5, que incluye metadata en las primeras filas) — columnas relevantes: `alpha` (ángulo), `Cm`, `q`, `M` (momento dimensional, ya calculado por XFLR5 con su propio S y c̄).
3. Guardar en formato ancho consolidado (`momento_bisagra_consolidado.csv`): una fila por ángulo, una columna de `M` y `Cm` por Mach.

## 6. Verificaciones de sanidad (aplicar siempre, no solo en la corrida inicial)

| Verificación | Cómo | Umbral de alerta |
|---|---|---|
| Antisimetría | `M(-β) ≈ -M(β)` en todo el rango, no solo en los extremos | Error relativo > ~1% |
| Escalado con Mach | `M(Mach_a)/M(Mach_b) ≈ (V_a/V_b)²` | Desviación > ~1% |
| Monotonía | `M(β)` estrictamente creciente, sin quiebres | Cualquier no-monotonía inesperada |
| Linealidad | Ajuste lineal de `M` vs. `β`, revisar R² | R² notablemente bajo (<0.99) sugiere problema numérico, no necesariamente físico |
| Invariancia de `Cm` con Mach | Comparar `Cm` entre corridas de distinto Mach | Si `Cm` es idéntico entre Mach (como en este caso), confirma que **no hay corrección de compresibilidad activa** — limitación a declarar, no a "arreglar" |
| Orden de magnitud vs. literatura | Comparar contra el valor de diseño de la fuente de geometría | Diferencia %>50-100% amerita revisar geometría/unidades antes de aceptar |

## 7. Limitaciones del método (declarar siempre junto con cualquier resultado)

1. **Flujo potencial puro, sin viscosidad:** no captura separación (relevante en el borde de ataque agudo del doble cuña a ángulos altos) ni arrastre viscoso.
2. **Sin corrección de compresibilidad:** verificado empíricamente (§6) — el `Cm` no cambia con Mach en esta configuración. A partir de M~0.3 esto empieza a ser una simplificación no despreciable.
3. **Degeneración AoA/deflexión:** un modelo de aleta aislada sin fuselaje no distingue ángulo de ataque del vehículo de deflexión de la superficie — ambos son el mismo ángulo total (ver `01_Casos/01_Geometria_Aleta_Referencia.md` §6).
4. **Sin velocidad angular de deflexión:** el método es estático/cuasi-estacionario; no puede proveer la cuarta dimensión de la superficie de respuesta acordada en el Avance I (ver `01_Casos/01_Geometria_Aleta_Referencia.md` §7).
5. **Bordes agudos y límite de convergencia:** en perfiles de espesor delgado con LE/TE agudos, ángulos altos pueden requerir mallado más fino o toparse con no convergencia — no observado en este dataset, pero a vigilar si se cambia la geometría.

## 8. Generar la tabla de carga de contingencia (formato largo, para el software)

**Script:** `generar_tabla_contingencia_xflr5.py`

- Lee `momento_bisagra_consolidado.csv` (formato ancho).
- Aplica el factor de escala `LAMBDA_ESCALA` (parametrizable, **por defecto 1.0 = sin escalar**, ya que λ sigue pendiente de cierre oficial — ver `01_Casos/01_Geometria_Aleta_Referencia.md` §5).
- Genera `tabla_carga_contingencia_xflr5.csv` en formato largo (una fila por combinación Mach/ángulo), con:
  - Metadata embebida en el propio archivo (comentarios `#`) declarando el origen y todas las limitaciones de §7 — para que la información no se pierda si el archivo circula sin este documento adjunto.
  - Columna de envolvente reportable (RF-CFD-04): rango de Mach y ángulo cubiertos.
  - Columna `torque_bisagra_Nm_referencia_sin_escalar`, para poder recalcular con otro λ sin volver a correr XFLR5.

**Para regenerar con la escala definitiva:** una vez que λ se cierre (Fase B1 del cronograma), cambiar `LAMBDA_ESCALA` en el script y volver a correrlo — no requiere repetir ningún paso anterior.

## 9. Extensión a otras altitudes (post-procesamiento, sin nuevas corridas)

**Hallazgo:** a Mach fijo, `q = ½ρV² = ½·ρ·(Mach·a)²` depende únicamente de `K(altitud) = ½·ρ(altitud)·a(altitud)²` — una constante por condición atmosférica. Dado que `Cm` ya se verificó independiente de Mach (§6bis) y el método es inviscid (sin dependencia de Reynolds/densidad en el coeficiente), `Cm` tampoco depende de la altitud. Por lo tanto:

```
M(Mach, ángulo, altitud) = Cm(ángulo) · K(altitud) · Mach² · S · c̄
```

**Esto significa que la altitud NO requiere una nueva dimensión de corridas en XFLR5** — solo se necesita el par `(ρ, a)` que XFLR5 reporta para cada altitud/temperatura de interés (leído directamente del panel de condiciones de vuelo, sin correr ningún polar), y aplicar el factor `K(altitud)/K(0)` a la curva ya calculada a nivel del mar.

**Verificación realizada (5000 m, T=-17.5°C ISA):**

| Cantidad | Valor |
|---|---|
| ρ(5000m) | 0.843 kg/m³ |
| a(5000m) | 320.5 m/s |
| M calculado (Mach0.6, β=15°) vía K(altitud) | 2.6552 N·m |
| M reportado por XFLR5 (corrida de verificación) | 2.66 N·m |
| Diferencia | 0.18% — verificado |

**Advertencia importante — corrección de un error propio:** inicialmente se intentó predecir este valor asumiendo que XFLR5 usa la fórmula barométrica ISA estándar de libro para `p(altitud)`. Esa predicción (2.320 N·m) **no coincidió** con el resultado real (2.66 N·m) — un 15% de diferencia. Al verificar, la presión que implican `ρ` y `T` reportados por XFLR5 a 5000 m (61864 Pa) difiere en 14.5% de la presión ISA de libro (54020 Pa), lo que indica que el modelo atmosférico interno de XFLR5 no sigue exactamente esa fórmula. **Conclusión metodológica: no asumir ninguna fórmula atmosférica externa — usar siempre los valores de `ρ` y `a` que XFLR5 reporta directamente** para la altitud/temperatura configurada, en vez de calcularlos de forma independiente.

**Limitación (igual que con Mach):** esta simplificación depende de que el método sea inviscid (sin Reynolds). En la CFD viscosa propia del proyecto (Fase B), el número de Reynolds sí depende de la altitud a igual Mach, y `Cm` podría tener una dependencia real (aunque probablemente secundaria) de la altitud — no se debe asumir que este atajo aplica directamente a la CFD sin verificación.

**Nota sobre el alcance del proyecto:** la altitud no aparece actualmente como variable de entrada en ningún documento del proyecto (`02_Requisitos_Funcionales.md`, RF-CFD-02 solo define Mach/AoA/deflexión). Ver pregunta 5 agregada en `00_Administración/02_Registro_Reuniones_Avance.md` (reunión 28/08/2026).

## 10. Qué NO resuelve este pipeline (siguiente trabajo, fuera de este documento)

- El **módulo de interpolación del software del banco** (RF-PRO-01/02) — este pipeline solo genera el archivo de entrada; el módulo que lo lee, interpola y lo sirve en tiempo real al Controlador es trabajo de la Fase D del cronograma, independiente de este documento.
- La **CFD propia del proyecto** (Fase B) — este pipeline es un atajo de bajo costo, no un reemplazo.
- La **matriz de casos CFD final** (Mach, ángulo, velocidad angular) — sigue pendiente de definir en Fase B1, informada pero no resuelta por este pipeline.

## 11. Checklist rápido para repetir el pipeline con una geometría nueva

- [ ] Extraer geometría de la nueva fuente (cuerdas, envergadura, flecha, perfil, t/c, posición del eje de bisagra).
- [ ] Ajustar parámetros en `generar_perfil_doble_cuna.py` (o rehacer si el perfil no es doble cuña).
- [ ] Reconstruir el `Wing` en XFLR5 con la nueva tabla de secciones (§3).
- [ ] Definir rango angular según el límite físico de la nueva referencia (no asumir ±15° si la fuente no lo especifica).
- [ ] Repetir verificaciones de §6 — no asumir que se cumplen igual con otra geometría.
- [ ] Actualizar `LAMBDA_ESCALA` y volver a evaluar contra el RNF-CAR-01 vigente en ese momento.
