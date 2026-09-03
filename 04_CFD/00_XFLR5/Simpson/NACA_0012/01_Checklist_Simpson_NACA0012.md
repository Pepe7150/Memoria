# Caso Simpson (2016) — NACA 0012, estabilizador con flecha 45°, elevador 25%

**Este documento asume que ya leíste `03_Pipeline_General_XFLR5.md`.** Aquí solo se detalla lo específico de este caso — datos de geometría, valores exactos a ingresar, y las particularidades que solo aparecen con esta fuente. Para explicaciones generales (por qué usar `TE Flap` en vez de `isFin`, por qué el límite de 100 puntos, cómo consolidar resultados, etc.) ver el pipeline general.

**Tipo de superficie:** flap parcial de cuerda (elevador, 25% de la cuerda) — usa el mecanismo `TE Flap` + `HMom` del pipeline general (§2.2, caso B), **no** el mecanismo `isFin` que se usó para la aleta de Nalci & Kayran.

**Fuente:** Simpson, C. D. (2016). *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics.* Tesis de maestría, University of Alabama. Capítulo 4 (geometría en Tabla 4.1, Figuras 4.1–4.2). Basado a su vez en el ensayo experimental de Johnson & Thompson (1950), túnel de alta velocidad Langley 7×10 ft.

---

## 1. Geometría (Tabla 4.1 de la fuente — valores a ingresar tal cual)

| Cantidad                                       | Símbolo | Valor                        |
| ---------------------------------------------- | -------- | ---------------------------- |
| Cuerda de sección (normal al borde de ataque) | c        | 15 in =**381 mm**      |
| Semi-envergadura                               | b/2      | 31.53 in =**800.9 mm** |
| Flecha                                         | Λ       | **45°**               |
| Espesor relativo                               | t/c      | 0.12 (NACA 0012)             |
| Cuerda del elevador (% de c)                   | cf/c     | **25%**                |
| Eje de bisagra, coordenada x                   | xh/c     | **0.75**               |
| Eje de bisagra, coordenada z                   | zh/c     | **0.0**                |
| Reynolds                                       | Re       | **5.52×10⁶**         |
| Mach                                           | M        | **0.5**                |

**Nota sobre el modelo real:** Johnson & Thompson ensayaron un modelo de **semi-envergadura** (una sola mitad, contra la pared del túnel), no un estabilizador completo. Por eso el wing en XFLR5 se construye con `Symmetric` activado (ver §3) — XFLR5 completa la otra mitad automáticamente para el cálculo, y el resultado por lado es directamente comparable al ensayo original (ver verificación en §6).

**Deflexiones ensayadas por la fuente** (ensayar las 4, incluida δ=0° — ver por qué en §4): `δ ∈ {0°, -1.7°, -3.7°, -7.8°}`

**Ángulos de ataque ensayados:** `α ∈ {-8°, -6°, -4°, -2°, 0°, 2°, 4°, 6°, 8°}` (9 puntos, paso 2°)

---

## 2. Crear el perfil base y las 4 variantes deflectadas

1. `Direct Foil Design` → `Foil` → `NACA Foils` → ingresar `0012` → generar y guardar como `NACA 0012`.
2. Para cada una de las 3 deflexiones no nulas, usar la herramienta de **`TE Flap`** sobre el perfil base:
   - Seleccionar el perfil `NACA 0012`.
   - En la tabla de perfiles (`Foil direct design`), completar las columnas:

| Nombre a guardar  | TE Flap (°) | TE XHinge | TE YHinge |
| ----------------- | ------------ | --------- | --------- |
| `NACA 0012 1p7` | 1.70         | 75.00     | 0.00      |
| `NACA 0012 3p7` | 3.70         | 75.00     | 0.00      |
| `NACA 0012 7p8` | 7.80         | 75.00     | 0.00      |

- Este paso **hornea** la deflexión en la geometría (crea un perfil nuevo, permanentemente rotado desde el 75% de cuerda) y, crucialmente, **guarda el hinge como metadata del perfil** — es lo que permite que XFLR5 calcule `HMom` más adelante.

