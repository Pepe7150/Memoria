% =========================================================================
% SCRIPT 6: ANÁLISIS DE SENSIBILIDAD DE SENSORES Y COMPONENTES CRÍTICOS
% =========================================================================
clc; clearvars; close all;

fprintf('=== INICIANDO ANÁLISIS DE SENSIBILIDAD ===\n');
fprintf('Evaluando impacto del ruido en la estimación de variables no medidas...\n');

% Multiplicadores de ruido a evaluar (0.1 = Premium, 1 = Base, 5 = Low-cost)
multiplicadores = [0.1, 0.5, 1.0, 2.0, 5.0];
num_tests = length(multiplicadores);

% Matrices para almacenar los resultados del RMSE
rmse_thetaC = zeros(4, num_tests); % Filas: 1=Hall, 2=Current, 3=Gyro, 4=Strain
rmse_TCB    = zeros(4, num_tests);

% Nombres para los gráficos
nombres_sensores = {'Ruido Sensores Hall', 'Ruido Sensores Corriente', ...
                    'Ruido IMU (Giroscopio)', 'Ruido Strain Gauge'};

% Ruido base nominal de tu sistema
base_hall_std = 0.002; base_current_std = 0.03;
base_gyro_std = 0.02;  base_strain_std  = 0.005;

for sensor_idx = 1:4
    for m_idx = 1:num_tests
        % Reiniciar valores nominales
        n_hall = base_hall_std; n_curr = base_current_std;
        n_gyro = base_gyro_std; n_strain = base_strain_std;
        
        % Aplicar multiplicador al sensor correspondiente
        mult = multiplicadores(m_idx);
        switch sensor_idx
            case 1, n_hall = base_hall_std * mult;
            case 2, n_curr = base_current_std * mult;
            case 3, n_gyro = base_gyro_std * mult;
            case 4, n_strain = base_strain_std * mult;
        end
        
        % Ejecutar simulación con los ruidos modificados
        [err_thetaC, err_TCB] = run_sim_for_sensitivity(n_hall, n_curr, n_gyro, n_strain);
        
        % Almacenar métricas
        rmse_thetaC(sensor_idx, m_idx) = err_thetaC;
        rmse_TCB(sensor_idx, m_idx)    = err_TCB;
    end
end

% --- Graficar Resultados de Sensibilidad ---
figure('Name', 'Sensibilidad de Componentes a la Calidad del Sensor', 'Color', 'w', 'Position', [100,100,1000,600]);
colores = lines(4);

subplot(1,2,1);
for i = 1:4
    plot(multiplicadores, rmse_thetaC(i,:), '-o', 'LineWidth', 2, 'Color', colores(i,:)); hold on;
end
xlabel('Multiplicador de Ruido (1 = Nominal, <1 = Mejor)');
ylabel('RMSE \theta_C (rad)');
title('Sensibilidad en Posición Central (No Medida)');
grid on; legend(nombres_sensores, 'Location', 'best');

subplot(1,2,2);
for i = 1:4
    plot(multiplicadores, rmse_TCB(i,:), '-o', 'LineWidth', 2, 'Color', colores(i,:)); hold on;
end
xlabel('Multiplicador de Ruido (1 = Nominal, <1 = Mejor)');
ylabel('RMSE T_{CB} (Nm)');
title('Sensibilidad en Torque Transmitido CB (No Medido)');
grid on; legend(nombres_sensores, 'Location', 'best');

fprintf('=== ANÁLISIS COMPLETADO ===\n');
fprintf('Revisa las pendientes en los gráficos: las curvas más empinadas indican los\n');
fprintf('componentes más críticos estructuralmente donde debes destinar más presupuesto.\n');

