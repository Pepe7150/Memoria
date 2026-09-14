function simulacion_torsion_dual_motor()
% simulacion_torsion_dual_motor.m
%
% Banco de dos motores antagónicos acoplados por un eje torsional:
% Motor A aplica una carga (ej. equivalente aerodinámica), Motor B la
% resiste/vence (actuador bajo prueba). Se estima el torque que ejerce
% CADA motor por separado, no solo el torque transmitido por el eje.
%
% Instrumentación (3 fuentes independientes -> observabilidad completa):
%   1. Strain gauge en el eje de acople -> mide el torque transmitido k*theta
%   2. Gyro/IMU en cada rotor           -> mide omega_A y omega_B por separado
%   3. Sensor de corriente en cada motor -> T = Kt*I (modelo de motor)
%
% Filtro de Kalman, 5 estados: x = [theta; omega_A; omega_B; T_A; T_B]
% (theta = torsión relativa del acople = theta_A - theta_B)
% Sin análisis espectral/FFT; se mantiene la regla heurística de ancho
% de banda como único criterio de evaluación adicional.

clc; clear; close all;

%% 1. PARÁMETROS MECÁNICOS
% Eje de acople entre los dos motores (Acero A36)
d = 0.005; L = 0.15; G = 79.3e9;
J_polar = (pi * d^4) / 32;
k_torsion = (G * J_polar) / L;    % Rigidez torsional del acople [Nm/rad]
c_amort   = 0.05;                 % Amortiguamiento viscoso del acople [Nms/rad]

% Inercias de cada lado (rotor de cada motor + su parte del acople)
J_A = 4e-4;   % Motor A: aplica la carga [kg*m^2]
J_B = 3e-4;   % Motor B: actuador que resiste/vence [kg*m^2]

J_red = (J_A*J_B)/(J_A+J_B);                       % Inercia reducida del modo de torsión
fn_twist = sqrt(k_torsion*(1/J_A + 1/J_B))/(2*pi);  % Frecuencia natural del modo relativo [Hz]
zeta_twist = c_amort/(2*sqrt(k_torsion*J_red));     % Razón de amortiguamiento de ese modo

fprintf('=== PARÁMETROS MECÁNICOS (2 motores antagónicos) ===\n');
fprintf('Rigidez del acople (k):     %.2f Nm/rad\n', k_torsion);
fprintf('Inercia Motor A (J_A):      %.6f kg*m^2\n', J_A);
fprintf('Inercia Motor B (J_B):      %.6f kg*m^2\n', J_B);
fprintf('Frecuencia natural (modo torsión relativa): %.2f Hz\n', fn_twist);
fprintf('Razón de amortig. de ese modo: %.4f\n', zeta_twist);
fprintf('======================================================\n\n');

%% 2. PARÁMETROS DE HARDWARE Y ANCHOS DE BANDA
bw_driver       = 200;   % Lazo de corriente de los drivers (ambos motores) [Hz]
bw_strain       = 30;    % Strain gauge del acople [Hz]
bw_imu          = 150;   % Gyro de cada rotor [Hz]
bw_current_filt = 500;   % Filtro del sensor de corriente [Hz]

Kt_A = 0.06;   % Constante de torque Motor A [Nm/A]
Kt_B = 0.05;   % Constante de torque Motor B [Nm/A]

%% 3. CONFIGURACIÓN TEMPORAL Y PERFILES DE TORQUE DE REFERENCIA
fs_sim = 5000; dt_sim = 1/fs_sim; T_sim = 5;
t = (0:dt_sim:T_sim-dt_sim)'; N = length(t);

f_test = 0.75 * fn_twist;   % Frecuencia de prueba cercana (no encima) del modo de torsión

% Motor A: aplica la carga (escalón rápido + perturbación de prueba)
T_A_ref = ones(N,1) * 0.5;
idx_step = floor(N*0.2);
T_A_ref(idx_step:end) = 4.0;
T_A_ref = T_A_ref + 0.3*sin(2*pi*f_test*t);

% Motor B: actuador que resiste/vence (rampa más lenta + perturbación desfasada)
T_B_ref = ones(N,1) * 0.3;
idx_r1 = floor(N*0.3); idx_r2 = floor(N*0.6);
T_B_ref(idx_r1:idx_r2) = linspace(0.3, 3.0, idx_r2-idx_r1+1)';
T_B_ref(idx_r2:end) = 3.0;
T_B_ref = T_B_ref + 0.15*sin(2*pi*f_test*t + pi/4);

