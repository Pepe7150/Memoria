# Pipeline general XFLR5 para tablas de carga de contingencia

**Propósito.** Procedimiento único y reutilizable para construir en XFLR5 una tabla estática de momento de bisagra como *fallback* de la CFD. No sustituye la CFD viscosa, ni representa la velocidad angular de deflexión. El documento termina con un checklist completamente cargado para el caso NACA 0012 de Simpson (2016).

**Alcance de la salida.** El resultado es una tabla de contingencia en variables estáticas: condición de flujo, ángulo y deflexión (cuando la geometría permite distinguirlos). Debe rotularse siempre como `XFLR5 - contingencia - no CFD`.

---

## 0. Antes de abrir XFLR5: definir el caso

Completar esta ficha. Si un dato no está respaldado por la fuente, marcarlo como pendiente; no reemplazarlo por una suposición silenciosa.

| Campo             | Valor a definir                                                             |
| ----------------- | --------------------------------------------------------------------------- |
| Fuente y versión | Autor, año, tabla/figura/página                                           |
| Configuración    | Aleta aislada, semiala con plano de simetría, estabilizador completo, etc. |
| Perfil(es)        | Nombre o archivo`.dat`; espesor y curvatura                               |
| Planta            | Cuerda(s), envergadura, barrido, torsión y superficies móviles            |
| Eje de bisagra    | Posición`x/c`, `z/c` y extensión en envergadura                       |
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
| -------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------ | -------------------------------------------------------------------------- |
| Perfil delgado, doble cuña o borde de ataque agudo; no hay polar viscosa fiable | Paneles 3D, inviscid                              | Conserva espesor y geometría        | Sin capa límite, separación ni corrección de compresibilidad verificada |
| Perfil redondeado y rango de Reynolds donde XFoil converge                       | XFoil viscoso 2D + VLM 3D con corrección viscosa | Incluye polares viscosas seccionales | VLM representa la línea media; no conserva el espesor 3D                  |

No llamar a la primera rama “más precisa”. Para bordes agudos en subsónico, se elige porque una polar viscosa no convergente sería menos defendible. Para un NACA 0012, comenzar por la rama viscosa y conservar una corrida inviscid de paneles 3D como comparación de sensibilidad.

---

## 2. Preparar el perfil y la superficie móvil

### 2.1 Perfil

1. Si el perfil es NACA de cuatro o cinco dígitos, usar `Direct Foil Design -> Foil -> NACA Foils` y guardar el perfil generado.
2. Si la fuente entrega coordenadas, importarlas como `.dat` en formato Selig y verificar visualmente borde de ataque, borde de salida y espesor.
3. Si el perfil es doble cuña u otro perfil no nativo, generar/importar sus coordenadas y verificar el `t/c` calculado.

### 2.2 Superficie móvil y eje de bisagra

1. Definir el eje con la posición de la fuente, por ejemplo `x_h/c = 0.75` para una superficie móvil final de 25% de cuerda.
2. Aplicar la deflexión geométrica de la superficie móvil en el sentido definido por la fuente. Registrar la convención de signos y una captura de pantalla de la geometría en deflexión nula y extrema.
3. Situar el punto de referencia del momento en el eje de bisagra. No usar el centro aerodinámico ni el centro de gravedad por defecto sin verificar el resultado.

---

## 3. Construir la geometría 3D

1. Crear el tipo de objeto según la regla de compatibilidad de la sección 0.
2. Ingresar cada sección con sus coordenadas, cuerda, offset por barrido, diedro, torsión y perfil correspondiente.
3. Verificar analíticamente área de referencia `S`, cuerda media aerodinámica `c_bar` y envergadura antes de correr polares.
4. Refinar paneles cerca del borde de ataque, punta, eje de bisagra y superficie móvil. Guardar el proyecto `.xfl` antes de las corridas.

Para una planta rectangular sin torsión: `S = b*c`, `c_bar = c` y `AR = b^2/S = b/c`.

---

## 4. Preparar las polares viscosas (sólo rama viscosa)

1. En XFoil/XFLR5, crear una polar **viscosa** por perfil y Reynolds relevante.
2. Usar `Re = rho*V*c/mu`, con la cuerda física de cada sección. Si cambian cuerda o escala, cambian Reynolds y potencialmente los coeficientes.
3. Activar la corrección de compresibilidad disponible sólo dentro de su rango de validez y registrar la opción elegida.
4. Barrer el ángulo efectivo suficiente para cubrir AoA y deflexión de la matriz. No rellenar por extrapolación zonas donde XFoil no converge.
5. Asignar a cada sección su polar viscosa correspondiente y seleccionar VLM con corrección viscosa para el análisis 3D.

**Regla de escala:** con viscosidad no es válido resolver una geometría arbitraria y multiplicar luego el momento por `lambda^3`. Primero se define la escala física, luego se recalcula Reynolds y las polares.

---

## 5. Configurar y correr la matriz 3D

1. Crear una polar por combinación de condición de flujo y deflexión si la versión no permite incluir la deflexión como variable del barrido.
2. Usar `3D Panels` para la rama inviscid, o `VLM1/VLM2` con polares viscosas para la rama viscosa.
3. Ingresar condiciones atmosféricas coherentes. Mach, Reynolds, densidad y temperatura no son valores independientes: comprobar que la combinación reproduzca los valores objetivo.
4. Barrer AoA o ángulo total usando exactamente los puntos de la fuente cuando el propósito sea comparativo.
5. Exportar cada polar a CSV/Excel, conservando columnas de ángulo, `Cm`, `q`, fuerzas y momento dimensional.

### Controles de calidad obligatorios

| Control           | Qué revisar                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| Geometría        | `S`, `c_bar`, barrido, eje de bisagra, orientación y signo de deflexión                     |
| Unidades          | m, s, kg y N m; no mezclar pulgadas con milímetros                                               |
| Momento           | Punto de referencia exactamente en el eje de bisagra                                              |
| Convergencia      | Mensajes de XFoil/XFLR5, rango angular y resolución de paneles                                   |
| Tendencia física | Linealidad sólo lejos de pérdida; no marcar una no linealidad viscosa como error automático    |
| Comparación      | Usar los mismos Mach, Reynolds, ángulos, deflexiones y referencia de momento que CFD/experimento |

---

## 6. Consolidar la tabla de contingencia

Usar formato largo, una fila por condición:

```text
caso,modelo_xflr5,perfil,Mach,Re,altitud_m,temperatura_K,aoa_deg,deflexion_deg,
torque_bisagra_Nm,Cm,area_m2,cuerda_ref_m,origen,limitaciones
```

Incluir en el encabezado o metadata: versión de XFLR5, fecha, rama usada, configuración geométrica, fuente, escala, eje de bisagra y las limitaciones relevantes. No mezclar los resultados XFLR5 con los CFD en un mismo campo sin conservar una columna de `origen`.
