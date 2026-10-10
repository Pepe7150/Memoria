# Runbook: Pipeline CFD NACA0012 con flap (OpenFOAM + Gmsh)

Todos los comandos asumen que estás parado en la carpeta `pipeline/` (donde
viven todos los scripts) y corriendo dentro de WSL.

Archivos que deben estar en esta carpeta:
`naca0012_flap_geometry.py`, `naca_mesh_gmsh.py`, `compute_first_layer_height.py`,
`fix_patch_types.py`, `convert_mesh.sh`, `build_case.py`, `run_sweep.py`,
`verify_sweep.py`, `continue_nonconverged.py`, `resync_results.py`,
`case_template/` (con `0/`, `constant/`, `system/`). Para la campaña
dinámica, además: `naca0012_flap_geometry_gapped.py`,
`naca_mesh_gmsh_dynamic.py`.

---

## 0. Preparar el entorno (una vez por sesión de terminal)

```bash
cd /mnt/c/Users/usuario_pc/Desktop/Memoria/04_CFD/pipeline

# entorno de OpenFOAM
source /opt/OpenFOAM/OpenFOAM-v2012/etc/bashrc

# venv de Python (numpy, matplotlib, gmsh)
source venv/bin/activate

# confirma que quedó el Python correcto activo
which python3   # debe apuntar a .../pipeline/venv/bin/python3
```

> Nota: los scripts de Python (numpy/gmsh) y los binarios de OpenFOAM
> requieren `LD_LIBRARY_PATH` distinto (chocan entre sí). Si corres algo de
> Python SUELTO (no a través de `run_sweep.py`, que ya maneja esto solo) y
> te tira un error de `libstdc++`/`GLIBCXX`/`CXXABI`, antepone
> `LD_LIBRARY_PATH=""`:
> ```bash
> LD_LIBRARY_PATH="" python3 naca0012_flap_geometry.py ...
> ```

---

## 1. Calcular la altura de primera celda (`y1`) para tu condición más exigente

```bash
python3 compute_first_layer_height.py --u 68.06 --c 0.2 --nu 1.5e-5 --yplus 1
```

Usa el valor de la línea `-> fracción de cuerda` (no el que está en metros)
como `y1` en tu `sweep_config.json`.

---

## 2. Probar UN caso suelto de punta a punta (antes de lanzar el barrido)

### 2.1 Geometría

```bash
LD_LIBRARY_PATH="" python3 naca0012_flap_geometry.py --delta 0 --hinge 0.7 --out test_d0.dat --plot
```

> Este comando y el siguiente (de malla) usan numpy/gmsh, que chocan con el
> `libstdc++` que trae cargado el entorno de OpenFOAM -- por eso el prefijo
> `LD_LIBRARY_PATH=""`.

### 2.2 Malla

```bash
LD_LIBRARY_PATH="" python3 naca_mesh_gmsh.py --dat test_d0.dat --out test_d0.msh \
    --farfield 15 --wake 20 --yplus-height 2.5513e-05 --layers 20 --growth 1.2 \
    --te-size 0.004 --le-size 0.004 --farfield-size 1.5
```

Confirma en la salida que aparecen los patches `mainfoil`, `flap`, `farfield`,
`outlet`, `front`, `back` sin errores de "Edge not recovered".

### 2.3 Convertir la malla a OpenFOAM y validarla

```bash
./convert_mesh.sh test_mesh_case_d0 test_d0.msh
```

Revisa que `checkMesh` termine sin fallar en lo esencial (aspect ratio alto es
normal por la capa límite; lo que importa es que no haya errores de
topología).

### 2.4 Armar el caso con una condición de vuelo

```bash
python3 build_case.py --mesh-case test_mesh_case_d0 \
    --mach 0.15 --aoa 6 --chord 1.0 --extrude-z 0.1 \
    --a 340.3 --nu 7.5e-5 --hinge 0.7 \
    --out test_case_d0
```

> `--nu` aquí es el nu "de malla" (`nu_real / chord_real`), no el nu real
> del aire. Ver sección 4 para la relación completa.

### 2.5 Correr el caso

```bash
simpleFoam -case test_case_d0 | tee test_case_d0/log.simpleFoam
```

### 2.6 Revisar resultados

```bash
tail -30 test_case_d0/log.simpleFoam
cat test_case_d0/postProcessing/forceCoeffs1/0/coefficient.dat
cat test_case_d0/postProcessing/hingeMoment1/0/coefficient.dat
```

### 2.7 Visualizar en ParaView (opcional pero recomendado)

```bash
touch test_case_d0/test_case_d0.foam
LD_LIBRARY_PATH="" paraFoam -case test_case_d0
```

> Mismo choque de `libstdc++` que con Python: el `paraview` instalado por
> `apt` es más nuevo que el que trae empaquetado OpenFOAM, así que si el
> entorno de OpenFOAM está cargado, `paraFoam` falla con errores de
> `GLIBCXX_*` a menos que antepongas `LD_LIBRARY_PATH=""`. Si aun así no
> abre ventana, prueba `LD_LIBRARY_PATH="" paraview` directo y abre el
> `.foam` manualmente desde `File > Open`.

