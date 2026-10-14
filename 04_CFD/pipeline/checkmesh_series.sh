#!/bin/bash
#
# checkmesh_series.sh
#
# Corre checkMesh en CADA carpeta de tiempo escrita por moveDynamicMesh y
# resume los indicadores que importan, para ver en que tiempo empieza a
# degradarse (o invertirse) la malla.
#
# Notas:
#  * checkMesh de OpenFOAM v2012 NO tiene -allTime; se usa -time T por cada tiempo.
#  * "Mesh OK" NO sirve como criterio: una malla con capa limite siempre
#    falla el chequeo de aspect ratio (tambien la malla estatica buena). Por eso
#    aqui se marcan umbrales concretos: volumen <= 0, skewness > 4, no-ortogonalidad > 70.
#
# Uso (con el entorno de OpenFOAM cargado):
#     ./checkmesh_series.sh [carpeta_del_caso]      # default: carpeta actual
# Salida: tabla por tiempo; la columna "avisos" vacia = sin problemas graves.

CASE="${1:-.}"
cd "$CASE" || { echo "No existe $CASE"; exit 1; }

if ! command -v checkMesh &> /dev/null; then
    echo "ERROR: no se encuentra checkMesh. Carga el entorno de OpenFOAM:"
    echo "       source /opt/OpenFOAM/OpenFOAM-v2012/etc/bashrc"
    exit 1
fi

times=$(ls -d [0-9]* 2>/dev/null | grep -v '^0$' | sort -g)
if [ -z "$times" ]; then
    echo "No hay carpetas de tiempo (>0) en $(pwd). Corriste moveDynamicMesh?"
    exit 1
fi

strip() { sed -E 's/\.$//'; }

printf "%-9s %-8s %-13s %-12s %-12s %s\n" "tiempo" "fallos" "min_volumen" "skew_max" "no_ortog" "avisos"
for t in $times; do
    out=$(checkMesh -time "$t" -allGeometry -allTopology 2>&1)
    echo "$out" > "log.checkMesh_t$t"

    nfail=$(echo "$out" | grep -oE "Failed [0-9]+ mesh checks" | awk '{print $2}')
    if echo "$out" | grep -q "Mesh OK"; then nfail=0; fi
    minvol=$(echo "$out" | grep -m1 -oE "Min volume = [-+0-9.eE]+" | awk '{print $4}' | strip)
    skew=$(echo "$out" | grep -m1 -oE "Max skewness = [-+0-9.eE]+" | awk '{print $4}' | strip)
    nonorth=$(echo "$out" | grep -m1 -oE "non-orthogonality Max: [-+0-9.eE]+" | awk '{print $3}' | strip)

    avisos=""
    echo "$out" | grep -qiE "negative cell volume|Zero or negative cell volume" && avisos="${avisos}VOLUMEN<=0 "
    echo "$out" | grep -qiE "incorrectly oriented" && avisos="${avisos}CARAS_MAL_ORIENTADAS "
    echo "$out" | grep -qiE "FOAM FATAL|Floating point|nan" && avisos="${avisos}ERROR/NaN "
    awk -v v="${minvol:-0}" 'BEGIN{exit !(v+0 <= 0)}' && avisos="${avisos}VOL_MIN<=0 "
    awk -v s="${skew:-0}"   'BEGIN{exit !(s+0 > 4)}'  && avisos="${avisos}SKEW>4 "
    awk -v n="${nonorth:-0}" 'BEGIN{exit !(n+0 > 70)}' && avisos="${avisos}NO_ORTOG>70 "
    [ -z "$minvol" ] && avisos="${avisos}SIN_DATOS "

    printf "%-9s %-8s %-13s %-12s %-12s %s\n" "$t" "${nfail:-?}" "${minvol:-?}" "${skew:-?}" "${nonorth:-?}" "$avisos"
done
echo
echo "Detalle completo por tiempo en log.checkMesh_t<tiempo>."