3. **No te saltes la deflexión δ=0°.** Aunque geométricamente sea idéntica al `NACA 0012` base, hay que crear igual una variante con `TE Flap=0.00`, `TE XHinge=75.00`, `TE YHinge=0.00`, y guardarla como `NACA 0012 0p0`. Sin este paso, el perfil base no tiene el hinge asociado y XFLR5 no podrá calcular `HMom` para ese caso — el resultado será un `Cm` de ala completa, inútil para lo que necesitas (ver explicación completa en el pipeline general, §2.2).

   **Por qué vale la pena igual (no es solo trámite):** incluso sin deflexión, el momento de bisagra no es cero para α≠0 — permite aislar `Ch_α` (sensibilidad a ángulo de ataque) de `Ch_δ` (sensibilidad a deflexión), ver verificación en §6.

**Convención de nombres:** usar exactamente el patrón `_delta_<signo><entero>p<decimal>` en el nombre del `Wing`/`Plane` que uses más adelante (ej. `Simpson_NACA0012_delta_-7p8`) — el script de consolidación (pipeline general, §7.2) lo parsea automáticamente con esa convención, incluyendo el caso `_delta_0p0`.

---

## 3. Polares 2D viscosas — Reynolds real, no un valor de prueba

Para **cada uno de los 4 perfiles** (`NACA 0012 0p0`, `1p7`, `3p7`, `7p8`):

1. `Direct Foil Design` → `Polars` → `Define an Analysis` → tipo viscoso (XFoil).
2. **Re = 5,520,000** (o el valor exacto que reporte el log de la corrida 3D si difiere ligeramente, ej. 5,517,204).
3. **Recomendación:** corre 2 polares que enmarquen ese Re (p. ej. 5,000,000 y 6,000,000) en vez de un único valor exacto — evita el error `Re is outside the flight envelope of polars` en el análisis 3D si el Reynolds local calculado no coincide dígito a dígito (ver pipeline general, §4).
4. **Mach = 0.5**, con corrección de compresibilidad activada.
5. Rango angular: -8° a 8°, refinando hasta que **converjan los 9 puntos** antes de pasar al wing 3D.

---

## 4. Construir el wing (uno por deflexión)

En `Wing and Plane Design`, crear **4 objetos `Wing`** (no `Plane`), uno por deflexión, cada uno con:

| Fila  | Y (mm) | Chord (mm) | Offset (mm)                         | Dihedral (°) | Foil                   |
| ----- | ------ | ---------- | ----------------------------------- | ------------- | ---------------------- |
| Raíz | 0      | 381        | 0                                   | 0             | `NACA 0012 <sufijo>` |
| Punta | 800.9  | 381        | 800.9 × tan(45°) =**800.9** | —            | `NACA 0012 <sufijo>` |

- **Symmetric:** activado, **Right Side** (ver nota de §1 — el modelo real es de semi-envergadura, XFLR5 completa la otra mitad automáticamente).
- **Twist:** 0° en ambas secciones.
- Nombrar el `Wing`: `Simpson_NACA0012_delta_<sufijo>` (ej. `Simpson_NACA0012_delta_-7p8`).
- Método de análisis: **VLM2** (necesario para la corrección viscosa vía polares 2D — el método de paneles 3D no la incorpora, ver pipeline general §1).

**Verificación rápida antes de correr:** el área de referencia que reporte XFLR5 debería ser `2 × 800.9mm × 381mm ≈ 0.6103 m²` (el ×2 es por la duplicación de `Symmetric`). Si no coincide, revisar la tabla de secciones antes de continuar.

---

## 5. Correr y exportar

1. Densidad y viscosidad cinemática consistentes con Re=5.52×10⁶ y M=0.5 a la condición atmosférica elegida (density=1.522 kg/m³ fue el valor usado en la corrida de referencia de este proyecto — no necesariamente el único válido, pero debe ser explícito y documentado).
2. Type 1 (fixed speed), α de -8° a 8° — cabe en un solo polar (9 puntos, muy por debajo del límite de 100).
3. **Exportar cada punto de operación (`OpPoint`) individualmente** — el export del polar completo no trae `HMom` (ver pipeline general, §5). Son 9 α × 4 δ = 36 archivos.
4. Opcional pero recomendado: exportar también el polar completo de cada δ (para la hoja de verificación cruzada de `Cm` del script de consolidación).

---

## 6. Consolidar y verificar

Usar el script de consolidación del pipeline general (§7.2) sobre la carpeta con los 36 `OpPoint` (+ 4 polares completos opcionales).

**Verificaciones específicas de este caso, además de las generales del pipeline (§6):**

