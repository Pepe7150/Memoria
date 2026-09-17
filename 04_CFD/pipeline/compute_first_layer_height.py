#!/usr/bin/env python3
"""
compute_first_layer_height.py

Estima la altura de la primera celda (y1) junto a la pared para lograr un
y+ objetivo, usando la correlación de placa plana turbulenta (Schlichting)
para el coeficiente de fricción. Es una estimación de orden de magnitud —
suficiente para dimensionar la malla antes de correr, no un cálculo exacto.

Como y1 depende de Re (y por lo tanto, en tu barrido, de Mach), calcula esto
para la condición de MAYOR Reynolds de tu barrido para ese delta: esa es la
que exige la celda más delgada. Usar ese y1 para todo el barrido de Mach/AoA
de un mismo delta es conservador (subestima y+ para los Re más bajos, lo
cual no es un problema) y te evita remallar por cada condición de flujo.

Uso:
    python compute_first_layer_height.py --u 60 --c 0.3 --nu 1.5e-5 --yplus 1
"""

import argparse


def reynolds(u, c, nu):
    return u * c / nu


def skin_friction_flat_plate(Re_c):
    """Correlación simple de placa plana turbulenta (válida Re ~5e5-1e7)."""
    return 0.058 * Re_c ** (-0.2)


def first_layer_height(u, c, nu, rho, yplus_target=1.0):
    Re_c = reynolds(u, c, nu)
    cf = skin_friction_flat_plate(Re_c)
    tau_w = cf * 0.5 * rho * u ** 2
    u_tau = (tau_w / rho) ** 0.5
    y1 = yplus_target * nu / u_tau
    return y1, Re_c, cf, u_tau


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--u", type=float, required=True, help="Velocidad freestream [m/s]")
    ap.add_argument("--c", type=float, required=True, help="Cuerda [m]")
    ap.add_argument("--nu", type=float, default=1.5e-5, help="Viscosidad cinemática [m^2/s] (default: aire a nivel del mar, ~1.5e-5)")
    ap.add_argument("--rho", type=float, default=1.225, help="Densidad [kg/m^3] (default: aire ISA nivel del mar)")
    ap.add_argument("--yplus", type=float, default=1.0, help="y+ objetivo en la primera celda (default: 1.0)")
    args = ap.parse_args()

    y1, Re_c, cf, u_tau = first_layer_height(args.u, args.c, args.nu, args.rho, args.yplus)

    print(f"Re_c        = {Re_c:.3e}")
    print(f"Cf (placa)  = {cf:.5f}")
    print(f"u_tau       = {u_tau:.4f} m/s")
    print(f"y1 (y+={args.yplus:g}) = {y1:.4e} m  ->  {y1 / args.c:.4e} (fracción de cuerda)")


if __name__ == "__main__":
    main()
