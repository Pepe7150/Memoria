"""
consolidar_oppoints_xflr5.py

Lee todos los archivos .csv exportados desde XFLR5 en una carpeta (tanto
exportaciones de un solo Punto de Operacion -con el momento de flap
dimensional- como exportaciones de polar completo -barrido de alpha, sin
momento de flap-), y arma una tabla consolidada en Excel con:

  - alpha, delta (deflexion), Cm del ala completa, momento de flap [N.m]
  - Ch (coeficiente de momento de bisagra), calculado con q, Sf, cf
  - Una hoja "ancho" (alpha en filas, delta en columnas) para graficar rapido
  - Una hoja de verificacion cruzada Cm entre archivos de OpPoint y de polar

Proyecto: Banco de ensayos para dimensionamiento y caracterizacion de
actuadores de superficies de control basado en cargas CFD.

Caso: Simpson (2016), estabilizador NACA 0012 con flecha 45 grados,
elevador de 25% de cuerda -- caso de contingencia con perfil redondeado
y analisis viscoso (VLM2 + polares 2D), ver
04_CFD/01_Casos/02_Geometria_Simpson_NACA0012.md.

USO:
    1. En XFLR5, exporta cada Punto de Operacion (por cada combinacion
       alpha/delta) a un .csv, todos en la misma carpeta. El nombre del
       archivo no importa -- el script identifica alpha y delta leyendo
       el contenido del archivo, no el nombre.
    2. Opcionalmente, tambien puedes dejar en la misma carpeta los .csv
       de "export polar completo" (barrido de alpha, sin momento de flap)
       -- se usan solo para verificacion cruzada de Cm, no para el Ch.
    3. Ajusta los PARAMETROS mas abajo (densidad, cuerda, envergadura del
       flap) segun tu caso.
    4. Corre: python consolidar_oppoints_xflr5.py
    5. Genera: tabla_hinge_moment_simpson_naca0012.xlsx
"""

import re
import glob
import os
import pandas as pd
import numpy as np

# ==========================================================================
# PARAMETROS -- ajustar segun el caso (valores actuales: Simpson NACA 0012,
# estabilizador con flecha, elevador 25%, ver Geometria_Simpson_NACA0012.md)
# ==========================================================================

CARPETA_CSV = "."           # carpeta donde estan los .csv exportados
ARCHIVO_SALIDA = "tabla_hinge_moment_simpson_naca0012.xlsx"

# Resolver CARPETA_CSV y ARCHIVO_SALIDA respecto a la ubicacion del propio
# script (no respecto al directorio desde el que se invoque python), para
# que el script funcione igual sin importar desde donde se ejecute.
_DIR_SCRIPT = os.path.dirname(os.path.abspath(__file__))
if not os.path.isabs(CARPETA_CSV):
    CARPETA_CSV = os.path.join(_DIR_SCRIPT, CARPETA_CSV)
if not os.path.isabs(ARCHIVO_SALIDA):
    ARCHIVO_SALIDA = os.path.join(_DIR_SCRIPT, ARCHIVO_SALIDA)

RHO = 1.522                    # kg/m3 -- densidad usada en el analisis XFLR5
CUERDA = 0.381                 # m -- cuerda de la seccion (constante, sin taper)
CF_FRAC = 0.25                 # fraccion de cuerda del elevador (25%)
SEMISPAN = 0.8009              # m -- semi-envergadura (un solo lado, 31.53 in)

CF = CF_FRAC * CUERDA           # cuerda del flap [m]
SF = SEMISPAN * CF               # area de referencia del flap, un solo lado [m2]


# ==========================================================================
# LECTURA Y PARSEO
# ==========================================================================

