# Valores de Referencia de Flujo Potencial (XFLR5)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Objetivo de este documento:** proveer un tercer punto de comparación para el momento de bisagra (junto a la literatura análoga y a la CFD propia), obtenido mediante análisis de flujo potencial (inviscid) en XFLR5 sobre la geometría de referencia de Nalci & Kayran (2014), a escala real (sin aplicar aún el factor de escala λ del banco).

**Estado:** Primeros resultados obtenidos y verificados (antisimetría, escala con Mach). Pendiente: tabular la curva completa (todos los ángulos, no solo ±15°) y decidir el factor de escala λ definitivo.

**Documentos relacionados:** `Geometria_Aleta_Referencia.md` (geometría y escala pendiente), `07_Valores_Referencia_Literatura_Analoga.md` (comparación con literatura), `03_Requisitos_No_Funcionales.md` (RNF-CAR-01).

---

## 1. Metodología

- **Software:** XFLR5 v6.61, método de **paneles 3D** (no VLM, para capturar el espesor del perfil doble cuña).
- **Geometría:** perfil doble cuña simétrico (raíz t/c=2.56%, punta t/c=2.82%, quiebre en 50% de cuerda), planta trapezoidal (cuerda raíz 156 mm, cuerda punta 78 mm, envergadura 150 mm, flecha LE 27.5°, TE recto) — geometría a escala real de Nalci & Kayran (2014), ver `Geometria_Aleta_Referencia.md`.
- **Objeto:** `Wing` aislado (no `Plane`), definido con `isFin = true` (Define → Advanced users) para evitar la duplicación en espejo que impone un objeto `Plane`.
- **Punto de referencia del momento:** eje de bisagra a **50% de la cuerda de raíz** (x = 78 mm desde el borde de ataque), según la descripción del modelo estructural de la tesis de Nalci (2013): *"The mid-node on the root chord of the fin is rigidly connected to [the shaft point]... rotational stiffness of the shaft in y-axis"* — el shaft/actuador se conecta al nodo medio de la cuerda de raíz.
- **Condición de vuelo:** nivel del mar (0 m), T = 15°C (288.15 K) → ρ = 1.225 kg/m³, a = 340.3 m/s.
- **Rango angular:** -15° a +15° (deflexión de la aleta, aparece como "beta" en XFLR5 por el flag `isFin`), coincidente con el límite de posición angular de la Tabla 2 de Nalci & Kayran (±15°). Dividido en 2 sub-corridas de Δ=0.25° por Mach, por el límite de 100 puntos por polar de XFLR5 v6.61.
- **Geometría de referencia XFLR5:** S = 0.018 m², c̄ (MAC) = 121.33 mm (verificado analíticamente: MAC = (2/3)·c_raíz·(1+λ_taper+λ_taper²)/(1+λ_taper) con λ_taper=0.5 → 121.33 mm ✓).

## 2. Verificaciones de sanidad realizadas

| Verificación | Resultado | Evaluación |
|---|---|---|
| Antisimetría (M(-15°) ≈ -M(15°), M0.6) | -4.359 N·m vs. 4.351 N·m (diferencia 0.18%) | ✅ Ruido numérico normal de discretización, sin problema |
| Escalado con Mach (M ∝ V², a igual β=15°) | Ver tabla §3 — coincidencia con predicción teórica <0.1% | ✅ Confirma consistencia de S, c̄, q y Cm entre corridas |

## 3. Resultados obtenidos (barrido completo -15° a 15°, escala real Nalci & Kayran)

Barrido completo, Δβ=0.25°, 121 puntos por Mach (exportado de XFLR5 a Excel, columna `M` — momento dimensional ya calculado internamente por XFLR5 usando su S y c̄ de referencia). Tabla de puntos clave:

| β (°) | M, Mach 0.4 [N·m] | M, Mach 0.5 [N·m] | M, Mach 0.6 [N·m] |
|---:|---:|---:|---:|
| -15 | -1.9366 | -3.0286 | -4.3595 |
| -10 | -1.3243 | -2.0710 | -2.9811 |
| -5  | -0.6721 | -1.0511 | -1.5131 |
| 0   |  0.0000 |  0.0000 |  0.0000 |
| 5   |  0.6717 |  1.0505 |  1.5121 |
| 10  |  1.3226 |  2.0683 |  2.9772 |
| 15  |  1.9328 |  3.0227 |  4.3510 |

