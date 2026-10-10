# Documentación técnica: campaña de CFD dinámica para momento de bisagra

> Documento vivo. Se va a ir corrigiendo y ampliando a medida que avanza la
> implementación. Cada sección tiene fecha de última revisión implícita en
> el estado del repo — si algo queda desactualizado, corregir aquí mismo.

---

## 1. Motivación

El barrido estático (Memoria, Sección CFD — δ × Mach × AoA, `run_sweep.py`)
entrega el momento de bisagra en condición **cuasi-estacionaria**: el flap
ya está en su posición final, el flujo ya se reorganizó completamente
alrededor de esa geometría, y no hay velocidad ni aceleración angular
involucradas.

Para dimensionar un actuador real hace falta algo distinto: **el momento
que el actuador tiene que vencer mientras se está moviendo**, no solo una
vez que llegó a su posición. Ese momento puede ser significativamente mayor
al valor estacionario correspondiente — el "pico dinámico" — por las dos
razones físicas descritas en la Sección 2.

---

## 2. Fenomenología de la aerodinámica no estacionaria

### 2.1 Efecto de masa aparente ("apparent mass" / "added mass")

Cuando una superficie acelera angularmente dentro de un fluido, no solo
tiene que vencer la resistencia aerodinámica "normal" — también tiene que
acelerar el fluido inmediatamente adyacente a ella. Esa reacción del fluido
sobre la superficie es proporcional a la **aceleración angular** del flap
($\ddot\delta$), no a su posición ni a su velocidad. Es un término
**no-circulatorio**: existe incluso en un fluido ideal sin generar
sustentación circulatoria.

Consecuencia práctica: el pico de momento de bisagra más agudo suele
aparecer justo en los instantes de **arranque y frenado** del movimiento
(donde $\ddot\delta$ es máxima), no necesariamente en el ángulo de
deflexión máximo.

### 2.2 Efecto Wagner (retraso de circulación)

Incluso en ausencia de aceleración, la parte **circulatoria** de la carga
aerodinámica no responde instantáneamente a un cambio de geometría. Cuando
el flap cambia de ángulo, la circulación alrededor del perfil se reorganiza
progresivamente, no de golpe. Esto se describe clásicamente con la
**función de Wagner** $\phi(s)$, que da la fracción de la sustentación
circulatoria "final" (la que tendría el caso estacionario equivalente)
alcanzada después de recorrer una distancia $s$ (en semicuerdas,
$s = \dfrac{2Ut}{c}$) desde el cambio brusco de ángulo. $\phi(s) \to 1$
asintóticamente, nunca de forma instantánea.

> Referencia clásica: Wagner (1925); tratamiento moderno en Fung,
> *An Introduction to the Theory of Aeroelasticity*, o Leishman,
> *Principles of Helicopter Aerodynamics* (cap. de aerodinámica no
> estacionaria).

### 2.3 Frecuencia reducida $k$

La aeroelasticidad clásica usa la **frecuencia reducida**
$k = \dfrac{\omega c}{2U}$ (con $\omega$ la frecuencia angular del
movimiento, $c$ la cuerda, $U$ la velocidad de la corriente libre) como el
parámetro que determina si los efectos no estacionarios importan:

- $k \lesssim 0.05$: el movimiento es lo bastante lento para que la
  hipótesis cuasi-estacionaria sea razonable (el barrido estático sería
  representativo).
- $k \gtrsim 0.05\text{-}0.1$: los efectos no estacionarios (masa aparente +
  retraso de Wagner) empiezan a ser relevantes y un barrido estático
  subestima el pico real.

Esto da una forma concreta de responder "¿qué tan rápido tiene que mover el
flap mi actuador para que esto importe?" — útil para decidir el rango de
tiempos de actuación $T$ a simular (Sección 5).

**(pendiente)**: calcular $k$ equivalente para los tiempos de actuación $T$
candidatos, una vez que se tenga un rango realista de velocidad de
actuador.

### 2.4 Separación dinámica ("dynamic stall") — nota para más adelante

