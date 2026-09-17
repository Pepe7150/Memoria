% =========================================================================
% SIMULACIÓN COMPLETA: SISTEMA DE 3 INERCIAS CON DERIVA TÉRMICA Y KALMAN
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
bw_encoder      = 500;
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

fprintf('=== PERFIL Y DERIVA TÉRMICA (LAZO ABIERTO) ===\n');
fprintf('Vector de tiempo (N): %d muestras (dt = %.4f s)\n', N, dt_sim);
fprintf('Torque de referencia final: %.2f Nm\n', T_A_ref(end));
fprintf('Kt_A nominal: %.4f Nm/A | Kt_A final degradado: %.4f Nm/A\n', Kt_A, Kt_A_actual(end));
fprintf('Torque real final aplicado (con deriva): %.4f Nm\n\n', T_A_true(end));


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

% Reinicio de vectores para el lazo cerrado
x6 = zeros(6, N);
I_A_true = zeros(N,1); T_A_true = zeros(N,1); 
I_B_true = zeros(N,1); T_B_true = zeros(N,1);
heatA = zeros(N,1); heatB = zeros(N,1);
I_A_rated = 4.0/Kt_A; I_B_rated = 3.0/Kt_B;
kt_drift_B = 0.08;

% --- FILTRO DE KALMAN (12 estados) ---
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
tau_imu_c = 1/(2*pi*bw_imu); 
tau_sg_c = 1/(2*pi*bw_strain);
Ac12(11,4) = 1/tau_imu_c; 
Ac12(11,11) = -1/tau_imu_c;
Ac12(12,1) = k1/tau_sg_c;
Ac12(12,3) = -k1/tau_sg_c;
Ac12(12,2) = c1/tau_sg_c; 
Ac12(12,4) = -c1/tau_sg_c; 
Ac12(12,12) = -1/tau_sg_c;
Adk = expm(Ac12*dt_sim);

H = zeros(6,nx); 
H(1,1) = 1; H(2,5) = 1; 
H(3,7) = 1; H(3,9) = 1;   
H(4,8) = 1; H(4,10) = 1;  
H(5,11) = 1; H(6,12) = 1; 

noise_encoder_std = 0.001; noise_current_std = 0.03;
noise_gyro_std = 0.02; noise_strain_std = 0.005;

tau_enc = 1/(2*pi*bw_encoder); alpha_enc = dt_sim/(tau_enc+dt_sim);
tau_cs = 1/(2*pi*bw_current_filt); alpha_cs = dt_sim/(tau_cs+dt_sim);
tau_imu = 1/(2*pi*bw_imu); alpha_imu = dt_sim/(tau_imu+dt_sim);
tau_sg = 1/(2*pi*bw_strain); alpha_sg = dt_sim/(tau_sg+dt_sim);

var_enc = noise_encoder_std^2 * alpha_enc/(2-alpha_enc);
var_IA = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_imu = noise_gyro_std^2 * alpha_imu/(2-alpha_imu);
var_sg = noise_strain_std^2 * alpha_sg/(2-alpha_sg);

R = diag([var_enc, var_enc, (Kt_A^2)*var_IA, (Kt_B^2)*var_IA, var_imu, var_sg]);
Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, 0.01*dt_sim, 0.01*dt_sim, 1e-5*dt_sim, 1e-5*dt_sim, 1e-8, 1e-8]);

x_est = zeros(nx,1);
P = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, 10, 10, 1, 1, 1, 1]);

X_hist = zeros(nx, N);
thetaA_meas = zeros(N,1); thetaB_meas = zeros(N,1);
TA_current_est = zeros(N,1); TB_current_est = zeros(N,1);
omegaC_meas = zeros(N,1); SG_meas = zeros(N,1);
T_A_cmd = zeros(N,1);

IA_meas = 0; IB_meas = 0; 

Kp_pos = 15; Ki_pos = 50; Kd_pos = 2.0; 
integral_max = 10; theta_C_target = 0.2; theta_err_int = 0;


%% LIMITES DE SEGURIDAD (FAIL SAFES)
max_angle_rad = 135 * (pi / 180);       % +/- 135 grados
max_speed_rads = 1000 * (2*pi / 60);    % 1000 RPM (Límite angular absoluto)
max_torque_Nm = 8.0;                    % 8 Nm (Límite para torque aplicado y transmitido)
system_fault = false;
fault_time = NaN;


