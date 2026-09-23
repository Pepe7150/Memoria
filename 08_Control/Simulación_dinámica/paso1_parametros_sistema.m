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
bw_hall         = 500;
bw_imu          = 150;
bw_strain       = 30;
bw_current_filt = 500;

fprintf('=== PARÁMETROS MECÁNICOS Y ELECTRÓNICOS CARGADOS ===\n');
fprintf('Rigidez k1 (A-C): %.2f Nm/rad | Rigidez k2 (C-B): %.2f Nm/rad\n', k1, k2);
fprintf('Frecuencias naturales: Modo Rígido = %.2f Hz | Modo 1 = %.2f Hz | Modo 2 = %.2f Hz\n\n', ...
    fn_all(1), fn1, fn2);