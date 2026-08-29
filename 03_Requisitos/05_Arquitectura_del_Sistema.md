# Arquitectura del Sistema

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

> **Actualización (revisión de arquitectura mecánica):** el banco incorpora una **aleta física representativa** montada en el mismo eje que el actuador bajo prueba, enfrentada a un **motor de carga** que aplica el torque equivalente derivado de CFD. El torque objetivo se recalcula en tiempo real a partir de la posición angular *real* de la aleta (no de un perfil temporal fijo), cerrando un lazo posición→torque. Ver notas al final de cada sección afectada.
>
> **Actualización (cierre de interfaz I-03):** el comando de torque hacia el motor de carga (DS3218 intervenido) se formaliza como una señal **PWM** generada por el microcontrolador hacia un **driver H-bridge COTS**, con el **lazo de corriente cerrado en software** (no en hardware dedicado ni por bus de tiempo real). Ver sección 3 (tabla de interfaces) y sección 5 (supuesto 4).
>
> **Actualización (acuerdos de Avance I):** (1) la tabla de carga pasa a tener **cuatro** variables de entrada — Mach, ángulo de ataque, deflexión de la aleta **y velocidad angular de deflexión** —, por lo que el lazo posición→torque (I-10) se extiende a un lazo posición+velocidad→torque; (2) se incorpora un **panel de potenciómetros** con **dos funciones distintas**: (a) fijar en modo manual, mediante la interfaz **I-11**, los valores de Mach y ángulo de ataque consumidos por el módulo de interpolación (condiciones de vuelo simuladas, no medidas), y (b) **comandar directamente al actuador bajo prueba un ángulo de deflexión objetivo**, mediante la nueva interfaz **I-12**, análogo a un probador de servo manual — si el actuador logra o no ese ángulo bajo la carga aplicada es precisamente lo que se mide (RF-INS-02) para su caracterización, no algo que el potenciómetro determine. Ver secciones 2.3, 2.5, 2.7, 3 y 4.
>
> **Actualización (reevaluación de arquitectura física, 27–28/08/2026):** a solicitud de los profesores guía, la implementación del motor de carga descrita en §2.5 (DS3218 intervenido, motor DC) está siendo **reevaluada** frente a un motor brushless y frente a una arquitectura de aplicación de carga lineal (actuador lineal + brazo, en dos sub-variantes de medición). Ver `Comparacion_Alternativas_Arquitectura_Fisica.md` y `Matriz_Decision_Arquitectura_Banco.xlsx`. Todo lo descrito en este documento (interfaces I-03/I-04b, lazo de corriente en software, etc.) sigue vigente como arquitectura de referencia mientras no se cierre la reevaluación.

## 1. Visión general

La arquitectura separa explícitamente dos dominios, conforme al alcance del proyecto (que excluye el *"acoplamiento directo entre CFD y el banco de ensayos"*, entendido como: no se ejecuta CFD durante el ensayo; sí se permite recalcular en tiempo real la interpolación sobre la tabla ya generada):

- **Dominio OFFLINE:** generación de cargas aerodinámicas mediante CFD y su procesamiento hasta convertirlas en tablas de carga reutilizables. No interactúa en tiempo real con el banco.
- **Dominio ONLINE:** lectura de la tabla de carga, interpolación (ahora realimentada por la posición **y velocidad angular** real de la aleta, y opcionalmente ajustada de forma manual mediante potenciómetros), control de la aplicación de torque, instrumentación y adquisición de datos durante el ensayo físico.

El único punto de acoplamiento entre ambos dominios sigue siendo la **tabla de carga** (archivo CSV/JSON), lo que permite sustituir la fuente de datos (nueva aplicación, nueva geometría) sin modificar el banco físico ni el software de control — este es el mecanismo concreto que materializa la modularidad exigida en el alcance del proyecto (RNF-MOD-01, RNF-MOD-02).

El banco monta, en un solo eje, en serie: **motor de carga → sensor de torque → actuador bajo prueba → aleta física representativa**. La aleta no experimenta carga aerodinámica real (no hay túnel de viento); su rol es ser el elemento cuyo ángulo real y velocidad angular real se miden, y cuya inercia/holgura mecánica forman parte de lo que se caracteriza. Un **panel de potenciómetros** conectado al microcontrolador cumple dos funciones independientes en modo manual: (a) fijar las condiciones de vuelo simuladas (Mach, ángulo de ataque) que alimenta la tabla de carga, y (b) comandar directamente un ángulo de deflexión objetivo al actuador bajo prueba, cuyo logro o no se verifica mediante la instrumentación del eje (RF-INS-02), no mediante el potenciómetro mismo (ver 2.7 y CU-006).

