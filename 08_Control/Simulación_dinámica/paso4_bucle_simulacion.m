% =========================================================================
% SCRIPT 4: BUCLE CERRADO DE TIEMPO REAL, CONTROL PID Y FILTRO DE KALMAN
% =========================================================================

% --- Inicialización de Vectores de Estado ---
x6 = zeros(6, N);

% Inicializamos variables de ambos motores para el bucle
I_A_true = zeros(N,1); T_A_true = zeros(N,1); heatA = zeros(N,1);
I_B_true = zeros(N,1); T_B_true = zeros(N,1); heatB = zeros(N,1);

I_A_rated = 4.0 / Kt_A;  kt_drift_A = 0;
I_B_rated = 3.0 / Kt_B;  kt_drift_B = 0;

x_est = zeros(nx,1);
X_hist = zeros(nx, N);
thetaA_meas = zeros(N,1); thetaB_meas = zeros(N,1);
TA_current_est = zeros(N,1); TB_current_est = zeros(N,1);
omegaC_meas = zeros(N,1); SG_meas = zeros(N,1);
T_A_cmd = zeros(N,1); IA_meas = 0; IB_meas = 0; 

% --- Inicialización de Sesgos Dinámicos Reales (Proceso Ornstein-Uhlenbeck) ---
bias_currentA_true = zeros(N,1); bias_currentA_true(1) = bias_currentA_0;
bias_currentB_true = zeros(N,1); bias_currentB_true(1) = bias_currentB_0;
bias_imu_true      = zeros(N,1); bias_imu_true(1)      = bias_imu_0;
bias_sg_true       = zeros(N,1); bias_sg_true(1)       = bias_sg_0;

% Pre-cálculo de factores para la simulación discreta exacta de Ornstein-Uhlenbeck
exp_IA  = exp(-dt_sim / tau_b_IA);  std_OU_IA  = sigma_b_IA  * sqrt(1 - exp(-2*dt_sim / tau_b_IA));
exp_IB  = exp(-dt_sim / tau_b_IB);  std_OU_IB  = sigma_b_IB  * sqrt(1 - exp(-2*dt_sim / tau_b_IB));
exp_imu = exp(-dt_sim / tau_b_imu); std_OU_imu = sigma_b_imu * sqrt(1 - exp(-2*dt_sim / tau_b_imu));
exp_sg  = exp(-dt_sim / tau_b_sg);  std_OU_sg  = sigma_b_sg  * sqrt(1 - exp(-2*dt_sim / tau_b_sg));

% --- Parámetros de Control PID para Motor B ---
Kp_pos = 1; Ki_pos = 5; Kd_pos = 0.5; 
integral_max = 10; theta_C_target = 0; theta_err_int = 0;

% --- Límites de Seguridad (Fail Safes) ---
max_angle_rad = 135 * (pi / 180);       
max_speed_rads = 1000 * (2*pi / 60);    
max_torque_Nm = 8.0;                    
system_fault = false; fault_time = NaN; fault_reason = '';

