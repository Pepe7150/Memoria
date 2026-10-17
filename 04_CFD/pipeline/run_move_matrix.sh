#!/bin/bash
#
# run_move_matrix.sh
#
# Corre una matriz de experimentos de MOVIMIENTO DE MALLA (sin flujo) para
# averiguar que combinacion de difusividad / refinamiento / deflexion aguanta,
# y imprime un resumen: en que tiempo aparece el primer problema de cada una.
#
# Uso (carpeta pipeline/, entorno de OpenFOAM cargado y venv activo):
#     ./run_move_matrix.sh <mesh_case_base> [mesh_case_refinada]
#
#   mesh_case_base      : malla con gap ya convertida (convert_mesh.sh)
#   mesh_case_refinada  : (opcional) misma geometria mallada con
#                         --gap-refine-size 0.001, ya convertida
#
# Los scripts de Python (numpy) se llaman con LD_LIBRARY_PATH="" para evitar
# el choque de libstdc++ con el entorno de OpenFOAM.

set -u
BASE="${1:?Falta <mesh_case_base>}"
REF="${2:-}"
DELTA="${DELTA:-10}"          # deflexion objetivo (env var, default 10)
TACT="${TACT:-0.05}"          # tiempo de actuacion real [s]
THOLD="${THOLD:-0.05}"        # tiempo de mantencion real [s]
CHORD="${CHORD:-0.2}"
HINGE="${HINGE:-0.7}"
GAP="${GAP:-0.01}"

PY() { LD_LIBRARY_PATH="" python3 "$@"; }

SUMMARY=""
run_variant () {
    local name="$1" mesh="$2" delta="$3"; shift 3
    local dir="move_${name}"
    rm -rf "$dir"
    echo "=== [$name] mesh=$mesh delta=$delta extra='$*' ==="
    PY build_dynamic_move_case.py --mesh-case "$mesh" --out "$dir" \
        --delta-target "$delta" --t-actuation-real "$TACT" --t-hold-real "$THOLD" \
        --chord-real "$CHORD" --hinge "$HINGE" --gap "$GAP" "$@" > "$dir.build.log" 2>&1 \
        || { echo "  build fallo, ver $dir.build.log"; SUMMARY="${SUMMARY}$(printf '%-22s %s\n' "$name" 'BUILD FALLO')\n"; return; }

    ( cd "$dir" && moveDynamicMesh > log.moveDynamicMesh 2>&1 )
    local series; series=$(./checkmesh_series.sh "$dir" 2>&1)
    echo "$series" > "$dir/series.txt"

    # primer tiempo con avisos (la columna 6 en adelante no vacia)
    local first_bad; first_bad=$(echo "$series" | awk 'NR>1 && NF>=6 && $1+0>0 {print $1; exit}')
    local last_t; last_t=$(ls -d "$dir"/[0-9]* 2>/dev/null | xargs -n1 basename | grep -v '^0$' | sort -g | tail -1)
    local verdict
    if [ -z "$last_t" ]; then
        verdict="moveDynamicMesh no escribio tiempos (ver $dir/log.moveDynamicMesh)"
    else
        local chk; chk=$(PY check_flap_motion.py --case "$dir" --time "$last_t" --hinge "$HINGE" 2>&1 | grep -E "RESULTADO|FALLA" | head -2 | tr '\n' ' ')
        verdict="ultimo t=$last_t: $chk"
    fi
    if [ -z "$first_bad" ]; then
        SUMMARY="${SUMMARY}$(printf '%-22s %-28s %s\n' "$name" "SIN problemas graves" "$verdict")\n"
    else
        SUMMARY="${SUMMARY}$(printf '%-22s %-28s %s\n' "$name" "primer problema en t=$first_bad" "$verdict")\n"
    fi
}

# --- malla base
run_variant A_base_flap          "$BASE" "$DELTA"
run_variant B_base_flap+main     "$BASE" "$DELTA" --diff-patches flap mainfoil
run_variant C_base_flap+main_quad "$BASE" "$DELTA" --diff-patches flap mainfoil --quadratic
run_variant F_base_flap_d4       "$BASE" 4
run_variant G_base_flap+main_d4  "$BASE" 4 --diff-patches flap mainfoil

# --- malla refinada (si se entrego)
if [ -n "$REF" ]; then
    run_variant D_ref_flap+main      "$REF" "$DELTA" --diff-patches flap mainfoil
    run_variant E_ref_flap+main_quad "$REF" "$DELTA" --diff-patches flap mainfoil --quadratic
fi

echo
echo "=================== RESUMEN (delta=$DELTA, T_act=$TACT s reales) ==================="
printf '%-22s %-28s %s\n' "variante" "calidad de malla" "verificador del movimiento"
printf "$SUMMARY"
echo
echo "Detalle: move_<variante>/series.txt, log.moveDynamicMesh y log.checkMesh_t<tiempo>."
