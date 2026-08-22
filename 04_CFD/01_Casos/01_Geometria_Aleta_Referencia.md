# Geometría de la Aleta de Referencia (CFD)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Decisión de **perfil y planta cerrada** (doble cuña, trapezoidal, proporciones tomadas de literatura). **Escala absoluta (factor de escalado lineal) PENDIENTE** — a definir junto con la matriz de casos CFD (Fase B1 del cronograma), de modo que el torque de charnela resultante caiga dentro del rango objetivo de RNF-CAR-01 (~0,5–2 N·m). **Actualización (acuerdos de Avance I):** la matriz de casos CFD de Fase B1 debe incorporar, además de Mach/ángulo de ataque/deflexión, un **rango de velocidades angulares de deflexión** como cuarta variable de entrada (ver `02_Requisitos_Funcionales.md`, RF-CFD-02).

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-05), `06_Seleccion_Actuador_de_Carga.md`, `07_Valores_Referencia_Literatura_Analoga.md`, `02_Literatura/resumen_referencias.md` (Tema 3, referencia 4).

---

## 1. Objeto de la decisión

La aleta que se **simula en CFD** (fuente de la tabla de carga que consume el banco) y la aleta **física impresa** que se monta en el eje del banco son conceptualmente distintas, aunque comparten la misma geometría de referencia por trazabilidad:

- La aleta física **no recibe carga aerodinámica real** (no hay túnel de viento asociado al banco, ver `01_Especificacion_del_Proyecto.md`, sección "No incluye"). Su función es servir de punto de medición del ángulo real (encoder) y de fuente de inercia/dinámica que el actuador bajo prueba debe vencer.
- En consecuencia, el **espesor de la pieza física puede ajustarse libremente por razones de fabricabilidad** (impresión 3D en PLA) sin afectar la validez del modelo CFD, que sí debe respetar el perfil aerodinámico delgado real para calcular el torque de charnela.
- Ambas geometrías comparten planta, proporciones y perfil de referencia; pueden divergir en espesor absoluto de la pieza impresa.

## 2. Fuente de referencia

Se utilizó como referencia geométrica la tesis de maestría detrás del paper ya catalogado en la revisión de literatura (Tema 3, ref. 4):

> Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, Middle East Technical University (METU). Supervisor: Prof. Dr. Altan Kayran.
> Versión publicada: Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055.

Se consultó el texto completo de la tesis (no solo el resumen ya incluido en `resumen_referencias.md`) para extraer valores geométricos concretos de la aleta modelada, dado que es la referencia más cercana al dominio específico del proyecto (misil, superficie de control, actuador electromecánico) identificada en la revisión bibliográfica.

## 3. Geometría extraída de la referencia

| Parámetro                                                                                   | Valor (Nalci & Kayran, 2014)                            |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Cuerda de raíz                                                                              | 156 mm                                                  |
| Cuerda de punta                                                                              | 78 mm                                                   |
| Envergadura                                                                                  | 150 mm                                                  |
| Razón de estrechamiento (taper ratio)                                                       | 0,5                                                     |
| Borde de fuga                                                                                | Recto (sin flecha)                                      |
| Flecha del borde de ataque                                                                   | ~27,5°                                                 |
| Perfil                                                                                       | Doble cuña (diamante), espesor variable en envergadura |
| Espesor en la raíz                                                                          | ~4 mm                                                   |
| Espesor en la punta                                                                          | ~2,2 mm                                                 |
| Relación espesor/cuerda (t/c)                                                               | ~2,4–2,8 %                                             |
| Torque de charnela de diseño (máximo)                                                      | 6 N·m                                                  |
| Envolvente de vuelo usada para dimensionar el actuador de la referencia                      | Mach 0,4–0,6, altitud 0–5000 m                        |
| Rigidez torsional del eje de montaje (dato estructural de la referencia, no aplica al banco) | 120 N·m/rad                                            |

**Nota:** la referencia no reporta explícitamente un rango de velocidades angulares de deflexión utilizado en su propio análisis aeroservoelástico; el valor de ~300°/s adoptado preliminarmente en RNF-REN-01 proviene de la misma fuente pero como límite dinámico del actuador, no como variable de barrido de la base de datos aerodinámica. La matriz de casos CFD propia del proyecto (sección 5) deberá definir su propio rango de velocidad angular de deflexión, sin asumir que coincide con ese valor.

