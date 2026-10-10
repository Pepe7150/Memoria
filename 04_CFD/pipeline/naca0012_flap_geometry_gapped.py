#!/usr/bin/env python3
"""
naca0012_flap_geometry_gapped.py

Variante de naca0012_flap_geometry.py para la campaña DINÁMICA: genera el
perfil NACA00xx con el flap como un polígono SEPARADO del mainfoil, con un
pequeño gap físico entre ambos en la bisagra (en vez de compartir un único
punto, como en la versión estática).

Por qué: para que el flap pueda rotar dentro de una malla dinámica (sin
regenerar la malla en cada paso de tiempo), su frontera no puede compartir
un punto con una frontera que se queda fija (mainfoil) -- ver
DOCUMENTACION_CFD_DINAMICA.md, Sección 4.3.

Salida: un .dat con DOS bloques (uno por polígono), separados por un
header de texto, en el mismo formato de puntos (x y) que ya usa
naca_mesh_gmsh.py -- pero acá cada bloque es ya un polígono cerrado
independiente, no hace falta columna is_flap.

Uso:
    python naca0012_flap_geometry_gapped.py --delta 0 --hinge 0.7 --gap 0.01 \
        --out naca0012_gap.dat --plot
"""

import argparse
import numpy as np


def naca00xx_thickness(x, t):
    return 5 * t * (
        0.2969 * np.sqrt(x)
        - 0.1260 * x
        - 0.3516 * x**2
        + 0.2843 * x**3
        - 0.1015 * x**4
    )


def cosine_spacing(n):
    beta = np.linspace(0, np.pi, n)
    return (1 - np.cos(beta)) / 2


def deflect_points(x, y, x_hinge, delta_deg):
    """Rota (x,y) rígidamente alrededor de (x_hinge, 0) en delta_deg grados
    (positivo = hacia abajo). Usado SOLO sobre los puntos del polígono del
    flap -- el mainfoil nunca se toca."""
    delta = np.radians(delta_deg)
    cos_d, sin_d = np.cos(delta), np.sin(delta)
    dx = x - x_hinge
    dy = y
    x_new = x_hinge + dx * cos_d + dy * sin_d
    y_new = -dx * sin_d + dy * cos_d
    return x_new, y_new


def build_side(x_full, y_full, keep_mask, cut_x, cut_y, prepend, min_spacing):
    """
    Arma un lado (extradós o intradós) de uno de los dos polígonos:
    filtra los puntos originales según keep_mask y agrega el punto exacto
    de corte (cut_x, cut_y) en la bisagra -- al principio (prepend=True) o
    al final (prepend=False) de la lista, según corresponda.

    Si el punto original más cercano al corte queda demasiado pegado al
    punto de corte exacto (riesgo del mismo problema de segmentos casi
    degenerados que ya resolvimos en la malla estática), se descarta.
    """
    xs = x_full[keep_mask]
    ys = y_full[keep_mask]

    if prepend:
        if len(xs) and abs(xs[0] - cut_x) < min_spacing:
            xs, ys = xs[1:], ys[1:]
        xs = np.concatenate([[cut_x], xs])
        ys = np.concatenate([[cut_y], ys])
    else:
        if len(xs) and abs(xs[-1] - cut_x) < min_spacing:
            xs, ys = xs[:-1], ys[:-1]
        xs = np.concatenate([xs, [cut_x]])
        ys = np.concatenate([ys, [cut_y]])

    return xs, ys