```mermaid
flowchart LR
    subgraph OFFLINE["Dominio OFFLINE (fuera de línea)"]
        direction TB
        A[Simulación CFD<br/>OpenFOAM] --> B[Generación de<br/>tablas aerodinámicas]
        B --> C[Procesamiento /<br/>reducción de datos]
    end

    C -->|Archivo CSV / JSON<br/>tabla de carga| D

    POT1[Potenciómetros<br/>Mach / AoA] -->|I-11: modo manual| E
    POT2[Potenciómetro<br/>ángulo objetivo] -->|I-12: comando directo| ACT

    subgraph ONLINE["Dominio ONLINE (banco de ensayos)"]
        direction TB
        D[Lectura de<br/>tabla de carga] --> E[Interpolación<br/>realimentada por posición<br/>y velocidad angular]
        E --> F[Torque objetivo<br/>de referencia]
        F --> G[Controlador]
        G --> H[Motor de carga]
        H --> S[Sensor de torque]
        S --> ACT[Actuador bajo prueba]
        ACT --> AL[Aleta física]
        AL -->|Encoder: ángulo y<br/>velocidad angular real| ENC[Instrumentación]
        S -->|Torque medido| ENC
        ENC -->|Realimentación de torque| G
        ENC -->|Realimentación de<br/>posición y velocidad| E
        ENC --> I[Adquisición<br/>de datos]
        I --> J[Resultados /<br/>exportación]
    end

    style OFFLINE fill:#f4f4f4,stroke:#999
    style ONLINE fill:#eef6ff,stroke:#5b9bd5
```

## 2. Subsistemas

### 2.1 Módulo CFD (offline)

**Responsabilidad:** obtener las cargas fluidodinámicas sobre la superficie de control mediante simulaciones CFD y estructurarlas en una tabla aerodinámica.

- **Entradas:** geometría de la superficie de control, condiciones de operación (Mach, ángulo de ataque, deflexión **y velocidad angular de deflexión**).
- **Salidas:** tabla aerodinámica cruda (coeficientes/torque de charnela en función de las cuatro variables de entrada).
- **Fuera de alcance del banco:** este módulo se ejecuta de forma independiente y no forma parte del software entregable del proyecto; su salida es la única interfaz con el resto del sistema.
- **RF relacionados:** ninguno directo (es la fuente externa que consume RF-CFD-01).

> **Nota (confirmado en Reunión de Avance 28/08/2026):** se adopta arquitectura de **ala con flap**, no superficie totalmente móvil. Ángulo de ataque (del ala) y deflexión (del flap) son variables físicamente distintas — no aplica la degeneración que sí ocurría en el modelo de aleta aislada sin fuselaje (ver `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` §6, ahora superado). Las "condiciones de operación" de este módulo se mantienen en **4 variables separadas**: Mach, ángulo de ataque, deflexión, velocidad angular de deflexión.

### 2.2 Módulo de procesamiento (Python, offline)

**Responsabilidad:** transformar la salida cruda de CFD en una tabla de carga lista para ser consumida por el banco (limpieza, formato, eventualmente reducción de orden o ajuste de superficie de respuesta).

- **Entradas:** salida del Módulo CFD.
- **Salidas:** archivo de tabla de carga (CSV/JSON) con estructura validada (cuatro variables de entrada: Mach, ángulo de ataque, deflexión, velocidad angular de deflexión; una variable de salida: torque de charnela).
- **RF relacionados:** RF-CFD-01, RF-CFD-02.

### 2.3 Lectura e interpolación (online)

**Responsabilidad:** importar la tabla de carga, validar su estructura y rango, e interpolar el torque objetivo. A diferencia de la versión anterior de esta arquitectura, el torque objetivo **no se limita a un perfil temporal precalculado**: la tabla de carga relaciona torque con (Mach, ángulo de ataque, **deflexión de la aleta y su velocidad angular de deflexión**), por lo que este módulo recibe continuamente la **posición angular real y la velocidad angular real de la aleta** (medidas por instrumentación) y recalcula el torque objetivo correspondiente a ese estado, no solo a la posición comandada. El perfil temporal generado al configurar el ensayo (CU-002) sigue existiendo como **referencia inicial y como envolvente de validación**, pero el valor aplicado en cada instante proviene del recálculo en tiempo real sobre las cuatro variables de la tabla.

Adicionalmente, este módulo puede recibir, en **modo manual**, los valores de Mach y ángulo de ataque fijados por el operador mediante los **potenciómetros de condiciones de vuelo** (I-11), en lugar de (o además de) los valores del escenario/maniobra programado. Este modo manual no reemplaza la realimentación de posición/velocidad de la aleta (I-10), que siempre proviene de la medición real: los potenciómetros de I-11 fijan únicamente las condiciones de vuelo simuladas (Mach, AoA), no la deflexión física del eje. El ángulo de deflexión, en cambio, nunca es una entrada manual de este módulo: proviene siempre de la medición real de la aleta (I-10), incluso cuando ese ángulo fue originalmente comandado al actuador bajo prueba mediante el potenciómetro de ángulo objetivo (I-12, ver 2.5).

