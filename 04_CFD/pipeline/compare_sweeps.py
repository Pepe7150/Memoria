#!/usr/bin/env python3
"""
compare_sweeps.py

Compara dos resultados.csv (por ejemplo el barrido ANTIGUO con rotación rígida de
la bisagra vs. el NUEVO con articulación sellada) en las combinaciones
(delta, Mach, AoA) que tienen en común, y resume cuánto cambian Cl, Cd, CmPitch,
ChHinge y el momento de bisagra. Sirve para cuantificar el efecto del modelo
geométrico de la bisagra y como validación del modelo nuevo.

Uso:
    python compare_sweeps.py resultados_antiguo.csv resultados.csv
    python compare_sweeps.py resultados_antiguo.csv resultados.csv --detalle
"""
import argparse
import csv
import statistics as st
from collections import defaultdict


def load(path):
    out = {}
    with open(path) as f:
        for r in csv.DictReader(f):
            out[(float(r["delta_deg"]), float(r["mach"]), float(r["aoa_deg"]))] = {
                k: float(r[k]) for k in ("Cl", "Cd", "CmPitch", "ChHinge", "HingeMoment_Nm")}
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("antiguo")
    ap.add_argument("nuevo")
    ap.add_argument("--detalle", action="store_true", help="imprime cada combinación común")
    args = ap.parse_args()

    a, b = load(args.antiguo), load(args.nuevo)
    common = sorted(set(a) & set(b))
    print(f"Combinaciones en común: {len(common)}  (antiguo: {len(a)}, nuevo: {len(b)})")
    if not common:
        return

    if args.detalle:
        print(f"\n{'delta':>6} {'Mach':>6} {'AoA':>5} | {'Cl ant':>8} {'Cl nue':>8} {'dCl':>8} | "
              f"{'M_bis ant':>10} {'M_bis nue':>10} {'d%':>7}")
        for k in common:
            o, n = a[k], b[k]
            rel = 100 * (n["HingeMoment_Nm"] - o["HingeMoment_Nm"]) / o["HingeMoment_Nm"] if abs(o["HingeMoment_Nm"]) > 0.02 else float("nan")
            print(f"{k[0]:>6.0f} {k[1]:>6.2f} {k[2]:>5.0f} | {o['Cl']:>8.4f} {n['Cl']:>8.4f} {n['Cl'] - o['Cl']:>+8.4f} | "
                  f"{o['HingeMoment_Nm']:>+10.4f} {n['HingeMoment_Nm']:>+10.4f} {rel:>6.1f}%")

    by_delta = defaultdict(list)
    for k in common:
        by_delta[k[0]].append(k)
    print(f"\n{'delta':>6} {'n':>3} | {'media |dCl|':>11} {'max |dCl|':>10} | {'media |dCd|':>11} | "
          f"{'media |dCm|':>11} | {'media d% M_bisagra':>19} {'max |d%|':>9}")
    for d in sorted(by_delta):
        ks = by_delta[d]
        dcl = [abs(b[k]["Cl"] - a[k]["Cl"]) for k in ks]
        dcd = [abs(b[k]["Cd"] - a[k]["Cd"]) for k in ks]
        dcm = [abs(b[k]["CmPitch"] - a[k]["CmPitch"]) for k in ks]
        rel = [100 * (b[k]["HingeMoment_Nm"] - a[k]["HingeMoment_Nm"]) / a[k]["HingeMoment_Nm"]
               for k in ks if abs(a[k]["HingeMoment_Nm"]) > 0.02]
        rel_s = f"{st.mean(rel):>+18.1f}% {max(abs(x) for x in rel):>8.1f}%" if rel else f"{'(M_bis ~ 0)':>19} {'':>9}"
        print(f"{d:>6.0f} {len(ks):>3} | {st.mean(dcl):>11.4f} {max(dcl):>10.4f} | {st.mean(dcd):>11.5f} | "
              f"{st.mean(dcm):>11.5f} | {rel_s}")
    print("\nLectura: diferencias pequeñas en |delta| bajo y que crecen con |delta| son lo esperable "
          "(el modelo antiguo deformaba más la zona de la bisagra al deflectar más).")


if __name__ == "__main__":
    main()
