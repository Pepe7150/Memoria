% =========================================================================
% SCRIPT 2: CONFIGURACIÓN TEMPORAL Y PERFIL DE PRUEBA 
% =========================================================================

fs_sim = 5000; 
dt_sim = 1/fs_sim; 
T_sim = 20;                      % Tiempo total de simulación [s]
t = (0:dt_sim:T_sim-dt_sim)'; 
N = length(t);

% --- Perfil de Torque Abierto en Motor A ---
t_ramp_ini = 1.0; 
t_ramp_fin = 4.0;
idx_r1 = find(t >= t_ramp_ini, 1, 'first');
idx_r2 = find(t >= t_ramp_fin, 1, 'first');

T_A_ref = zeros(N,1);
T_A_ref(idx_r1:idx_r2) = linspace(0, 4.0, idx_r2-idx_r1+1)';
T_A_ref(idx_r2:end) = 4.0;

% --- Parámetros Temporales para Dinámicas ---
tau_drv = 1/(2*pi*bw_driver);       
alpha_drv = dt_sim / (tau_drv + dt_sim);        

tau_thermal = 10;                 % Constante de tiempo de calentamiento [s]
alpha_th = dt_sim / (tau_thermal + dt_sim);

fprintf('=== PERFIL TEMPORAL GENERADO ===\n');
fprintf('Pasos de simulación: %d | Frecuencia de muestreo: %d Hz\n\n', N, fs_sim);