## 4. Decisión de perfil y planta (cerrada)

Se adopta, para el modelo geométrico de la aleta del proyecto:

- **Perfil aerodinámico:** doble cuña, típico de superficies supersónicas de misil.
- **Forma en planta:** trapezoidal, con borde de ataque en flecha y borde de fuga recto.
- **Proporciones a mantener** (adimensionales, independientes de la escala absoluta):
  - Razón de estrechamiento: 0,5 (cuerda de punta = mitad de la cuerda de raíz).
  - Flecha del borde de ataque: ~27,5°.
  - Relación espesor/cuerda: ~2,4–2,8 %, decreciente de raíz a punta — **aplica al modelo usado en CFD**; la pieza física impresa puede apartarse de este valor por fabricabilidad (ver sección 1).

## 5. Escala absoluta — hipótesis λ≈1/4 DESCARTADA, nuevo rango en evaluación

**Actualización:** se obtuvieron valores de referencia de flujo potencial (XFLR5) sobre la
geometría a escala real (ver `04_CFD/02_Valores_Referencia_XFLR5.md` para la metodología
completa). Aplicando la ley de escalado M_λ = λ³·M_referencia (Barlow, Rae & Pope, 1999) a la
condición más exigente (β=15°, Mach 0.6, M_referencia=4.35 N·m):

- La hipótesis de trabajo λ≈1/4 da un momento de bisagra de solo ~0.068 N·m — muy por debajo
  del piso de RNF-CAR-01 (~0.5 N·m continuo). **Esta hipótesis queda descartada.**
- El rango de λ consistente con RNF-CAR-01 (0.5–2 N·m) es **λ ≈ 0.49–0.77**.

Este rango depende de haber usado β=15° (extremo del rango de Nalci & Kayran, pensado para un misil) como condición de diseño. Sigue **PENDIENTE** cerrar la escala definitiva, ahora condicionado a: (a) la matriz de casos CFD (Mach, ángulo de ataque, deflexión — Fase B1), y (b) la definición del contexto de aplicación final del banco (ver nota abierta sobre posible cambio de objeto de diseño hacia un UAV, que podría requerir rehacer este análisis con otra geometría/perfil/rango angular de referencia).

El tamaño absoluto de la aleta (y por tanto de la geometría CFD) no se fija en esta decisión. Queda explícitamente abierto por la siguiente razón:

El torque de charnela escala aproximadamente con el cubo del factor de escala lineal si se mantienen las mismas condiciones de vuelo (M ∝ q·S·c̄, con S ∝ λ² y c̄ ∝ λ). Sin embargo, el proyecto **no está obligado a replicar la envolvente de vuelo de la referencia** (Mach 0,4–0,6, nivel del mar a 5000 m) — el rango de Mach/ángulo de ataque/deflexión de las simulaciones CFD propias es una decisión independiente (Fase B1 del cronograma, "Definición de casos de simulación").

Esto significa que **escala geométrica y matriz de casos CFD están acopladas**: un mismo torque objetivo (0,5–2 N·m, RNF-CAR-01) puede alcanzarse con una aleta más grande a menor presión dinámica, o una aleta más pequeña a mayor presión dinámica. Fijar la escala hoy, antes de definir el rango de Mach/AoA, sería una decisión sin verificación.

**Se registra como hipótesis de trabajo no confirmada** (solo a modo de referencia para dimensionar el acople mecánico en paralelo, no como valor cerrado): un factor de escala del orden de 1/4 respecto a la referencia (envergadura ≈ 37,5 mm, cuerda de raíz ≈ 39 mm, cuerda de punta ≈ 19,5 mm) fue mencionado como punto de partida razonable por tamaño de banco, pero **no está validado contra ninguna matriz de casos CFD todavía**.

**Cuarta dimensión de la matriz (nuevo, acuerdos de Avance I):** la matriz de casos CFD de Fase B1 ya no se limita a barrer Mach × ángulo de ataque × deflexión; debe incorporar también un barrido de **velocidad angular de deflexión**, dado que ésta pasó a ser una variable de entrada obligatoria de la tabla de carga (RF-CFD-02) y no solo un dato de caracterización del actuador. Esto tiene dos implicancias prácticas para la definición de la matriz (aún no resueltas):

