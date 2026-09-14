function simulacion_torsion_fusion()
% simulacion_torsion_fusion.m
%
% Simulación combinada del banco de ensayo de actuadores de superficie de
% control: dinámica torsional realista del eje + motor con ancho de banda
% limitado, fusión de sensores (Strain Gauge + IMU) mediante un Filtro de
% Kalman recursivo (predicción + corrección con AMBAS mediciones cada
% paso), y evaluación final mediante la regla heurística de ancho de
% banda (bw_motor > 5*fn, bw_strain vs fn, etc). No incluye análisis
% espectral/FFT.

clc; clear; close all;

%% 1. PARÁMETROS DEL SISTEMA MECÁNICO (Eje Acero A36)
d = 0.005;                     % Diámetro del eje [m]
L = 0.15;                      % Longitud del eje [m]
G = 79.3e9;                    % Módulo de corte Acero A36 [Pa]
J_polar = (pi * d^4) / 32;     % Momento polar de inercia de la sección [m^4]

k_torsion = (G * J_polar) / L; % Rigidez torsional del eje [Nm/rad]
c_amort   = 0.05;              % Amortiguamiento viscoso estimado [Nms/rad]
J_inercia = 5e-4;              % Inercia rotacional equivalente (motor+eje+superficie) [kg*m^2]

wn = sqrt(k_torsion / J_inercia);  % Frecuencia natural no amortiguada [rad/s]
fn = wn / (2*pi);                  % Frecuencia natural [Hz]
zeta = c_amort / (2*sqrt(k_torsion*J_inercia)); % Razón de amortiguamiento

fprintf('=== PARÁMETROS DEL SISTEMA MECÁNICO ===\n');
fprintf('Rigidez Torsional (k):   %.2f Nm/rad\n', k_torsion);
fprintf('Inercia Total (J):       %.6f kg*m^2\n', J_inercia);
fprintf('Frecuencia Natural (fn): %.2f Hz\n', fn);
fprintf('Razón de Amortig. (z):   %.4f\n', zeta);
fprintf('========================================\n\n');

%% 2. PARÁMETROS DE HARDWARE Y ANCHOS DE BANDA
bw_motor  = 300;    % Ancho de banda del motor [Hz]
bw_driver = 200;    % Ancho de banda del driver de corriente [Hz]
bw_strain = 30;     % Strain gauge + INA (limitado por filtro anti-aliasing/ruido) [Hz]
bw_imu    = 150;    % IMU / MEMS (rápida, ruidosa) [Hz]
bw_esp32  = 1000;   % Frecuencia del lazo de control en ESP32 [Hz]

%% 3. CONFIGURACIÓN TEMPORAL Y PERFIL DE TORQUE DE REFERENCIA
fs_sim = 5000;              % Frecuencia de muestreo de la simulación [Hz] (>> anchos de banda)
dt_sim = 1/fs_sim;
T_sim = 5;                  % Duración de la simulación [s]
t = (0:dt_sim:T_sim-dt_sim)';
N = length(t);

% Perfil realista de carga aerodinámica a emular: escalón (0.2 -> 5 Nm)
% más una componente senoidal de prueba para excitar la dinámica del eje.
T_ref_min = 0.2;
T_ref_max = 5.0;
f_test = 0.75 * fn;         % Frecuencia de prueba cercana (no encima) de fn

T_ref = ones(N,1) * T_ref_min;
%T_ref = T_ref_min;

idx_step = floor(N*0.2);
T_ref(idx_step:end) = T_ref_max;

T_ref = T_ref + 0.5;
%T_ref = T_ref + 0.5 * sin(2*pi*f_test*t);

fprintf('Frecuencia de excitación de prueba: %.2f Hz (0.75*fn)\n\n', f_test);

%% 4. SIMULACIÓN DE LA DINÁMICA MECÁNICA (Espacio de Estados)
% J*theta'' + c*theta' + k*theta = T_motor
% x = [theta; theta_dot]
A = [0 1; -k_torsion/J_inercia -c_amort/J_inercia];
B = [0; 1/J_inercia];
Ad = eye(2) + A*dt_sim;     % Discretización de Euler
Bd = B*dt_sim;

x = zeros(2, N);
T_motor_applied = zeros(N,1);
tau_motor = 1/(2*pi*bw_motor);
alpha_m = dt_sim / (tau_motor + dt_sim);

for i = 2:N
    % El motor sigue la referencia de torque con un retardo de 1er orden
    % limitado por su ancho de banda.
    T_motor_applied(i) = T_motor_applied(i-1) + alpha_m * (T_ref(i) - T_motor_applied(i-1));
    u = T_motor_applied(i);
    x(:,i) = Ad*x(:,i-1) + Bd*u;
end

theta = x(1,:)';                       % Posición angular [rad]
omega = x(2,:)';                       % Velocidad angular [rad/s]
alpha_ang = gradient(omega, dt_sim);   % Aceleración angular [rad/s^2]

% Torque "real" en el eje: el que efectivamente actúa sobre la superficie
T_real = k_torsion*theta + c_amort*omega;

