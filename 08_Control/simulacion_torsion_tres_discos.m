% =========================================================================
% SIMULACIÓN COMPLETA: SISTEMA DE 3 INERCIAS CON DERIVA TÉRMICA Y KALMAN
% (VERSIÓN CON SENSORES HALL, IMU, SG Y CORRIENTE)
% =========================================================================
clc; clear; close all;

%% 1. PARÁMETROS MECÁNICOS Y ELÉCTRICOS
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

% FRECUENCIAS NATURALES (Matriz M y K)
M = diag([J_A, J_C, J_B]);
K = [ k1,      -k1,      0;
      -k1,   k1+k2,    -k2;
        0,     -k2,     k2];

[~, Dlam] = eig(K, M);
fn_all = sort(sqrt(max(diag(Dlam),0)) / (2*pi));   % Incluye modo rígido (~0 Hz)
fn1 = fn_all(2);   % Primer modo elástico
fn2 = fn_all(3);   % Segundo modo elástico

% ANCHOS DE BANDA Y ELECTRONICA [Hz]
bw_driver       = 200;
bw_hall         = 500; % Ancho de banda del sensor Hall
bw_imu          = 150;
bw_strain       = 30;
bw_current_filt = 500;

fprintf('=== PARÁMETROS MECÁNICOS CARGADOS ===\n');
fprintf('Rigidez k1 (A-C): %.2f Nm/rad | Rigidez k2 (C-B): %.2f Nm/rad\n', k1, k2);
fprintf('Frecuencias naturales: Modo Rígido = %.2f Hz | Modo 1 = %.2f Hz | Modo 2 = %.2f Hz\n\n', ...
    fn_all(1), fn1, fn2);


%% 2. CONFIGURACIÓN TEMPORAL Y PERFIL DE TORQUE ABIERTO
fs_sim = 5000; 
dt_sim = 1/fs_sim; 
T_sim = 20;   % 20 segundos de simulación
t = (0:dt_sim:T_sim-dt_sim)'; 
N = length(t);

% PERFIL DE TORQUE DEL MOTOR A (Carga, Open-loop)
t_ramp_ini = 1.0; 
t_ramp_fin = 4.0;
idx_r1 = find(t >= t_ramp_ini, 1, 'first');
idx_r2 = find(t >= t_ramp_fin, 1, 'first');

T_A_ref = zeros(N,1);
T_A_ref(idx_r1:idx_r2) = linspace(0, 4.0, idx_r2-idx_r1+1)';
T_A_ref(idx_r2:end) = 4.0;

% DINÁMICA DEL DRIVER DEL MOTOR A (Prueba Lazo Abierto)
I_A_ref = T_A_ref / Kt_A;
tau_drv = 1/(2*pi*bw_driver);       
alpha_drv = dt_sim / (tau_drv + dt_sim);        

I_A_true = zeros(N,1);
for i = 2:N
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref(i) - I_A_true(i-1));
end

% DERIVA TÉRMICA DE Kt (Prueba Lazo Abierto)
I_A_rated = 4.0 / Kt_A;        
tau_thermal = 10;              
alpha_th = dt_sim / (tau_thermal + dt_sim);
kt_drift_A = 0.08;             

heatA = zeros(N,1);
for i = 2:N
    heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i)/I_A_rated)^2 - heatA(i-1));
end

Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA);
T_A_true = Kt_A_actual .* I_A_true;   


%% 3. INICIALIZACIÓN LAZO CERRADO Y FILTRO DE KALMAN
% --- Planta Mecánica (6 estados) ---
Ac6 = [0, 1, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0;
       0, 0, 0, 1, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C;
       0, 0, 0, 0, 0, 1;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B];
Bc6 = [0,0; 1/J_A,0; 0,0; 0,0; 0,0; 0,-1/J_B];
Maug6d = expm([Ac6, Bc6; zeros(2, 8)]*dt_sim);
Ad6 = Maug6d(1:6, 1:6); 
Bd6 = Maug6d(1:6, 7:8);

x6 = zeros(6, N);
I_A_true = zeros(N,1); T_A_true = zeros(N,1); 
I_B_true = zeros(N,1); T_B_true = zeros(N,1);
heatA = zeros(N,1); heatB = zeros(N,1);
I_A_rated = 4.0/Kt_A; I_B_rated = 3.0/Kt_B;
kt_drift_B = 0.08;

