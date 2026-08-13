# Revisión de literatura — Banco de ensayos de actuadores de superficies de control

Archivo consolidado con las referencias encontradas por tema. El archivo `referencias_bibliograficas.bib` contiene todas las entradas en formato BibTeX, listo para importar en Zotero (Archivo → Importar).

## Tema 1: Métodos CFD para cargas aerodinámicas (15 referencias)

---

**1. Simpson, C. D. (2016).** *Control Surface Hinge Moment Prediction Using Computational Fluid Dynamics.* Tesis de maestría, Utah State University.
Compara métodos de predicción de momento de charnela (bisagra) para superficies de control: relaciones empíricas (Datcom), XFOIL y CFD viscoso con Fun3D (NASA), incluyendo adaptación de malla basada en adjunto. Útil como referencia metodológica directa para comparar niveles de fidelidad al generar las tablas de carga del banco.

**2. Solarte-Pineda, J., Bravo-Mosquera, P. D., Fernandino Westin, M., & Moura Castro, B. (2026).** *Unsteady Aerodynamics and Hinge Moment Calculations of Control Surfaces at Transonic Speeds.* Journal of Aircraft. DOI: 10.2514/1.C038573
Metodología para calcular momento de charnela y sus derivadas en flujo transónico no estacionario usando el software de código abierto SU2, con movimiento de malla. Referencia reciente y directamente aplicable a la generación de cargas dinámicas para el banco.

**3. Grismer, M., Kinsey, D., & Grismer, D. (2000).** *Hinge Moment Predictions Using CFD.* 18th Applied Aerodynamics Conference, AIAA Paper 2000-4325. DOI: 10.2514/6.2000-4325
Trabajo clásico sobre predicción de momentos de charnela mediante CFD; discute efectos de modelar las paredes del túnel de viento en las soluciones numéricas al comparar con datos experimentales. Buen antecedente histórico/metodológico.

**4. Da Ronch, A., Ghoreyshi, M., & Badcock, K. J. (2011).** *On the Generation of Flight Dynamics Aerodynamic Tables by Computational Fluid Dynamics.* Progress in Aerospace Sciences, 47(8), 597–620. DOI: 10.1016/j.paerosci.2011.09.001
Muy relevante para el proyecto: propone un método para generar tablas aerodinámicas multidimensionales (look-up tables) a partir de CFD usando un modelo sustituto tipo kriging, reduciendo el número de corridas de alta fidelidad necesarias. Es prácticamente el mismo problema que "CFD → tablas de carga" planteado en la arquitectura del banco.

**5. Sinha, A., Kumar, R., & Umakant, J. (2022).** *Reduced-Order Model for Efficient Generation of a Subsonic Missile's Aerodynamic Database.* The Aeronautical Journal, 126(1303), 1546–1567. DOI: 10.1017/aer.2022.4
Desarrolla un modelo de orden reducido (POD) entrenado con soluciones CFD para predecir coeficientes aerodinámicos de un misil en segundos en vez de horas, con errores de interpolación <1%. Aporta ideas para acelerar la generación de la base de datos aerodinámica del proyecto.

**6. DeSpirito, J., Edge, H. L., Weinacht, P., Sahu, J., & Dinavahi, S. P. G. (2000).** *Computational Fluid Dynamic (CFD) Analysis of a Generic Missile with Grid Fins.* U.S. Army Research Laboratory, ARL-TR-2318.
Analiza mediante CFD viscoso las cargas aerodinámicas sobre un misil genérico con superficies de control tipo "grid fin", comparando con datos experimentales. Relevante como ejemplo de metodología CFD aplicada específicamente a superficies de control de vehículos guiados.

**7. Ghoreyshi, M., Vallespin, D., Da Ronch, A., Badcock, K. J., Vos, J., & Hitzel, S. (2010).** *Simulation of Aircraft Manoeuvres Based on Computational Fluid Dynamics.* AIAA Atmospheric Flight Mechanics Conference, Toronto. DOI: 10.2514/6.2010-8239
Genera y valida tablas aerodinámicas por muestreo/reconstrucción a partir de CFD, incluyendo superficies de control móviles, y las valida contra corridas CFD tiempo-exactas replicando maniobras. Ejemplo directo de validación de la metodología "CFD → tabla → aplicación de carga".

