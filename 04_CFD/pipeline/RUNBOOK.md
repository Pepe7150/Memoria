# Runbook: Pipeline CFD NACA0012 con flap (OpenFOAM + Gmsh)

Todos los comandos asumen que estás parado en la carpeta `pipeline/` (donde
viven todos los scripts) y corriendo dentro de WSL.

Archivos que deben estar en esta carpeta:
`naca0012_flap_geometry.py`, `naca_mesh_gmsh.py`, `compute_first_layer_height.py`,
`fix_patch_types.py`, `convert_mesh.sh`, `build_case.py`, `run_sweep.py`,
`verify_sweep.py`, `continue_nonconverged.py`, `case_template/` (con `0/`,
`constant/`, `system/`).

---

## 0. Preparar el entorno (una vez por sesión de terminal)

```bash
cd ruta/a/04_CFD/pipeline

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
> te tira un error de `libstdc++`/`GLIBCXX`, antepone `LD_LIBRARY_PATH=""`:
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

---

## 8. Resultado final

`resultados.csv` queda con las columnas:

```
delta_deg, mach, aoa_deg, Cl, Cd, CmPitch, ChHinge, HingeMoment_Nm
```

`HingeMoment_Nm` es el momento de bisagra real (en N·m), listo para el
dimensionamiento del actuador.