fprintf('Frecuencia de excitación de prueba: %.2f Hz (0.75*fn_twist)\n\n', f_test);

%% 4. TORQUE REAL APLICADO POR CADA MOTOR (vía corriente real, limitada por el driver)
I_A_ref = T_A_ref / Kt_A;  I_B_ref = T_B_ref / Kt_B;

tau_drv = 1/(2*pi*bw_driver);
alpha_drv = dt_sim / (tau_drv + dt_sim);

I_A_true = zeros(N,1); I_B_true = zeros(N,1);
for i = 2:N
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref(i) - I_A_true(i-1));
    I_B_true(i) = I_B_true(i-1) + alpha_drv*(I_B_ref(i) - I_B_true(i-1));
end
T_A_true = Kt_A * I_A_true;   % Torque real que efectivamente entrega el Motor A
T_B_true = Kt_B * I_B_true;   % Torque real que efectivamente entrega el Motor B

%% 5. DINÁMICA MECÁNICA REAL (sistema de dos masas acopladas)
% theta = theta_A - theta_B (torsión relativa del acople)
% J_A*omega_A' = T_A - (k*theta + c*(omega_A-omega_B))
% J_B*omega_B' = (k*theta + c*(omega_A-omega_B)) - T_B
Ac3 = [0, 1, -1;
      -k_torsion/J_A, -c_amort/J_A,  c_amort/J_A;
       k_torsion/J_B,  c_amort/J_B, -c_amort/J_B];
Bc3 = [0, 0; 1/J_A, 0; 0, -1/J_B];
Ad3 = eye(3) + Ac3*dt_sim;
Bd3 = Bc3*dt_sim;

x3 = zeros(3, N);  % [theta; omega_A; omega_B]
for i = 2:N
    x3(:,i) = Ad3*x3(:,i-1) + Bd3*[T_A_true(i); T_B_true(i)];
end
theta_true   = x3(1,:)';
omega_A_true = x3(2,:)';
omega_B_true = x3(3,:)';
T_transmitido_true = k_torsion*theta_true + c_amort*(omega_A_true - omega_B_true);

%% 6. GENERACIÓN DE SEÑALES DE SENSORES

% 6.1 Strain gauge en el acople -> mide k*theta
noise_strain_std = 0.05;
SG_raw = k_torsion*theta_true + noise_strain_std*randn(N,1);
tau_sg = 1/(2*pi*bw_strain); alpha_sg = dt_sim/(tau_sg+dt_sim);
SG_meas = zeros(N,1);
for i = 2:N
    SG_meas(i) = SG_meas(i-1) + alpha_sg*(SG_raw(i) - SG_meas(i-1));
end

% 6.2 Gyro en cada rotor -> mide omega_A y omega_B directamente
noise_gyro_std = 0.02;   % rad/s
tau_imu = 1/(2*pi*bw_imu); alpha_imu = dt_sim/(tau_imu+dt_sim);

wA_raw = omega_A_true + noise_gyro_std*randn(N,1);
wB_raw = omega_B_true + noise_gyro_std*randn(N,1);
omegaA_meas = zeros(N,1); omegaB_meas = zeros(N,1);
for i = 2:N
    omegaA_meas(i) = omegaA_meas(i-1) + alpha_imu*(wA_raw(i) - omegaA_meas(i-1));
    omegaB_meas(i) = omegaB_meas(i-1) + alpha_imu*(wB_raw(i) - omegaB_meas(i-1));
end

% 6.3 Sensor de corriente en cada motor -> T = Kt*I (modelo de motor)
noise_current_std = 0.03;  % A
tau_cs = 1/(2*pi*bw_current_filt); alpha_cs = dt_sim/(tau_cs+dt_sim);

IA_raw = I_A_true + noise_current_std*randn(N,1);
IB_raw = I_B_true + noise_current_std*randn(N,1);
IA_filt = zeros(N,1); IB_filt = zeros(N,1);
for i = 2:N
    IA_filt(i) = IA_filt(i-1) + alpha_cs*(IA_raw(i) - IA_filt(i-1));
    IB_filt(i) = IB_filt(i-1) + alpha_cs*(IB_raw(i) - IB_filt(i-1));
