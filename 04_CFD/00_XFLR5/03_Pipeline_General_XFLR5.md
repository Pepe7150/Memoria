# Pipeline general XFLR5 para tablas de carga de contingencia

**Propósito.** Procedimiento único y reutilizable para construir en XFLR5 una tabla estática de momento de bisagra como *fallback* de la CFD. No sustituye la CFD viscosa, ni representa la velocidad angular de deflexión. El documento termina con un checklist completamente cargado para el caso NACA 0012 de Simpson (2016).

**Alcance de la salida.** El resultado es una tabla de contingencia en variables estáticas: condición de flujo, ángulo y deflexión (cuando la geometría permite distinguirlos). Debe rotularse siempre como `XFLR5 - contingencia - no CFD`.

---

## 0. Antes de abrir XFLR5: definir el caso

Completar esta ficha. Si un dato no está respaldado por la fuente, marcarlo como pendiente; no reemplazarlo por una suposición silenciosa.

| Campo             | Valor a definir                                                             |
| ----------------- | ----------------------------------------------------------------------------- |
| Fuente y versión | Autor, año, tabla/figura/página                                           |
| Configuración    | Aleta aislada, semiala con plano de simetría, estabilizador completo, etc. |
| Perfil(es)        | Nombre o archivo `.dat`; espesor y curvatura                               |
| Planta            | Cuerda(s), envergadura, barrido, torsión y superficies móviles            |
| Eje de bisagra    | Posición `x/c`, `z/c` y extensión en envergadura                       |
| Condiciones       | Mach, Reynolds o propiedades atmosféricas, altitud/temperatura/presión    |
| Matriz            | Valores de AoA, deflexión y, si corresponde, otros parámetros estáticos  |
| Escala física    | Dimensiones reales a simular en XFLR5 y razón para elegirlas               |
| Objetivo          | Prueba de software, orden de magnitud, o comparación con CFD/experimento   |

### Regla de compatibilidad

- **Aleta aislada:** AoA del vehículo y giro de la aleta se reducen a un único ángulo total. Usar un `Wing` con `isFin=true`; no un `Plane` duplicado en espejo.
- **Semiala experimental con pared de simetría:** puede representarse como estabilizador completo simétrico sin fuselaje, o como media geometría con la condición de simetría equivalente si la versión de XFLR5 lo permite. Declarar cuál de ambas se usó.
- **Estabilizador/ala completa:** no convertirla arbitrariamente en una aleta aislada: se pierden la simetría y los efectos tridimensionales que la fuente estudia.
- **Deflexión dinámica:** XFLR5 no la cubre. Mantenerla fuera de la tabla XFLR5 y documentarla como exigencia exclusiva de CFD no estacionaria.

---

## 1. Elegir la rama del análisis

| Geometría y objetivo                                                            | Rama XFLR5                                        | Razón                               | Limitación principal                                                      |
| -------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------ | -------------------------------------------------------------------------- |
| Perfil delgado, doble cuña o borde de ataque agudo; no hay polar viscosa fiable | Paneles 3D, inviscid                              | Conserva espesor y geometría        | Sin capa límite, separación ni corrección de compresibilidad verificada |
| Perfil redondeado y rango de Reynolds donde XFoil converge                       | XFoil viscoso 2D + VLM 3D con corrección viscosa | Incluye polares viscosas seccionales | VLM representa la línea media; no conserva el espesor 3D                  |

No llamar a la primera rama "más precisa". Para bordes agudos en subsónico, se elige porque una polar viscosa no convergente sería menos defendible. Para un NACA 0012, comenzar por la rama viscosa y conservar una corrida inviscid de paneles 3D como comparación de sensibilidad.

---

## 2. Preparar el perfil y la superficie móvil

### 2.1 Perfil

1. Si el perfil es NACA de cuatro o cinco dígitos, usar `Direct Foil Design -> Foil -> NACA Foils` y guardar el perfil generado.
2. Si la fuente entrega coordenadas, importarlas como `.dat` en formato Selig y verificar visualmente borde de ataque, borde de salida y espesor.
3. Si el perfil es doble cuña u otro perfil no nativo, generar/importar sus coordenadas y verificar el `t/c` calculado.

### 2.2 Superficie móvil y eje de bisagra — dos mecanismos distintos según el tipo de control

**No son intercambiables.** Cuál usar depende de si la superficie es totalmente móvil (todo el perfil rota) o un flap parcial de cuerda (solo la porción posterior rota):

