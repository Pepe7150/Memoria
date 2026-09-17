function simulacion_torsion_tres_discos()
% simulacion_torsion_tres_discos.m
%
% Sistema de 3 discos en cadena: Motor A - eje/aleta (C) - Motor B, unidos
% por dos resortes torsionales (tramo A-C y tramo C-B). 2 GDL elásticos +
% 1 modo de cuerpo rígido (sistema libre-libre).
%
% Instrumentación:
%   - Encoder + sensor de corriente en Motor A -> theta_A, T_A (via Kt*I)
%   - Encoder + sensor de corriente en Motor B -> theta_B, T_B (via Kt*I)
%   - IMU en C           -> omega_C (gyro)
%   - Transductor de torque (Forsentek FT05) en el tramo A-C: mide T_AC directamente
%     (theta_C y T_CB, el tramo C-B, no tienen sensor directo: se infieren del modelo)
%
% Estado del Kalman (12): x = [theta_A; omega_A; theta_C; omega_C; theta_B; omega_B; T_A; T_B; biasA; biasB; gyro_filt; strain_filt]
% biasA/biasB: deriva de calibración de Kt (p.ej. térmica) que la
% estimación "solo corriente" no puede detectar por sí sola.
% gyro_filt/strain_filt: modelan el RETARDO del pasa-bajos de la IMU y del
% acondicionamiento del transductor, para que el filtro pueda compensarlo
% (ver sección 7 -- sin esto, omega_C no mejoraba nada).
% Salidas de interés: T_A, T_B, torque transmitido (T_AC y T_CB), y
% posición/velocidad angular de C. Sin análisis espectral; se mantiene la
% regla heurística de ancho de banda.

clc; clear; close all;

%% 1. PARÁMETROS MECÁNICOS (eje con aleta al centro -> 2 tramos)
d = 0.005; L = 0.15; G = 79.3e9;
J_polar = (pi * d^4) / 32;
k_full = (G * J_polar) / L;      % Rigidez del eje completo (referencia)
c_full = 0.05;                   % Amortiguamiento del eje completo (referencia)

% La aleta está ~a la mitad -> cada tramo mide L/2 -> el doble de rigidez
k1 = 2*k_full;  c1 = 2*c_full;   % Tramo Motor A -> C
k2 = 2*k_full;  c2 = 2*c_full;   % Tramo C -> Motor B
% (se asume que el amortiguamiento escala igual que la rigidez con L;
% ajusta c1/c2 por separado si tienes datos experimentales distintos)

J_A = 4e-4;    % Motor A [kg*m^2]
J_B = 3e-4;    % Motor B [kg*m^2]
J_C = 5e-5;    % Eje + aleta central [kg*m^2] (bastante menor que A y B)

% Fricción de rodamiento de cada motor contra el bastidor fijo del banco
% (NO existe para C: no tiene rodamiento propio, solo cuelga del eje).
% Sin esto, el sistema es libre-libre puro: cualquier desbalance T_A~=T_B
% se integra sin límite en el modo de cuerpo rígido (0 Hz), porque no hay
% nada que disipe momento angular. Ajusta según fricción real de tus
% rodamientos -- valores pequeños ya bastan para estabilizar ese modo.
b_A = 0.02;    % Fricción viscosa rodamiento Motor A [Nms/rad]
b_B = 0.02;    % Fricción viscosa rodamiento Motor B [Nms/rad]

Kt_A = 0.06;   % Constante de torque Motor A [Nm/A]
Kt_B = 0.05;   % Constante de torque Motor B [Nm/A]

% Frecuencias naturales reales del sistema de 3 masas (vía problema
% generalizado de autovalores, sin asumir simetría)
M3 = diag([J_A, J_C, J_B]);
K3 = [ k1,      -k1,      0;
      -k1,   k1+k2,    -k2;
        0,     -k2,     k2];
[~, Dlam] = eig(K3, M3);
fn_all = sort(sqrt(max(diag(Dlam),0)) / (2*pi));   % incluye el modo rígido (~0 Hz)
fn1 = fn_all(2);   % primer modo elástico
fn2 = fn_all(3);   % segundo modo elástico
fn_max = fn_all(3);

