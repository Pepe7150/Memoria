clc; clear; close all;

%% 1. PARÁMETROS MECÁNICOS
d = 0.005; 
L = 0.15; 
G = 79.3e9;
J_polar = (pi * d^4) / 32;
k_full = (G * J_polar) / L;      % Rigidez del eje completo
c_full = 0.05;                   % Amortiguamiento de referencia

% Tramos divididos por la aleta central (L/2 -> 2x rigidez)
k1 = 2*k_full;  c1 = 2*c_full;   % Tramo Motor A -> C
k2 = 2*k_full;  c2 = 2*c_full;   % Tramo C -> Motor B

J_A = 4e-4;    % Motor A [kg*m^2]
J_B = 3e-4;    % Motor B [kg*m^2]
J_C = 5e-5;    % Eje + aleta central [kg*m^2]

% Fricción viscosa de rodamientos
b_A = 0.02;    % Motor A [Nms/rad]
b_B = 0.02;    % Motor B [Nms/rad]

% Constantes de torque nominables
Kt_A = 0.06;   % Motor A [Nm/A]
Kt_B = 0.05;   % Motor B [Nm/A]

%% 2. FRECUENCIAS NATURALES (Matriz M y K)
M = diag([J_A, J_C, J_B]);
K = [ k1,      -k1,      0;
      -k1,   k1+k2,    -k2;
        0,     -k2,     k2];

[~, Dlam] = eig(K, M);
fn_all = sort(sqrt(max(diag(Dlam),0)) / (2*pi));   % Incluye modo rígido (~0 Hz)
fn1 = fn_all(2);   % Primer modo elástico
fn2 = fn_all(3);   % Segundo modo elástico
fn_max = fn_all(3);

%% 3. ANCHOS DE BANDA Y ELECTRONICA [Hz]
bw_driver       = 200;
bw_encoder      = 500;
bw_imu          = 150;
bw_strain       = 30;
bw_current_filt = 500;

%% MOSTRAR RESULTADOS EN CONSOLA
fprintf('=== PARÁMETROS MECÁNICOS CARGADOS ===\n');
fprintf('Rigidez k1 (A-C): %.2f Nm/rad | Rigidez k2 (C-B): %.2f Nm/rad\n', k1, k2);
fprintf('Frecuencias naturales: Modo Rígido = %.2f Hz | Modo 1 = %.2f Hz | Modo 2 = %.2f Hz\n', ...
    fn_all(1), fn1, fn2);