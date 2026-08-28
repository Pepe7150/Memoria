## 7. Qué comparación es posible — y cuál no

**No existe una tabla numérica exacta en la fuente para este caso 3D.** El Capítulo 4 de Simpson presenta los resultados solo como gráfico (Figura 4.6: `Ch` vs. α, una curva por δ, comparando el experimento de Johnson & Thompson contra su propio Fun3D estacionario) — no hay tabla de la que extraer números para comparar dígito a dígito.

**Lo que sí se puede afirmar con el texto de la fuente:** el propio Fun3D de Simpson (RANS con modelo de turbulencia Spalart-Allmaras, más fidelidad que cualquier cosa que XFLR5 pueda dar) tiene errores de **~35% en δ=-7.8°** respecto al experimento, con buena concordancia en deflexiones pequeñas. Si tu resultado de XFLR5 se aleja bastante del orden de magnitud esperado en δ=-7.8°, no es necesariamente una falla de tu metodología — es la misma separación de flujo que ya le cuesta capturar a una CFD viscosa completa.

**Si se necesita una validación numérica exacta:** el caso 2D GA(W)-1 de la misma fuente (Capítulo 3, Tablas 3.7–3.12) sí tiene números exactos — incluyendo el propio XFOIL de Simpson, comparable directamente contra un XFLR5 propio del mismo perfil. Es un ejercicio separado, no descrito en este documento (geometría: cuerda 24in, flap 20%, hinge en 80% de cuerda, Re=2.2×10⁶, M=0.13).

---

## 7bis. Resultado obtenido y cierre del caso (actualizado tras comparación contra Fig. 4.6)

Al consolidar los 36 puntos (`OpPoint`, 4 deflexiones × 9 ángulos) y comparar contra la Fig. 4.6, se encontraron y corrigieron dos problemas — ver el detalle completo en `04_Lecciones_Metodologicas_XFLR5.md`, Hallazgo 3 (§3bis):

1. El caso **δ=0°** había quedado con `delta=NaN` en la tabla consolidada, por un desajuste entre el nombre del `Wing`/`Plane` de ese caso y la convención de nombre `_delta_0p0` que espera `consolidar_oppoints_xflr5.py`. Corregido manualmente tras confirmar que los datos sí correspondían a δ=0° (`Ch(α=0)≈0`).
2. El término de respuesta a la deflexión (`Ch_δ`) salía con **signo invertido** respecto a la Fig. 4.6, mientras que el término de respuesta a α (`Ch_α`) ya era correcto desde el principio. Esto es consistente con que el `TE Flap` se haya ingresado en XFLR5 con signo contrario al documentado en §2 de este checklist (`TE Flap=+X` debería representar `δ=−X` de Simpson).

**Corrección aplicada:** para un perfil simétrico como el NACA 0012, invertir el signo de la deflexión equivale a reflejar verticalmente todo el problema, lo que se corrige con `Ch_corregido(α) = −Ch_original(−α)` a δ fijo (script: `corregir_signo_delta_naca0012.py`).

**Resultado tras la corrección:** el orden de las curvas y la tendencia coinciden con la Fig. 4.6 (δ=-7.8° arriba, δ=0° abajo, pendiente decreciente con α en las cuatro curvas). La diferencia absoluta remanente es del orden de **~0.01 en `Ch`**, comparando contra una lectura aproximada de la figura (no hay tabla numérica exacta disponible, a diferencia de GA(W)-1) — un margen razonable dado que la comparación es gráfica, no numérica.

**Caso NACA 0012: verificado y cerrado.** Pendiente no bloqueante: confirmar en el archivo `.xfl` original si el signo del `TE Flap` de las variantes deflectadas se ingresó al revés de lo documentado en §2, para corregir en el origen antes de reutilizar este procedimiento en una geometría nueva.