% --- FILTRO DE KALMAN (14 estados: 6 mecánica + 2 torques + 2 bias corriente + 2 filtros + 2 bias IMU/SG) ---
Ac8 = [0, 1, 0, 0, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0, 1/J_A, 0; 
       0, 0, 0, 1, 0, 0, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C, 0, 0;
       0, 0, 0, 0, 0, 1, 0, 0;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B, 0, -1/J_B; 
       0, 0, 0, 0, 0, 0, 0, 0;
       0, 0, 0, 0, 0, 0, 0, 0];

nx = 14; 
Ac14 = zeros(nx,nx);
Ac14(1:8,1:8) = Ac8;
tau_imu_c = 1/(2*pi*bw_imu); 
tau_sg_c = 1/(2*pi*bw_strain);

% Filtros de dinámica de sensores
Ac14(11,4) = 1/tau_imu_c; 
Ac14(11,11) = -1/tau_imu_c;
Ac14(12,1) = k1/tau_sg_c;
Ac14(12,3) = -k1/tau_sg_c;
Ac14(12,2) = c1/tau_sg_c; 
Ac14(12,4) = -c1/tau_sg_c; 
Ac14(12,12) = -1/tau_sg_c;

% Nota: Los estados 9, 10, 13 y 14 son derivas/sesgos constantes (sus derivadas son 0)
Adk = expm(Ac14*dt_sim);

% Matriz de Observación (6 sensores con estimación de bias en corriente, IMU y SG)
H = zeros(6,nx); 
H(1,1) = 1;               % Sensor Hall Motor A (thetaA)
H(2,5) = 1;               % Sensor Hall Motor B (thetaB)
H(3,7) = 1; H(3,9) = 1;   % Sensor corriente Motor A + Bias Corriente A
H(4,8) = 1; H(4,10) = 1;  % Sensor corriente Motor B + Bias Corriente B
H(5,11) = 1; H(5,13) = 1; % IMU + Bias IMU
H(6,12) = 1; H(6,14) = 1; % Strain Gauge + Bias SG

noise_hall_std = 0.002;   % Ruido típico para sensor Hall magnético
noise_current_std = 0.03;
noise_gyro_std = 0.02; 
noise_strain_std = 0.005;

% --- Sesgos (Bias) reales de los sensores ---
bias_hallA = 0.05;      % Sesgo constante Hall A [rad]
bias_hallB = -0.03;     % Sesgo constante Hall B [rad]
bias_currentA = 0.1;    % Sesgo constante Corriente A [A]
bias_currentB = -0.08;  % Sesgo constante Corriente B [A]
bias_imu = 0.2;         % Sesgo constante IMU [rad/s]
bias_sg = 0.15;         % Sesgo constante Strain Gauge [Nm]

% --- Análisis de Observabilidad ---
O_mat = obsv(Adk, H);      % Matriz de observabilidad discreta
rank_O = rank(O_mat);      % Rango (debe ser igual a nx = 14)
cond_O = cond(O_mat);      % Número de condición

% --- Búsqueda del mínimo de sensores ---
min_sensores = 0;
nombres_sensores = {'Hall A', 'Hall B', 'Corriente A', 'Corriente B', 'IMU', 'Strain Gauge'};
combo_ideal = {};

for k = 1:6
    combos = nchoosek(1:6, k);
    for j = 1:size(combos, 1)
        H_test = H(combos(j,:), :);
        if rank(obsv(Adk, H_test)) == nx
            min_sensores = k;
            combo_ideal = nombres_sensores(combos(j,:));
            break;
        end
    end
    if min_sensores > 0
        break; 
    end
end

tau_hall = 1/(2*pi*bw_hall); alpha_hall = dt_sim/(tau_hall+dt_sim);
tau_cs = 1/(2*pi*bw_current_filt); alpha_cs = dt_sim/(tau_cs+dt_sim);
tau_imu = 1/(2*pi*bw_imu); alpha_imu = dt_sim/(tau_imu+dt_sim);
tau_sg = 1/(2*pi*bw_strain); alpha_sg = dt_sim/(tau_sg+dt_sim);

var_hall = noise_hall_std^2 * alpha_hall/(2-alpha_hall);
var_IA = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_imu = noise_gyro_std^2 * alpha_imu/(2-alpha_imu);
var_sg = noise_strain_std^2 * alpha_sg/(2-alpha_sg);

% Matriz de Covarianza R (6x6)
R = diag([var_hall, var_hall, (Kt_A^2)*var_IA, (Kt_B^2)*var_IA, var_imu, var_sg]);

