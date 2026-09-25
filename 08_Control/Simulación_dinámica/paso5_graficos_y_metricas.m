% =========================================================================
% SCRIPT 5: GENERACIÓN DE GRÁFICOS Y ANÁLISIS DE MÉTRICAS
% =========================================================================

% --- Figura 1: Torques de los Motores ---
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

% --- Figura 2: Torque Transmitido ---
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

% --- Figura 3: Cinemática del Disco Central C ---
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

% --- Figura 4: Seguimiento de Sesgos Dinámicos (Gauss-Markov) ---
figure('Name', 'Seguimiento de Sesgos (Gauss-Markov)', 'Color', 'w', 'Position', [110,110,950,700]);

subplot(2,2,1);
plot(t, bias_currentA_true, 'k--', 'LineWidth', 1.5); hold on;
plot(t, bias_IA_kf, 'b', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('Bias I_A (A)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real (Gauss-Markov)', 'Estimación Kalman', 'Location', 'best'); title('Sesgo Corriente Motor A');

subplot(2,2,2);
plot(t, bias_currentB_true, 'k--', 'LineWidth', 1.5); hold on;
plot(t, bias_IB_kf, 'r', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('Bias I_B (A)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real (Gauss-Markov)', 'Estimación Kalman', 'Location', 'best'); title('Sesgo Corriente Motor B');

subplot(2,2,3);
plot(t, bias_imu_true, 'k--', 'LineWidth', 1.5); hold on;
plot(t, bias_imu_kf, 'm', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('Bias IMU (rad/s)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real (Gauss-Markov)', 'Estimación Kalman', 'Location', 'best'); title('Sesgo Giroscopio IMU');

subplot(2,2,4);
plot(t, bias_sg_true, 'k--', 'LineWidth', 1.5); hold on;
plot(t, bias_sg_kf, 'g', 'LineWidth', 2);
if system_fault, xline(fault_time, 'r--', 'HandleVisibility', 'off'); end
ylabel('Bias SG (Nm)'); xlabel('Tiempo (s)'); grid on; xlim([0 T_sim]);
legend('Real (Gauss-Markov)', 'Estimación Kalman', 'Location', 'best'); title('Sesgo Strain Gauge');

% --- REPORTE DE MÉTRICAS ---
mejora = @(rmse_crudo, rmse_kf) ((rmse_crudo - rmse_kf)/rmse_crudo)*100;

fprintf('========================================================================================\n');
fprintf('                             MÉTRICAS DE DESEMPEÑO Y SENSORES                           \n');
fprintf('========================================================================================\n\n');

fprintf('--- ESTIMACIÓN DE SESGOS DINÁMICOS (MODELO GAUSS-MARKOV) ---\n');
fprintf('Bias Corriente A | RMSE Estimación: %.4f A\n', rmse(bias_IA_kf, bias_currentA_true));
fprintf('Bias Corriente B | RMSE Estimación: %.4f A\n', rmse(bias_IB_kf, bias_currentB_true));
fprintf('Bias IMU         | RMSE Estimación: %.4f rad/s\n', rmse(bias_imu_kf, bias_imu_true));
fprintf('Bias Strain Gauge| RMSE Estimación: %.4f Nm\n\n', rmse(bias_sg_kf, bias_sg_true));

fprintf('--- POSICIONES ANGULARES [rad] ---\n');
fprintf('theta_A  | Sensor directo: Hall A (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.5f rad | RMSE Kalman: %.5f rad | Mejora: %.2f %%\n', ...
    rmse(thetaA_meas, theta_A_true), rmse(thetaA_kf, theta_A_true), mejora(rmse(thetaA_meas, theta_A_true), rmse(thetaA_kf, theta_A_true)));

fprintf('theta_B  | Sensor directo: Hall B (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.5f rad | RMSE Kalman: %.5f rad | Mejora: %.2f %%\n', ...
    rmse(thetaB_meas, theta_B_true), rmse(thetaB_kf, theta_B_true), mejora(rmse(thetaB_meas, theta_B_true), rmse(thetaB_kf, theta_B_true)));

fprintf('theta_C  | Sensor directo: Ninguno (Estimación Virtual por Fusión)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.5f rad\n\n', rmse(thetaC_kf, theta_C_true));

fprintf('--- VELOCIDADES ANGULARES [rad/s] ---\n');
fprintf('omega_A  | Sensor directo: Ninguno (Estimación Virtual)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.4f rad/s\n', rmse(omegaA_kf, omega_A_true));

fprintf('omega_B  | Sensor directo: Ninguno (Estimación Virtual)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.4f rad/s\n', rmse(omegaB_kf, omega_B_true));

fprintf('omega_C  | Sensor directo: IMU Giroscopio (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.4f rad/s | RMSE Kalman: %.4f rad/s | Mejora: %.2f %%\n\n', ...
    rmse(omegaC_meas, omega_C_true), rmse(omegaC_kf, omega_C_true), mejora(rmse(omegaC_meas, omega_C_true), rmse(omegaC_kf, omega_C_true)));

fprintf('--- TORQUES ACTIVOS Y TRANSMITIDOS [Nm] ---\n');
fprintf('T_A      | Sensor directo: Corriente Motor A (+ Estimación Kalman de Kt y Bias)\n');
fprintf('         RMSE Crudo: %.4f Nm   | RMSE Kalman: %.4f Nm   | Mejora: %.2f %%\n', ...
    rmse(TA_current_est, T_A_true), rmse(T_A_kf, T_A_true), mejora(rmse(TA_current_est, T_A_true), rmse(T_A_kf, T_A_true)));

fprintf('T_B      | Sensor directo: Corriente Motor B (+ Estimación Kalman de Kt y Bias)\n');
fprintf('         RMSE Crudo: %.4f Nm   | RMSE Kalman: %.4f Nm   | Mejora: %.2f %%\n', ...
    rmse(TB_current_est, T_B_true), rmse(T_B_kf, T_B_true), mejora(rmse(TB_current_est, T_B_true), rmse(T_B_kf, T_B_true)));

fprintf('T_AC     | Sensor directo: Strain Gauge SG (+ Fusión Modelo/Kalman)\n');
fprintf('         RMSE Crudo: %.4f Nm   | RMSE Kalman: %.4f Nm   | Mejora: %.2f %%\n', ...
    rmse(SG_meas, T_AC_true), rmse(T_AC_kf, T_AC_true), mejora(rmse(SG_meas, T_AC_true), rmse(T_AC_kf, T_AC_true)));

fprintf('T_CB     | Sensor directo: Ninguno (Estimación Virtual: Modelo + Hall B + SG)\n');
fprintf('         RMSE Crudo: N/A          | RMSE Kalman: %.4f Nm\n', rmse(T_CB_kf, T_CB_true));
fprintf('========================================================================================\n\n');

% --- EVALUACIÓN DE ANCHO DE BANDA Y ESTADOS ---
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

fprintf('\n=== ESTADO DE SEGURIDAD (FAIL SAFES) ===\n');
if system_fault
    fprintf('!!! ADVERTENCIA: Se disparó un FAIL SAFE a los %.3f segundos !!!\n', fault_time);
    fprintf('Causa específica: %s\n', fault_reason);
else
    fprintf('Estado: OK. No se detectaron violaciones a los límites angulares, cinemáticos ni de torque.\n');
end
fprintf('=====================================================\n');