% =========================================================================
% FUNCIÓN LOCAL: MOTOR DE SIMULACIÓN Y KALMAN CONDENSADO
% =========================================================================
function [rmse_thC, rmse_tcb] = run_sim_for_sensitivity(noise_hall, noise_current, noise_gyro, noise_strain)
    % Parámetros mecánicos base
    d = 0.005; L = 0.15; G = 79.3e9; 
    J_polar = (pi * d^4) / 32; k_full = (G * J_polar) / L; c_full = 0.05;
    k1 = 2*k_full; c1 = 2*c_full; k2 = 2*k_full; c2 = 2*c_full;
    J_A = 4e-4; J_B = 3e-4; J_C = 5e-5; b_A = 0.02; b_B = 0.02;
    Kt_A = 0.06; Kt_B = 0.05;
    
    % Configuración temporal
    fs_sim = 5000; dt_sim = 1/fs_sim; T_sim = 5; % Simulación corta (5s) para sensibilidad rápida
    t = (0:dt_sim:T_sim-dt_sim)'; N = length(t);
    
    % Perfil de entrada (Torque Motor A)
    T_A_ref = zeros(N,1); 
    T_A_ref(t >= 1) = 4.0;
    
    % Matrices de Estado de Planta 6x6
    Ac6 = [0, 1, 0, 0, 0, 0;
          -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0;
           0, 0, 0, 1, 0, 0;
           k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C;
           0, 0, 0, 0, 0, 1;
           0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B];
    Bc6 = [0,0; 1/J_A,0; 0,0; 0,0; 0,0; 0,-1/J_B];
    C_torque = [k1, c1, -k1, -c1, 0, 0; 0, 0, k2, c2, -k2, -c2];
    sys_d = c2d(ss(Ac6, Bc6, eye(6), zeros(6,2)), dt_sim, 'zoh');
    Ad6 = sys_d.A; Bd6 = sys_d.B;
    
    % Filtros Sensores
    alpha_drv = dt_sim / (1/(2*pi*200) + dt_sim);
    alpha_hall = dt_sim / (1/(2*pi*500) + dt_sim);
    alpha_cs = dt_sim / (1/(2*pi*500) + dt_sim);
    alpha_imu = dt_sim / (1/(2*pi*150) + dt_sim);
    alpha_sg = dt_sim / (1/(2*pi*30) + dt_sim);
    
    % Parámetros Kalman Ampliado (14 Estados)
    nx = 14; Ac14 = zeros(nx,nx);
    Ac14(1:6, 1:6) = Ac6; Ac14(1:6, 7:8) = Bc6;
    Ac14(9,4) = 150*2*pi; Ac14(9,9) = -150*2*pi; % BW IMU = 150Hz
    Ac14(10,1:6) = C_torque(1,:) * (30*2*pi); Ac14(10,10) = -30*2*pi; % BW SG = 30Hz
    
    % Dinámica de Sesgos (Gauss-Markov aproximado)
    tau_b = 10; Ac14(11:14, 11:14) = diag([-1/12, -1/12, -1/8, -1/10]);
    Adk = expm(Ac14*dt_sim);
    
    H = zeros(6,nx);
    H(1,1)=1; H(2,5)=1; 
    H(3,7)=1; H(3,11)=1; 
    H(4,8)=1; H(4,12)=1; 
    H(5,9)=1; H(5,13)=1; 
    H(6,10)=1; H(6,14)=1;
    
    % Matrices Q y R para el Kalman según la iteración
    var_hall = noise_hall^2 * alpha_hall/(2-alpha_hall);
    var_IA   = noise_current^2 * alpha_cs/(2-alpha_cs);
    var_imu  = noise_gyro^2 * alpha_imu/(2-alpha_imu);
    var_sg   = noise_strain^2 * alpha_sg/(2-alpha_sg);
    R = diag([var_hall, var_hall, (Kt_A^2)*var_IA, (Kt_B^2)*var_IA, var_imu, var_sg]);
    
    Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, ... 
              0.01*dt_sim, 0.01*dt_sim, 1e-8, 1e-8, ... 
              1e-5, 1e-5, 1e-5, 1e-5]); 
          
    P = eye(nx);
    for iter = 1:100
        P_pred = Adk*P*Adk' + Q;
        K_k = (P_pred*H') / (H*P_pred*H' + R);
        P = (eye(nx) - K_k*H)*P_pred;
    end
    
    % Bucle de Simulación
    x6 = zeros(6,N); x_est = zeros(nx,1); X_hist = zeros(nx,N);
    TA_true = 0; TB_true = 0; IA_true = 0; IB_true = 0;
    thA_meas=0; thB_meas=0; IA_meas=0; IB_meas=0; wC_meas=0; SG_meas=0;
    th_err_int = 0;
    
    for i=2:N
        % Planta y Control Básico
        TA_true = TA_true + alpha_drv*(T_A_ref(i) - TA_true);
        IA_true = TA_true / Kt_A;
        
        th_err = 0 - x_est(3); th_err_int = th_err_int + th_err*dt_sim;
        TB_cmd = -(1*th_err + 5*th_err_int + 0.5*(0 - x_est(4)));
        IB_true = IB_true + alpha_drv*((TB_cmd/Kt_B) - IB_true);
        TB_true = Kt_B * IB_true;
        
        x6(:,i) = Ad6*x6(:,i-1) + Bd6*[TA_true; TB_true];
        
        % Sensores + Ruido
        thA_meas = thA_meas + alpha_hall*((x6(1,i) + noise_hall*randn) - thA_meas);
        thB_meas = thB_meas + alpha_hall*((x6(5,i) + noise_hall*randn) - thB_meas);
        IA_meas  = IA_meas  + alpha_cs*((IA_true + noise_current*randn) - IA_meas);
        IB_meas  = IB_meas  + alpha_cs*((IB_true + noise_current*randn) - IB_meas);
        wC_meas  = wC_meas  + alpha_imu*((x6(4,i) + noise_gyro*randn) - wC_meas);
        
        TAC_true_i = C_torque(1,:) * x6(:,i);
        SG_meas  = SG_meas + alpha_sg*((TAC_true_i + noise_strain*randn) - SG_meas);
        
        % Kalman Fusión
        x_pred = Adk*x_est;
        z = [thA_meas; thB_meas; Kt_A*IA_meas; Kt_B*IB_meas; wC_meas; SG_meas];
        x_est = x_pred + K_k*(z - H*x_pred);
        X_hist(:,i) = x_est;
    end
    
    % Calcular RMSE para los estados críticos (Omitiendo el transitorio inicial de 1s)
    idx_eval = (fs_sim*1):N;
    rmse_thC = sqrt(mean((X_hist(3,idx_eval)' - x6(3,idx_eval)').^2));
    
    T_CB_true = (C_torque(2,:) * x6(:,idx_eval))';
    T_CB_kf   = (C_torque(2,:) * X_hist(1:6,idx_eval))';
    rmse_tcb  = sqrt(mean((T_CB_kf - T_CB_true).^2));
end