% Matriz de Covarianza Q (14x14)
Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, ... % 1-6: Dinámica mecánica
          0.01*dt_sim, 0.01*dt_sim, ...              % 7-8: Torques activos
          1e-5*dt_sim, 1e-5*dt_sim, ...              % 9-10: Bias Corrientes
          1e-8, 1e-8, ...                            % 11-12: Filtros sensores
          1e-6, 1e-6]);                              % 13-14: Bias IMU y SG

x_est = zeros(nx,1);
P = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, 10, 10, 1, 1, 1, 1, 1, 1]);

X_hist = zeros(nx, N);
thetaA_meas = zeros(N,1); thetaB_meas = zeros(N,1);
TA_current_est = zeros(N,1); TB_current_est = zeros(N,1);
omegaC_meas = zeros(N,1); SG_meas = zeros(N,1);
T_A_cmd = zeros(N,1);

IA_meas = 0; IB_meas = 0; 

Kp_pos = 1; Ki_pos = 5; Kd_pos = 0.5; 
integral_max = 10; theta_C_target = 0.2; theta_err_int = 0;


%% LIMITES DE SEGURIDAD (FAIL SAFES)
max_angle_rad = 135 * (pi / 180);       
max_speed_rads = 1000 * (2*pi / 60);    
max_torque_Nm = 8.0;                    
system_fault = false;
fault_time = NaN;
fault_reason = ''; % <-- Nueva variable para almacenar la causa exacta

