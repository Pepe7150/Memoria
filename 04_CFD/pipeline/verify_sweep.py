#!/usr/bin/env python3
"""
verify_sweep.py

Cruza sweep_config.json contra resultados.csv y las carpetas de caso reales
para detectar:
  - combinaciones (delta, mach, aoa) que deberían existir pero no están en el CSV
  - filas del CSV cuya carpeta de caso no existe
  - casos que probablemente NO convergieron (llegaron al tope de iteraciones
    en vez de cortar por el criterio de residuales)
  - valores de Cl/Cd/CmPitch fuera de rango físico razonable (NaN, Cd<0, etc.)

No necesita releer los logs de simpleFoam (que run_sweep.py no guarda por
caso) -- para detectar no-convergencia usa un truco simple: revisa el mayor
directorio de tiempo escrito en cada carpeta de caso. Si el caso convergió
antes del tope, ese número es "raro" (ej. 1263, 1481); si el caso llegó al
tope de iteraciones sin converger, vas a ver exactamente el valor de endTime
(ej. 2000) como carpeta de tiempo final.

Uso:
    python verify_sweep.py --config sweep_config.json --summary resultados.csv \
        --workdir sweep_run
"""

import argparse
import csv
import json
import math
import os
import re


def case_name(delta, mach, aoa):
    return f"d{delta:+.1f}_M{mach:.3f}_aoa{aoa:+.1f}".replace(".", "p")


def expected_combos(cfg):
    for delta in cfg["deltas"]:
        for mach in cfg["machs"]:
            for aoa in cfg["aoas"]:
                yield (float(delta), float(mach), float(aoa))


def read_results_csv(path):
    rows = {}
    if not os.path.exists(path):
        return rows
    with open(path) as f:
        for row in csv.DictReader(f):
            key = (float(row["delta_deg"]), float(row["mach"]), float(row["aoa_deg"]))
            rows[key] = row
    return rows


def get_end_time(case_dir):
    """Lee endTime desde system/controlDict de un caso (asume una línea simple
    'endTime  N;')."""
    path = os.path.join(case_dir, "system", "controlDict")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        text = f.read()
    m = re.search(r"endTime\s+([0-9.]+)\s*;", text)
    return float(m.group(1)) if m else None


def max_time_dir(case_dir):
    """Mayor carpeta de tiempo numérica escrita dentro del caso."""
    times = []
    if not os.path.isdir(case_dir):
        return None
    for name in os.listdir(case_dir):
        try:
            times.append(float(name))
        except ValueError:
            continue
    return max(times) if times else None


def check_values(row):
    problems = []
    for key in ("Cl", "Cd", "CmPitch"):
        try:
            val = float(row[key])
        except (KeyError, ValueError):
            problems.append(f"{key} no numérico")
            continue
        if math.isnan(val) or math.isinf(val):
            problems.append(f"{key} es NaN/Inf")
    try:
        if float(row["Cd"]) < 0:
            problems.append("Cd negativo (no físico)")
        if abs(float(row["Cl"])) > 3:
            problems.append(f"Cl={row['Cl']} fuera de rango esperable")
    except (KeyError, ValueError):
        pass
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", required=True)
    ap.add_argument("--summary", default="resultados.csv")
    ap.add_argument("--workdir", default="sweep_run")
    args = ap.parse_args()

    with open(args.config) as f:
        cfg = json.load(f)

    results = read_results_csv(args.summary)
    combos = list(expected_combos(cfg))

    missing_from_csv = []
    missing_case_dir = []
    not_converged = []
    bad_values = []
    ok = []

    for delta, mach, aoa in combos:
        key = (delta, mach, aoa)
        name = case_name(delta, mach, aoa)
        case_dir = os.path.join(args.workdir, "cases", name)

        if key not in results:
            missing_from_csv.append(name)
            continue

        if not os.path.isdir(case_dir):
            missing_case_dir.append(name)
            continue

        end_time = get_end_time(case_dir)
        last_time = max_time_dir(case_dir)
        case_not_converged = (
            end_time is not None and last_time is not None and last_time >= end_time
        )
        if case_not_converged:
            not_converged.append((name, last_time, end_time))

        problems = check_values(results[key])
        if problems:
            bad_values.append((name, problems))

        if not problems and not case_not_converged:
            ok.append(name)

    extra_in_csv = [k for k in results if k not in combos]

    print(f"Combinaciones esperadas: {len(combos)}")
    print(f"OK (en CSV, carpeta existe, converge, valores sanos): {len(ok)}")
    print()

    if missing_from_csv:
        print(f"FALTAN en {args.summary} ({len(missing_from_csv)}):")
        for n in missing_from_csv:
            print(f"  - {n}")
        print()

    if missing_case_dir:
        print(f"Están en el CSV pero falta la carpeta de caso ({len(missing_case_dir)}):")
        for n in missing_case_dir:
            print(f"  - {n}")
        print()

    if not_converged:
        print(f"POSIBLEMENTE NO CONVERGIERON -- llegaron al tope de iteraciones ({len(not_converged)}):")
        for n, last_t, end_t in not_converged:
            print(f"  - {n}  (última carpeta de tiempo: {last_t:g}, endTime: {end_t:g})")
        print()

    if bad_values:
        print(f"VALORES SOSPECHOSOS ({len(bad_values)}):")
        for n, problems in bad_values:
            print(f"  - {n}: {', '.join(problems)}")
        print()

    if extra_in_csv:
        print(f"Filas en el CSV que NO corresponden a ninguna combinación esperada ({len(extra_in_csv)}):")
        for delta, mach, aoa in extra_in_csv:
            print(f"  - delta={delta} mach={mach} aoa={aoa}")
        print()

    total_problems = len(missing_from_csv) + len(missing_case_dir) + len(not_converged) + len(bad_values)
    if total_problems == 0:
        print("Todo en orden: todas las combinaciones están presentes, con carpeta, convergidas y con valores sanos.")
    else:
        print(f"Total de casos con algún problema: {total_problems} de {len(combos)}")


if __name__ == "__main__":
    main()