**8. NASA (1971).** *Fin Loads and Control-Surface Hinge Moments Measured in Flight.* NASA Technical Report.
Reporte histórico con mediciones en vuelo de cargas normales, momentos flectores y de torsión sobre aletas y superficies de control, y su variación con ángulo de ataque y deflexión. Sirve como referencia de datos experimentales de contraste para validar cargas obtenidas por simulación.

**9. Natale, N., Salomone, T., De Stefano, G., & Piccolo, A. (2020).** *Computational Evaluation of Control Surfaces Aerodynamics for a Mid-Range Commercial Aircraft.* Aerospace, 7(10), 139. DOI: 10.3390/aerospace7100139
Aplica CFD (RANS) sobre la geometría real de un avión comercial regional para predecir cargas aerodinámicas de las superficies de control de borde de fuga, comparando contra datos industriales de referencia (Leonardo Aircraft). Buen ejemplo de metodología con mallas relativamente gruesas orientada a diseño preliminar, replicable en el proyecto.

**10. DeSpirito, J., Vaughn, M. E., & Washington, W. D. (2002).** *Numerical Investigation of Aerodynamics of Canard-Controlled Missile Using Planar and Grid Tail Fins, Part I: Supersonic Flow.* U.S. Army Research Laboratory, ARL-TR-2848.
CFD viscoso sobre un misil genérico con canard, comparando aletas planas y tipo grid a Mach 1.5 y 3.0, validado contra túnel de viento. Aporta un caso de validación específico para superficies de control deflectadas en régimen supersónico.

**11. Ghoreyshi, M., Jirasek, A., Aref, P., & Seidel, J. (2022).** *Computational Aerodynamic Investigation of Long Strake-Tail Missile Configurations.* Aerospace Science and Technology, 127, 107704. DOI: 10.1016/j.ast.2022.107704
Caracteriza mediante CFD distintas configuraciones de misil con aletas de cola totalmente móviles (deflectadas para producir momentos de roll/pitch/yaw), comparando con Missile DATCOM y mediciones. Relevante para entender cómo se generan cargas por combinación de deflexiones de superficies de control.

**12. Yan, L., Chang, X., Wang, N., Zhang, L., Liu, W., & Deng, X. (2023).** *Aerodynamic Identification and Control Law Design of a Missile Using Machine Learning.* AIAA Journal, 61(7), 2998–3018. DOI: 10.2514/1.J062801
Combina malla dinámica/overset con acoplamiento CFD/dinámica de cuerpo rígido para simular la deflexión del elevador de un misil, e identifica el momento aerodinámico con una red neuronal a partir de pocos datos no estacionarios. Interesante como referencia de generación eficiente de datos de carga no estacionaria por deflexión de superficie de control.

**13. Allen, J., & Ghoreyshi, M. (2018).** *Forced Motions Design for Aerodynamic Identification and Modeling of a Generic Missile Configuration.* Aerospace Science and Technology, 77, 742–754. DOI: 10.1016/j.ast.2018.04.014
Diseña maniobras forzadas (barridos de Mach, superposición de ángulo de ataque y cabeceo) para estimar derivadas de estabilidad de un misil con un número reducido de simulaciones CFD no estacionarias. Útil como metodología para reducir el costo computacional de generar la base de datos de cargas del banco.

**14. Allen, J. D., Ghoreyshi, M., Jirasek, A., & Satchell, M. (2018).** *Aerodynamic Loads Identification and Modeling of UCAV Configurations with Control Surfaces Using Prescribed CFD Maneuvers.* AIAA Paper 2018-2999, Applied Aerodynamics Conference. DOI: 10.2514/6.2018-2999
Identifica y modela las cargas generadas específicamente por las superficies de control de un UCAV a partir de maniobras CFD prescritas, en vez de barridos estáticos convencionales. Es de los antecedentes más directos para la metodología "maniobra CFD → carga sobre superficie de control" del proyecto.

**15. Laurenceau, J., & Sagaut, P. (2008).** *Building Efficient Response Surfaces of Aerodynamic Functions with Kriging and Cokriging.* AIAA Journal, 46(2), 498–507. DOI: 10.2514/1.32308
Compara estrategias de muestreo y modelos de interpolación (kriging, cokriging con gradientes) para construir superficies de respuesta aerodinámicas con el menor número posible de simulaciones CFD. Referencia metodológica clave para la etapa de interpolación de las tablas de carga del banco (RF-002 del proyecto).