- **Entradas:** tabla de carga (archivo), parámetros del ensayo definidos por el operador (escenario/maniobra), posición y velocidad angular real de la aleta (realimentación, I-10), valores manuales de Mach/AoA desde los potenciómetros de condiciones de vuelo en modo manual (I-11).
- **Salidas:** torque objetivo instantáneo, perfil temporal de referencia (para comparación/validación), estimación del error de interpolación.
- **RF relacionados:** RF-CFD-01 a RF-CFD-04, RF-PRO-01 a RF-PRO-06, RF-BAN-07.

### 2.4 Controlador

**Responsabilidad:** ejecutar el lazo de control que compara el torque objetivo (recalculado según posición y velocidad real, 2.3) con el torque medido y comanda el motor de carga, incluyendo la **compensación activa del torque parásito** inducido por el movimiento del actuador bajo prueba (efecto documentado en la literatura del Tema 2: Yao et al. 2010/2012; Lee & Cho 2001), típicamente mediante feedforward o sincronización de velocidad. El controlador también implementa la **protección ante atasco mutuo (stall)**: si el actuador bajo prueba y el motor de carga se oponen de forma sostenida sin que la posición de la aleta cambie, el sistema debe detectar la condición y llevar el banco a estado seguro, en lugar de forzar ambos motores indefinidamente.

El comando final hacia el motor de carga se ejecuta mediante un **lazo de corriente anidado, cerrado en software** dentro del mismo microcontrolador: el lazo externo (torque) genera una corriente objetivo; el lazo interno (corriente) compara esa referencia contra la corriente real medida en el motor DC del DS3218 intervenido y ajusta el duty cycle de la señal PWM de salida (ver I-03, sección 3). No existe lazo de corriente en hardware dedicado: la simplicidad del driver (H-bridge COTS sin electrónica de control propia) traslada esa función al software del controlador.

- **Entradas:** torque objetivo instantáneo (de 2.3), torque medido (de 2.5), posición y velocidad angular real de la aleta (de 2.5), corriente real del motor de carga (de 2.5, para el lazo interno), límites de seguridad configurados.
- **Salidas:** comando PWM (duty cycle) al driver del motor de carga; señales de parada ante condición de falla o de atasco mutuo.
- **RF relacionados:** RF-BAN-01 a RF-BAN-04, RF-BAN-06, RF-SWC-02.
- **RNF relacionados:** RNF-REN-01, RNF-REN-02, RNF-REN-03, RNF-SEG-02, RNF-SEG-04.

### 2.5 Banco: motor de carga + sensor de torque + actuador bajo prueba + aleta + instrumentación

**Responsabilidad:** aplicar físicamente el torque comandado sobre el eje (motor de carga), medir el torque real transmitido (sensor de torque) y medir la posición angular y la velocidad angular real alcanzada por la **aleta** (no por el actuador internamente, dado que puede haber holgura o compliance entre ambos bajo carga).

