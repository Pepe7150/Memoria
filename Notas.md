# Notas

* [X] Documentar y mejorar la documentación existente del caso
* [X] Correr con simpson perfi GAW algo así
* [X] Validar con datos numéricos disponibles.
* [X] Ver opciones de imponer torque
* [X] Ver pros y contras
* [X] Posiblemente una matriz de decisión
* [X] Terminar de agregar las opciones
* [X] Hacer monos de las opciones
* [X] Para medición de torque se requieren strain gauges, estimación por corriente, medición de torque de reacción (celda de carga y brazo en el estator sobre rodamientos), encoder para sacar la aceleración angular. Combinar todas las estimaciones con un filtro de kalman. Agregar todo a documentación.
* [X] Para la estimación del ángulo y la velocidad angular usar una combinación de IMU+encoder+modelo eléctrico back emf en un filtro de Kalman. Documentar esto
* [X] Calcular el torque de bisagra en Nm del NACA 0012 para ver su orden de magnitud.
* [X] Terminar de revisar los OE y ajustarlos.
* [X] Faltaría lo que dijeron de tener una maqueta del sistema, tengo que ver como cresta voy a hacer eso.
* [X] Ver lo que falta para la entrega del avance 1. Subir contexto y empezar a crear el documento consolidado.
* [X] Incorporar switches de fin de carrera para que el motor de carga no vaya a explotar si nada lo frena.
* [X] Hacer el ASD del eje y el filtro de kalman para torque.
* [X] revisar el ancho de banda de los componentes y el necesario.
* [X] Terminar de ajustar los OEs.
* [X] Hacer el informe con formato
* [X] Revisar que hay archivos de documentación que están duplicados en texto
* [X] Partir con las simulaciones en CFD cuanto antes.
* [X] Terminar de ver lo de los anchos de banda
* [X] En el motor de carga definir los límites de torque para que el sistema no se mantenga girando ante la ausencia de un torque resistente
* [X] Evaluar si el lazo de todo el sistema responde mejor al torque o a la posición
* [ ] Terminar de ver el sistema simulado en matlab

  * [X] Terminar de seccionar el código
  * [X] Revisar el lazo de control de posición de B, por qué empieza a controlar la posición cuando termina la rampa
  * [X] El kalman no tiene acción de control, o no explicita facil de encontrar
  * [X] integrar fail safes al sistema (switches, theta max y omega peligroso) a una frecuencia suficientemente alta para proteger al sistema en caso de falla catastrófica.
  * [X] Ver si se puede estimar todas las mediciones solo con IMUs (parece que no), parece que si pero hay que ver bien. Se supone que no, pero funciona  cuando el control es lento.
  * [X] Sacar los encoders por sensorles de efecto hall
  * [ ] Ver el asunto de la observabilidad
  * [ ] Cambiar el transductor chino por los strain gauges de nuevo
  * [ ] Incorporar sesgo a todos los sensores
  * [ ] Volver a seccionar el codigo largo
* [ ] Para lo de la altitud, definir en que rango tendría sentido el NACA 0012 de el objeto de estudio.  que sea coherente con el contexto del laboratorio y los uavs que se usan ahí. Preguntar a Tinnapp o decidir uno solamente
* [ ] Ver que dicen los chinos del transductor de torque e incorporarlo

  * [ ] Ya no será con el transductor chino, muy caro. Se hará uno casero, un tubo con mayor diámetro (donde si quepan los strain gauges) con rebajes donde se deban pegar y este irá acolpado al eje.
* [ ] en el modelo dinámico a lo mejor tirar la mitad de la inercia del eje mismo por lado (A y C o B y C), aunque vicuña dijo que la inercia del eje suele ser casi insignificante
* [ ] Agregar revisión a la hora de integrar que los cables no interfieran con el movimiento o que cambien la inercia al ser un sistema muy pequeño.
* [X] Crear/actualizar la documentación una vez cerrados los temas que se mantienen abiertos
* [ ] Quiero tener un esquema ordenado como el de annastopoulos et al. Para eso falta tener el sistema completamente definido y cerrado
* [ ] Evaluar valores realistas de fail safe
* [ ] Seguir con el CFD del caso con deflexion