---

### Notas del tema 1
- Todas las referencias fueron localizadas por búsqueda web; antes de citarlas formalmente en el documento de especificación, conviene verificar el acceso al texto completo (algunas están detrás de paywall de AIAA/Cambridge/ScienceDirect — revisa si tu institución tiene acceso).

---

## Tema 2: Banco de ensayos / simulación de carga sobre actuadores (15 referencias)

**1. Plummer, A. R. (2007).** *Control Techniques for Structural Testing: A Review.* Proc. IMechE Part I: J. Systems and Control Engineering, 221(2), 139–169. DOI: 10.1243/09596518JSCE295
Revisión clásica y muy citada de algoritmos de control (lazo cerrado y abierto) usados en bancos de ensayo dinámicos que replican fuerzas/movimientos reales en laboratorio, principalmente con actuación electrohidráulica. Excelente punto de partida como marco conceptual para el diseño de control del banco.

**2. Anastasopoulos, L., & Hornung, M. (2018).** *Design of a Real-Time Test Bench for UAV Servo Actuators.* AIAA AVIATION Forum, AIAA 2018-3735. DOI: 10.2514/6.2018-3735
Banco de ensayos tipo dinamómetro para emular cargas aerodinámicas sobre servoactuadores de UAV, con motor de carga aplicando torque en el eje de charnela y sensores de torque/corriente. Es el antecedente más directo y cercano en escala/objetivo al banco propuesto en el proyecto.

**3. Yao, J., Jiao, Z., Shang, Y., & Huang, C. (2010).** *Adaptive Nonlinear Optimal Compensation Control for Electro-Hydraulic Load Simulator.* Chinese Journal of Aeronautics, 23(6), 720–733. DOI: 10.1016/S1000-9361(09)60274-3
Propone un controlador adaptativo no lineal para compensar el "torque excedente" (extra torque) generado por el movimiento del actuador bajo prueba en un simulador de carga electrohidráulico. Relevante para el diseño de control del banco al aplicar torque objetivo mientras el actuador se mueve.

**4. Jiao, Z., Gao, J., Hua, Q., & Wang, S. (2004).** *The Velocity Synchronizing Control on the Electro-Hydraulic Load Simulator.* Chinese Journal of Aeronautics, 17(1), 39–46. DOI: 10.1016/S1000-9361(11)60201-6
Trabajo temprano y de referencia sobre simuladores de carga electrohidráulicos, que introduce el control por sincronización de velocidad para reducir la interferencia entre el movimiento del actuador y la carga aplicada.

**5. Yao, J., Jiao, Z., & Yao, B. (2012).** *Robust Control for Static Loading of Electrohydraulic Load Simulator with Friction Compensation.* Chinese Journal of Aeronautics, 25(6), 954–962. DOI: 10.1016/S1000-9361(11)60466-0
Control robusto para aplicar cargas estáticas con compensación de fricción en un simulador de carga electrohidráulico. Aporta un caso concreto de cómo tratar la fricción como fuente de error al reproducir la carga objetivo.

**6. Lee, S. Y., & Cho, H. S. (2001).** *A Fuzzy Controller for an Aeroload Simulator Using Phase Plane Method.* IEEE Transactions on Control Systems Technology, 9(6), 791–801. DOI: 10.1109/87.960340
Control difuso basado en plano de fase para un simulador de carga aerodinámica, con foco en eliminar el torque parásito generado por el movimiento simultáneo del actuador bajo prueba.

**7. Nam, Y. (2001).** *QFT Force Loop Design for the Aerodynamic Load Simulator.* IEEE Transactions on Aerospace and Electronic Systems, 37(4), 1384–1392. DOI: 10.1109/7.976972
Diseña el lazo de control de fuerza de un simulador de carga aerodinámica mediante Quantitative Feedback Theory (QFT), un enfoque robusto frente a incertidumbre paramétrica. Referencia técnica útil para la etapa de control del banco.

