# Geometría de la Aleta de Referencia (CFD)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Decisión de **perfil y planta cerrada** (doble cuña, trapezoidal, proporciones tomadas de literatura). **Escala absoluta (factor de escalado lineal) PENDIENTE** — hipótesis inicial λ≈1/4 **descartada** tras análisis de flujo potencial en XFLR5 (ver §5 y `04_CFD/02_Valores_Referencia_XFLR5.md`); nuevo rango λ≈0.49–0.77 en evaluación, sujeto a la matriz de casos CFD (Fase B1) y a la posible revisión del objeto de diseño (ver §9).

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `03_Requisitos_No_Funcionales.md` (RNF-CAR-01), `06_Seleccion_Actuador_de_Carga.md`, `07_Valores_Referencia_Literatura_Analoga.md`, `04_CFD/02_Valores_Referencia_XFLR5.md`, `00_Administración/02_Registro_Reuniones_Avance.md`, `02_Literatura/resumen_referencias.md` (Tema 3, referencia 4).

---

## 1. Objeto de la decisión

La aleta que se **simula en CFD** (fuente de la tabla de carga que consume el banco) y la aleta **física impresa** que se monta en el eje del banco son conceptualmente distintas, aunque comparten la misma geometría de referencia por trazabilidad:

- La aleta física **no recibe carga aerodinámica real** (no hay túnel de viento asociado al banco, ver `01_Especificacion_del_Proyecto.md`, sección "No incluye"). Su función es servir de punto de medición del ángulo real (encoder) y de fuente de inercia/dinámica que el actuador bajo prueba debe vencer.
- En consecuencia, el **espesor de la pieza física puede ajustarse libremente por razones de fabricabilidad** (impresión 3D en PLA) sin afectar la validez del modelo CFD, que sí debe respetar el perfil aerodinámico delgado real para calcular el torque de bisagra.
- Ambas geometrías comparten planta, proporciones y perfil de referencia; pueden divergir en espesor absoluto de la pieza impresa.

## 2. Fuente de referencia

Se utilizó como referencia geométrica la tesis de maestría detrás del paper ya catalogado en la revisión de literatura (Tema 3, ref. 4):

> Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, Middle East Technical University (METU). Supervisor: Prof. Dr. Altan Kayran.
> Versión publicada: Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055.

Se consultó el texto completo de la tesis (no solo el resumen ya incluido en `resumen_referencias.md`) para extraer valores geométricos concretos de la aleta modelada, dado que es la referencia más cercana al dominio específico del proyecto (misil, superficie de control, actuador electromecánico) identificada en la revisión bibliográfica.

## 3. Geometría extraída de la referencia

| Parámetro | Valor (Nalci & Kayran, 2014) |
|---|---|
| Cuerda de raíz | 156 mm |
| Cuerda de punta | 78 mm |
| Envergadura | 150 mm |
| Razón de estrechamiento (taper ratio) | 0,5 |
| Borde de fuga | Recto (sin flecha) |
| Flecha del borde de ataque | ~27,5° |
| Perfil | Doble cuña (diamante), espesor variable en envergadura |
| Espesor en la raíz | ~4 mm |
| Espesor en la punta | ~2,2 mm |
| Relación espesor/cuerda (t/c) | ~2,4–2,8 % |
| Eje de bisagra (shaft del actuador) | 50% de la cuerda de raíz (x=78 mm desde el borde de ataque) — nodo medio de la cuerda de raíz según el modelo FEM de la tesis |
| Límite de posición angular (deflexión) | ±15° |
| Torque de bisagra de diseño (máximo) | 6 N·m |
| Envolvente de vuelo usada para dimensionar el actuador de la referencia | Mach 0,4–0,6, altitud 0–5000 m |
| Rigidez torsional del eje de montaje (dato estructural de la referencia, no aplica al banco) | 120 N·m/rad |

## 4. Decisión de perfil y planta (cerrada)

Se adopta, para el modelo geométrico de la aleta del proyecto:

- **Perfil aerodinámico:** doble cuña, típico de superficies supersónicas de misil.
- **Forma en planta:** trapezoidal, con borde de ataque en flecha y borde de fuga recto.
- **Proporciones a mantener** (adimensionales, independientes de la escala absoluta):
  - Razón de estrechamiento: 0,5 (cuerda de punta = mitad de la cuerda de raíz).
  - Flecha del borde de ataque: ~27,5°.
  - Relación espesor/cuerda: ~2,4–2,8 %, decreciente de raíz a punta — **aplica al modelo usado en CFD**; la pieza física impresa puede apartarse de este valor por fabricabilidad (ver sección 1).