- **Entradas:** comando PWM del Controlador (I-03), a través del driver H-bridge; valores manuales de los potenciómetros de condiciones de vuelo (I-11) y del potenciómetro de ángulo objetivo (I-12), leídos por el mismo microcontrolador.
- **Salidas:** torque medido y posición/velocidad angular de la aleta hacia el Controlador y hacia Lectura e interpolación (realimentación); corriente real del motor de carga hacia el Controlador (lazo interno); comando de posición directo hacia el actuador bajo prueba cuando el potenciómetro de ángulo objetivo está activo (I-12); todo lo anterior también hacia Adquisición de datos.
- **Interfaz externa:** el **actuador bajo prueba** es un componente intercambiable, fuera del alcance de desarrollo del proyecto (ver "No incluye" en `01_Especificacion_del_Proyecto.md`), montado mediante un acople mecánico normalizado.
- **Aleta física:** elemento de prueba representativo (no vinculado a una plataforma o geometría específica), montado rígidamente en el mismo eje; no está sometida a carga aerodinámica real — su función es ser el punto de medición del ángulo real y de la velocidad angular real, y aportar la inercia/dinámica que el actuador debe vencer bajo carga.
- **Implementación mecánica del acople (preliminar):** motor de carga y actuador se unen mediante un **eje intermedio de 5 mm de diámetro**, conectado a cada servo con **acoples flexibles de aluminio 5 mm** (toleran pequeños desalineamientos entre los cuernos/horns de los servos y el eje). El eje se apoya en **dos rodamientos tipo pillow block** montados en el riel de la bancada. La **aleta** se fija al eje mediante un collar cerca del extremo del actuador. El **sensor de torque no es inline**: se implementa como una **celda de carga fija al riel** (modelo Altronics LC-10KG-HX711, tipo barra, 10 kg, con módulo HX711 de 24 bits), presionada por un **brazo de palanca (torque arm) de radio ~4 cm** rígidamente sujeto al eje (torque = fuerza medida × radio; ver RNF-CAR-01, RNF-PRE-02). Las piezas custom (collares, brazo de torque, soportes de rodamiento) se fabrican por **impresión 3D**.
- **Implementación electrónica del motor de carga (I-03):** el motor DC crudo, resultante de intervenir el servo DS3218, se comanda mediante un **driver H-bridge COTS** de bajo costo (BTS7960), sin electrónica de lazo de corriente propia. La corriente real se mide con el sensor de corriente **INA219** y se digitaliza hacia el Controlador (2.4), que cierra el lazo de corriente en software.
- **Panel de potenciómetros (nuevo), con dos funciones e interfaces distintas:**
  - **I-11 — potenciómetros de condiciones de vuelo:** fijan manualmente los valores de Mach y ángulo de ataque usados por el módulo de interpolación (2.3). No miden nada del sistema físico; solo fijan condiciones de entrada de la tabla de carga, en modo manual/exploración.
  - **I-12 — potenciómetro de ángulo objetivo:** comanda **directamente** al actuador bajo prueba un ángulo de deflexión objetivo, como un probador de servo manual, independiente del torque objetivo generado por 2.3/2.4. El sistema no asume que el actuador alcanza ese ángulo: lo que realmente se logra se mide vía RF-INS-02 (posición real de la aleta) y esa comparación comandado-vs-logrado es, en sí misma, un dato de caracterización del actuador (OE-6).

> **Nota (reevaluación en curso):** la elección de motor DC crudo con driver H-bridge simple, descrita arriba, es la arquitectura de referencia actual pero está siendo comparada formalmente contra un motor brushless y una arquitectura lineal — ver `Comparacion_Alternativas_Arquitectura_Fisica.md`.

- **RF relacionados:** RF-BAN-01, RF-BAN-05, RF-BAN-07 (aplicación física del torque comandado, modo manual, entradas manuales por potenciómetro de condiciones de vuelo y comando directo de ángulo objetivo — la decisión de control, incluida la detección de atasco mutuo RF-BAN-06, se aloja en el Controlador, sección 2.4), RF-INS-01 a RF-INS-04, RF-SIS-02.
- **RNF relacionados:** RNF-PRE-02, RNF-PRE-03, RNF-PRE-04, RNF-SEG-01, RNF-SEG-03, RNF-CAR-01 (la decisión de detener ante atasco mutuo, RNF-SEG-04, se aloja en el Controlador, sección 2.4).

### 2.6 Adquisición de datos y registro

**Responsabilidad:** sincronizar temporalmente las señales medidas, registrarlas junto con la referencia objetivo, y dejarlas disponibles para visualización y exportación.

- **Entradas:** señales medidas de 2.5 (incluyendo posición y velocidad angular de la aleta), referencia objetivo de 2.3, valores manuales de los potenciómetros activos durante el ensayo (condiciones de vuelo y/o ángulo objetivo comandado, para trazabilidad, si se usaron).
- **Salidas:** registro de ensayo (variables + eventos + configuración), archivo exportable (CSV).
- **RF relacionados:** RF-INS-04, RF-INS-05, RF-SWC-04, RF-SWC-05.
- **RNF relacionados:** RNF-DOC-01.

### 2.7 Software de operación (interfaz de usuario)

**Responsabilidad:** proveer al operador la interfaz para importar tablas, configurar ensayos, ejecutarlos/detenerlos, visualizar variables en tiempo real y consultar la bitácora. El **panel de potenciómetros** (2.5, I-11/I-12) es una interfaz de entrada física complementaria a esta interfaz de software, pensada para modo manual/calibración (CU-006) más que para la configuración inicial de un ensayo automático (CU-002).

- **RF relacionados:** RF-SWC-01, RF-SWC-03, RF-SWC-06, RF-BAN-07.
- **RNF relacionados:** RNF-USA-01, RNF-USA-02.

## 3. Interfaces entre subsistemas

