# Diagrama de Arquitectura del Sistema — Banco de Ensayos de Actuadores

**Referencia:** Estilo анастасοpoulos & Hornung (2018) — bancos de carga dinámica para caracterización de actuadores de superficies de control.

---

## Diagrama principal de arquitectura (Mermaid)

```mermaid
flowchart TB
    subgraph OFFLINE["DOMINIO OFFLINE (Fuera de línea)"]
        direction TB
        CFD[Simulación CFD<br/>OpenFOAM<br/>Mach, AoA, δ, ω] --> PROC[Procesamiento Python<br/>Limpieza, formato,<br/>reducción de datos]
        PROC --> TABLA["Tabla de Carga<br/>CSV/JSON<br/>4 entradas: Mach, AoA, δ, ω<br/>1 salida: H(Nm)"]
    end

    subgraph ONLINE["DOMINIO ONLINE (Banco de ensayos)"]
        direction TB
  
        subgraph INTERFACES["Interfaces de Entrada Manual"]
            POT_MACH[Potenciómetro Mach<br/>I-11a] 
            POT_AOA[Potenciómetro AoA<br/>I-11b]
            POT_ANG[Potenciómetro Ángulo Objetivo<br/>I-12<br/>Comando directo al AUT]
        end

        subgraph CONTROL["Sistema de Control (ESP32)"]
            READ[Lectura de Tabla<br/>Validación de rango]
            INTERP[Interpolación en Tiempo Real<br/>Entradas: Mach, AoA, δ_real, ω_real<br/>Salida: H_ref]
            CTRL_EXT[Controlador Externo<br/>Lazo de torque<br/>H_ref vs H_med → I_ref]
            CTRL_INT[Controlador Interno<br/>Lazo de corriente<br/>I_ref vs I_med → PWM]
      
            READ --> INTERP
            INTERP --> CTRL_EXT
            CTRL_EXT --> CTRL_INT
        end

        subgraph BANCO["Banco Físico"]
            DRIVER[Driver H-Bridge<br/>BTS7960<br/>PWM → V_motor]
            MOTOR[M Motor de Carga<br/>DS3218 intervenido<br/>Motor DC crudo]
            TORQ[Sensor de Torque<br/>Celda de carga + brazo<br/>o torquímetro inline]
            AUT["Actuador Bajo Prueba<br/>MG996R (intercambiable)<br/>RF-SIS-02"]
            ALETA["Aleta Física<br/>NACA 0012, flap 25%<br/>c=381mm, b=1.602m"]
            ENC[Encoder Óptico<br/>Ángulo θ y velocidad ω]
            IMU[IMU en la aleta<br/>Giroscopio ω, acelerómetro]
            LIMIT[Fin de Carrera x2<br/>Protección hardware<br/>RF-BAN-08]
      
            CTRL_INT -->|I-03: PWM| DRIVER
            DRIVER --> MOTOR
            MOTOR --> TORQ
            TORQ --> AUT
            AUT --> ALETA
            ALETA -->|Eje común| ENC
            ALETA --> IMU
            ENC -->|I-10: θ, ω| CONTROL
            IMU -->|I-09: ω_gyro, acc| CONTROL
            TORQ -->|I-04: Fuerza → H_med| CONTROL
      
            ALETA -.->|Acciona | LIMIT
            LIMIT -.->|Corte físico de potencia| DRIVER
        end

        subgraph ADQ["Adquisición y Registro"]
            DAQ["Adquisición de Datos<br/>θ(t), ω(t), H_med(t), I(t)"]
            EXPORT[Exportación de Resultados<br/>CSV para análisis<br/>Comparación δ_cmd vs δ_real]
      
            CONTROL --> DAQ
            DAQ --> EXPORT
        end
    end

    TABLA -->|I-01: Archivo CSV/JSON| READ
    POT_MACH -->|I-11a: Mach_manual| INTERP
    POT_AOA -->|I-11b: AoA_manual| INTERP
    POT_ANG -->|I-12: δ_cmd| AUT
  
    ENC -.->|Realimentación de posición| INTERP
    TORQ -.->|Realimentación de torque| CTRL_EXT
    MOTOR -.->|"I_med (INA219)"| CTRL_INT

    style OFFLINE fill:#f4f4f4,stroke:#666,stroke-width:2px
    style ONLINE fill:#eef6ff,stroke:#5b9bd5,stroke-width:2px
    style CONTROL fill:#fff4e6,stroke:#ff9900,stroke-width:2px
    style BANCO fill:#ffe6f2,stroke:#d63384,stroke-width:2px
    style INTERFACES fill:#e6f7ff,stroke:#1890ff,stroke-width:2px
    style ADQ fill:#f6ffed,stroke:#52c41a,stroke-width:2px
```