**8. Ahn, K. K., Truong, D. Q., Thanh, T. Q., & Lee, B. R. (2008).** *Online Self-Tuning Fuzzy Proportional-Integral-Derivative Control for Hydraulic Load Simulator.* Proc. IMechE Part I: J. Systems and Control Engineering, 222(2), 81–95. DOI: 10.1243/09596518JSCE480
Controlador PID difuso auto-ajustable en línea para un simulador de carga hidráulico, orientado a mejorar la precisión de seguimiento de la carga objetivo ante no linealidades del sistema.

**9. Zhao, Y., Qiu, C., Huang, J., Tan, Q., Sun, S., & Gong, Z. (2024).** *Terminal Sliding Mode Force Control Based on Modified Fast Double-Power Reaching Law for Aerospace Electro-Hydraulic Load Simulator of Large Loads.* Actuators, 13(4), 145. DOI: 10.3390/act13040145
Aborda el problema de seguimiento de fuerza en simuladores de carga electrohidráulicos aeroespaciales de grandes cargas, con alta inercia y fuerte acoplamiento. Referencia reciente y directamente aplicable si el banco maneja cargas de magnitud considerable.

**10. Jing, C., Zhang, H., Hui, Y., Zhang, L., & Xu, H. (2024).** *Adaptive Robust Disturbance Rejection Backstepping Control of a Novel Friction Electro-Hydraulic Load Simulator.* Ain Shams Engineering Journal, 15(12), 103092. DOI: 10.1016/j.asej.2024.103092
Propone un nuevo diseño de simulador de carga electrohidráulico friccional que evita el problema de acoplamiento fuerza-movimiento típico de los simuladores tradicionales, con control adaptativo robusto.

**11. Chen, Z., Yan, H., Zhang, P., Shan, J., & Li, J. (2024).** *Adaptive NN Force Loading Control of Electro-Hydraulic Load Simulator.* Actuators, 13(12), 471. DOI: 10.3390/act13120471
Usa redes neuronales adaptativas para manejar incertidumbres y no linealidades en el control de carga de un simulador electrohidráulico, con backstepping y función de Lyapunov de barrera. Ejemplo de enfoque de control más moderno (aprendizaje) aplicado al mismo problema.

**12. Li, Z., Chen, G., & Zhang, C. (2022).** *Research on Position and Torque Loading System with Velocity-Sensitive and Adaptive Robust Control.* Sensors, 22(4), 1329. DOI: 10.3390/s22041329
Compara estrategias de control PID convencional y sensible a velocidad para sistemas de carga de posición y torque, evaluando precisión de seguimiento. Útil como referencia comparativa de desempeño entre esquemas de control simples y avanzados.

**13. Truong, D. Q., Ahn, K. K., & Yoon, J. I. (2008).** *A Study on Force Control of Electric-Hydraulic Load Simulator Using an Online Tuning Quantitative Feedback Theory.* ICCAS 2008, 2622–2627. DOI: 10.1109/ICCAS.2008.4694299
Presenta un simulador de carga electrohidráulico con ajuste en línea de QFT para pruebas de desempeño y estabilidad en banco, en un contexto donde el control preciso de fuerza es crítico.

**14. Wang, X., & Feng, D. Z. (2009).** *A Study on Dynamics of Electric Load Simulator Using Spring Beam and Feedforward Control Technique.* 2009 Chinese Control and Decision Conference (CCDC), 301–306. DOI: 10.1109/CCDC.2009.5192559
Analiza la dinámica de un simulador de carga eléctrico que usa una viga elástica (spring beam) como elemento de acoplamiento mecánico, combinado con control feedforward. Ofrece una alternativa mecánica distinta a los sistemas puramente hidráulicos.

**15. Oberschwendtner, S., Teubl, D., & Hornung, M. (2022).** *Static Test Procedure for Electromechanical Actuators for UAV Applications.* AIAA AVIATION Forum. DOI: 10.2514/6.2022-3705
Complementa la referencia 2 (mismo grupo de investigación): define un procedimiento de ensayo estático para actuadores electromecánicos de UAV, útil como referencia metodológica para definir protocolos de prueba en el banco.

