# Graph Report - Memoria  (2026-09-04)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 85 nodes · 80 edges · 23 communities (7 shown, 15 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.85)
- Token cost: 1,052 input · 124 output

## Graph Freshness
- Built from commit: `b81d95ed`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- XFLR5 Data Processing
- Airfoil Geometry Generation
- 2D Polar Consolidation
- Aerodynamic Analysis Methodology
- Data Formatting and Reporting
- Control System Hardware
- Test Execution Use Cases
- Calibration and Input Setup
- Actuator Characterization
- Operational Domains
- Project Progress Checklist
- Literature Review
- Sensor de Torque
- Cronograma — Etapas restantes del proyecto
- Especificación del Proyecto
- Estado del Arte
- Kalman Filter (Torque/Angle Estimation)
- Principios Metodológicos del Proyecto
- Registro de Reuniones de Avance
- Requisitos Funcionales
- Requisitos No Funcionales
- Parasitic Torque (Extra Torque)

## God Nodes (most connected - your core abstractions)
1. `main()` - 6 edges
2. `parsear_polar_2d()` - 6 edges
3. `leer_texto()` - 5 edges
4. `parsear_oppoint()` - 5 edges
5. `parsear_polar()` - 5 edges
6. `Lecciones metodológicas del pipeline XFLR5` - 5 edges
7. `extraer_delta()` - 4 edges
8. `generar_perfil()` - 4 edges
9. `main()` - 4 edges
10. `es_archivo_oppoint()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Reevaluación de Alternativas — Arquitectura Física del Banco` --references--> `Lecciones metodológicas del pipeline XFLR5`  [INFERRED]
  05_Diseño_Mecánico/Comparacion_Alternativas_Arquitectura_Fisica.md → 04_CFD/00_XFLR5/04_Lecciones_Metodologicas_XFLR5.md
- `Lecciones metodológicas del pipeline XFLR5` --references--> `NACA 0012 wing hinge moments (corregido)`  [EXTRACTED]
  04_CFD/00_XFLR5/04_Lecciones_Metodologicas_XFLR5.md → 04_CFD/00_XFLR5/Simpson/NACA_0012/comparacion_Ch_vs_alpha_NACA0012.png
- `Valores de Referencia de Flujo Potencial (XFLR5)` --references--> `Momento de bisagra vs. deflexión (Nalci & Kayran)`  [EXTRACTED]
  04_CFD/00_XFLR5/02_Valores_Referencia_XFLR5.md → 04_CFD/00_XFLR5/Nalci&Kayran/momento_bisagra_vs_beta.png
- `Lecciones metodológicas del pipeline XFLR5` --references--> `Pipeline general XFLR5 para tablas de carga`  [EXTRACTED]
  04_CFD/00_XFLR5/04_Lecciones_Metodologicas_XFLR5.md → 04_CFD/00_XFLR5/03_Pipeline_General_XFLR5.md
- `Lecciones metodológicas del pipeline XFLR5` --references--> `Simpson GA(W)-1: Hoja de entrada XFLR5`  [EXTRACTED]
  04_CFD/00_XFLR5/04_Lecciones_Metodologicas_XFLR5.md → 04_CFD/00_XFLR5/Simpson/GA(W)-1/01_Checklist_Simpson_GAW1.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Torque Sensor Re-evaluation Flow** — registro_reuniones_avance_md, requisitos_no_funcionales_md, 01_documentos_memoria_capítulos_avance_1_checklist_avance_1_md [EXTRACTED 0.95]
- **CFD to Test Bench Methodology** — especificacion_del_proyecto_md, requisitos_funcionales_md, 02_literatura_resumen_referencias_md [EXTRACTED 1.00]
- **Geometry Transition Flow (Nalci to Simpson)** — 04_cfd_00_xflr5_02_valores_referencia_xflr5, 04_cfd_01_casos_01_geometria_aleta_referencia, 04_cfd_01_casos_03_matriz_casos_cfd_faseb1 [EXTRACTED 1.00]
- **Interacción en Modo Manual** — 03_requisitos_04_casos_de_uso_cu006, 03_requisitos_04_casos_de_uso_cu010, 03_requisitos_05_arquitectura_del_sistema_i11, 03_requisitos_05_arquitectura_del_sistema_i12 [EXTRACTED 1.00]
- **Flujo de Estimación de Torque** — 03_requisitos_05_arquitectura_del_sistema_sensor_torque, 03_requisitos_10_estrategia_estimacion_torque_fusion_sensorial_kalman, 03_requisitos_10_estrategia_estimacion_torque_fusion_sensorial_backemf [EXTRACTED 1.00]
- **XFLR5 Validation Pipeline** — 04_cfd_00_xflr5_03_pipeline_general_xflr5, 04_cfd_00_xflr5_04_lecciones_metodologicas_xflr5, 04_cfd_00_xflr5_simpson_gaw1_01_checklist_simpson_gaw1, 04_cfd_00_xflr5_simpson_naca_0012_01_checklist_simpson_naca0012 [EXTRACTED 1.00]

