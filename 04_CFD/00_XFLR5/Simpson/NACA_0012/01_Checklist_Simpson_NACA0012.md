# Simpson NACA 0012: hoja de entrada directa para XFLR5

Este documento sirve para **ingresar el caso en XFLR5**, no para rediseñar el banco. Copiar los números de una sola alternativa completa; no mezclar filas de las dos alternativas.

## Corrección de la geometría actualmente mostrada

- El **offset de 0.8009 m es correcto** para el barrido de 45 grados de Simpson: `offset = semienvergadura * tan(45 grados) = 0.8009 m`.
- Visualmente el desplazamiento hacia atrás es grande porque 45 grados es, efectivamente, un barrido muy grande. La imagen es coherente con esa geometría.
- El perfil de toda la superficie es **NACA 0012**, de cuerda uniforme. El elevador no usa otro perfil: es el 25% final de la misma sección NACA 0012 al que se le aplica giro alrededor de su eje de bisagra.
- La geometría de la captura **no reproduce Simpson**: usa `c = 0.318 m` pero mantiene `b/2 = 0.8009 m`. Por eso XFLR5 entrega `S ≈ 0.51 m²`, `MAC = 0.318 m` y `AR ≈ 5.038`.
- Para Simpson sin escalar, los valores correctos son `c = 0.3810 m`, `S = 0.6103 m²`, `MAC = 0.3810 m` y `AR ≈ 4.204`.

---

# Alternativa A - Réplica geométrica de Simpson (usar primero)

Usar esta alternativa para comparar en los mismos términos con Simpson. Es un estabilizador completo y simétrico, sin fuselaje; equivale a duplicar la semiala experimental alrededor del plano de simetría.

## A1. Crear el perfil

1. Abrir `Direct Foil Design`.
2. Elegir `Foil -> NACA Foils`.
3. Escribir: `0012`.
4. Guardar/comprobar que el nombre aparezca como `NACA 0012`.

## A2. Crear la superficie

1. Crear un objeto de ala/estabilizador **simétrico**, no una aleta vertical.
2. Seleccionar `Symmetric`.
3. Seleccionar `Right Side`.
4. En la tabla de secciones ingresar exactamente lo siguiente.

|      Fila |            y (m) |        chord (m) |       offset (m) | dihedral (deg) | twist (deg) | foil                | X-panels | X-dist | Y-panels | Y-dist |
| --------: | ---------------: | ---------------: | ---------------: | -------------: | ----------: | ------------------- | -------: | ------ | -------: | ------ |
| 1 - raíz |           0.0000 | **0.3810** |           0.0000 |            0.0 |         0.0 | **NACA 0012** |       13 | Cosine |       19 | Sine   |
| 2 - punta | **0.8009** | **0.3810** | **0.8009** |            0.0 |         0.0 | **NACA 0012** |       13 | Cosine |       19 | Sine   |

**No dejar el perfil vacío en la fila de raíz.** Debe ser `NACA 0012` en las dos filas.

## A3. Comprobación inmediata

Después de aceptar la geometría, XFLR5 debe mostrar aproximadamente:

| Magnitud                   |       Valor esperado |
| -------------------------- | -------------------: |
| Envergadura total          |             1.6018 m |
| Área`S`                 | **0.6103 m²** |
| MAC                        |   **0.3810 m** |
| Aspect ratio`AR`         |      **4.204** |
| Barrido de borde de ataque |            45 grados |

Si aparece `S ≈ 0.51 m²`, `MAC = 0.318 m` o `AR ≈ 5.04`, detenerse: sigue ingresada una cuerda de 0.318 m y no se está reconstruyendo Simpson.

## A4. Definir el elevador y el eje de bisagra

| Campo                            |                                        Valor que ingresar |
| -------------------------------- | --------------------------------------------------------: |
| Tipo                             |                        Elevador / flap de borde de salida |
| Extensión en semiala            |              Desde`y = 0.0000 m` hasta `y = 0.8009 m` |
| Extensión total                 | Se replica automáticamente al otro lado por`Symmetric` |
| Cuerda del elevador              |                                          25% de la cuerda |
| Eje de bisagra                   |                   `x/c = 0.75` desde el borde de ataque |
| Posición dimensional de bisagra |                `x = 0.28575 m` desde el borde de ataque |
| Coordenada vertical del eje      |                                               `z/c = 0` |