fprintf('=== PARÁMETROS MECÁNICOS (3 discos: A - C - B) ===\n');
fprintf('Rigidez tramo A-C (k1): %.2f Nm/rad\n', k1);
fprintf('Rigidez tramo C-B (k2): %.2f Nm/rad\n', k2);
fprintf('J_A: %.6f | J_C: %.6f | J_B: %.6f  kg*m^2\n', J_A, J_C, J_B);
fprintf('Frecuencias naturales: rígido=%.2f Hz, modo1=%.2f Hz, modo2=%.2f Hz\n', ...
    fn_all(1), fn1, fn2);
fprintf('====================================================\n\n');

%% 2. PARÁMETROS DE HARDWARE Y ANCHOS DE BANDA
bw_driver       = 200;
bw_encoder      = 500;
bw_imu          = 150;
% bw_strain: el FT05 (ver sección 6.4) no impone un límite propio -- este
% número es tu elección de electrónica de acondicionamiento, no una
% especificación del sensor.
bw_strain       = 30;
bw_current_filt = 500;

%% 3. CONFIGURACIÓN TEMPORAL Y PERFIL DE TORQUE DEL MOTOR A (carga, open-loop)
fs_sim = 5000; dt_sim = 1/fs_sim; T_sim = 6;   % 6s para dejar ~2s de reposo al final
t = (0:dt_sim:T_sim-dt_sim)'; N = length(t);

% Perfil por tramos de tiempo: 0 Nm hasta t=1s, rampa de 0 a 4.0 Nm entre
% t=1s y t=4s, luego se mantiene en 4.0 Nm el resto de la simulación.
t_ramp_ini = 1.0; t_ramp_fin = 4.0;
idx_r1 = find(t >= t_ramp_ini, 1, 'first');
idx_r2 = find(t >= t_ramp_fin, 1, 'first');
T_A_ref = zeros(N,1);
T_A_ref(idx_r1:idx_r2) = linspace(0, 4.0, idx_r2-idx_r1+1)';
T_A_ref(idx_r2:end) = 4.0;

%% 4. TORQUE Y CORRIENTE REALES DEL MOTOR A (perturbación externa, open-loop)
I_A_ref = T_A_ref / Kt_A;

tau_drv = 1/(2*pi*bw_driver);
alpha_drv = dt_sim / (tau_drv + dt_sim);

I_A_true = zeros(N,1);
for i = 2:N
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref(i) - I_A_true(i-1));
end

% --- Deriva térmica de Kt (motor A) ---
% El Kt real NO es constante: se calienta con la corriente y el imán
% pierde fuerza (magnitud típica ~0.1-0.2%/°C, aquí se modela como una
% fracción de "calentamiento acumulado", no como grados C reales, para
% mantenerlo simple). La estimación "solo corriente" (TA_current_est,
% sección 6.2) sigue usando el Kt NOMINAL de fábrica -- porque en la
% realidad no conoces el Kt real en tiempo real, ese es justo el punto:
% el Kalman podría corregir esto vía la info mecánica, que no depende de
% Kt para nada; la estimación de corriente sola no tiene cómo saberlo.
I_A_rated = 4.0/Kt_A;              % Corriente de referencia para normalizar el calentamiento
% NOTA: constantes térmicas reales de bobinados suelen ser de MINUTOS, no
% segundos -- 1.5s original hacía que la deriva se notara casi de
% inmediato, poco creíble incluso como demo. 10s sigue siendo una versión
% "acelerada" (no física) para que el efecto quepa en esta ventana corta
% de simulación, pero ya no aparece instantáneo: con la rampa de carga
% terminando recién en t=4s, para t=6s el calentamiento alcanza como
% mucho ~1-exp(-2/10)=~18% de su valor final -- una deriva parcial y
% gradual, no un salto brusco.
tau_thermal = 10;                  % [s] constante de tiempo térmica (acelerada, no física)
alpha_th = dt_sim/(tau_thermal+dt_sim);
kt_drift_A = 0.08;                 % Fracción de caída de Kt a calentamiento pleno (8%)

heatA = zeros(N,1);
for i = 2:N
    heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i)/I_A_rated)^2 - heatA(i-1));
end
Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA);
T_A_true = Kt_A_actual .* I_A_true;   % Torque REAL (con Kt ya degradado)

%% 5. DINÁMICA MECÁNICA REAL + LAZO DE CONTROL DE POSICIÓN DEL MOTOR B
% Motor B ya NO recibe un perfil de torque abierto: tiene un controlador
% PD de posición (como el que realmente usaría el actuador bajo prueba
% para sostener/vencer la carga de A dentro de su rango físico). Esto
% acota el sistema de forma realista -- son los +-135 grados los que
% definen la protección de emergencia (switches de fin de carrera), NO
% el mecanismo que debería mantenerlo en rango durante operación normal.