---

## Leyenda de interfaces (I-01 a I-12)

| ID             | Tipo               | Descripción                                                   | Dirección                    | Estado                  |
| -------------- | ------------------ | -------------------------------------------------------------- | ----------------------------- | ----------------------- |
| **I-01** | Archivo            | Tabla de carga CFD (CSV/JSON)                                  | Offline → Online             | ✅ Implementada         |
| **I-02** | Eléctrica         | Alimentación 12V/5V al banco                                  | Fuente → Banco               | ✅ Implementada         |
| **I-03** | PWM                | Comando de torque al motor de carga (duty cycle)               | ESP32 → Driver BTS7960       | ✅ Implementada         |
| **I-04** | Analógica/Digital | Medición de fuerza (celda de carga) → torque calculado       | Celda → ESP32 (HX711)        | ⚠️ En reevaluación   |
| **I-05** | Digital            | Lectura de encoder (posición θ)                              | Encoder → ESP32              | ✅ Implementada         |
| **I-06** | UART/I2C           | Lectura de IMU (giroscopio ω, acelerómetro)                  | IMU → ESP32                  | ✅ Implementada         |
| **I-07** | UART/USB           | Comunicación con PC (envío de datos)                         | ESP32 → PC                   | ✅ Implementada         |
| **I-08** | Digital            | Comando de posición al actuador bajo prueba                   | ESP32 → MG996R               | ✅ Implementada         |
| **I-09** | I2C/SPI            | Lectura fusionada encoder+IMU para estimación de estado       | Sensor Fusion → Control      | ✅ En desarrollo (§10) |
| **I-10** | Realimentación    | Posición angular real δ_real y velocidad ω_real de la aleta | Encoder/IMU → Interpolación | ✅ Implementada         |
| **I-11** | Analógica         | Potenciómetros de condiciones de vuelo (Mach, AoA)            | Pot → ADC ESP32              | ✅ Implementada         |
| **I-12** | Analógica         | Potenciómetro de ángulo objetivo (comando manual directo)    | Pot → ADC ESP32 → AUT       | ✅ Implementada         |

---

## Diagrama de lazo de control (detalle)

```mermaid
flowchart LR
    subgraph LAZO_EXTERNO["Lazo Externo (Torque)"]
        H_ref[H_ref: Torque objetivo<br/>de interpolación] --> SUM1((Σ))
        SUM1 --> CTRL_TORQ[Controlador de Torque<br/>PID/Feedforward]
        CTRL_TORQ --> I_ref[I_ref: Corriente objetivo]
        H_med[H_med: Torque medido<br/>sensor de torque] -.-> SUM1
    end

    subgraph LAZO_INTERNO["Lazo Interno (Corriente)"]
        I_ref --> SUM2((Σ))
        SUM2 --> CTRL_CURR[Controlador de Corriente<br/>PID software]
        CTRL_CURR --> PWM[Señal PWM<br/>Duty cycle]
        PWM --> DRIVER[Driver H-Bridge<br/>BTS7960]
        DRIVER --> MOTOR[Motor DC<br/>DS3218]
        I_med[I_med: Corriente real<br/>INA219] -.-> SUM2
        MOTOR --> H_med
    end

    LAZO_EXTERNO --> LAZO_INTERNO
  
    style LAZO_EXTERNO fill:#fff4e6,stroke:#ff9900
    style LAZO_INTERNO fill:#e6f7ff,stroke:#1890ff
```

**Nota:** Ambos lazos están cerrados **en software** dentro del mismo ESP32, no en hardware dedicado. Esto es una decisión de arquitectura para mantener la simplicidad del driver (BTS7960 sin electrónica de control propia) y la flexibilidad del algoritmo de control.

---

## Diagrama de fusión sensorial (ángulo y velocidad)

