#!/usr/bin/env python3
"""
build_dynamic_move_case.py

Paso 2 del roadmap dinámico: arma un caso OpenFOAM para validar SOLO el
movimiento de malla (utilidad `moveDynamicMesh`, sin resolver flujo) con el
flap rotando según una rampa suave (coseno elevado) alrededor de la bisagra.

Entrada: una malla ya convertida a OpenFOAM (carpeta con constant/polyMesh,
generada con convert_mesh.sh a partir de la malla con gap de
naca_mesh_gmsh_dynamic.py).

IMPORTANTE -- escalamiento del tiempo:
La malla está en unidades de cuerda (cuerda = 1 <-> chord_real metros) pero
se usa la velocidad real (m/s) y nu_malla = nu_real/chord_real. Para que las
ecuaciones de Navier-Stokes sean semejantes, el tiempo de OpenFOAM debe ser
    t_OF = t_real / chord_real
Por eso este script recibe los tiempos en segundos REALES y los convierte.

Convención de signo: delta positivo = flap hacia abajo (igual que en toda la
campaña estática) = giro horario visto en el plano x-y = rotación NEGATIVA
alrededor de +z. Por eso yaw = -delta (ver --yaw-sign si la verificación con
check_flap_motion.py indicara lo contrario).

Uso:
    python build_dynamic_move_case.py --mesh-case mesh_case_gap \
        --delta-target 10 --t-actuation-real 0.05 --t-hold-real 0.05 \
        --chord-real 0.2 --hinge 0.7 --gap 0.01 --out move_test_d10
"""

import argparse
import math
import os
import shutil

import numpy as np


# ---------------------------------------------------------------- geometría
def naca_half_thickness(x, t=0.12):
    return 5 * t * (
        0.2969 * math.sqrt(x) - 0.1260 * x - 0.3516 * x**2
        + 0.2843 * x**3 - 0.1015 * x**4
    )


def corner_clearance(delta_deg, hinge, gap, naca_t=0.12):
    """
    Holgura horizontal mínima entre las esquinas de la cara frontal del flap
    (rotadas delta_deg alrededor de la bisagra) y el plano de la cara
    trasera del mainfoil (x = hinge - gap/2). Devuelve (holgura, fraccion
    del gap original). Si la fracción llega a 0 o negativa, el flap choca
    con el mainfoil.
    """
    xm = hinge - gap / 2
    xf = hinge + gap / 2
    tf = naca_half_thickness(xf, naca_t)
    d = math.radians(delta_deg)
    c, s = math.cos(d), math.sin(d)
    clear = []
    for y0 in (+tf, -tf):
        dx, dy = xf - hinge, y0
        x_new = hinge + dx * c + dy * s  # misma convención que la geometría estática
        clear.append(x_new - xm)
    m = min(clear)
    return m, m / gap


# ---------------------------------------------------- tabla de movimiento
def flap_motion_table(delta_deg, T_of, hold_of, n_ramp=100, yaw_sign=-1.0):
    """Lista de (t_OF, yaw_deg): rampa coseno 0 -> delta en T_of, luego
    mantiene delta durante hold_of, y un punto final lejano (la función de
    movimiento de OpenFOAM da error si el tiempo de simulación sale del
    rango de la tabla)."""
    rows = []
    for i in range(n_ramp + 1):
        t = T_of * i / n_ramp
        ang = delta_deg * 0.5 * (1 - math.cos(math.pi * i / n_ramp))
        rows.append((t, yaw_sign * ang))
    t_total = T_of + hold_of
    for k in range(1, 5):
        rows.append((T_of + hold_of * k / 4, yaw_sign * delta_deg))
    rows.append((2 * t_total + 1.0, yaw_sign * delta_deg))  # margen de seguridad
    return rows


def write_motion_table(path, rows):
    with open(path, "w") as f:
        f.write("// (tiempo_OF ((surge sway heave) (roll pitch yaw)))  -- traslacion en m, rotacion en GRADOS\n")
        f.write("// Valores TOTALES (no incrementales). Rotacion alrededor de z = yaw.\n")
        f.write("(\n")
        for t, yaw in rows:
            f.write(f"({t:.10g} ((0 0 0) (0 0 {yaw + 0.0:.10g})))\n")  # +0.0 evita "-0"
        f.write(")\n")


# ------------------------------------------------------------ plantillas
HEADER = """FoamFile
{{
    version     2.0;
    format      ascii;
    class       {cls};
    {loc}object      {obj};
}}
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //
"""


