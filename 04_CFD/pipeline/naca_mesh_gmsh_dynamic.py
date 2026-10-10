#!/usr/bin/env python3
"""
naca_mesh_gmsh_dynamic.py

Variante de naca_mesh_gmsh.py para la campaña DINÁMICA: lee el .dat de dos
bloques que produce naca0012_flap_geometry_gapped.py (mainfoil y flap como
polígonos YA separados por un gap físico) y genera una malla tipo C donde
mainfoil y flap son dos agujeros INDEPENDIENTES del dominio -- no comparten
ningún punto, a diferencia de la malla estática.

Cada polígono se parte en spline de extradós + spline de intradós + una
línea recta de cierre (mismo truco que en la malla estática para evitar que
una spline cerrada pase por una esquina aguda y se autointersecte): para el
mainfoil la línea de cierre va por el lado de la bisagra (antes recto, sin
LE ahí, el LE lo cubren las dos splines); para el flap hay DOS líneas
rectas de cierre: una en la bisagra (el gap) y otra en el borde de fuga
romo (igual que siempre).

Uso:
    python naca_mesh_gmsh_dynamic.py --dat naca_gap.dat --out naca_gap.msh \
        --farfield 15 --wake 20 --yplus-height 2.5e-5 --layers 20 --growth 1.2 \
        --te-size 0.004 --le-size 0.004 --farfield-size 1.5
"""

import argparse
import numpy as np
import gmsh


def read_gapped_dat(path, min_spacing=5e-4):
    """Lee el .dat de dos bloques (# MAINFOIL / # FLAP) y filtra puntos
    consecutivos demasiado cercanos (mismo motivo que en la malla estática:
    evitar segmentos casi degenerados que rompen la recuperación de curvas
    en Gmsh)."""
    blocks = {"MAINFOIL": [], "FLAP": []}
    current = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("NACA"):
                continue
            if line.startswith("#"):
                current = line.lstrip("#").strip()
                continue
            x, y = map(float, line.split())
            blocks[current].append((x, y))

    def filt(pts):
        pts = np.array(pts)
        out = [pts[0]]
        for p in pts[1:]:
            if np.linalg.norm(p - out[-1]) >= min_spacing:
                out.append(p)
        # asegura terminar EXACTO en el último punto original (el corte de
        # bisagra, geométricamente importante) sin duplicarlo si ya quedó
        # como el último punto conservado
        if not np.array_equal(out[-1], pts[-1]):
            out[-1] = pts[-1]
        return np.array(out)

    return filt(blocks["MAINFOIL"]), filt(blocks["FLAP"])


def build_polygon_curves(occ, pts, le_size, split_at_sign_change=False):
    """
    Construye un polígono cerrado a partir de un arreglo de puntos (x,y)
    ordenados, partido en dos splines + líneas de cierre para evitar
    auto-intersecciones en las esquinas agudas.

    Si split_at_sign_change=True (caso del flap), el polígono tiene DOS
    esquinas agudas artificiales (el gap de bisagra Y el borde de fuga
    romo) -- se parte en el índice donde y cambia de signo (el salto del
    gap) Y se cierra tanto ahí como en el borde de fuga.

    Si split_at_sign_change=False (caso del mainfoil), el polígono tiene
    UNA esquina aguda artificial (el gap de bisagra) y un extremo suave
    natural (el borde de ataque) -- se parte en el índice de x mínimo (LE).
    """
    point_tags = [occ.addPoint(x, y, 0, le_size) for x, y in pts]

    if split_at_sign_change:
        # el salto de signo de y marca el gap (cut_upper -> cut_lower)
        split_idx = next(
            i for i in range(len(pts) - 1)
            if pts[i][1] >= 0 and pts[i + 1][1] < 0
        )
        upper_spline = occ.addSpline(point_tags[: split_idx + 1])      # TE_sup -> cut_upper
        gap_cap = occ.addLine(point_tags[split_idx], point_tags[split_idx + 1])  # cut_upper -> cut_lower
        lower_spline = occ.addSpline(point_tags[split_idx + 1:])       # cut_lower -> TE_inf
        te_line = occ.addLine(point_tags[-1], point_tags[0])           # TE_inf -> TE_sup
        curves = [upper_spline, gap_cap, lower_spline, te_line]
    else:
        # el mínimo de x marca el borde de ataque
        le_idx = int(np.argmin(pts[:, 0]))
        upper_spline = occ.addSpline(point_tags[: le_idx + 1])         # cut_upper -> LE
        lower_spline = occ.addSpline(point_tags[le_idx:])              # LE -> cut_lower
        gap_cap = occ.addLine(point_tags[-1], point_tags[0])           # cut_lower -> cut_upper
        curves = [upper_spline, lower_spline, gap_cap]

    loop = occ.addCurveLoop(curves)
    return loop, curves


