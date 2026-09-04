# Checklist Avance 1 — Estado al 11/09/2026

**Fecha límite:** Viernes 11 de septiembre de 2026 (Semana 5, S5)  
**Horizonte del cronograma:** Ver `00_Administración/01_Cronograma.md`

---

## Resumen ejecutivo

Según el cronograma oficial (§Hitos institucionales), para el **Avance I** se espera tener:

> "Fase A prácticamente cerrada: RF/RNF definitivos (~31/08), actuador de carga seleccionado (~26/08), simulaciones CFD ya en ejecución. Contenido natural para este avance: documento de especificación + metodología CFD en curso."

---

## ✅ Completados (listos para presentar)

### 1. Especificación del proyecto
- [x] `01_Especificacion_del_Proyecto.md` — Alcance, objetivos, restricciones, cronograma
- [x] Inclusión de acuerdos de Avance I (tabla de 4 variables, potenciómetros I-11/I-12)

### 2. Requisitos funcionales y no funcionales
- [x] `02_Requisitos_Funcionales.md` — 20+ RF cubriendo CFD, banco, instrumentación, software
- [x] `03_Requisitos_No_Funcionales.md` — 15+ RNF con valores de referencia (torque ~0.5–2 Nm, precisión 0.5% FE, etc.)
- [x] Incorporación de RF-BAN-08 (fin de carrera) y RNF-SEG-06 (protección hardware independiente)
- [x] Incorporación de RF-BAN-07 (panel de potenciómetros con dos funciones) y RNF-PRE-05/PRE-06 (velocidad angular y potenciómetros)

### 3. Casos de uso
- [x] `04_Casos_de_Uso.md` — 10 casos de uso (CU-001 a CU-010)
- [x] CU-010 agregado para comando manual de ángulo objetivo (acuerdo Avance I)

### 4. Arquitectura del sistema
- [x] `05_Arquitectura_del_Sistema.md` — Diagrama de bloques Mermaid, 7 subsistemas, 12 interfaces (I-01 a I-12)
- [x] Incorporación de switches de fin de carrera (§2.5, línea 110)
- [x] Incorporación de panel de potenciómetros (I-11, I-12)
- [x] Notas de reevaluación (motor de carga, sensor de torque) claramente marcadas

### 5. Estrategia de estimación por fusión sensorial
- [x] `10_Estrategia_Estimacion_Torque_Fusion_Sensorial.md` — Filtro de torque (encoder + IMU + back-EMF)
- [x] Sección 10 agregada: Estrategia de estimación de **ángulo y velocidad angular** (encoder + giroscopio + back-EMF como diagnóstico de backlash)
- [x] Estados propuestos: [θ, ω, b_gyro] con corrección de bias del giroscopio

### 6. Selección preliminar de componentes
- [x] `06_Seleccion_Actuador_de_Carga.md` — Motor de carga DS3218 intervenido (DC crudo)
- [x] Driver H-bridge BTS7960, sensor de corriente INA219, microcontrolador ESP32
- [x] Celda de carga Altronics LC-10KG-HX711 (**en reevaluación**, ver abajo)

### 7. Metodología CFD (en ejecución)
- [x] `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` — NACA 0012 con flap 25%, cuerda 381 mm, envergadura 1.602 m
- [x] Checklist de validación vs. Simpson (XFLR5) completado
- [x] Coeficientes Ch consolidados en Excel
- [x] **Cálculo de momento de bisagra dimensional (Nm)** incorporado: H = Ch × q × S_ctrl × c_ctrl
  - c_ctrl = 95.25 mm (25% de 381 mm)
  - S_ctrl = 0.1526 m² (flap cubre toda la envergadura)
- [ ] `03_Matriz_Casos_CFD_FaseB1.md` — **Pendiente**: incluir rango de velocidades angulares de deflexión (acuerdo Avance I)

### 8. Principios metodológicos
- [x] `00_Principios_Metodologicos.md` — Principio "sistema completo primero, optimizar después" (recomendación Prof. Tinnap)

---

## ⚠️ En reevaluación / pendientes críticos (no bloquean Avance 1)

### 1. Arquitectura física de aplicación de torque
- **Estado:** En reevaluación a solicitud de los profesores guía (27–28/08/2026)
- **Alternativas:** Motor DC (DS3218 intervenido) vs. brushless vs. actuador lineal + brazo
- **Documento:** `05_Diseño_Mecánico/Comparacion_Alternativas_Arquitectura_Fisica.md`
- **Impacto:** No bloquea Avance 1 — la arquitectura de referencia está documentada y las interfaces son agnósticas