## Communities (23 total, 15 thin omitted)

### Community 0 - "XFLR5 Data Processing"
Cohesion: 0.22
Nodes (14): es_archivo_oppoint(), es_archivo_polar(), extraer_delta(), leer_texto(), main(), parsear_oppoint(), parsear_polar(), consolidar_oppoints_xflr5.py Lee todos los archivos .csv exportados desde XFLR5… (+6 more)

### Community 1 - "Airfoil Geometry Generation"
Cohesion: 0.20
Nodes (11): distribucion_x(), escribir_dat(), espesor_doble_cuna(), generar_perfil(), generar_perfil_doble_cuna.py Genera archivos de coordenadas (.dat, formato…, Escribe el archivo .dat en formato Selig (una línea de título, luego pares x z…, Chequeo rápido de sanidad: espesor máximo alcanzado, área aproximada, número de…, Genera una distribución de x/c entre 0 y 1, con espaciado coseno (más denso… (+3 more)

### Community 2 - "2D Polar Consolidation"
Cohesion: 0.26
Nodes (11): es_archivo_polar_2d_gaw1(), extraer_condicion(), extraer_delta(), leer_texto(), main(), parsear_polar_2d(), consolidar_polares_2D_gaw1.py Consolida los polares 2D exportados desde XFLR5…, Extrae Mach, Re y Ncrit del encabezado, solo para dejar constancia en la tabla… (+3 more)

### Community 3 - "Aerodynamic Analysis Methodology"
Cohesion: 0.22
Nodes (10): Valores de Referencia de Flujo Potencial (XFLR5), Pipeline general XFLR5 para tablas de carga, Lecciones metodológicas del pipeline XFLR5, Momento de bisagra vs. deflexión (Nalci & Kayran), Simpson GA(W)-1: Hoja de entrada XFLR5, Caso Simpson (2016) — NACA 0012 Checklist, NACA 0012 wing hinge moments (corregido), Geometría de la Aleta/Superficie de Referencia (CFD) (+2 more)

### Community 4 - "Data Formatting and Reporting"
Cohesion: 0.25
Nodes (5): generar_tabla_contingencia_xflr5.py Transforma los resultados de flujo…, RF-CFD-04: reportar el rango válido contenido en la tabla., Convierte de formato ancho (una columna M_MachX por Mach) a formato largo (una…, reportar_envolvente(), reshape_a_formato_largo()

### Community 5 - "Control System Hardware"
Cohesion: 0.33
Nodes (6): Controlador (ESP32), Motor de Carga (DS3218 intervenido), Driver BTS7960, Servo DS3218, Diagnóstico por Back-EMF, Filtro de Kalman (Fusión Sensorial)

### Community 6 - "Test Execution Use Cases"
Cohesion: 0.67
Nodes (3): CU-001: Importar tabla de carga aerodinámica, CU-002: Configurar un ensayo, CU-003: Ejecutar un ensayo

## Knowledge Gaps
- **28 isolated node(s):** `Sensor de Torque`, `Simpson GA(W)-1: Hoja de entrada XFLR5`, `Matriz de Casos CFD — Fase B1`, `Reevaluación de Alternativas — Arquitectura Física del Banco`, `Momento de bisagra vs. deflexión (Nalci & Kayran)` (+23 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 52 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `Sensor de Torque`, `Simpson GA(W)-1: Hoja de entrada XFLR5`, `Matriz de Casos CFD — Fase B1` to the rest of the system?**
  _28 weakly-connected nodes found - possible documentation gaps or missing edges._