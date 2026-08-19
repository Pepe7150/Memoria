# Datasheet del Servo DS3218 (motor de carga) — Referencia técnica

**Proyecto:** Banco de ensayos para dimensionamiento y caracterización de actuadores de superficies de control basado en cargas CFD.

**Estado:** Documenta las especificaciones **de fábrica, a nivel de servo completo** (después de la caja reductora) del DS3218, obtenidas de datasheets oficiales/de fabricante. **No resuelve** la caracterización del motor DC crudo una vez intervenido (ver §4), que sigue pendiente en `06_Seleccion_Actuador_de_Carga.md` §6, ítem 3.

**Documentos relacionados:** `06_Seleccion_Actuador_de_Carga.md`, `03_Requisitos_No_Funcionales.md` (RNF-CAR-01), `05_Arquitectura_del_Sistema.md` (§2.5, §5 supuesto 10).

---

## 1. Advertencia sobre variantes

El "DS3218" se comercializa bajo al menos dos variantes con especificaciones distintas, encontradas en datasheets independientes:

- **DS3218MG estándar** (revendido por ANNIMOS y otros, datasheet genérico "DS-Model Servo")
- **DS3218 PRO Red** ("6V 20kg High Speed Servo", datasheet oficial de **Dongguan City Dsservo Technology Co., Ltd**, fabricante — www.dsservo.com)

Los valores ya registrados en `03_Requisitos_No_Funcionales.md` (RNF-CAR-01: ~1,8–2,1 N·m de bloqueo, ~1,8–2 A de corriente de stall a 6–7 V) **corresponden a la variante estándar (MG)**, no a la PRO. Esta sección confirma esos valores con fuente citable y deja registrada la diferencia por si el componente efectivamente adquirido resulta ser la variante PRO.

**Acción recomendada:** al momento de la compra, verificar en la ficha del producto/vendedor cuál de las dos variantes corresponde, ya que la corriente de stall de la PRO (~2,9 A a 6,8 V) se acerca más al límite superior del sensor INA219 seleccionado (rango 0–3,2 A, ver `06_Seleccion_Actuador_de_Carga.md` §6.1).

## 2. Especificaciones — DS3218MG estándar

**Fuente:** ANNIMOS DS-Model Servo, Product datasheet (fabricante genérico/OEM).

### 2.1 Condiciones ambientales

| Parámetro | Valor |
|---|---|
| Temperatura de almacenamiento | -20 °C a 60 °C |
| Temperatura de operación | -10 °C a 50 °C |
| Rango de voltaje de operación | 4,8–6,8 V |

### 2.2 Especificación mecánica

| Parámetro | Valor |
|---|---|
| Dimensiones | 40 × 20 × 40,5 mm |
| Peso | 60 g |
| Relación de engranaje (gear ratio) | ~250:1 |
| Rodamiento | Doble rodamiento (ball bearing) |
| Motor | 3 polos (motor DC escobillado estándar, **no coreless** pese a lo indicado por algunos revendedores) |
| Grado de protección | IP66 |

### 2.3 Especificación eléctrica (a nivel de servo completo, post-reductora)

| Parámetro | 5 V | 6,8 V |
|---|---|---|
| Corriente en vacío (idle, detenido) | 4 mA | 5 mA |
| Velocidad sin carga | 0,16 s/60° (≈375 °/s) | 0,14 s/60° (≈429 °/s) |
| **Torque de bloqueo (stall)** | 19 kgf·cm = **1,86 N·m** | 21,5 kgf·cm = **2,11 N·m** |
| **Corriente de bloqueo (stall)** | 1,5 A | **1,8 A** |

### 2.4 Especificación de control

| Parámetro | Valor |
|---|---|
| Sistema de control | PWM |
| Ancho de pulso | 500–2500 µs |
| Posición neutral | 1500 µs |
| Rango de giro | 270° (con 500–2500 µs) |
| Ancho de banda muerta (dead band) | 3 µs |
| Frecuencia de operación | 50–330 Hz |

## 3. Especificaciones — DS3218 PRO Red (variante alternativa, para contraste)

**Fuente:** Dongguan City Dsservo Technology Co., Ltd, Product datasheet oficial ("DS3218 PRO Red — 6V 20kg High Speed Servo", www.dsservo.com).

| Parámetro | 5 V | 6,8 V |
|---|---|---|
| Relación de engranaje | 236:1 | — |
| Corriente en vacío | 4 mA | 5 mA |
| Velocidad sin carga | 0,12 s/60° | 0,1 s/60° |
| Torque de bloqueo | 21 kgf·cm = 2,06 N·m | 23,5 kgf·cm = **2,30 N·m** |
| Corriente de bloqueo | 2,1 A | **2,9 A** |
| Motor | 3 polos |

*(Condiciones ambientales, dimensiones y especificación de control son iguales a §2.1/§2.4 salvo temperatura de operación: -25 °C a 70 °C en esta variante.)*

## 4. Lo que sigue pendiente: caracterización del motor DC crudo

Ambos datasheets son **a nivel de servo completo**, es decir, incluyen el efecto de la caja reductora (~236–250:1) y su fricción/eficiencia. Ninguno documenta el motor DC interno como componente aislado, porque es una pieza genérica sin marca ni modelo propio publicado por el fabricante — no existe un datasheet independiente del motor crudo disponible por búsqueda web.

Esto significa que **el ítem 3 de `06_Seleccion_Actuador_de_Carga.md` §6 (Próximos pasos) sigue abierto**: para cerrar RNF-REN-01/02 con valores propios se requiere, una vez intervenido el servo (bypaseado el potenciómetro/controlador interno), caracterizar experimentalmente:

- Corriente nominal y de stall del motor DC solo (sin la reducción de engranajes, o con ella si se mantiene la caja reductora en la implementación final).
- Curva torque–velocidad del motor.
- Constante eléctrica (Kt/Ke) y resistencia de armadura, para modelar el lazo de corriente en software (ver `05_Arquitectura_del_Sistema.md` §5, supuesto 10).

**Lo que este documento sí aporta como avance:** confirma con fuente primaria citable los valores de corriente y torque de bloqueo *a nivel de servo* ya usados en RNF-CAR-01, y deja explícita la relación de engranaje (~236–250:1) necesaria para, una vez caracterizado el motor crudo, poder pasar de "torque en el eje del motor DC" a "torque en el eje de salida del servo" (o viceversa) al interpretar los resultados de la caracterización experimental.

## 5. Referencias

- ANNIMOS DS-Model Servo. *Product datasheet — DS3218MG, 6.8V 20kg Digital Servo.* Disponible en: https://cdck-file-uploads-europe1.s3.dualstack.eu-west-1.amazonaws.com/arduino/original/4X/7/4/f/74f50fff235673f3d7b2a23ae8b8d6e7f30a47f7.pdf
- Dongguan City Dsservo Technology Co., Ltd. *Product datasheet — DS3218 PRO Red, 6V 20kg High Speed Servo.* www.dsservo.com. Disponible en: https://itgresa.com/wp-content/uploads/2025/10/DS-Servo-20kg-DS3218-PRO-datasheet-PDF.pdf
