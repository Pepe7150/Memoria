% =========================================================================
% SIMULACIÓN CON MÉTRICAS Y PLOTS: SISTEMA DE 3 INERCIAS (IMU-ONLY)
% =========================================================================

%Funciona pero cuando el control es lento solamente
clc; clear; close all;

%% 1. PARÁMETROS MECÁNICOS Y ELÉCTRICOS
d = 0.005; 
L = 0.15; 
G = 79.3e9;
J_polar = (pi * d^4) / 32;
k_full = (G * J_polar) / L;      
c_full = 0.05;                   

k1 = 2*k_full;  c1 = 2*c_full;   
k2 = 2*k_full;  c2 = 2*c_full;   

J_A = 4e-4;    
J_B = 3e-4;    
J_C = 5e-5;    

b_A = 0.02;    
b_B = 0.02;    

Kt_A = 0.06;   
Kt_B = 0.05;   

M = diag([J_A, J_C, J_B]);
K = [ k1,      -k1,      0;
      -k1,   k1+k2,    -k2;
        0,     -k2,     k2];

bw_driver       = 200;
bw_imu          = 150;

%% 2. CONFIGURACIÓN TEMPORAL Y PERFIL DE TORQUE ABIERTO
fs_sim = 5000; 
dt_sim = 1/fs_sim; 
T_sim = 20;   
t = (0:dt_sim:T_sim-dt_sim)'; 
N = length(t);

t_ramp_ini = 1.0; 
t_ramp_fin = 4.0;
idx_r1 = find(t >= t_ramp_ini, 1, 'first');
idx_r2 = find(t >= t_ramp_fin, 1, 'first');

T_A_ref = zeros(N,1);
T_A_ref(idx_r1:idx_r2) = linspace(0, 4.0, idx_r2-idx_r1+1)';
T_A_ref(idx_r2:end) = 4.0;

tau_drv = 1/(2*pi*bw_driver);       
alpha_drv = dt_sim / (tau_drv + dt_sim);        

%% 3. INICIALIZACIÓN LAZO CERRADO Y FILTRO DE KALMAN
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
tau_thermal = 10; alpha_th = dt_sim / (tau_thermal + dt_sim);
kt_drift_A = 0.08; kt_drift_B = 0.08;

% --- FILTRO DE KALMAN (IMU-Only) ---
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
Ac12(1:8,1:8) = Ac8;
Adk = expm(Ac12*dt_sim); 

H_imu = zeros(3, nx);
H_imu(1, 2) = 1; % w_A
H_imu(2, 4) = 1; % w_C
H_imu(3, 6) = 1; % w_B

noise_gyro_std = 0.02;
tau_imu = 1/(2*pi*bw_imu); alpha_imu = dt_sim/(tau_imu+dt_sim);
var_imu = noise_gyro_std^2 * alpha_imu/(2-alpha_imu);

R_imu = diag([var_imu, var_imu, var_imu]);
Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, 0.01*dt_sim, 0.01*dt_sim, 1e-5*dt_sim, 1e-5*dt_sim, 1e-8, 1e-8]);

x_est = zeros(nx,1);
P = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, 10, 10, 1, 1, 1, 1]);
X_hist = zeros(nx, N);

T_A_cmd = zeros(N,1);
Kp_pos = 15; Ki_pos = 50; Kd_pos = 2.0; 
integral_max = 10; theta_C_target = 0.2; theta_err_int = 0;

max_angle_rad = 135 * (pi / 180);       
max_speed_rads = 1000 * (2*pi / 60);    
max_torque_Nm = 8.0;                    
system_fault = false;
fault_time = NaN;

