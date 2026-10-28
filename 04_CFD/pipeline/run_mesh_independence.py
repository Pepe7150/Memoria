import os
import subprocess
import csv
import re
import shutil

# ==========================================
# CONFIGURACIÓN DEL CASO CRÍTICO
# ==========================================
MACH = 0.2
AOA = 12.0
FLAP_DEFLECTION = 10.0

# Factor de refinamiento global ~ 1.4
niveles_malla = [
    {"nombre": "Gruesa",    "te": 0.0056, "le": 0.0056, "ff": 2.1},
    {"nombre": "Base",      "te": 0.0040, "le": 0.0040, "ff": 1.5},
    {"nombre": "Fina",      "te": 0.0028, "le": 0.0028, "ff": 1.07},
    {"nombre": "ExtraFina", "te": 0.0020, "le": 0.0020, "ff": 0.75}
]

DAT_FILE = "naca0012.dat"
MSH_FILE = "naca0012.msh"
BASE_CASE = "mesh_base"
RUN_CASE = "run_case"

# ==========================================
# FUNCIONES AUXILIARES
# ==========================================
def run_cmd(cmd, clean_ld=False, cwd=None):
    """Ejecuta un comando en la terminal. Limpia LD_LIBRARY_PATH si es GMSH."""
    env = os.environ.copy()
    if clean_ld and "LD_LIBRARY_PATH" in env:
        env["LD_LIBRARY_PATH"] = ""
    
    print(f"  >>> Ejecutando: {cmd}")
    subprocess.run(cmd, shell=True, env=env, check=True, cwd=cwd, stdout=subprocess.DEVNULL)

def get_cell_count(case_dir):
    """Ejecuta checkMesh y extrae el número total de celdas."""
    try:
        salida = subprocess.check_output(f"checkMesh -case {case_dir}", shell=True, text=True, stderr=subprocess.STDOUT)
        match = re.search(r'cells:\s+(\d+)', salida)
        return int(match.group(1)) if match else 0
    except subprocess.CalledProcessError:
        return 0

def extract_last_values(filepath):
    """Extrae la última línea de datos numéricos de un archivo coefficient.dat."""
    if not os.path.exists(filepath):
        return None
    with open(filepath, 'r') as f:
        lineas = f.readlines()
        for linea in reversed(lineas):
            if not linea.startswith('#') and linea.strip():
                return [float(x) for x in linea.strip().split()]
    return None

# ==========================================
# FLUJO PRINCIPAL
# ==========================================
def main():
    resultados = []
    
    # 1. Generar la geometría base (solo se necesita una vez si la deflexión es constante)
    print(f"--- Generando Geometría (Flap = {FLAP_DEFLECTION}°) ---")
    run_cmd(f"python3 naca0012_flap_geometry.py --delta {FLAP_DEFLECTION} --out {DAT_FILE}", clean_ld=True)

    for malla in niveles_malla:
        print(f"\n==========================================")
        print(f" EVALUANDO MALLA: {malla['nombre']}")
        print(f"==========================================")
        
        # Limpiar carpetas previas si existen
        if os.path.exists(BASE_CASE): shutil.rmtree(BASE_CASE)
        if os.path.exists(RUN_CASE): shutil.rmtree(RUN_CASE)
        
        # 2. Generar malla con GMSH
        cmd_mesh = f"python3 naca_mesh_gmsh.py --dat {DAT_FILE} --out {MSH_FILE} --te-size {malla['te']} --le-size {malla['le']} --farfield-size {malla['ff']}"
        run_cmd(cmd_mesh, clean_ld=True)
        
        # 3. Convertir a OpenFOAM (se guarda en BASE_CASE)
        run_cmd(f"./convert_mesh.sh {BASE_CASE} {MSH_FILE}")
        
        # 4. Obtener cantidad de celdas
        celdas = get_cell_count(BASE_CASE)
        print(f"  -> Celdas generadas: {celdas}")
        
        # 5. Configurar caso aerodinámico (toma BASE_CASE y exporta a RUN_CASE)
        run_cmd(f"python3 build_case.py --mesh-case {BASE_CASE} --mach {MACH} --aoa {AOA} --out {RUN_CASE}")
        
        # 6. Correr CFD (ejecutado DENTRO de RUN_CASE)
        print("  -> Corriendo simpleFoam (esto tomará un momento)...")
        run_cmd("simpleFoam", cwd=RUN_CASE)
        
        # 7. Extraer resultados desde las rutas del caso evaluado
        dir_coeffs = f"{RUN_CASE}/postProcessing/forceCoeffs1/0/coefficient.dat"
        dir_hinge  = f"{RUN_CASE}/postProcessing/hingeMoment1/0/coefficient.dat"
        
        val_coeffs = extract_last_values(dir_coeffs)
        val_hinge = extract_last_values(dir_hinge)
        
        cd = val_coeffs[1] if val_coeffs else 0.0
        cl = val_coeffs[3] if val_coeffs else 0.0
        ch = val_hinge[1] if val_hinge else 0.0
        
        print(f"  -> Cl: {cl:.4f} | Cd: {cd:.4f} | ChHinge: {ch:.4f}")
        
        resultados.append({
            "Malla": malla["nombre"],
            "Celdas": celdas,
            "Cl": cl,
            "Cd": cd,
            "ChHinge": ch
        })

    # ==========================================
    # EXPORTAR A CSV
    # ==========================================
    archivo_csv = "mesh_independence_results.csv"
    with open(archivo_csv, mode='w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=["Malla", "Celdas", "Cl", "Cd", "ChHinge"])
        writer.writeheader()
        for res in resultados:
            writer.writerow(res)
            
    # Limpieza final para mantener el directorio pulcro
    if os.path.exists(BASE_CASE): shutil.rmtree(BASE_CASE)
    if os.path.exists(RUN_CASE): shutil.rmtree(RUN_CASE)
            
    print(f"\n✅ Estudio completado. Resultados exportados a {archivo_csv}")

if __name__ == "__main__":
    main()