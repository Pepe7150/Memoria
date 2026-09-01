# Geometría de la Aleta/Superficie de Referencia (CFD)

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado (actualizado 28/08/2026):** **Geometría de referencia reemplazada.** El estabilizador en flecha con perfil NACA 0012 y elevador (flap) de Simpson (2016) — ya usado como caso de validación en el pipeline XFLR5 (`04_CFD/00_XFLR5/Simpson/NACA_0012/`) — pasa a ser la **geometría de referencia activa** del proyecto para CFD, reemplazando la aleta doble cuña de Nalci & Kayran (2014) que este documento describía anteriormente. Este cambio resuelve, como efecto directo, la pregunta que este documento dejaba abierta sobre degeneración AoA/deflexión (§6 antigua): al ser una configuración de **ala con flap parcial de cuerda**, y no una aleta aislada tipo misil, AoA y deflexión **son variables físicamente distintas y se mantienen separadas** — consistente con el acuerdo #2 de la reunión de avance del 28/08/2026 ("Ala con flap, AoA y deflexión separados", ver `00_Administración/02_Registro_Reuniones_Avance.md`).

**Qué se mantiene y qué se reemplaza:**

- **Se reemplaza** como geometría de referencia para la matriz de casos CFD (Fase B1) y para el dimensionamiento final del actuador de carga: la geometría de Nalci & Kayran (§ antigua 3–5 de este documento).
- **Se mantiene como antecedente metodológico** (no como geometría vigente): el ejercicio de validación de flujo potencial en XFLR5 sobre Nalci & Kayran (`04_CFD/00_XFLR5/02_Valores_Referencia_XFLR5.md`) sigue siendo válido como prueba del pipeline de software y como referencia de método de escalado (λ³), pero **no debe usarse ya para fijar el rango de torque final del banco**, dado que la geometría física de origen ya no es la del proyecto.
- **Se mantiene sin cambios:** todo el trabajo de validación del método XFLR5 realizado sobre el caso Simpson NACA 0012 y el caso Simpson GA(W)-1 (`04_CFD/00_XFLR5/Simpson/`), ya que ambos usan precisamente la geometría que ahora se adopta como referencia.

**Documentos relacionados:** `01_Especificacion_del_Proyecto.md`, `03_Requisitos_No_Funcionales.md` (RNF-CAR-01), `06_Seleccion_Actuador_de_Carga.md`, `07_Valores_Referencia_Literatura_Analoga.md`, `04_CFD/00_XFLR5/Simpson/NACA_0012/01_Checklist_Simpson_NACA0012.md`, `04_CFD/00_XFLR5/02_Valores_Referencia_XFLR5.md` (antecedente metodológico, geometría superada), `00_Administración/02_Registro_Reuniones_Avance.md`.

---

## 1. Objeto de la decisión

La superficie que se **simula en CFD** (fuente de la tabla de carga que consume el banco) y la aleta **física impresa** que se monta en el eje del banco son conceptualmente distintas, aunque comparten la misma geometría de referencia por trazabilidad:

- La aleta física **no recibe carga aerodinámica real** (no hay túnel de viento asociado al banco, ver `01_Especificacion_del_Proyecto.md`, sección "No incluye"). Su función es servir de punto de medición del ángulo real (encoder) y de fuente de inercia/dinámica que el actuador bajo prueba debe vencer.
- En consecuencia, el **espesor y tamaño de la pieza física puede ajustarse libremente por razones de fabricabilidad** (impresión 3D en PLA) sin afectar la validez del modelo CFD, que sí debe respetar el perfil y la planta aerodinámica reales para calcular el torque de bisagra.
- Ambas geometrías comparten perfil, proporciones y ubicación del eje de bisagra de referencia; pueden divergir en escala y espesor absoluto de la pieza impresa.

## 2. Fuente de referencia (geometría vigente)

Se adopta como referencia geométrica el caso ya documentado y usado como validación del pipeline XFLR5 del proyecto:

> Simpson, C. D. (2016). *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics.* Tesis de maestría, University of Alabama. Capítulo 4 (geometría en Tabla 4.1, Figuras 4.1–4.2). Basado a su vez en el ensayo experimental de Johnson & Thompson (1950), túnel de alta velocidad Langley 7×10 ft.

Esta fuente ya se usó en profundidad para dos ejercicios de validación de XFLR5 (NACA 0012 3D en flecha, y GA(W)-1 2D — ver `04_CFD/00_XFLR5/04_Lecciones_Metodologicas_XFLR5.md`), lo que da una ventaja adicional sobre partir de una geometría no explorada aún: el pipeline de software ya está validado sobre esta geometría específica, incluyendo las correcciones de convención de signo/normalización documentadas en esas lecciones.