```mermaid
flowchart TB
    subgraph SENSORES["Sensores"]
        ENC[Encoder en el eje<br/>θ_encoder absoluto<br/>sin deriva, resolución discreta]
        GYRO[Giroscopio IMU<br/>ω_gyro directo<br/>con bias b_gyro que deriva]
        ACCEL[Acelerómetro IMU<br/>Orientación en reposo<br/>contaminado por ω²r si r≠0]
    end

    subgraph FILTRO["Filtro Kalman / Complementario"]
        ESTADO["Estado estimado:<br/>x = [θ, ω, b_gyro]"]
        PREDIC["Predicción:<br/>θ_k = θ_{k-1} + ω·Δt<br/>ω_k = ω_{k-1}<br/>b_gyro_k = b_gyro_{k-1}"]
        CORR["Corrección:<br/>z_encoder → corrige θ<br/>z_gyro - b_gyro → corrige ω<br/>z_accel → opcional, solo estático"]
  
        PREDIC --> ESTADO
        CORR --> ESTADO
    end

    subgraph BACKEMF["Diagnóstico de Backlash"]
        V[V_terminal del motor]
        I[Corriente del motor]
        CALC["ω_rotor = (V - I·R)/Ke"]
        COMP[Comparación:<br/>ω_rotor/N vs ω_aleta<br/>→ estima backlash en tiempo real]
  
        V --> CALC
        I --> CALC
        CALC --> COMP
    end

    ENC -->|z_encoder| CORR
    GYRO -->|z_gyro| CORR
    ACCEL -->|z_accel| CORR
    ESTADO -->|ω estimada| COMP
    ESTADO -->|θ estimada| SALIDA[Salida: θ, ω robustos]
  
    style SENSORES fill:#f4f4f4,stroke:#666
    style FILTRO fill:#fff4e6,stroke:#ff9900
    style BACKEMF fill:#e6f7ff,stroke:#1890ff
```

**Referencia completa:** Ver sección 10 de `10_Estrategia_Estimacion_Torque_Fusion_Sensorial.md` para la formulación matemática detallada y la secuencia de implementación incremental.

---

## Flujo de datos durante un ensayo típico

```mermaid
sequenceDiagram
    participant OP as Operador
    participant POT as Potenciómetros
    participant ESP as ESP32 (Control)
    participant AUT as Actuador Bajo Prueba
    participant MOT as Motor de Carga
    participant SEN as Sensores (Encoder/IMU/Torque)
    participant PC as PC (Adquisición)

    OP->>POT: Fija Mach, AoA (I-11) y δ_cmd (I-12)
    POT->>ESP: Lee valores ADC
  
    loop Cada ciclo de control (~1 kHz)
        ESP->>ESP: Interpola H_ref(Mach, AoA, δ_real, ω_real)
        SEN->>ESP: Envía δ_real, ω_real, H_med, I_med
        ESP->>ESP: Calcula error H_ref - H_med
        ESP->>ESP: Lazo externo → I_ref
        ESP->>ESP: Lazo interno → PWM (I-03)
        ESP->>MOT: Envía PWM vía driver
        MOT->>AUT: Aplica torque de carga
        AUT->>SEN: Mueve eje + aleta
        SEN->>ESP: Realimentación
        SEN->>PC: Log de datos (I-07)
    end

    OPT Sensor de fin de carrera activado
        SEN->>MOT: Corte físico de potencia (RF-BAN-08)
    end

    OPT Fin del ensayo
        PC->>PC: Exporta CSV: δ_cmd(t), δ_real(t), H_med(t), ω(t)
        OP->>PC: Analiza: error de seguimiento, compliance, backlash
    end
```

---

## Comparación con Anastasopoulos & Hornung (2018)

| Característica                               | Anastasopoulos & Hornung (2018)          | Este proyecto                                                                       |
| --------------------------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------- |
| **Tecnología de aplicación de carga** | Motor brushless con driver COTS          | Motor DC (DS3218 intervenido) con driver BTS7960                                    |
| **Lazo de control**                     | Torque vía corriente, hardware dedicado | Torque vía corriente,**software en ESP32**                                   |
| **Sensor de torque**                    | Torquímetro rotativo inline             | Celda de carga + brazo (⚠️ en reevaluación) o torquímetro                       |
| **Medición de posición**              | Encoder en el eje                        | Encoder + IMU (fusión sensorial, §10)                                             |
| **Protección de límites**             | Topes físicos + software                | **Fin de carrera hardware independiente** (RF-BAN-08) + software              |
| **Interfaz manual**                     | No reportada                             | **Panel de potenciómetros** (I-11: condiciones vuelo, I-12: comando directo) |
| **Back-EMF como diagnóstico**          | No reportado                             | **Sí**: ω_rotor/N vs ω_aleta → estima backlash en tiempo real             |
| **Modularidad**                         | Banco fijo para un tipo de actuador      | **Actuador bajo prueba intercambiable** (RF-SIS-02)                           |

---

**Documento relacionado:** `05_Arquitectura_del_Sistema.md` para la descripción textual completa de subsistemas y requisitos trazables.
