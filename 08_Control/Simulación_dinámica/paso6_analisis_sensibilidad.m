% =========================================================================
% SCRIPT 6: ANÁLISIS DE SENSIBILIDAD EN VARIABLES CRÍTICAS (th_C, om_C, I_B)
% =========================================================================
clc; clearvars; close all;

fprintf('========================================================================\n');
fprintf(' INICIANDO ANÁLISIS DE SENSIBILIDAD UNIFICADO (th_C, om_C, I_B)\n');
fprintf('========================================================================\n');

mult_ruido  = [0.1, 0.5, 1.0, 2.0, 5.0]; 
mult_modelo = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]; 

nombres_sensores = {'1. Sensores Hall (Encoder)', '2. Sensores de Corriente', ...
                    '3. Giroscopio (IMU)', '4. Strain Gauge (Tramo AC)'};
nombres_parametros = {'1. Inercias (J_A, J_B, J_C)', '2. Fricción y Amortiguamiento (c, b)', ...
                      '3. Constante de Torque (Kt)', '4. Sesgos Estocásticos (\sigma_b)', ...
                      '5. Rigidez Torsional del Eje (k)'};

rmse_thC_ruido = zeros(4, length(mult_ruido));
rmse_omC_ruido = zeros(4, length(mult_ruido));
rmse_IB_ruido  = zeros(4, length(mult_ruido));

rmse_thC_mod = zeros(5, length(mult_modelo));
rmse_omC_mod = zeros(5, length(mult_modelo));
rmse_IB_mod  = zeros(5, length(mult_modelo));

fprintf('\n[1/2] Evaluando propagación de ruido de sensores...\n');
for i = 1:4
    for m = 1:length(mult_ruido)
        [rmse_thC_ruido(i,m), rmse_omC_ruido(i,m), rmse_IB_ruido(i,m)] = run_unified_sim(1, i, mult_ruido(m));
    end
end

fprintf('[2/2] Evaluando sensibilidad a errores paramétricos de hardware...\n');
for i = 1:5
    for m = 1:length(mult_modelo)
        [rmse_thC_mod(i,m), rmse_omC_mod(i,m), rmse_IB_mod(i,m)] = run_unified_sim(2, i, mult_modelo(m));
    end
end

figure('Name', 'Sensibilidad en Variables Críticas', 'Color', 'w', 'Position', [50, 50, 1200, 900]);

subplot(3,2,1); hold on; grid on;
for i=1:4, plot(mult_ruido, rmse_thC_ruido(i,:), '-o', 'LineWidth', 2); end
title('Ruido vs Posición \theta_C'); ylabel('RMSE (rad)'); 
legend(nombres_sensores, 'Location', 'best', 'FontSize', 8);

subplot(3,2,2); hold on; grid on;
for i=1:5, plot(mult_modelo, rmse_thC_mod(i,:), '-s', 'LineWidth', 2); end
xline(1.0, 'k--', 'Modelo Perfecto'); title('Desajuste vs Posición \theta_C'); ylabel('RMSE (rad)');
legend(nombres_parametros, 'Location', 'best', 'FontSize', 8);

subplot(3,2,3); hold on; grid on;
for i=1:4, plot(mult_ruido, rmse_omC_ruido(i,:), '-o', 'LineWidth', 2); end
title('Ruido vs Velocidad \omega_C'); ylabel('RMSE (rad/s)');

subplot(3,2,4); hold on; grid on;
for i=1:5, plot(mult_modelo, rmse_omC_mod(i,:), '-s', 'LineWidth', 2); end
xline(1.0, 'k--', 'Modelo Perfecto'); title('Desajuste vs Velocidad \omega_C'); ylabel('RMSE (rad/s)');

subplot(3,2,5); hold on; grid on;
for i=1:4, plot(mult_ruido, rmse_IB_ruido(i,:), '-o', 'LineWidth', 2); end
title('Ruido vs Corriente Motor B'); xlabel('Multiplicador de Ruido (1=Nominal)'); ylabel('RMSE (A)');

subplot(3,2,6); hold on; grid on;
for i=1:5, plot(mult_modelo, rmse_IB_mod(i,:), '-s', 'LineWidth', 2); end
xline(1.0, 'k--', 'Modelo Perfecto'); title('Desajuste vs Corriente Motor B'); xlabel('Factor Físico vs Software (1=Exacto)'); ylabel('RMSE (A)');