%% 4. BUCLE EN TIEMPO REAL (Simulación Lazo Cerrado)
for i = 2:N
    
    % --- VERIFICACIÓN DE SEGURIDAD ---
    if ~system_fault
        % Torques transmitidos mecánicamente en la iteración anterior
        T_AC_prev = k1*(x6(1,i-1)-x6(3,i-1)) + c1*(x6(2,i-1)-x6(4,i-1));
        T_CB_prev = k2*(x6(3,i-1)-x6(5,i-1)) + c2*(x6(4,i-1)-x6(6,i-1));
        
        % Revisamos ángulos, velocidades y todos los torques (eléctricos y mecánicos)
        if abs(x6(1,i-1)) >= max_angle_rad || abs(x6(5,i-1)) >= max_angle_rad || ...
           abs(x6(2,i-1)) >= max_speed_rads || abs(x6(6,i-1)) >= max_speed_rads || ...
           abs(T_A_true(i-1)) >= max_torque_Nm || abs(T_B_true(i-1)) >= max_torque_Nm || ...
           abs(T_AC_prev) >= max_torque_Nm || abs(T_CB_prev) >= max_torque_Nm
       
            system_fault = true;
            fault_time = t(i);
        end
    end

    % --- LÓGICA DE CONTROL VS FALLA ---
    if system_fault
        T_A_cmd(i) = 0;
        I_A_ref_i = 0;
        T_B_cmd_i = 0;
        I_B_ref_i = 0;
    else
        % Control Motor A (Feedforward + Compensación)
        biasA_estimado = x_est(9); 
        T_A_cmd(i) = T_A_ref(i) + biasA_estimado; 
        I_A_ref_i = T_A_cmd(i) / Kt_A;
        
        % Control Motor B (Lazo Cerrado PID)
        theta_err = theta_C_target - x6(3,i-1);
        theta_err_int = max(min(theta_err_int + dt_sim*theta_err, integral_max), -integral_max);
        T_B_cmd_i = -(Kp_pos*theta_err + Ki_pos*theta_err_int + Kd_pos*(0 - x6(4,i-1)));
        I_B_ref_i = T_B_cmd_i / Kt_B;
    end
    
    % Dinámica compartida (funciona igual ya sea control activo o cortado a 0)
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref_i - I_A_true(i-1));
    heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i)/I_A_rated)^2 - heatA(i-1));
    Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA(i));
    T_A_true(i) = Kt_A_actual * I_A_true(i);

    I_B_true(i) = I_B_true(i-1) + alpha_drv*(I_B_ref_i - I_B_true(i-1));
    heatB(i) = heatB(i-1) + alpha_th*((I_B_true(i)/I_B_rated)^2 - heatB(i-1));
    Kt_B_actual = Kt_B * (1 - kt_drift_B*heatB(i));
    T_B_true(i) = Kt_B_actual * I_B_true(i);

    u_plant = [T_A_true(i); T_B_true(i)];

    % Avance de la Planta Física
    x6(:,i) = Ad6*x6(:,i-1) + Bd6*u_plant; 
    
    theta_A_true_i = x6(1,i); omega_A_true_i = x6(2,i);
    theta_C_true_i = x6(3,i); omega_C_true_i = x6(4,i);
    theta_B_true_i = x6(5,i); omega_B_true_i = x6(6,i);
    T_AC_true_i = k1*(theta_A_true_i-theta_C_true_i) + c1*(omega_A_true_i-omega_C_true_i);

    % Sensores (Ruido + Filtro Digital)
    thA_raw = theta_A_true_i + noise_encoder_std*randn;
    thB_raw = theta_B_true_i + noise_encoder_std*randn;
    thetaA_meas(i) = thetaA_meas(i-1) + alpha_enc*(thA_raw - thetaA_meas(i-1));
    thetaB_meas(i) = thetaB_meas(i-1) + alpha_enc*(thB_raw - thetaB_meas(i-1));

    IA_raw = I_A_true(i) + noise_current_std*randn;
    IB_raw = I_B_true(i) + noise_current_std*randn;
    IA_meas = IA_meas + alpha_cs*(IA_raw - IA_meas);
    IB_meas = IB_meas + alpha_cs*(IB_raw - IB_meas);
    TA_current_est(i) = Kt_A * IA_meas;
    TB_current_est(i) = Kt_B * IB_meas;

    wC_raw = omega_C_true_i + noise_gyro_std*randn;
    omegaC_meas(i) = omegaC_meas(i-1) + alpha_imu*(wC_raw - omegaC_meas(i-1));

    SG_raw = T_AC_true_i + noise_strain_std*randn;
    SG_meas(i) = SG_meas(i-1) + alpha_sg*(SG_raw - SG_meas(i-1));

    % Filtro de Kalman
    x_pred = Adk*x_est;
    P_pred = Adk*P*Adk' + Q;
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