| ID              | Origen                                            | Destino                                          | Datos intercambiados                                                                                        | Formato / mecanismo                                                                                                                                                                                                                                                                                                         | RF relacionado                  |
| --------------- | ------------------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| I-01            | Módulo de procesamiento (offline)                | Lectura e interpolación (online)                | Tabla de carga aerodinámica (4 entradas: Mach, AoA, deflexión, velocidad angular de deflexión → torque) | Archivo CSV/JSON                                                                                                                                                                                                                                                                                                            | RF-CFD-01, RF-CFD-02            |
| I-02            | Lectura e interpolación                          | Controlador                                      | Torque objetivo instantáneo (recalculado por posición y velocidad)                                        | Estructura interna / cola de referencias                                                                                                                                                                                                                                                                                    | RF-PRO-05, RF-PRO-06            |
| **I-03**  | **Controlador**                             | **Driver H-bridge → Motor de carga**      | **Comando de corriente (duty cycle PWM)**                                                             | **Señal PWM desde el microcontrolador (ESP32 DevKitC-V4) hacia un driver H-bridge COTS (BTS7960). Sin lazo de corriente en hardware: el lazo de corriente se cierra en software, en el mismo microcontrolador que ejecuta el Controlador (2.4), a partir de la corriente real medida por el sensor INA219 (I-04b).** | **RF-BAN-01**             |
| I-04            | Motor de carga / actuador bajo prueba / aleta     | Instrumentación                                 | Señales físicas (torque, posición y velocidad angular de la aleta, corriente/tensión)                   | Señal analógica o digital de sensor                                                                                                                                                                                                                                                                                       | RF-INS-01, RF-INS-02, RF-INS-03 |
| **I-04b** | **Motor de carga**                          | **Controlador**                            | **Corriente real del motor de carga (realimentación del lazo interno)**                              | **Sensor de corriente INA219 (I2C, 0–3,2 A, 12 bits), ciclo de control**                                                                                                                                                                                                                                             | **RF-BAN-01, RF-INS-03**  |
| I-05            | Instrumentación                                  | Controlador                                      | Torque medido (realimentación del lazo de control)                                                         | Señal digitalizada, ciclo de control                                                                                                                                                                                                                                                                                       | RF-BAN-02, RF-SWC-02            |
| I-06            | Instrumentación                                  | Adquisición de datos                            | Señales digitalizadas y sincronizadas                                                                      | Bus/DAQ interno                                                                                                                                                                                                                                                                                                             | RF-INS-04                       |
| I-07            | Adquisición de datos                             | Software de operación                           | Datos en tiempo real para visualización                                                                    | Interna (misma aplicación o IPC)                                                                                                                                                                                                                                                                                           | RF-SWC-03                       |
| I-08            | Adquisición de datos                             | Almacenamiento / exportación                    | Registro completo del ensayo                                                                                | Archivo CSV                                                                                                                                                                                                                                                                                                                 | RF-SWC-04, RNF-DOC-01           |
| I-09            | Software de operación                            | Operador                                         | Configuración, visualización, control del ensayo                                                          | Interfaz gráfica (GUI)                                                                                                                                                                                                                                                                                                     | RF-SWC-01, RF-SWC-06            |
| **I-10**  | **Instrumentación**                        | **Lectura e interpolación**               | **Posición angular real y velocidad angular real de la aleta (realimentación)**                     | **Señal digitalizada, ciclo de interpolación (dos canales: posición y velocidad)**                                                                                                                                                                                                                                 | **RF-PRO-06**             |
| **I-11**  | **Potenciómetros de condiciones de vuelo** | **Lectura e interpolación (modo manual)** | **Valores manuales de Mach y ángulo de ataque**                                                      | **Señal analógica → ADC del microcontrolador → estructura interna, activa solo en modo manual/calibración**                                                                                                                                                                                                      | **RF-BAN-07(a)**          |
| **I-12**  | **Potenciómetro de ángulo objetivo**      | **Actuador bajo prueba**                   | **Ángulo de deflexión objetivo (comando directo, tipo probador de servo)**                          | **Señal analógica → ADC del microcontrolador → señal de comando de posición hacia el actuador bajo prueba, independiente del lazo de torque (2.3/2.4)**                                                                                                                                                         | **RF-BAN-07(b)**          |

> **Nota:** I-10 es la interfaz que cierra el lazo posición(+velocidad)→torque descrito en 2.3. Antes de la revisión de arquitectura mecánica, la interpolación solo generaba un perfil temporal fijo (I-02 unidireccional); ahora I-02 transporta un torque objetivo que cambia en cada ciclo según la posición y velocidad reales reportadas por I-10.
>
> **I-11 (nueva, acuerdos de Avance I):** interfaz de entrada manual, físicamente independiente del lazo de instrumentación del eje (I-04/I-10). No mide nada del banco; solo fija, mediante potenciómetros leídos por el mismo microcontrolador, las condiciones de vuelo simuladas (Mach, ángulo de ataque) que el módulo de interpolación usa como entrada cuando el operador opera en modo manual (RF-BAN-07(a), CU-006).
>
> **I-12 (nueva, acuerdos de Avance I):** a diferencia de I-11, esta interfaz **no toca la tabla de carga**: es un comando de posición directo al actuador bajo prueba, análogo a un probador de servo. El ángulo efectivamente alcanzado por la aleta bajo ese comando —y bajo el torque de carga aplicado simultáneamente por el motor de carga— se mide mediante I-10/RF-INS-02; no se asume ni se deriva del valor del potenciómetro. Esta comparación (ángulo comandado por I-12 vs. ángulo medido por I-10) es un dato de caracterización directo del actuador bajo prueba (OE-6). Queda pendiente definir en el diseño detallado si I-12 puede coexistir con un ensayo automático (override momentáneo del perfil de RF-PRO-03) o si es exclusiva del modo manual — ver sección 7.
>
> **I-03 e I-04b:** el comando de torque hacia el motor de carga se implementa como una señal PWM simple hacia un driver H-bridge COTS sin electrónica de control propia; toda la inteligencia del lazo de corriente vive en el mismo microcontrolador del Controlador. Se descartó un bus de tiempo real (EtherCAT/CAN) porque el banco opera un solo eje y no requiere sincronizar múltiples nodos distribuidos — esa complejidad no se justifica dado el alcance y presupuesto del proyecto (RNF-COS-01).

