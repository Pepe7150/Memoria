#!/usr/bin/env python3
"""
check_flap_motion.py

Verifica que moveDynamicMesh haya movido la malla como se esperaba, SIN
depender de mirar ParaView a ojo. Compara, para un tiempo dado:
  * rotación medida del borde de fuga del flap alrededor de la bisagra
    (a partir de constant/polyMesh/points y <t>/polyMesh/points)
  * rotación esperada según constant/flapMotion.dat
y chequea que puntos del mainfoil y del far-field NO se hayan movido.

Detecta errores de unidades (grados/radianes), de signo y de eje de giro.

Uso (dentro de la carpeta del caso, después de correr moveDynamicMesh):
    python check_flap_motion.py --case . --time 0.25 --hinge 0.7
"""

import argparse
import math
import os
import re
import sys

import numpy as np

NUM = r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"


def read_points(path):
    text = open(path).read()
    # saltar el bloque FoamFile { ... }
    text = text[text.index("}") + 1:]
    pts = re.findall(rf"\(\s*({NUM})\s+({NUM})\s+({NUM})\s*\)", text)
    return np.array(pts, dtype=float)


def read_motion_table(path):
    times, yaws = [], []
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("//") or line in ("(", ")"):
            continue
        nums = re.findall(NUM, line)
        if len(nums) == 7:  # t, surge sway heave, roll pitch yaw
            times.append(float(nums[0]))
            yaws.append(float(nums[6]))
    return np.array(times), np.array(yaws)


def nearest(points, x, y):
    d = np.hypot(points[:, 0] - x, points[:, 1] - y)
    i = int(np.argmin(d))
    return i, d[i]


def signed_angle_deg(p0, p1, hinge):
    a0 = math.atan2(p0[1], p0[0] - hinge)
    a1 = math.atan2(p1[1], p1[0] - hinge)
    d = math.degrees(a1 - a0)
    return (d + 180) % 360 - 180


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--case", default=".")
    ap.add_argument("--time", required=True, help="Nombre de la carpeta de tiempo a revisar (ej. 0.25)")
    ap.add_argument("--hinge", type=float, default=0.7)
    ap.add_argument("--flap-ref", type=float, nargs=2, default=[1.0, 0.00126],
                    help="Coordenadas (x y) de un punto del flap lejos de la bisagra (default: borde de fuga superior)")
    ap.add_argument("--main-ref", type=float, nargs=2, default=[0.3, 0.06],
                    help="Un punto del mainfoil (no debe moverse)")
    ap.add_argument("--far-ref", type=float, nargs=2, default=[-15.0, 0.0],
                    help="Un punto del far-field (no debe moverse)")
    ap.add_argument("--tol-deg", type=float, default=0.05)
    args = ap.parse_args()

    p0_path = os.path.join(args.case, "constant", "polyMesh", "points")
    p1_path = os.path.join(args.case, args.time, "polyMesh", "points")
    tab_path = os.path.join(args.case, "constant", "flapMotion.dat")
    for p in (p0_path, p1_path, tab_path):
        if not os.path.exists(p):
            print(f"ERROR: no existe {p}")
            if p == p1_path:
                dirs = sorted(d for d in os.listdir(args.case) if re.fullmatch(NUM, d))
                print(f"  carpetas de tiempo presentes en {args.case}: {dirs}")
            sys.exit(2)

    pts0 = read_points(p0_path)
    pts1 = read_points(p1_path)
    if pts0.shape != pts1.shape:
        print(f"ERROR: distinto numero de puntos ({len(pts0)} vs {len(pts1)})")
        sys.exit(2)

    times, yaws = read_motion_table(tab_path)
    t = float(args.time)
    expected = float(np.interp(t, times, yaws))

    ok = True
    print(f"Tiempo revisado: {args.time}   puntos: {len(pts0)}")

    # --- flap: rotación medida
    i, d = nearest(pts0, *args.flap_ref)
    measured = signed_angle_deg(pts0[i], pts1[i], args.hinge)
    r0 = math.hypot(pts0[i][0] - args.hinge, pts0[i][1])
    r1 = math.hypot(pts1[i][0] - args.hinge, pts1[i][1])
    print(f"\n[FLAP] punto #{i} (dist. a la referencia {d:.2e}): "
          f"({pts0[i][0]:.5f}, {pts0[i][1]:.5f}) -> ({pts1[i][0]:.5f}, {pts1[i][1]:.5f})")
    print(f"  rotacion medida alrededor de la bisagra : {measured:+.4f} deg")
    print(f"  rotacion esperada (tabla, canal yaw)     : {expected:+.4f} deg")
    print(f"  radio respecto a la bisagra: {r0:.6f} -> {r1:.6f}  (debe conservarse: cuerpo rigido)")
    if abs(measured - expected) > args.tol_deg:
        ok = False
        print("  >>> FALLA: la rotacion medida no coincide con la esperada.")
        if abs(measured + expected) < args.tol_deg and abs(expected) > args.tol_deg:
            print("      Parece SIGNO invertido: prueba --yaw-sign +1 en build_dynamic_move_case.py")
        elif expected != 0 and abs(measured - (((expected * 180 / math.pi) + 180) % 360 - 180)) < 0.5:
            print("      OpenFOAM parece estar leyendo la tabla en RADIANES (no en grados):")
            print("      convierte los valores de flapMotion.dat a radianes (o usa la opcion de grados de tu version).")
        elif abs(measured) < args.tol_deg:
            print("      El flap NO se movio: revisa 0/pointDisplacement, dynamicMeshDict y el log de moveDynamicMesh.")
    if abs(r1 - r0) > 1e-6:
        ok = False
        print("  >>> FALLA: el radio cambio -> el flap se esta deformando, no rotando como cuerpo rigido.")

    # --- puntos que NO deben moverse
    for name, ref in (("MAINFOIL", args.main_ref), ("FARFIELD", args.far_ref)):
        j, dj = nearest(pts0, *ref)
        disp = float(np.linalg.norm(pts1[j] - pts0[j]))
        flag = "ok" if disp < 1e-8 else "FALLA"
        print(f"\n[{name}] punto #{j} (dist. a la referencia {dj:.2e}): desplazamiento = {disp:.3e}   [{flag}]")
        if disp >= 1e-8:
            ok = False

    # --- cuánto se mueve la malla en total
    disp_all = np.linalg.norm(pts1 - pts0, axis=1)
    print(f"\n[GLOBAL] desplazamiento maximo de cualquier punto: {disp_all.max():.5f}   "
          f"(puntos que se mueven > 1e-9: {int((disp_all > 1e-9).sum())} de {len(disp_all)})")

    print("\nRESULTADO:", "OK" if ok else "REVISAR")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