Repite 2.1-2.7 con `--delta 10` (o el valor que quieras) para confirmar que
el flap deflectado también funciona antes de lanzar el barrido completo.

---

## 3. Configurar el barrido completo

```bash
python3 run_sweep.py --example-config
```

Esto crea `sweep_config.json`. Ajusta como mínimo:

- `deltas`, `machs`, `aoas`: tus rangos reales.
- `hinge`, `extrude_z`, `farfield`, `wake`, `farfield_size`, `te_size`,
  `le_size`, `layers`, `growth`: los parámetros de malla ya validados en el
  paso 2.
- `y1`: el valor calculado en el paso 1.
- `chord`: **siempre `1.0`** (unidad de la malla, no la cuerda real -- no lo
  cambies).
- `nu`: **`nu_real / chord_real`**, no el nu real del aire (ver sección 4).
- `speed_of_sound`: velocidad del sonido real (340.3 m/s a nivel del mar).
- `rho_real`, `chord_real`, `span_real`: cantidades físicas REALES de tu
  banco de ensayos, necesarias para reconstituir el momento de bisagra en
  N·m (`span_real` es un dato de diseño que tú defines).

---

## 4. Relación entre unidades de malla y unidades reales

La malla está en "unidades de cuerda" (cuerda = 1), pero representa una
cuerda real de `chord_real` metros. Para que el Reynolds resuelto sea el
real, usando la velocidad real:

```
nu_malla = nu_real_aire / chord_real
```

Ejemplo con `chord_real = 0.2` m y `nu_real_aire = 1.5e-5` m²/s:

```bash
python3 -c "print(1.5e-5 / 0.2)"   # -> 7.5e-05
```

Ese `7.5e-05` es el `nu` que va en `sweep_config.json` y en las llamadas a
`build_case.py`.

---

## 5. Lanzar el barrido completo (dentro de tmux)

```bash
tmux new -s barrido
```

Dentro de la sesión tmux (repite el paso 0 de activar entornos si es una
sesión nueva):

```bash
source /opt/OpenFOAM/OpenFOAM-v2012/etc/bashrc
source venv/bin/activate

python3 run_sweep.py --config sweep_config.json 2>&1 | tee sweep_log.txt
```

Para salir sin cortar el proceso: `Ctrl+B`, soltar, luego `D`.

Para reconectarte más tarde:

```bash
tmux attach -t barrido
```

Para ver el progreso sin entrar del todo:

```bash
tail -f sweep_log.txt
```

---

## 6. Verificar que el barrido esté completo

```bash
python3 verify_sweep.py --config sweep_config.json --summary resultados.csv --workdir sweep_run
```

Revisa las secciones de salida: combinaciones faltantes, carpetas faltantes,
casos que posiblemente no convergieron, valores sospechosos.

---

## 7. Continuar los casos que no convergieron

```bash
python3 continue_nonconverged.py --config sweep_config.json \
    --summary resultados.csv --workdir sweep_run --extra-iters 3000
```

Esto retoma esos casos puntuales desde donde quedaron (no desde cero) y
actualiza `resultados.csv`. Vuelve a correr el paso 6 para confirmar.

Si algún caso sigue sin converger después de esto, probablemente es flujo
genuinamente separado/inestable (cerca de pérdida) -- ahí conviene mirarlo
en ParaView en vez de seguir dándole más iteraciones a ciegas.

Si en algún momento `resultados.csv` queda con columnas `ChHinge`/
`HingeMoment_Nm` desactualizadas (por ejemplo, de una corrida vieja de
`continue_nonconverged.py` previa al fix de ese bug), reconstrúyelo sin
relanzar nada:

```bash
python3 resync_results.py --config sweep_config.json --summary resultados.csv --workdir sweep_run
```

---

## 8. Resultado final (campaña estática)

`resultados.csv` queda con las columnas:

```
delta_deg, mach, aoa_deg, Cl, Cd, CmPitch, ChHinge, HingeMoment_Nm
```

`HingeMoment_Nm` es el momento de bisagra real (en N·m), listo para el
dimensionamiento del actuador.

## 9. Visualizar un caso específico del barrido en ParaView

Para visualizar los resultados de un caso particular que ya fue corrido dentro del barrido (por ejemplo, `d+10p0_M0p200_aoa+12p0`), sigue estos pasos:

1. **Crear el archivo `.foam`:** Genera un archivo vacío dentro de la carpeta del caso específico.
   ```bash
   touch sweep_run/cases/d+10p0_M0p200_aoa+12p0/caso.foam
   ```
2. Abrir con paraFoam: Ejecuta el comando limpiando la variable de entorno para evitar choques de librerías con el entorno de OpenFOAM.
   ```bash
   LD_LIBRARY_PATH="" paraFoam -case sweep_run/cases/d+10p0_M0p200_aoa+12p0
   ```

---