### 2. Sensor de torque
- **Estado:** Objetado por profesores guía (acuerdo #4, 28/08/2026)
- **Problema:** Celda de carga fija + brazo de palanca no acompaña el cambio de ángulo de la aleta
- **Alternativas:** Torquímetro rotativo inline, strain gauges en el eje
- **Impacto:** No bloquea Avance 1 — RF-INS-01/02 son agnósticos a la tecnología; RNF-CAR-01/RNF-PRE-02 mantienen umbrales independientemente de la tecnología

### 3. Propagación de confirmación AoA/deflexión separados
- **Estado:** Confirmado en Avance I (acuerdo #2, 28/08/2026)
- **Pendiente:** Actualizar `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` (§6, §8, §10 aún registran pregunta como abierta)
- **Impacto:** Menor — la estructura de tabla de 4 variables ya está confirmada en RF/RNF/CU

---

## 📋 Pendientes de baja prioridad (post-Avance 1)

### 1. Especificación detallada de potenciómetros
- Rango físico de cada perilla (I-11: Mach, AoA; I-12: ángulo objetivo)
- Resolución/repetibilidad requerida (eventual RNF nueva)
- Si I-12 puede actuar como override durante ensayo automático o es exclusivo de modo manual

### 2. Método de medición de velocidad angular
- Decidir entre derivada numérica de encoder vs. sensor dedicado
- Condiciona RNF-PRE-05 (resolución/ruido efectivo [a definir])

### 3. Estrategia de compensación de torque parásito
- Feedforward de velocidad, sincronización, control robusto (Tema 2: Yao et al., Lee & Cho)

### 4. Criterio de detección de atasco mutuo (stall)
- Umbral de torque diferencial sostenido, timeout
- Vinculado a RNF-SEG-04

### 5. Validación experimental del ancho de banda del lazo de corriente en software
- Una vez seleccionado el microcontrolador y montado el banco
- Condiciona si RNF-REN-01/02 (~100–200 Hz) son alcanzables

### 6. Gestión de usuarios/perfiles (uso docente)
- Sin RF explícito todavía; mencionado en Alcance pero no prioritario

---

## 🎯 Entregables naturales para Avance 1

1. **Documento de especificación completo** (`01_Especificacion_del_Proyecto.md` + `02_Requisitos_Funcionales.md` + `03_Requisitos_No_Funcionales.md` + `04_Casos_de_Uso.md`)
2. **Arquitectura del sistema documentada** (`05_Arquitectura_del_Sistema.md` con diagrama Mermaid + interfaces I-01 a I-12)
3. **Estrategia de fusión sensorial** (`10_Estrategia_Estimacion_Torque_Fusion_Sensorial.md` con torque + ángulo/velocidad)
4. **Metodología CFD en ejecución** (`04_CFD/` con geometría validada vs. Simpson, Ch calculados, momentos dimensionales en Nm)
5. **Selección preliminar de componentes** (`06_Seleccion_Actuador_de_Carga.md` con DS3218, BTS7960, INA219, ESP32)
6. **Presentación** (`01_Documentos_Memoria/Avances_semanales/Avance_Reunion_Profesor_01.pptx`)

---

## 🔗 Documentos que requieren actualización menor (no bloqueante)

| Documento | Pendiente | Impacto |
|-----------|-----------|---------|
| `04_CFD/01_Casos/01_Geometria_Aleta_Referencia.md` | Eliminar notas sobre "degeneración AoA/deflexión pendiente de confirmar" | Menor — ya confirmado en Avance I |
| `03_Matriz_Casos_CFD_FaseB1.md` | Incluir rango de velocidades angulares de deflexión como 4ta variable | Medio — requerido para CFD Fase B1 |
| `05_Arquitectura_del_Sistema.md` §2.1 | Eliminar nota sobre posible simplificación de condiciones de operación del Módulo CFD | Menor — ya confirmado AoA/deflexión separados |

---

## 📌 Notas adicionales

- **Fin de carrera:** Incorporado como RF-BAN-08 y RNF-SEG-06, siguiendo a Anastasopoulos & Hornung (2018). Protección hardware independiente del software.
- **Back-EMF:** Tratado como diagnóstico de backlash en tiempo real, no como entrada primaria al filtro de ángulo/velocidad (ver §10 de `10_Estrategia_Estimacion_Torque_Fusion_Sensorial.md`).
- **Cronograma:** Avance II (28/10/2026) debería tener banco construido e instrumentado + primeros resultados de validación. Informe 3 (04/12/2026) deja ~10 días de margen tras redacción final (~24/11).

---

**Próxima acción inmediata:** Generar diagrama de arquitectura del sistema en Mermaid (similar a Anastasopoulos et al.) e integrarlo en `05_Arquitectura_del_Sistema.md` o como documento independiente para la presentación.