def hdr(cls, obj, location=None):
    loc = f'location    "{location}";\n    ' if location else ""
    return HEADER.format(cls=cls, obj=obj, loc=loc)


def dynamic_mesh_dict(exponent_quadratic=False):
    diff = "quadratic inverseDistance 1(flap)" if exponent_quadratic else "inverseDistance 1(flap)"
    return hdr("dictionary", "dynamicMeshDict", "constant") + f"""
dynamicFvMesh       dynamicMotionSolverFvMesh;

motionSolverLibs    ("libfvMotionSolvers.so");

// v2012 acepta 'motionSolver' (y 'solver' como alias antiguo); se dejan los
// dos para maximizar compatibilidad -- el que sobre se ignora.
motionSolver        displacementLaplacian;
solver              displacementLaplacian;

displacementLaplacianCoeffs
{{
    // Cerca del flap (patch que se mueve) la malla es "rigida" y sigue al
    // flap; lejos del flap absorbe la deformacion.
    diffusivity     {diff};
}}

// ************************************************************************* //
"""


def point_displacement(hinge):
    return hdr("pointVectorField", "pointDisplacement") + f"""
dimensions      [0 1 0 0 0 0 0];

internalField   uniform (0 0 0);

boundaryField
{{
    flap
    {{
        type            solidBodyMotionDisplacement;
        solidBodyMotionFunction tabulated6DoFMotion;
        tabulated6DoFMotionCoeffs
        {{
            CofG            ({hinge:.10g} 0 0);     // bisagra (z es irrelevante: giro alrededor de z)
            timeDataFileName "$FOAM_CASE/constant/flapMotion.dat";
        }}
    }}

    mainfoil
    {{
        type            fixedValue;
        value           uniform (0 0 0);
    }}

    farfield
    {{
        type            fixedValue;
        value           uniform (0 0 0);
    }}

    outlet
    {{
        type            fixedValue;
        value           uniform (0 0 0);
    }}

    front
    {{
        type            empty;
    }}

    back
    {{
        type            empty;
    }}
}}

// ************************************************************************* //
"""


def control_dict(t_end, dt, write_interval):
    return hdr("dictionary", "controlDict", "system") + f"""
application     moveDynamicMesh;

startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         {t_end:.10g};

deltaT          {dt:.10g};

writeControl    timeStep;
writeInterval   {write_interval};

writeFormat     ascii;
writePrecision  10;
timeFormat      general;
timePrecision   8;

runTimeModifiable false;

// ************************************************************************* //
"""


FV_SCHEMES = hdr("dictionary", "fvSchemes", "system") + """
ddtSchemes          { default steadyState; }
gradSchemes         { default Gauss linear; }
divSchemes          { default none; }
laplacianSchemes    { default Gauss linear corrected; }
interpolationSchemes{ default linear; }
snGradSchemes       { default corrected; }

// ************************************************************************* //
"""

FV_SOLUTION = hdr("dictionary", "fvSolution", "system") + """
solvers
{
    "cellDisplacement.*"
    {
        solver          PCG;
        preconditioner  DIC;
        tolerance       1e-10;
        relTol          0;
        maxIter         500;
    }
}

// ************************************************************************* //
"""