## 3. Geometría extraída de la referencia (caso NACA 0012, Simpson 2016)

| Parámetro                                      | Valor (Simpson 2016, Tabla 4.1)                                                                                              |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Cuerda de sección (normal al borde de ataque)  | 15 in =**381 mm**, constante (sin taper)                                                                               |
| Semi-envergadura                                | 31.53 in =**800.9 mm**                                                                                                 |
| Flecha (borde de ataque)                        | **45°**                                                                                                               |
| Perfil                                          | **NACA 0012** (t/c = 12%, borde de ataque redondeado)                                                                  |
| Cuerda del elevador (flap, % de cuerda)         | **25%**                                                                                                                |
| Eje de bisagra, coordenada x                    | x_h/c =**0.75**                                                                                                        |
| Eje de bisagra, coordenada z                    | z_h/c =**0.0**                                                                                                         |
| Reynolds de referencia (ensayo original)        | **5.52×10⁶**                                                                                                         |
| Mach de referencia (ensayo original)            | **0.5**                                                                                                                |
| Deflexiones ensayadas por la fuente             | δ ∈ {0°, -1.7°, -3.7°, -7.8°}                                                                                          |
| Ángulos de ataque ensayados por la fuente      | α ∈ {-8°, -6°, -4°, -2°, 0°, 2°, 4°, 6°, 8°}                                                                      |
| Configuración estructural del modelo de ensayo | Semi-envergadura (modelo contra pared de túnel), no estabilizador completo — XFLR5 lo representa con`Symmetric` activado |

**Nota sobre escala:** a diferencia de la geometría anterior (Nalci & Kayran, un misil escalado hipotéticamente por un factor λ desconocido), la geometría de Simpson corresponde a un **modelo de ensayo real de túnel de viento a escala conocida** (cuerda física 381 mm). Esto cambia la naturaleza del problema de escalado del proyecto — ver §5.

## 4. Decisión de perfil y planta (vigente)

Se adopta, para el modelo geométrico de la superficie de control del proyecto:

- **Perfil aerodinámico:** NACA 0012 (simétrico, borde de ataque redondeado, t/c=12%).
- **Forma en planta:** rectangular en cuerda (sin taper), con flecha de 45° en el borde de ataque, semi-envergadura de 800.9 mm.
- **Tipo de control:** elevador (flap parcial de cuerda, 25%), con eje de bisagra en x/c=0.75 — a diferencia de la geometría anterior (aleta totalmente móvil tipo `isFin`), este es un **flap parcial**, lo que exige el mecanismo `TE Flap` + `HMom` de XFLR5, no `isFin` (ver `04_CFD/00_XFLR5/03_Pipeline_General_XFLR5.md` §2.2).
- **Configuración de vehículo:** ala/estabilizador con flap — **no** una aleta aislada sin fuselaje. Esta es la diferencia estructural clave frente a la geometría anterior, y es la que resuelve la degeneración AoA/deflexión (ver §6).

## 5. Escala física del banco — estado del problema, redefinido

Con la geometría anterior (Nalci & Kayran), el problema de escala era: "¿qué fracción λ de una aleta de misil hipotética reproduce el rango de torque del banco (~0,5–2 N·m)?". Con la geometría de Simpson, el problema cambia de naturaleza:

- La geometría de Simpson **ya corresponde a un modelo físico real** (cuerda 381 mm, semi-envergadura 800.9 mm) usado en un ensayo de túnel de viento — no es una entidad hipotética que haya que escalar desde cero.
- **Aún no existe, en la documentación del proyecto, un cálculo de torque de bisagra en unidades absolutas (N·m) para esta geometría** a ninguna escala. El trabajo ya hecho en XFLR5 sobre este caso (`04_CFD/00_XFLR5/Simpson/NACA_0012/`) reporta y valida **coeficientes** (`Ch`, comparados contra la Fig. 4.6 de Simpson), no momentos dimensionales — a diferencia del ejercicio sobre Nalci & Kayran, que sí produjo una tabla de momentos en N·m (`02_Valores_Referencia_XFLR5.md`).
- Esto significa que el factor de escala λ para el banco (que relaciona la geometría de referencia con el tamaño de la aleta física a construir) **sigue pendiente de calcular**, pero ahora debe hacerse sobre la geometría de Simpson, no reutilizando el λ≈0,63 obtenido para Nalci & Kayran.

**Lo que sí es reutilizable de `02_Valores_Referencia_XFLR5.md`:** la ley de escalado `M_λ = λ³ · M_referencia` (Barlow, Rae & Pope, 1999) sigue siendo válida en general para flujo potencial invíscido; una vez que se calcule el momento dimensional de referencia para la geometría de Simpson (repitiendo el procedimiento de esa sección, pero con la nueva geometría), el mismo método de escalado aplica directamente.