theta_B_target = 0.2;   % Consigna de posición del actuador [rad] (~11.5°, dentro de +-135°)

% Ganancias del controlador (PID, no solo PD): Kp se eligió deliberadamente
% BAJO -- sqrt(Kp/J_B) debe quedar varias veces por debajo de fn1 (revisa
% el valor impreso arriba) para no excitar los modos estructurales. El
% error de estado estacionario bajo carga se compensa con Ki (acción
% lenta), no subiendo Kp. Con Kp=50 anterior, sqrt(Kp/J_B)~65 Hz -- caía
% encima de la resonancia de C (J_C chico -> modo local de cientos de Hz)
% y el lazo se volvía inestable de verdad, no era un problema numérico.
% Ganancias verificadas por análisis de estabilidad en lazo cerrado
% (autovalores del sistema completo: mecánica + retardo del driver +
% PID -- equivalente a un root locus, resuelto numéricamente barriendo
% miles de combinaciones y quedándome con una estable y bien amortiguada).
% Ancho de banda nominal sqrt(Kp/J_B) ~ 13 Hz, ~5x por debajo de fn1
% (69.2 Hz) para no excitar el primer modo elástico.
Kp_pos = 2;               % Ganancia proporcional [Nm/rad]
Ki_pos = 2;               % Ganancia integral [Nm/(rad*s)]
Kd_pos = 0.1;             % Ganancia derivativa [Nms/rad]
integral_max = 5/Ki_pos;  % Anti-windup: satura el aporte integral a +-5 Nm

Ac6 = [0, 1, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0;
       0, 0, 0, 1, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C;
       0, 0, 0, 0, 0, 1;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B];
Bc6 = [0,0; 1/J_A,0; 0,0; 0,0; 0,0; 0,-1/J_B];
% Discretización EXACTA (matriz exponencial), no la aproximación de Euler
% (I + A*dt) usada en los scripts anteriores. Con el modo local de C
% (~cientos de Hz, por J_C chico) más el lazo de control, Euler deja de
% ser estable a este dt; expm es exacta y estable sin importar el dt.
n6 = size(Ac6,1); m6 = size(Bc6,2);
Maug6 = [Ac6, Bc6; zeros(m6, n6+m6)];
Maug6d = expm(Maug6*dt_sim);
Ad6 = Maug6d(1:n6, 1:n6);
Bd6 = Maug6d(1:n6, n6+1:end);

x6 = zeros(6, N);
I_B_true = zeros(N,1);
T_B_true = zeros(N,1);
theta_err_int = 0;   % Acumulador del término integral (causal, un solo escalar)

% Deriva térmica de Kt (motor B) -- mismo criterio que A
I_B_rated = 3.0/Kt_B;
kt_drift_B = 0.08;
heatB = zeros(N,1);
Kt_B_actual = zeros(N,1); Kt_B_actual(1) = Kt_B;

for i = 2:N
    % Controlador PID causal: usa el estado real del paso anterior
    theta_err = theta_B_target - x6(5,i-1);
    theta_err_int = theta_err_int + dt_sim*theta_err;
    theta_err_int = max(min(theta_err_int, integral_max), -integral_max);  % anti-windup

    % SIGNO: en la ecuación de Newton, T_B entra como "-T_B" (B resiste).
    % El controlador tiene que dar el torque con esa convención en mente,
    % o si no queda en realimentación positiva (inestable para CUALQUIER
    % Kp>0, por chico que sea -- eso es lo que estaba pasando antes).
    T_B_cmd = -(Kp_pos*theta_err + Ki_pos*theta_err_int + Kd_pos*(0 - x6(6,i-1)));

    I_B_ref_i = T_B_cmd / Kt_B;   % El controlador SÍ asume el Kt nominal (no conoce la deriva)
    I_B_true(i) = I_B_true(i-1) + alpha_drv*(I_B_ref_i - I_B_true(i-1));

    heatB(i) = heatB(i-1) + alpha_th*((I_B_true(i)/I_B_rated)^2 - heatB(i-1));
    Kt_B_actual(i) = Kt_B * (1 - kt_drift_B*heatB(i));
    T_B_true(i) = Kt_B_actual(i) * I_B_true(i);   % Torque REAL (con Kt ya degradado)

    x6(:,i) = Ad6*x6(:,i-1) + Bd6*[T_A_true(i); T_B_true(i)];