## 5. Escala absoluta — hipótesis λ≈1/4 DESCARTADA, nuevo rango en evaluación

Se obtuvieron valores de referencia de flujo potencial (XFLR5, método de paneles 3D, inviscid) sobre la geometría a escala real de esta sección, con el eje de bisagra en el punto indicado en §3. Ver `04_CFD/02_Valores_Referencia_XFLR5.md` para la metodología y resultados completos (barrido -15° a 15°, Mach 0.4/0.5/0.6, nivel del mar).

**Ley de escalado aplicada** (a igual condición de vuelo, mismo `q`): `M_λ = λ³ · M_referencia` (Barlow, Rae & Pope, 1999 — ver `resumen_referencias.md`, referencia adicional §74).

Aplicando la condición más exigente del barrido (β=15°, Mach 0.6, M_referencia=4.351 N·m):

- La hipótesis de trabajo λ≈1/4 da un momento de bisagra de solo ~0.068 N·m — muy por debajo del piso de RNF-CAR-01 (~0.5 N·m continuo). **Esta hipótesis queda descartada.**
- El rango de λ consistente con RNF-CAR-01 (0.5–2 N·m) es **λ ≈ 0.49–0.77**.

Este rango depende de haber usado β=15° (extremo del rango angular de Nalci & Kayran, pensado para un misil) como condición de diseño. Sigue **PENDIENTE** cerrar la escala definitiva, condicionado a la matriz de casos CFD (Fase B1) y a la definición del contexto de aplicación final del banco (ver §9).

## 6. Hallazgo: degeneración entre ángulo de ataque y deflexión en el modelo de aleta aislada

Al definir la matriz de casos para XFLR5 surgió un punto conceptual relevante, también aplicable a la futura CFD propia del proyecto:

**El modelo actual (aleta aislada, sin fuselaje ni otra geometría de referencia) no puede distinguir entre ángulo de ataque (AoA) del vehículo y deflexión de la aleta.** Ambos ángulos miden lo mismo — la orientación entre la cuerda de la aleta y la corriente libre — y solo son magnitudes distintas cuando existe un tercer objeto (el fuselaje) contra el cual referenciar cada uno por separado. Como el alcance del proyecto excluye explícitamente el diseño del vehículo/misil (`01_Especificacion_del_Proyecto.md`, "No incluye"), el modelo de aleta aislada no incluye ese marco de referencia adicional.

**Consecuencia:** tanto para XFLR5 como, previsiblemente, para la CFD propia (mientras el dominio de simulación sea solo la aleta, sin fuselaje), la matriz de casos debería parametrizarse con un **único ángulo total** (Mach × ángulo × velocidad angular de deflexión), no con AoA y deflexión como dos variables independientes (Mach × AoA × deflexión × velocidad angular). Esto reduce en una dimensión la matriz de casos CFD respecto a lo planteado originalmente en la arquitectura del sistema (`05_Arquitectura_del_Sistema.md` §2.1, `02_Requisitos_Funcionales.md` RF-CFD-02) — **pendiente de confirmar con los profesores guía** (ver pregunta 1, `00_Administración/02_Registro_Reuniones_Avance.md`, reunión 28/08/2026) antes de propagar el cambio a esos documentos.

## 7. Alcance de XFLR5 frente a las 4 dimensiones de la superficie de respuesta

Con el acuerdo del Avance I (21/08/2026) de incorporar la velocidad de deflexión angular como cuarta dimensión de la superficie de respuesta CFD, y con el hallazgo de §6, las dimensiones de la matriz de casos quedan así:

| Dimensión | ¿Cubierta por XFLR5? | Motivo |
|---|---|---|
| Mach | Sí | Barrido directo de velocidad/densidad |
| Ángulo (total, ver §6) | Sí | Barrido directo de deflexión |
| Velocidad angular de deflexión | **No** | XFLR5 resuelve polares estáticos/cuasi-estacionarios; la tasa de deflexión es un efecto genuinamente no estacionario (requiere resolver la evolución de la estela durante el movimiento), fuera del alcance de este método. Requiere CFD no estacionaria (ver Tema 1: Solarte-Pineda et al. 2026; Yan et al. 2023). |