Revisar visualmente dos veces: elevador neutro y elevador con una deflexión de prueba de `-7.8 grados`.

---

# Alternativa B - Versión compacta de 50 cm de envergadura total

Usar **sólo** si el límite físico de 50 cm se refiere a la envergadura total de la pieza. Es una reducción geométrica uniforme de Simpson: `lambda = 0.5000 / 1.6018 = 0.3121`.

## B1. Tabla de entrada directa

|      Fila |            y (m) |        chord (m) |       offset (m) | dihedral (deg) | twist (deg) | foil                | X-panels | X-dist | Y-panels | Y-dist |
| --------: | ---------------: | ---------------: | ---------------: | -------------: | ----------: | ------------------- | -------: | ------ | -------: | ------ |
| 1 - raíz |           0.0000 | **0.1189** |           0.0000 |            0.0 |         0.0 | **NACA 0012** |       13 | Cosine |       19 | Sine   |
| 2 - punta | **0.2500** | **0.1189** | **0.2500** |            0.0 |         0.0 | **NACA 0012** |       13 | Cosine |       19 | Sine   |

## B2. Valores esperados

| Magnitud             |                            Valor esperado |
| -------------------- | ----------------------------------------: |
| Envergadura total    |                                  0.5000 m |
| Área`S`           |                                0.0595 m² |
| MAC                  |                                  0.1189 m |
| `AR`               |                                     4.204 |
| Cuerda del elevador  |                                  0.0297 m |
| Posición de bisagra | `x = 0.0892 m` desde el borde de ataque |

La alternativa B conserva perfil, forma, barrido y `AR`; cambia Reynolds y los momentos dimensionales. No se puede comparar directamente su momento con la tabla original de Simpson sin declarar esa diferencia.

---

# Corridas del caso Simpson

## Valores publicados por Simpson

| Variable                                 | Ingreso                                      |
| ---------------------------------------- | -------------------------------------------- |
| Mach                                     | `0.5`                                      |
| Reynolds de referencia, basado en cuerda | `5.52e6`                                   |
| AoA (deg)                                | `-8, -6, -4, -2, 0, 2, 4, 6, 8`            |
| Deflexión de elevador (deg)             | `0, -1.7, -3.7, -7.8`                      |
| Total                                    | 4 corridas de deflexión x 9 AoA = 36 puntos |

## Orden exacto de trabajo

- [X] Elegir **A** o **B** y no mezclar valores.
- [X] Crear NACA 0012 y asignarlo a raíz y punta.
- [X] Ingresar la tabla de secciones.
- [X] Verificar `S`, `MAC` y `AR` contra la tabla correspondiente.
- [X] Crear el elevador: 25% final, desde la raíz a la punta de la semiala, eje al 75% de cuerda.
- [X] Crear las cuatro configuraciones: `delta_0`, `delta_-1.7`, `delta_-3.7`, `delta_-7.8`.
- [ ] En cada configuración barrer los nueve AoA publicados.
- [ ] Exportar por separado ángulo, `Cm`, momento respecto de bisagra, `CL`, `CD` y `q`.

## Antes de correr las polares viscosas

**Pausa obligatoria:** Simpson publica `Mach = 0.5` y `Re = 5.52e6`, pero la tabla no fija una altitud, temperatura o presión de túnel suficiente para reconstruirlos automáticamente en XFLR5.

- Para la alternativa A, definir una condición atmosférica equivalente que reproduzca simultáneamente Mach y Reynolds, o recuperar las condiciones del experimento de Johnson y Thompson.
- Para la alternativa B, el Reynolds cambia por la escala; recalcularlo y generar nuevas polares viscosas NACA 0012.
- XFLR5 queda como fallback estático: no añadir velocidad de deflexión a estas corridas.

## Resultado que debe quedar guardado

```text
Simpson_NACA0012_A_o_B.xfl
Simpson_NACA0012_delta_0.csv
Simpson_NACA0012_delta_-1p7.csv
Simpson_NACA0012_delta_-3p7.csv
Simpson_NACA0012_delta_-7p8.csv
Simpson_NACA0012_consolidado.csv
```

## Fuente de los números

Simpson, C. D. (2016), *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics*, capítulo 4, tabla 4.1 y sección 4.3. Fuente pública: https://ir.ua.edu/items/b24e56da-42e8-45ef-861c-f32ff2a6d3e5