**Pendiente concreto (no cerrado en este documento):**

1. Calcular el momento de bisagra dimensional (N·m) de la geometría de Simpson a su escala real (381 mm de cuerda), a las condiciones de Mach/AoA/deflexión relevantes para el banco — análogo a lo ya hecho para Nalci & Kayran en `02_Valores_Referencia_XFLR5.md`, pero repitiendo el cálculo sobre esta geometría.
2. A partir de ese valor, despejar el λ requerido para que el torque caiga dentro de RNF-CAR-01 (~0,5–2 N·m), siguiendo el mismo método analítico ya usado (§5 de `02_Valores_Referencia_XFLR5.md`).
3. Verificar si, dado que la cuerda real (381 mm) ya es de tamaño moderado, un λ cercano a 1 (aleta física de tamaño similar al modelo de ensayo) es viable dentro de las restricciones de espacio y costo del banco, o si de todas formas se requiere una reducción de escala significativa.

## 6. Degeneración AoA/deflexión — resuelta (ya no aplica a esta geometría)

**Antecedente (geometría anterior, ya superada):** con la aleta aislada de Nalci & Kayran (sin fuselaje ni otra geometría de referencia), AoA y deflexión eran indistinguibles — ambos ángulos miden la misma orientación relativa al flujo, y solo se separan cuando existe un tercer objeto (el fuselaje) contra el cual referenciar cada uno por separado.

**Con la geometría de Simpson (ala/estabilizador con flap), este problema no existe:** el modelo tiene una superficie de referencia (el ala/estabilizador) distinta de la superficie de control (el flap/elevador), por lo que el ángulo de ataque del ala y la deflexión del flap respecto a esa ala son, desde el principio, dos variables físicamente independientes — exactamente como se parametriza en los checklists de XFLR5 ya ejecutados (`01_Checklist_Simpson_NACA0012.md`, matriz α × δ) y como confirma el acuerdo #2 de la reunión del 28/08/2026.

**Esta sección deja de ser una pregunta abierta.** La estructura de tabla de carga con AoA y deflexión como variables separadas, ya reflejada en `02_Requisitos_Funcionales.md` (RF-CFD-02) y `05_Arquitectura_del_Sistema.md` (§2.1), es la vigente y no requiere revisión adicional por este motivo.

## 7. Velocidad angular de deflexión — sin cambios respecto al acuerdo del Avance I

El acuerdo del Avance I (21/08/2026) de incorporar la velocidad angular de deflexión como cuarta dimensión de la superficie de respuesta CFD se mantiene sin cambios con el reemplazo de geometría. Al igual que con la geometría anterior, **XFLR5 no puede proveer esta dimensión** (resuelve polares estáticos/cuasi-estacionarios; la tasa de deflexión es un efecto no estacionario fuera del alcance del método, ver Tema 1: Solarte-Pineda et al. 2026; Yan et al. 2023).

| Dimensión                      | ¿Cubierta por XFLR5 (geometría Simpson)? | Motivo                                                                       |
| ------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------- |
| Mach                            | Sí                                        | Barrido directo, Type 1 (Re/Mach fijos)                                      |
| Ángulo de ataque (AoA)         | Sí                                        | Variable independiente, barrida directamente                                 |
| Deflexión del flap             | Sí                                        | Variable independiente, mediante`TE Flap` (geometría horneada por perfil) |
| Velocidad angular de deflexión | **No**                               | Requiere CFD no estacionaria — mismo motivo que con la geometría anterior  |

**Conclusión (sin cambios respecto a la versión previa de este documento):** el dataset XFLR5 sobre la geometría de Simpson es, como máximo, una referencia de contingencia en **3 dimensiones** (Mach × AoA × deflexión) — una dimensión más que lo que ofrecía la aleta aislada de Nalci & Kayran (que colapsaba AoA y deflexión en una sola variable), pero sigue sin cubrir la velocidad angular, que exige la CFD propia no estacionaria (Fase B).

## 8. Impacto sobre otros documentos del proyecto