1. El número de simulaciones necesarias crece con la cuarta dimensión — refuerza la pertinencia de las estrategias de reducción de corridas ya identificadas en el Tema 1 de la literatura (Da Ronch et al. 2011; Allen & Ghoreyshi 2018; muestreo adaptativo), que ahora deben aplicarse sobre un espacio de 4 variables en vez de 3.
2. El rango de velocidad angular a barrer no puede fijarse arbitrariamente: debe ser consistente con (a) el ancho de banda dinámico objetivo del banco (~10 Hz, ver `07_Valores_Referencia_Literatura_Analoga.md` §3) y (b) el rango que el actuador bajo prueba pueda efectivamente alcanzar bajo carga, dato que en parte se obtendrá empíricamente mediante CU-010 (caracterización manual vía potenciómetro de ángulo objetivo) una vez que el banco esté operativo — lo que sugiere que este rango podría requerir una primera estimación conservadora y un ajuste posterior, en lugar de quedar cerrado antes de tener datos propios del banco.

## 6. Impacto sobre otros documentos del proyecto

| Documento                                               | Estado                                                                                                                                                                                                                                                            |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `03_Requisitos_No_Funcionales.md` (RNF-CAR-01)        | Sin cambios por ahora; el rango de torque (~0,5–2 N·m) sigue siendo la restricción que la escala de la aleta deberá satisfacer una vez cerrada.                                                                                                               |
| `03_Requisitos_No_Funcionales.md` (RNF-PRE-05, nuevo) | La resolución de medición de velocidad angular de la aleta debe ser consistente con el rango de velocidad angular que finalmente se adopte en la matriz de casos CFD (sección 5) — relación aún no cuantificada.                                            |
| `05_Arquitectura_del_Sistema.md`                      | Sin cambios de fondo; la aleta física sigue descrita como "elemento representativo de prueba, de geometría genérica" (supuesto 3) — esta decisión aporta el perfil y planta concretos que llenan ese rol, sin contradecir la naturaleza genérica declarada. |
| Diseño mecánico (CAD, Fase C del cronograma)          | **Parcialmente desbloqueado**: perfil y proporciones ya permiten avanzar bocetos, pero el modelo dimensionado final de la aleta física depende de que se cierre la escala (sección 5).                                                                    |
| Metodología CFD (Fase B)                               | Esta geometría (con su escala aún pendiente) es el insumo directo para B1 ("Definición de casos de simulación"), que ahora incluye explícitamente la dimensión de velocidad angular de deflexión.                                                          |

## 7. Próximos pasos

1. **Definir la matriz de casos CFD** (Mach, ángulo de ataque, deflexión **y velocidad angular de deflexión**) — Fase B1 del cronograma. Esta matriz creció de 3 a 4 dimensiones respecto a la versión previa de este documento.
2. **Cerrar el factor de escala** en conjunto con el paso 1, verificando que el torque de charnela resultante caiga dentro de RNF-CAR-01 (~0,5–2 N·m).
3. Una vez cerrada la escala, **confirmar la geometría física final** de la aleta impresa (espesor ajustado por fabricabilidad, punto de fijación del collar sobre el eje de 5 mm).
4. **Definir el rango de velocidad angular de deflexión** a barrer en CFD, considerando el ancho de banda objetivo del banco (~10 Hz) y, si están disponibles, datos preliminares obtenidos mediante caracterización manual del actuador (CU-010) — puede requerir una primera estimación conservadora sujeta a ajuste posterior.
5. Actualizar este documento y `06_Seleccion_Actuador_de_Carga.md` / `03_Requisitos_No_Funcionales.md` con el valor de escala y de rango de velocidad angular confirmados, retirando las marcas "PENDIENTE".

## 8. Referencias citadas en esta decisión

- Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, Middle East Technical University. Supervisor: Prof. Dr. Altan Kayran. Disponible en: https://etd.lib.metu.edu.tr/upload/12615904/index.pdf
- Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055. DOI: 10.2514/6.2014-2055