| Tipo de superficie | Mecanismo en XFLR5 | Qué reporta como "momento" |
| --- | --- | --- |
| **Totalmente móvil** (ej. aleta que rota completa alrededor del eje del actuador) | Objeto `Wing` con `isFin=true`; el "ángulo" barrido en el polar ES la deflexión completa. El punto de referencia del momento se fija en la pestaña **Inertia** del wing (`X_cog`, `Z_cog` = posición del eje de bisagra). | `Cm` del wing completo — correcto porque toda la superficie es "el control" |
| **Flap parcial de cuerda** (ej. elevador de 25% de cuerda con eje de bisagra fijo) | Herramienta **`TE Flap`** en `Direct Foil Design`: columnas `TE Flap (°)`, `TE XHinge`, `TE YHinge` en la tabla de perfiles. Esto **hornea la deflexión en la geometría** del perfil (crea un perfil nuevo, deflectado). | `Cm` del wing completo **NO sirve** — mezcla la contribución del 75% delantero, que no es parte del control. Hay que leer **`HMom`** (Hinge Moment), un output separado que XFLR5 calcula usando el hinge guardado como metadata del perfil |

**Por qué importa la distinción:** el momento de bisagra real es la integral de presión **solo sobre la porción aft del eje** — no el momento de todo el perfil transferido a ese punto. Para una superficie totalmente móvil ambas cosas coinciden (no hay "porción delantera" que excluir); para un flap parcial, no. Confundir esto fue exactamente el error a evitar en el caso de contingencia con flap parcial (ver checklist Simpson, más abajo).

**Verificación del punto de referencia (aplica a ambos mecanismos):** correr un punto de operación con dos configuraciones de hinge/CoG distintas. Si el momento reportado (`Cm` o `HMom`, según el caso) no cambia entre ambas, el punto de referencia no se está aplicando — hay que revisar la configuración antes de confiar en ningún resultado.

---

## 3. Construir la geometría 3D

1. Crear el tipo de objeto según la regla de compatibilidad de la sección 0 (`Wing` aislado con `isFin=true`, o un `Wing`/`Plane` simétrico según corresponda).
   - **Ojo con `Plane`:** un objeto `Plane` siempre asume dos semi-alas respecto a un fuselaje central — no se puede desactivar esa duplicación desmarcando "Symmetric". Para una superficie verdaderamente aislada, usar `Define (Advanced users) -> isFin=true` sobre un `Wing`, no crear un `Plane`.
   - **Si la fuente ensayó una semi-envergadura** (modelo contra pared de túnel, como es común en ensayos de estabilizadores), usar un `Wing` con **Symmetric** activado y **Right Side** — XFLR5 duplica automáticamente la otra mitad para el cálculo, pero como los coeficientes son adimensionales, cada mitad reporta el mismo valor por simetría (ver §6, verificación).
2. Ingresar cada sección con sus coordenadas, cuerda, offset por barrido, diedro y perfil correspondiente. El **offset** que genera la flecha se calcula como `offset = semienvergadura × tan(flecha)`.
3. Verificar analíticamente área de referencia `S`, cuerda media aerodinámica `c̄` y envergadura antes de correr polares:
   - Planta rectangular sin taper: `S = b·c`, `c̄ = c`.
   - Planta trapezoidal: `S = envergadura·(c_raíz+c_punta)/2`, `c̄ = (2/3)·c_raíz·(1+λ+λ²)/(1+λ)` (`λ` = razón de estrechamiento).
   - Si el valor reportado por XFLR5 no coincide, revisar unidades y filas de la tabla de secciones antes de continuar — un error aquí se propaga silenciosamente a todos los resultados dimensionales.
4. Refinar paneles cerca del borde de ataque, punta, eje de bisagra y superficie móvil. Guardar el proyecto `.xfl` antes de las corridas.

---

## 4. Preparar las polares viscosas (solo rama viscosa)

1. En XFoil/XFLR5, crear una polar **viscosa** por perfil (incluyendo cada variante deflectada, si se usó `TE Flap`) y por Reynolds relevante.
2. Usar `Re = ρ·V·c/µ`, con la cuerda física de cada sección. Si cambian cuerda o escala, cambian Reynolds y potencialmente los coeficientes.
3. Activar la corrección de compresibilidad disponible solo dentro de su rango de validez y registrar la opción elegida.
4. Barrer el ángulo efectivo suficiente para cubrir AoA y deflexión de la matriz. No rellenar por extrapolación zonas donde XFoil no converge.
5. Asignar a cada sección su polar viscosa correspondiente y seleccionar VLM con corrección viscosa para el análisis 3D.

