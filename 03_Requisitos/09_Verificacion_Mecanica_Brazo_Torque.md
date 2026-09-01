# Verificación Mecánica del Brazo de Torque (piezas impresas en 3D)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** **Primera pasada analítica** (cálculo a mano). Propone una geometría de partida para el brazo de torque en PLA que cumple con margen razonable frente al torque pico de RNF-CAR-01, y verifica la fijación de los collares al eje mediante prisionero (§4). **No reemplaza** el análisis FEA sobre el CAD definitivo ni el ensayo físico de confirmación una vez impresa la pieza (ver §6).

**⚠️ Nota de estado (28/08/2026):** este documento completo (§1 a §6) asume la implementación de sensor de torque descrita en `06_Seleccion_Actuador_de_Carga.md` §6.2 y `05_Arquitectura_del_Sistema.md` §2.5 — celda de carga fija sobre brazo de palanca de radio fijo (~4 cm). En la reunión de avance del 28/08/2026, los profesores guía objetaron esa implementación por no acompañar el cambio de ángulo de la aleta, sugiriendo un torquímetro o strain gauges como alternativa (acuerdo #4, `00_Administración/02_Registro_Reuniones_Avance.md`). **Si esa reevaluación concluye en un cambio de tecnología de sensor, gran parte del análisis de este documento (§1, §3, partes de §4) deja de aplicar directamente**, ya que depende de que exista físicamente un brazo de palanca transmitiendo el torque hacia una celda externa. Lo que sí seguiría siendo reutilizable en ese escenario: la verificación de fijación de collares al eje mediante prisionero (§4), que es necesaria independientemente de cómo se mida el torque (cualquier elemento solidario al eje —brazo, disco de strain gauges, acople de torquímetro— requiere una fijación mecánicamente robusta). Este documento se mantiene como referencia técnica válida mientras no se cierre la reevaluación; no debe usarse todavía para congelar el CAD definitivo del brazo.

**Documentos relacionados:** `05_Arquitectura_del_Sistema.md` (§2.5, §5 supuesto 9), `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-04, RNF-REN-03), `06_Seleccion_Actuador_de_Carga.md` (§6, ítem 6).

---

## 1. Modelo mecánico

*(Aplica solo bajo la implementación celda + brazo de palanca actualmente en reevaluación — ver nota de estado arriba.)*

El brazo de torque se modela como una **viga en voladizo**: fija en el extremo del eje (collar), libre en la punta donde la presiona la celda de carga a un radio r ≈ 40 mm (RNF-CAR-01). Bajo el torque pico del banco, la fuerza de reacción en la punta es:

F_pico = T_pico / r = 2 N·m / 0,04 m = **50 N**

El momento flector máximo ocurre en la raíz (el collar), y es numéricamente igual al torque aplicado:

M_max = F_pico × r = T_pico = **2000 N·mm**

## 2. Advertencia sobre la resistencia del PLA impreso (FDM)

La resistencia de una pieza impresa en FDM es fuertemente anisotrópica: la literatura reporta resistencia a la tracción entre **~4 MPa** (carga perpendicular a las capas — la peor orientación posible) y **~42–48 MPa** (carga alineada con la dirección de impresión, con infill alto). El factor decisivo no es solo el material sino **la orientación de impresión y el porcentaje de infill**. Esto condiciona directamente cómo debe orientarse la pieza al imprimirla, no solo qué material usar.

**Recomendación de impresión:** orientar el brazo de modo que el eje longitudinal (la dirección de la flexión bajo carga) quede **alineado con la dirección de impresión/raster**, no apilado en capas perpendiculares a esa dirección — es decir, imprimir la pieza "acostada" a lo largo de su eje mayor, no de pie. Usar infill alto (≥80%, idealmente 100% dado el tamaño pequeño de la pieza — el costo adicional de material es marginal). Bajo estas condiciones es razonable esperar una resistencia efectiva en el rango de ~35–45 MPa; con una orientación deficiente, podría caer por debajo de 10 MPa.

**Nota:** esta sección (propiedades del PLA-FDM según orientación e infill) es independiente de qué elemento específico se imprima — sigue siendo relevante para cualquier pieza custom del banco (brazo de torque, collares, u otras piezas que resulten de la reevaluación del sensor de torque), no solo para la geometría de brazo de palanca de §1/§3.

## 3. Geometría propuesta y verificación

*(Aplica solo bajo la implementación celda + brazo de palanca actualmente en reevaluación — ver nota de estado arriba.)*

Se evaluaron dos secciones cuadradas macizas como punto de partida (elegidas cuadradas por simplicidad de impresión y porque 12 mm coincide con la sección de la celda de carga ya seleccionada, sin que eso sea un requisito):

| Sección              | Z (módulo de sección) | σ a T_pico (2 N·m) | σ a T_cont_max (1 N·m) | σ a T_cont_min (0,5 N·m) | Deflexión en la punta a T_pico |
| --------------------- | ----------------------- | -------------------- | ------------------------ | -------------------------- | ------------------------------- |
| 12 × 12 mm           | 288 mm³                | 6,94 MPa             | 3,47 MPa                 | 1,74 MPa                   | 0,31 mm                         |
| **14 × 14 mm** | 457 mm³                | **4,37 MPa**   | **2,19 MPa**       | **1,09 MPa**         | **0,17 mm**               |

**Evaluación frente al esfuerzo admisible:**

- Con orientación de impresión correcta (§2, ~35–45 MPa efectivos), ambas secciones dan un factor de seguridad estático amplio frente al torque pico (FS ≈ 5–8 para la sección 12×12 mm; FS ≈ 8–10 para 14×14 mm).
- El torque pico es una condición **breve** (protegida además por RF-BAN-06, que detiene el banco ante atasco sostenido); el criterio más exigente en la práctica es la **carga cíclica continua** (0,5–1 N·m, aplicada repetidamente durante ensayos dinámicos de hasta ~10 Hz). El PLA, como la mayoría de los termoplásticos, tiene un límite de fatiga sensiblemente menor que su resistencia estática — no se encontró un valor de fatiga específico y confiable para PLA impreso en FDM en esta búsqueda, por lo que **se recomienda mantener el esfuerzo en operación continua por debajo de ~3 MPa** como margen conservador, no como valor derivado de una curva S-N publicada.

**Recomendación:** la sección **14 × 14 mm** cumple ese criterio conservador (2,19 MPa a T_cont_max) con margen, mientras que la de 12 × 12 mm queda justo en el límite (3,47 MPa). Se propone **14 × 14 mm como geometría de partida** para el brazo de torque, con:

- Material: PLA, infill ≥80% (idealmente 100%).
- Orientación de impresión: eje longitudinal alineado con la dirección de impresión (§2).
- Radios de acuerdo (fillets) generosos en la unión brazo–collar, para reducir el concentrador de esfuerzo que este cálculo simplificado no captura.

## 4. Fijación de los collares al eje

**Decisión:** fijación mediante **prisionero (set-screw)**, para ambos collares (brazo de torque y aleta).

**Nota (28/08/2026):** el análisis de esta sección sigue siendo aplicable con independencia del resultado de la reevaluación del sensor de torque (§0/nota de estado). Cualquier elemento solidario al eje que deba transmitir torque de forma confiable —sea el brazo de palanca actual, un disco de strain gauges, o el acople de un torquímetro— enfrenta el mismo problema de fijación mecánica aquí analizado.

**Verificación:** un prisionero apoyado únicamente por fricción sobre un eje liso de 5 mm transmite, en una estimación conservadora, del orden de ~0,11 N·m (μ≈0,15, fuerza de apriete ~300 N) — muy por debajo del torque pico del banco (2 N·m) y de la sobrecarga transitoria de la celda de carga (~5,9 N·m). La fricción pura **no es suficiente**; se requiere un punto de apoyo mecánico positivo, no solo presión de contacto.

**Refinamientos necesarios para que el prisionero funcione con margen adecuado:**

- **Plana (flat) en el eje** en el punto donde asienta cada prisionero: convierte la unión de fricción pura a interferencia mecánica parcial, dando margen amplio sobre el torque pico.
- **Inserto roscado metálico (heat-set insert)** en cada collar impreso en PLA: evita que la rosca del prisionero se barra en el plástico, especialmente relevante dado que el banco contempla desmontar/montar el actuador bajo prueba repetidamente (CU-008).
- **Collar del brazo de torque — dos prisioneros** (separados ~90–120°): esta es la unión más crítica, porque transmite el torque de carga hacia la celda; un solo punto de apoyo es más sensible a aflojamiento por vibración y a error de medición si patina levemente. El collar de la aleta, al no transmitir torque de carga (solo debe seguir el eje sin holgura angular, RF-INS-02), puede mantenerse con un solo prisionero si se prioriza simplicidad constructiva.

Estos tres refinamientos no cambian el método elegido (prisionero); lo hacen viable para el torque real del banco. Quedan sujetos a confirmación en el CAD definitivo y a verificación física. *(Nota: "el collar del brazo de torque" en el tercer punto asume que existe un collar dedicado al brazo de palanca; si el sensor final no usa brazo, este punto debe releerse como "el collar del elemento que transmite el torque hacia el sensor", cualquiera sea su forma final.)*

## 5. Lo que este cálculo aún NO cubre

- **Concentradores de esfuerzo** en la unión brazo–collar (esquinas, orificio del prisionero, punto de la plana en el eje) — requieren FEA sobre la geometría real del CAD, no capturados por el modelo de viga simple ni por la estimación de fricción de §4.
- **Fatiga cuantitativa:** se usó un margen conservador (§3) por ausencia de datos de fatiga confiables para PLA-FDM, no una verificación con curva S-N real.
- **Efecto de la temperatura y el tiempo** (creep/fluencia del PLA, que tiene una temperatura de transición vítrea relativamente baja, ~60 °C) bajo carga sostenida durante ensayos largos.
- **Dimensionamiento exacto de la plana del eje e inserto roscado** (§4): se identificó la necesidad, pero no se calculó su geometría específica (profundidad de la plana, tamaño del inserto) — depende del prisionero concreto que se seleccione (M3 vs M4) y del CAD definitivo.
- **(Nuevo, 28/08/2026) Viabilidad de la geometría de brazo fijo frente al cambio de ángulo de la aleta:** este cálculo (§1, §3) no evaluó, porque no era su objetivo original, si el brazo de palanca de radio fijo puede seguir presionando correctamente la celda de carga a medida que la aleta cambia de ángulo durante el ensayo — que es precisamente la objeción planteada por los profesores guía (acuerdo #4). Este punto debe resolverse en la reevaluación del sensor de torque antes de dar por válida la geometría de §3 para el CAD definitivo.

## 6. Próximos pasos

1. **Antes de continuar con los pasos siguientes:** resolver la reevaluación del sensor de torque (acuerdo #4, 28/08/2026, ver `06_Seleccion_Actuador_de_Carga.md` §6.2 y §6 ítem 10). Si se mantiene el esquema de brazo de palanca (con algún ajuste que resuelva la objeción de ángulo variable), los pasos 1–4 siguientes aplican tal como están. Si se adopta un torquímetro o strain gauges, este documento debe rehacerse para la nueva geometría antes de avanzar.
2. Confirmar la geometría (14×14 mm o ajustarla) en el CAD definitivo del brazo, junto con la plana e inserto roscado en cada collar (§4).
3. Correr un análisis FEA simple (Fusion 360 / FreeCAD FEM / SolidWorks Simulation) sobre el CAD real, para capturar concentradores de esfuerzo en la unión brazo–collar y en la zona de la plana del eje.
4. Seleccionar el tamaño concreto de prisionero (M3 o M4) e inserto roscado, y dimensionar la plana del eje en función de esa elección.
5. **Ensayo físico de confirmación** una vez impresa la pieza: aplicar carga creciente hasta el torque pico (idealmente hasta la sobrecarga de seguridad del sistema, ~5,9 N·m según la celda de carga seleccionada) y verificar ausencia de fluencia visible, delaminación o deslizamiento del collar, antes de la validación experimental del banco completo.

## 7. Referencias

- Estudios de anisotropía de PLA impreso por FDM consultados para los valores de resistencia por orientación (~4–48 MPa según orientación/raster/infill): literatura reciente sobre "tensile strength FDM PLA raster angle build orientation" (ej. estudios con probetas ASTM D638 a distintos ángulos de construcción, publicados en revistas de manufactura aditiva, 2024–2025). No se cita un DOI específico porque los valores se usaron como orden de magnitud orientativo, no como dato puntual atribuido a un estudio único — se recomienda verificar con el material/impresora específicos del laboratorio antes de la validación final.