def build_mesh(dat_path, out_path, farfield_radius=15.0, wake_length=20.0,
                y1=2.5e-5, n_layers=20, growth_rate=1.2,
                te_size=0.004, le_size=0.004, farfield_size=1.5,
                extrude_z=0.1, min_spacing=5e-4):
    main_pts, flap_pts = read_gapped_dat(dat_path, min_spacing=min_spacing)
    print(f"Puntos tras filtrar: mainfoil={len(main_pts)}  flap={len(flap_pts)}")

    gmsh.initialize()
    gmsh.model.add("naca_c_mesh_dynamic")
    occ = gmsh.model.occ

    mainfoil_loop, mainfoil_curves = build_polygon_curves(occ, main_pts, le_size, split_at_sign_change=False)
    flap_loop, flap_curves = build_polygon_curves(occ, flap_pts, le_size, split_at_sign_change=True)

    # --- far-field tipo C (idéntico a la malla estática) ---
    R = farfield_radius
    L = wake_length
    p_top = occ.addPoint(0.0, R, 0, farfield_size)
    p_bot = occ.addPoint(0.0, -R, 0, farfield_size)
    p_left = occ.addPoint(-R, 0.0, 0, farfield_size)
    p_center = occ.addPoint(0.0, 0.0, 0, farfield_size)
    p_top_out = occ.addPoint(1.0 + L, R, 0, farfield_size)
    p_bot_out = occ.addPoint(1.0 + L, -R, 0, farfield_size)

    arc_top = occ.addCircleArc(p_top, p_center, p_left)
    arc_bot = occ.addCircleArc(p_left, p_center, p_bot)
    l_top = occ.addLine(p_top, p_top_out)
    l_out = occ.addLine(p_top_out, p_bot_out)
    l_bot = occ.addLine(p_bot_out, p_bot)

    outer_loop = occ.addCurveLoop([arc_top, l_top, l_out, l_bot, arc_bot])
    farfield_arc_curves = {arc_top, arc_bot}

    surface = occ.addPlaneSurface([outer_loop, mainfoil_loop, flap_loop])
    occ.synchronize()

    # --- capa límite sobre AMBOS polígonos ---
    wall_curves = mainfoil_curves + flap_curves
    bl_field = gmsh.model.mesh.field.add("BoundaryLayer")
    gmsh.model.mesh.field.setNumbers(bl_field, "CurvesList", wall_curves)
    gmsh.model.mesh.field.setNumber(bl_field, "hwall_n", y1)
    gmsh.model.mesh.field.setNumber(bl_field, "ratio", growth_rate)
    gmsh.model.mesh.field.setNumber(bl_field, "thickness", y1 * (growth_rate ** n_layers))
    gmsh.model.mesh.field.setNumber(bl_field, "Quads", 1)
    gmsh.model.mesh.field.setAsBoundaryLayer(bl_field)

    dist_field = gmsh.model.mesh.field.add("Distance")
    gmsh.model.mesh.field.setNumbers(dist_field, "CurvesList", wall_curves)
    gmsh.model.mesh.field.setNumber(dist_field, "Sampling", 300)

    size_field = gmsh.model.mesh.field.add("Threshold")
    gmsh.model.mesh.field.setNumber(size_field, "InField", dist_field)
    gmsh.model.mesh.field.setNumber(size_field, "SizeMin", te_size)
    gmsh.model.mesh.field.setNumber(size_field, "SizeMax", farfield_size)
    gmsh.model.mesh.field.setNumber(size_field, "DistMin", 0.05)
    gmsh.model.mesh.field.setNumber(size_field, "DistMax", R * 0.8)
    gmsh.model.mesh.field.setAsBackgroundMesh(size_field)

    gmsh.option.setNumber("Mesh.MeshSizeExtendFromBoundary", 0)
    gmsh.option.setNumber("Mesh.MeshSizeFromPoints", 0)
    gmsh.option.setNumber("Mesh.MeshSizeFromCurvature", 0)

    gmsh.model.mesh.generate(2)

    ext = occ.extrude([(2, surface)], 0, 0, extrude_z, numElements=[1], recombine=True)
    occ.synchronize()
    gmsh.model.mesh.generate(3)

    # --- grupos físicos: igual que en la malla estática, por curva de origen ---
    vol_tag = [e[1] for e in ext if e[0] == 3][0]
    gmsh.model.addPhysicalGroup(3, [vol_tag], name="internal")

    mainfoil_curve_set = set(mainfoil_curves)
    flap_curve_set = set(flap_curves)
    base_curve_ids = mainfoil_curve_set | flap_curve_set | farfield_arc_curves | {l_top, l_out, l_bot}

    mainfoil_tags, flap_tags, farfield_tags, outlet_tags = [], [], [], []
    front_tag = None

    for dim, tag in gmsh.model.getEntities(2):
        if tag == surface:
            continue
        bnd = gmsh.model.getBoundary([(2, tag)], oriented=False, combined=False)
        curve_ids = {abs(c[1]) for c in bnd}

        if curve_ids & mainfoil_curve_set:
            mainfoil_tags.append(tag)
        elif curve_ids & flap_curve_set:
            flap_tags.append(tag)
        elif l_out in curve_ids:
            outlet_tags.append(tag)
        elif curve_ids & (farfield_arc_curves | {l_top, l_bot}):
            farfield_tags.append(tag)
        elif not (curve_ids & base_curve_ids):
            front_tag = tag

    if front_tag is None:
        raise RuntimeError("No se identificó la tapa 'front' del extrude; revisa la geometría.")

    gmsh.model.addPhysicalGroup(2, mainfoil_tags, name="mainfoil")
    gmsh.model.addPhysicalGroup(2, flap_tags, name="flap")
    gmsh.model.addPhysicalGroup(2, farfield_tags, name="farfield")
    gmsh.model.addPhysicalGroup(2, outlet_tags, name="outlet")
    gmsh.model.addPhysicalGroup(2, [front_tag], name="front")
    gmsh.model.addPhysicalGroup(2, [surface], name="back")

    print("Patches creados:")
    print(f"  mainfoil -> {len(mainfoil_tags)} superficie(s)")
    print(f"  flap     -> {len(flap_tags)} superficie(s)")
    print(f"  farfield -> {len(farfield_tags)} superficie(s)")
    print(f"  outlet   -> {len(outlet_tags)} superficie(s)")
    print(f"  front/back -> tags {front_tag} / {surface}")

    gmsh.option.setNumber("Mesh.SaveAll", 0)
    gmsh.option.setNumber("Mesh.MshFileVersion", 2.2)
    gmsh.write(out_path)
    gmsh.finalize()
    print(f"\nMalla escrita en: {out_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dat", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--farfield", type=float, default=15.0)
    ap.add_argument("--wake", type=float, default=20.0)
    ap.add_argument("--yplus-height", type=float, default=2.5e-5, dest="y1")
    ap.add_argument("--layers", type=int, default=20)
    ap.add_argument("--growth", type=float, default=1.2)
    ap.add_argument("--te-size", type=float, default=0.004)
    ap.add_argument("--le-size", type=float, default=0.004)
    ap.add_argument("--farfield-size", type=float, default=1.5)
    ap.add_argument("--extrude-z", type=float, default=0.1)
    ap.add_argument("--min-spacing", type=float, default=5e-4)
    args = ap.parse_args()

    build_mesh(
        args.dat, args.out,
        farfield_radius=args.farfield, wake_length=args.wake,
        y1=args.y1, n_layers=args.layers, growth_rate=args.growth,
        te_size=args.te_size, le_size=args.le_size, farfield_size=args.farfield_size,
        extrude_z=args.extrude_z, min_spacing=args.min_spacing,
    )


if __name__ == "__main__":
    main()