**Regla de escala:** con viscosidad no es válido resolver una geometría arbitraria y multiplicar luego el momento por `λ³`. Primero se define la escala física, luego se recalcula Reynolds y las polares.

**Error frecuente — Reynolds fuera de la envolvente de polares:** el log de la corrida 3D puede mostrar `Re = XXXXXXX is outside the flight envelope of polars` para cada punto de la envergadura. Esto significa que el Reynolds local real (calculado por XFLR5 a partir de densidad/velocidad/cuerda) no está cubierto por ningún polar 2D ya calculado. **Solución:** volver a `Direct Foil Design` y correr (o re-correr) los polares viscosos al Reynolds real de la condición de vuelo — idealmente dos polares que enmarquen ese valor (p. ej. Re=5,000,000 y Re=6,000,000 si el real es ~5,520,000), para que XFLR5 interpole en vez de depender de un único punto exacto.

---

## 5. Configurar y correr la matriz 3D

1. Crear una polar por combinación de condición de flujo y deflexión si la versión no permite incluir la deflexión como variable del barrido (si se usó `TE Flap` horneado por perfil, cada deflexión ya es una `Wing`/perfil distinto — no hace falta una variable adicional).
2. Usar `3D Panels` para la rama inviscid, o `VLM1/VLM2` con polares viscosas para la rama viscosa.
3. Ingresar condiciones atmosféricas coherentes:
   - Fijar por **Altitud + Temperatura** (no por densidad directa) — XFLR5 calcula `ρ` y `a` internamente.
   - **No asumir que XFLR5 sigue la fórmula ISA de libro.** Si se necesita verificar consistencia entre altitudes, usar siempre los valores de `ρ`/`a` que el propio programa reporta para cada condición, no una fórmula barométrica calculada aparte — se confirmó una discrepancia de ~14% entre ambas en una verificación cruzada.
   - Mach y Reynolds/velocidad no son independientes: comprobar que la combinación reproduzca los valores objetivo.
4. Barrer AoA o ángulo total usando exactamente los puntos de la fuente cuando el propósito sea comparativo.
5. **Límite de 100 puntos por polar (XFLR5 v6.61):** si `rango_total / Δ > 100`, dividir en 2+ sub-corridas (p. ej. -15° a 0° y 0.25° a 15°). Si se mantienen los demás parámetros idénticos entre sub-corridas, XFLR5 las concatena automáticamente en el mismo polar — no arrancar la segunda mitad repitiendo el punto central.
6. Exportar cada polar a CSV/Excel.

**Limitación importante del export estándar:** la exportación de "polar completo" (barrido de α) normalmente **no incluye** el momento de flap/hinge (`HMom`) — esa columna solo aparece al exportar **puntos de operación individuales** (`OpPoint`). Si se necesita el momento de bisagra de un flap parcial (§2.2), hay que exportar cada punto por separado, no el polar completo. Ver §7 para consolidar automáticamente muchos archivos de `OpPoint`.

### Controles de calidad obligatorios

| Control           | Qué revisar                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| Geometría        | `S`, `c̄`, barrido, eje de bisagra, orientación y signo de deflexión                     |
| Unidades          | m, s, kg y N·m; no mezclar pulgadas con milímetros                                               |
| Momento           | Punto de referencia exactamente en el eje de bisagra (§2.2) — verificar por sensibilidad, no asumir |
| Convergencia      | Mensajes de XFoil/XFLR5 (revisar el log completo), rango angular y resolución de paneles                                                   |
| Tendencia física | Linealidad solo lejos de pérdida; no marcar una no linealidad viscosa como error automático    |
| Comparación      | Usar los mismos Mach, Reynolds, ángulos, deflexiones y referencia de momento que CFD/experimento |

---

## 6. Verificaciones de sanidad sobre los resultados

Aplicar siempre, no solo en la corrida inicial:

