#!/usr/bin/env python3
"""
build_case.py

Instancia case_template/ para una condición de vuelo concreta (Mach, AoA) y
una malla ya convertida a OpenFOAM (una carpeta de caso que ya tiene
constant/polyMesh, generada con convert_mesh.sh a partir de un .msh de un
delta específico).

Punto clave: como el AoA se impone rotando la dirección de la corriente
libre (NO la malla), liftDir y dragDir del forceCoeffs también deben rotar
con el AoA -- si los dejas fijos en (0,1,0)/(1,0,0) el Cl y Cd que reporte
OpenFOAM van a estar mal para cualquier AoA != 0. Este script calcula eso
correctamente.

Uso:
    python build_case.py --mesh-case casos_malla/naca0012_d10 \
        --mach 0.15 --aoa 6 --chord 1.0 --extrude-z 0.1 \
        --a 340.3 --nu 1.5e-5 \
        --out casos/naca0012_d10_M015_aoa6
"""

import argparse
import math
import os
import shutil

TEMPLATE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "case_template")

TEMPLATE_FILES = [
    "system/controlDict",
    "constant/transportProperties",
    "0/U",
    "0/p",
    "0/nuTilda",
]
# fvSchemes, fvSolution, turbulenceProperties, nut, createPatchDict no llevan
# tokens -> se copian tal cual (createPatchDict solo hace falta una vez, ya
# se usó en convert_mesh.sh, no se vuelve a copiar aquí)
PLAIN_COPY_FILES = [
    "system/fvSchemes",
    "system/fvSolution",
    "constant/turbulenceProperties",
    "0/nut",
]


def substitute(text, tokens):
    for key, value in tokens.items():
        text = text.replace(f"@{key}@", value)
    remaining = [
        line for line in text.splitlines()
        if "@" in line and not line.strip().startswith(("//", "/*", "*", "\\*"))
    ]
    if remaining:
        raise ValueError("Quedaron tokens sin reemplazar:\n" + "\n".join(remaining))
    return text


def build_case(mesh_case, mach, aoa_deg, chord, extrude_z, a, nu, out_dir,
               nutilda_ratio=3.0, cofr_x=0.25):
    if os.path.exists(out_dir):
        raise FileExistsError(f"{out_dir} ya existe -- bórralo o elige otro nombre")

    umag = mach * a
    aoa = math.radians(aoa_deg)
    ux = umag * math.cos(aoa)
    uy = umag * math.sin(aoa)

    # dragDir: alineado con la corriente libre. liftDir: perpendicular, "hacia
    # arriba" respecto del flujo. Ambos rotan con el AoA, no con la malla.
    drag_x, drag_y = math.cos(aoa), math.sin(aoa)
    lift_x, lift_y = -math.sin(aoa), math.cos(aoa)

    re = umag * chord / nu
    nutilda = nutilda_ratio * nu
    aref = chord * extrude_z

    tokens = {
        "UX": f"{ux:.6f}",
        "UY": f"{uy:.6f}",
        "UMAG": f"{umag:.6f}",
        "NU": f"{nu:.6e}",
        "NUTILDA": f"{nutilda:.6e}",
        "CHORD": f"{chord:.6f}",
        "AREF": f"{aref:.6f}",
        "LIFT_X": f"{lift_x:.6f}",
        "LIFT_Y": f"{lift_y:.6f}",
        "DRAG_X": f"{drag_x:.6f}",
        "DRAG_Y": f"{drag_y:.6f}",
        "COFR_X": f"{cofr_x:.6f}",
    }

    # 1. copia la malla ya convertida (constant/polyMesh)
    os.makedirs(out_dir)
    shutil.copytree(
        os.path.join(mesh_case, "constant", "polyMesh"),
        os.path.join(out_dir, "constant", "polyMesh"),
    )

    # 2. archivos con tokens
    for rel_path in TEMPLATE_FILES:
        src = os.path.join(TEMPLATE_DIR, rel_path)
        dst = os.path.join(out_dir, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(src) as f:
            content = f.read()
        content = substitute(content, tokens)
        with open(dst, "w") as f:
            f.write(content)

    # 3. archivos sin tokens
    for rel_path in PLAIN_COPY_FILES:
        src = os.path.join(TEMPLATE_DIR, rel_path)
        dst = os.path.join(out_dir, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(src, dst)

    print(f"Caso escrito en: {out_dir}")
    print(f"  Mach = {mach}  AoA = {aoa_deg} deg")
    print(f"  U = ({ux:.4f}, {uy:.4f}) m/s   |U| = {umag:.4f} m/s")
    print(f"  Re_c = {re:.3e}")
    print(f"  nuTilda freestream = {nutilda:.4e}  (ratio {nutilda_ratio} x nu)")
    print(f"  dragDir = ({drag_x:.4f}, {drag_y:.4f}, 0)")
    print(f"  liftDir = ({lift_x:.4f}, {lift_y:.4f}, 0)")
    print(f"  Aref = {aref:.4f}  (chord x extrude_z -- confirma que extrude_z calza con tu malla)")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mesh-case", required=True, help="Carpeta de caso ya convertida (con constant/polyMesh)")
    ap.add_argument("--mach", type=float, required=True)
    ap.add_argument("--aoa", type=float, required=True, help="Ángulo de ataque en grados")
    ap.add_argument("--chord", type=float, default=1.0)
    ap.add_argument("--extrude-z", type=float, default=0.1, help="Debe calzar con el usado en naca_mesh_gmsh.py")
    ap.add_argument("--a", type=float, default=340.3, help="Velocidad del sonido [m/s] (default: ISA nivel del mar)")
    ap.add_argument("--nu", type=float, default=1.5e-5, help="Viscosidad cinemática [m^2/s]")
    ap.add_argument("--nutilda-ratio", type=float, default=3.0,
                     help="nuTilda_freestream / nu (default 3, práctica estándar para SA)")
    ap.add_argument("--cofr-x", type=float, default=0.25, help="Posición x del centro de referencia de momento (default: 1/4 de cuerda)")
    ap.add_argument("--out", required=True, help="Carpeta de salida del caso")
    args = ap.parse_args()

    build_case(
        args.mesh_case, args.mach, args.aoa, args.chord, args.extrude_z,
        args.a, args.nu, args.out,
        nutilda_ratio=args.nutilda_ratio, cofr_x=args.cofr_x,
    )


if __name__ == "__main__":
    main()