%% 5. GENERACIÓN DE SEÑALES DE SENSORES

% Ruido "crudo" de cada sensor (antes de cualquier filtrado). Estos son
% los parámetros que deberían salir de datasheet/calibración real.
noise_strain_std = 0.05;   % Ruido crudo del Strain Gauge, ya en Nm
noise_imu_std    = 5.0;    % Ruido crudo de la IMU, en rad/s^2 (aceleración)

% 5.1 Strain Gauge -> mide deformación, se traduce a Torque = k*theta
noise_strain = noise_strain_std * randn(N,1);
SG_raw = k_torsion*theta + noise_strain;

tau_sg = 1/(2*pi*bw_strain);
alpha_sg = dt_sim / (tau_sg + dt_sim);
SG_meas = zeros(N,1);
for i = 2:N
    SG_meas(i) = SG_meas(i-1) + alpha_sg * (SG_raw(i) - SG_meas(i-1));
end

% 5.2 IMU -> mide aceleración angular, se traduce a Torque = J*alpha
noise_imu = noise_imu_std * randn(N,1);
IMU_acc_raw = alpha_ang + noise_imu;

tau_imu = 1/(2*pi*bw_imu);
alpha_imu = dt_sim / (tau_imu + dt_sim);
IMU_acc_filt = zeros(N,1);
for i = 2:N
    IMU_acc_filt(i) = IMU_acc_filt(i-1) + alpha_imu * (IMU_acc_raw(i) - IMU_acc_filt(i-1));
end
% OJO: esto NO es el torque aplicado, solo la componente inercial
% (J*alpha). En régimen permanente alpha->0 aunque el torque real sea
% grande (lo sostiene el resorte, no la inercia). Se deja calculado solo
% para graficar y evidenciar el punto.
IMU_meas_solo_inercial = J_inercia * IMU_acc_filt;

%% 6. FILTRO DE KALMAN DE 3 ESTADOS (modelo físico, no dos "torques" sueltos)
% El error anterior era tratar SG e IMU como dos mediciones independientes
% del mismo escalar "Torque". Eso es físicamente falso: en un eje con
% resorte (k) y amortiguamiento (c), la ecuación de Newton es
%   J*theta'' + c*theta' + k*theta = T_aplicado
% El strain gauge mide la parte elástica (k*theta) y la IMU mide la parte
% inercial (J*alpha). Ninguna de las dos, por sí sola, es "el torque".
%
% Por eso el estado ahora es x = [theta; omega; T_aplicado], con el
% modelo mecánico como ecuación de proceso (para theta y omega, exacta;
% para T_aplicado, paseo aleatorio porque no sabemos cómo cambiará) y
% cada sensor mide la parte de la ecuación que físicamente le corresponde:
%   z_SG  = k*theta                              (elástico)
%   z_IMU = alpha = (T_aplicado - c*omega - k*theta)/J   (inercial)
% Así, cuando el sistema está en régimen permanente (omega=alpha=0), el
% filtro deduce T_aplicado = k*theta directamente de la ecuación -no
% colapsa a cero-, y durante el transitorio usa la dinámica real del eje
% (incluido su propio "ringing") en vez de confundirlo con ruido de torque.

Ac = [0, 1, 0;
      -k_torsion/J_inercia, -c_amort/J_inercia, 1/J_inercia;
      0, 0, 0];
Adk = eye(3) + Ac*dt_sim;                 % Discretización de Euler (consistente con el resto)

H_sg  = [k_torsion, 0, 0];                                          % SG mide k*theta
H_imu = [-k_torsion/J_inercia, -c_amort/J_inercia, 1/J_inercia];    % IMU mide alpha
H = [H_sg; H_imu];

var_strain_filt  = noise_strain_std^2 * alpha_sg/(2-alpha_sg);   % [Nm^2],       ya filtrado
var_imu_acc_filt = noise_imu_std^2 * alpha_imu/(2-alpha_imu);    % [(rad/s^2)^2], ya filtrado
R = diag([var_strain_filt, var_imu_acc_filt]);

% Ruido de proceso: casi nulo en theta/omega (el modelo mecánico es
% prácticamente exacto), y una densidad ajustable en T_aplicado (cuánto
% puede cambiar el torque real entre pasos, que es lo que no conocemos).
q_theta = 1e-12; q_omega = 1e-8;
q_torque_density = 400;             % [Nm^2/s], ajustable según qué tan rápido cambia la carga real
Q = diag([q_theta, q_omega, q_torque_density*dt_sim]);

fprintf('=== SINTONÍA DEL KALMAN (3 estados: theta, omega, T_aplicado) ===\n');
fprintf('R_strain (k*theta): %.3e Nm^2   (sigma = %.4f Nm)\n', R(1,1), sqrt(R(1,1)));
fprintf('R_imu (alpha):      %.3e (rad/s^2)^2\n', R(2,2));
fprintf('Q_torque:            %.3e Nm^2 por paso\n', Q(3,3));
fprintf('===================================================================\n\n');

x_est = [0; 0; 0];
P = diag([1e-4, 1, 10]);   % Covarianza inicial (theta, omega, T_aplicado)

