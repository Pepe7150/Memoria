#!/bin/bash
#
# convert_mesh.sh
#
# Convierte una malla .msh de Gmsh al formato de OpenFOAM, corrige los tipos
# de patch y valida la calidad de la malla.
#
# Debe correrse DENTRO de WSL, con el entorno de OpenFOAM ya cargado
# (source /opt/openfoam*/etc/bashrc o el equivalente de tu instalación).
#
# Uso:
#   ./convert_mesh.sh <caso> <archivo.msh>
#
# Ejemplo:
#   ./convert_mesh.sh casos/naca0012_d10 mallas/naca0012_d10.msh
#
# El <caso> es solo la carpeta donde va a vivir constant/polyMesh -- este
# script se genera sus propios system/controlDict, fvSchemes y fvSolution
# mínimos ahí mismo (necesarios porque gmshToFoam/checkMesh, aunque no
# resuelven nada, igual construyen el objeto Time de OpenFOAM, que exige que
# existan esos archivos). No necesitas crearlos tú antes de llamar al script.

set -e  # aborta si cualquier comando falla
set -o pipefail  # ...incluyendo comandos dentro de un pipe (ej. "gmshToFoam ... | tail -20")
# Sin esto, "cmd_que_falla | tail -20" reporta el código de salida de tail
# (siempre 0), no el de cmd_que_falla -- set -e nunca se entera de que algo
# se cayó, y el script sigue adelante con pasos posteriores sobre una malla
# que en realidad no se generó.

CASE_DIR="$1"
MSH_FILE="$2"
HERE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$CASE_DIR" ] || [ -z "$MSH_FILE" ]; then
    echo "Uso: $0 <carpeta_del_caso> <archivo.msh>"
    exit 1
fi

if [ ! -f "$MSH_FILE" ]; then
    echo "ERROR: no se encuentra el archivo de malla: $MSH_FILE"
    exit 1
fi

# Verifica que el entorno de OpenFOAM esté cargado
if ! command -v gmshToFoam &> /dev/null; then
    echo "ERROR: no se encuentra gmshToFoam."
    echo "       ¿Cargaste el entorno de OpenFOAM? Prueba:"
    echo "       source /opt/openfoam*/etc/bashrc"
    exit 1
fi

echo "=== 0. Preparando system/ mínimo para conversión/validación de malla ==="
mkdir -p "$CASE_DIR/system"

# controlDict mínimo, SIN el bloque de forceCoeffs: en esta etapa la malla
# todavía no está asociada a ningún Mach/AoA (se comparte entre todas las
# combinaciones de un mismo delta), así que las direcciones de lift/drag
# (que dependen del AoA) todavía no existen. Ese controlDict completo lo
# arma build_case.py más adelante, por cada condición de vuelo.
cat > "$CASE_DIR/system/controlDict" <<'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    object      controlDict;
}
application     simpleFoam;
startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         1;
deltaT          1;
writeControl    timeStep;
writeInterval   1;
EOF

cp "$HERE_DIR/case_template/system/fvSchemes" "$CASE_DIR/system/fvSchemes"
cp "$HERE_DIR/case_template/system/fvSolution" "$CASE_DIR/system/fvSolution"

echo "=== 1. Convirtiendo malla de Gmsh a OpenFOAM ==="
gmshToFoam "$MSH_FILE" -case "$CASE_DIR" 2>&1 | tail -20

echo ""
echo "=== 2. Corrigiendo tipos de patch en constant/polyMesh/boundary ==="
# OJO: NO usamos createPatch aquí. gmshToFoam ya crea los patches con los
# nombres exactos de los grupos físicos (front, back, airfoil, farfield,
# outlet), así que para createPatch esos patches "ya existen" -- y cuando un
# patch ya existe, createPatch únicamente reordena sus caras e IGNORA el tipo
# que le pidas en patchInfo (queda como "patch" genérico, no "empty"/"wall").
# Tampoco usamos foamDictionary: el archivo boundary es una lista anónima
# ("entry0") para foamDictionary, no un diccionario navegable por nombre de
# patch, así que "-entry front.type" falla con "not found in dictionary".
# La forma robusta es editar el texto del archivo directamente:
python3 "$(dirname "$0")/fix_patch_types.py" "$CASE_DIR/constant/polyMesh/boundary" \
    front:empty back:empty airfoil:wall

echo ""
echo "=== 3. Validando calidad de malla ==="
checkMesh -case "$CASE_DIR" 2>&1 | tail -40

echo ""
echo "=== Listo ==="
echo "Revisa arriba la salida de checkMesh. Cosas a mirar:"
echo "  - 'Mesh OK' al final -> la malla es utilizable"
echo "  - max aspect ratio    -> valores muy altos (>1000) pueden dar problemas"
echo "  - max skewness        -> idealmente < 4"
echo "  - non-orthogonality   -> max idealmente < 70; si es mayor, sube"
echo "    nNonOrthogonalCorrectors en fvSolution"