- `Ch` en α=0°, δ=0° debería salir ≈0 (perfil simétrico, sin deflexión, sin ángulo → sin asimetría que produzca momento).
- La pendiente `Ch_α` (ajuste lineal de `Ch` vs. α, por cada δ) debería salir muy similar entre las 4 deflexiones — confirma el modelo lineal `Ch ≈ Ch_α·α + Ch_δ·δ` de la literatura de superficies de control.
- Los dos objetos de flap que reporta XFLR5 (uno por cada mitad simétrica del wing) deberían dar el mismo valor — es la firma esperada de un caso sin β ni deflexión diferencial, no un error.

---

## 7. Qué comparación es posible — y cuál no

**No existe una tabla numérica exacta en la fuente para este caso 3D.** El Capítulo 4 de Simpson presenta los resultados solo como gráfico (Figura 4.6: `Ch` vs. α, una curva por δ, comparando el experimento de Johnson & Thompson contra su propio Fun3D estacionario) — no hay tabla de la que extraer números para comparar dígito a dígito.

**Lo que sí se puede afirmar con el texto de la fuente:** el propio Fun3D de Simpson (RANS con modelo de turbulencia Spalart-Allmaras, más fidelidad que cualquier cosa que XFLR5 pueda dar) tiene errores de **~35% en δ=-7.8°** respecto al experimento, con buena concordancia en deflexiones pequeñas. Si tu resultado de XFLR5 se aleja bastante del orden de magnitud esperado en δ=-7.8°, no es necesariamente una falla de tu metodología — es la misma separación de flujo que ya le cuesta capturar a una CFD viscosa completa.

**Si se necesita una validación numérica exacta:** el caso 2D GA(W)-1 de la misma fuente (Capítulo 3, Tablas 3.7–3.12) sí tiene números exactos — incluyendo el propio XFOIL de Simpson, comparable directamente contra un XFLR5 propio del mismo perfil. Es un ejercicio separado, no descrito en este documento (geometría: cuerda 24in, flap 20%, hinge en 80% de cuerda, Re=2.2×10⁶, M=0.13).

---

### 7bis. Resultado obtenido y cierre del caso (actualizado tras comparación contra Fig. 4.6)

Al consolidar los 36 puntos (`OpPoint`, 4 deflexiones × 9 ángulos) y comparar contra la Fig. 4.6, se encontraron y corrigier<on dos problemas — ver el detalle completo en `04_Lecciones_Metodologicas_XFLR5.md`, Hallazgo 3 (§3bis):

1. El caso **δ=0°** había quedado con `delta=NaN` en la tabla consolidada, por un desajuste entre el nombre del `Wing`/`Plane` de ese caso y la convención de nombre `_delta_0p0` que espera `consolidar_oppoints_xflr5.py`. Corregido manualmente tras confirmar que los datos sí correspondían a δ=0° (`Ch(α=0)≈0`).
2. El término de respuesta a la deflexión (`Ch_δ`) salía con **signo invertido** respecto a la Fig. 4.6, mientras que el término de respuesta a α (`Ch_α`) ya era correcto desde el principio. Esto es consistente con que el `TE Flap` se haya ingresado en XFLR5 con signo contrario al documentado en §2 de este checklist (`TE Flap=+X` debería representar `δ=−X` de Simpson).

**Corrección aplicada:** para un perfil simétrico como el NACA 0012, invertir el signo de la deflexión equivale a reflejar verticalmente todo el problema, lo que se corrige con `Ch_corregido(α) = −Ch_original(−α)` a δ fijo (script: `corregir_signo_delta_naca0012.py`).

**Resultado tras la corrección:** el orden de las curvas y la tendencia coinciden con la Fig. 4.6 (δ=-7.8° arriba, δ=0° abajo, pendiente decreciente con α en las cuatro curvas). La diferencia absoluta remanente es del orden de **~0.01 en `Ch`**, comparando contra una lectura aproximada de la figura (no hay tabla numérica exacta disponible, a diferencia de GA(W)-1) — un margen razonable dado que la comparación es gráfica, no numérica.

**Caso NACA 0012: verificado y cerrado.** Pendiente no bloqueante: confirmar en el archivo `.xfl` original si el signo del `TE Flap` de las variantes deflectadas se ingresó al revés de lo documentado en §2, para corregir en el origen antes de reutilizar este procedimiento en una geometría nueva.

---

## 8. Referencias

- Simpson, C. D. (2016). *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics.* Tesis de maestría, University of Alabama.
- Johnson, J. L., & Thompson, F. L. (1950). Ensayo experimental citado como fuente primaria de la geometría y datos de referencia en el Capítulo 4 de Simpson (2016).
