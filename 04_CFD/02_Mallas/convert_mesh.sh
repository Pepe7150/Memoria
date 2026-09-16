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
# El <caso> debe ser una carpeta de caso de OpenFOAM que ya tenga system/
# (con controlDict, fvSchemes, fvSolution y createPatchDict).

set -e  # aborta si cualquier comando falla

CASE_DIR="$1"
MSH_FILE="$2"

if [ -z "$CASE_DIR" ] || [ -z "$MSH_FILE" ]; then
    echo "Uso: $0 <carpeta_del_caso> <archivo.msh>"
    exit 1
fi

if [ ! -f "$MSH_FILE" ]; then
    echo "ERROR: no se encuentra el archivo de malla: $MSH_FILE"
    exit 1
fi

if [ ! -d "$CASE_DIR/system" ]; then
    echo "ERROR: $CASE_DIR no parece un caso de OpenFOAM (falta system/)"
    exit 1
fi

if [ ! -f "$CASE_DIR/system/createPatchDict" ]; then
    echo "ERROR: falta $CASE_DIR/system/createPatchDict"
    echo "       Copia el createPatchDict a la carpeta system/ del caso."
    exit 1
fi

# Verifica que el entorno de OpenFOAM esté cargado
if ! command -v gmshToFoam &> /dev/null; then
    echo "ERROR: no se encuentra gmshToFoam."
    echo "       ¿Cargaste el entorno de OpenFOAM? Prueba:"
    echo "       source /opt/openfoam*/etc/bashrc"
    exit 1
fi

echo "=== 1. Convirtiendo malla de Gmsh a OpenFOAM ==="
gmshToFoam "$MSH_FILE" -case "$CASE_DIR" 2>&1 | tail -20

echo ""
echo "=== 2. Corrigiendo tipos de patch (empty para front/back, wall para airfoil) ==="
createPatch -overwrite -case "$CASE_DIR" 2>&1 | tail -20

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