Si en algún momento la campaña dinámica se extiende a AoA/δ altos (cerca de
donde el barrido estático ya mostraba señales de pérdida, ver análisis de
`verify_sweep.py`), entra en juego un tercer fenómeno: el desprendimiento
de flujo también tiene retraso respecto al caso estacionario equivalente
(dynamic stall), y puede producir picos de carga adicionales por formación
y desprendimiento de un vórtice de borde de ataque. Esto es
significativamente más difícil de capturar bien con RANS (se beneficia de
modelos tipo LES/DES). **No es el foco inicial de esta campaña** — se deja
anotado para si hace falta más adelante.

---

## 3. Por qué el barrido estático no alcanza

En términos simples: el barrido estático entrega $\phi(s\to\infty)$ para
cada combinación — el valor *asintótico*, sin aceleración angular. La
campaña dinámica busca resolver $\delta(t)$, $\dot\delta(t)$,
$\ddot\delta(t)$ explícitamente mediante una simulación transitoria con
malla en movimiento, capturando ambos efectos de la Sección 2 directamente
a través de las ecuaciones de Navier-Stokes no estacionarias (RANS
no-estacionario, vía PIMPLE) en vez de aproximarlos con teoría clásica.

---

## 4. Enfoque de CFD elegido

### 4.1 Solver transitorio: `pimpleFoam` en vez de `simpleFoam`

`simpleFoam` (usado en el barrido estático) resuelve un estado estacionario
por relajación iterativa — no tiene noción de tiempo físico real, solo de
"iteración hacia la convergencia". `pimpleFoam` resuelve las ecuaciones de
forma transitoria real (acoplando SIMPLE y PISO), con un paso de tiempo
físico $\Delta t$ — necesario para resolver $\delta(t)$ como una función
del tiempo real, no como un parámetro fijo del caso.

### 4.2 Malla dinámica: deformación (*morphing*) vs. *overset*

Dos formas de manejar una frontera que se mueve dentro de la malla:

- **Overset (chimera)**: el flap se malla de forma independiente y "flota"
  sobre una malla de fondo, intercambiando información por interpolación.
  Robusto para movimientos grandes, pero significativamente más complejo de
  configurar (`dynamicOversetFvMesh`, requiere `overPimpleDyMFoam` o
  equivalente).
- **Deformación de malla (*mesh morphing*)**: la malla se mantiene con la
  misma topología (mismas celdas, mismas conexiones) y solo se mueven las
  posiciones de los puntos, resolviendo un Laplaciano de desplazamiento
  (`displacementLaplacian`) que difunde el movimiento del flap suavemente
  hacia el resto del dominio (los puntos cerca del flap se mueven casi con
  él, los puntos lejos del flap casi no se mueven).

**Elegido: deformación de malla.** Para deflexiones moderadas (del orden de
las usadas en el barrido estático, ±10-20°), es más simple de configurar y
suficientemente robusto — el *overset* se reserva como alternativa si la
calidad de malla se degrada demasiado con ángulos grandes.

### 4.3 El gap de bisagra (prerrequisito geométrico)

La malla del barrido estático comparte un único punto entre `mainfoil` y
`flap` en la bisagra — válido ahí porque cada δ es una malla nueva y
watertight. Para que el flap **rote dentro de la misma malla**, ese punto
no puede pertenecer simultáneamente a una frontera fija (`mainfoil`) y una
móvil (`flap`). Se necesita un **gap físico explícito** desde la geometría
neutra (δ=0): dos puntos distintos (uno en cada superficie) separados por
una pequeña holgura, rellena de celdas de dominio fluido normales — no un
tratamiento especial, solo geometría que dé espacio para que el flap se
mueva sin que las mallas se toquen ni se crucen.