## 4. Diagrama de bloques detallado

```mermaid
flowchart TB
    subgraph OFF["OFFLINE"]
        CFD[Módulo CFD<br/>OpenFOAM]
        PROC[Procesamiento<br/>Python]
        CFD --> PROC
    end

    PROC -->|I-01: tabla de carga<br/>CSV/JSON, 4 entradas| INT

    POT1[["Potenciómetros<br/>Mach / AoA"]]
    POT2[["Potenciómetro<br/>ángulo objetivo"]]

    subgraph ON["ONLINE — Banco de ensayos"]
        INT[Lectura e<br/>interpolación]
        CTRL[Controlador<br/>lazo torque + lazo corriente SW]
        DRV[Driver H-bridge COTS]
        LOADM[Motor de carga<br/>DS3218 intervenido]
        TSENS[Sensor de torque<br/>celda de carga + brazo]
        CSENS[Sensor de corriente]
        ACT[["Actuador bajo prueba<br/>(componente externo/intercambiable)"]]
        FIN[["Aleta física<br/>(elemento representativo de prueba)"]]
        INSTR[Instrumentación]
        DAQ[Adquisición<br/>y registro]
        UI[Software de<br/>operación / GUI]

        INT -->|I-02: torque objetivo<br/>instantáneo| CTRL
        CTRL -->|I-03: PWM duty cycle| DRV
        DRV --> LOADM
        LOADM --> TSENS
        TSENS --> ACT
        ACT --> FIN
        LOADM -->|I-04b: corriente real| CSENS
        CSENS -->|I-04b: realimentación<br/>lazo de corriente| CTRL
        TSENS -->|I-04: torque| INSTR
        FIN -->|I-04: ángulo y<br/>velocidad angular real| INSTR
        ACT -->|I-04: corriente/tensión| INSTR
        INSTR -->|I-05: torque medido<br/>realimentación| CTRL
        INSTR -->|I-10: posición y velocidad<br/>real, realimentación| INT
        INSTR -->|I-06: señales<br/>sincronizadas| DAQ
        DAQ -->|I-07: datos en<br/>tiempo real| UI
        DAQ -->|I-08: registro<br/>completo| EXP[[Exportación CSV]]
        UI -->|I-09: configuración<br/>y comandos| INT
        UI -->|I-09| CTRL
        POT1 -->|I-11: Mach/AoA<br/>modo manual| INT
        POT2 -->|I-12: ángulo objetivo<br/>comando directo| ACT
    end

    style OFF fill:#f4f4f4,stroke:#999
    style ON fill:#eef6ff,stroke:#5b9bd5
    style ACT fill:#fff3e0,stroke:#e0a020,stroke-dasharray: 4 3
    style FIN fill:#fff3e0,stroke:#e0a020,stroke-dasharray: 4 3
    style POT1 fill:#fff3e0,stroke:#e0a020,stroke-dasharray: 4 3
    style POT2 fill:#fff3e0,stroke:#e0a020,stroke-dasharray: 4 3
```

*Los nodos "Actuador bajo prueba", "Aleta física" y los potenciómetros se resaltan con borde punteado para indicar que son elementos externos/representativos o de interacción manual directa (RF-SIS-02, RF-BAN-07), no parte del lazo automático de control. Nótese que I-12 comanda al actuador bajo prueba directamente, no a través del módulo de interpolación — el logro o no de ese ángulo se verifica por la ruta INSTR → I-10, igual que en modo automático.*

## 5. Supuestos de diseño