%% 4. BUCLE EN TIEMPO REAL
for i = 2:N
    if ~system_fault
        T_AC_prev = k1*(x6(1,i-1)-x6(3,i-1)) + c1*(x6(2,i-1)-x6(4,i-1));
        T_CB_prev = k2*(x6(3,i-1)-x6(5,i-1)) + c2*(x6(4,i-1)-x6(6,i-1));
        
        if abs(x6(1,i-1)) >= max_angle_rad || abs(x6(5,i-1)) >= max_angle_rad || ...
           abs(x6(2,i-1)) >= max_speed_rads || abs(x6(6,i-1)) >= max_speed_rads || ...
           abs(T_A_true(i-1)) >= max_torque_Nm || abs(T_B_true(i-1)) >= max_torque_Nm || ...
           abs(T_AC_prev) >= max_torque_Nm || abs(T_CB_prev) >= max_torque_Nm
            system_fault = true;
            fault_time = t(i);
        end
    end

    if system_fault
        T_A_cmd(i) = 0; I_A_ref_i = 0;
        T_B_cmd_i = 0; I_B_ref_i = 0;
    else
        biasA_estimado = x_est(9); 
        T_A_cmd(i) = T_A_ref(i) + biasA_estimado; 
        I_A_ref_i = T_A_cmd(i) / Kt_A;
        
        % Control PID usando la estimación ciega de Kalman
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

    % Mediciones IMU
    wA_raw = x6(2,i) + noise_gyro_std*randn;
    wC_raw = x6(4,i) + noise_gyro_std*randn;
    wB_raw = x6(6,i) + noise_gyro_std*randn;
    z_imu = [wA_raw; wC_raw; wB_raw];

    % Kalman Update
    x_pred = Adk*x_est;
    P_pred = Adk*P*Adk' + Q;
    y_innov = z_imu - H_imu*x_pred;
    S = H_imu*P_pred*H_imu' + R_imu;
    K = (P_pred*H_imu') / S;
    x_est = x_pred + K*y_innov;
    P = (eye(nx) - K*H_imu)*P_pred;
    X_hist(:,i) = x_est;
end

%% 5. CÁLCULO DE MÉTRICAS DE DESEMPEÑO
theta_C_true = x6(3,:)'; 
omega_C_true = x6(4,:)';
thetaC_kf = X_hist(3,:)'; 
omegaC_kf = X_hist(4,:)';

pos_error = theta_C_true - thetaC_kf;
rms_pos_error = sqrt(mean(pos_error.^2));
max_drift = abs(theta_C_true(end) - thetaC_kf(end));
max_speed_sys = max(abs(x6(2,:)));
max_torque_sys = max(abs(T_A_true));

fprintf('\n=========================================\n');
fprintf('       MÉTRICAS DEL EXPERIMENTO IMU-ONLY   \n');
fprintf('=========================================\n');
if system_fault
    fprintf('Estado del Sistema : FALLÓ a los %.3f s\n', fault_time);
else
    fprintf('Estado del Sistema : Completado sin disparo\n');
end
fprintf('Error RMS de Posición (theta_C) : %.4f rad\n', rms_pos_error);
fprintf('Deriva de Posición Final        : %.4f rad\n', max_drift);
fprintf('Velocidad Máxima Registrada     : %.2f rad/s\n', max_speed_sys);
fprintf('Torque Máximo en Motor A        : %.2f Nm\n', max_torque_sys);
fprintf('=========================================\n\n');

%% 6. PLOTS Y PANEL DE RESULTADOS MÚLTIPLES
figure('Name', 'Analisis de Observabilidad IMU-Only', 'Color', 'w', 'Position', [50, 50, 1100, 750]);

% Gráfico 1: Posición Real vs Estimada por Kalman
subplot(2,2,1);
plot(t, theta_C_true, 'k--', 'LineWidth', 1.5); hold on;
plot(t, thetaC_kf, 'b-', 'LineWidth', 1.5);
if system_fault, xline(fault_time, 'r--', 'Falla', 'LineWidth', 1.5); end
ylabel('\theta_C (rad)'); title('Posición Inercia C: Real vs Estimada');
legend('Real', 'Kalman (IMU)', 'Location', 'best'); grid on;

% Gráfico 2: Velocidad Angular Real vs Estimada
subplot(2,2,2);
plot(t, omega_C_true, 'k--', 'LineWidth', 1.2); hold on;
plot(t, omegaC_kf, 'r-', 'LineWidth', 1.2);
ylabel('\omega_C (rad/s)'); title('Velocidad Angular (Muy buena precisión)');
legend('Real', 'Kalman (IMU)', 'Location', 'best'); grid on;

% Gráfico 3: Error de Estimación de Posición
subplot(2,2,3);
plot(t, pos_error, 'm-', 'LineWidth', 1.5);
ylabel('Error (rad)'); xlabel('Tiempo (s)');
title('Deriva Acumulada de Posición (Random Walk)');
grid on;

% Gráfico 4: Señales de Control / Torques Aplicados
subplot(2,2,4);
plot(t, T_A_true, 'b-', 'LineWidth', 1.2); hold on;
plot(t, T_B_true, 'g-', 'LineWidth', 1.2);
ylabel('Torque (Nm)'); xlabel('Tiempo (s)');
title('Torques en los Motores A y B');
legend('T_A (Referencia)', 'T_B (PID Ciego)', 'Location', 'best'); grid on;

%% ANÁLISIS DE OBSERVABILIDAD MATEMÁTICA
% Extraemos la matriz de transición de estados discreta (Adk) y la matriz H
% (Usaremos la parte lineal principal de 8 estados para simplificar el análisis analítico)
A_obs = Adk(1:8, 1:8);
H_obs = H_imu(:, 1:8);

% Construcción de la matriz de observabilidad de Kalman: O = [H; H*A; H*A^2; ...; H*A^(n-1)]
O_matrix = obsv(A_obs, H_obs);

% Cálculo del rango
n_states = size(A_obs, 1);
rank_O = rank(O_matrix);

fprintf('\n=========================================\n');
fprintf('     ANÁLISIS TEÓRICO DE OBSERVABILIDAD  \n');
fprintf('=========================================\n');
fprintf('Número total de estados analizados : %d\n', n_states);
fprintf('Rango de la matriz de observabilidad: %d\n', rank_O);
if rank_O < n_states
    fprintf('>> CONCLUSIÓN: El sistema es NO OBSERVABLE.\n');
    fprintf('Faltan %d estados por ser observados (las posiciones absolutas).\n', n_states - rank_O);
else
    fprintf('>> CONCLUSIÓN: El sistema es completamente observable.\n');
end
fprintf('=========================================\n\n');