| Verificación | Cómo | Umbral de alerta |
|---|---|---|
| Antisimetría | `M(-β) ≈ -M(β)` en todo el rango, no solo en los extremos (geometrías simétricas) | Error relativo > ~1% |
| Escalado con Mach | `M(Mach_a)/M(Mach_b) ≈ (V_a/V_b)²`, a igual condición atmosférica | Desviación > ~1% |
| Monotonía | En rama inviscid, `M(β)` debería ser estrictamente creciente, sin quiebres — en rama viscosa, la no monotonía cerca de pérdida es física, no un error | — |
| Invariancia de `Cm`/`Ch` con Mach | Rama inviscid: si no se activó compresibilidad, debería ser exactamente invariante — confirma que no hay corrección activa (una limitación a declarar, no a "arreglar"). Rama viscosa con compresibilidad activada: sí se espera variación real | — |
| Descomposición lineal (flap parcial) | Ajustar `Ch(α,δ) ≈ Ch_α·α + Ch_δ·δ` con los datos de varias deflexiones; la pendiente `Ch_α` debería salir muy similar entre deflexiones distintas | Pendientes muy dispares sin explicación física entre ellas |
| Simetría izquierda/derecha (wing simétrico) | Si se activó `Symmetric`, ambos lados deberían dar el mismo momento en ausencia de β o deflexión diferencial | Valores distintos → revisar si hay β≠0 accidental |
| Orden de magnitud vs. literatura | Comparar contra el valor de diseño o experimental de la fuente | Diferencia %>50-100% amerita revisar geometría/unidades antes de aceptar |

---

## 7. Consolidar resultados en una tabla

### 7.1 Caso superficie totalmente móvil (§2.2)

El polar completo exportado ya trae `Cm` correctamente referenciado — basta con un reshape de formato ancho (una columna por Mach) a formato largo (una fila por combinación Mach/ángulo).

### 7.2 Caso flap parcial de cuerda (§2.2) — requiere consolidar múltiples `OpPoint`

Como el momento de flap (`HMom`) solo aparece en exportaciones de punto individual, y se necesitan varios puntos (ángulos) × varias deflexiones, conviene automatizar la consolidación en vez de pegar archivos a mano. Un script robusto para esto debe:

- Leer **todos** los `.csv` de una carpeta, sin depender de sus nombres (los nombres de archivo de XFLR5 no son fiables como fuente de metadata — leer `alpha`, `delta`, `Cm`, `HMom` del **contenido** del archivo).
- Distinguir automáticamente entre archivos de `OpPoint` (tienen momento de flap) y de polar completo (solo para verificación cruzada de `Cm`).
- Calcular `Ch = H / (q·Sf·cf)` con la densidad, velocidad, cuerda de flap y área de flap del caso.
- Advertir explícitamente (no fallar en silencio) si algún archivo no tiene momento de flap detectado — la causa más común es que a esa configuración específica le faltó definir el hinge/flap antes de exportar.
- **Resolver rutas de carpeta relativas al directorio del propio script**, no al directorio desde el que se invoque `python` — evita el error típico de Windows/PowerShell donde el usuario ejecuta el script desde una carpeta distinta a donde están los `.csv`.

*(Ver script de referencia ya usado en este proyecto: `consolidar_oppoints_xflr5.py`.)*

---

## 8. Limitaciones del método — declarar siempre junto con cualquier resultado

1. **Rama inviscid:** no captura separación (crítico en bordes agudos a ángulos altos) ni arrastre viscoso. No es una "versión simplificada pero segura" del viscoso — es la alternativa más honesta cuando el viscoso no convergería a algo físicamente real (ver razonamiento completo en §8.1).
2. **Sin corrección de compresibilidad**, salvo que se haya activado explícitamente y verificado.
3. **Degeneración AoA/deflexión** en modelos de aleta aislada sin fuselaje — ambos ángulos son la misma variable física vista desde dos marcos de referencia.
4. **Sin velocidad angular de deflexión** — el método es estático/cuasi-estacionario; requiere CFD no estacionaria para esa dimensión.
5. **Bordes agudos y límite de convergencia** — en perfiles delgados de LE/TE agudo, ángulos altos pueden requerir mallado más fino o toparse con no convergencia.
6. **Rama viscosa, acoplamiento con la escala (λ):** el número de Reynolds depende de la cuerda física real. A diferencia de la rama inviscid, `Cm`/`Ch` **puede** cambiar con la escala — no asumir independencia sin verificar.
7. **VLM (rama viscosa) no conserva el espesor real** — reduce cada sección a su línea media. Es un costo aceptado a cambio de incorporar viscosidad; declarar el trade-off.

### 8.1 Por qué elegir inviscid no es "perder fidelidad" en perfiles de borde agudo