| Documento                                          | Estado                                                                                                                                                                                                                                                                                              |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `03_Requisitos_No_Funcionales.md` (RNF-CAR-01)   | Sin cambio de fondo; el rango de torque (~0,5–2 N·m) sigue siendo la restricción a satisfacer, ahora con la geometría de Simpson como fuente de cálculo.                                                                                                                                       |
| `02_Requisitos_Funcionales.md` (RF-CFD-02)       | Ya actualizado — confirma AoA y deflexión como variables separadas (acuerdo#2, 28/08/2026), consistente con §6 de este documento.                                                                                                                                                                |
| `05_Arquitectura_del_Sistema.md` (§2.1)         | Ya actualizado — nota de esta sección refleja la confirmación de AoA/deflexión separados.                                                                                                                                                                                                       |
| `04_CFD/01_Casos/03_Matriz_Casos_CFD_FaseB1.md`  | **Pendiente de actualizar** (próxima iteración): la matriz de casos propuesta ahí (rango angular ±15°, Mach 0.4/0.5/0.6, acoplamiento λ↔Reynolds) fue diseñada sobre la geometría de Nalci & Kayran y debe rehacerse considerando la geometría, rangos y escala de Simpson.         |
| `04_CFD/00_XFLR5/02_Valores_Referencia_XFLR5.md` | **Pendiente de marcar explícitamente** como antecedente metodológico sobre geometría superada — el documento en sí no requiere rehacerse (su análisis de flujo potencial sigue siendo válido como ejercicio), pero debe indicar que ya no es la fuente activa para fijar λ del banco. |
| Diseño mecánico (CAD, Fase C del cronograma)     | Sigue parcialmente desbloqueado a nivel de perfil/proporciones, pero la escala final de la aleta física depende de resolver §5 (pendiente) de este documento.                                                                                                                                     |
| Metodología CFD (Fase B)                          | Esta geometría —ya con perfil, planta y eje de bisagra cerrados— es el insumo directo para B1 ("Definición de casos de simulación"), una vez rehecha la matriz de §7 de este documento.                                                                                                       |

## 9. Nota sobre el antiguo objeto de diseño (misil → ala/estabilizador)

Este documento registraba anteriormente (§9 antigua) la posibilidad, mencionada informalmente por los profesores guía, de que el objeto de diseño de referencia pasara de un misil a un UAV/estabilizador del laboratorio. **Con la adopción de Simpson (2016) como geometría de referencia, ese cambio ya se concretó en la práctica**: la fuente actual es un estabilizador con flap, no una aleta de misil. La geometría de Nalci & Kayran (doble cuña, aleta aislada) queda archivada como **antecedente metodológico** — el procedimiento de extracción de geometría, generación de perfil y análisis XFLR5 desarrollado sobre ella sigue siendo directamente reutilizable (y de hecho ya se reutilizó sobre la geometría de Simpson), pero la geometría en sí ya no es la referencia activa del proyecto.

## 10. Próximos pasos

1. **Calcular el momento de bisagra dimensional de la geometría de Simpson** (Mach, AoA, deflexión relevantes) — ver §5, pendiente concreto ítems 1–2. Es el paso que actualmente bloquea cerrar el factor de escala λ para esta geometría.
2. **Rehacer `04_CFD/01_Casos/03_Matriz_Casos_CFD_FaseB1.md`** sobre la geometría y rangos de Simpson (Mach de referencia 0.5, Reynolds 5.52×10⁶, rango de deflexión y AoA de la Tabla 4.1) en lugar de los de Nalci & Kayran.
3. **Marcar `04_CFD/00_XFLR5/02_Valores_Referencia_XFLR5.md`** explícitamente como antecedente metodológico sobre geometría superada, no como fuente activa de λ.
4. Una vez cerrada la escala (§5), **confirmar la geometría física final** de la aleta/superficie impresa (espesor y tamaño ajustados por fabricabilidad, punto de fijación del collar sobre el eje de 5 mm) — este paso es análogo al que ya estaba pendiente con la geometría anterior, ahora aplicado a Simpson.
5. Actualizar este documento y `03_Requisitos_No_Funcionales.md` con el valor de escala confirmado una vez calculado.

## 11. Referencias citadas en esta decisión

- Simpson, C. D. (2016). *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics.* Tesis de maestría, University of Alabama. Disponible en: https://ir.ua.edu/items/b24e56da-42e8-45ef-861c-f32ff2a6d3e5
- Johnson, J. L., & Thompson, F. L. (1950). Ensayo experimental citado como fuente primaria de la geometría y datos de referencia en el Capítulo 4 de Simpson (2016).
- Barlow, J. B., Rae, W. H., & Pope, A. (1999). *Low-Speed Wind Tunnel Testing* (3rd ed.). John Wiley & Sons. *(ley de escalado M=λ³·M_ref, reutilizable sobre la nueva geometría — ver §5.)*

**Referencia histórica (geometría superada, mantenida por trazabilidad metodológica, no como fuente vigente):**

- Nalci, M. O. (2013). *Aeroservoelastic Modeling of a Missile Control Fin.* Tesis de maestría, Middle East Technical University. Supervisor: Prof. Dr. Altan Kayran. Disponible en: https://etd.lib.metu.edu.tr/upload/12615904/index.pdf
- Nalci, M. O., & Kayran, A. (2014). *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055. DOI: 10.2514/6.2014-2055