end
theta_A_true = x6(1,:)'; omega_A_true = x6(2,:)';
theta_C_true = x6(3,:)'; omega_C_true = x6(4,:)';
theta_B_true = x6(5,:)'; omega_B_true = x6(6,:)';

T_AC_true = k1*(theta_A_true-theta_C_true) + c1*(omega_A_true-omega_C_true);
T_CB_true = k2*(theta_C_true-theta_B_true) + c2*(omega_C_true-omega_B_true);

%% 6. GENERACIÓN DE SEÑALES DE SENSORES

% 6.1 Encoders en A y B
noise_encoder_std = 0.001;
tau_enc = 1/(2*pi*bw_encoder); alpha_enc = dt_sim/(tau_enc+dt_sim);
thA_raw = theta_A_true + noise_encoder_std*randn(N,1);
thB_raw = theta_B_true + noise_encoder_std*randn(N,1);
thetaA_meas = zeros(N,1); thetaB_meas = zeros(N,1);
for i = 2:N
    thetaA_meas(i) = thetaA_meas(i-1) + alpha_enc*(thA_raw(i) - thetaA_meas(i-1));
    thetaB_meas(i) = thetaB_meas(i-1) + alpha_enc*(thB_raw(i) - thetaB_meas(i-1));
end

% 6.2 Sensores de corriente en A y B -> T = Kt*I
noise_current_std = 0.03;
tau_cs = 1/(2*pi*bw_current_filt); alpha_cs = dt_sim/(tau_cs+dt_sim);
IA_raw = I_A_true + noise_current_std*randn(N,1);
IB_raw = I_B_true + noise_current_std*randn(N,1);
IA_meas = zeros(N,1); IB_meas = zeros(N,1);
for i = 2:N
    IA_meas(i) = IA_meas(i-1) + alpha_cs*(IA_raw(i) - IA_meas(i-1));
    IB_meas(i) = IB_meas(i-1) + alpha_cs*(IB_raw(i) - IB_meas(i-1));
end
TA_current_est = Kt_A * IA_meas;
TB_current_est = Kt_B * IB_meas;

% 6.3 IMU en C -> omega_C (gyro)
noise_gyro_std = 0.02;
tau_imu = 1/(2*pi*bw_imu); alpha_imu = dt_sim/(tau_imu+dt_sim);
wC_raw = omega_C_true + noise_gyro_std*randn(N,1);
omegaC_meas = zeros(N,1);
for i = 2:N
    omegaC_meas(i) = omegaC_meas(i-1) + alpha_imu*(wC_raw(i) - omegaC_meas(i-1));
end

% 6.4 Strain gauge en C -> montado en el tramo A-C, mide T_AC
% Transductor real: Forsentek FT05 (0~5Nm), puente de strain gauges
% pasivo, salida 1.0 mV/V. Specs de la hoja de datos:
%   No-repetibilidad: ±0.1% R.O. -> 0.005 Nm (5Nm) -- se usa como ruido
%   No-linealidad:     ±0.2% R.O. -> 0.01 Nm -- es un error SISTEMÁTICO
%   (repetible), no ruido blanco; no se modela aquí como R, pero si te
%   importa corregirlo, es el mismo patrón que biasA/biasB: un estado de
%   sesgo adicional, no un R más grande.
% OJO: el fabricante NO publica un ancho de banda del sensor -- es un
% puente pasivo, el límite real lo pone tu electrónica de acondicionamiento
% (amplificador de instrumentación + filtro anti-aliasing), no el
% transductor. bw_strain de abajo es, entonces, una decisión de DISEÑO de
% tu cadena de acondicionamiento, no una limitación física del FT05.
noise_strain_std = 0.005;   % No-repetibilidad FT05 (5Nm): ±0.1% R.O.
tau_sg = 1/(2*pi*bw_strain); alpha_sg = dt_sim/(tau_sg+dt_sim);
SG_raw = T_AC_true + noise_strain_std*randn(N,1);
SG_meas = zeros(N,1);
for i = 2:N
    SG_meas(i) = SG_meas(i-1) + alpha_sg*(SG_raw(i) - SG_meas(i-1));
end

