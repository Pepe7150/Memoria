# Verificación Mecánica del Brazo de Torque (piezas impresas en 3D)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** **Primera pasada analítica** (cálculo a mano). Propone una geometría de partida para el brazo de torque en PLA que cumple con margen razonable frente al torque pico de RNF-CAR-01. **No reemplaza** el análisis FEA sobre el CAD definitivo ni el ensayo físico de confirmación una vez impresa la pieza (ver §5). Los collares de fijación al eje quedan fuera de este cálculo (ver §4).

**Documentos relacionados:** `05_Arquitectura_del_Sistema.md` (§2.5, §5 supuesto 9), `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-04, RNF-REN-03), `06_Seleccion_Actuador_de_Carga.md` (§6, ítem 6).

---

## 1. Modelo mecánico

El brazo de torque se modela como una **viga en voladizo**: fija en el extremo del eje (collar), libre en la punta donde la presiona la celda de carga a un radio r ≈ 40 mm (RNF-CAR-01). Bajo el torque pico del banco, la fuerza de reacción en la punta es:

F_pico = T_pico / r = 2 N·m / 0,04 m = **50 N**

El momento flector máximo ocurre en la raíz (el collar), y es numéricamente igual al torque aplicado:

M_max = F_pico × r = T_pico = **2000 N·mm**

## 2. Advertencia sobre la resistencia del PLA impreso (FDM)

La resistencia de una pieza impresa en FDM es fuertemente anisotrópica: la literatura reporta resistencia a la tracción entre **~4 MPa** (carga perpendicular a las capas — la peor orientación posible) y **~42–48 MPa** (carga alineada con la dirección de impresión, con infill alto). El factor decisivo no es solo el material sino **la orientación de impresión y el porcentaje de infill**. Esto condiciona directamente cómo debe orientarse la pieza al imprimirla, no solo qué material usar.

**Recomendación de impresión:** orientar el brazo de modo que el eje longitudinal (la dirección de la flexión bajo carga) quede **alineado con la dirección de impresión/raster**, no apilado en capas perpendiculares a esa dirección — es decir, imprimir la pieza "acostada" a lo largo de su eje mayor, no de pie. Usar infill alto (≥80%, idealmente 100% dado el tamaño pequeño de la pieza — el costo adicional de material es marginal). Bajo estas condiciones es razonable esperar una resistencia efectiva en el rango de ~35–45 MPa; con una orientación deficiente, podría caer por debajo de 10 MPa.

## 3. Geometría propuesta y verificación

Se evaluaron dos secciones cuadradas macizas como punto de partida (elegidas cuadradas por simplicidad de impresión y porque 12 mm coincide con la sección de la celda de carga ya seleccionada, sin que eso sea un requisito):

| Sección | Z (módulo de sección) | σ a T_pico (2 N·m) | σ a T_cont_max (1 N·m) | σ a T_cont_min (0,5 N·m) | Deflexión en la punta a T_pico |
|---|---|---|---|---|---|
| 12 × 12 mm | 288 mm³ | 6,94 MPa | 3,47 MPa | 1,74 MPa | 0,31 mm |
| **14 × 14 mm** | 457 mm³ | **4,37 MPa** | **2,19 MPa** | **1,09 MPa** | **0,17 mm** |

**Evaluación frente al esfuerzo admisible:**
- Con orientación de impresión correcta (§2, ~35–45 MPa efectivos), ambas secciones dan un factor de seguridad estático amplio frente al torque pico (FS ≈ 5–8 para la sección 12×12 mm; FS ≈ 8–10 para 14×14 mm).
- El torque pico es una condición **breve** (protegida además por RF-BAN-06, que detiene el banco ante atasco sostenido); el criterio más exigente en la práctica es la **carga cíclica continua** (0,5–1 N·m, aplicada repetidamente durante ensayos dinámicos de hasta ~10 Hz). El PLA, como la mayoría de los termoplásticos, tiene un límite de fatiga sensiblemente menor que su resistencia estática — no se encontró un valor de fatiga específico y confiable para PLA impreso en FDM en esta búsqueda, por lo que **se recomienda mantener el esfuerzo en operación continua por debajo de ~3 MPa** como margen conservador, no como valor derivado de una curva S-N publicada.

**Recomendación:** la sección **14 × 14 mm** cumple ese criterio conservador (2,19 MPa a T_cont_max) con margen, mientras que la de 12 × 12 mm queda justo en el límite (3,47 MPa). Se propone **14 × 14 mm como geometría de partida** para el brazo de torque, con:
- Material: PLA, infill ≥80% (idealmente 100%).
- Orientación de impresión: eje longitudinal alineado con la dirección de impresión (§2).
- Radios de acuerdo (fillets) generosos en la unión brazo–collar, para reducir el concentrador de esfuerzo que este cálculo simplificado no captura.

## 4. Lo que este cálculo NO cubre

- **Los collares de fijación al eje** (sujeción del brazo y de la aleta al eje de 5 mm) no se analizaron aquí: su modo de falla depende del método de fijación (prisionero/set-screw, chavetero, ajuste a presión, adhesivo), que aún no está definido en la documentación del proyecto (`05_Arquitectura_del_Sistema.md` solo menciona "collares" de forma genérica). Esto es un ítem de diseño abierto adicional, no solo de verificación.
- **Concentradores de esfuerzo** en la unión brazo–collar (esquinas, orificios de prisionero) — requieren FEA sobre la geometría real del CAD, no capturados por el modelo de viga simple.
- **Fatiga cuantitativa:** se usó un margen conservador por ausencia de datos de fatiga confiables para PLA-FDM, no una verificación con curva S-N real.
- **Efecto de la temperatura y el tiempo** (creep/fluencia del PLA, que tiene una temperatura de transición vítrea relativamente baja, ~60 °C) bajo carga sostenida durante ensayos largos.

## 5. Próximos pasos

1. Confirmar la geometría (14×14 mm o ajustarla) en el CAD definitivo del brazo, junto con el método de fijación de los collares.
2. Correr un análisis FEA simple (Fusion 360 / FreeCAD FEM / SolidWorks Simulation) sobre el CAD real, para capturar concentradores de esfuerzo en la unión brazo–collar.
3. Definir el método de fijación collar–eje (prisionero, chavetero, adhesivo) y extender la verificación a esa unión.
4. **Ensayo físico de confirmación** una vez impresa la pieza: aplicar carga creciente hasta el torque pico (idealmente hasta la sobrecarga de seguridad del sistema, ~5,9 N·m según la celda de carga seleccionada) y verificar ausencia de fluencia visible o delaminación, antes de la validación experimental del banco completo.

## 6. Referencias

- Estudios de anisotropía de PLA impreso por FDM consultados para los valores de resistencia por orientación (~4–48 MPa según orientación/raster/infill): literatura reciente sobre "tensile strength FDM PLA raster angle build orientation" (ej. estudios con probetas ASTM D638 a distintos ángulos de construcción, publicados en revistas de manufactura aditiva, 2024–2025). No se cita un DOI específico porque los valores se usaron como orden de magnitud orientativo, no como dato puntual atribuido a un estudio único — se recomienda verificar con el material/impresora específicos del laboratorio antes de la validación final.