**Conclusión:** XFLR5 puede proveer, a lo sumo, un dataset de **contingencia en 2 dimensiones** (Mach × ángulo total) — útil como prueba del pipeline de software de interpolación/control mientras no esté disponible la CFD propia, pero no reemplaza la caracterización completa de 3 dimensiones (Mach × ángulo × velocidad angular) que exige el acuerdo del Avance I.

## 8. Impacto sobre otros documentos del proyecto

| Documento | Estado |
|---|---|
| `03_Requisitos_No_Funcionales.md` (RNF-CAR-01) | Sin cambios por ahora; el rango de torque (~0,5–2 N·m) sigue siendo la restricción que la escala de la aleta deberá satisfacer una vez cerrada. |
| `05_Arquitectura_del_Sistema.md` | Sin cambios estructurales; la aleta física sigue descrita como "elemento representativo de prueba, de geometría genérica" (supuesto 3). **Nota agregada:** la descripción del Módulo CFD (§2.1) y la tabla de RF-CFD-02 (variables Mach/AoA/deflexión) quedan marcadas como pendientes de revisión por el hallazgo de §6 de este documento. |
| `02_Requisitos_Funcionales.md` (RF-CFD-02) | Marcado como pendiente de revisión: la estructura de la tabla de carga (Mach, AoA, deflexión → torque) podría simplificarse a (Mach, ángulo total → torque) según el hallazgo de §6, sujeto a confirmación con los profesores guía. |
| `04_CFD/02_Valores_Referencia_XFLR5.md` | Documento con la metodología y resultados completos que sustentan §5 y §7 de este documento. |
| Diseño mecánico (CAD, Fase C del cronograma) | **Parcialmente desbloqueado**: perfil y proporciones ya permiten avanzar bocetos, pero el modelo dimensionado final de la aleta física depende de que se cierre la escala (§5) y de la posible revisión de contexto (§9). |
| Metodología CFD (Fase B) | Esta geometría (con su escala aún pendiente) y el hallazgo de §6 son insumo directo para B1 ("Definición de casos de simulación"). |

## 9. Nota abierta: posible cambio de objeto de diseño

Los profesores guía mencionaron informalmente la posibilidad de que el objeto de diseño de referencia del proyecto pase de un misil (geometría actual, Nalci & Kayran 2014) a un UAV sobre el que ya trabaja el laboratorio, para dar mayor coherencia entre el banco de ensayos y las líneas de trabajo activas del grupo. **Esta posibilidad se registrará y confirmará formalmente en la reunión de avance del 28/08/2026** (ver pregunta 3, `00_Administración/02_Registro_Reuniones_Avance.md`). De concretarse, este documento (geometría, escala, hallazgos de §5–§7) se archivaría como referencia metodológica — el procedimiento (extracción de geometría de la fuente, generación de perfil, análisis XFLR5, verificación de escalado) seguiría siendo directamente reutilizable con la nueva geometría de referencia.

## 10. Próximos pasos

1. **Confirmar en la reunión del 28/08/2026** (i) la parametrización de ángulo único vs. AoA+deflexión separados (§6), y (ii) si se mantiene o cambia el objeto de diseño de referencia (§9).
2. **Definir la matriz de casos CFD** (Mach, ángulo total, velocidad angular) — Fase B1 del cronograma, ahora informada por §5–§7 de este documento.
3. **Cerrar el factor de escala** en conjunto con el paso 2, verificando que el torque de bisagra resultante caiga dentro de RNF-CAR-01 (~0,5–2 N·m) — rango de partida actualizado a λ≈0.49–0.77 (§5), sujeto a revisión.
4. Una vez cerrada la escala (y confirmado el objeto de diseño), **confirmar la geometría física final** de la aleta impresa (espesor ajustado por fabricabilidad, punto de fijación del collar sobre el eje de 5 mm).
5. Actualizar este documento, `06_Seleccion_Actuador_de_Carga.md` y `03_Requisitos_No_Funcionales.md` con el valor de escala confirmado, retirando la marca "PENDIENTE".

## 11. Referencias citadas en esta decisión

- Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, Middle East Technical University. Supervisor: Prof. Dr. Altan Kayran. Disponible en: https://etd.lib.metu.edu.tr/upload/12615904/index.pdf
- Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055. DOI: 10.2514/6.2014-2055
- Barlow, J. B., Rae, W. H., & Pope, A. (1999). *Low-Speed Wind Tunnel Testing* (3rd ed.). John Wiley & Sons.