### Notas del tema 2
- La mayoría de estas referencias abordan el problema desde la óptica de control (eliminar el "torque/fuerza excedente" causado por el movimiento del actuador bajo prueba), que es uno de los desafíos centrales identificados en el riesgo #2 de la especificación del proyecto ("Dificultad en la reproducción experimental de las cargas objetivo").
- Hay una línea de trabajo muy activa en China (grupo de Jiao/Yao, Beihang University) sobre simuladores de carga electrohidráulicos para aplicaciones aeroespaciales; si el banco de ensayos usa actuación hidráulica en vez de eléctrica, esa línea es especialmente relevante.

---

## Tema 3: Actuadores para superficies de control (15 referencias)

**1. Annaz, F. Y., & Kaluarachchi, M. M. (2023).** *Progress in Redundant Electromechanical Actuators for Aerospace Applications.* Aerospace, 10(9), 787. DOI: 10.3390/aerospace10090787
Revisión crítica y reciente de arquitecturas de actuación de superficies de control (electrohidráulica, electromecánica) y del fenómeno de "force-fighting" en sistemas redundantes. Muy buen punto de partida para el estado del arte de actuadores.

**2. Qiao, G., Liu, G., Shi, Z., Wang, Y., Ma, S., & Lim, T. C. (2018).** *A Review of Electromechanical Actuators for More/All Electric Aircraft Systems.* Proc. IMechE Part C, 232(22), 4128–4151. DOI: 10.1177/0954406217749869
Revisión extensa de actuadores electromecánicos lineales de tipo aeronáutico, cubriendo motor tolerante a fallas, transmisión mecánica de alto empuje, modelado multidisciplinario y gestión térmica. Referencia técnica de fondo muy completa.

**3. Li, J., Yu, Z., Huang, Y., & Li, Z. (2016).** *A Review of Electromechanical Actuation System for More Electric Aircraft.* 2016 IEEE International Conference on Aircraft Utility Systems (AUS), Beijing, 490–497.
Revisión complementaria a la anterior sobre sistemas de actuación electromecánica para aeronaves "more electric", con enfoque en arquitecturas y componentes clave.

**4. Nalci, M. O., & Kayran, A. (2014).** *Aeroservoelastic Modeling and Analysis of a Missile Control Surface with a Nonlinear Electromechanical Actuator.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2014-2055. DOI: 10.2514/6.2014-2055
Modela y analiza una superficie de control de misil operada por un actuador electromecánico no lineal (limitado en potencia), integrando el modelo estructural del fin, el modelo aerodinámico (matriz GAF) y el sistema de servoactuación. Referencia muy directa al dominio del proyecto (misiles, actuador + superficie de control + carga aerodinámica).

**5. Shin, W. H. (2007).** *Nonlinear Aeroelastic Analysis for a Control Fin with an Actuator.* Journal of Aircraft, 44(2), 597–605. DOI: 10.2514/1.24680
Analiza el comportamiento aeroelástico no lineal de un fin de control junto con su actuador, relevante para entender la interacción dinámica actuador-superficie de control bajo carga aerodinámica.

**6. Papini, L., Connor, P., Patel, C., Empringham, L., Gerada, C., & Wheeler, P. (2018).** *Design and Testing of Electromechanical Actuator for Aerospace Applications.* 2018 25th International Workshop on Electric Drives (IWED), Moscú.
Diseño y ensayo experimental de un actuador electromecánico para un sistema de control de vuelo (swash-plate de helicóptero), validando el desempeño predicho mediante prototipos. Ejemplo concreto de flujo diseño→prototipo→validación experimental, análogo al del proyecto.

**7. Baldo, L., Querques, I., Dalla Vedova, M. D. L., & Maggiore, P. (2023).** *A Model-Based Prognostic Framework for Electromechanical Actuators Based on Metaheuristic Algorithms.* Aerospace, 10(3), 293. DOI: 10.3390/aerospace10030293
Propone un marco de pronóstico basado en modelos y algoritmos metaheurísticos para monitorear la salud de actuadores electromecánicos. Aporta una perspectiva de mantenimiento/monitoreo que puede complementar la instrumentación del banco.

**8. Fu, S., & Avdelidis, N. P. (2023).** *Prognostic and Health Management of Critical Aircraft Systems and Components: An Overview.* Sensors, 23(19), 8124. DOI: 10.3390/s23198124
Panorama general de técnicas de monitoreo de salud y pronóstico aplicadas a sistemas críticos de aeronaves, incluyendo actuadores. Útil como referencia de contexto para la instrumentación orientada a caracterización de actuadores.