def leer_texto(path):
    """Lee el archivo probando utf-8 y, si falla, latin-1 (XFLR5 exporta
    a veces con codificacion latin-1 por el simbolo de grado °)."""
    for enc in ("utf-8", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError(f"No se pudo leer {path} con utf-8 ni latin-1")


def extraer_delta(texto):
    """Busca un patron tipo 'delta_-7p8' o 'delta_1p7' en cualquier parte
    del archivo (nombre del Plane/Wing) y lo convierte a float.
    Si no encuentra el patron pero sí encuentra 'NACA0012' o 'NACA 0012'
    sin sufijo de deflexion, asume delta=0.0 (caso sin deflectar)."""
    m = re.search(r"delta_(-?)(\d+)p(\d+)", texto)
    if m:
        signo, entero, decimal = m.groups()
        valor = float(f"{entero}.{decimal}")
        return -valor if signo == "-" else valor

    if re.search(r"NACA\s*0012(?!.*delta)", texto):
        return 0.0

    return None


def es_archivo_oppoint(texto):
    """Un archivo de OpPoint individual tiene la linea 'Alpha = ,' -- el
    momento de flap puede estar o no (algunos casos, p.ej. sin flap
    definido, no lo tendran; se incluyen igual con Ch en blanco)."""
    return bool(re.search(r"^Alpha\s*=\s*,", texto, re.MULTILINE))


def es_archivo_polar(texto):
    """Un archivo de polar completo tiene el encabezado 'alpha, Beta, CL,...'."""
    return bool(re.search(r"^alpha\s*,\s*Beta\s*,\s*CL", texto, re.MULTILINE))


def parsear_oppoint(path):
    """Extrae alpha, Cm, QInf y todos los momentos de flap de un archivo
    de exportacion de un solo punto de operacion."""
    texto = leer_texto(path)
    delta = extraer_delta(texto)

    m_alpha = re.search(r"^Alpha\s*=\s*,\s*([-\d.eE]+)", texto, re.MULTILINE)
    alpha = float(m_alpha.group(1)) if m_alpha else None

    m_cm = re.search(r"^Cm\s*=,\s*([-\d.eE]+)", texto, re.MULTILINE)
    cm = float(m_cm.group(1)) if m_cm else None

    m_cl = re.search(r"^CL\s*=\s*,\s*([-\d.eE]+)", texto, re.MULTILINE)
    cl = float(m_cl.group(1)) if m_cl else None

    m_q = re.search(r"QInf\s*=,\s*([-\d.eE]+)", texto)
    qinf = float(m_q.group(1)) if m_q else None

    flaps = re.findall(
        r"([A-Za-z][\w ]*?)\s*,\s*(\d+)\s*,\s*moment\s*=\s*,\s*([-\d.eE]+)\s*N\.m",
        texto,
    )
    # flaps: lista de tuplas (etiqueta, indice, valor)
    flap_valores = [float(v) for (_, _, v) in flaps]

    return {
        "archivo": os.path.basename(path),
        "delta": delta,
        "alpha": alpha,
        "Cm_oppoint": cm,
        "CL_oppoint": cl,
        "QInf": qinf,
        "n_flaps_encontrados": len(flap_valores),
        "flap_moment_Nm": flap_valores[0] if flap_valores else None,
        "flaps_coinciden": (
            len(set(round(v, 4) for v in flap_valores)) == 1
            if flap_valores
            else None
        ),
        "flap_valores_todos": flap_valores,
    }


def parsear_polar(path):
    """Extrae la tabla alpha/Cm de un archivo de polar completo (barrido),
    solo para verificacion cruzada -- no trae momento de flap."""
    texto = leer_texto(path)
    delta = extraer_delta(texto)

    # localizar la fila de encabezado y leer con pandas desde ahi
    lineas = texto.splitlines()
    idx_header = next(
        i for i, l in enumerate(lineas) if l.strip().lower().startswith("alpha,")
    )
    from io import StringIO

    sub_csv = "\n".join(lineas[idx_header:])
    df = pd.read_csv(StringIO(sub_csv))
    df.columns = [c.strip() for c in df.columns]
    df["delta"] = delta
    df["archivo"] = os.path.basename(path)
    return df[["archivo", "delta", "alpha", "Cm", "CL"]].rename(
        columns={"Cm": "Cm_polar", "CL": "CL_polar"}
    )


# ==========================================================================
# PROCESAMIENTO PRINCIPAL
# ==========================================================================

def main():
    archivos = glob.glob(os.path.join(CARPETA_CSV, "*.csv"))
    if not archivos:
        print(f"No se encontraron .csv en: {CARPETA_CSV}")
        print("(ruta absoluta resuelta -- revisa que la carpeta exista y tenga los .csv)")
        return

    filas_oppoint = []
    filas_polar = []

    for path in archivos:
        texto = leer_texto(path)
        if es_archivo_oppoint(texto):
            filas_oppoint.append(parsear_oppoint(path))
        elif es_archivo_polar(texto):
            filas_polar.append(parsear_polar(path))
        else:
            print(f"  [omitido] {os.path.basename(path)} -- formato no reconocido")

    if not filas_oppoint:
        print("No se encontraron archivos de OpPoint con momento de flap.")
        print("Revisa que hayas exportado los Puntos de Operacion individuales,")
        print("no solo el polar completo (el polar completo no trae el momento).")
        return

    df = pd.DataFrame(filas_oppoint)

    # Calcular Ch = H / (q * Sf * cf)
    df["q_Pa"] = 0.5 * RHO * df["QInf"] ** 2
    df["Ch"] = df["flap_moment_Nm"] / (df["q_Pa"] * SF * CF)

    df = df.sort_values(["delta", "alpha"]).reset_index(drop=True)

    # Advertencias de sanidad
    n_incons = (df["flaps_coinciden"] == False).sum()  # noqa: E712
    if n_incons > 0:
        print(f"ADVERTENCIA: {n_incons} archivo(s) con momentos de flap "
              f"distintos entre lados (revisar si hay beta o deflexion diferencial).")

    faltantes = df["flap_moment_Nm"].isna().sum()
    if faltantes > 0:
        print(f"\nADVERTENCIA: {faltantes} archivo(s) SIN momento de flap detectado")
        print("(se incluyen en la tabla con Ch en blanco). Archivos:")
        for _, fila in df[df["flap_moment_Nm"].isna()].iterrows():
            print(f"  - {fila['archivo']}  (delta={fila['delta']}, alpha={fila['alpha']})")
        print("Si esperabas momento de flap en estos casos, revisa en XFLR5 que")
        print("el objeto 'Flap' este definido en ese Wing antes de exportar.\n")

    # Hoja "ancho": alpha en filas, delta en columnas, valor = Ch
    tabla_ancha = df.pivot_table(index="alpha", columns="delta", values="Ch")

    # Verificacion cruzada de Cm contra los archivos de polar, si existen
    df_check = None
    if filas_polar:
        df_polar = pd.concat(filas_polar, ignore_index=True)
        df_check = df.merge(
            df_polar[["delta", "alpha", "Cm_polar"]],
            on=["delta", "alpha"],
            how="left",
        )
        df_check["Cm_diff"] = (df_check["Cm_oppoint"] - df_check["Cm_polar"]).abs()

    # Exportar a Excel con varias hojas
    with pd.ExcelWriter(ARCHIVO_SALIDA, engine="openpyxl") as writer:
        cols_principal = [
            "delta", "alpha", "flap_moment_Nm", "Ch", "Cm_oppoint",
            "CL_oppoint", "QInf", "n_flaps_encontrados", "flaps_coinciden", "archivo",
        ]
        df[cols_principal].to_excel(writer, sheet_name="Datos (largo)", index=False)
        tabla_ancha.to_excel(writer, sheet_name="Ch (ancho, alpha x delta)")
        if df_check is not None:
            df_check.to_excel(writer, sheet_name="Verificacion Cm", index=False)

    print(f"\nArchivos de OpPoint procesados: {len(df)}")
    print(f"Archivos de polar (solo verificacion): {len(filas_polar)}")
    print(f"Tabla generada: {ARCHIVO_SALIDA}")
    print("\nResumen (Ch por caso):")
    print(df[["delta", "alpha", "Ch"]].to_string(index=False))


if __name__ == "__main__":
    main()