end
TA_current_est = Kt_A * IA_filt;   % Estimación de T_A solo por corriente+modelo
TB_current_est = Kt_B * IB_filt;   % Estimación de T_B solo por corriente+modelo

%% 7. FILTRO DE KALMAN DE 5 ESTADOS
% x = [theta; omega_A; omega_B; T_A; T_B]
% Modelo de proceso: la parte mecánica (theta, omega_A, omega_B) es la
% ecuación de Newton exacta del sistema de dos masas; T_A y T_B se
% modelan como paseo aleatorio porque no se conocen a priori (para eso
% están las mediciones de corriente).
%
% Cada sensor mide exactamente el estado que le corresponde físicamente:
%   SG      -> k*theta                 (torque transmitido)
%   Gyro A  -> omega_A
%   Gyro B  -> omega_B
%   Corr. A -> T_A  (vía Kt_A*I_A, con su propio ruido/incertidumbre)
%   Corr. B -> T_B  (vía Kt_B*I_B, con su propio ruido/incertidumbre)
% Esto separa T_A y T_B: cada uno se ve directamente en su propio canal
% de corriente, y la mecánica (SG + gyros) sirve para corregir/filtrar
% el ruido y el sesgo del modelo de corriente de cada motor.

Ac5 = [0, 1, -1, 0, 0;
      -k_torsion/J_A, -c_amort/J_A,  c_amort/J_A, 1/J_A, 0;
       k_torsion/J_B,  c_amort/J_B, -c_amort/J_B, 0, -1/J_B;
       0, 0, 0, 0, 0;
       0, 0, 0, 0, 0];
Adk = eye(5) + Ac5*dt_sim;

H = [k_torsion, 0, 0, 0, 0;    % Strain gauge
     0, 1, 0, 0, 0;            % Gyro A
     0, 0, 1, 0, 0;            % Gyro B
     0, 0, 0, 1, 0;            % Corriente A
     0, 0, 0, 0, 1];           % Corriente B

var_sg    = noise_strain_std^2  * alpha_sg/(2-alpha_sg);
var_gyro  = noise_gyro_std^2    * alpha_imu/(2-alpha_imu);
var_IA    = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_IB    = var_IA;
R = diag([var_sg, var_gyro, var_gyro, (Kt_A^2)*var_IA, (Kt_B^2)*var_IB]);

% Ruido de proceso: casi nulo en la parte mecánica (el modelo es exacto),
% densidad ajustable en T_A/T_B (qué tan rápido puede cambiar el torque
% real de cada motor entre pasos -- súbelo si el filtro reacciona lento).
q_mec = 1e-10;
q_TA_density = 400; q_TB_density = 400;   % [Nm^2/s]
Q = diag([q_mec, q_mec, q_mec, q_TA_density*dt_sim, q_TB_density*dt_sim]);

fprintf('=== SINTONÍA DEL KALMAN (5 estados) ===\n');
fprintf('R strain gauge:  %.3e Nm^2\n', R(1,1));
fprintf('R gyro (A y B):  %.3e (rad/s)^2\n', var_gyro);
fprintf('R corriente A:   %.3e Nm^2\n', R(4,4));
fprintf('R corriente B:   %.3e Nm^2\n', R(5,5));
fprintf('Q torque A/B:    %.3e Nm^2 por paso\n', Q(4,4));
fprintf('=========================================\n\n');

x_est = zeros(5,1);
P = diag([1e-4, 1, 1, 10, 10]);