def build_geometry_gapped(naca_digits="0012", delta_deg=0.0, x_hinge=0.7,
                           gap=0.01, n_points=200, min_spacing=None):
    """
    Devuelve (main_x, main_y, flap_x, flap_y): dos polígonos abiertos (cada
    uno se cierra después con una línea recta en el script de mallado,
    igual que el TE en la versión estática), listos para pasar a
    naca_mesh_gmsh_dynamic.py.

    main_*: desde el corte en xm=x_hinge-gap/2 (extradós), pasando por el
            borde de ataque, hasta el mismo corte (intradós).
    flap_*: desde el corte en xf=x_hinge+gap/2 (extradós), pasando por el
            borde de fuga, hasta el mismo corte (intradós) -- YA rotado
            según delta_deg alrededor de (x_hinge, 0).
    """
    if min_spacing is None:
        min_spacing = gap * 0.5  # evita puntos casi pegados al corte

    t = int(naca_digits[2:]) / 100.0
    x = cosine_spacing(n_points)
    yt = naca00xx_thickness(x, t)

    xm = x_hinge - gap / 2
    xf = x_hinge + gap / 2
    tm = naca00xx_thickness(np.array(xm), t)
    tf = naca00xx_thickness(np.array(xf), t)

    # --- mainfoil: extradós (xm -> LE) + intradós (LE -> xm) ---
    main_up_x, main_up_y = build_side(x, yt, x < xm, xm, tm, prepend=False, min_spacing=min_spacing)
    main_up_x, main_up_y = main_up_x[::-1], main_up_y[::-1]  # xm -> LE

    main_lo_x, main_lo_y = build_side(x, -yt, x < xm, xm, -tm, prepend=False, min_spacing=min_spacing)
    # main_lo ya viene LE->xm en orden creciente de x

    main_x = np.concatenate([main_up_x, main_lo_x[1:]])  # evita duplicar LE
    main_y = np.concatenate([main_up_y, main_lo_y[1:]])

    # --- flap: extradós (TE_sup -> xf, decreciente) + intradós (xf -> TE_inf, creciente) ---
    # build_side(..., prepend=True) devuelve siempre [xf, puntos con x>xf en
    # orden creciente ..., TE] (orden "xf -> TE"). Para el extradós queremos
    # el sentido opuesto (TE_sup -> xf), así que se revierte UNA vez; para el
    # intradós el orden que entrega build_side ya es el que queremos (xf ->
    # TE_inf), así que no se toca.
    flap_up_x, flap_up_y = build_side(x, yt, x > xf, xf, tf, prepend=True, min_spacing=min_spacing)
    flap_up_x, flap_up_y = flap_up_x[::-1], flap_up_y[::-1]  # TE_sup -> xf

    flap_lo_x, flap_lo_y = build_side(x, -yt, x > xf, xf, -tf, prepend=True, min_spacing=min_spacing)
    # xf -> TE_inf, ya en el orden correcto

    # OJO: a diferencia del mainfoil (donde extradós e intradós comparten el
    # punto del borde de ataque y hay que evitar duplicarlo), acá el corte de
    # arriba (xf,+tf) y el de abajo (xf,-tf) son puntos DISTINTOS -- no se
    # descarta ninguno.
    flap_x = np.concatenate([flap_up_x, flap_lo_x])
    flap_y = np.concatenate([flap_up_y, flap_lo_y])

    if abs(delta_deg) > 1e-9:
        flap_x, flap_y = deflect_points(flap_x, flap_y, x_hinge, delta_deg)

    return main_x, main_y, flap_x, flap_y


def write_dat(path, main_x, main_y, flap_x, flap_y, header):
    with open(path, "w") as f:
        f.write(header.strip() + "\n")
        f.write("# MAINFOIL\n")
        for xi, yi in zip(main_x, main_y):
            f.write(f"{xi:.6f} {yi:.6f}\n")
        f.write("# FLAP\n")
        for xi, yi in zip(flap_x, flap_y):
            f.write(f"{xi:.6f} {yi:.6f}\n")


def plot_geometry(main_x, main_y, flap_x, flap_y, title, out_png=None):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(8, 3))
    ax.plot(main_x, main_y, "-o", markersize=3, linewidth=1, color="tab:blue", label="mainfoil")
    ax.plot(flap_x, flap_y, "-o", markersize=3, linewidth=1, color="tab:red", label="flap")
    # cierra visualmente cada polígono (la línea de cierre real la agrega el mallador)
    ax.plot([main_x[-1], main_x[0]], [main_y[-1], main_y[0]], "--", linewidth=0.7, color="tab:blue")
    ax.plot([flap_x[-1], flap_x[0]], [flap_y[-1], flap_y[0]], "--", linewidth=0.7, color="tab:red")
    ax.axhline(0, color="gray", linewidth=0.5, linestyle=":")
    ax.set_aspect("equal")
    ax.set_title(title)
    ax.set_xlabel("x/c")
    ax.set_ylabel("y/c")
    ax.legend(loc="upper right", fontsize=8)
    fig.tight_layout()
    if out_png:
        fig.savefig(out_png, dpi=150)
    return fig


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--naca", default="0012")
    ap.add_argument("--hinge", type=float, default=0.7)
    ap.add_argument("--gap", type=float, default=0.01,
                     help="Ancho del gap de bisagra, en fraccion de cuerda (default 0.01 = 1%% -- valor de partida, por ajustar)")
    ap.add_argument("--delta", type=float, default=0.0,
                     help="Angulo del flap en grados (para la malla dinamica normalmente 0: la deflexion la da el movimiento, no la geometria neutra)")
    ap.add_argument("--points", type=int, default=200)
    ap.add_argument("--out", default="naca_gap.dat")
    ap.add_argument("--plot", action="store_true")
    args = ap.parse_args()

    main_x, main_y, flap_x, flap_y = build_geometry_gapped(
        args.naca, args.delta, args.hinge, args.gap, args.points
    )

    header = f"NACA{args.naca} gap={args.gap} hinge={args.hinge} delta={args.delta:.2f}deg"
    write_dat(args.out, main_x, main_y, flap_x, flap_y, header)
    print(f"Escrito: {args.out}")
    print(f"  mainfoil: {len(main_x)} puntos   flap: {len(flap_x)} puntos")

    if args.plot:
        png_path = args.out.rsplit(".", 1)[0] + ".png"
        plot_geometry(main_x, main_y, flap_x, flap_y, header, out_png=png_path)
        print(f"  -> figura de verificación: {png_path}")


if __name__ == "__main__":
    main()