**Estado: implementado.** `naca0012_flap_geometry_gapped.py` genera
`mainfoil` y `flap` como dos polígonos cerrados independientes (gap inicial
de prueba: 1% de cuerda, `--gap 0.01` -- **(pendiente)** afinar este valor,
ver más abajo). `naca_mesh_gmsh_dynamic.py` los malla como dos agujeros
separados del dominio (en vez de un solo contorno partido), reutilizando el
mismo truco de la malla estática (spline de extradós + spline de intradós +
línea recta de cierre) para evitar auto-intersecciones en las esquinas
agudas -- acá cada polígono tiene su propia esquina de cierre en el lado de
la bisagra (el "gap cap"), y el flap además conserva la del borde de fuga
romo.

Validado con δ=0°, 10° y −15° (mallas limpias, sin warnings/errores de
Gmsh, gap mantenido sin traslape incluso con deflexión agresiva).

**(pendiente)**: afinar el tamaño del gap -- 1% de cuerda fue el valor de
partida para probar la mecánica de la malla, no una elección final. Lo
bastante chico para no alterar la aerodinámica de forma significativa, lo
bastante grande para que la malla no se degrade al rotar el flap en el
rango de δ de interés (falta correr el paso 2, `moveDynamicMesh`, para ver
si este valor aguanta el rango completo o hay que agrandarlo).

**Límite geométrico de deflexión con caras planas.** Al rotar el flap
alrededor de la bisagra, la esquina de su cara frontal (a distancia
$g/2$ de la bisagra y altura $h$ = semi-espesor local) se acerca al
mainfoil en el lado comprimido. Con las caras planas actuales, el flap
choca con el mainfoil cuando

$$\tan\left(\frac{\theta_{max}}{2}\right) = \frac{g/2}{h}
\quad\Rightarrow\quad \theta_{max} = 2\arctan\left(\frac{g}{2h}\right)$$

Para $g=0.01$ y $h \approx 0.036$ (NACA0012 en $x/c=0.7$):
$\theta_{max} \approx 15.7°$. Mucho antes de eso la malla ya sufre: a 10°
solo queda ~36% del gap original en el lado comprimido (la celdas ahí se
aplastan a un tercio de su ancho). `build_dynamic_move_case.py` imprime
esta holgura y avisa si baja del 30%.

**Alternativa si el paso 2 muestra deterioro excesivo: nariz redondeada
concéntrica.** Es lo que hacen las superficies de control reales: la cara
frontal del flap es un arco de círculo centrado en la bisagra y el
mainfoil tiene un "cove" cóncavo concéntrico. Con arcos concéntricos el
gap es *constante para cualquier δ* (el flap solo desliza tangencialmente),
las celdas del gap se cizallan en vez de comprimirse, y el rango de
deflexión deja de estar limitado por la geometría. Es un cambio de
geometría (arcos en vez de líneas de cierre en
`naca0012_flap_geometry_gapped.py` y `naca_mesh_gmsh_dynamic.py`), así que
solo conviene hacerlo si los resultados de `moveDynamicMesh` lo justifican.

---

## 5. Definición del movimiento prescrito

Rampa suave tipo coseno elevado (*smoothstep*), no un escalón — un cambio
instantáneo de ángulo implicaría velocidad angular infinita en $t=0$ y
rompería la malla de inmediato:

$$\delta(t) = \delta_{objetivo} \cdot \frac{1-\cos(\pi t / T)}{2}, \quad t \in [0, T]$$

con $\delta(t) = \delta_{objetivo}$ constante para $t > T$.

**$T$ = tiempo de actuación**, directamente relacionado a la velocidad del
actuador que se está dimensionando. La idea es correr varios valores de
$T$ (actuador rápido vs. lento) y ver cómo cambia el pico dinámico de
momento de bisagra según qué tan exigente sea el actuador elegido — esto
cierra el círculo de diseño entre "qué tan rápido necesito que se mueva" y
"qué tan fuerte tiene que ser el motor".

**(pendiente)**: rango de $T$ a explorar — depende de la velocidad angular
típica de actuadores candidatos para el banco de ensayos (°/s), que aún no
está definida.

### 5.1 Escalamiento del tiempo (importante)