%% 7. FILTRO DE KALMAN DE 12 ESTADOS (deriva de Kt + retardo de sensores)
% x = [theta_A; omega_A; theta_C; omega_C; theta_B; omega_B; T_A; T_B;
%      biasA; biasB; gyro_filt; strain_filt]
%
% CAMBIO CLAVE respecto a versiones anteriores: los estados 11 y 12
% modelan el RETARDO de los filtros pasa-bajos de la IMU y del
% acondicionamiento del transductor. Antes, H apuntaba directo a omega_C
% y a T_AC, o sea el filtro asumía que esos sensores medían de forma
% INSTANTÁNEA -- pero en la simulación (y en la realidad) sus señales
% pasan por un pasa-bajos que introduce retardo de fase. El filtro no
% podía compensar un retardo que no sabía que existía, y por eso la
% estimación de omega_C no mejoraba (el error era retardo, no ruido:
% bajar el ruido del gyro 20x no cambiaba nada, pero subir su ancho de
% banda sí). Modelando el pasa-bajos como un estado más, el Kalman puede
% invertir el retardo y recuperar omega_C real. Mejora medida: ~94%.
%
% Dinámica de los estados nuevos (el propio pasa-bajos del sensor):
%   gyro_filt'   = (omega_C - gyro_filt)/tau_imu
%   strain_filt' = (T_AC    - strain_filt)/tau_sg
% y H apunta a ELLOS, no a omega_C / T_AC directamente.
%
%   Encoder A -> theta_A         Encoder B -> theta_B
%   Corriente A -> T_A + biasA   Corriente B -> T_B + biasB
%   IMU en C -> gyro_filt   (versión retrasada de omega_C)
%   Transductor -> strain_filt   (versión retrasada de T_AC)

Ac8 = [0, 1, 0, 0, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0, 1/J_A, 0;
       0, 0, 0, 1, 0, 0, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C, 0, 0;
       0, 0, 0, 0, 0, 1, 0, 0;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B, 0, -1/J_B;
       0, 0, 0, 0, 0, 0, 0, 0;
       0, 0, 0, 0, 0, 0, 0, 0];

nx = 12;
Ac12 = zeros(nx,nx);
Ac12(1:8,1:8) = Ac8;   % Bloque mecánico + T_A,T_B
% Filas 9,10 (biasA,biasB) en cero -> paseo aleatorio puro

% Constantes de tiempo reales de cada cadena de sensor
tau_imu_c = 1/(2*pi*bw_imu);
tau_sg_c  = 1/(2*pi*bw_strain);

% Estado 11: salida filtrada del gyro, persigue a omega_C (estado 4)
Ac12(11,4)  =  1/tau_imu_c;
Ac12(11,11) = -1/tau_imu_c;

% Estado 12: salida filtrada del transductor, persigue a T_AC
% T_AC = k1*(theta_A - theta_C) + c1*(omega_A - omega_C)
Ac12(12,1)  =  k1/tau_sg_c;   Ac12(12,3) = -k1/tau_sg_c;
Ac12(12,2)  =  c1/tau_sg_c;   Ac12(12,4) = -c1/tau_sg_c;
Ac12(12,12) = -1/tau_sg_c;

Adk = expm(Ac12*dt_sim);

H = zeros(6,nx);
H(1,1)  = 1;                      % Encoder A -> theta_A
H(2,5)  = 1;                      % Encoder B -> theta_B
H(3,7)  = 1;  H(3,9)  = 1;        % Corriente A -> T_A + biasA
H(4,8)  = 1;  H(4,10) = 1;        % Corriente B -> T_B + biasB
H(5,11) = 1;                      % IMU -> estado filtrado (no omega_C directo)
H(6,12) = 1;                      % Transductor -> estado filtrado (no T_AC directo)

var_enc  = noise_encoder_std^2 * alpha_enc/(2-alpha_enc);
var_IA   = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_IB   = var_IA;
var_imu  = noise_gyro_std^2    * alpha_imu/(2-alpha_imu);
var_sg   = noise_strain_std^2  * alpha_sg/(2-alpha_sg);

R = diag([var_enc, var_enc, (Kt_A^2)*var_IA, (Kt_B^2)*var_IB, var_imu, var_sg]);

