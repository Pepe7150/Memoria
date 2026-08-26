"""
consolidar_polares_2D_gaw1.py

Consolida los polares 2D exportados desde XFLR5 (Direct Foil Design, GA(W)-1
con flap) en una tabla unica, en formato largo. A diferencia del caso NACA
0012 (3D, OpPoint individuales), aca cada archivo .csv es un POLAR COMPLETO
(barrido de alpha) que ya trae Chinge calculado internamente por XFLR5 --
no hace falta recalcular Ch = flap_moment / (q * Sf * cf).

Proyecto: Banco de ensayos para dimensionamiento y caracterizacion de
actuadores de superficies de control basado en cargas CFD.

Caso: Simpson (2016), GA(W)-1, flap 20% de cuerda, x_h/c=0.80, y_h/c=0.03443,
Re=2.2e6, M=0.13 -- ver 04_CFD/00_XFLR5/.../02_Checklist_Simpson_GAW1.md

FORMATO DE ENTRADA ESPERADO (un archivo por deflexion, ej. exportado por
XFLR5 con nombre tipo T1_Re2_200_M0_13_N9_0.csv):

    xflr5 v6.61
    <linea en blanco>
     Calculated polar for: GA(W)-1 -10p0
    <linea en blanco>
     1 1 Reynolds number fixed          Mach number fixed
    <linea en blanco>
     xtrf =   1.000 (top)        1.000 (bottom)
     Mach =   0.130     Re =     2.200 e 6     Ncrit =   9.000
    <linea en blanco>
    alpha,CL,CD,CDp,Cm,Top Xtr,Bot Xtr,Cpmin,Chinge,XCp
     -8.000, 0.1678, ...

La deflexion (delta) se identifica leyendo la linea "Calculated polar for:",
NO el nombre del archivo -- el nombre de archivo (p.ej. el que exporta
XFLR5 automaticamente) no necesariamente contiene la deflexion.

USO:
    1. Deja todos los .csv de polares GA(W)-1 (uno por deflexion) en la
       misma carpeta que este script (o ajusta CARPETA_CSV).
    2. Corre: python consolidar_polares_2D_gaw1.py
    3. Genera: tabla_hinge_moment_simpson_gaw1.xlsx
"""

import re
import glob
import os
from io import StringIO

import pandas as pd

# ==========================================================================
# PARAMETROS
# ==========================================================================

CARPETA_CSV = "."
ARCHIVO_SALIDA = "tabla_hinge_moment_simpson_gaw1.xlsx"

_DIR_SCRIPT = os.path.dirname(os.path.abspath(__file__))
if not os.path.isabs(CARPETA_CSV):
    CARPETA_CSV = os.path.join(_DIR_SCRIPT, CARPETA_CSV)
if not os.path.isabs(ARCHIVO_SALIDA):
    ARCHIVO_SALIDA = os.path.join(_DIR_SCRIPT, ARCHIVO_SALIDA)

# Matriz esperada (Simpson 2016, GA(W)-1) -- solo para el chequeo de
# completitud al final; no filtra los datos leidos.
ALPHAS_ESPERADOS = [-8.0, 0.0, 8.0, 12.0, 16.0, 20.0]
DELTAS_ESPERADOS = [-40.0, -20.0, -10.0, -5.0, 0.0, 5.0, 10.0, 20.0, 40.0]


# ==========================================================================
# LECTURA Y PARSEO
# ==========================================================================

