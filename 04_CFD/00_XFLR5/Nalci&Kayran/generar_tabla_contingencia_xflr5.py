"""
generar_tabla_contingencia_xflr5.py

Transforma los resultados de flujo potencial (XFLR5) ya verificados
(momento_bisagra_consolidado.csv, formato ancho: una columna por Mach)
en una tabla de carga de CONTINGENCIA (formato largo: una fila por
combinación Mach/ángulo), lista para ser leída por el módulo de
procesamiento del banco (RF-CFD-01/02), en caso de que la CFD propia
del proyecto no esté disponible a tiempo.

Proyecto: Banco de ensayos para dimensionamiento y caracterización de
actuadores de superficies de control basado en cargas CFD.

IMPORTANTE — limitaciones de este dataset (declaradas explícitamente
en la tabla generada, no solo en este docstring):
  1. Es flujo potencial (XFLR5, paneles 3D inviscid) — sin viscosidad
     ni compresibilidad. NO reemplaza la caracterización CFD del
     proyecto; es solo un dataset de contingencia para probar el
     pipeline de software (interpolación, control) mientras la CFD
     propia no esté lista.
  2. Solo 2 dimensiones de entrada (Mach, ángulo total) en vez de las
     3 acordadas en el Avance I (Mach, ángulo, velocidad angular de
     deflexión) — XFLR5 no puede resolver velocidad angular (ver
     Geometria_Aleta_Referencia.md, §7).
  3. "Ángulo" es un ángulo TOTAL (no AoA y deflexión por separado) —
     ver Geometria_Aleta_Referencia.md, §6, pendiente de confirmación
     con los profesores guía (reunión 28/08/2026).
  4. El factor de escala geométrica λ (variable LAMBDA_ESCALA más
     abajo) sigue PENDIENTE de cierre oficial. Por defecto este script
     se ejecuta con LAMBDA_ESCALA = 1.0 (geometría a escala real de
     Nalci & Kayran, SIN escalar) — cambia esta constante y vuelve a
     correr el script una vez que λ se confirme, para generar la
     tabla en la escala física real del banco.

Entrada: momento_bisagra_consolidado.csv (generado en la sesión de
         verificación de XFLR5 — columnas beta_deg, M_Mach0.4,
         Cm_Mach0.4, M_Mach0.5, Cm_Mach0.5, M_Mach0.6, Cm_Mach0.6)

Salida:  tabla_carga_contingencia_xflr5.csv (formato largo)
"""

import pandas as pd
import numpy as np

# ==========================================================================
# PARÁMETROS
# ==========================================================================

ARCHIVO_ENTRADA = "momento_bisagra_consolidado.csv"
ARCHIVO_SALIDA = "tabla_carga_contingencia_xflr5.csv"

# Factor de escala geométrica lineal (λ). PENDIENTE de cierre oficial
# (ver Geometria_Aleta_Referencia.md §5: rango en evaluación 0.49-0.77).
# Por defecto = 1.0 (tabla a escala real de Nalci & Kayran, sin escalar).
# El momento escala con λ³ (Barlow, Rae & Pope, 1999) a igual condición
# de vuelo (mismo Mach, misma densidad -> mismo q).
LAMBDA_ESCALA = 1.0

MACH_DISPONIBLES = [0.4, 0.5, 0.6]

# Metadata para el encabezado del archivo de salida
METADATA = f"""# TABLA DE CARGA DE CONTINGENCIA — NO ES CFD
# Fuente: XFLR5 v6.61, metodo de paneles 3D, flujo potencial (inviscid)
# Geometria: doble cuna, Nalci & Kayran (2014), escala real x lambda={LAMBDA_ESCALA}
# Eje de bisagra: 50% cuerda de raiz
# Condicion de vuelo: nivel del mar, T=15C, rho=1.225 kg/m3
# LIMITACIONES:
#   - Sin viscosidad ni compresibilidad (Cm identico entre Mach, verificado)
#   - Solo 2 dimensiones: Mach y angulo TOTAL (no AoA/deflexion por separado)
#   - NO incluye velocidad angular de deflexion (XFLR5 es estatico/cuasi-estacionario)
#   - Factor de escala lambda={LAMBDA_ESCALA} -- ver PENDIENTE en Geometria_Aleta_Referencia.md §5
#   - No cumple RNF-PRE-01 (no hay error de interpolacion respecto a CFD, no hay CFD de referencia)
#   - USO PREVISTO: prueba del pipeline de software (interpolacion, control), no caracterizacion real
# Ver: 04_CFD/02_Valores_Referencia_XFLR5.md, 04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md
"""


def cargar_datos_anchos(archivo):
    df = pd.read_csv(archivo)
    return df


def reshape_a_formato_largo(df_ancho, lambda_escala):
    """
    Convierte de formato ancho (una columna M_MachX por Mach) a formato
    largo (una fila por combinación Mach/ángulo), aplicando el factor
    de escala lambda^3 al momento.
    """
    filas = []
    for mach in MACH_DISPONIBLES:
        col_M = f"M_Mach{mach}"
        for _, row in df_ancho.iterrows():
            angulo = row["beta_deg"]
            M_referencia = row[col_M]
            M_escalado = M_referencia * (lambda_escala ** 3)
            filas.append({
                "mach": mach,
                "angulo_deg": angulo,
                "torque_bisagra_Nm": M_escalado,
                "torque_bisagra_Nm_referencia_sin_escalar": M_referencia,
                "lambda_escala_aplicado": lambda_escala,
            })
    df_largo = pd.DataFrame(filas)
    df_largo = df_largo.sort_values(["mach", "angulo_deg"]).reset_index(drop=True)
    return df_largo


def reportar_envolvente(df_largo):
    """RF-CFD-04: reportar el rango válido contenido en la tabla."""
    print("--- Envolvente de la tabla ---")
    print(f"  Mach:   {df_largo['mach'].min()} a {df_largo['mach'].max()}")
    print(f"  Ángulo: {df_largo['angulo_deg'].min()}° a {df_largo['angulo_deg'].max()}°")
    print(f"  Torque: {df_largo['torque_bisagra_Nm'].min():.4f} a "
          f"{df_largo['torque_bisagra_Nm'].max():.4f} N·m")
    print(f"  Puntos totales: {len(df_largo)}")
    print()


def escribir_con_metadata(df_largo, archivo_salida, metadata):
    with open(archivo_salida, "w") as f:
        f.write(metadata)
        df_largo.to_csv(f, index=False)


if __name__ == "__main__":
    df_ancho = cargar_datos_anchos(ARCHIVO_ENTRADA)
    df_largo = reshape_a_formato_largo(df_ancho, LAMBDA_ESCALA)
    reportar_envolvente(df_largo)
    escribir_con_metadata(df_largo, ARCHIVO_SALIDA, METADATA)
    print(f"Tabla generada: {ARCHIVO_SALIDA}")
    print(f"NOTA: generada con LAMBDA_ESCALA={LAMBDA_ESCALA} (pendiente de cierre oficial).")
    print("Para regenerar con la escala definitiva, cambia LAMBDA_ESCALA y vuelve a correr.")