**9. Chakraborty, I., Trawick, D. R., Jackson, D., & Mavris, D. N. (2013).** *Electric Control Surface Actuator Design Optimization and Allocation for the More Electric Aircraft.* AIAA 2013-4283. DOI: 10.2514/6.2013-4283
Optimiza actuadores eléctricos (electrohidrostáticos y electromecánicos) para superficies de control primarias y secundarias de un avión comercial, en función de las cargas de vuelo identificadas. Metodológicamente cercano al objetivo de dimensionamiento de actuadores del proyecto.

**10. Stephan, R., Stumpf, E., Schottmüller, H., Röben, T., Dreyer, N., & Immler, T. (2023).** *Methodology for Preliminary Flight Control Actuator Design.* Journal of Aircraft, 60(5), 1538–1552. DOI: 10.2514/1.C036717
Presenta una metodología de diseño preliminar de actuadores de control de vuelo (electromecánicos y electrohidrostáticos) que permite estimar peso, potencia y volumen con pocos datos de entrada, sin necesidad de una base de datos empírica. Referencia directamente aplicable al proceso de dimensionamiento que busca apoyar el banco de ensayos.

**11. Jensen, S. C., Jenney, G. D., & Dawson, D. (2000).** *Flight Test Experience with an Electromechanical Actuator on the F-18 Systems Research Aircraft.* 19th Digital Avionics Systems Conference, 2E3/1–2E3/10.
Reporta la integración y ensayo en vuelo de un actuador electromecánico (programa EPAD) en el alerón de un F/A-18, comparando su desempeño contra el actuador hidráulico original. Referencia histórica clásica sobre validación experimental de actuadores de superficies de control.

**12. Budinger, M., Liscouët, J., Hospital, F., & Maré, J.-C. (2012).** *Estimation Models for the Preliminary Design of Electromechanical Actuators.* Proc. IMechE Part G, 226(3), 243–259. DOI: 10.1177/0954410011408941
Desarrolla modelos de estimación para el diseño preliminar de actuadores electromecánicos, generando los parámetros necesarios para un diseño multi-objetivo. Complementa directamente a Stephan et al. (2023) como metodología de dimensionamiento.

**13. Zhang, R., Wu, Z., & Yang, C. (2015).** *Dynamic Stiffness Testing-Based Flutter Analysis of a Fin with an Actuator.* Chinese Journal of Aeronautics, 28(5). DOI: 10.1016/j.cja.2015.08.016
Analiza el flameo (flutter) de un fin de control con su actuador a partir de ensayos de rigidez dinámica, relevante para entender límites dinámicos del actuador al aplicarle cargas variables en el banco.

**14. Rosero, J. A., Ortega, J. A., Aldabas, E., & Romeral, L. (2007).** *Moving Towards a More Electric Aircraft.* IEEE Aerospace and Electronic Systems Magazine, 22(3), 3–9. DOI: 10.1109/MAES.2007.340500
Artículo de panorama, muy citado, sobre la transición de sistemas hidráulicos a eléctricos en aeronaves, incluyendo actuadores de superficies de control. Buena referencia introductoria/contextual para la sección de estado del arte.

**15. Fu, J., Maré, J.-C., & Fu, Y. (2017).** *Modelling and Simulation of Flight Control Electromechanical Actuators with Special Focus on Model Architecting, Multidisciplinary Effects and Power Flows.* Chinese Journal of Aeronautics, 30(1), 47–65. DOI: 10.1016/j.cja.2016.07.006
Propone una metodología de modelado multidisciplinario (mecánico, eléctrico, térmico) de actuadores electromecánicos de control de vuelo, incluyendo flujos de potencia. Útil para plantear el modelo del actuador bajo prueba dentro de la arquitectura de control del banco.