fprintf('\n========================================================================\n');
fprintf(' CONCLUSIONES: CALIDAD DE SENSORES (PRESUPUESTO)\n');
fprintf('========================================================================\n');
idx_nom_r = find(mult_ruido == 1.0);
idx_peor_r = find(mult_ruido == 5.0);

for i = 1:4
    deg_thC = (rmse_thC_ruido(i, idx_peor_r) - rmse_thC_ruido(i, idx_nom_r)) / rmse_thC_ruido(i, idx_nom_r) * 100;
    deg_omC = (rmse_omC_ruido(i, idx_peor_r) - rmse_omC_ruido(i, idx_nom_r)) / rmse_omC_ruido(i, idx_nom_r) * 100;
    deg_IB  = (rmse_IB_ruido(i, idx_peor_r) - rmse_IB_ruido(i, idx_nom_r)) / rmse_IB_ruido(i, idx_nom_r) * 100;
    deg_max = max([deg_thC, deg_omC, deg_IB]);
    
    if deg_max > 40.0 
        fprintf('[CRÍTICO] %s:\n -> Hardware barato destruye la estimación (Peor degradación: %.1f%%).\n\n', nombres_sensores{i}, deg_max);
    else
        fprintf('[AHORRO]  %s:\n -> Kalman compensa bien. Apto para hardware económico (Peor degradación: %.1f%%).\n\n', nombres_sensores{i}, deg_max);
    end
end

fprintf('========================================================================\n');
fprintf(' CONCLUSIONES: TIEMPO DE CARACTERIZACIÓN (INGENIERÍA)\n');
fprintf('========================================================================\n');
idx_nom_m = find(mult_modelo == 1.0);
idx_peor_m = find(mult_modelo == 2.0);

for i = 1:5
    deg_thC = (rmse_thC_mod(i, idx_peor_m) - rmse_thC_mod(i, idx_nom_m)) / rmse_thC_mod(i, idx_nom_m) * 100;
    deg_omC = (rmse_omC_mod(i, idx_peor_m) - rmse_omC_mod(i, idx_nom_m)) / rmse_omC_mod(i, idx_nom_m) * 100;
    deg_IB  = (rmse_IB_mod(i, idx_peor_m) - rmse_IB_mod(i, idx_nom_m)) / rmse_IB_mod(i, idx_nom_m) * 100;
    deg_max = max(abs([deg_thC, deg_omC, deg_IB]));
    
    if deg_max > 25.0 
        fprintf('[CRÍTICO] %s:\n -> Requiere modelado 3D o ensayos reales (Error se dispara %.1f%%).\n\n', nombres_parametros{i}, deg_max);
    else
        fprintf('[TABULAR] %s:\n -> Usa un valor de internet. La dinámica es robusta a este error (Variación: %.1f%%).\n\n', nombres_parametros{i}, deg_max);
    end
end
fprintf('========================================================================\n');