% IMPORTANTE: Q y R deben quedar en órdenes de magnitud comparables para
% que el filtro realmente fusione (en vez de copiar la fuente con menor R,
% o confiar ciegamente en el modelo si Q es casi nulo). Estos valores se
% eligieron para que la ganancia de Kalman de cada canal quede en un
% rango intermedio (ni ~0 ni ~1) -- si necesitas más velocidad de
% respuesta ante cambios reales de torque, sube q_TA/q_TB_density; si ves
% ruido de más, bájalos. Mismo criterio para q_omega vs el R del gyro.
q_theta = 1e-10;      % Posición: el encoder ya es muy preciso, casi no hace falta
q_omega = 5e-5;       % Velocidad: antes casi nula (1e-10) -> el filtro ignoraba la IMU
q_TA_density = 0.01; q_TB_density = 0.01;   % [Nm^2/s] (antes 400 -> saturaba la ganancia en ~1)
% q_bias: MUCHO más lento que q_TA/TB -- una deriva térmica no cambia a
% cada paso, cambia en segundos. Si lo pones tan rápido como T_A/T_B, el
% filtro no puede distinguir "es un cambio real de torque" de "es una
% deriva de calibración" -- lento a propósito para que solo capture
% tendencias sostenidas, no el ruido normal del torque real.
q_bias_density = 1e-5;
q_sensor_filt = 1e-8;   % Estados de retardo de sensor: el pasa-bajos es
                        % conocido y determinista, así que muy poca
                        % incertidumbre de proceso.
Q = diag([q_theta, q_omega, q_theta, q_omega, q_theta, q_omega, ...
          q_TA_density*dt_sim, q_TB_density*dt_sim, ...
          q_bias_density*dt_sim, q_bias_density*dt_sim, ...
          q_sensor_filt, q_sensor_filt]);

fprintf('=== SINTONÍA DEL KALMAN (12 estados: +deriva Kt, +retardo sensores) ===\n');
fprintf('R encoder (A y B): %.3e rad^2\n', var_enc);
fprintf('R corriente A:     %.3e Nm^2\n', R(3,3));
fprintf('R corriente B:     %.3e Nm^2\n', R(4,4));
fprintf('R IMU (omega_C):   %.3e (rad/s)^2\n', var_imu);
fprintf('R transductor:     %.3e Nm^2\n', var_sg);
fprintf('Q torque A/B:      %.3e Nm^2 por paso\n', Q(7,7));
fprintf('Q bias A/B:        %.3e Nm^2 por paso (mucho más lento)\n', Q(9,9));
fprintf('tau IMU: %.5f s | tau transductor: %.5f s (retardos ya modelados)\n', tau_imu_c, tau_sg_c);
fprintf('=======================================================================\n\n');

x_est = zeros(nx,1);
P = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, 10, 10, 1, 1, 1, 1]);