%% 4. BUCLE EN TIEMPO REAL (Simulación Lazo Cerrado)
for i = 2:N
    
    if ~system_fault
        T_AC_prev = k1*(x6(1,i-1)-x6(3,i-1)) + c1*(x6(2,i-1)-x6(4,i-1));
        T_CB_prev = k2*(x6(3,i-1)-x6(5,i-1)) + c2*(x6(4,i-1)-x6(6,i-1));
        
        % Lógica desglozada para identificar la causa raíz
        if abs(x6(1,i-1)) >= max_angle_rad || abs(x6(5,i-1)) >= max_angle_rad
            system_fault = true;
            fault_time = t(i);
            fault_reason = 'Límite de ÁNGULO superado (>= 135°)';
            
        elseif abs(x6(2,i-1)) >= max_speed_rads || abs(x6(6,i-1)) >= max_speed_rads
            system_fault = true;
            fault_time = t(i);
            fault_reason = 'Límite de VELOCIDAD superado (>= 1000 RPM)';
            
        elseif abs(T_A_true(i-1)) >= max_torque_Nm || abs(T_B_true(i-1)) >= max_torque_Nm || ...
               abs(T_AC_prev) >= max_torque_Nm || abs(T_CB_prev) >= max_torque_Nm
            system_fault = true;
            fault_time = t(i);
            fault_reason = sprintf('Límite de TORQUE superado (>= %.1f Nm)', max_torque_Nm);
        end
    end

    if system_fault
        T_A_cmd(i) = 0;
        I_A_ref_i = 0;
        T_B_cmd_i = 0;
        I_B_ref_i = 0;
    else
        % Motor A
        biasA_estimado = x_est(9); 
        T_A_cmd(i) = T_A_ref(i) + biasA_estimado; 
        I_A_ref_i = T_A_cmd(i) / Kt_A;
        
        % Motor B (Lazo Cerrado PID)
        % CRÍTICO: El PID vuelve a usar la estimación del Kalman (x_est) porque 
        % los sensores Hall recuperaron la observabilidad de la posición absoluta.
        theta_err = theta_C_target - x_est(3);
        theta_err_int = max(min(theta_err_int + dt_sim*theta_err, integral_max), -integral_max);
        T_B_cmd_i = -(Kp_pos*theta_err + Ki_pos*theta_err_int + Kd_pos*(0 - x_est(4)));
        I_B_ref_i = T_B_cmd_i / Kt_B;
    end
    
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref_i - I_A_true(i-1));
    heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i)/I_A_rated)^2 - heatA(i-1));
    Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA(i));
    T_A_true(i) = Kt_A_actual * I_A_true(i);

    I_B_true(i) = I_B_true(i-1) + alpha_drv*(I_B_ref_i - I_B_true(i-1));
    heatB(i) = heatB(i-1) + alpha_th*((I_B_true(i)/I_B_rated)^2 - heatB(i-1));
    Kt_B_actual = Kt_B * (1 - kt_drift_B*heatB(i));
    T_B_true(i) = Kt_B_actual * I_B_true(i);

    u_plant = [T_A_true(i); T_B_true(i)];

    x6(:,i) = Ad6*x6(:,i-1) + Bd6*u_plant; 
    
    theta_A_true_i = x6(1,i); omega_A_true_i = x6(2,i);
    theta_C_true_i = x6(3,i); omega_C_true_i = x6(4,i);
    theta_B_true_i = x6(5,i); omega_B_true_i = x6(6,i);
    T_AC_true_i = k1*(theta_A_true_i-theta_C_true_i) + c1*(omega_A_true_i-omega_C_true_i);

    % --- Adquisición de Sensores ---
    
    % Sensores Hall
    thA_raw = theta_A_true_i + bias_hallA + noise_hall_std*randn;
    thB_raw = theta_B_true_i + bias_hallB + noise_hall_std*randn;
    
    % Compensación estática (Homing) requerida por el modo rígido
    thA_cal = thA_raw - bias_hallA; 
    thB_cal = thB_raw - bias_hallB; 
    
    thetaA_meas(i) = thetaA_meas(i-1) + alpha_hall*(thA_cal - thetaA_meas(i-1));
    thetaB_meas(i) = thetaB_meas(i-1) + alpha_hall*(thB_cal - thetaB_meas(i-1));
    
    % Corriente
    IA_raw = I_A_true(i) + bias_currentA + noise_current_std*randn;
    IB_raw = I_B_true(i) + bias_currentB + noise_current_std*randn;
    IA_meas = IA_meas + alpha_cs*(IA_raw - IA_meas);
    IB_meas = IB_meas + alpha_cs*(IB_raw - IB_meas);
    TA_current_est(i) = Kt_A * IA_meas;
    TB_current_est(i) = Kt_B * IB_meas;

    % IMU y SG
    wC_raw = omega_C_true_i + bias_imu + noise_gyro_std*randn;
    omegaC_meas(i) = omegaC_meas(i-1) + alpha_imu*(wC_raw - omegaC_meas(i-1));

    SG_raw = T_AC_true_i + bias_sg + noise_strain_std*randn;
    SG_meas(i) = SG_meas(i-1) + alpha_sg*(SG_raw - SG_meas(i-1));

    % --- Filtro de Kalman (6 mediciones) ---
    x_pred = Adk*x_est;
    P_pred = Adk*P*Adk' + Q;
    
    % Vector z actualizado con las 6 variables
    z = [thetaA_meas(i); thetaB_meas(i); TA_current_est(i); TB_current_est(i); omegaC_meas(i); SG_meas(i)];
         
    y_innov = z - H*x_pred;
    S = H*P_pred*H' + R;
    K = (P_pred*H') / S;

    x_est = x_pred + K*y_innov;
    P = (eye(nx) - K*H)*P_pred;
    X_hist(:,i) = x_est;
end

% Cálculos derivados
thetaA_kf = X_hist(1,:)'; omegaA_kf = X_hist(2,:)';
thetaC_kf = X_hist(3,:)'; omegaC_kf = X_hist(4,:)';
thetaB_kf = X_hist(5,:)'; omegaB_kf = X_hist(6,:)';
T_A_kf    = X_hist(7,:)'; T_B_kf    = X_hist(8,:)';
biasA_kf  = X_hist(9,:)'; biasB_kf  = X_hist(10,:)';

T_AC_kf = k1*(thetaA_kf-thetaC_kf) + c1*(omegaA_kf-omegaC_kf);
T_CB_kf = k2*(thetaC_kf-thetaB_kf) + c2*(omegaC_kf-omegaB_kf);

theta_C_true = x6(3,:)'; omega_C_true = x6(4,:)';
T_AC_true = k1*(x6(1,:)'-x6(3,:)') + c1*(x6(2,:)'-x6(4,:)');
T_CB_true = k2*(x6(3,:)'-x6(5,:)') + c2*(x6(4,:)'-x6(6,:)');

%% 5. GRÁFICOS Y MÉTRICAS
% Figura 1: Torques
figure('Name', 'Torque Motor A y Motor B', 'Color', 'w', 'Position', [50,50,950,700]);
subplot(2,1,1);
plot(t, T_A_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TA_current_est, 'm', 'LineWidth', 1); plot(t, T_A_kf, 'b', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('T_A (Nm)'); grid on; xlim([0 T_sim]);
legend('Real', 'Solo corriente (Kt nominal)', 'Kalman', 'Location', 'best'); title('Torque Motor A');
subplot(2,1,2);
plot(t, T_B_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TB_current_est, 'm', 'LineWidth', 1); plot(t, T_B_kf, 'r', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('T_B (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Solo corriente (Kt nominal)', 'Kalman', 'Location', 'best'); title('Torque Motor B');

% Figura 2: Torque Transmitido
figure('Name', 'Torque Transmitido', 'Color', 'w', 'Position', [70,70,950,700]);
subplot(2,1,1);
plot(t, T_AC_true, 'k--', 'LineWidth', 2); hold on;
plot(t, SG_meas, 'c', 'LineWidth', 1); plot(t, T_AC_kf, 'g', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('T_{AC} (Nm)'); grid on; xlim([0 T_sim]);
legend('Real', 'Strain gauge', 'Kalman', 'Location', 'best'); title('Torque Transmitido A-C');
subplot(2,1,2);
plot(t, T_CB_true, 'k--', 'LineWidth', 2); hold on; plot(t, T_CB_kf, 'g', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('T_{CB} (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Kalman', 'Location', 'best'); title('Torque Transmitido C-B');

% Figura 3: Cinemática Disco C
figure('Name', 'Cinemática Disco C', 'Color', 'w', 'Position', [90,90,950,700]);
subplot(2,1,1);
plot(t, theta_C_true, 'k--', 'LineWidth', 2); hold on; plot(t, thetaC_kf, 'b', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('\theta_C (rad)'); grid on; xlim([0 T_sim]); legend('Real', 'Kalman (Recuperado)', 'Location', 'best');
title('Posición Absoluta (Sin Deriva)');
subplot(2,1,2);
plot(t, omega_C_true, 'k--', 'LineWidth', 2); hold on;
plot(t, omegaC_meas, 'm', 'LineWidth', 1); plot(t, omegaC_kf, 'b', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('\omega_C (rad/s)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]); legend('Real', 'IMU', 'Kalman');

% --- EXTRACTO DE ESTADOS REALES Y MÉTRICAS ---
theta_A_true = x6(1,:)'; omega_A_true = x6(2,:)';
theta_C_true = x6(3,:)'; omega_C_true = x6(4,:)';
theta_B_true = x6(5,:)'; omega_B_true = x6(6,:)';

rmse = @(e) sqrt(mean(e.^2));
mejora = @(rmse_crudo, rmse_kf) ((rmse_crudo - rmse_kf)/rmse_crudo)*100;

fprintf('========================================================================================\n');
fprintf('                             MÉTRICAS DE DESEMPEÑO Y SENSORES                           \n');
fprintf('========================================================================================\n\n');

% 1. POSICIONES ANGULARES
fprintf('--- POSICIONES ANGULARES [rad] ---\n');
fprintf('theta_A  | Sensor directo: Hall A (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.5f rad | RMSE Kalman: %.5f rad | Mejora: %.2f %%\n', ...
    rmse(thetaA_meas - theta_A_true), rmse(thetaA_kf - theta_A_true), mejora(rmse(thetaA_meas - theta_A_true), rmse(thetaA_kf - theta_A_true)));

fprintf('theta_B  | Sensor directo: Hall B (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.5f rad | RMSE Kalman: %.5f rad | Mejora: %.2f %%\n', ...
    rmse(thetaB_meas - theta_B_true), rmse(thetaB_kf - theta_B_true), mejora(rmse(thetaB_meas - theta_B_true), rmse(thetaB_kf - theta_B_true)));

fprintf('theta_C  | Sensor directo: Ninguno (Estimación Virtual por Fusión: Hall A, Hall B, IMU, SG)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.5f rad\n\n', ...
    rmse(thetaC_kf - theta_C_true));

% 2. VELOCIDADES ANGULARES
fprintf('--- VELOCIDADES ANGULARES [rad/s] ---\n');
fprintf('omega_A  | Sensor directo: Ninguno (Estimación Virtual: Modelo + Hall A + Corriente A)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.4f rad/s\n', ...
    rmse(omegaA_kf - omega_A_true));

fprintf('omega_B  | Sensor directo: Ninguno (Estimación Virtual: Modelo + Hall B + Corriente B)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.4f rad/s\n', ...
    rmse(omegaB_kf - omega_B_true));

fprintf('omega_C  | Sensor directo: IMU Giroscopio (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.4f rad/s | RMSE Kalman: %.4f rad/s | Mejora: %.2f %%\n\n', ...
    rmse(omegaC_meas - omega_C_true), rmse(omegaC_kf - omega_C_true), mejora(rmse(omegaC_meas - omega_C_true), rmse(omegaC_kf - omega_C_true)));

% 3. TORQUES
fprintf('--- TORQUES ACTIVOS Y TRANSMITIDOS [Nm] ---\n');
fprintf('T_A      | Sensor directo: Corriente Motor A (+ Estimación Kalman de Kt drift y Bias)\n');
fprintf('         RMSE Crudo: %.4f Nm   | RMSE Kalman: %.4f Nm   | Mejora: %.2f %%\n', ...
    rmse(TA_current_est - T_A_true), rmse(T_A_kf - T_A_true), mejora(rmse(TA_current_est - T_A_true), rmse(T_A_kf - T_A_true)));

fprintf('T_B      | Sensor directo: Corriente Motor B (+ Estimación Kalman de Kt drift y Bias)\n');
fprintf('         RMSE Crudo: %.4f Nm   | RMSE Kalman: %.4f Nm   | Mejora: %.2f %%\n', ...
    rmse(TB_current_est - T_B_true), rmse(T_B_kf - T_B_true), mejora(rmse(TB_current_est - T_B_true), rmse(T_B_kf - T_B_true)));

fprintf('T_AC     | Sensor directo: Strain Gauge SG (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.4f Nm   | RMSE Kalman: %.4f Nm   | Mejora: %.2f %%\n', ...
    rmse(SG_meas - T_AC_true), rmse(T_AC_kf - T_AC_true), mejora(rmse(SG_meas - T_AC_true), rmse(T_AC_kf - T_AC_true)));

fprintf('T_CB     | Sensor directo: Ninguno (Estimación Virtual: Modelo + Hall B + SG)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.4f Nm\n', ...
    rmse(T_CB_kf - T_CB_true));
fprintf('========================================================================================\n\n');

fprintf('=== EVALUACIÓN DE ANCHO DE BANDA ===\n');
bw_ctrl_loop = sqrt(Kp_pos/J_B)/(2*pi);
fprintf('Ancho de banda del lazo de control de B: %.2f Hz\n', bw_ctrl_loop);

if bw_driver > 5*bw_ctrl_loop
    fprintf('>> OK: Driver (%d Hz) > 5x ancho de banda de control (%.2f Hz).\n', bw_driver, bw_ctrl_loop);
else
    fprintf('>> ALERTA: Driver (%d Hz) podría limitar el control.\n', bw_driver);
end

if bw_current_filt > 5*fn1
    fprintf('>> OK: Filtro corriente (%d Hz) resuelve fn1 (BW > 5x fn1).\n', bw_current_filt);
else
    fprintf('>> ALERTA: Filtro corriente (%d Hz) podría no resolver fn1.\n', bw_current_filt);
end
fprintf('=====================================================\n\n');

fprintf('=== ESTADO DE SEGURIDAD (FAIL SAFES) ===\n');
if system_fault
    fprintf('!!! ADVERTENCIA: Se disparó un FAIL SAFE a los %.3f segundos !!!\n', fault_time);
    fprintf('Causa específica: %s\n', fault_reason); % <-- Imprime la razón exacta
else
    fprintf('Estado: OK. No se detectaron violaciones a los límites angulares, cinemáticos ni de torque.\n');
end
fprintf('=====================================================\n');

fprintf('=== ANÁLISIS DE OBSERVABILIDAD ===\n');
fprintf('Rango de la matriz: %d / %d\n', rank_O, nx);
fprintf('Número de condición: %.2e (valores menores indican mejor observabilidad numérica)\n', cond_O);

if rank_O == nx
    fprintf('>> OK: El sistema es COMPLETAMENTE OBSERVABLE con los 6 sensores actuales.\n');
else
    fprintf('>> ALERTA: El sistema NO es completamente observable. Rango deficiente.\n');
end

if min_sensores > 0
    fprintf('>> MÍNIMO NECESARIO: Se requieren al menos %d sensor(es) para observar los %d estados.\n', min_sensores, nx);
    fprintf('>> COMBINACIÓN VÁLIDA: %s\n', strjoin(combo_ideal, ', '));
else
    fprintf('>> ERROR: Ninguna combinación de los sensores permite observabilidad completa.\n');
end
fprintf('=====================================================\n\n');