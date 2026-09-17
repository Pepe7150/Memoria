%% 1. GRÁFICOS COMPARATIVOS

% Figura 1: Torques de Motor A y Motor B
figure('Name', 'Torque Motor A y Motor B', 'Color', 'w', 'Position', [50,50,950,700]);
subplot(2,1,1);
plot(t, T_A_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TA_current_est, 'm', 'LineWidth', 1);
plot(t, T_A_kf, 'b', 'LineWidth', 2);
ylabel('T_A (Nm)'); grid on; xlim([0 T_sim]);
legend('Real', 'Solo corriente (Kt nominal)', 'Kalman', 'Location', 'best');
title('Torque Motor A (con deriva térmica de Kt)');

subplot(2,1,2);
plot(t, T_B_true, 'k--', 'LineWidth', 2); hold on;
plot(t, TB_current_est, 'm', 'LineWidth', 1);
plot(t, T_B_kf, 'r', 'LineWidth', 2);
ylabel('T_B (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Solo corriente (Kt nominal)', 'Kalman', 'Location', 'best');
title('Torque Motor B (con deriva térmica de Kt)');

% Figura 2: Torque Transmitido (A-C y C-B)
figure('Name', 'Torque Transmitido', 'Color', 'w', 'Position', [70,70,950,700]);
subplot(2,1,1);
plot(t, T_AC_true, 'k--', 'LineWidth', 2); hold on;
plot(t, SG_meas, 'c', 'LineWidth', 1);
plot(t, T_AC_kf, 'g', 'LineWidth', 2);
ylabel('T_{AC} (Nm)'); grid on; xlim([0 T_sim]);
legend('Real', 'Strain gauge', 'Kalman', 'Location', 'best');
title('Torque Transmitido, tramo A-C (con sensor directo)');

subplot(2,1,2);
plot(t, T_CB_true, 'k--', 'LineWidth', 2); hold on;
plot(t, T_CB_kf, 'g', 'LineWidth', 2);
ylabel('T_{CB} (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'Kalman (sin sensor directo)', 'Location', 'best');
title('Torque Transmitido, tramo C-B (inferido del modelo)');

% Figura 3: Cinemática del Disco C
figure('Name', 'Posición y Velocidad Angular de C', 'Color', 'w', 'Position', [90,90,950,700]);
subplot(2,1,1);
plot(t, theta_C_true, 'k--', 'LineWidth', 2); hold on;
plot(t, thetaC_kf, 'b', 'LineWidth', 2);
ylabel('\theta_C (rad)'); grid on; xlim([0 T_sim]);
legend('Real', 'Kalman (sin encoder directo)', 'Location', 'best');
title('Posición Angular de C');

subplot(2,1,2);
plot(t, omega_C_true, 'k--', 'LineWidth', 2); hold on;
plot(t, omegaC_meas, 'm', 'LineWidth', 1);
plot(t, omegaC_kf, 'b', 'LineWidth', 2);
ylabel('\omega_C (rad/s)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real', 'IMU (cruda)', 'Kalman', 'Location', 'best');
title('Velocidad Angular de C');


%% 2. MÉTRICAS DE DESEMPEÑO (RMSE y % Mejora)
rmse = @(e) sqrt(mean(e.^2));
mejora = @(rmse_crudo, rmse_kf) ((rmse_crudo - rmse_kf)/rmse_crudo)*100;

rmse_TA_curr = rmse(TA_current_est - T_A_true); 
rmse_TA_kf   = rmse(T_A_kf - T_A_true);
rmse_TB_curr = rmse(TB_current_est - T_B_true); 
rmse_TB_kf   = rmse(T_B_kf - T_B_true);
rmse_TAC_sg  = rmse(SG_meas - T_AC_true);       
rmse_TAC_kf  = rmse(T_AC_kf - T_AC_true);
rmse_wC_imu  = rmse(omegaC_meas - omega_C_true); 
rmse_wC_kf   = rmse(omegaC_kf - omega_C_true);

fprintf('\n=== MÉTRICAS DE DESEMPEÑO ===\n');
fprintf('T_A - RMSE corriente: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TA_curr, rmse_TA_kf, mejora(rmse_TA_curr, rmse_TA_kf));
fprintf('T_B - RMSE corriente: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TB_curr, rmse_TB_kf, mejora(rmse_TB_curr, rmse_TB_kf));
fprintf('--- Deriva de Kt (Estimación de Sesgo) ---\n');
fprintf('biasA - RMSE vs sesgo real: %.4f Nm (Sesgo real final: %.4f Nm)\n', ...
    rmse(biasA_kf - biasA_true), biasA_true(end));
fprintf('biasB - RMSE vs sesgo real: %.4f Nm (Sesgo real final: %.4f Nm)\n', ...
    rmse(biasB_kf - biasB_true), biasB_true(end));
fprintf('--- Torque Transmitido ---\n');
fprintf('T_AC - RMSE strain: %.4f Nm | RMSE Kalman: %.4f Nm | Mejora: %.2f %%\n', ...
    rmse_TAC_sg, rmse_TAC_kf, mejora(rmse_TAC_sg, rmse_TAC_kf));
fprintf('T_CB - RMSE Kalman (sin sensor directo): %.4f Nm\n', rmse(T_CB_kf - T_CB_true));
fprintf('--- Estado de C ---\n');
fprintf('theta_C - RMSE Kalman (sin encoder): %.5f rad\n', rmse(thetaC_kf - theta_C_true));
fprintf('omega_C - RMSE IMU: %.4f rad/s | RMSE Kalman: %.4f rad/s | Mejora: %.2f %%\n', ...
    rmse_wC_imu, rmse_wC_kf, mejora(rmse_wC_imu, rmse_wC_kf));
fprintf('==============================\n\n');


%% 3. EVALUACIÓN DE ANCHO DE BANDA
fprintf('=== EVALUACIÓN DE ANCHO DE BANDA ===\n');
bw_ctrl_loop = sqrt(Kp_pos/J_B)/(2*pi);
fprintf('Modo dominante (fn1): %.2f Hz | Modo local C (fn2): %.2f Hz\n', fn1, fn2);
fprintf('Ancho de banda del lazo de control de B: %.2f Hz\n', bw_ctrl_loop);
fprintf('-----------------------------------------------------------\n');

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
fprintf('=====================================================\n');