X_hist = zeros(5, N);
for i = 2:N
    x_pred = Adk*x_est;
    P_pred = Adk*P*Adk' + Q;

    z = [SG_meas(i); omegaA_meas(i); omegaB_meas(i); TA_current_est(i); TB_current_est(i)];
    y_innov = z - H*x_pred;
    S = H*P_pred*H' + R;
    K = (P_pred*H') / S;

    x_est = x_pred + K*y_innov;
    P = (eye(5) - K*H)*P_pred;

    X_hist(:,i) = x_est;
end

T_A_kf = X_hist(4,:)';
T_B_kf = X_hist(5,:)';
theta_kf = X_hist(1,:)';
T_transmitido_kf = k_torsion*theta_kf + c_amort*(X_hist(2,:)' - X_hist(3,:)');

%% 8. RESULTADOS Y GRÁFICOS (sin análisis espectral)
figure('Name', 'Torque por Motor - Dos Motores Antagónicos', 'Color', 'w', ...
       'Position', [80, 80, 1000, 900]);

subplot(3,1,1);
plot(t, T_A_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TA_current_est, 'm', 'LineWidth', 1);
plot(t, T_A_kf, 'b', 'LineWidth', 2);
ylabel('T_A (Nm)'); grid on; xlim([0 T_sim]);
legend('T_A real', 'Solo corriente (Kt \cdot I)', 'Fusión Kalman', 'Location', 'best');
title('Torque del Motor A (carga)');

subplot(3,1,2);
plot(t, T_B_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TB_current_est, 'm', 'LineWidth', 1);
plot(t, T_B_kf, 'r', 'LineWidth', 2);
ylabel('T_B (Nm)'); grid on; xlim([0 T_sim]);
legend('T_B real', 'Solo corriente (Kt \cdot I)', 'Fusión Kalman', 'Location', 'best');
title('Torque del Motor B (actuador)');

subplot(3,1,3);
plot(t, T_transmitido_true, 'k--', 'LineWidth', 2); hold on;
plot(t, SG_meas, 'c', 'LineWidth', 1);
plot(t, T_transmitido_kf, 'g', 'LineWidth', 2);
ylabel('T_{transmitido} (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Strain gauge', 'Fusión Kalman', 'Location', 'best');
title('Torque Transmitido por el Acople');

err_TA_curr = TA_current_est - T_A_true;  err_TA_kf = T_A_kf - T_A_true;
err_TB_curr = TB_current_est - T_B_true;  err_TB_kf = T_B_kf - T_B_true;

rmse_TA_curr = sqrt(mean(err_TA_curr.^2)); rmse_TA_kf = sqrt(mean(err_TA_kf.^2));
rmse_TB_curr = sqrt(mean(err_TB_curr.^2)); rmse_TB_kf = sqrt(mean(err_TB_kf.^2));

fprintf('=== MÉTRICAS DE DESEMPEÑO ===\n');
fprintf('T_A - RMSE solo corriente: %.4f Nm | RMSE fusión: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TA_curr, rmse_TA_kf, ((rmse_TA_curr-rmse_TA_kf)/rmse_TA_curr)*100);
fprintf('T_B - RMSE solo corriente: %.4f Nm | RMSE fusión: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TB_curr, rmse_TB_kf, ((rmse_TB_curr-rmse_TB_kf)/rmse_TB_curr)*100);
fprintf('==============================\n\n');

%% 9. REGLA HEURÍSTICA DE ANCHO DE BANDA
fprintf('=== EVALUACIÓN POR REGLA HEURÍSTICA DE ANCHO DE BANDA ===\n');
fprintf('Frecuencia natural del modo de torsión: %.2f Hz\n', fn_twist);
fprintf('Ancho de Banda Driver (corriente):      %d Hz\n', bw_driver);
fprintf('Ancho de Banda Strain Gauge:             %d Hz\n', bw_strain);
fprintf('Ancho de Banda Gyro (por rotor):         %d Hz\n', bw_imu);
fprintf('Ancho de Banda Filtro de Corriente:      %d Hz\n', bw_current_filt);
fprintf('-----------------------------------------------------------\n');

if bw_driver > 5*fn_twist
    fprintf('>> VIABLE: los drivers pueden imponer dinámica hasta la frecuencia natural (BW > 5*fn).\n');
else
    fprintf('>> ALERTA: los drivers podrían ser lentos frente al modo de torsión (BW <= 5*fn).\n');
end

if bw_strain < fn_twist
    fprintf('>> ALERTA: el strain gauge es demasiado lento para el modo de torsión (BW < fn).\n');
    fprintf('   Justifica apoyarse en los gyros/corriente para la dinámica rápida.\n');
else
    fprintf('>> OK: el strain gauge tiene ancho de banda suficiente (BW >= fn).\n');
end

if bw_imu > 5*fn_twist
    fprintf('>> OK: los gyros tienen ancho de banda de sobra (BW > 5*fn).\n');
else
    fprintf('>> ALERTA: los gyros podrían no ser suficientemente rápidos (BW <= 5*fn).\n');
end

if bw_current_filt > 5*fn_twist
    fprintf('>> OK: el filtro del sensor de corriente no limita la dinámica relevante (BW > 5*fn).\n');
else
    fprintf('>> ALERTA: el filtro de corriente podría estar recortando dinámica útil (BW <= 5*fn).\n');
end
fprintf('=============================================================\n');

end