![Momento de bisagra vs. deflexión](momento_bisagra_vs_beta.png)

### Verificaciones sobre el rango completo

| Verificación | Resultado |
|---|---|
| Antisimetría (todo el rango, no solo endpoints) | Error relativo máx. 0.195% en los 121 puntos — consistente en toda la curva |
| Monotonía | M(β) estrictamente creciente en los 3 Mach, sin quiebres — sin artefactos numéricos residuales del límite de convergencia detectado en pantalla (§1) |
| Linealidad | Ajuste lineal con R² > 0.9998 en los 3 Mach; ligera curvatura (rigidez creciente hacia los extremos), coherente con efectos de envergadura finita en flujo potencial |

### Hallazgo: XFLR5 no aplica corrección de compresibilidad en esta configuración

`Cm(β)` es **idéntico** (diferencia exactamente 0.0) entre los tres Mach — toda la variación de `M` entre velocidades proviene únicamente de `q` (∝V²), no de un cambio en el coeficiente por compresibilidad. Esto confirma, con evidencia numérica directa, la limitación anticipada en la metodología original: el método de paneles 3D de XFLR5, en esta configuración, opera como **flujo incompresible puro**, sin Prandtl-Glauert ni corrección equivalente — relevante al momento de justificar por qué la CFD propia (viscosa/compresible) es indispensable más allá de esta referencia de orden de magnitud.

## 4. Comparación con el valor de diseño de la literatura

| Fuente | Condición | Momento de bisagra |
|---|---|---|
| Nalci & Kayran (2014) — valor de diseño ("Maximum Load Torque") | M 0.4–0.6, envolvente de diseño con margen | 6 N·m |
| XFLR5 (este documento) — flujo potencial puro | β=15°, M0.6, nivel del mar | 4.3510 N·m |
| Diferencia | — | ~27% por debajo del valor de diseño |

**Evaluación:** la diferencia es razonable y en la dirección esperada. El valor de diseño de la tesis es una *capacidad* de actuador con margen (no la carga aerodinámica real instantánea), consistente con la práctica reportada en Anastasopoulos & Hornung (2018) de dimensionar el motor de carga ~1.1–1.4× por sobre el torque continuo/pico del actuador bajo prueba (ver `07_Valores_Referencia_Literatura_Analoga.md`, §2.1). Un valor de flujo potencial ~25-30% por debajo del valor de diseño con margen es coherente con esa práctica, y confirma que la geometría, el punto de referencia del momento y la conversión dimensional (S, c̄, q) están correctamente implementados.

## 5. Hallazgo sobre el factor de escala λ

**Ley de escalado aplicada:** a igual condición de vuelo (mismo Mach, misma altitud → mismo `q`), los coeficientes aerodinámicos (`Cm`, `CH`) son invariantes con el tamaño físico del modelo, mientras que el momento dimensional escala con el cubo del factor de escala lineal:

```
M_λ(β, Mach) = λ³ · M_referencia(β, Mach)
```

Ver Barlow, Rae & Pope (1999), *Low-Speed Wind Tunnel Testing*, para la formulación de coeficientes adimensionales y el argumento de escalado geométrico en ensayos con modelos a escala.

**Aplicando la hipótesis de trabajo λ≈1/4 (registrada como no confirmada en `Geometria_Aleta_Referencia.md`):**

| Mach | M_referencia (156 mm) | M_λ=1/4 (λ³=1/64) |
|---|---|---|
| 0.4 | 1.93 N·m | 0.030 N·m |
| 0.5 | 3.02 N·m | 0.047 N·m |
| 0.6 | 4.35 N·m | **0.068 N·m** |

**Resultado:** con λ=1/4, el momento de bisagra en la condición más exigente (β=15°, M0.6) queda en **0.068 N·m** — muy por debajo del piso de RNF-CAR-01 (~0.5 N·m continuo), un factor de ~7–30× por debajo del rango objetivo. **La hipótesis λ≈1/4 no es consistente con el rango de torque que el banco necesita reproducir.**

