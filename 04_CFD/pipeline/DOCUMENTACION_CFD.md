# Documentación técnica: campaña CFD — NACA0012 con flap (OpenFOAM + Gmsh)

> Documento vivo. Cubre la campaña **estática** (barrido δ × Mach × AoA) de
> punta a punta: metodología, decisiones de diseño, bugs encontrados y sus
> soluciones, y resultados. La continuación dinámica (picos transitorios de
> momento de bisagra) se documenta aparte en
> `DOCUMENTACION_CFD_DINAMICA.md`.

---

## 1. Objetivo de la campaña

Generar las curvas aerodinámicas (Cl, Cd, CmPitch) y, sobre todo, el
**momento de bisagra** del flap de un NACA0012 en función de:

- **δ**: ángulo de deflexión de la superficie de control.
- **Mach**: condición de vuelo (vía velocidad, régimen subsónico bajo).
- **AoA**: ángulo de ataque.

El momento de bisagra es el insumo directo para dimensionar el actuador del
banco de ensayos (Memoria de Título) — ver `/areas/memoria-de-titulo.md`.

---

## 2. Geometría (`naca0012_flap_geometry.py`)

- Perfil NACA 00xx generado analíticamente (fórmula de espesor estándar),
  con espaciado coseno a lo largo de la cuerda.
- El flap se modela como una **rotación rígida** de todos los puntos con
  $x \geq x_{hinge}$ (en la geometría sin deflectar) alrededor de la
  bisagra $(x_{hinge}, 0)$ — el perfil es simétrico (NACA00xx, sin cámber),
  así que la línea de cuerda coincide con $y=0$ y la bisagra cae
  exactamente ahí.
- Salida en formato Selig (TE→extradós→LE→intradós→TE), el que esperan la
  mayoría de los malladores.
- Cada punto lleva una **tercera columna `is_flap`** (0/1) calculada
  *antes* de rotar — necesaria para que el mallador pueda separar
  `mainfoil` y `flap` en patches distintos aunque el flap esté deflectado
  (las coordenadas finales ya no permiten inferir la pertenencia con un
  simple `x >= x_hinge`).

---

## 3. Malla (`naca_mesh_gmsh.py`, vía API de Python de Gmsh)

### 3.1 Topología

Dominio tipo **C**: semicírculo aguas arriba del borde de ataque + rectángulo
aguas abajo hasta el plano de salida. Extruido una celda de espesor en z
(caso pseudo-2D para OpenFOAM, con `front`/`back` tipo `empty`).

### 3.2 Capa límite

Campo `BoundaryLayer` de Gmsh sobre la superficie del perfil, con altura de
primera celda (`y1`) calculada para un y+ objetivo (`compute_first_layer_height.py`,
correlación de placa plana turbulenta) usando la condición de **mayor
Reynolds** del barrido para ese δ — un solo y1 conservador sirve para todo
el rango de Mach/AoA de esa malla (se reutiliza la misma malla, solo cambia
la dirección/magnitud de la corriente libre).

### 3.3 Patches generados

`mainfoil`, `flap`, `farfield` (arco + costados sup/inf), `outlet` (plano
de salida), `front`/`back` (caras del espesor de extrusión), y el volumen
`internal`. La separación `mainfoil`/`flap` usa la columna `is_flap` del
`.dat` para partir las splines del extradós/intradós en el punto de
bisagra.

### 3.4 Clasificación robusta de patches

Los patches se identifican por **qué curva de base generó cada superficie
lateral del extrude** (no por el orden que devuelve `extrude()`, que no es
confiable entre versiones). La tapa "front" se identifica como la única
superficie cuyo contorno no toca ninguna curva del dominio 2D original.

---

## 4. Conversión a OpenFOAM (`convert_mesh.sh`, `fix_patch_types.py`)

