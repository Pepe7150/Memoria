# Geometría de la Aleta de Referencia (CFD)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Decisión de **perfil y planta cerrada** (doble cuña, trapezoidal, proporciones tomadas de literatura). **Escala absoluta (factor de escalado lineal) PENDIENTE** — a definir junto con la matriz de casos CFD (Fase B1 del cronograma), de modo que el torque de charnela resultante caiga dentro del rango objetivo de RNF-CAR-01 (~0,5–2 N·m).

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `03_Requisitos_No_Funcionales.md` (RNF-CAR-01), `06_Seleccion_Actuador_de_Carga.md`, `07_Valores_Referencia_Literatura_Analoga.md`, `02_Literatura/resumen_referencias.md` (Tema 3, referencia 4).

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
| Torque de charnela de diseño (máximo) | 6 N·m |
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

## 5. Escala absoluta — PENDIENTE

El tamaño absoluto de la aleta (y por tanto de la geometría CFD) no se fija en esta decisión. Queda explícitamente abierto por la siguiente razón:

El torque de charnela escala aproximadamente con el cubo del factor de escala lineal si se mantienen las mismas condiciones de vuelo (M ∝ q·S·c̄, con S ∝ λ² y c̄ ∝ λ). Sin embargo, el proyecto **no está obligado a replicar la envolvente de vuelo de la referencia** (Mach 0,4–0,6, nivel del mar a 5000 m) — el rango de Mach/ángulo de ataque/deflexión de las simulaciones CFD propias es una decisión independiente (Fase B1 del cronograma, "Definición de casos de simulación").

Esto significa que **escala geométrica y matriz de casos CFD están acopladas**: un mismo torque objetivo (0,5–2 N·m, RNF-CAR-01) puede alcanzarse con una aleta más grande a menor presión dinámica, o una aleta más pequeña a mayor presión dinámica. Fijar la escala hoy, antes de definir el rango de Mach/AoA, sería una decisión sin verificación.

**Se registra como hipótesis de trabajo no confirmada** (solo a modo de referencia para dimensionar el acople mecánico en paralelo, no como valor cerrado): un factor de escala del orden de 1/4 respecto a la referencia (envergadura ≈ 37,5 mm, cuerda de raíz ≈ 39 mm, cuerda de punta ≈ 19,5 mm) fue mencionado como punto de partida razonable por tamaño de banco, pero **no está validado contra ninguna matriz de casos CFD todavía**.

## 6. Impacto sobre otros documentos del proyecto

| Documento | Estado |
|---|---|
| `03_Requisitos_No_Funcionales.md` (RNF-CAR-01) | Sin cambios por ahora; el rango de torque (~0,5–2 N·m) sigue siendo la restricción que la escala de la aleta deberá satisfacer una vez cerrada. |
| `05_Arquitectura_del_Sistema.md` | Sin cambios; la aleta física sigue descrita como "elemento representativo de prueba, de geometría genérica" (supuesto 3) — esta decisión aporta el perfil y planta concretos que llenan ese rol, sin contradecir la naturaleza genérica declarada. |
| Diseño mecánico (CAD, Fase C del cronograma) | **Parcialmente desbloqueado**: perfil y proporciones ya permiten avanzar bocetos, pero el modelo dimensionado final de la aleta física depende de que se cierre la escala (sección 5). |
| Metodología CFD (Fase B) | Esta geometría (con su escala aún pendiente) es el insumo directo para B1 ("Definición de casos de simulación"). |

## 7. Próximos pasos

1. **Definir la matriz de casos CFD** (Mach, ángulo de ataque, deflexión) — Fase B1 del cronograma.
2. **Cerrar el factor de escala** en conjunto con el paso 1, verificando que el torque de charnela resultante caiga dentro de RNF-CAR-01 (~0,5–2 N·m).
3. Una vez cerrada la escala, **confirmar la geometría física final** de la aleta impresa (espesor ajustado por fabricabilidad, punto de fijación del collar sobre el eje de 5 mm).
4. Actualizar este documento y `06_Seleccion_Actuador_de_Carga.md` / `03_Requisitos_No_Funcionales.md` con el valor de escala confirmado, retirando la marca "PENDIENTE".

## 8. Referencias citadas en esta decisión

- Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, Middle East Technical University. Supervisor: Prof. Dr. Altan Kayran. Disponible en: https://etd.lib.metu.edu.tr/upload/12615904/index.pdf
- Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055. DOI: 10.2514/6.2014-2055