Un perfil con borde de ataque agudo (p. ej. doble cuña) en régimen subsónico separaría el flujo casi de inmediato ante cualquier ángulo distinto de cero, en la realidad física — no hay radio de curvatura que permita a la capa límite negociar el gradiente de presión. El solver de capa límite de XFoil está formulado asumiendo una capa límite delgada y adherida; al forzarlo sobre esta geometría, no falla por dificultad numérica en abstracto — falla (o converge a un resultado sin sentido) porque intenta resolver una condición física que no existe ahí. El modo inviscid, en cambio, tiene limitaciones que se pueden declarar con precisión. Por eso se prefiere, y por eso el dataset resultante debe tratarse como contingencia, no como sustituto de una CFD viscosa real con modelo de turbulencia apropiado para flujo separado.

**Esta limitación es específica del borde agudo — no generalizar.** Con un perfil de borde de ataque redondeado (NACA u otro), el análisis viscoso sí puede converger de forma confiable en un rango razonable de ángulos. Evaluar la elección de rama (§1) caso a caso, no por defecto.

---

## 9. Extensión a otras altitudes (post-procesamiento, sin nuevas corridas)

A Mach fijo, `q = ½ρV² = ½·ρ·(Mach·a)²` depende únicamente de `K(altitud) = ½·ρ(altitud)·a(altitud)²`. Si `Cm`/`Ch` ya se verificó independiente de Mach y el método es inviscid (sin dependencia de Reynolds), tampoco depende de la altitud. Por lo tanto:

```
M(Mach, ángulo, altitud) = Cm(ángulo) · K(altitud) · Mach² · S · c̄
```

**No se necesita correr una nueva matriz de ángulos por altitud** — solo el par `(ρ, a)` que XFLR5 reporta para la altitud/temperatura de interés (leído directamente del panel de condiciones de vuelo, sin correr ningún polar), aplicando el factor `K(altitud)/K(0)` a la curva ya calculada. **Usar siempre los `(ρ,a)` que XFLR5 reporta, no una fórmula atmosférica calculada aparte** (ver advertencia en §5).

**Chequeo de robustez recomendado (una vez por geometría, no por cada altitud de uso):** antes de confiar en el escalado, consultar `ρ` y `a` para 2-3 altitudes intermedias del rango de interés y confirmar que decrecen de forma monótona y sin saltos anómalos — no valida la física (garantizada por la formulación del método), valida que el modelo atmosférico interno de XFLR5 no tenga un comportamiento inesperado en el rango específico a usar.

**Limitación:** válido solo bajo inviscid. En CFD viscosa, Reynolds depende de la altitud a igual Mach, y `Cm` podría tener una dependencia real — no asumir que este atajo aplica sin verificación.

---

## 10. Checklist rápido para un caso nuevo

- [ ] Completar la ficha de la sección 0 con la fuente específica.
- [ ] Elegir rama (§1) según si el borde de ataque es agudo o redondeado — no por defecto.
- [ ] Generar/importar el perfil (§2.1); usar el generador nativo de NACA si aplica, ahorra un paso.
- [ ] Definir el mecanismo de superficie móvil correcto según el tipo de control (§2.2) — totalmente móvil (`isFin`+CoG) vs. flap parcial (`TE Flap`+`HMom`). Esta decisión teóricamente errónea invalida todo lo que sigue.
- [ ] Construir la geometría 3D (§3), verificando `S`/`c̄` analíticamente antes de correr nada.
- [ ] Si es rama viscosa: correr los polares 2D al Reynolds **real** de la condición de vuelo (no un valor de prueba) — evita el error de "Re fuera de la envolvente" en el análisis 3D.
- [ ] Definir el rango angular según el límite físico de la fuente (no asumir un rango genérico).
- [ ] Correr la matriz 3D, dividiendo en sub-corridas si se supera el límite de 100 puntos.
- [ ] Exportar: polar completo para `Cm`/verificación; puntos de operación individuales si se necesita `HMom` de un flap parcial.
- [ ] Aplicar las verificaciones de sanidad (§6) — no solo mirar si "el número se ve razonable".
- [ ] Consolidar con script (§7), verificando que resuelva rutas de forma robusta.
- [ ] Declarar explícitamente las limitaciones del método (§8) en cualquier documento que use estos resultados.
- [ ] Si se necesita extender a otras altitudes, aplicar el escalado analítico (§9) en vez de correr una matriz nueva.