## 10. Campaña dinámica -- paso 1: geometría y malla con gap de bisagra

Ver `DOCUMENTACION_CFD_DINAMICA.md` para la teoría y el porqué de este gap.

### 10.1 Geometría con gap

```bash
LD_LIBRARY_PATH="" python3 naca0012_flap_geometry_gapped.py --delta 0 --hinge 0.7 --gap 0.01 --out naca_gap.dat --plot
```

Revisa `naca_gap.png`: debe verse `mainfoil` y `flap` como dos polígonos
separados por un hueco visible en la bisagra, sin traslape.

### 10.2 Malla con mainfoil y flap como agujeros independientes

```bash
LD_LIBRARY_PATH="" python3 naca_mesh_gmsh_dynamic.py --dat naca_gap.dat --out naca_gap.msh \
    --farfield 15 --wake 20 --yplus-height 2.5513e-05 --layers 20 --growth 1.2 \
    --te-size 0.004 --le-size 0.004 --farfield-size 1.5
```

Confirma que salen los 7 grupos físicos (`mainfoil`, `flap`, `farfield`,
`outlet`, `front`, `back`, `internal`) sin warnings ni errores de Gmsh.

### 10.3 Convertir y revisar en ParaView

Igual que en la campaña estática (pasos 2.3 y 2.7), usando `naca_gap.msh`.
Presta especial atención a la calidad de malla cerca del gap -- es la zona
más delicada de toda la malla.

Repite con `--delta 10`, `--delta -10` (u otros valores) para confirmar que
el gap se mantiene sin traslape también con el flap deflectado, antes de
pasar al paso 2 del roadmap dinámico (`moveDynamicMesh`).

---

## 11. Campaña dinámica -- paso 2: validar SOLO el movimiento de malla

No se resuelve flujo todavía: se mueve la malla con el flap rotando y se
revisa que no se degrade. Ver `DOCUMENTACION_CFD_DINAMICA.md` (Secciones
4.3, 5.1 y 5.2) para el porqué de cada decisión.

### 11.1 Convertir la malla con gap a OpenFOAM

`convert_mesh.sh` sirve tal cual (los patches se llaman igual: `mainfoil`,
`flap`, `farfield`, `outlet`, `front`, `back`):

```bash
./convert_mesh.sh mesh_case_gap naca_gap.msh
```

Revisa que `checkMesh` no falle en topología (el aspect ratio alto es
normal por la capa límite).

### 11.2 Armar el caso de movimiento de malla

Los tiempos se dan en segundos REALES; el script los convierte a tiempo de
OpenFOAM (`t_OF = t_real / chord_real`):

```bash
python3 build_dynamic_move_case.py --mesh-case mesh_case_gap \
    --delta-target 10 --t-actuation-real 0.05 --t-hold-real 0.05 \
    --chord-real 0.2 --hinge 0.7 --gap 0.01 --out move_test_d10
```

Lee el resumen que imprime: tiempo total, tiempos de escritura, y sobre
todo la **holgura de esquina** (si baja del 30% del gap original, avisa).

### 11.3 Mover la malla y revisar su calidad

```bash
cd move_test_d10
moveDynamicMesh | tee log.moveDynamicMesh
checkMesh -allTime -allGeometry -allTopology | tee log.checkMesh_allTime
```

Busca en `log.checkMesh_allTime`, para cada tiempo: `Mesh OK` (o fallas
solo en cosas esperables), volumen mínimo POSITIVO, `Max skewness`,
`Mesh non-orthogonality Max`. Lo más probable es que lo peor ocurra al
final de la rampa (máxima deflexión).

### 11.4 Verificar numéricamente rotación, signo y unidades

```bash
python3 ../check_flap_motion.py --case . --time 0.25 --hinge 0.7
```

(`--time` es una de las carpetas de tiempo escritas; usa una durante la
rampa, por ejemplo 0.125 -> se esperan -5°, y una al final, 0.25 -> -10°.)
Debe terminar en `RESULTADO: OK`. Si dice FALLA, el mensaje indica si es
signo, unidades (radianes vs grados) o si el flap no se movió.

Este script solo usa numpy: si el entorno de OpenFOAM está cargado y falla
por `libstdc++`, antepón `LD_LIBRARY_PATH=""`.

### 11.5 Mirar la malla en movimiento (opcional)

```bash
touch caso.foam
LD_LIBRARY_PATH="" paraFoam -case .
```

En ParaView avanza por los tiempos y haz zoom en la bisagra: la zona del
gap es la más delicada. Si las celdas del lado comprimido se aplastan o
se cruzan, ver la alternativa de nariz redondeada concéntrica en la
Sección 4.3 de la documentación dinámica.

### 11.6 Probar otros casos

Repite 11.2-11.4 con `--delta-target -10`, con `--quadratic` (malla más
rígida cerca del flap) y con otros `--gap` (hay que regenerar la malla con
ese gap, pasos 10.1-10.2, y reconvertirla) para ver qué combinación aguanta
mejor el rango de deflexión que necesitas.