### Notas del tema 3
- Nalci & Kayran (2014) y Zhang, Wu & Yang (2015) son las referencias más cercanas al dominio específico del proyecto (misil/superficie de control + actuador + carga aerodinámica), mientras que las demás son en su mayoría del ámbito de aeronaves comerciales/militares "more electric" pero con metodologías directamente transferibles.
- Stephan et al. (2023), Budinger et al. (2012) y Chakraborty et al. (2013) forman un conjunto coherente de metodologías de dimensionamiento preliminar de actuadores, relevante para el objetivo específico "Diseñar la arquitectura mecánica, electrónica y de control" del proyecto.

---

## Tema 4: Interpolación / generación de tablas aerodinámicas (15 referencias)

Nota: dos de estas 15 referencias (Da Ronch et al. 2011 y Laurenceau & Sagaut 2008) ya figuraban en el Tema 1 (CFD) porque encajaban naturalmente ahí; se listan aquí de nuevo por pertenecer también a este eje temático, pero solo cuentan una vez en el archivo `.bib` y en el Excel.

**1. Da Ronch, A., Ghoreyshi, M., & Badcock, K. J. (2011).** *On the Generation of Flight Dynamics Aerodynamic Tables by Computational Fluid Dynamics.* Progress in Aerospace Sciences, 47(8), 597–620. *(ver detalle en Tema 1)*

**2. Laurenceau, J., & Sagaut, P. (2008).** *Building Efficient Response Surfaces of Aerodynamic Functions with Kriging and Cokriging.* AIAA Journal, 46(2), 498–507. *(ver detalle en Tema 1)*

**3. Mackman, T. J., Allen, C. B., Ghoreyshi, M., & Badcock, K. J. (2013).** *Comparison of Adaptive Sampling Methods for Generation of Surrogate Aerodynamic Models.* AIAA Journal, 51(4), 797–808. DOI: 10.2514/1.J051607
Compara dos estrategias de muestreo adaptativo (Kriging vs. función de base radial) para construir modelos sustitutos que recuperan coeficientes aerodinámicos, reduciendo el número de simulaciones CFD necesarias. Referencia central y muy citada para la etapa de interpolación de las tablas de carga.

**4. de Visser, C. C., Mulder, J. A., & Chu, Q. P. (2008).** *Global Aerodynamic Modeling with Multivariate Splines.* AIAA Modeling and Simulation Technologies Conference and Exhibit.
Introduce el uso de splines multivariados para construir modelos aerodinámicos globales no lineales, como alternativa a las tablas de búsqueda tradicionales.

**5. de Visser, C. C., Mulder, J. A., & Chu, Q. P. (2009).** *Global Nonlinear Aerodynamic Model Identification with Multivariate Splines.* AIAA Atmospheric Flight Mechanics Conference, AIAA 2009-5726. DOI: 10.2514/6.2009-5726
Extiende el trabajo anterior a la identificación de modelos aerodinámicos no lineales globales a partir de datos, usando splines multivariados como método de interpolación/ajuste.

**6. de Visser, C. C., Mulder, J. A., & Chu, Q. P. (2010).** *A Multidimensional Spline-Based Global Nonlinear Aerodynamic Model for the Cessna Citation II.* AIAA Atmospheric Flight Mechanics Conference.
Aplica la metodología de splines multivariados a un caso real (Cessna Citation II), demostrando su viabilidad frente a tablas de búsqueda convencionales para simulación de vuelo.

**7. Garbo, A., Parekh, J., Rischmann, T., & Bekemeyer, P. (2024).** *Multi-Fidelity Adaptive Sampling for Surrogate-Based Optimization and Uncertainty Quantification.* Aerospace, 11(6), 448. DOI: 10.3390/aerospace11060448
Propone una técnica de muestreo multi-fidelidad que separa la selección de nuevas muestras del nivel de fidelidad, mejorando la eficiencia computacional frente a métodos de fidelidad única. Referencia reciente sobre cómo combinar datos de distinta fidelidad (p. ej. CFD gruesa/fina) al construir la tabla de carga.

**8. Leng, G. (1997).** *Compression of Aircraft Aerodynamic Database Using Multivariable Chebyshev Polynomials.* Advances in Engineering Software, 28(2), 133–141. DOI: 10.1016/S0965-9978(96)00043-9
Trabajo clásico que usa polinomios de Chebyshev multivariables para comprimir bases de datos aerodinámicas tabulares (validado con datos del F-16), reduciendo tamaño de almacenamiento y horas-hombre de modelado. Alternativa de interpolación/aproximación distinta a kriging o splines.

