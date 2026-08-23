# Pipeline (variante): Perfil Redondeado + Análisis Viscoso en XFLR5

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Objetivo de este documento:** ejercicio exploratorio para entender qué cambia en el pipeline de `03_Pipeline_XFLR5_Tabla_Carga.md` (perfil doble cuña, modo inviscid) si en cambio se usa un perfil de borde de ataque redondeado (p. ej. NACA) en modo viscoso — útil como referencia si en algún momento el objeto de diseño cambia (p. ej. hacia el UAV mencionado por los profesores) y el nuevo perfil ya no tiene borde agudo.

**Estado:** Ejercicio metodológico. No está atado a la geometría actual del proyecto (Nalci & Kayran, doble cuña) ni reemplaza ningún resultado ya obtenido — es un "qué pasaría si" documentado para no tener que redescubrir el procedimiento si se necesita en el futuro.

**Antecedente en la literatura:** Simpson (2016) — ver `02_Literatura/resumen_referencias.md`, Tema 1, ref. 1 — es el antecedente más directo: compara Datcom, XFOIL (perfil grueso GA(W)-1) y CFD viscosa (Fun3D, incluyendo un caso NACA 0012), exactamente el tipo de comparación que este documento explora a menor escala con XFLR5.

---

## Resumen de las diferencias (tabla comparativa)

| Paso del pipeline | Doble cuña / inviscid (actual) | Perfil redondeado (NACA) / viscoso |
|---|---|---|
| 1. Generar perfil | Script Python propio (`generar_perfil_doble_cuna.py`), perfil no existe nativamente en XFLR5 | **No hace falta script.** XFLR5 tiene generador nativo de perfiles NACA (4 y 5 dígitos) en `Direct Foil Design` |
| 2. Análisis 2D del perfil | Se omite (no se corrió XFoil viscoso sobre el perfil aislado) | **Nuevo paso obligatorio:** correr el análisis viscoso de XFoil sobre el perfil 2D, especificando Reynolds |
| 3. Método de análisis 3D | Paneles 3D (con espesor, sin viscosidad) | **VLM** (con corrección viscosa vía polar 2D, pero sin espesor — ver limitación abajo) |
| 4. Variable nueva requerida | — | **Número de Reynolds** (por corrida) — depende de velocidad, altitud y **cuerda física real** (λ) |
| 5. Compresibilidad | No modelada (verificado: Cm idéntico entre Mach) | XFoil sí ofrece corrección de compresibilidad (Karman-Tsien) — Cm podría dejar de ser Mach-invariante |
| 6. Acoplamiento con λ | Ninguno (Cm es λ-independiente) | **Nuevo:** Reynolds depende de la cuerda física, por lo tanto de λ — ya no se puede correr "a escala de referencia y escalar después" sin más consideración |
| 7. Qué se gana | — | Arrastre real (Cd), ángulo de pérdida físico, efecto de la capa límite sobre Cm |
| 8. Qué se pierde | — | Modelado del espesor real en el análisis 3D (VLM reduce a línea media) |

---

## 1. Generar el perfil — más simple que antes

A diferencia del doble cuña (que no existe como opción nativa), XFLR5 genera perfiles NACA directamente:

`Direct Foil Design` → `Foil` → `NACA Foils` → ingresar el código (p. ej. `0012` para un perfil simétrico de 12% de espesor, o `2412` si se quiere algo de curvatura) → XFLR5 genera las coordenadas automáticamente.

**No se necesita el script Python de generación de coordenadas** — ese paso completo desaparece del pipeline.

## 2. Nuevo paso: análisis viscoso 2D del perfil (XFoil)

Antes de construir el wing 3D, corre el análisis viscoso sobre el perfil aislado:

- `Direct Foil Design` → `Polars` → `Define an Analysis`.
- **Tipo:** viscoso (activar XFoil, no solo geometría de paneles).
- **Número de Reynolds:** hay que definirlo explícitamente. Se calcula como `Re = ρ·V·c/μ`, usando la cuerda **física real** de la sección (raíz o punta) — es decir, ya depende de tu factor de escala λ, a diferencia del caso inviscid donde el resultado era independiente de la escala.
- **Mach:** aquí sí puedes activar la corrección de compresibilidad de XFoil (Karman-Tsien) si te interesa evaluar si aparece dependencia real con Mach (contrastando con el hallazgo de invariancia que obtuviste en el caso inviscid).
- **Rango de ángulo:** análogo al caso anterior, pero ahora es más realista esperar que el solver **no converja** más allá del ángulo de pérdida real del perfil — eso ya no es un problema a resolver (como sí lo fue el límite de 100 puntos), es información física (el ángulo donde XFoil deja de converger es, aproximadamente, tu ángulo de pérdida).

**Resultado de este paso:** una polar 2D (`Cl`, `Cd`, `Cm` vs. ángulo, a un Reynolds y Mach dados) — este es el insumo que usará el análisis 3D del siguiente paso.

## 3. Construir el wing 3D — cambia el método de análisis

**Aquí está el trade-off central de usar viscosidad dentro de XFLR5:** el método de **paneles 3D** (el que usamos para el doble cuña, porque preserva el espesor) **no** incorpora corrección viscosa de ningún tipo. Para que la viscosidad entre al análisis 3D, hay que usar **VLM** (`VLM1` o `VLM2`), que integra la polar 2D viscosa del paso anterior mediante teoría de franjas (cada sección del wing usa su polar local para obtener `Cl`, `Cd`, `Cm` en función del ángulo efectivo local).