% --- BUCLE DE SIMULACIÓN ---
for i = 2:N
    % 1. Verificación de Lógicas de Seguridad
    if ~system_fault
        T_trans_prev = C_torque * x6(:,i-1);
        
        if abs(x6(1,i-1)) >= max_angle_rad || abs(x6(5,i-1)) >= max_angle_rad
            system_fault = true; fault_time = t(i);
            fault_reason = 'Límite de ÁNGULO superado (>= 135°)';
        elseif abs(x6(2,i-1)) >= max_speed_rads || abs(x6(6,i-1)) >= max_speed_rads
            system_fault = true; fault_time = t(i);
            fault_reason = 'Límite de VELOCIDAD superado (>= 1000 RPM)';
        elseif abs(T_A_true(i-1)) >= max_torque_Nm || abs(T_B_true(i-1)) >= max_torque_Nm || ...
               abs(T_trans_prev(1)) >= max_torque_Nm || abs(T_trans_prev(2)) >= max_torque_Nm
            system_fault = true; fault_time = t(i);
            fault_reason = sprintf('Límite de TORQUE superado (>= %.1f Nm)', max_torque_Nm);
        end
    end

    % 2. Ley de Control y Actuación
    if system_fault
        T_A_cmd(i) = 0; T_B_cmd_i = 0; 
        T_A_true(i) = 0; I_A_true(i) = 0; 
        I_B_ref_i = 0; 
    else
        % --- MOTOR A: Lazo abierto con compensación de Torque ---
        T_A_cmd(i) = T_A_ref(i); 
        T_A_true(i) = T_A_true(i-1) + alpha_drv*(T_A_cmd(i) - T_A_true(i-1));
        
        heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i-1)/I_A_rated)^2 - heatA(i-1));
        Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA(i));
        I_A_true(i) = T_A_true(i) / Kt_A_actual;
        
        % --- MOTOR B: Control PID de Posición ---
        theta_err = theta_C_target - x_est(3);
        theta_err_int = max(min(theta_err_int + dt_sim*theta_err, integral_max), -integral_max);
        T_B_cmd_i = -(Kp_pos*theta_err + Ki_pos*theta_err_int + Kd_pos*(0 - x_est(4)));
        I_B_ref_i = T_B_cmd_i / Kt_B;
    end
    
    % 3. Integración de Actuador B y Planta
    I_B_true(i) = I_B_true(i-1) + alpha_drv*(I_B_ref_i - I_B_true(i-1));
    heatB(i) = heatB(i-1) + alpha_th*((I_B_true(i)/I_B_rated)^2 - heatB(i-1));
    Kt_B_actual = Kt_B * (1 - kt_drift_B*heatB(i));
    T_B_true(i) = Kt_B_actual * I_B_true(i);

    u_plant = [T_A_true(i); T_B_true(i)];
    x6(:,i) = Ad6*x6(:,i-1) + Bd6*u_plant; 
    
    % --- Evolución de Sesgos Dinámicos Reales (Proceso Gauss-Markov) ---
    bias_currentA_true(i) = bias_currentA_true(i-1) * exp_IA  + std_OU_IA  * randn;
    bias_currentB_true(i) = bias_currentB_true(i-1) * exp_IB  + std_OU_IB  * randn;
    bias_imu_true(i)      = bias_imu_true(i-1)      * exp_imu + std_OU_imu * randn;
    bias_sg_true(i)       = bias_sg_true(i-1)       * exp_sg  + std_OU_sg  * randn;

    % 4. Adquisición Ruidosa y Calibración Estática
    thA_raw = x6(1,i) + bias_hallA + noise_hall_std*randn;
    thB_raw = x6(5,i) + bias_hallB + noise_hall_std*randn;
    thA_cal = thA_raw - bias_hallA; thB_cal = thB_raw - bias_hallB; 
    
    thetaA_meas(i) = thetaA_meas(i-1) + alpha_hall*(thA_cal - thetaA_meas(i-1));
    thetaB_meas(i) = thetaB_meas(i-1) + alpha_hall*(thB_cal - thetaB_meas(i-1));
    
    IA_raw = I_A_true(i) + bias_currentA_true(i) + noise_current_std*randn;
    IB_raw = I_B_true(i) + bias_currentB_true(i) + noise_current_std*randn;
    
    IA_meas = IA_meas + alpha_cs*(IA_raw - IA_meas);
    IB_meas = IB_meas + alpha_cs*(IB_raw - IB_meas);
    
    TA_current_est(i) = Kt_A * IA_meas;
    TB_current_est(i) = Kt_B * IB_meas;

    wC_raw = x6(4,i) + bias_imu_true(i) + noise_gyro_std*randn;
    omegaC_meas(i) = omegaC_meas(i-1) + alpha_imu*(wC_raw - omegaC_meas(i-1));

    T_AC_true_i = C_torque(1,:) * x6(:,i);
    SG_raw = T_AC_true_i + bias_sg_true(i) + noise_strain_std*randn;
    SG_meas(i) = SG_meas(i-1) + alpha_sg*(SG_raw - SG_meas(i-1));

    % 5. Filtro de Kalman (Ganancia Pre-calculada K_kalman_steady)
    x_pred = Adk*x_est;
    z = [thetaA_meas(i); thetaB_meas(i); TA_current_est(i); TB_current_est(i); omegaC_meas(i); SG_meas(i)];
    y_innov = z - H*x_pred;
    
    x_est = x_pred + K_kalman_steady*y_innov;
    X_hist(:,i) = x_est;
end

% --- Extracción de Resultados ---
thetaA_kf = X_hist(1,:)'; omegaA_kf = X_hist(2,:)';
thetaC_kf = X_hist(3,:)'; omegaC_kf = X_hist(4,:)';
thetaB_kf = X_hist(5,:)'; omegaB_kf = X_hist(6,:)';
T_A_kf    = X_hist(7,:)'; T_B_kf    = X_hist(8,:)';

% Desacople de Sesgos Estimados
bias_TA_kf  = X_hist(11,:)';
bias_TB_kf  = X_hist(12,:)';
bias_imu_kf = X_hist(13,:)';
bias_sg_kf  = X_hist(14,:)';

% Conversión de sesgos de torque a corriente para comparar con los reales
bias_IA_kf = bias_TA_kf / Kt_A;
bias_IB_kf = bias_TB_kf / Kt_B;

theta_A_true = x6(1,:)'; omega_A_true = x6(2,:)';
theta_C_true = x6(3,:)'; omega_C_true = x6(4,:)';
theta_B_true = x6(5,:)'; omega_B_true = x6(6,:)';

T_trans_kf = C_torque * X_hist(1:6,:);
T_AC_kf = T_trans_kf(1,:)';
T_CB_kf = T_trans_kf(2,:)';

T_trans_true = C_torque * x6;
T_AC_true = T_trans_true(1,:)';
T_CB_true = T_trans_true(2,:)';

fprintf('=== BUCLE DE SIMULACIÓN FINALIZADO ===\n\n');