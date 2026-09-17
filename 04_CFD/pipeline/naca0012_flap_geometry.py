#!/usr/bin/env python3
"""
naca0012_flap_geometry.py

Genera las coordenadas del perfil NACA 0012 (o cualquier NACA 00xx simétrico)
con una superficie de control (flap) deflectada rígidamente en un ángulo delta,
rotando alrededor de una bisagra ubicada en x_hinge (fracción de cuerda).

Pensado para automatizar el paso "una malla por cada valor de delta" del
flujo de trabajo en OpenFOAM: cada corrida de este script produce un .dat
con la geometría exacta que le vas a pasar a tu mallador (Gmsh/Construct2D/etc).

Uso típico:
    python naca0012_flap_geometry.py --delta 10 --hinge 0.7 --out naca0012_d10.dat
    python naca0012_flap_geometry.py --delta -5 --hinge 0.7 --out naca0012_dm5.dat

Para generar todo el barrido de deltas de una vez:
    python naca0012_flap_geometry.py --sweep -20 20 5 --hinge 0.7 --outdir geometrias/ --plot
"""

import argparse
import os
import numpy as np


def naca00xx_thickness(x, t):
    """Distribución de espesor NACA 00xx (perfil simétrico), t = espesor máx (ej. 0.12)."""
    return 5 * t * (
        0.2969 * np.sqrt(x)
        - 0.1260 * x
        - 0.3516 * x**2
        + 0.2843 * x**3
        - 0.1015 * x**4
    )


def cosine_spacing(n):
    """Espaciado coseno entre 0 y 1: concentra puntos cerca del borde de ataque
    y del borde de fuga, donde la curvatura y los gradientes son mayores."""
    beta = np.linspace(0, np.pi, n)
    return (1 - np.cos(beta)) / 2


def base_airfoil(naca_digits="0012", n_points=200):
    """
    Genera la superficie superior e inferior de un NACA 00xx simétrico sin deflexión.
    Devuelve (x, y_upper, y_lower), ambos de longitud n_points, con x en [0, 1].
    """
    t = int(naca_digits[2:]) / 100.0  # ej. "0012" -> 0.12
    x = cosine_spacing(n_points)
    yt = naca00xx_thickness(x, t)
    y_upper = yt
    y_lower = -yt
    return x, y_upper, y_lower


def deflect_flap(x, y, x_hinge, delta_deg):
    """
    Rota rígidamente, alrededor de la bisagra (x_hinge, 0), todos los puntos
    con x >= x_hinge en un ángulo delta_deg (positivo = flap hacia abajo,
    convención típica de deflexión de superficie de control).

    Como el NACA 00xx no tiene cámber, la línea de cuerda coincide con y=0,
    así que la bisagra está exactamente en (x_hinge, 0).
    """
    delta = np.radians(delta_deg)
    # Rotación horaria para delta positivo = flap hacia abajo
    cos_d, sin_d = np.cos(delta), np.sin(delta)

    x_new = x.copy()
    y_new = y.copy()

    mask = x >= x_hinge
    dx = x[mask] - x_hinge
    dy = y[mask]

    x_new[mask] = x_hinge + dx * cos_d + dy * sin_d
    y_new[mask] = -dx * sin_d + dy * cos_d

    return x_new, y_new


def build_geometry(naca_digits="0012", delta_deg=0.0, x_hinge=0.7, n_points=200):
    """
    Arma el perfil completo (superior + inferior) con el flap deflectado,
    y devuelve los puntos ordenados en formato Selig: desde el borde de fuga
    superior, sobre el extradós hacia el borde de ataque, y de vuelta por el
    intradós hasta el borde de fuga. Ese es el orden que esperan la mayoría
    de los malladores (Gmsh, Construct2D, Xfoil).
    """
    x, y_upper, y_lower = base_airfoil(naca_digits, n_points)

    if abs(delta_deg) > 1e-9:
        x_upper, y_upper = deflect_flap(x, y_upper, x_hinge, delta_deg)
        x_lower, y_lower = deflect_flap(x, y_lower, x_hinge, delta_deg)
    else:
        x_upper, x_lower = x, x

    # Extradós de TE a LE (orden inverso), luego intradós de LE a TE
    x_top = x_upper[::-1]
    y_top = y_upper[::-1]
    x_bot = x_lower[1:]  # se salta el punto del LE para no duplicarlo
    y_bot = y_lower[1:]

    x_full = np.concatenate([x_top, x_bot])
    y_full = np.concatenate([y_top, y_bot])

    return x_full, y_full


def write_dat(path, x, y, header):
    with open(path, "w") as f:
        f.write(header.strip() + "\n")
        for xi, yi in zip(x, y):
            f.write(f"{xi:.6f} {yi:.6f}\n")


def plot_geometry(x, y, title, out_png=None):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(8, 3))
    ax.plot(x, y, "-o", markersize=2, linewidth=1)
    ax.axhline(0, color="gray", linewidth=0.5, linestyle="--")
    ax.set_aspect("equal")
    ax.set_title(title)
    ax.set_xlabel("x/c")
    ax.set_ylabel("y/c")
    fig.tight_layout()
    if out_png:
        fig.savefig(out_png, dpi=150)
    return fig


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--naca", default="0012", help="Dígitos NACA 00xx (default: 0012)")
    parser.add_argument("--hinge", type=float, default=0.7,
                         help="Posición de la bisagra del flap, en fracción de cuerda x/c (default: 0.7)")
    parser.add_argument("--points", type=int, default=200,
                         help="Número de puntos por superficie antes de unir (default: 200)")
    parser.add_argument("--delta", type=float, default=None,
                         help="Ángulo de deflexión del flap en grados (positivo = hacia abajo). "
                              "Usa esto para un único caso.")
    parser.add_argument("--sweep", nargs=3, type=float, metavar=("MIN", "MAX", "STEP"),
                         help="Barrido de deltas: MIN MAX STEP (grados). Genera un .dat por cada valor.")
    parser.add_argument("--out", default="naca_geom.dat",
                         help="Nombre de archivo de salida (solo para --delta único)")
    parser.add_argument("--outdir", default="geometrias",
                         help="Carpeta de salida (solo para --sweep)")
    parser.add_argument("--plot", action="store_true",
                         help="También guarda un .png de verificación por cada geometría")
    args = parser.parse_args()

    if args.delta is None and args.sweep is None:
        parser.error("Debes indicar --delta <valor> para un único caso, "
                      "o --sweep MIN MAX STEP para generar varios.")

    if args.delta is not None:
        deltas = [args.delta]
        outputs = [args.out]
    else:
        dmin, dmax, dstep = args.sweep
        deltas = np.arange(dmin, dmax + 1e-9, dstep)
        os.makedirs(args.outdir, exist_ok=True)
        outputs = [
            os.path.join(args.outdir, f"naca{args.naca}_delta{d:+.1f}.dat".replace("+", "p").replace("-", "m"))
            for d in deltas
        ]

    for delta_deg, out_path in zip(deltas, outputs):
        x, y = build_geometry(args.naca, delta_deg, args.hinge, args.points)
        header = f"NACA{args.naca} flap hinge={args.hinge} delta={delta_deg:.2f}deg"
        write_dat(out_path, x, y, header)
        print(f"Escrito: {out_path}  (delta = {delta_deg:.2f} deg)")

        if args.plot:
            png_path = os.path.splitext(out_path)[0] + ".png"
            plot_geometry(x, y, header, out_png=png_path)
            print(f"  -> figura de verificación: {png_path}")


if __name__ == "__main__":
    main()