1. `gmshToFoam` convierte el `.msh` a `constant/polyMesh`.
2. Los tipos de patch (`empty` para front/back, `wall` para mainfoil/flap)
   se corrigen con **edición de texto directa** sobre
   `constant/polyMesh/boundary` (`fix_patch_types.py`), no con `createPatch`
   ni `foamDictionary` — ver Sección 7 (bugs) para el porqué.
3. `checkMesh` valida la malla (aspect ratio alto es normal por la capa
   límite; lo que importa es ausencia de errores de topología).

---

## 5. Caso OpenFOAM (`build_case.py`, `case_template/`)

### 5.1 Solver y turbulencia

`simpleFoam` (RANS estacionario incompresible) + Spalart-Allmaras — elegido
por ser el estándar de validación para perfiles NACA (usado también por el
NASA Turbulence Modeling Resource) y barato de correr para un barrido
amplio.

### 5.2 Cómo se impone el AoA

El AoA **no** rota la malla — rota la dirección de la corriente libre
(`U = (U·cos(AoA), U·sin(AoA), 0)`). Consecuencia importante: `liftDir` y
`dragDir` del `forceCoeffs` también deben rotar con el AoA (no quedarse
fijos en los ejes de la malla), porque lift/drag se definen relativos al
viento, no al perfil.

### 5.3 Condiciones de borde

- `farfield` y `outlet`: tipo `freestream` (maneja entrada y salida en la
  misma cara según el signo local del flujo — natural para el borde curvo
  del dominio C).
- `mainfoil`/`flap`: `noSlip` (U), `nutLowReWallFunction` (se adapta solo si
  el y+ real difiere del objetivo).

### 5.4 Unidades: malla vs. realidad

La malla está en **unidades de cuerda** (cuerda = 1), pero representa una
cuerda real (`chord_real`, en metros). Para que el Reynolds resuelto sea el
real usando la velocidad real:

$$
\nu_{malla} = \frac{\nu_{real,aire}}{c_{real}}
$$

`chord` en `build_case.py`/`sweep_config.json` se queda **siempre en 1.0**
(no se cambia) — es `nu` el que se escala. (Este fue el origen del primer
barrido fallido completo: un `nu` mal escalado en `sweep_config.json`.)

### 5.5 Coeficientes de fuerza y momento

Dos `forceCoeffs` por caso:

- **`forceCoeffs1`**: patches `(mainfoil flap)` juntos, `CofR` en el cuarto
  de cuerda — Cl, Cd, CmPitch "normales" del perfil completo.
- **`hingeMoment1`**: patch `(flap)` solo, `CofR` en la bisagra — el
  coeficiente de momento de bisagra (`ChHinge`).

### 5.6 Reconstitución del momento de bisagra real (N·m)

`ChHinge` es adimensional (calculado con `rhoInf=1` y unidades de malla).
Se reconstituye a dimensional real con las cantidades físicas reales —
misma lógica de "teoría de franjas" (2D → 3D) que para cualquier
coeficiente aerodinámico:

$$
M_{bisagra} = Ch_{hinge} \times 0.5 \times \rho_{real} \times U_{real}^2 \times c_{real}^2 \times b_{real}
$$

donde $b_{real}$ (envergadura real de la superficie de control) es un dato
de diseño que se define aparte — no sale de la malla, que es pseudo-2D.

---

## 6. Automatización del barrido (`run_sweep.py` y utilidades)

| Script                       | Qué hace                                                                                                                                                                                                                                                               |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `run_sweep.py`             | Recorre δ (genera geometría+malla+conversión **una vez** por δ) × Mach × AoA (reutilizando la malla, solo cambia `build_case.py` + `simpleFoam`). Junta Cl/Cd/CmPitch/ChHinge/HingeMoment_Nm en `resultados.csv`.                                    |
| `verify_sweep.py`          | Cruza`sweep_config.json` contra `resultados.csv` y las carpetas reales: combinaciones faltantes, carpetas faltantes, casos que probablemente no convergieron (truco: última carpeta de tiempo == `endTime` del `controlDict`), valores fuera de rango físico. |
| `continue_nonconverged.py` | Retoma (NO desde cero --`startFrom latestTime`) los casos no convergidos, les da más iteraciones, y actualiza las 5 columnas de `resultados.csv`.                                                                                                                  |
| `resync_results.py`        | Reconstruye`resultados.csv` desde cero releyendo directo `postProcessing/` de cada caso ya corrido (sin relanzar nada) -- útil para corregir columnas desactualizadas sin gastar cómputo de nuevo.                                                                |

