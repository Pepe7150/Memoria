%% 1. INICIALIZACIÓN DE MATRICES Y ESTADOS
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
I_A_true = zeros(N,1); 
T_A_true = zeros(N,1); 
I_B_true = zeros(N,1); 
T_B_true = zeros(N,1);
heatA = zeros(N,1); 
heatB = zeros(N,1);
I_A_rated = 4.0/Kt_A; I_B_rated = 3.0/Kt_B;
kt_drift_A = 0.08; kt_drift_B = 0.08;

% =========================================================================
% --- FILTRO DE KALMAN LINEAL CON ESTADO AUMENTADO (12 estados) ---
%
% EXPLICACIÓN DIDÁCTICA: ¿Por qué no es un EKF y dónde está la matriz B?
% 1. NO es un EKF (Kalman Extendido) porque el sistema es estrictamente lineal. 
%    Las matrices A y H son constantes, no hay funciones no lineales (como 
%    seno/coseno) y no se calculan matrices Jacobianas en el bucle en tiempo real.
%
% 2. NO tiene vector de entradas (u) ni matriz (B) en la ecuación de predicción
%    porque utiliza la técnica de "Aumento de Estado" (State Augmentation).
%    En lugar de confiar en los comandos de los motores (que sufren degradación 
%    térmica), el filtro asume que los torques (T_A, T_B) son estados 
%    desconocidos (estados 7 y 8).
%
% 3. ¿Dónde quedó la matriz B original? 
%    Fíjate en las columnas 7 y 8 de la matriz Ac8. Los términos 1/J_A y -1/J_B 
%    (que en la planta física Bc6 multiplicaban a las entradas) ahora están 
%    DENTRO de la matriz de transición del sistema A, multiplicando a los nuevos 
%    estados de torque estimado.
% =========================================================================

Ac8 = [0, 1, 0, 0, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0, 1/J_A, 0; % <-- 1/J_A absorbe a T_A
       0, 0, 0, 1, 0, 0, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C, 0, 0;
       0, 0, 0, 0, 0, 1, 0, 0;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B, 0, -1/J_B; % <-- -1/J_B absorbe a T_B
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

%12 Estados: 1 al 6 theta y omega de cada disco, 7 y 8 torques estimados
%(entradas), 9 y 10 sesgos térmicos de los motores, 11 y 12 modelos de IMU
%y SG.

H = zeros(6,nx); % Matriz de observación
H(1,1) = 1;  % Mide theta_A (Encoder A)
H(2,5) = 1;  % Mide theta_B (Encoder B)
H(3,7) = 1;
H(3,9) = 1;   % Sensor de corriente A = Torque A + Bias A
H(4,8) = 1;
H(4,10) = 1;  % Sensor de corriente B = Torque B + Bias B
H(5,11) = 1; % Mide omega_C filtrada por la IMU
H(6,12) = 1; % Mide T_AC filtrado por el Strain Gauge

% === DEFINICIÓN EXPLICATIVA DEL RUIDO (Q y R) ===
noise_encoder_std = 0.001; 
noise_current_std = 0.03;
noise_gyro_std = 0.02;
noise_strain_std = 0.005;

tau_enc = 1/(2*pi*bw_encoder); 
alpha_enc = dt_sim/(tau_enc+dt_sim);
tau_cs = 1/(2*pi*bw_current_filt);
alpha_cs = dt_sim/(tau_cs+dt_sim);
tau_imu = 1/(2*pi*bw_imu); 
alpha_imu = dt_sim/(tau_imu+dt_sim);
tau_sg = 1/(2*pi*bw_strain); 
alpha_sg = dt_sim/(tau_sg+dt_sim);

var_enc = noise_encoder_std^2 * alpha_enc/(2-alpha_enc);
var_IA = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_imu = noise_gyro_std^2 * alpha_imu/(2-alpha_imu);
var_sg = noise_strain_std^2 * alpha_sg/(2-alpha_sg);

% Matriz R: Ruido de Medida. Indica cuánto confiamos en cada sensor físico.
R = diag([var_enc, var_enc, (Kt_A^2)*var_IA, (Kt_B^2)*var_IA, var_imu, var_sg]);

% Matriz Q: Ruido de Proceso. Indica cuánto confiamos en la física teórica (Adk).
% Nota didáctica: Los valores muy bajos (1e-10) obligan al filtro a creer en 
% la cinemática rígida. Los valores más altos (0.01*dt_sim) en los torques y 
% sesgos permiten al filtro "aprender" la degradación térmica asumiendo que 
% el modelo matemático ahí es imperfecto.
Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, 0.01*dt_sim, 0.01*dt_sim, 1e-5*dt_sim, 1e-5*dt_sim, 1e-8, 1e-8]);

x_est = zeros(nx,1);
P = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, 10, 10, 1, 1, 1, 1]);

% Vectores de memoria y variables iniciales
X_hist = zeros(nx, N);
thetaA_meas = zeros(N,1);
thetaB_meas = zeros(N,1);
TA_current_est = zeros(N,1);
TB_current_est = zeros(N,1);
omegaC_meas = zeros(N,1); 
SG_meas = zeros(N,1);
T_A_cmd = zeros(N,1);

IA_meas = 0; 
IB_meas = 0; 