**9. Kuya, Y., Takeda, K., Zhang, X., & Forrester, A. I. J. (2011).** *Multifidelity Surrogate Modeling of Experimental and Computational Aerodynamic Data Sets.* AIAA Journal, 49(2), 289–298. DOI: 10.2514/1.J050384
Combina datos experimentales y computacionales de distinta fidelidad en un único modelo sustituto aerodinámico. Relevante si el proyecto combina datos CFD con futuras mediciones experimentales del banco.

**10. Toal, D. J. J., & Keane, A. J. (2011).** *Efficient Multipoint Aerodynamic Design Optimization via Cokriging.* Journal of Aircraft, 48(5), 1685–1695. DOI: 10.2514/1.C031342
Usa cokriging (variante de kriging que combina múltiples fuentes de datos correlacionadas) para optimización aerodinámica multipunto, reduciendo el número de evaluaciones CFD de alta fidelidad requeridas.

**11. Keane, A. J. (2012).** *Cokriging for Robust Design Optimization.* AIAA Journal, 50(11), 2351–2364. DOI: 10.2514/1.J051391
Profundiza en la técnica de cokriging aplicada a optimización robusta, con base matemática útil para entender el método de interpolación antes de implementarlo en el software de procesamiento del banco.

**12. Xiao, M., Zhang, G., Breitkopf, P., Villon, P., & Zhang, W. (2018).** *Extended Co-Kriging Interpolation Method Based on Multi-Fidelity Data.* Applied Mathematics and Computation, 323, 120–131. DOI: 10.1016/j.amc.2017.10.055
Propone una extensión del método de co-kriging para combinar datos de múltiple fidelidad, con base matemática detallada. Complementa a Toal & Keane (2011) y Keane (2012) con una formulación más reciente.

**13. Shi, Q., Wang, H., Cheng, H., Cheng, F., & Wang, M. (2021).** *An Adaptive Sequential Sampling Strategy-Based Multi-Objective Optimization of Aerodynamic Configuration for a Tandem-Wing UAV via a Surrogate Model.* IEEE Access, 9, 164131–164147. DOI: 10.1109/ACCESS.2021.3132775
Aplica una estrategia de muestreo secuencial adaptativo para construir un modelo sustituto aerodinámico usado en optimización multiobjetivo de un UAV. Ejemplo aplicado y reciente de la metodología de muestreo inteligente para reducir el número de simulaciones necesarias.

**14. Toal, D. J. J. (2015).** *Some Considerations Regarding the Use of Multi-Fidelity Kriging in the Construction of Surrogate Models.* Structural and Multidisciplinary Optimization, 51, 1223–1245. DOI: 10.1007/s00158-014-1209-5
Discute consideraciones prácticas y trampas comunes al usar kriging multi-fidelidad para construir modelos sustitutos, útil como guía metodológica antes de implementar el método de interpolación del banco.

**15. Zhang, Y., Kim, N. H., Park, C., & Haftka, R. T. (2018).** *Multi-Fidelity Surrogate Based on Single Linear Regression.* AIAA Journal, 56(12), 4944–4952. DOI: 10.2514/1.J057339
Propone un modelo sustituto multi-fidelidad simplificado basado en regresión lineal simple entre fidelidades, como alternativa computacionalmente más económica a kriging/cokriging para combinar datos de distinta fidelidad.

### Notas del tema 4
- Este tema complementa directamente al RF-002 del proyecto ("El sistema deberá interpolar los valores de torque para condiciones intermedias") y al módulo de "Procesamiento (Python)" descrito en la arquitectura del sistema.
- Hay dos líneas metodológicas principales representadas: (a) kriging/cokriging y sus extensiones (Laurenceau & Sagaut, Mackman et al., Toal & Keane, Keane, Xiao et al., Toal, Zhang et al.), y (b) splines multivariados como alternativa (de Visser et al.). Conviene decidir cuál enfoque se adoptará antes de profundizar la lectura.
- Con esto se completan las 60 referencias planificadas entre los cuatro temas (15 CFD + 15 banco de ensayos + 15 actuadores + 15 interpolación, con 2 referencias compartidas entre CFD e interpolación).
