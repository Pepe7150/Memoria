#!/usr/bin/env python3
"""
resync_results.py

Reconstruye resultados.csv desde cero, releyendo DIRECTO los archivos
postProcessing/forceCoeffs1 y postProcessing/hingeMoment1 de cada carpeta de
caso que ya corrió -- sin relanzar simpleFoam. Útil para corregir columnas
que quedaron desactualizadas (por ejemplo, el bug de continue_nonconverged.py
que no refrescaba ChHinge/HingeMoment_Nm al continuar un caso).

Uso:
    python resync_results.py --config sweep_config.json \
        --summary resultados.csv --workdir sweep_run
"""

import argparse
import csv
import json
import os

from verify_sweep import expected_combos, case_name
from run_sweep import parse_force_coeffs


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", required=True)
    ap.add_argument("--summary", default="resultados.csv")
    ap.add_argument("--workdir", default="sweep_run")
    args = ap.parse_args()

    with open(args.config) as f:
        cfg = json.load(f)

    rho_real = cfg["rho_real"]
    chord_real = cfg["chord_real"]
    span_real = cfg["span_real"]
    a = cfg["speed_of_sound"]

    rows = []
    skipped = []

    for delta, mach, aoa in expected_combos(cfg):
        name = case_name(delta, mach, aoa)
        case_dir = os.path.join(args.workdir, "cases", name)
        if not os.path.isdir(case_dir):
            skipped.append(name)
            continue

        try:
            coeffs = parse_force_coeffs(case_dir, "forceCoeffs1")
            hinge_coeffs = parse_force_coeffs(case_dir, "hingeMoment1")
        except (FileNotFoundError, ValueError) as e:
            print(f"  AVISO: {name}: {e}")
            skipped.append(name)
            continue

        umag_real = mach * a
        hinge_moment_Nm = (
            hinge_coeffs["CmPitch"] * 0.5 * rho_real * umag_real**2
            * chord_real**2 * span_real
        )

        rows.append({
            "delta_deg": delta, "mach": mach, "aoa_deg": aoa,
            **coeffs,
            "ChHinge": hinge_coeffs["CmPitch"],
            "HingeMoment_Nm": hinge_moment_Nm,
        })

    with open(args.summary, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "delta_deg", "mach", "aoa_deg", "Cl", "Cd", "CmPitch",
            "ChHinge", "HingeMoment_Nm",
        ])
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n{args.summary} reconstruido: {len(rows)} filas desde postProcessing/.")
    if skipped:
        print(f"Casos sin carpeta o sin datos (omitidos, {len(skipped)}):")
        for n in skipped:
            print(f"  - {n}")


if __name__ == "__main__":
    main()
