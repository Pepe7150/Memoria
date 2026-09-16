#!/usr/bin/env python3
"""
naca_mesh_gmsh.py

Genera una malla tipo C alrededor de un perfil (leído desde un .dat en formato
Selig, el mismo que produce naca0012_flap_geometry.py) con capa límite (inflation
layers) sobre la superficie del perfil, y la exporta en formato .msh (v2 ASCII)
lista para convertir a OpenFOAM con gmshToFoam.

Topología: dominio en C (semicírculo aguas arriba + rectángulo aguas abajo),
extruido una celda en z para que quede como un caso 2D pseudo-3D de OpenFOAM
(patches "front" y "back" tipo empty).

Uso típico (uno por cada .dat generado en el paso de geometría):
    python naca_mesh_gmsh.py --dat geometrias/naca0012_delta+10.0.dat \ --out mallas/naca0012_delta+10.msh \--yplus-height 3e-6 --farfield 20

El valor de --yplus-height es la altura de la primera celda junto a la pared
(y1), que depende del Reynolds más alto de tu barrido de Mach/AoA para ese
delta (ver compute_first_layer_height.py). Usa el mismo y1 para todas las
combinaciones de Mach/AoA de un mismo delta: es conservador para los Re más
bajos del barrido, pero evita tener que remallar por cada condición de flujo.
"""

import argparse
import numpy as np
import gmsh


def read_dat(path, min_spacing=5e-4):
    """
    Lee el .dat y filtra puntos consecutivos demasiado cercanos entre sí.

    Los .dat generados con espaciado coseno acumulan puntos extremadamente
    juntos cerca del borde de fuga (más aún si además hay un flap deflectado
    ahí cerca). Pasarle esos segmentos casi degenerados a Gmsh como spline
    hace que la recuperación de la curva 1D falle ("Edge not recovered").
    Este filtro conserva la forma pero evita segmentos menores a min_spacing
    (en fracción de cuerda).
    """
    pts = []
    with open(path) as f:
        lines = f.readlines()[1:]  # salta el header
    for line in lines:
        line = line.strip()
        if not line:
            continue
        x, y = map(float, line.split())
        pts.append((x, y))
    pts = np.array(pts)

    filtered = [pts[0]]
    for p in pts[1:]:
        if np.linalg.norm(p - filtered[-1]) >= min_spacing:
            filtered.append(p)
    filtered.append(pts[-1])  # asegura cerrar exactamente donde termina el .dat
    return np.array(filtered)