**El costo:** VLM reduce cada sección a su **línea de curvatura media** — el espesor real (tan importante en el doble cuña) deja de estar representado geométricamente. Para un NACA de espesor moderado, esta pérdida suele ser menos grave que la que habría significado en el doble cuña (donde el espesor y las esquinas agudas eran la geometría misma) — pero sigue siendo una simplificación real que hay que declarar.

**Configuración:**
- Construir el `Wing` con `isFin=true` igual que antes (mismo criterio para evitar la duplicación de un `Plane`).
- En cada sección (raíz/punta), asignar el perfil NACA y **su polar viscosa ya calculada** (debe existir una polar por sección, a su propio Reynolds si las cuerdas son distintas — para un wing trapezoidal con taper, esto implica correr el análisis 2D del paso 2 **más de una vez**, una por cada Reynolds relevante, no solo una vez).
- Habilitar la opción de corrección viscosa en el análisis 3D (usa las polares asignadas).

## 4. Consecuencia importante: ya no hay independencia de escala (λ)

En el pipeline inviscid, un resultado clave era que `Cm` no dependía de Mach ni de la escala — permitiendo correr **una sola vez** a la escala de referencia (Nalci & Kayran) y aplicar `λ³` para cualquier tamaño físico del banco. **Esto deja de ser válido en modo viscoso**, porque el número de Reynolds depende de la cuerda física real:

```
Re = ρ · V · c_física / μ
```

Si cambias λ, cambias `c_física`, cambias `Re`, y **`Cm` podría cambiar** (el efecto suele ser pequeño para variaciones moderadas de Re, pero no está garantizado que sea despreciable — depende del perfil y de si el flujo está cerca de la transición laminar-turbulenta, ver el hallazgo de Sebastia & Hornung 2023 sobre la sensibilidad del momento de bisagra a la transición). **Consecuencia práctica:** con perfil viscoso, el análisis debería correrse a la escala física real del banco (o al menos verificar sensibilidad a Re antes de asumir independencia), no a una escala de referencia arbitraria como se hizo con el doble cuña.

## 5. Verificaciones — qué cambia

| Verificación (ver `03_Pipeline...md` §6) | En modo viscoso |
|---|---|
| Antisimetría | Sigue aplicando igual — un perfil simétrico (p. ej. NACA 0012) debería seguir dando `M(-β)≈-M(β)` |
| Monotonía | **Ya no se espera que se cumpla en todo el rango** — cerca del ángulo de pérdida, `Cm` (y `Cl`) puede volverse no monótono o incluso caer abruptamente; esto es física real, no un error, a diferencia de lo que habría sido una señal de alarma en el caso inviscid |
| Linealidad | Se espera **menos lineal** que el caso inviscid, especialmente cerca de pérdida — de nuevo, esperado, no un problema |
| Invariancia de Cm con Mach | **Ya no se espera que se cumpla** si activaste la corrección de compresibilidad — una diferencia real y esperable frente al caso inviscid |
| No convergencia | Ya no es solo un límite de "100 puntos" a resolver dividiendo el rango — la no convergencia cerca de pérdida es información física real sobre el límite del perfil, hay que distinguir esto de un problema numérico genuino (ej. mallado insuficiente) revisando el mensaje de log específico |

## 6. Qué preguntar/verificar antes de adoptar esto para el proyecto real

1. ¿El nuevo perfil de referencia (si el objeto de diseño cambia a UAV) es efectivamente de borde redondeado? Si sigue siendo un perfil delgado de borde agudo (poco probable en UAV subsónico, pero a confirmar), el modo inviscid seguiría siendo la opción más honesta, igual que con el doble cuña.
2. Si se adopta modo viscoso, decidir a qué Reynolds correr — esto requiere haber cerrado antes el factor de escala λ (o al menos una hipótesis de trabajo), rompiendo el orden de decisiones que se usó con el doble cuña (ahí se pudo posponer λ sin bloquear el análisis de forma).
3. Revisar si conviene comparar resultados de VLM+viscoso contra paneles 3D+inviscid en el mismo perfil NACA, como chequeo cruzado de cuánto cambia `Cm` por el espesor perdido — daría una idea cuantitativa del costo de ese trade-off para el perfil específico que se termine usando.

## 7. Referencias

- Simpson, C. D. (2016). *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics.* Tesis de maestría, Utah State University. (Ya catalogada en `resumen_referencias.md`, Tema 1, ref. 1 — antecedente directo de comparación Datcom/XFOIL/CFD sobre perfiles de borde redondeado, incluyendo NACA 0012).
- Sebastia Saez, C., & Hornung, M. (2023). *Numerical Analysis of Aerodynamic Flap Hinge Moment Under Unsteady Flow Conditions Considering Laminar-Turbulent Transition.* AIAA AVIATION Forum, AIAA 2023-3528. (No catalogada aún en la bibliografía del proyecto — evalúa CFD viscosa con transición sobre un perfil laminar con flap articulado; confirma que la transición laminar-turbulenta afecta el momento de bisagra de forma no despreciable, relevante si se decide usar modo viscoso).