1. **Desacople offline/online estricto:** la única interfaz entre CFD y banco es el archivo de tabla de carga (I-01); no existe retroalimentación desde el banco hacia el módulo CFD ni ejecución de CFD durante el ensayo, conforme al alcance del proyecto. Sí existe retroalimentación *interna* al dominio online (I-10) entre instrumentación e interpolación — esto no constituye acoplamiento directo con CFD.
2. **Actuador bajo prueba como componente externo:** el banco se diseña para admitir distintos actuadores mediante un acople mecánico normalizado (RF-SIS-02); su desarrollo interno queda fuera de alcance.
3. **Aleta como elemento representativo de prueba:** no está vinculada a una geometría o plataforma específica y no experimenta carga aerodinámica real; su rol es servir de punto de medición de ángulo y velocidad angular real, y de fuente de inercia/dinámica adicional. No contradice la exclusión de "diseño del misil o torpedo" del alcance del proyecto.
4. **Protocolo de comunicación controlador–banco (I-03) definido:** PWM desde el microcontrolador hacia un driver H-bridge COTS, con el lazo de corriente cerrado en software (no en hardware dedicado, no vía bus de tiempo real). Se descartaron EtherCAT/CAN (Tema 6: Zhang et al. 2024; Bahari et al. 2025) por ser innecesarios para un banco de un solo eje sin nodos distribuidos, priorizando simplicidad y costo (RNF-COS-01) sobre una arquitectura de comunicación pensada para sistemas multieje.
5. **Arquitectura de software modular:** "Lectura e interpolación", "Controlador", "Instrumentación/DAQ" y "Software de operación" se conciben como módulos con interfaces internas bien definidas, pudiendo implementarse como procesos separados o como una única aplicación multihilo, según se decida en el diseño detallado (RNF-MAN-01).
6. **Un solo banco, un solo actuador a la vez:** no se contempla operación simultánea de múltiples bancos ni de múltiples actuadores en paralelo en la versión actual del alcance.
7. **Trazabilidad de ensayos:** cada ejecución del ciclo I-01 → I-08 debe quedar asociada a la tabla de carga y configuración utilizadas (RNF-DOC-01), de modo que un resultado experimental sea siempre reproducible. Si se usó el panel de potenciómetros (I-11) durante el ensayo, esa condición también debe quedar registrada.
8. **Alineación mecánica y margen dinámico del conjunto en un solo eje:** el montaje en serie (motor de carga–sensor–actuador–aleta) exige alta concentricidad para que el sensor de torque no registre cargas parásitas radiales o de flexión; adicionalmente, la frecuencia natural del conjunto (incluyendo la inercia de la aleta) debe quedar suficientemente alejada del ancho de banda del lazo de control para evitar acoplamiento dinámico no deseado (ver RNF-PRE-04 y RNF-REN-03).
9. **Fabricación de piezas mecánicas custom por impresión 3D:** collares de fijación al eje, brazo de torque y soportes de rodamiento se fabrican por impresión 3D (acceso confirmado). Esto condiciona la tolerancia de alineación real alcanzable (RNF-PRE-04) y el torque máximo que estas piezas pueden transmitir sin deformarse — debe verificarse que el material impreso resista el torque pico de RNF-CAR-01 (~2 N·m) en el brazo de torque y los collares antes de la validación experimental.
10. **Lazo de corriente sin electrónica dedicada:** al usar un driver H-bridge COTS simple (sin lazo de corriente propio), toda la responsabilidad de estabilidad y ancho de banda del lazo de corriente recae en el software del Controlador (2.4) y en la frecuencia de muestreo del microcontrolador — esto condiciona directamente RNF-REN-01/02 y debe validarse experimentalmente una vez seleccionado el microcontrolador.
11. **(Nuevo) Velocidad angular como cuarta variable de la tabla de carga:** se asume que la tabla CFD (I-01) y la interpolación (2.3) pueden extenderse de tres a cuatro dimensiones de entrada sin cambio de arquitectura, dado que RF-PRO-01/02 ya contemplaban el método de interpolación como configurable. El método de medición de esta cuarta variable en el banco (derivada de posición vs. sensor dedicado) queda pendiente (sección 7).
12. **(Nuevo) El panel de potenciómetros no reemplaza la instrumentación del eje:** ni los potenciómetros de I-11 (Mach/AoA) ni el de I-12 (ángulo objetivo) miden nada físico del banco. I-11 fija condiciones de vuelo simuladas; I-12 fija un comando de posición para el actuador bajo prueba. La posición y velocidad angular *real* de la aleta siempre provienen de la instrumentación (I-10), incluso cuando el ángulo fue comandado manualmente por I-12 — esto es precisamente lo que permite usar la diferencia comandado-vs-logrado como dato de caracterización, y evita que el modo manual comprometa la trazabilidad exigida por RNF-DOC-01.

## 6. Trazabilidad arquitectura → requisitos (resumen)

