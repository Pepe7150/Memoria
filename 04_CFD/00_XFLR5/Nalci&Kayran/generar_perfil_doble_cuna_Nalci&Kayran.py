"""
generar_perfil_doble_cuna.py

Genera archivos de coordenadas (.dat, formato Selig) de un perfil DOBLE CUÑA
(diamante) simétrico, para importar en XFLR5 (Direct Foil Design -> Load foil).

Proyecto: Banco de ensayos para dimensionamiento y caracterización de
actuadores de superficies de control basado en cargas CFD.

Geometría de referencia (Nalci & Kayran, 2014 / METU thesis, Nalci 2013):
  - Cuerda de raíz:  156 mm  -> espesor raíz  ~4.0 mm  -> t/c_raiz ~2.56%
  - Cuerda de punta:  78 mm  -> espesor punta ~2.2 mm  -> t/c_punta ~2.82%
  (ver 04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md)

El perfil se genera NORMALIZADO (cuerda = 1), que es la convención esperada
por XFLR5: el escalado real (cuerda de raíz/punta, envergadura) se define
después en el módulo "Wing and Plane Design", no en el archivo de perfil.

Nota importante:
  Este perfil tiene borde de ataque y de fuga agudos. El análisis viscoso
  de XFoil (dentro de XFLR5) muy probablemente NO convergerá bien en este
  tipo de perfil (predice separación inmediata en el LE agudo). Para el
  objetivo de "valores de referencia de flujo potencial", se recomienda
  usar el análisis INVISCID de XFLR5 (paneles), no la polar viscosa.

Uso:
    python generar_perfil_doble_cuna.py

Genera, en el mismo directorio:
    aleta_raiz.dat
    aleta_punta.dat

Y opcionalmente (si se pide), una figura de verificación con matplotlib.
"""

import numpy as np


# ==========================================================================
# PARÁMETROS — modificar aquí si cambian las hipótesis geométricas
# ==========================================================================

# Espesor relativo t/c de cada sección (adimensional, cuerda = 1)
TC_RAIZ = 4.0 / 156.0     # ~0.0256  (2.56%)
TC_PUNTA = 2.2 / 78.0     # ~0.0282  (2.82%)

# Posición del espesor máximo (x/c), medida desde el borde de ataque.
# 0.5 = doble cuña simétrico clásico (dos rampas de igual longitud).
X_TMAX = 0.5

# Número de paneles por superficie (más puntos = geometría más suave,
# pero el doble cuña es lineal a trozos, así que con pocos puntos basta
# para representar la forma EXACTA; se usa espaciado coseno solo para
# tener más resolución cerca de LE/TE si luego se desea suavizar esquinas).
N_PUNTOS_POR_SUPERFICIE = 80

# Nombre de archivo de salida
ARCHIVO_RAIZ = "aleta_raiz.dat"
ARCHIVO_PUNTA = "aleta_punta.dat"


# ==========================================================================
# GENERACIÓN DE COORDENADAS
# ==========================================================================

def distribucion_x(n, x_quiebre):
    """
    Genera una distribución de x/c entre 0 y 1, con espaciado coseno
    (más denso cerca de LE y TE) y garantizando que el punto de quiebre
    (x_tmax) esté exactamente incluido en la lista.
    """
    beta = np.linspace(0, np.pi, n)
    x = 0.5 * (1 - np.cos(beta))  # espaciado coseno en [0, 1]

    # Insertar el punto de quiebre exacto si no está ya presente
    if not np.any(np.isclose(x, x_quiebre)):
        x = np.sort(np.append(x, x_quiebre))

    return x


def espesor_doble_cuna(x, tc, x_tmax):
    """
    Devuelve el espesor local (z_upper - z_lower, adimensional) del doble
    cuña en cada posición x/c, como dos rampas lineales:
      - de (0, 0) a (x_tmax, tc)
      - de (x_tmax, tc) a (1, 0)
    """
    t = np.where(
        x <= x_tmax,
        tc * (x / x_tmax),
        tc * ((1 - x) / (1 - x_tmax)),
    )
    return t


def generar_perfil(tc, x_tmax, n_por_superficie):
    """
    Genera las coordenadas (x, z) del perfil doble cuña SIMÉTRICO,
    en formato Selig: desde el TE por el extradós hasta el LE,
    y desde el LE por el intradós hasta el TE.

    Devuelve un array Nx2 listo para escribir a archivo.
    """
    x = distribucion_x(n_por_superficie, x_tmax)
    espesor = espesor_doble_cuna(x, tc, x_tmax)
    z_upper = espesor / 2.0
    z_lower = -espesor / 2.0

    # Extradós: de TE (x=1) a LE (x=0) -> orden descendente de x
    idx_desc = np.argsort(-x)
    x_upper = x[idx_desc]
    z_up = z_upper[idx_desc]

    # Intradós: de LE (x=0) a TE (x=1), EXCLUYENDO el punto LE duplicado
    idx_asc = np.argsort(x)
    x_lower = x[idx_asc]
    z_lo = z_lower[idx_asc]
    # quitar el primer punto (x=0) del intradós para no duplicar el LE
    x_lower = x_lower[1:]
    z_lo = z_lo[1:]

    x_total = np.concatenate([x_upper, x_lower])
    z_total = np.concatenate([z_up, z_lo])

    return np.column_stack([x_total, z_total])


def escribir_dat(nombre_archivo, titulo, coords):
    """
    Escribe el archivo .dat en formato Selig (una línea de título,
    luego pares x z separados por espacio, 6 decimales).
    """
    with open(nombre_archivo, "w") as f:
        f.write(f"{titulo}\n")
        for x, z in coords:
            f.write(f"{x:.6f} {z:.6f}\n")


def verificar_geometria(coords, tc_nominal, nombre):
    """
    Chequeo rápido de sanidad: espesor máximo alcanzado, área aproximada,
    número de puntos, para detectar errores antes de importar a XFLR5.
    """
    x = coords[:, 0]
    z = coords[:, 1]
    espesor_max = z.max() - z.min()
    print(f"--- Verificación: {nombre} ---")
    print(f"  Puntos totales:       {len(coords)}")
    print(f"  x/c min / max:        {x.min():.4f} / {x.max():.4f}")
    print(f"  Espesor máx. (z):     {espesor_max:.5f}  (nominal t/c={tc_nominal:.5f})")
    print(f"  Diferencia:           {abs(espesor_max - tc_nominal):.2e}")
    print()


if __name__ == "__main__":
    coords_raiz = generar_perfil(TC_RAIZ, X_TMAX, N_PUNTOS_POR_SUPERFICIE)
    coords_punta = generar_perfil(TC_PUNTA, X_TMAX, N_PUNTOS_POR_SUPERFICIE)

    escribir_dat(ARCHIVO_RAIZ, f"Aleta_Raiz_DobleCuna_tc{TC_RAIZ*100:.2f}pct", coords_raiz)
    escribir_dat(ARCHIVO_PUNTA, f"Aleta_Punta_DobleCuna_tc{TC_PUNTA*100:.2f}pct", coords_punta)

    verificar_geometria(coords_raiz, TC_RAIZ, "raíz")
    verificar_geometria(coords_punta, TC_PUNTA, "punta")

    print(f"Archivos generados: {ARCHIVO_RAIZ}, {ARCHIVO_PUNTA}")
    print("Listos para importar en XFLR5: Direct Foil Design -> File -> Open.")
