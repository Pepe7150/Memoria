% =========================================================================
% SCRIPT 1: PARÁMETROS MECÁNICOS, ELÉCTRICOS Y ANCHOS DE BANDA
% =========================================================================
clc; clearvars; close all;

% --- Parámetros Geométricos y Mecánicos ---
d = 0.005;                        % Diámetro del eje [m]
L = 0.15;                         % Longitud total del eje [m]
G = 79.3e9;                       % Módulo de rigidez al corte (Acero) [Pa]
J_polar = (pi * d^4) / 32;        % Momento polar de inercia [m^4]
k_full = (G * J_polar) / L;       % Rigidez del eje completo [Nm/rad]
c_full = 0.05;                    % Amortiguamiento de referencia [Nms/rad]

% Tramos divididos por la aleta central (L/2 -> 2x rigidez)
k1 = 2*k_full; 
c1 = 2*c_full;    % Tramo Motor A -> C
k2 = 2*k_full; 
c2 = 2*c_full;    % Tramo C -> Motor B

J_A = 4e-4;                       % Inercia Motor A [kg*m^2]
J_B = 3e-4;                       % Inercia Motor B [kg*m^2]
J_C = 5e-5;                       % Inercia Aleta Central C [kg*m^2]

b_A = 0.02;                       % Fricción viscosa en A [Nms/rad]
b_B = 0.02;                       % Fricción viscosa en B [Nms/rad]

% --- Parámetros Eléctricos ---
Kt_A = 0.06;                      % Constante de torque Motor A [Nm/A]
Kt_B = 0.05;                      % Constante de torque Motor B [Nm/A]

% --- Parámetros Físicos de Montaje ---
r_imu = 0.005;                    % Excentricidad radial de la IMU [m] (5 mm fuera del centro)

% Sensibilidad del giroscopio a aceleración lineal (g-sensitivity).
% Un giroscopio MEMS montado fuera del eje siente la aceleración centrípeta
% (omega^2 * r_imu) y una fracción se filtra a su salida de velocidad angular.
% El datasheet la da en [°/s por g]. 0.05 °/s/g es un valor TÍPICO de MEMS,
% NO el de tu IMU: reemplázalo con el valor del datasheet del sensor real.
g_sens_imu  = 0.05 * (pi/180);    % [(rad/s) por g]
g_terrestre = 9.81;               % [m/s^2]

% --- Escala de torque del banco (LUT aleta 15x15 cm: pico ~0.38 N·m) ---
% Antes: 4 N·m (A) y 3 N·m (B) y fail-safe de 8 N·m, heredados del ejemplo.
T_nom_A = 0.4;                    % Torque nominal A [Nm] (solo modelo térmico)
T_nom_B = 0.4;                    % Torque nominal B [Nm] (solo modelo térmico)
T_B_max = 1.0;                    % Saturación del actuador bajo ensayo [Nm] (MG996R ~1 N·m en bloqueo: VERIFICAR datasheet)
max_torque_Nm = 0.8;              % Fail-safe de torque [Nm] (~2x el pico de la LUT)
max_fin_deg   = 20;               % Fail-safe de ángulo de la aleta C [deg] (topes mecánicos a diseñar)

% --- Actuador bajo ensayo (B = MG996R): lazo interno modelado como PID ---
% Realimenta con el potenciómetro propio del servo, NO con el Kalman.
Kp_pos = 5; Ki_pos = 20; Kd_pos = 0.05;   % [Nm/rad], [Nm/(rad·s)], [Nm·s/rad] (provisorios)
noise_pot_std = 0.0005;           % Ruido del potenciómetro del servo [rad]
tau_d_srv     = 0.01;             % Filtro de la derivada del servo [s]
w_servo_max   = 6.16;             % Velocidad máx. del servo [rad/s] (0.17 s/60° a 4.8 V: VERIFICAR)

% --- Frecuencias Naturales ---
M = diag([J_A, J_C, J_B]);
K = [ k1,      -k1,      0;
      -k1,   k1+k2,    -k2;
        0,     -k2,     k2];

[~, Dlam] = eig(K, M);
fn_all = sort(sqrt(max(diag(Dlam),0)) / (2*pi));
fn1 = fn_all(2);                  % Primer modo [Hz]
fn2 = fn_all(3);                  % Segundo modo [Hz]

% --- Anchos de Banda [Hz] ---
bw_driver       = 200;
bw_hall         = 200;     % antes 500; con fs_kf = 1 kHz el Nyquist es 500 Hz
bw_imu          = 150;
bw_strain       = 30;
bw_current_filt = 200;     % antes 500; idem

% --- Parámetros de Sesgo (Modelo Gauss-Markov / Ornstein-Uhlenbeck) ---
tau_b_IA  = 12.0;    % Tiempo de correlación sesgo Corriente A [s]
tau_b_IB  = 12.0;    % Tiempo de correlación sesgo Corriente B [s]
tau_b_imu = 8.0;     % Tiempo de correlación sesgo IMU Giroscopio [s]
tau_b_sg  = 10.0;    % Tiempo de correlación sesgo Strain Gauge [s]

sigma_b_IA  = 0.15;  % Sesgo de Corriente A [A]
sigma_b_IB  = 0.12;  % Sesgo de Corriente B [A]
sigma_b_imu = 0.25;  % Sesgo de IMU Giroscopio [rad/s]
sigma_b_sg  = 0.20;  % Sesgo de Strain Gauge [Nm]

fprintf('=== PARÁMETROS MECÁNICOS, ELECTRÓNICOS Y FÍSICOS CARGADOS ===\n');
fprintf('Rigidez k1 (A-C): %.2f Nm/rad | Rigidez k2 (C-B): %.2f Nm/rad\n', k1, k2);
fprintf('Frecuencias naturales: Modo Rígido = %.2f Hz | Modo 1 = %.2f Hz | Modo 2 = %.2f Hz\n', ...
    fn_all(1), fn1, fn2);
fprintf('Excentricidad IMU configurada: r_imu = %.1f mm\n\n', r_imu*1000);