Manejo de entornos: `run_sweep.py` limpia `LD_LIBRARY_PATH` automáticamente
solo para los subprocesos de Python que usan numpy/gmsh (chocan con el
`libstdc++` que trae OpenFOAM), dejando el entorno normal para los binarios
de OpenFOAM.

---

## 7. Bugs encontrados y resueltos (bitácora)

Vale la pena mantener esta lista — varios son comportamientos no intuitivos
de OpenFOAM/Gmsh que pueden reaparecer en trabajo futuro.

1. **Arco de semicírculo del far-field tomaba el lado equivocado**:
   `addCircleArc` de 3 puntos no garantiza la vuelta larga; con puntos casi
   opuestos puede tomar el arco corto por el lado contrario. Fix: partir el
   semicírculo en dos arcos de 90° inequívocos.
2. **Spline cerrada a través del borde de fuga romo se auto-intersectaba**:
   una sola spline por todo el contorno genera *overshoot* numérico en el
   kink del TE. Fix: separar en spline de extradós + spline de intradós +
   línea recta de TE.
3. **Detección de la tapa "front" del extrude fallaba por tolerancia de
   punto flotante**: comparar `z` contra `extrude_z` con tolerancia
   `1e-9` era demasiado estricto por el ruido numérico del extrude. Fix:
   identificar la tapa por no compartir ninguna curva con el dominio 2D
   original, en vez de comparar bounding box.
4. **`createPatch` no cambia el tipo de un patch que ya existe**: solo
   reordena sus caras e ignora `patchInfo` si el nombre ya existía (y
   `gmshToFoam` ya crea los patches con los nombres exactos de los grupos
   físicos de Gmsh). Fix: `fix_patch_types.py`, edición de texto directa
   sobre `constant/polyMesh/boundary`.
5. **`foamDictionary` no puede navegar `constant/polyMesh/boundary` por
   nombre de patch**: ese archivo es una lista anónima (`entry0`) para
   `foamDictionary`, no un diccionario. Mismo fix que el punto anterior.
6. **`set -e` no detecta fallas dentro de un pipe** (`cmd | tail -20`):
   bash solo mira el código de salida del último comando del pipe. Fix:
   `set -o pipefail` en `convert_mesh.sh`.
7. **`gmshToFoam`/`checkMesh` requieren `system/controlDict` (y
   `fvSchemes`) aunque no resuelvan nada**: es un requisito de construcción
   del objeto `Time` de OpenFOAM. Fix: `convert_mesh.sh` se genera sus
   propios diccionarios mínimos (sin bloque de `forceCoeffs`, que depende
   de un AoA que en esta etapa todavía no existe).
8. **Choque de `libstdc++` entre el entorno de OpenFOAM y Python/ParaView
   del sistema**: el `LD_LIBRARY_PATH` que carga OpenFOAM apunta a su
   propio `libstdc++` (más viejo), que rompe numpy/matplotlib/gmsh y el
   `paraview` instalado por `apt` (más nuevo). Fix: `LD_LIBRARY_PATH=""`
   como prefijo para esos comandos puntuales.
9. **`continue_nonconverged.py` no actualizaba `ChHinge`/`HingeMoment_Nm`**:
   solo refrescaba Cl/Cd/CmPitch al continuar un caso, dejando esas dos
   columnas con el valor de antes de converger -- justo en los casos de
   AoA alto, los más relevantes para el peor caso de momento de bisagra.
   Fix: el script ahora actualiza las 5 columnas; `resync_results.py` sirve
   para corregir un CSV ya afectado sin volver a correr nada.
