from vpython import *

# 1. Configurar la escena (Fondo blanco, estilo libro)
scene.background = color.white
scene.width = 800
scene.height = 600
scene.camera.pos = vector(10, 8, 15)
scene.camera.axis = vector(-10, -8, -15)

# 2. Definir parámetros geométricos
radio = 2.0
grosor = 0.5
separacion = 5.0

# 3. Crear los discos (con los tubos acoplados directamente a ellos)

# --- DISCO A (Motor) con tubo rotatorio naranja ---
cil_1 = cylinder(pos=vector(0, 0, 0), axis=vector(grosor, 0, 0), radius=radio, color=color.gray(0.9))
marca_1 = box(pos=vector(grosor/2, radio/2, 0), size=vector(0.1, radio, 0.1), color=color.black)
tubo_a = cylinder(pos=vector(grosor, 0, 0), axis=vector(1.5, 0, 0), radius=0.8, color=color.orange, opacity=0.4)
linea_a = box(pos=vector(grosor + 0.75, 0.8, 0), size=vector(1.5, 0.05, 0.05), color=color.black)
disco1 = compound([cil_1, marca_1, tubo_a, linea_a])

# --- DISCO C (Aleta) con IMU ---
cil_2 = cylinder(pos=vector(separacion, 0, 0), axis=vector(grosor, 0, 0), radius=radio, color=color.gray(0.9))
marca_2 = box(pos=vector(separacion + grosor/2, radio/2, 0), size=vector(0.1, radio, 0.1), color=color.black)
caja_imu = box(pos=vector(separacion + grosor + 0.1, 1.0, 0), size=vector(0.2, 0.8, 1.2), color=color.black)
texto_imu = text(text='IMU', pos=vector(separacion + grosor + 0.2, 0.85, 0), axis=vector(0,0,-1), align='center', color=color.white, height=0.3, depth=0.05)
disco2 = compound([cil_2, marca_2, caja_imu, texto_imu])

# --- DISCO B (Actuador) con tubo rotatorio naranja ---
pos_b = 2 * separacion
cil_3 = cylinder(pos=vector(pos_b, 0, 0), axis=vector(grosor, 0, 0), radius=radio, color=color.gray(0.9))
marca_3 = box(pos=vector(pos_b + grosor/2, radio/2, 0), size=vector(0.1, radio, 0.1), color=color.black)
tubo_b = cylinder(pos=vector(pos_b, 0, 0), axis=vector(-1.5, 0, 0), radius=0.8, color=color.orange, opacity=0.4)
linea_b = box(pos=vector(pos_b - 0.75, 0.8, 0), size=vector(1.5, 0.05, 0.05), color=color.black)
disco3 = compound([cil_3, marca_3, tubo_b, linea_b])

# Títulos superiores fijos
label(pos=vector(0, radio + 1.5, 0), text='A\nMotor de carga', box=False, color=color.black, height=14)
label(pos=vector(separacion, radio + 1.5, 0), text='C\nAleta', box=False, color=color.black, height=14)
label(pos=vector(pos_b, radio + 1.5, 0), text='B\nActuador bajo prueba', box=False, color=color.black, height=14)

# Cajas de Sensores de Corriente a los costados
caja_sensor_a = box(pos=vector(-3.5, -1.0, 0), size=vector(2.5, 1.2, 0.5), color=color.gray(0.8))
label(pos=vector(-4.8, 0.3, 0), text='Sensor de\ncorriente', box=False, color=color.black, height=12)
cable_a = curve(pos=[vector(0, 0, 0), vector(-1.5, -0.8, 0), vector(-3.5, -0.4, 0)], color=color.black, radius=0.04)

x_final = pos_b + grosor
caja_sensor_b = box(pos=vector(x_final + 3.5, -1.0, 0), size=vector(2.5, 1.2, 0.5), color=color.gray(0.8))
label(pos=vector(x_final + 3.5, 0.3, 0), text='Sensor de\ncorriente', box=False, color=color.black, height=12)
cable_b = curve(pos=[vector(x_final, 0, 0), vector(x_final + 1.5, -0.8, 0), vector(x_final + 3.5, -0.4, 0)], color=color.black, radius=0.04)

# Magnetómetros en dirección radial (Eje Z, apuntando a la cámara)
centro_tubo_a_x = grosor + 0.75
caja_mag_a = box(pos=vector(centro_tubo_a_x, 0, 1.2), size=vector(0.6, 0.6, 0.4), color=color.gray(0.3))
label(pos=vector(centro_tubo_a_x, -0.8, 1.2), text='Magnetómetro', box=False, color=color.black, height=12)

centro_tubo_b_x = pos_b - 0.75
caja_mag_b = box(pos=vector(centro_tubo_b_x, 0, 1.2), size=vector(0.6, 0.6, 0.4), color=color.gray(0.3))
label(pos=vector(centro_tubo_b_x, -0.8, 1.2), text='Magnetómetro', box=False, color=color.black, height=12)

# Centramos la cámara
scene.center = vector(separacion, 0, 0)

# 4. Crear los resortes torsionales
resorte1 = helix(pos=vector(grosor, 0, 0), axis=vector(separacion - grosor, 0, 0), radius=0.5, thickness=0.1, coils=6, color=color.black)
resorte2 = helix(pos=vector(separacion + grosor, 0, 0), axis=vector(separacion - grosor, 0, 0), radius=0.5, thickness=0.1, coils=6, color=color.black)

# --- Tubo ESTÁTICO recortado con cuadrado negro (Celeste) ---
largo_tubo_estatico = 1.0
inicio_tubo = 2.5 
tubo_estatico = cylinder(pos=vector(inicio_tubo, 0, 0), axis=vector(largo_tubo_estatico, 0, 0), radius=0.8, color=color.cyan, opacity=0.3)
centro_estatico_x = inicio_tubo + largo_tubo_estatico / 2

# Cuadrado negro y NUEVA etiqueta SG (Texto 2D legible)
cuadrado_negro = box(pos=vector(centro_estatico_x, 0.85, 0), size=vector(0.6, 0.1, 0.6), color=color.black)
label(pos=vector(centro_estatico_x, 1.5, 0), text='SG', box=False, color=color.black, height=14)
# -------------------------------------------------------------

# 5. Bucle de animación
t = 0
dt = 0.05
angulos_anteriores = [0, 0, 0]

while True:
    rate(30)
    
    # Simulación de las posiciones angulares
    theta1 = 0.5 * sin(2 * t)
    theta2 = 0.8 * sin(2 * t - 0.5)
    theta3 = 0.3 * sin(2 * t - 1.0)
    
    # Calcular el diferencial
    d_theta1 = theta1 - angulos_anteriores[0]
    d_theta2 = theta2 - angulos_anteriores[1]
    d_theta3 = theta3 - angulos_anteriores[2]
    
    # Rotar los discos sobre su centro exacto
    disco1.rotate(angle=d_theta1, axis=vector(1,0,0), origin=vector(0,0,0))
    disco2.rotate(angle=d_theta2, axis=vector(1,0,0), origin=vector(0,0,0))
    disco3.rotate(angle=d_theta3, axis=vector(1,0,0), origin=vector(0,0,0))
    
    angulos_anteriores = [theta1, theta2, theta3]
    t += dt