biasA_true = TA_current_est - T_A_true;
biasB_true = TB_current_est - T_B_true;

fprintf('=== SIMULACIÓN CON COMPENSACIÓN DE KALMAN CONCLUIDA ===\n');
fprintf('Torque de referencia solicitado: %.2f Nm\n', T_A_ref(end));
fprintf('Torque real entregado por Motor A: %.4f Nm (Lazo cerrado compensado)\n', T_A_true(end));
fprintf('Sesgo térmico estimado por Kalman: %.4f Nm\n\n', biasA_kf(end));


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

% Figura 3: Cinemática
figure('Name', 'Cinemática Disco C', 'Color', 'w', 'Position', [90,90,950,700]);
subplot(2,1,1);
plot(t, theta_C_true, 'k--', 'LineWidth', 2); hold on; plot(t, thetaC_kf, 'b', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('\theta_C (rad)'); grid on; xlim([0 T_sim]); legend('Real', 'Kalman', 'Location', 'best');
subplot(2,1,2);
plot(t, omega_C_true, 'k--', 'LineWidth', 2); hold on;
plot(t, omegaC_meas, 'm', 'LineWidth', 1); plot(t, omegaC_kf, 'b', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('\omega_C (rad/s)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]); legend('Real', 'IMU', 'Kalman');

% Métricas
rmse = @(e) sqrt(mean(e.^2));
mejora = @(rmse_crudo, rmse_kf) ((rmse_crudo - rmse_kf)/rmse_crudo)*100;

fprintf('=== MÉTRICAS DE DESEMPEÑO ===\n');
fprintf('T_A - RMSE corriente: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse(TA_current_est - T_A_true), rmse(T_A_kf - T_A_true), mejora(rmse(TA_current_est - T_A_true), rmse(T_A_kf - T_A_true)));
fprintf('T_B - RMSE corriente: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse(TB_current_est - T_B_true), rmse(T_B_kf - T_B_true), mejora(rmse(TB_current_est - T_B_true), rmse(T_B_kf - T_B_true)));
fprintf('--- Torque Transmitido ---\n');
fprintf('T_AC - RMSE strain: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse(SG_meas - T_AC_true), rmse(T_AC_kf - T_AC_true), mejora(rmse(SG_meas - T_AC_true), rmse(T_AC_kf - T_AC_true)));
fprintf('T_CB - RMSE Kalman (sin sensor): %.4f Nm\n', rmse(T_CB_kf - T_CB_true));
fprintf('==============================\n\n');

fprintf('=== EVALUACIÓN DE ANCHO DE BANDA ===\n');
bw_ctrl_loop = sqrt(Kp_pos/J_B)/(2*pi);
fprintf('Ancho de banda del lazo de control de B: %.2f Hz\n', bw_ctrl_loop);

if bw_driver > 5*bw_ctrl_loop
    fprintf('>> OK: Driver (%d Hz) > 5x ancho de banda de control (%.2f Hz).\n', bw_driver, bw_ctrl_loop);
else
    fprintf('>> ALERTA: Driver (%d Hz) podría limitar el control.\n', bw_driver);
end

if bw_encoder > 5*fn1
    fprintf('>> OK: Encoders (%d Hz) resuelven fn1 (BW > 5x fn1).\n', bw_encoder);
else
    fprintf('>> ALERTA: Encoders (%d Hz) podrían no resolver fn1.\n', bw_encoder);
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
    fprintf('Causa: Se superó un límite crítico de ángulo, velocidad o torque (%.1f Nm).\n', max_torque_Nm);
else
    fprintf('Estado: OK. No se detectaron violaciones a los límites angulares, cinemáticos ni de torque.\n');
end
fprintf('=====================================================\n');