La malla está en unidades de cuerda ($x_m = x_{real}/c_{real}$), pero se usa
la velocidad real y $\nu_{malla} = \nu_{real}/c_{real}$ (Sección 5.4 de
`DOCUMENTACION_CFD.md`). Para que las ecuaciones de Navier-Stokes sean
semejantes, el **tiempo** también debe escalarse. Con $\nabla_r =
\nabla_m / c_{real}$ y multiplicando la ecuación de cantidad de movimiento
por $c_{real}$:

$$c_{real}\,\frac{\partial u}{\partial t_{real}} + u\cdot\nabla_m u =
-\nabla_m \frac{p}{\rho} + \frac{\nu_{real}}{c_{real}}\nabla_m^2 u
\;\;\Rightarrow\;\; t_{OF} = \frac{t_{real}}{c_{real}}$$

Ejemplo: $T_{real}=0.05$ s con $c_{real}=0.2$ m → $T_{OF}=0.25$. Los
ángulos (grados) no se escalan; la velocidad angular real es
$\omega_{real} = \omega_{OF}/c_{real}$. Los coeficientes ($Ch_{hinge}(t_{OF})$)
siguen siendo adimensionales y el momento real se reconstituye igual que en
la campaña estática:
$M_{real}(t_{real}) = Ch_{hinge}(t_{OF}=t_{real}/c_{real})\cdot 0.5\rho U^2 c^2 b$.

Si se olvidara este escalamiento, la rampa correría 5× más rápido de lo
real (para $c_{real}=0.2$ m) y el pico dinámico saldría sobreestimado.
`build_dynamic_move_case.py` recibe los tiempos en segundos **reales** y
hace la conversión.

### 5.2 Convención de signo y eje

El caso es 2D en el plano x-y, así que el flap rota alrededor de **z**
(canal *yaw* de `tabulated6DoFMotion`; tabla en grados, valores totales).
δ positivo = flap hacia abajo = giro horario = rotación **negativa** alrededor
de +z, por lo que `yaw = -δ`. `check_flap_motion.py` mide la rotación real
de la malla movida y detecta errores de signo, de unidades (grados/radianes)
y de eje.

---

## 6. Glosario de términos y mecanismos de OpenFOAM

| Término / objeto | Qué es |
|---|---|
| `pimpleFoam` | Solver transitorio incompresible (PIMPLE = SIMPLE + PISO), resuelve con paso de tiempo físico real. |
| `dynamicMeshDict` | Diccionario (`constant/`) que define cómo se mueve la malla durante la simulación. |
| `dynamicMotionSolverFvMesh` | Tipo de malla dinámica que delega el movimiento a un *motion solver* (en este caso, `displacementLaplacian`). |
| `displacementLaplacian` | Motion solver que calcula el desplazamiento de cada punto de la malla resolviendo un Laplaciano, difundiendo el movimiento prescrito en la frontera hacia el resto del dominio. |
| `diffusivity inverseDistance` | Esquema de difusividad para `displacementLaplacian`: los puntos más cerca de la frontera móvil se mueven más, los lejanos casi nada. |
| `pointDisplacement` | Campo (en `0/`) que define, por cada punto de la malla, cuánto se desplaza. Las condiciones de borde ahí definen qué patches se mueven y cómo. |
| `solidBodyMotionDisplacement` | Tipo de condición de borde para `pointDisplacement`: mueve un patch entero como cuerpo rígido, según una `solidBodyMotionFunction`. |
| `solidBodyMotionFunction` | Define la cinemática del movimiento rígido (rotación/traslación) en función del tiempo. |
| `tabulated6DoFMotion` | Una `solidBodyMotionFunction` que lee una tabla tiempo→(traslación, rotación) desde un archivo -- la que se usaría para prescribir $\delta(t)$ de la Sección 5. |
| `moveDynamicMesh` | Utilidad de OpenFOAM que mueve la malla según `dynamicMeshDict` SIN resolver flujo -- para validar que la malla no se degrada/invierte antes de gastar cómputo en un caso con flujo. |
| Frecuencia reducida $k$ | $k = \omega c / (2U)$ -- parámetro que indica si los efectos no estacionarios son relevantes (Sección 2.3). |
| Función de Wagner $\phi(s)$ | Describe el retraso de la componente circulatoria de la carga aerodinámica tras un cambio brusco de ángulo (Sección 2.2). |
| Masa aparente / *added mass* | Componente no-circulatoria de la carga, proporcional a la aceleración angular del flap (Sección 2.1). |

