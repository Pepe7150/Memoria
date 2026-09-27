from vpython import *

# 1. Configurar la escena (Fondo blanco, estilo libro)
scene.background = color.white
scene.width = 800
scene.height = 600
scene.camera.pos = vector(10, 8, 15) # Ajustamos la cámara para la vista horizontal
scene.camera.axis = vector(-10, -8, -15)

# 2. Definir parámetros geométricos
radio = 2.0
grosor = 0.5
separacion = 5.0

# 3. Crear los 3 discos (Ahora alineados en el eje X)
def crear_disco(x_pos):
    # El eje del cilindro ahora apunta hacia X
    cilindro = cylinder(pos=vector(x_pos, 0, 0), axis=vector(grosor, 0, 0), radius=radio, color=color.gray(0.9))
    # La marca radial ahora apunta hacia arriba (eje Y) para que se vea la rotación
    marca = box(pos=vector(x_pos + grosor/2, radio/2, 0), size=vector(0.1, radio, 0.1), color=color.black)
    return compound([cilindro, marca])

disco1 = crear_disco(0)
disco2 = crear_disco(separacion)
disco3 = crear_disco(2 * separacion)

# Centramos la cámara en el disco de al medio
scene.center = vector(separacion, 0, 0)

# 4. Crear los resortes torsionales (Ahora a lo largo del eje X)
resorte1 = helix(pos=vector(grosor, 0, 0), axis=vector(separacion - grosor, 0, 0), radius=0.5, thickness=0.1, coils=6, color=color.black)
resorte2 = helix(pos=vector(separacion + grosor, 0, 0), axis=vector(separacion - grosor, 0, 0), radius=0.5, thickness=0.1, coils=6, color=color.black)

# 5. Bucle de animación de las vibraciones torsionales
t = 0
dt = 0.05
angulos_anteriores = [0, 0, 0]

while True:
    rate(30) # Mantener la animación a 30 FPS
    
    # Simulación de las posiciones angulares (Movimiento armónico)
    theta1 = 0.5 * sin(2 * t)
    theta2 = 0.8 * sin(2 * t - 0.5)
    theta3 = 0.3 * sin(2 * t - 1.0)
    
    # Calcular el cambio de ángulo en este fotograma específico
    d_theta1 = theta1 - angulos_anteriores[0]
    d_theta2 = theta2 - angulos_anteriores[1]
    d_theta3 = theta3 - angulos_anteriores[2]
    
    # Aplicar la rotación AHORA SOBRE EL EJE X: vector(1,0,0)
    disco1.rotate(angle=d_theta1, axis=vector(1,0,0), origin=disco1.pos)
    disco2.rotate(angle=d_theta2, axis=vector(1,0,0), origin=disco2.pos)
    disco3.rotate(angle=d_theta3, axis=vector(1,0,0), origin=disco3.pos)
    
    # Guardar los ángulos para calcular el siguiente movimiento
    angulos_anteriores = [theta1, theta2, theta3]
    
    t += dt