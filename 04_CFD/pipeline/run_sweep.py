#!/usr/bin/env python3
"""
run_sweep.py

Orquesta el barrido completo: para cada delta genera geometría + malla y la
convierte a OpenFOAM UNA vez; para cada combinación de Mach/AoA de ese delta
arma el caso (build_case.py), corre simpleFoam, y junta el Cl/Cd/Cm final en
una tabla resumen (CSV).

Requiere que naca0012_flap_geometry.py, naca_mesh_gmsh.py, build_case.py,
convert_mesh.sh y case_template/ estén en la misma carpeta que este script.
Debe correrse DENTRO de WSL con el entorno de OpenFOAM cargado.

Uso:
    python run_sweep.py --config sweep_config.json

El .json define los deltas, Machs y AoAs a recorrer (ver ejemplo más abajo
en generate_example_config()).
"""

import argparse
import csv
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def run(cmd, **kwargs):
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        print(result.stdout[-3000:])
        print(result.stderr[-3000:])
        raise RuntimeError(f"Falló: {' '.join(cmd)}")
    return result


def build_geometry_and_mesh(delta, cfg, workdir):
    dat_path = os.path.join(workdir, f"naca_delta{delta:+.1f}.dat")
    msh_path = os.path.join(workdir, f"naca_delta{delta:+.1f}.msh")
    mesh_case = os.path.join(workdir, f"mesh_case_delta{delta:+.1f}")

    run([
        sys.executable, os.path.join(HERE, "naca0012_flap_geometry.py"),
        "--delta", str(delta), "--hinge", str(cfg["hinge"]), "--out", dat_path,
    ])

    run([
        sys.executable, os.path.join(HERE, "naca_mesh_gmsh.py"),
        "--dat", dat_path, "--out", msh_path,
        "--farfield", str(cfg["farfield"]), "--wake", str(cfg["wake"]),
        "--yplus-height", str(cfg["y1"]), "--layers", str(cfg["layers"]),
        "--growth", str(cfg["growth"]),
        "--te-size", str(cfg["te_size"]), "--le-size", str(cfg["le_size"]),
        "--farfield-size", str(cfg["farfield_size"]),
        "--extrude-z", str(cfg["extrude_z"]),
    ])

    os.makedirs(mesh_case, exist_ok=True)
    shutil_copy_system_dict(mesh_case)
    run([os.path.join(HERE, "convert_mesh.sh"), mesh_case, msh_path])

    return mesh_case


def shutil_copy_system_dict(case_dir):
    import shutil
    os.makedirs(os.path.join(case_dir, "system"), exist_ok=True)
    shutil.copy(
        os.path.join(HERE, "createPatchDict"),
        os.path.join(case_dir, "system", "createPatchDict"),
    )


def parse_force_coeffs(case_dir):
    """
    Lee el último valor de Cl/Cd/Cm escrito por el function object forceCoeffs
    (postProcessing/forceCoeffs1/0/forceCoeffs.dat o coefficient.dat según la
    versión de OpenFOAM). Devuelve (Cd, Cl, CmPitch) del último renglón.
    """
    candidates = [
        os.path.join(case_dir, "postProcessing", "forceCoeffs1", "0", "coefficient.dat"),
        os.path.join(case_dir, "postProcessing", "forceCoeffs1", "0", "forceCoeffs.dat"),
    ]
    dat_file = next((c for c in candidates if os.path.exists(c)), None)
    if dat_file is None:
        raise FileNotFoundError(
            f"No encontré el archivo de forceCoeffs en {case_dir}/postProcessing/forceCoeffs1/"
        )

    last_line = None
    with open(dat_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                last_line = line

    if last_line is None:
        raise ValueError(f"{dat_file} no tiene datos (¿el caso corrió?)")

    values = re.split(r"\s+", last_line)
    # Confirmado con un caso real: Time Cd Cs Cl CmRoll CmPitch CmYaw Cd(f) ...
    return {"Cd": float(values[1]), "Cl": float(values[3]), "CmPitch": float(values[5])}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", required=True)
    ap.add_argument("--workdir", default="sweep_run")
    ap.add_argument("--summary", default="resultados.csv")
    args = ap.parse_args()

    with open(args.config) as f:
        cfg = json.load(f)

    os.makedirs(args.workdir, exist_ok=True)
    rows = []

    for delta in cfg["deltas"]:
        print(f"\n=== delta = {delta} deg ===")
        mesh_case = build_geometry_and_mesh(delta, cfg, args.workdir)

        for mach in cfg["machs"]:
            for aoa in cfg["aoas"]:
                case_name = f"d{delta:+.1f}_M{mach:.3f}_aoa{aoa:+.1f}".replace(".", "p")
                case_dir = os.path.join(args.workdir, "cases", case_name)

                print(f"\n--- {case_name} ---")
                run([
                    sys.executable, os.path.join(HERE, "build_case.py"),
                    "--mesh-case", mesh_case,
                    "--mach", str(mach), "--aoa", str(aoa),
                    "--chord", str(cfg["chord"]), "--extrude-z", str(cfg["extrude_z"]),
                    "--a", str(cfg["speed_of_sound"]), "--nu", str(cfg["nu"]),
                    "--out", case_dir,
                ])

                run(["simpleFoam", "-case", case_dir], cwd=HERE)

                coeffs = parse_force_coeffs(case_dir)
                rows.append({
                    "delta_deg": delta, "mach": mach, "aoa_deg": aoa,
                    **coeffs,
                })
                print(f"  -> Cl={coeffs['Cl']:.4f}  Cd={coeffs['Cd']:.4f}  CmPitch={coeffs['CmPitch']:.4f}")

    with open(args.summary, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["delta_deg", "mach", "aoa_deg", "Cl", "Cd", "CmPitch"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nResumen escrito en: {args.summary} ({len(rows)} corridas)")


def generate_example_config(path):
    example = {
        "deltas": [-10, 0, 10],
        "machs": [0.1, 0.15, 0.2],
        "aoas": [-4, 0, 4, 8, 12],
        "chord": 1.0,
        "hinge": 0.7,
        "extrude_z": 0.1,
        "farfield": 15,
        "wake": 20,
        "farfield_size": 1.5,
        "te_size": 0.004,
        "le_size": 0.004,
        "y1": 5.95e-6,
        "layers": 20,
        "growth": 1.2,
        "speed_of_sound": 340.3,
        "nu": 1.5e-5,
    }
    with open(path, "w") as f:
        json.dump(example, f, indent=2)
    print(f"Config de ejemplo escrita en: {path}")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--example-config":
        generate_example_config("sweep_config.json")
    else:
        main()
