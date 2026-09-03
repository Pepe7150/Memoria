# Estrategia de Medición/Estimación de Torque — Casos Estáticos y Dinámicos

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Propuesta de trabajo, no cerrada. Documento generado como insumo directo para la reunión de avance del viernes — ver §6 para los puntos concretos a presentar/preguntar a los profesores guía (Bernardo Hernández, Frank Tinnap).

**Origen:** continuación directa de la reevaluación del sensor de torque iniciada en la reunión del 28/08/2026 (acuerdo #4, `00_Administración/02_Registro_Reuniones_Avance.md`). Ese acuerdo objetó la celda de carga + brazo de palanca (`06_Seleccion_Actuador_de_Carga.md` §6.2) por no acompañar el cambio de ángulo de la aleta, y sugirió torquímetro o strain gauges como alternativas.

**Documentos relacionados:** `06_Seleccion_Actuador_de_Carga.md` (§6.2, en reevaluación), `05_Arquitectura_del_Sistema.md` (§2.4, §2.5, interfaces I-04, I-04b, I-05, I-10), `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-02, RNF-PRE-04, RNF-PRE-05, RNF-REN-03), `02_Requisitos_Funcionales.md` (RF-BAN-02, RF-BAN-06, RF-INS-01 a RF-INS-03), `00_Principios_Metodologicos.md`.

---

## 1. Motivación — por qué un solo sensor no basta

El banco debe reproducir y evaluar tanto **efectos estáticos** (torque de bisagra a deflexión y velocidad angular constantes) como **efectos dinámicos** (aceleración angular ≠ 0), incluyendo el caso de un comando de cambio de ángulo, que por definición implica movimiento del conjunto. Esto tiene dos consecuencias directas sobre qué se necesita medir:

1. **El actuador bajo prueba no siempre compensa completamente el torque de carga.** Hay condiciones (aceleración angular distinta de cero) donde el torque neto en el eje no es solo la diferencia estática entre ambos motores — hay un término inercial adicional (`J·α`) que ninguno de los dos motores "decide"; es una consecuencia de la dinámica del conjunto.
2. **Se necesita el torque de cada motor por separado, no solo el neto transmitido.** RF-BAN-02 (compensación activa de torque parásito) y RF-BAN-06 (detección de atasco mutuo) requieren, ambos, distinguir cuánto aporta el motor de carga y cuánto el actuador bajo prueba — no basta con conocer el torque que efectivamente llega a la aleta.

Ningún sensor único entrega esto de forma directa y confiable en todo el rango de operación (ver §2). La propuesta es fusionar tres fuentes de información complementarias mediante un filtro de Kalman.

## 2. Qué observa cada fuente, y qué no

| Fuente | Mide directamente | Limitación principal |
|---|---|---|
| Corriente del motor de carga (INA219, ya seleccionado, I-04b) | Torque en el rotor del DS3218 crudo, vía `T = Kt·I` | La relación corriente↔torque de salida se degrada por la fricción/backlash de la reductora (~236–250:1) — problema ya documentado en `Comparacion_Alternativas_Arquitectura_Fisica.md` §0 |
| Corriente del actuador bajo prueba (**sensor adicional, no instrumentado hoy**) | Torque en el rotor del MG996R | Mismo problema de reductora; además, hoy **no existe** un segundo INA219 asignado a este motor — RF-INS-03 lo deja como "cuando aplique", sin canal físico definido |
| Strain gauges en el eje intermedio (entre motor de carga y actuador bajo prueba, topología cara a cara) | Torque **transmitido** en ese punto del eje — medición directa, sin depender de ningún modelo de motor | No distingue por sí solo cuánto aporta cada motor individualmente; da el neto en ese punto |
| Encoder → aceleración angular (doble derivada de posición, o derivada simple si se usa IMU/giroscopio) | Torque inercial, vía `T = J·α` | La doble diferenciación numérica amplifica ruido más que la derivada simple ya señalada como riesgo en RNF-PRE-05 |

**Observación relevante para el diseño:** al montar los strain gauges directamente en el eje entre ambos motores, esa lectura por sí sola ya satisface razonablemente bien RF-INS-01 (torque transmitido). El valor añadido real de la fusión sensorial no es "obtener un torque" — es **separar la contribución de cada motor**, que es lo que efectivamente exigen RF-BAN-02 y RF-BAN-06.

## 3. Comparación de alternativas de sensor de torque en el eje

Esta sección retoma y cierra, a nivel de análisis, el ítem 10 pendiente de `06_Seleccion_Actuador_de_Carga.md` §6.

### 3.1 Torquímetro inline COTS (tipo Anastasopoulos & Hornung 2018)

El costo elevado de un torquímetro rotativo inline (HBM T20WN, Futek TRS605, y similares) no proviene principalmente del elemento sensor (puente de galgas), sino del mecanismo para extraer la señal de un eje que se asume en **rotación continua**: anillos rozantes (slip rings) o telemetría inductiva/inalámbrica.

**Punto clave para este proyecto:** el eje del banco no gira continuamente — oscila dentro de un rango angular acotado (±15° bajo la hipótesis Nalci & Kayran; considerablemente menor bajo la geometría vigente de Simpson, δ ∈ {0°, −1.7°, −3.7°, −7.8°}, ver `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` §3). Con rotación limitada **no se requiere slip ring**: el puente de galgas puede cablearse directamente con cable flexible, con holgura suficiente para el rango angular de operación — eliminando el componente que más encarece la alternativa COTS.

### 3.2 Strain gauges montados directamente sobre el eje intermedio (propuesta)

**Verificación de señal esperada.** Para un eje sólido en torsión, el esfuerzo cortante y la microdeformación a 45° son:

```
τ = 16·T / (π·d³)
ε(45°) = τ / (2·G)
```

Con `d = 5 mm` (eje intermedio ya definido, RNF-PRE-04) y acero (`G ≈ 80 GPa`):

| Torque | τ (esfuerzo cortante) | ε a 45° |
|---|---|---|
| 0,5 N·m (continuo mínimo, RNF-CAR-01) | ~20,4 MPa | ~127 µε |
| 2 N·m (pico, RNF-CAR-01) | ~81,5 MPa | ~509 µε |

Señal perfectamente medible con un puente completo (4 galgas a ±45°) y un amplificador de instrumentación estándar — del mismo orden de magnitud que la señal ya manejada con la celda de carga actual.

**Implicación sobre el material del eje:** a 2 N·m, el esfuerzo (~81 MPa) es significativo para un eje de 5 mm. Esto confirma —debe quedar explícito, no solo asumido— que el eje intermedio debe ser **metálico (acero), no impreso en PLA**, a diferencia de las piezas custom (collares, brazo, soportes) que sí se fabrican por impresión 3D.

**Ventaja de diseño adicional:** un puente completo montado a ±45° mide cortante puro por torsión y **rechaza automáticamente componentes de flexión y carga axial parásita** — a diferencia del esquema celda + brazo, que era muy sensible a desalineación (motivo original de RNF-PRE-04). Esto no solo iguala a la alternativa objetada; la mejora en un eje que antes era una fuente de riesgo reconocida.

### 3.3 Tabla comparativa

| Criterio | Torquímetro inline COTS | Strain gauges DIY sobre el eje |
|---|---|---|
| Resuelve la objeción del acuerdo #4 (seguir el ángulo de la aleta) | Sí | Sí |
| Requiere slip ring / telemetría | Sí (ahí concentra el costo) | **No**, por rango angular acotado |
| Costo estimado | Alto — previsiblemente excede RNF-COS-01 | Bajo — galgas + amplificador, compatible con COTS de bajo costo |
| Trabajo de instrumentación propio | Mínimo (producto llave en mano) | Requiere montar, pegar y calibrar el puente |
| Rechazo de cargas parásitas (flexión/axial) | Sí, por diseño del transductor | Sí, si el montaje a 45° es correcto |
| Riesgo técnico dominante | Bajo (producto terminado) | Medio — calidad del pegado/alineación de galgas |

**Conclusión preliminar (a validar con los profesores):** dado el presupuesto ya fijado (RNF-COS-01) y que el rango angular del banco es acotado (no rotación continua), strain gauges sobre el eje intermedio es la opción más consistente con las restricciones ya cerradas del proyecto. El riesgo se traslada de "¿alcanza el presupuesto?" a "¿el laboratorio tiene la destreza de montaje/calibración de galgas?" — punto a confirmar antes de cerrar la decisión.

## 4. Modelo dinámico propuesto para la fusión

Con el eje modelado como cuerpo rígido entre motor de carga y actuador bajo prueba (más la aleta), la ecuación de balance de torque es:

```
J_total · α = T_actuador − T_carga − T_fricción
```

**Estados propuestos para el filtro:** `[θ, ω, T_carga, T_actuador]` — alternativamente, tratando las estimaciones por corriente como mediciones con sesgo (bias) en vez de estados adicionales, según la formulación final que se elija.

**Mediciones disponibles en cada ciclo del lazo de control:**

- `θ` medido por encoder → `ω` por derivada simple (o directo, si se usa un giroscopio en la aleta, ver `Comparacion_Alternativas_Arquitectura_Fisica.md` §3).
- `T_shaft` (strain gauges) — actúa como **restricción algebraica** entre `T_carga` y `T_actuador` en cada instante; es el dato más informativo para el filtro, al no depender de ningún modelo de motor.
- `I_carga`, `I_actuador` → estimaciones ruidosas y potencialmente sesgadas de `T_carga` y `T_actuador` vía `T = Kt·I`.

## 5. Riesgos técnicos a resolver antes del diseño final del filtro

1. **El backlash es no lineal y no suave.** Un Kalman estándar asume dinámica razonablemente lineal y ruido gaussiano; el backlash de la reductora (DS3218 y MG996R) es una zona muerta discontinua. Sin modelarlo explícitamente (o usar un EKF con modelo de zona muerta), el filtro puede divergir o sesgarse justo en la región de mayor interés (inversión de sentido, bajo torque). **Acción previa recomendada:** caracterizar experimentalmente el backlash de ambos motores antes de comprometerse al diseño completo del filtro.
2. **Kt y J no están caracterizados todavía.** El Kt del motor DC crudo del DS3218 sigue pendiente de medición experimental (`08_Datasheet_Motor_DS3218.md` §4), y la inercia J de la aleta + acoples tampoco se ha calculado. El filtro rendirá mal con valores de datasheet aproximados — esto es, en la práctica, un **prerrequisito bloqueante** para afinar el KF, no solo un dato deseable.
3. **La aceleración por doble derivada del encoder será ruidosa.** Es el eslabón más débil de las tres fuentes. Si el ancho de banda del lazo termina cerca de RNF-REN-01 (preliminar, ~100–200 Hz), diferenciar dos veces una señal de posición discreta a esa frecuencia probablemente exigirá filtrado agresivo, que introduce retardo de fase — justo lo que penaliza el criterio "índice diez-diez" (`07_Valores_Referencia_Literatura_Analoga.md` §3). **Alternativa a evaluar:** un giroscopio en la aleta entrega velocidad angular directa sin derivar, reduciendo a una sola derivación (no dos) el camino hasta la aceleración.

## 6. Secuencia de implementación propuesta (aplicando `00_Principios_Metodologicos.md`)

Consistente con el principio ya formalizado del proyecto ("que funcione antes de que funcione bien", recomendación del profesor Tinnap, reunión 28/08/2026):

1. **Primero:** filtro simple (promedio ponderado o filtro complementario) entre strain gauge y corriente, sin modelo dinámico completo — cierra el lazo de estimación de torque de punta a punta cuanto antes.
2. **Después:** incorporar el término inercial (encoder → aceleración) una vez que J esté caracterizado experimentalmente.
3. **Recién entonces:** escalar a un EKF con modelo de backlash explícito, si el filtro simple muestra un error sistemático que el Kalman completo resolvería — no antes, para no invertir esfuerzo en un componente que el sistema, corriendo, podría no necesitar tal como se lo diseñó.

## 7. Cambio de instrumentación que esta estrategia implica

Para estimar `T_actuador` vía corriente, se requiere un **segundo sensor de corriente** (INA219 u otro) en el actuador bajo prueba (MG996R). Hoy solo está instrumentado el motor de carga (interfaz I-04b). Esto es una extensión concreta de RF-INS-03 y de la arquitectura de instrumentación (`05_Arquitectura_del_Sistema.md` §2.5), pendiente de formalizar como interfaz nueva si se confirma esta estrategia.

---

## 8. Puntos a presentar/preguntar en la reunión del viernes

1. **Cierre de la reevaluación del sensor de torque (acuerdo #4):** presentar la comparación de §3 (torquímetro inline vs. strain gauges sobre el eje) y la conclusión preliminar a favor de strain gauges, condicionada a la destreza de montaje disponible en el laboratorio. ¿Confirman esta dirección, o prefieren evaluar cotizaciones concretas de torquímetro antes de descartarlo por costo?
2. **Necesidad de un segundo canal de corriente** (actuador bajo prueba, no solo motor de carga) — confirmar si esto se considera dentro del alcance de instrumentación ya aprobado o si requiere justificación adicional de presupuesto/lead time.
3. **Estrategia de fusión sensorial (§4–§6):** presentar el enfoque de tres fuentes (corriente ×2, strain gauge, encoder) fusionadas por Kalman, y la secuencia incremental propuesta (§6) como aplicación directa del principio metodológico ya acordado. ¿Están de acuerdo con partir por el filtro simple antes de comprometerse al EKF completo?
4. **Priorización de la caracterización experimental pendiente (§5):** Kt del motor DC crudo, inercia J de la aleta, y backlash de ambas reductoras son, en la práctica, prerrequisitos del filtro. ¿Esto cambia la prioridad de tareas de la Fase C del cronograma (`00_Administración/01_Cronograma.md`), dado que hoy esa caracterización aparece como tarea de fondo, no como bloqueante explícito de otro entregable?
5. **Alternativa de IMU/giroscopio en la aleta (§5, punto 3):** retomar la pregunta ya abierta en `Comparacion_Alternativas_Arquitectura_Fisica.md` §3 — ¿se evalúa como reemplazo del encoder o como complemento específicamente para reducir el ruido de la estimación de aceleración que alimenta el filtro?

## 9. Impacto sobre otros documentos del proyecto (pendiente de propagar si se confirma esta dirección)

| Documento | Impacto |
|---|---|
| `06_Seleccion_Actuador_de_Carga.md` §6.2 | Reemplazar la selección de celda de carga por la decisión de strain gauges (o mantener torquímetro si la reunión lo prioriza), incorporando el cálculo de §3.2 de este documento. |
| `05_Arquitectura_del_Sistema.md` §2.4, §2.5, §3 | Nueva interfaz de corriente para el actuador bajo prueba; actualizar I-05 (torque medido) para reflejar que proviene de una estimación fusionada, no de una lectura directa de celda de carga. |
| `03_Requisitos_No_Funcionales.md` (RNF-CAR-01, RNF-PRE-02, RNF-PRE-04) | Revisar una vez confirmada la tecnología de sensor; RNF-PRE-04 probablemente se relaje al eliminar la dependencia del radio efectivo de un brazo externo. |
| `09_Verificacion_Mecanica_Brazo_Torque.md` | Si se confirma strain gauges, este documento (centrado en el brazo de palanca) deja de aplicar en su mayor parte — solo se mantiene reutilizable §4 (fijación de collares al eje), según ya lo anticipa su propia nota de estado. |
| `01_Cronograma.md` | Evaluar si la caracterización de Kt, J y backlash debe adelantarse en la Fase C, dado que ahora bloquea explícitamente el diseño del filtro de fusión, no solo el ajuste fino del control de corriente. |