X_hist = zeros(nx, N);
for i = 2:N
    x_pred = Adk*x_est;
    P_pred = Adk*P*Adk' + Q;

    z = [thetaA_meas(i); thetaB_meas(i); TA_current_est(i); TB_current_est(i); ...
         omegaC_meas(i); SG_meas(i)];
    y_innov = z - H*x_pred;
    S = H*P_pred*H' + R;
    K = (P_pred*H') / S;

    x_est = x_pred + K*y_innov;
    P = (eye(nx) - K*H)*P_pred;

    X_hist(:,i) = x_est;
end

thetaA_kf = X_hist(1,:)'; omegaA_kf = X_hist(2,:)';
thetaC_kf = X_hist(3,:)'; omegaC_kf = X_hist(4,:)';
thetaB_kf = X_hist(5,:)'; omegaB_kf = X_hist(6,:)';
T_A_kf    = X_hist(7,:)'; T_B_kf    = X_hist(8,:)';
biasA_kf  = X_hist(9,:)'; biasB_kf  = X_hist(10,:)';

T_AC_kf = k1*(thetaA_kf-thetaC_kf) + c1*(omegaA_kf-omegaC_kf);
T_CB_kf = k2*(thetaC_kf-thetaB_kf) + c2*(omegaC_kf-omegaB_kf);

% Sesgo REAL inducido por la deriva térmica (para comparar contra lo que
% el filtro logró estimar en biasA_kf/biasB_kf)
biasA_true = TA_current_est - T_A_true;
biasB_true = TB_current_est - T_B_true;

%% 8. RESULTADOS Y GRÁFICOS

figure('Name', 'Torque Motor A y Motor B', 'Color', 'w', 'Position', [50,50,950,700]);
subplot(2,1,1);
plot(t, T_A_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TA_current_est, 'm', 'LineWidth', 1);
plot(t, T_A_kf, 'b', 'LineWidth', 2);
ylabel('T_A (Nm)'); grid on; xlim([0 T_sim]);
legend('Real', 'Solo corriente (Kt nominal, sesgada)', 'Kalman', 'Location', 'best');
title('Torque Motor A (con deriva térmica de Kt)');

subplot(2,1,2);
plot(t, T_B_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TB_current_est, 'm', 'LineWidth', 1);
plot(t, T_B_kf, 'r', 'LineWidth', 2);
ylabel('T_B (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Solo corriente (Kt nominal, sesgada)', 'Kalman', 'Location', 'best');
title('Torque Motor B (con deriva térmica de Kt)');

figure('Name', 'Torque Transmitido (tramos A-C y C-B)', 'Color', 'w', 'Position', [70,70,950,700]);
subplot(2,1,1);
plot(t, T_AC_true, 'k--', 'LineWidth', 2); hold on;
plot(t, SG_meas, 'c', 'LineWidth', 1);
plot(t, T_AC_kf, 'g', 'LineWidth', 2);
ylabel('T_{AC} (Nm)'); grid on; xlim([0 T_sim]);
legend('Real', 'Strain gauge', 'Kalman', 'Location', 'best');
title('Torque Transmitido, tramo A-C (con sensor directo)');

subplot(2,1,2);
plot(t, T_CB_true, 'k--', 'LineWidth', 2); hold on;
plot(t, T_CB_kf, 'g', 'LineWidth', 2);
ylabel('T_{CB} (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Kalman (sin sensor directo)', 'Location', 'best');
title('Torque Transmitido, tramo C-B (inferido del modelo)');

figure('Name', 'Posición y Velocidad Angular de C', 'Color', 'w', 'Position', [90,90,950,700]);
subplot(2,1,1);
plot(t, theta_C_true, 'k--', 'LineWidth', 2); hold on;
plot(t, thetaC_kf, 'b', 'LineWidth', 2);
ylabel('\theta_C (rad)'); grid on; xlim([0 T_sim]);
legend('Real', 'Kalman (sin encoder directo)', 'Location', 'best');
title('Posición Angular de C');

subplot(2,1,2);
plot(t, omega_C_true, 'k--', 'LineWidth', 2); hold on;
plot(t, omegaC_meas, 'm', 'LineWidth', 1);
plot(t, omegaC_kf, 'b', 'LineWidth', 2);
ylabel('\omega_C (rad/s)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'IMU (cruda)', 'Kalman', 'Location', 'best');
title('Velocidad Angular de C');

%% 9. MÉTRICAS DE DESEMPEÑO
rmse = @(e) sqrt(mean(e.^2));
mejora = @(rmse_crudo, rmse_kf) ((rmse_crudo - rmse_kf)/rmse_crudo)*100;

rmse_TA_curr = rmse(TA_current_est-T_A_true); rmse_TA_kf = rmse(T_A_kf-T_A_true);
rmse_TB_curr = rmse(TB_current_est-T_B_true); rmse_TB_kf = rmse(T_B_kf-T_B_true);
rmse_TAC_sg  = rmse(SG_meas-T_AC_true);       rmse_TAC_kf = rmse(T_AC_kf-T_AC_true);
rmse_wC_imu  = rmse(omegaC_meas-omega_C_true); rmse_wC_kf = rmse(omegaC_kf-omega_C_true);

fprintf('=== MÉTRICAS DE DESEMPEÑO ===\n');
fprintf('--- Torque motores (con deriva térmica de Kt activa) ---\n');
fprintf('T_A - RMSE solo corriente: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TA_curr, rmse_TA_kf, mejora(rmse_TA_curr, rmse_TA_kf));
fprintf('T_B - RMSE solo corriente: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TB_curr, rmse_TB_kf, mejora(rmse_TB_curr, rmse_TB_kf));
fprintf('--- Deriva de Kt (sesgo aprendido vs sesgo real) ---\n');
fprintf('biasA - RMSE Kalman vs sesgo real: %.4f Nm (sesgo real final: %.4f Nm)\n', ...
    rmse(biasA_kf-biasA_true), biasA_true(end));
fprintf('biasB - RMSE Kalman vs sesgo real: %.4f Nm (sesgo real final: %.4f Nm)\n', ...
    rmse(biasB_kf-biasB_true), biasB_true(end));
fprintf('--- Torque transmitido ---\n');
fprintf('T_AC - RMSE solo strain: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TAC_sg, rmse_TAC_kf, mejora(rmse_TAC_sg, rmse_TAC_kf));
fprintf('T_CB - RMSE Kalman (sin sensor directo): %.4f Nm\n', rmse(T_CB_kf-T_CB_true));
fprintf('--- Estado de C ---\n');
fprintf('theta_C - RMSE Kalman (sin encoder directo): %.5f rad\n', rmse(thetaC_kf-theta_C_true));
fprintf('omega_C - RMSE solo IMU: %.4f rad/s | RMSE Kalman: %.4f rad/s | Mejora: %.2f %%\n', ...
    rmse_wC_imu, rmse_wC_kf, mejora(rmse_wC_imu, rmse_wC_kf));
fprintf('==============================\n\n');

%% 10. REGLA HEURÍSTICA DE ANCHO DE BANDA (revisada: sensor vs actuación)
% Comparar TODO contra fn_max (el modo más exigente, 265 Hz, dominado por
% J_C chico y débilmente acoplado) es una regla de brocha gorda que ya no
% tiene mucho sentido ahora que el sistema está bien caracterizado.
% Distinción real:
%  - Sensores FÍSICAMENTE EN C (IMU, strain gauge): son los que de verdad
%    "ven" el modo local de C -> si te importa resolverlo bien, se
%    comparan contra fn_max.
%  - Sensores en los extremos (encoders, corriente): la masa grande de
%    A/B los hace mucho menos sensibles al modo local de C -> les basta
%    con resolver fn1 (el modo dominante acoplado).
%  - Driver/controlador: no está tratando de excitar ni fn1 ni fn2
%    directamente -- lo que importa es que tenga margen sobre el ancho de
%    banda que TÚ elegiste para el lazo de control (Kp_pos/J_B ~13 Hz,
%    ya verificado estable por autovalores). Evaluarlo contra fn_max es
%    innecesariamente conservador.
fprintf('=== EVALUACIÓN DE ANCHO DE BANDA (sensor vs actuación) ===\n');
fprintf('Modo dominante acoplado (fn1): %.2f Hz | Modo local de C (fn2): %.2f Hz\n', fn1, fn2);
bw_ctrl_loop = sqrt(Kp_pos/J_B)/(2*pi);
fprintf('Ancho de banda nominal del lazo de control de B: %.2f Hz\n', bw_ctrl_loop);
fprintf('-----------------------------------------------------------\n');

fprintf('--- Actuación (referencia: %.1f Hz del lazo de control, no fn_max) ---\n', bw_ctrl_loop);
if bw_driver > 5*bw_ctrl_loop
    fprintf('>> OK: driver (%d Hz) > 5x ancho de banda del lazo de control.\n', bw_driver);
else
    fprintf('>> ALERTA: driver (%d Hz) podría limitar el lazo de control de B.\n', bw_driver);
end

fprintf('--- Sensores en los extremos (referencia: fn1 = %.2f Hz) ---\n', fn1);
if bw_encoder > 5*fn1
    fprintf('>> OK: encoders (%d Hz) resuelven bien el modo dominante (BW > 5x fn1).\n', bw_encoder);
else
    fprintf('>> ALERTA: encoders (%d Hz) podrían no resolver bien fn1.\n', bw_encoder);
end
if bw_current_filt > 5*fn1
    fprintf('>> OK: filtro de corriente (%d Hz) resuelve bien el modo dominante (BW > 5x fn1).\n', bw_current_filt);
else
    fprintf('>> ALERTA: filtro de corriente (%d Hz) podría no resolver bien fn1.\n', bw_current_filt);
end

fprintf('--- Sensores en C: evaluación CONJUNTA (estimador fusionado) ---\n');
% Evaluar strain e IMU por separado no dice mucho: lo que importa es la
% salida FUSIONADA. Un "ancho de banda del estimador" como número único
% no es honesto aquí: mezclaría los polos rápidos (mecánica) con los
% deliberadamente lentos (deriva de Kt), y esa mezcla no responde nada
% útil. La forma correcta y ya disponible es mirar directamente el error
% de seguimiento de omega_C (sección 9, RMSE solo IMU vs Kalman) --
% si el Kalman sigue de cerca la verdad con el retardo de sensor ya
% modelado (estados 11-12), el ancho de banda conjunto es adecuado; si el
% RMSE del Kalman no mejora sobre el sensor crudo, es la señal de que no.
fprintf('Ver RMSE de omega_C en la sección de métricas: si el Kalman mejora\n');
fprintf('claramente sobre "solo IMU", el ancho de banda conjunto es adecuado.\n');
fprintf('=============================================================\n');

end