def leer_texto(path):
    for enc in ("utf-8", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError(f"No se pudo leer {path} con utf-8 ni latin-1")


def es_archivo_polar_2d_gaw1(texto):
    """Identifica un polar 2D de perfil (con Chinge), a diferencia del
    formato OpPoint (Alpha = ,) y del formato polar 3D (alpha, Beta, CL,...)."""
    tiene_header_2d = bool(
        re.search(r"^alpha\s*,\s*CL\s*,\s*CD", texto, re.MULTILINE)
    )
    tiene_chinge = "Chinge" in texto
    return tiene_header_2d and tiene_chinge


def extraer_delta(texto):
    """Lee la deflexion desde la linea 'Calculated polar for: <perfil> <delta>'.
    Acepta deltas tipo '-10p0', '10p0', '0p0', con o sin signo."""
    m = re.search(
        r"Calculated polar for:.*?(-?\d+p\d+)\s*$", texto, re.MULTILINE
    )
    if not m:
        return None
    token = m.group(1)
    signo = -1.0 if token.startswith("-") else 1.0
    token = token.lstrip("-")
    entero, decimal = token.split("p")
    return signo * float(f"{entero}.{decimal}")


def extraer_condicion(texto):
    """Extrae Mach, Re y Ncrit del encabezado, solo para dejar constancia
    en la tabla consolidada (verificacion de que todos los archivos
    comparten la misma condicion de vuelo)."""
    m_mach = re.search(r"Mach\s*=\s*([\d.]+)", texto)
    m_re = re.search(r"Re\s*=\s*([\d.]+)\s*e\s*([\d.]+)", texto)
    m_ncrit = re.search(r"Ncrit\s*=\s*([\d.]+)", texto)

    mach = float(m_mach.group(1)) if m_mach else None
    if m_re:
        re_val = float(m_re.group(1)) * (10 ** float(m_re.group(2)))
    else:
        re_val = None
    ncrit = float(m_ncrit.group(1)) if m_ncrit else None
    return mach, re_val, ncrit


def parsear_polar_2d(path):
    """Lee la tabla alpha/CL/CD/Cm/Chinge de un polar 2D completo.

    NOTA SOBRE EL FORMATO: en las exportaciones reales de XFLR5 v6.61
    (polar 2D de perfil con flap) el encabezado declara 10 nombres de
    columna:
        alpha,CL,CD,CDp,Cm,Top Xtr,Bot Xtr,Cpmin,Chinge,XCp
    pero cada fila de datos trae 12 valores. Se confirmo manualmente
    (comparando contra el grafico Chinge vs alpha dentro de XFLR5) que:
      - Las primeras 8 columnas coinciden 1:1 con los primeros 8 nombres
        del encabezado (alpha, CL, CD, CDp, Cm, Top Xtr, Bot Xtr, Cpmin).
      - La 9na columna es Chinge (confirmado).
      - Las columnas 10 y 11 son dos campos adicionales sin nombre en el
        encabezado, de contenido no relevante para este proyecto (no se
        usan y se descartan explicitamente, no se interpretan ni se
        exportan).
      - La 12va y ultima columna corresponde a XCp.
    Esta asignacion posicional fija (no por nombre de encabezado) es
    necesaria porque pandas, leyendo por nombre con un encabezado de 10
    campos y filas de 12 valores, desplaza las columnas silenciosamente.
    """
    texto = leer_texto(path)
    delta = extraer_delta(texto)
    mach, re_val, ncrit = extraer_condicion(texto)

    lineas = texto.splitlines()
    idx_header = next(
        i for i, l in enumerate(lineas)
        if l.strip().lower().startswith("alpha,")
    )

    # Mapeo posicional fijo, confirmado manualmente contra XFLR5 (ver
    # docstring). Las posiciones 10 y 11 (0-index 9 y 10) se descartan.
    NOMBRES_POSICIONALES = [
        "alpha", "CL", "CD", "CDp", "Cm", "Top Xtr", "Bot Xtr", "Cpmin",
        "Chinge", "_ignorar_1", "_ignorar_2", "XCp",
    ]

    filas_datos = [l for l in lineas[idx_header + 1:] if l.strip()]
    n_esperado = len(NOMBRES_POSICIONALES)
    for l in filas_datos:
        n_campos = len(l.split(","))
        if n_campos != n_esperado:
            raise ValueError(
                f"\n[ERROR] En {os.path.basename(path)}: se esperaban "
                f"{n_esperado} campos por fila (mapeo posicional ya "
                f"confirmado), pero una fila trae {n_campos}. Revisa si "
                f"cambio el formato de exportacion de XFLR5 antes de "
                f"continuar:\n  {l.strip()}"
            )

    sub_csv = "\n".join(filas_datos)
    df = pd.read_csv(StringIO(sub_csv), header=None,
                      names=NOMBRES_POSICIONALES)
    df = df.drop(columns=["_ignorar_1", "_ignorar_2"])

    df["delta"] = delta
    df["Mach"] = mach
    df["Re"] = re_val
    df["Ncrit"] = ncrit
    df["archivo"] = os.path.basename(path)

    cols = ["archivo", "delta", "alpha", "Chinge", "Cm", "CL", "CD",
            "Mach", "Re", "Ncrit"]
    cols = [c for c in cols if c in df.columns]
    return df[cols]


# ==========================================================================
# PROCESAMIENTO PRINCIPAL
# ==========================================================================

def main():
    archivos = glob.glob(os.path.join(CARPETA_CSV, "*.csv"))
    if not archivos:
        print(f"No se encontraron .csv en: {CARPETA_CSV}")
        return

    # --- Conversion a convencion Wentz/NACA (Ch = H/(q*Sf*cf)) ---
    # Confirmado empiricamente (ver justificacion en el chat del proyecto,
    # comparacion contra Simpson 2016 Tabla 3.7 en alpha=0/delta=0):
    #   1) XFLR5 exporta Chinge con signo invertido respecto a Wentz/NACA.
    #   2) XFLR5 normaliza Chinge con la cuerda completa (c^2) en vez de
    #      la referencia de flap (Sf*cf) -> factor de correccion (c/cf)^2.
    # Validado con buena precision (~0.5% de error) SOLO en delta pequeno
    # (delta=0 en alpha=0). Para |delta| grande (>=20 deg aprox.) la
    # conversion se degrada e incluso invierte el signo respecto a los
    # valores de Simpson -- esto es coherente con la limitacion ya
    # documentada en 02_Checklist_Simpson_GAW1.md (separacion de flujo no
    # resuelta por XFoil a deflexion grande), no un error de esta formula.
    # NO tratar Ch_estandar como confiable fuera de |delta| pequeno sin
    # verificacion adicional.
    CF_SOBRE_C = 0.20  # cuerda del flap / cuerda total (GA(W)-1, Simpson)
    FACTOR_CONVERSION = (1.0 / CF_SOBRE_C) ** 2  # = 25

    filas = []
    for path in archivos:
        texto = leer_texto(path)
        if es_archivo_polar_2d_gaw1(texto):
            df_i = parsear_polar_2d(path)
            if df_i["delta"].isna().all():
                print(f"  [ADVERTENCIA] no se pudo leer delta en: "
                      f"{os.path.basename(path)} -- revisa la linea "
                      f"'Calculated polar for:' del archivo")
            filas.append(df_i)
        else:
            print(f"  [omitido] {os.path.basename(path)} -- no es un polar "
                  f"2D con Chinge (revisa que sea Direct Foil Design, no "
                  f"OpPoint ni polar de Wing/Plane)")

    if not filas:
        print("No se encontraron polares 2D validos con columna Chinge.")
        return

    df = pd.concat(filas, ignore_index=True)
    df = df.sort_values(["delta", "alpha"]).reset_index(drop=True)
    df["Ch_estandar_NACA_Wentz"] = -FACTOR_CONVERSION * df["Chinge"]

    # Verificacion de condicion de vuelo consistente entre archivos
    for campo in ("Mach", "Re", "Ncrit"):
        valores = df[campo].dropna().unique()
        if len(valores) > 1:
            print(f"  [ADVERTENCIA] {campo} no es constante entre archivos: "
                  f"{valores}")

    # Chequeo de completitud frente a la matriz de Simpson (§4.2 del
    # checklist) -- no descarta nada, solo informa que falta.
    deltas_leidos = set(df["delta"].dropna().unique())
    faltantes_delta = [d for d in DELTAS_ESPERADOS if d not in deltas_leidos]
    if faltantes_delta:
        print(f"  [INFO] deflexiones de la matriz aun no presentes: "
              f"{faltantes_delta}")

    for delta in sorted(deltas_leidos):
        alphas_leidos = set(
            df.loc[df["delta"] == delta, "alpha"].round(3)
        )
        faltantes_alpha = [
            a for a in ALPHAS_ESPERADOS if a not in alphas_leidos
        ]
        if faltantes_alpha:
            print(f"  [INFO] delta={delta}: alpha sin convergencia o "
                  f"sin correr: {faltantes_alpha}")

    # Hoja "ancho": alpha en filas, delta en columnas, valor = Chinge (crudo
    # de XFLR5) y otra hoja igual pero con la conversion a Ch_estandar
    tabla_ancha_crudo = df.pivot_table(index="alpha", columns="delta",
                                        values="Chinge")
    tabla_ancha_estandar = df.pivot_table(index="alpha", columns="delta",
                                           values="Ch_estandar_NACA_Wentz")

    with pd.ExcelWriter(ARCHIVO_SALIDA, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Datos (largo)", index=False)
        tabla_ancha_crudo.to_excel(writer, sheet_name="Chinge XFLR5 (crudo)")
        tabla_ancha_estandar.to_excel(writer, sheet_name="Ch estandar (NACA)")

    print(f"\nArchivos procesados: {len(filas)}")
    print(f"Puntos totales: {len(df)}")
    print(f"Tabla generada: {ARCHIVO_SALIDA}")
    print("\nResumen (Chinge por caso):")
    print(df[["delta", "alpha", "Chinge"]].to_string(index=False))


if __name__ == "__main__":
    main()