---

## 7. Plan de implementación (roadmap)

1. ✅ **Gap de bisagra en la geometría** -- `naca0012_flap_geometry_gapped.py`
   + `naca_mesh_gmsh_dynamic.py` (scripts nuevos, separados de los
   estáticos). Ver Sección 4.3 y la bitácora de bugs (Sección 9) para el
   detalle.
2. 🔧 **Validar solo el movimiento de malla** (scripts listos, falta
   correrlos en el servidor): `build_dynamic_move_case.py` arma el caso
   (`dynamicMeshDict` + `0/pointDisplacement` + tabla `flapMotion.dat` con
   tiempo escalado), se corre `moveDynamicMesh` + `checkMesh -allTime`, y
   `check_flap_motion.py` verifica numéricamente rotación, signo y
   unidades. Criterios de aprobación: `checkMesh` sin celdas de volumen
   negativo en ningún tiempo, no-ortogonalidad/skewness razonables, y
   `check_flap_motion.py` en OK. **Nota**: la sintaxis de OpenFOAM v2012 se
   contrastó con documentación y la wiki ESI pero NO se pudo ejecutar en el
   entorno de desarrollo -- los primeros errores de `moveDynamicMesh` pueden
   requerir ajustes menores en los diccionarios.
3. **Un caso de prueba con `pimpleFoam`**: una sola rampa, un Mach, un AoA
   fijos -- validar que el caso corre, converge razonablemente, y que el
   momento de bisagra en función del tiempo se ve físicamente sensato
   (pico cerca del arranque/frenado del movimiento, como predice la
   Sección 2.1).
4. **Automatizar el barrido dinámico**: una vez validado el caso base,
   extenderlo a múltiples $T$ (velocidad de actuador) y, después,
   Mach/AoA -- siguiendo el mismo patrón de automatización que
   `run_sweep.py`, pero para casos transitorios.

---

## 8. Bitácora de bugs -- paso 1 (gap de bisagra)

1. **Doble reversión de orden en los puntos del flap**: al armar la
   secuencia de puntos del polígono del flap, se aplicó una reversión de
   orden dos veces por accidente (se cancelan entre sí), dejando extradós e
   intradós en el mismo sentido en vez de sentidos opuestos -- esto arma un
   recorrido que va y vuelve en vez de un polígono simple, generando
   auto-intersección al cerrarlo en Gmsh. Fix: una sola reversión en el
   extradós, ninguna en el intradós (el orden que entrega `build_side` ya
   era el correcto ahí).
2. **El filtro de puntos casi-duplicados podía generar un punto extra**: la
   función de filtrado agregaba el último punto original al final
   incondicionalmente, incluso si ya había quedado conservado por el filtro
   normal -- duplicándolo. Eso rompía `addSpline` en Gmsh (segmento final de
   largo ~cero) justo en el punto de corte de la bisagra del mainfoil. Fix:
   reemplazar el último punto conservado por el original exacto solo si no
   coinciden, en vez de agregarlo siempre.

---

## 9. Preguntas abiertas / pendientes

- [ ] Tamaño del gap de bisagra (Sección 4.3).
- [ ] Rango de $T$ a explorar, atado a velocidades de actuador candidatas
      (Sección 5).
- [ ] Resolución temporal ($\Delta t$) necesaria para resolver bien el
      transitorio -- criterio de Courant para `pimpleFoam`, a definir una
      vez que se tenga la malla con gap.
- [ ] Si vale la pena correr algún caso de validación cuasi-estacionario
      (T muy grande) y comparar contra el barrido estático existente, como
      chequeo de consistencia entre ambas campañas.
- [ ] Si el pico dinámico resulta mucho mayor al estático, decidir qué
      factor de margen aplicar al dimensionar el actuador (o si se diseña
      directo contra el valor dinámico).