10. **`nu` mal escalado en `sweep_config.json`** hizo fallar el barrido
    completo la primera vez (ver Sección 5.4 para la relación correcta).

---

## 8. Resultados del barrido estático (45/45 casos, validado)

- **Rango cubierto**: δ ∈ {−10°, 0°, 10°}, Mach ∈ {0.1, 0.15, 0.2},
  AoA ∈ {−4°, 0°, 4°, 8°, 12°}.
- **Chequeos de sanidad, todos superados**:
  - Simetría perfecta Cl(δ=+10°, AoA) ≈ −Cl(δ=−10°, −AoA) en todo el
    barrido.
  - Cl≈0 y CmPitch≈0 en δ=0°/AoA=0° (correcto para NACA0012 sin
    deflexión).
  - Pendiente de sustentación cercana a $2\pi$ en el rango lineal,
    consistente con teoría de perfil delgado (también verificado contra
    teoría de perfil delgado + flap con el factor de efectividad τ de
    Glauert, en el caso puntual Mach=0.15/AoA=6°/δ=10° durante el
    desarrollo).
- **Peor caso para dimensionamiento del actuador**:
  δ=+10°, Mach=0.2, AoA=+12° → **HingeMoment ≈ −0.247 N·m** (usando
  `chord_real=0.2` m, `span_real=0.15` m, `rho_real=1.225` kg/m³ -- ajustar
  si estos valores de diseño cambian).
- Nota: AoA=12° ya muestra señales de acercarse a pérdida (caída de
  pendiente de Cl, salto de Cd) -- vale la pena confirmar si la envolvente
  de vuelo real del banco de ensayos llega hasta ese AoA o si el punto de
  diseño debería tomarse más adentro del rango lineal (ej. AoA=8°,
  −0.195 N·m).

---

## 9. Inventario de archivos del pipeline

| Archivo                           | Rol                                                                                                      |
| --------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `naca0012_flap_geometry.py`     | Geometría del perfil + flap deflectado, con columna`is_flap`.                                         |
| `compute_first_layer_height.py` | Calcula`y1` (altura de primera celda) para un y+ objetivo.                                             |
| `naca_mesh_gmsh.py`             | Malla tipo C con capa límite y patches`mainfoil`/`flap`/`farfield`/`outlet`/`front`/`back`. |
| `fix_patch_types.py`            | Corrige tipos de patch en`constant/polyMesh/boundary` por edición de texto.                           |
| `convert_mesh.sh`               | `gmshToFoam` + corrección de patches + `checkMesh`, con sus propios diccionarios mínimos.          |
| `case_template/`                | Plantilla de caso OpenFOAM (`0/`, `constant/`, `system/`) con tokens a sustituir.                  |
| `build_case.py`                 | Instancia`case_template/` para una condición Mach/AoA concreta.                                       |
| `run_sweep.py`                  | Orquesta el barrido completo δ × Mach × AoA.                                                          |
| `verify_sweep.py`               | Audita completitud/convergencia/sanidad de un barrido ya corrido.                                        |
| `continue_nonconverged.py`      | Retoma casos no convergidos sin reiniciar desde cero.                                                    |
| `resync_results.py`             | Reconstruye`resultados.csv` desde `postProcessing/` sin relanzar nada.                               |
| `RUNBOOK.md`                    | Comandos en orden, paso a paso, para correr todo el pipeline.                                            |
| `DOCUMENTACION_CFD_DINAMICA.md` | Teoría y plan para la campaña dinámica (picos transitorios).                                          |

---

## 10. Próximos pasos

Ver `DOCUMENTACION_CFD_DINAMICA.md` para el plan de la campaña dinámica
(momento de bisagra transitorio durante el movimiento del actuador), que
es la continuación directa de este trabajo.