% Parámetros PID Motor B
Kp_pos = 150;
Ki_pos = 50; 
Kd_pos = 2.0; 
integral_max = 10; 
theta_C_target = 0.2; 
theta_err_int = 0;

%% 2. BUCLE EN TIEMPO REAL (Simulación + Sensores + Kalman + Realimentación)
for i = 2:N
    
    % === A) ACCIONES DE CONTROL (Señales u enviadas a los motores) ===
    
    % Control Motor A (Feedforward + Compensación Térmica de Kalman)
    biasA_estimado = x_est(9); 
    T_A_cmd(i) = T_A_ref(i) + biasA_estimado; 
    I_A_ref_i = T_A_cmd(i) / Kt_A;
    
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref_i - I_A_true(i-1));
    heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i)/I_A_rated)^2 - heatA(i-1));
    Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA(i));
    T_A_true(i) = Kt_A_actual * I_A_true(i);

    % Control Motor B (Lazo Cerrado PID usando el estado de C)
    theta_err = theta_C_target - x6(3,i-1);
    theta_err_int = max(min(theta_err_int + dt_sim*theta_err, integral_max), -integral_max);
    T_B_cmd_i = -(Kp_pos*theta_err + Ki_pos*theta_err_int + Kd_pos*(0 - x6(4,i-1)));

    I_B_ref_i = T_B_cmd_i / Kt_B;
    I_B_true(i) = I_B_true(i-1) + alpha_drv*(I_B_ref_i - I_B_true(i-1));
    heatB(i) = heatB(i-1) + alpha_th*((I_B_true(i)/I_B_rated)^2 - heatB(i-1));
    Kt_B_actual = Kt_B * (1 - kt_drift_B*heatB(i));
    T_B_true(i) = Kt_B_actual * I_B_true(i);

    % Variable 'u_plant' explícita para la matriz B de la planta física
    u_plant = [T_A_true(i); T_B_true(i)];

    % === B) AVANCE DE LA PLANTA FÍSICA ===
    % Ecuación: X_{k} = A * X_{k-1} + B * U_{k}
    x6(:,i) = Ad6*x6(:,i-1) + Bd6*u_plant; 
    
    theta_A_true_i = x6(1,i); 
    omega_A_true_i = x6(2,i);
    theta_C_true_i = x6(3,i);
    omega_C_true_i = x6(4,i);
    theta_B_true_i = x6(5,i);
    omega_B_true_i = x6(6,i);
    T_AC_true_i = k1*(theta_A_true_i-theta_C_true_i) + c1*(omega_A_true_i-omega_C_true_i);

    % === C) LECTURA DE SENSORES Y SALIDAS (Vector z) ===
    % Captura de la física real + ruido blanco + filtro digital pasa-bajas

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

    % === D) ACTUALIZACIÓN FILTRO DE KALMAN ===
    % 1. Predicción a priori
    x_pred = Adk*x_est;
    P_pred = Adk*P*Adk' + Q;

    % 2. Conformación del vector de observaciones (z)
    z = [thetaA_meas(i); thetaB_meas(i); TA_current_est(i); TB_current_est(i); omegaC_meas(i); SG_meas(i)];
         
    % 3. Corrección a posteriori (Innovación)
    y_innov = z - H*x_pred;
    S = H*P_pred*H' + R;
    K = (P_pred*H') / S;

    x_est = x_pred + K*y_innov;
    P = (eye(nx) - K*H)*P_pred;
    X_hist(:,i) = x_est;
end

%% 3. EXTRAER ESTADOS ESTIMADOS Y CÁLCULOS DERIVADOS
% Extraer estados del Kalman

thetaA_kf = X_hist(1,:)';
omegaA_kf = X_hist(2,:)';
thetaC_kf = X_hist(3,:)';
omegaC_kf = X_hist(4,:)';
thetaB_kf = X_hist(5,:)';
omegaB_kf = X_hist(6,:)';
T_A_kf    = X_hist(7,:)';
T_B_kf    = X_hist(8,:)';
biasA_kf  = X_hist(9,:)';
biasB_kf  = X_hist(10,:)';

% Calcular torques transmitidos estimados por Kalman
T_AC_kf = k1*(thetaA_kf-thetaC_kf) + c1*(omegaA_kf-omegaC_kf);
T_CB_kf = k2*(thetaC_kf-thetaB_kf) + c2*(omegaC_kf-omegaB_kf);

% Extraer estados reales de la planta física (para métricas y gráficos)
theta_C_true = x6(3,:)';
omega_C_true = x6(4,:)';
T_AC_true = k1*(x6(1,:)'-x6(3,:)') + c1*(x6(2,:)'-x6(4,:)');
T_CB_true = k2*(x6(3,:)'-x6(5,:)') + c2*(x6(4,:)'-x6(6,:)');

% Calcular sesgos reales
biasA_true = TA_current_est - T_A_true;
biasB_true = TB_current_est - T_B_true;

fprintf('=== SIMULACIÓN CON COMPENSACIÓN DE KALMAN CONCLUIDA ===\n');
fprintf('Torque de referencia solicitado: %.2f Nm\n', T_A_ref(end));
fprintf('Torque real entregado por Motor A: %.4f Nm (Lazo cerrado compensado)\n', T_A_true(end));
fprintf('Sesgo térmico estimado por Kalman: %.4f Nm\n', biasA_kf(end));