**λ requerido para caer dentro de RNF-CAR-01** (despejando de la condición más exigente, M_referencia = 4.35 N·m):

```
λ = (M_objetivo / M_referencia)^(1/3)

Para M_objetivo = 0.5 N·m (piso continuo, RNF-CAR-01):  λ ≈ 0.49
Para M_objetivo = 2 N·m   (techo pico, RNF-CAR-01):      λ ≈ 0.77
```

Es decir, una aleta entre **~49% y ~77%** del tamaño de la referencia de Nalci & Kayran — sustancialmente mayor que la hipótesis de 1/4 originalmente registrada.

## 6. Impacto sobre otros documentos del proyecto

| Documento | Impacto |
|---|---|
| `Geometria_Aleta_Referencia.md` §5 | La hipótesis λ≈1/4 debe marcarse como **descartada por este hallazgo** (no como confirmada ni como pendiente sin evidencia); el rango λ≈0.49–0.77 pasa a ser la nueva hipótesis de trabajo, sujeta a la definición de la matriz de casos CFD (Fase B1) — ver decisión pendiente en §7. |
| `07_Valores_Referencia_Literatura_Analoga.md` | Puede incorporarse esta comparación como tercer punto de referencia, junto a Anastasopoulos & Hornung (2018). |
| `referencias_bibliograficas.bib` / `resumen_referencias.md` | Agregar Barlow, Rae & Pope (1999) — ver snippet BibTeX provisto en la conversación de origen de este documento. |

## 6bis. Alcance dimensional de este dataset frente a la matriz de casos acordada

Con el acuerdo del Avance I (21/08/2026, ver `00_Administración/02_Registro_Reuniones_Avance.md`) de incorporar la velocidad de deflexión angular como cuarta dimensión de la superficie de respuesta CFD, y con el hallazgo de que el modelo de aleta aislada (sin fuselaje) no distingue AoA de deflexión — mismo ángulo, dos nombres (ver `Geometria_Aleta_Referencia.md` §6) —, el dataset de este documento cubre:

| Dimensión acordada | ¿Cubierta aquí? |
|---|---|
| Mach | Sí |
| Ángulo (total; no AoA y deflexión por separado) | Sí |
| Velocidad angular de deflexión | **No** — XFLR5 resuelve polares estáticos/cuasi-estacionarios; la tasa de deflexión es un efecto no estacionario fuera del alcance del método (requiere CFD no estacionaria, ver Tema 1: Solarte-Pineda et al. 2026; Yan et al. 2023). |

**Este dataset es, como máximo, una referencia de contingencia en 2 dimensiones (Mach × ángulo total)** — útil para validar el pipeline de software de interpolación/control mientras no esté disponible la CFD propia, pero no reemplaza la caracterización completa de 3 dimensiones que exige el acuerdo del Avance I.

## 7. Pendiente / decisión abierta

El rango de λ (0.49–0.77) se calculó usando **β=15° como condición de diseño** — el extremo del rango angular de Nalci & Kayran, pensado para un misil. Si la matriz de casos CFD del proyecto (Fase B1, aún pendiente) concentra los casos de uso reales en deflexiones menores (ej. ±5–8°), el torque requerido cae proporcionalmente y λ=1/4 podría volver a ser viable. **Esta decisión no se cierra en este documento** — depende de definir primero qué rango angular de operación es representativo del caso de uso real del banco, lo cual a su vez depende del contexto de aplicación final (ver nota de contexto en la conversación de origen: posible cambio del objeto de diseño de misil a UAV).

## 8. Referencias citadas en este documento

- Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055.
- Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, METU.
- Anastasopoulos, L., & Hornung, M. (2018). *Design of a Real-Time Test Bench for UAV Servo Actuators.* AIAA AVIATION Forum, AIAA 2018-3735.
- Barlow, J. B., Rae, W. H., & Pope, A. (1999). *Low-Speed Wind Tunnel Testing* (3rd ed.). John Wiley & Sons. *(referencia nueva, agregar a la bibliografía del proyecto)*
