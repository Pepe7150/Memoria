% =========================================================================
% SCRIPT 3: MATRICES DEL SISTEMA, FILTRO DE KALMAN Y OBSERVABILIDAD
% =========================================================================

% --- Planta Mecánica Real (6 Estados) ---
Ac6 = [0, 1, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0;
       0, 0, 0, 1, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C;
       0, 0, 0, 0, 0, 1;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B];
Bc6 = [0,0; 1/J_A,0; 0,0; 0,0; 0,0; 0,-1/J_B];

% Matriz auxiliar de salida para extraer Torques Transmitidos (T_AC, T_CB)
% Permite calcular: T_trans = C_torque * x6
C_torque = [k1, c1, -k1, -c1,  0,   0; 
             0,  0,  k2,  c2, -k2, -c2];

% Discretización nativa con Retención de Orden Cero (ZOH)
sys_c = ss(Ac6, Bc6, eye(6), zeros(6,2));
sys_d = c2d(sys_c, dt_sim, 'zoh');
Ad6 = sys_d.A; 
Bd6 = sys_d.B;

% --- Modelo Ampliado del Kalman (14 Estados Ordenados) ---
% 1-6: Mecánica | 7-8: Torques | 9-10: Filtros Sensores | 11-14: Sesgos
nx = 14; 
Ac14 = zeros(nx,nx);

% 1. Reutilizamos las matrices reales Ac6 y Bc6 para construir la dinámica base
% Los estados 7 y 8 (Torques) entran a la planta exactamente como lo define Bc6
Ac14(1:6, 1:6) = Ac6;
Ac14(1:6, 7:8) = Bc6;

tau_imu_c = 1/(2*pi*bw_imu); 
tau_sg_c = 1/(2*pi*bw_strain);

% 2. Integración dinámica de la respuesta temporal de sensores (Estados 9 y 10)
Ac14(9,4)  = 1/tau_imu_c;    Ac14(9,9)   = -1/tau_imu_c;      % IMU depende de omega_C

% Reutilizamos la matriz C_torque para acoplar la dinámica del Strain Gauge (depende de T_AC)
Ac14(10,1:6) = C_torque(1,:) / tau_sg_c;
Ac14(10,10)  = -1/tau_sg_c;                                   

Adk = expm(Ac14*dt_sim); % Matriz del Kalman (Predictor)

% --- Matriz de Medición H (6 Sensores) ---
H = zeros(6,nx); 
H(1,1)  = 1;               % Hall A (thetaA)
H(2,5)  = 1;               % Hall B (thetaB)
H(3,7)  = 1; H(3,11) = 1;  % Corriente A (Torque A) + Bias Corriente A
H(4,8)  = 1; H(4,12) = 1;  % Corriente B (Torque B) + Bias Corriente B
H(5,9)  = 1; H(5,13) = 1;  % IMU Dinámica + Bias IMU
H(6,10) = 1; H(6,14) = 1;  % SG Dinámica + Bias SG

% --- Sesgos Reales y Ruidos ---
noise_hall_std = 0.002; noise_current_std = 0.03;
noise_gyro_std = 0.02;  noise_strain_std  = 0.005;

bias_hallA = 0.05;    bias_hallB = -0.03;
bias_currentA = 0.1;  bias_currentB = -0.08;
bias_imu = 0.2;       bias_sg = 0.15;

% --- Análisis de Observabilidad ---
O_mat = obsv(Adk, H);
rank_O = rank(O_mat);
cond_O = cond(O_mat);

% --- Matrices de Covarianza Q y R ---
tau_hall = 1/(2*pi*bw_hall);     alpha_hall = dt_sim/(tau_hall+dt_sim);
tau_cs = 1/(2*pi*bw_current_filt); alpha_cs = dt_sim/(tau_cs+dt_sim);
tau_imu = 1/(2*pi*bw_imu);       alpha_imu = dt_sim/(tau_imu+dt_sim);
tau_sg = 1/(2*pi*bw_strain);     alpha_sg = dt_sim/(tau_sg+dt_sim);

var_hall = noise_hall_std^2 * alpha_hall/(2-alpha_hall);
var_IA   = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_imu  = noise_gyro_std^2 * alpha_imu/(2-alpha_imu);
var_sg   = noise_strain_std^2 * alpha_sg/(2-alpha_sg);

R = diag([var_hall, var_hall, (Kt_A^2)*var_IA, (Kt_B^2)*var_IA, var_imu, var_sg]);

Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, ... % 1-6: Mecánica
          0.01*dt_sim, 0.01*dt_sim, ...              % 7-8: Torques
          1e-8, 1e-8, ...                            % 9-10: Filtros Sensores
          1e-5*dt_sim, 1e-5*dt_sim, ...              % 11-12: Bias Corriente
          1e-6, 1e-6]);                              % 13-14: Bias IMU y SG

% --- PRE-CÁLCULO DE LA GANANCIA ESTACIONARIA DE KALMAN ---
P_temp = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, ... % Mecánica
               10, 10, ...                    % Torques
               1, 1, ...                      % Filtros Sensores
               1, 1, 1, 1]);                  % Sesgos

for iter = 1:500 
    P_pred = Adk*P_temp*Adk' + Q;
    S = H*P_pred*H' + R;
    K_kalman_steady = (P_pred*H') / S;
    P_temp = (eye(nx) - K_kalman_steady*H)*P_pred;
end

fprintf('=== CONFIGURACIÓN DE KALMAN Y OBSERVABILIDAD COMPLETADA ===\n');
fprintf('Rango de Observabilidad: %d/%d (Condición: %.2e)\n\n', rank_O, nx, cond_O);