function [rmse_thC, rmse_omC, rmse_IB] = run_unified_sim(tipo_test, idx_caso, mult)
    d = 0.005; L = 0.15; G = 79.3e9; J_polar = (pi * d^4) / 32; 
    k_nom = (G * J_polar) / L; c_nom = 0.05;
    k1_nom = 2*k_nom; k2_nom = 2*k_nom; c1_nom = 2*c_nom; c2_nom = 2*c_nom;
    JA_nom = 4e-4; JB_nom = 3e-4; JC_nom = 5e-5; bA_nom = 0.02; bB_nom = 0.02;
    KtA_nom = 0.06; KtB_nom = 0.05; r_imu = 0.005;
    g_sens_imu = 0.05*(pi/180); g_terrestre = 9.81;
    
    n_hall_nom = 0.002; n_curr_nom = 0.03; n_gyro_nom = 0.02; n_strain_nom = 0.005;
    sig_b_IA_nom = 0.15; sig_b_IB_nom = 0.12; sig_b_imu_nom = 0.25; sig_b_sg_nom = 0.20;

    JA_true = JA_nom; JB_true = JB_nom; JC_true = JC_nom;
    k1_true = k1_nom; k2_true = k2_nom; 
    c1_true = c1_nom; c2_true = c2_nom; bA_true = bA_nom; bB_true = bB_nom;
    KtA_true = KtA_nom; KtB_true = KtB_nom;
    sig_b_IA_true = sig_b_IA_nom; sig_b_imu_true = sig_b_imu_nom; sig_b_sg_true = sig_b_sg_nom;
    n_hall_true = n_hall_nom; n_curr_true = n_curr_nom; n_gyro_true = n_gyro_nom; n_strain_true = n_strain_nom;

    if tipo_test == 1 
        if idx_caso == 1, n_hall_true = n_hall_nom * mult; end
        if idx_caso == 2, n_curr_true = n_curr_nom * mult; end
        if idx_caso == 3, n_gyro_true = n_gyro_nom * mult; end
        if idx_caso == 4, n_strain_true = n_strain_nom * mult; end
    elseif tipo_test == 2 
        if idx_caso == 1, JA_true = JA_nom * mult; JB_true = JB_nom * mult; JC_true = JC_nom * mult; end
        if idx_caso == 2, c1_true = c1_nom * mult; c2_true = c2_nom * mult; bA_true = bA_nom * mult; bB_true = bB_nom * mult; end
        if idx_caso == 3, KtA_true = KtA_nom * mult; KtB_true = KtB_nom * mult; end
        if idx_caso == 4, sig_b_IA_true = sig_b_IA_nom * mult; sig_b_imu_true = sig_b_imu_nom * mult; sig_b_sg_true = sig_b_sg_nom * mult; end
        if idx_caso == 5, k1_true = k1_nom * mult; k2_true = k2_nom * mult; end
    end

    Ac6_nom = [0, 1, 0, 0, 0, 0; -k1_nom/JA_nom, -(c1_nom+bA_nom)/JA_nom, k1_nom/JA_nom, c1_nom/JA_nom, 0, 0;
               0, 0, 0, 1, 0, 0; k1_nom/JC_nom, c1_nom/JC_nom, -(k1_nom+k2_nom)/JC_nom, -(c1_nom+c2_nom)/JC_nom, k2_nom/JC_nom, c2_nom/JC_nom;
               0, 0, 0, 0, 0, 1; 0, 0, k2_nom/JB_nom, c2_nom/JB_nom, -k2_nom/JB_nom, -(c2_nom+bB_nom)/JB_nom];
    Bc6_nom = [0,0; 1/JA_nom,0; 0,0; 0,0; 0,0; 0,-1/JB_nom];
    C_torque_nom = [k1_nom, c1_nom, -k1_nom, -c1_nom, 0, 0; 0, 0, k2_nom, c2_nom, -k2_nom, -c2_nom];
    
    fs_sim = 5000; dt_sim = 1/fs_sim; T_sim = 4;
    sys_nom = c2d(ss(Ac6_nom, Bc6_nom, eye(6), zeros(6,2)), dt_sim, 'zoh');
    Ad6_nom = sys_nom.A; Bd6_nom = sys_nom.B;
    
    Ac6_true = [0, 1, 0, 0, 0, 0; -k1_true/JA_true, -(c1_true+bA_true)/JA_true, k1_true/JA_true, c1_true/JA_true, 0, 0;
                0, 0, 0, 1, 0, 0; k1_true/JC_true, c1_true/JC_true, -(k1_true+k2_true)/JC_true, -(c1_true+c2_true)/JC_true, k2_true/JC_true, c2_true/JC_true;
                0, 0, 0, 0, 0, 1; 0, 0, k2_true/JB_true, c2_true/JB_true, -k2_true/JB_true, -(c2_true+bB_true)/JB_true];
    Bc6_true = [0,0; 1/JA_true,0; 0,0; 0,0; 0,0; 0,-1/JB_true];
    C_torque_true = [k1_true, c1_true, -k1_true, -c1_true, 0, 0; 0, 0, k2_true, c2_true, -k2_true, -c2_true];
    
    sys_true = c2d(ss(Ac6_true, Bc6_true, eye(6), zeros(6,2)), dt_sim, 'zoh');
    Ad6_true = sys_true.A; Bd6_true = sys_true.B;

    nx = 14; Ac14 = zeros(nx,nx); Ac14(1:6, 1:6) = Ac6_nom; Ac14(1:6, 7:8) = Bc6_nom;
    Ac14(9,4) = 150*2*pi; Ac14(9,9) = -150*2*pi; Ac14(10,1:6) = C_torque_nom(1,:)*(30*2*pi); Ac14(10,10) = -30*2*pi;
    Ac14(11:14, 11:14) = diag([-1/12, -1/12, -1/8, -1/10]);
    Adk = expm(Ac14*dt_sim);
    
    % <- CORREGIDO: Matriz H multiplicada por KtA_nom y KtB_nom
    H = zeros(6,nx); H(1,1)=1; H(2,5)=1; H(3,7)=1; H(3,11)=KtA_nom; H(4,8)=1; H(4,12)=KtB_nom; H(5,9)=1; H(5,13)=1; H(6,10)=1; H(6,14)=1;
    
    Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, 0.01*dt_sim, 0.01*dt_sim, 1e-8, 1e-8, 1e-5, 1e-5, 1e-5, 1e-5]);
    R = diag([1e-5, 1e-5, 1e-3, 1e-3, 1e-4, 1e-4]);
    P = eye(nx);
    for iter = 1:50, P_pred = Adk*P*Adk' + Q; K_k = (P_pred*H') / (H*P_pred*H' + R); P = (eye(nx) - K_k*H)*P_pred; end

    t = (0:dt_sim:T_sim-dt_sim)'; N = length(t);
    x6 = zeros(6,N); x_est = zeros(nx,1); X_hist = zeros(nx,N);
    TA_true = 0; TB_true = 0; IA_true = 0; IB_true = 0; th_err_int = 0;
    
    bias_IA = 0.1; bias_IB = -0.08; bias_imu = 0.2; bias_sg = 0.15;
    alpha_drv = dt_sim / (1/(2*pi*200) + dt_sim);
    IB_true_arr = zeros(N,1);
    
    for i=2:N
        TA_cmd = (t(i) >= 1) * 4.0 * sin(2 * pi * 5 * t(i));
        TA_true = TA_true + alpha_drv*(TA_cmd - TA_true);
        IA_true = TA_true / KtA_true;
        
        th_err = 0 - x_est(3); th_err_int = max(min(th_err_int + th_err*dt_sim, 10), -10);
        TB_cmd = -(1*th_err + 5*th_err_int + 0.5*(0 - x_est(4)));
        IB_true = IB_true + alpha_drv*((TB_cmd/KtB_nom) - IB_true); 
        TB_true = KtB_true * IB_true; 
        IB_true_arr(i) = IB_true;
        
        x6(:,i) = Ad6_true*x6(:,i-1) + Bd6_true*[TA_true; TB_true];
        
        bias_IA = bias_IA*exp(-dt_sim/12) + sig_b_IA_true*sqrt(1-exp(-2*dt_sim/12))*randn;
        bias_IB = bias_IB*exp(-dt_sim/12) + sig_b_IB_nom*sqrt(1-exp(-2*dt_sim/12))*randn;
        bias_imu = bias_imu*exp(-dt_sim/8) + sig_b_imu_true*sqrt(1-exp(-2*dt_sim/8))*randn;
        bias_sg = bias_sg*exp(-dt_sim/10) + sig_b_sg_true*sqrt(1-exp(-2*dt_sim/10))*randn;
        
        thA_m = x6(1,i) + n_hall_true*randn;
        thB_m = x6(5,i) + n_hall_true*randn;
        IA_m  = IA_true + bias_IA + n_curr_true*randn;
        IB_m  = IB_true + bias_IB + n_curr_true*randn;
        
        omega_C_val  = x6(4,i);
        a_centripeta = (omega_C_val^2) * r_imu;                    
        error_gsens  = g_sens_imu * (a_centripeta / g_terrestre);  
        wC_m  = omega_C_val + error_gsens + bias_imu + n_gyro_true*randn;
        
        SG_m  = C_torque_true(1,:)*x6(:,i) + bias_sg + n_strain_true*randn;
        
        x_pred = Adk*x_est;
        z = [thA_m; thB_m; KtA_nom*IA_m; KtB_nom*IB_m; wC_m; SG_m];
        x_est = x_pred + K_k*(z - H*x_pred);
        X_hist(:,i) = x_est;
    end
    
    idx_eval = (fs_sim*1):N;
    rmse_thC = sqrt(mean((X_hist(3,idx_eval)' - x6(3,idx_eval)').^2));
    rmse_omC = sqrt(mean((X_hist(4,idx_eval)' - x6(4,idx_eval)').^2));
    
    IB_est = (X_hist(8,idx_eval) / KtB_nom)';
    rmse_IB  = sqrt(mean((IB_est - IB_true_arr(idx_eval)).^2));
    
    if rmse_thC > 1e3 || isnan(rmse_thC), rmse_thC = 1e3; end
    if rmse_omC > 1e3 || isnan(rmse_omC), rmse_omC = 1e3; end
    if rmse_IB > 1e3 || isnan(rmse_IB),   rmse_IB = 1e3; end
end