T_kf = zeros(N,1);
theta_kf = zeros(N,1);

for i = 2:N
    % --- Predicción ---
    x_pred = Adk * x_est;
    P_pred = Adk * P * Adk' + Q;

    % --- Corrección con ambas mediciones a la vez ---
    z = [SG_meas(i); IMU_acc_filt(i)];
    y_innov = z - H*x_pred;
    S = H*P_pred*H' + R;
    K = (P_pred*H') / S;

    x_est = x_pred + K*y_innov;
    P = (eye(3) - K*H) * P_pred;

    T_kf(i) = x_est(3);
    theta_kf(i) = x_est(1);
end

%% 7. RESULTADOS Y GRÁFICOS (sin análisis espectral)
% Para el RMSE se compara contra T_motor_applied (el torque físico que
% realmente entrega el motor en la simulación), no contra T_ref: T_ref es
% el setpoint ideal antes del retardo propio del motor, y los sensores
% miden el eje real, no el setpoint.
T_verdadero = T_motor_applied;

figure('Name', 'Fusión de Sensores - Filtro de Kalman (3 estados)', 'Color', 'w', ...
       'Position', [100, 100, 1000, 800]);

subplot(2,1,1);
plot(t, T_verdadero, 'k--', 'LineWidth', 2); hold on;
plot(t, SG_meas, 'b', 'LineWidth', 1);
plot(t, IMU_meas_solo_inercial, 'r', 'LineWidth', 0.8);
plot(t, T_kf, 'g', 'LineWidth', 2);
ylabel('Torque (Nm)');
legend('Torque real aplicado', 'Strain Gauge (k\theta, filtrado)', ...
       'IMU (J\alpha, solo inercial)', 'Fusión Kalman (3 estados)', ...
       'Location', 'best');
title('Torque Real vs Sensores vs Estimación Fusionada');
grid on; xlim([0 T_sim]);

subplot(2,1,2);
err_sg = SG_meas - T_verdadero;
err_kf = T_kf - T_verdadero;
plot(t, err_sg, 'b', t, err_kf, 'g', 'LineWidth', 1.5);
yline(0, 'k--');
ylabel('Error (Nm)'); xlabel('Tiempo (s)');
legend('Error Strain Gauge', 'Error Fusión Kalman', 'Location', 'best');
title('Error de Estimación');
grid on; xlim([0 T_sim]);

rmse_sg = sqrt(mean(err_sg.^2));
rmse_kf = sqrt(mean(err_kf.^2));

fprintf('=== MÉTRICAS DE DESEMPEÑO ===\n');
fprintf('RMSE Strain Gauge solo: %.4f Nm\n', rmse_sg);
fprintf('RMSE Fusión Kalman:     %.4f Nm\n', rmse_kf);
fprintf('Mejora porcentual:      %.2f %%\n', ((rmse_sg - rmse_kf)/rmse_sg)*100);
fprintf('==============================\n\n');

%% 8. REGLA HEURÍSTICA DE ANCHO DE BANDA (único criterio de evaluación)
fprintf('=== EVALUACIÓN POR REGLA HEURÍSTICA DE ANCHO DE BANDA ===\n');
fprintf('Frecuencia Natural del Sistema: %.2f Hz\n', fn);
fprintf('Ancho de Banda Motor:           %d Hz\n', bw_motor);
fprintf('Ancho de Banda Driver:          %d Hz\n', bw_driver);
fprintf('Ancho de Banda Strain Gauge:    %d Hz\n', bw_strain);
fprintf('Ancho de Banda IMU:             %d Hz\n', bw_imu);
fprintf('Frecuencia de Lazo ESP32:       %d Hz\n', bw_esp32);
fprintf('-----------------------------------------------------------\n');

if bw_motor > 5*fn
    fprintf('>> VIABLE: el motor puede controlar la dinámica natural (BW_motor > 5*fn).\n');
else
    fprintf('>> ALERTA: el motor podría tener dificultad para controlar la resonancia (BW_motor <= 5*fn).\n');
end

if bw_strain < fn
    fprintf('>> ALERTA: el Strain Gauge es demasiado lento para captar la dinámica natural (BW_strain < fn).\n');
    fprintf('   Esto justifica fusionarlo con la IMU mediante el Filtro de Kalman.\n');
else
    fprintf('>> OK: el Strain Gauge tiene ancho de banda suficiente (BW_strain >= fn).\n');
end

if bw_imu > 5*fn
    fprintf('>> OK: la IMU tiene ancho de banda de sobra para capturar la dinámica natural (BW_imu > 5*fn).\n');
else
    fprintf('>> ALERTA: la IMU podría no ser suficientemente rápida (BW_imu <= 5*fn).\n');
end

if bw_esp32 > 10*fn
    fprintf('>> OK: la frecuencia de lazo del ESP32 es adecuada para el control (f_loop > 10*fn).\n');
else
    fprintf('>> ALERTA: la frecuencia de lazo del ESP32 podría ser insuficiente (f_loop <= 10*fn).\n');
end
fprintf('=============================================================\n');

end