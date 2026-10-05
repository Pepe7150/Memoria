#!/usr/bin/env python3
"""
continue_nonconverged.py

Para cada caso que verify_sweep.py marca como "posiblemente no convergió"
(llegó a endTime sin cumplir el residualControl), le sube el endTime y lo
retoma desde el último estado guardado (NO desde cero), y actualiza
resultados.csv con el Cl/Cd/CmPitch Y TAMBIÉN ChHinge/HingeMoment_Nm una vez
que termina (las cuatro columnas, no solo las tres primeras -- antes este
script dejaba ChHinge/HingeMoment_Nm con el valor viejo, de antes de
converger).

Clave: cambia "startFrom" a "latestTime" antes de relanzar simpleFoam --
si no, simpleFoam vuelve a arrancar desde el tiempo 0 (el controlDict de la
plantilla trae "startFrom startTime; startTime 0;" fijo) y se pierden todas
las iteraciones ya hechas.

Debe correrse DENTRO de WSL con el entorno de OpenFOAM cargado.

Uso:
    python continue_nonconverged.py --config sweep_config.json \
        --summary resultados.csv --workdir sweep_run --extra-iters 3000
"""

import argparse
import csv
import json
import os
import subprocess
import sys

from verify_sweep import expected_combos, case_name, get_end_time, max_time_dir
from run_sweep import parse_force_coeffs


def run(cmd, **kwargs):
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        print(result.stdout[-3000:])
        print(result.stderr[-3000:])
        raise RuntimeError(f"Falló: {' '.join(cmd)}")
    return result


def find_not_converged(cfg, workdir):
    not_converged = []
    for delta, mach, aoa in expected_combos(cfg):
        name = case_name(delta, mach, aoa)
        case_dir = os.path.join(workdir, "cases", name)
        if not os.path.isdir(case_dir):
            continue
        end_time = get_end_time(case_dir)
        last_time = max_time_dir(case_dir)
        if end_time is not None and last_time is not None and last_time >= end_time:
            not_converged.append((delta, mach, aoa, case_dir, end_time))
    return not_converged


def continue_case(case_dir, new_end_time):
    run(["foamDictionary", os.path.join(case_dir, "system", "controlDict"),
         "-entry", "startFrom", "-set", "latestTime"])
    run(["foamDictionary", os.path.join(case_dir, "system", "controlDict"),
         "-entry", "endTime", "-set", str(new_end_time)])
    run(["simpleFoam", "-case", case_dir])


def update_csv(summary_path, updates):
    """updates: dict {(delta,mach,aoa): {"Cl":.., "Cd":.., "CmPitch":..,
    "ChHinge":.., "HingeMoment_Nm":..}}"""
    rows = []
    with open(summary_path) as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            key = (float(row["delta_deg"]), float(row["mach"]), float(row["aoa_deg"]))
            if key in updates:
                for k, v in updates[key].items():
                    row[k] = f"{v:.6f}" if k != "HingeMoment_Nm" else f"{v:.8f}"
            rows.append(row)

    with open(summary_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", required=True)
    ap.add_argument("--summary", default="resultados.csv")
    ap.add_argument("--workdir", default="sweep_run")
    ap.add_argument("--extra-iters", type=float, default=3000,
                     help="Cuántas iteraciones más darle (se suma al endTime actual)")
    args = ap.parse_args()

    with open(args.config) as f:
        cfg = json.load(f)

    rho_real = cfg["rho_real"]
    chord_real = cfg["chord_real"]
    span_real = cfg["span_real"]
    a = cfg["speed_of_sound"]

    targets = find_not_converged(cfg, args.workdir)
    if not targets:
        print("No hay casos marcados como no convergidos. Nada que hacer.")
        return

    print(f"Casos a continuar: {len(targets)}")
    updates = {}

    for delta, mach, aoa, case_dir, end_time in targets:
        new_end_time = end_time + args.extra_iters
        print(f"\n--- {os.path.basename(case_dir)}  (endTime {end_time:g} -> {new_end_time:g}) ---")
        continue_case(case_dir, new_end_time)

        coeffs = parse_force_coeffs(case_dir, "forceCoeffs1")
        hinge_coeffs = parse_force_coeffs(case_dir, "hingeMoment1")

        umag_real = mach * a
        hinge_moment_Nm = (
            hinge_coeffs["CmPitch"] * 0.5 * rho_real * umag_real**2
            * chord_real**2 * span_real
        )

        updates[(delta, mach, aoa)] = {
            **coeffs,
            "ChHinge": hinge_coeffs["CmPitch"],
            "HingeMoment_Nm": hinge_moment_Nm,
        }
        print(f"  -> Cl={coeffs['Cl']:.4f}  Cd={coeffs['Cd']:.4f}  CmPitch={coeffs['CmPitch']:.4f}"
              f"  |  ChHinge={hinge_coeffs['CmPitch']:.4f}  M_bisagra={hinge_moment_Nm:.4f} N·m")

    update_csv(args.summary, updates)
    print(f"\n{args.summary} actualizado con {len(updates)} filas (las 5 columnas calculadas).")
    print("Vuelve a correr verify_sweep.py para confirmar que ya convergieron")
    print("(si alguno sigue llegando al tope, puede ser flujo genuinamente")
    print("separado/inestable -- ahí conviene mirar el caso en ParaView antes")
    print("de simplemente seguir dándole más iteraciones).")


if __name__ == "__main__":
    main()