def build_mesh(dat_path, out_path, farfield_radius=20.0, wake_length=25.0,
                y1=1e-5, n_layers=25, growth_rate=1.2,
                te_size=0.001, le_size=0.001, farfield_size=1.5,
                extrude_z=0.1, min_spacing=5e-4):
    coords = read_dat(dat_path, min_spacing=min_spacing)
    print(f"Puntos del perfil tras filtrar (min_spacing={min_spacing}): {len(coords)}")

    gmsh.initialize()
    gmsh.model.add("naca_c_mesh")
    occ = gmsh.model.occ

    # --- 1. Puntos del perfil, partidos en extradós/intradós + línea de TE ---
    # OJO: una sola spline cerrada que pase por el borde de fuga romo produce
    # "overshoot" numérico justo en ese kink agudo (la spline intenta ser
    # suave donde la geometría en realidad tiene una esquina) y eso es lo que
    # generaba las auto-intersecciones. La solución estándar es partir la
    # curva en extradós + intradós y cerrar el TE con una línea recta.
    le_idx = int(np.argmin(coords[:, 0]))  # el .dat va TE_sup -> LE -> TE_inf
    upper = coords[: le_idx + 1]           # TE_sup -> LE
    lower = coords[le_idx:]                # LE -> TE_inf

    upper_pts = [occ.addPoint(x, y, 0, le_size) for x, y in upper]
    lower_pts = [occ.addPoint(x, y, 0, le_size) for x, y in lower]
    # comparten el punto del LE para no duplicarlo
    lower_pts[0] = upper_pts[-1]

    spline_upper = occ.addSpline(upper_pts)                  # TE_sup -> LE
    spline_lower = occ.addSpline(lower_pts)                  # LE -> TE_inf
    te_line = occ.addLine(lower_pts[-1], upper_pts[0])        # TE_inf -> TE_sup

    airfoil_loop = occ.addCurveLoop([spline_upper, spline_lower, te_line])
    airfoil_curves = [spline_upper, spline_lower, te_line]

    # --- 2. Dominio exterior tipo C: semicírculo aguas arriba + rectángulo aguas abajo ---
    R = farfield_radius
    L = wake_length

    p_top_te = occ.addPoint(1.0, R, 0, farfield_size)
    p_bot_te = occ.addPoint(1.0, -R, 0, farfield_size)
    p_top_out = occ.addPoint(1.0 + L, R, 0, farfield_size)
    p_bot_out = occ.addPoint(1.0 + L, -R, 0, farfield_size)
    p_center = occ.addPoint(0.0, 0.0, 0, farfield_size)

    arc = occ.addCircleArc(p_top_te, p_center, p_bot_te)
    l_top = occ.addLine(p_top_te, p_top_out)
    l_out = occ.addLine(p_top_out, p_bot_out)
    l_bot = occ.addLine(p_bot_out, p_bot_te)

    outer_loop = occ.addCurveLoop([arc, l_top, l_out, l_bot])

    surface = occ.addPlaneSurface([outer_loop, airfoil_loop])
    occ.synchronize()

    # --- 3. Capa límite (Boundary Layer field) sobre la superficie del perfil ---
    bl_field = gmsh.model.mesh.field.add("BoundaryLayer")
    gmsh.model.mesh.field.setNumbers(bl_field, "CurvesList", airfoil_curves)
    gmsh.model.mesh.field.setNumber(bl_field, "hwall_n", y1)
    gmsh.model.mesh.field.setNumber(bl_field, "ratio", growth_rate)
    gmsh.model.mesh.field.setNumber(bl_field, "thickness", y1 * (growth_rate ** n_layers))
    gmsh.model.mesh.field.setNumber(bl_field, "Quads", 1)
    gmsh.model.mesh.field.setAsBoundaryLayer(bl_field)

    # --- 4. Tamaños de malla: fino en el perfil, creciendo hacia el far-field ---
    dist_field = gmsh.model.mesh.field.add("Distance")
    gmsh.model.mesh.field.setNumbers(dist_field, "CurvesList", airfoil_curves)
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

    # --- 5. Generar malla 2D y extruir 1 celda en z (pseudo-2D para OpenFOAM) ---
    gmsh.model.mesh.generate(2)

    ext = occ.extrude(
        [(2, surface)], 0, 0, extrude_z, numElements=[1], recombine=True
    )
    occ.synchronize()
    gmsh.model.mesh.generate(3)

    # --- 6. Grupos físicos: nombres de patch que gmshToFoam va a respetar ---
    vol_tag = [e[1] for e in ext if e[0] == 3][0]
    gmsh.model.addPhysicalGroup(3, [vol_tag], name="internal")

    # OJO: los tags de superficies laterales del extrude dependen del orden de
    # curvas del loop exterior + perfil; revisa con gmsh.model.getEntities(2)
    # y ajusta estos nombres a tu caso si tu contorno exterior tiene otro orden.
    surf_entities = [e for e in ext if e[0] == 2]
    print("Superficies generadas por el extrude (revisar antes de nombrar patches):")
    for e in surf_entities:
        print("  ", e)

    gmsh.option.setNumber("Mesh.SaveAll", 0)
    gmsh.option.setNumber("Mesh.MshFileVersion", 2.2)
    gmsh.write(out_path)
    gmsh.finalize()
    print(f"\nMalla escrita en: {out_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dat", required=True, help="Archivo .dat del perfil (formato Selig)")
    ap.add_argument("--out", required=True, help="Archivo .msh de salida")
    ap.add_argument("--farfield", type=float, default=20.0, help="Radio del far-field en cuerdas (default 20)")
    ap.add_argument("--wake", type=float, default=25.0, help="Longitud del dominio aguas abajo en cuerdas (default 25)")
    ap.add_argument("--yplus-height", type=float, default=1e-5, dest="y1",
                     help="Altura de la primera celda junto a la pared (y1), en cuerdas")
    ap.add_argument("--layers", type=int, default=25, help="Número de capas de la capa límite")
    ap.add_argument("--growth", type=float, default=1.2, help="Razón de crecimiento de la capa límite")
    ap.add_argument("--extrude-z", type=float, default=0.1, help="Espesor de extrusión en z (pseudo-2D)")
    ap.add_argument("--min-spacing", type=float, default=5e-4,
                     help="Distancia mínima entre puntos consecutivos del perfil (fracción de cuerda)")
    ap.add_argument("--te-size", type=float, default=0.004,
                     help="Tamaño de malla junto al perfil, en cuerdas (default 0.004; bájalo solo si necesitas capturar más detalle geométrico ahí)")
    ap.add_argument("--le-size", type=float, default=0.004,
                     help="Tamaño de malla en los puntos del perfil, en cuerdas")
    ap.add_argument("--farfield-size", type=float, default=1.5,
                     help="Tamaño de malla en el far-field, en cuerdas (default 1.5)")
    args = ap.parse_args()

    build_mesh(
        args.dat, args.out,
        farfield_radius=args.farfield,
        wake_length=args.wake,
        y1=args.y1,
        n_layers=args.layers,
        growth_rate=args.growth,
        extrude_z=args.extrude_z,
        min_spacing=args.min_spacing,
        te_size=args.te_size,
        le_size=args.le_size,
        farfield_size=args.farfield_size,
    )


if __name__ == "__main__":
    main()