| Subsistema                                                                     | RF                                                     | RNF                                                                    |
| ------------------------------------------------------------------------------ | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| Módulo de procesamiento (offline)                                             | RF-CFD-01, RF-CFD-02                                   | —                                                                     |
| Lectura e interpolación                                                       | RF-CFD-03, RF-CFD-04, RF-PRO-01 a RF-PRO-06, RF-BAN-07 | —                                                                     |
| Controlador                                                                    | RF-BAN-01 a RF-BAN-04, RF-BAN-06, RF-SWC-02            | RNF-REN-01, RNF-REN-02, RNF-REN-03, RNF-SEG-02, RNF-SEG-04             |
| Banco (motor de carga + actuador + aleta + potenciómetros) + instrumentación | RF-BAN-05, RF-BAN-07, RF-INS-01 a RF-INS-04, RF-SIS-02 | RNF-PRE-02, RNF-PRE-03, RNF-PRE-04, RNF-CAR-01, RNF-SEG-01, RNF-SEG-03 |
| Adquisición y registro                                                        | RF-INS-05, RF-SWC-04, RF-SWC-05                        | RNF-DOC-01                                                             |
| Software de operación                                                         | RF-SWC-01, RF-SWC-03, RF-SWC-06, RF-BAN-07             | RNF-USA-01, RNF-USA-02                                                 |
| Arquitectura general                                                           | RF-SIS-01                                              | RNF-MOD-01, RNF-MOD-02, RNF-MAN-01, RNF-MAN-02                         |

## 7. Pendiente / a definir en próxima iteración

- ~~Preselección de componentes concretos para I-03/I-04b~~ — **Completado:** driver H-bridge BTS7960, sensor de corriente INA219, microcontrolador ESP32 DevKitC-V4. Ver `06_Seleccion_Actuador_de_Carga.md`, §6.1, para la justificación de cada elección.
- ~~Selección de celda de carga concreta~~ — **Completado:** celda de carga tipo barra Altronics LC-10KG-HX711 (10 kg, con módulo HX711), sobre el brazo de palanca de ~4 cm. Ver `06_Seleccion_Actuador_de_Carga.md`, §6.2, y RNF-PRE-02.
- **Estrategia concreta de compensación del torque parásito** (feedforward de velocidad, sincronización de velocidad, control robusto — ver Tema 2: Yao et al. 2010/2012; Lee & Cho 2001; Nam 2001) a seleccionar antes del diseño detallado del Controlador.
- **Criterio de detección de atasco mutuo (stall)** entre motor de carga y actuador bajo prueba (umbral de torque diferencial sostenido, timeout) — a definir junto con RNF-SEG-04.
- Definir si "Lectura e interpolación", "Controlador" y "Software de operación" se implementan como una única aplicación o como procesos/servicios separados.
- **Validación experimental del ancho de banda alcanzable** con el lazo de corriente en software (supuesto 10), una vez seleccionado el microcontrolador — condiciona si RNF-REN-01/02 (~100–200 Hz preliminar) son alcanzables con esta arquitectura simplificada o si se requiere revisar el enfoque.
- **(Nuevo) Método de medición de la velocidad angular de la aleta:** decidir entre derivar numéricamente la señal de posición del encoder (más simple, sin hardware adicional, pero sensible a ruido/latencia) o incorporar un sensor de velocidad dedicado. Condiciona una eventual nueva RNF de precisión (análoga a RNF-PRE-03) aún no creada en `03_Requisitos_No_Funcionales.md`.
- **(Nuevo) Especificación concreta del panel de potenciómetros:** para I-11 (Mach, AoA), rango físico que cubre cada perilla; para I-12 (ángulo objetivo), rango angular, si el comando pasa por algún acondicionamiento/limitador antes de llegar al actuador bajo prueba, y si puede actuar como *override* momentáneo durante un ensayo automático o es exclusivo del modo manual/calibración (CU-006). Pendiente también: si se requiere una RNF de resolución/repetibilidad para estas interfaces.
- **Propagación pendiente de los acuerdos de Avance I** a `03_Requisitos_No_Funcionales.md` (nuevas RNF de precisión de velocidad angular y de resolución del panel de potenciómetros), `04_Casos_de_Uso.md` (extender CU-002/CU-006 y evaluar un CU-010 dedicado al modo potenciómetros) y `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` (la matriz de casos CFD de Fase B1 debe incorporar un rango de velocidades angulares de deflexión).
- **(Nuevo, 27–28/08/2026) Reevaluación de la arquitectura física de aplicación de torque:** en curso a solicitud de los profesores guía. Ver `Comparacion_Alternativas_Arquitectura_Fisica.md` (comparación cualitativa, incluye diagrama del lazo de corriente que reencuadra la objeción original) y `Matriz_Decision_Arquitectura_Banco.xlsx` (matriz de decisión ponderada). Mientras no se cierre, §2.4/§2.5/§3 (I-03, I-04b) de este documento siguen describiendo la arquitectura de referencia (Opción A).