def build_case(args):
    if os.path.exists(args.out):
        raise FileExistsError(f"{args.out} ya existe -- bórralo o elige otro nombre")
    src_mesh = os.path.join(args.mesh_case, "constant", "polyMesh")
    if not os.path.isdir(src_mesh):
        raise FileNotFoundError(f"No encuentro {src_mesh} (¿corriste convert_mesh.sh?)")

    # tiempos reales -> tiempos de OpenFOAM
    T_of = args.t_actuation_real / args.chord_real
    hold_of = args.t_hold_real / args.chord_real
    t_total = T_of + hold_of
    dt = t_total / args.n_steps
    write_interval = max(1, args.n_steps // args.n_writes)

    os.makedirs(os.path.join(args.out, "constant"))
    os.makedirs(os.path.join(args.out, "system"))
    os.makedirs(os.path.join(args.out, "0"))
    shutil.copytree(src_mesh, os.path.join(args.out, "constant", "polyMesh"))

    rows = flap_motion_table(args.delta_target, T_of, hold_of, args.n_ramp, args.yaw_sign)
    write_motion_table(os.path.join(args.out, "constant", "flapMotion.dat"), rows)

    with open(os.path.join(args.out, "constant", "dynamicMeshDict"), "w") as f:
        f.write(dynamic_mesh_dict(args.quadratic))
    with open(os.path.join(args.out, "0", "pointDisplacement"), "w") as f:
        f.write(point_displacement(args.hinge))
    with open(os.path.join(args.out, "system", "controlDict"), "w") as f:
        f.write(control_dict(t_total, dt, write_interval))
    with open(os.path.join(args.out, "system", "fvSchemes"), "w") as f:
        f.write(FV_SCHEMES)
    with open(os.path.join(args.out, "system", "fvSolution"), "w") as f:
        f.write(FV_SOLUTION)

    # ------------- resumen y avisos
    omega_real = math.radians(args.delta_target) / args.t_actuation_real
    print(f"Caso de movimiento de malla escrito en: {args.out}")
    print(f"  delta objetivo      = {args.delta_target:+.2f} deg (positivo = flap hacia abajo)")
    print(f"  T actuacion         = {args.t_actuation_real} s reales  ->  {T_of:.6g} en tiempo OpenFOAM")
    print(f"  T mantencion        = {args.t_hold_real} s reales  ->  {hold_of:.6g} en tiempo OpenFOAM")
    print(f"  tiempo total (OF)   = {t_total:.6g}   deltaT = {dt:.6g}  ({args.n_steps} pasos)")
    print(f"  escritura cada {write_interval} pasos -> tiempos: "
          + ", ".join(f"{k * write_interval * dt:.4g}" for k in range(1, args.n_steps // write_interval + 1)))
    print(f"  velocidad angular media de la rampa ~ {math.degrees(omega_real):.1f} deg/s reales")

    clear, frac = corner_clearance(args.delta_target, args.hinge, args.gap, args.naca_t)
    print(f"  holgura de esquina al deflectar {args.delta_target:+.1f} deg: {clear:.5f} "
          f"({100 * frac:.0f}% del gap original de {args.gap})")
    if frac <= 0:
        print("  ¡¡ AVISO: el flap CHOCA con el mainfoil a esta deflexión (gap insuficiente) !!")
    elif frac < 0.3:
        print("  AVISO: queda menos del 30% del gap en el lado comprimido -- espera "
              "deterioro fuerte de la malla ahí; considera un gap mayor o un nariz redondeada.")
    theta_max = 2 * math.degrees(math.atan((args.gap / 2) / naca_half_thickness(args.hinge + args.gap / 2, args.naca_t)))
    print(f"  deflexion maxima teorica antes de chocar (cara plana, gap={args.gap}): {theta_max:.1f} deg")
    print("\nSiguiente paso (en WSL con OpenFOAM cargado):")
    print(f"  cd {args.out} && moveDynamicMesh | tee log.moveDynamicMesh")
    print("  checkMesh -allTime -allGeometry -allTopology | tee log.checkMesh_allTime")
    print(f"  python check_flap_motion.py --case . --time {t_total / 2:.6g} --hinge {args.hinge}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mesh-case", required=True, help="Carpeta con constant/polyMesh (malla con gap, ya convertida)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--delta-target", type=float, default=10.0, help="Deflexion final en grados (positivo = flap hacia abajo)")
    ap.add_argument("--t-actuation-real", type=float, default=0.05, help="Duracion de la rampa, en segundos REALES")
    ap.add_argument("--t-hold-real", type=float, default=0.05, help="Tiempo que se mantiene la deflexion final, segundos REALES")
    ap.add_argument("--chord-real", type=float, default=0.2, help="Cuerda real [m] (para escalar el tiempo)")
    ap.add_argument("--hinge", type=float, default=0.7)
    ap.add_argument("--gap", type=float, default=0.01, help="Gap usado al generar la geometria (solo para el aviso de holgura)")
    ap.add_argument("--naca-t", type=float, default=0.12)
    ap.add_argument("--n-steps", type=int, default=200)
    ap.add_argument("--n-writes", type=int, default=10)
    ap.add_argument("--n-ramp", type=int, default=100, help="Puntos de la tabla en la rampa")
    ap.add_argument("--yaw-sign", type=float, default=-1.0, help="-1: delta positivo = giro horario (flap abajo)")
    ap.add_argument("--quadratic", action="store_true", help="Usa 'quadratic inverseDistance' (malla mas rigida cerca del flap)")
    args = ap.parse_args()
    build_case(args)


if __name__ == "__main__":
    main()
