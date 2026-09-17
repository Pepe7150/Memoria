%% 1. CONFIGURACIÓN TEMPORAL
fs_sim = 5000; 
dt_sim = 1/fs_sim; 
T_sim = 20;   % 6 segundos de simulación
t = (0:dt_sim:T_sim-dt_sim)'; 
N = length(t);

%% 2. PERFIL DE TORQUE DEL MOTOR A (Carga, Open-loop)
% Rampa de 0 a 4.0 Nm entre t=1s y t=4s
t_ramp_ini = 1.0; 
t_ramp_fin = 4.0;
idx_r1 = find(t >= t_ramp_ini, 1, 'first');
idx_r2 = find(t >= t_ramp_fin, 1, 'first');

T_A_ref = zeros(N,1);
T_A_ref(idx_r1:idx_r2) = linspace(0, 4.0, idx_r2-idx_r1+1)';
T_A_ref(idx_r2:end) = 4.0;

%% 3. DINÁMICA DEL DRIVER DEL MOTOR A
I_A_ref = T_A_ref / Kt_A;

tau_drv = 1/(2*pi*bw_driver);       %cte de tiempo del driver (cuanto se demora en responder)
alpha_drv = dt_sim / (tau_drv + dt_sim);        %factor de discretización (error que el driver es capaz de corregir en dt

I_A_true = zeros(N,1);
for i = 2:N
    I_A_true(i) = I_A_true(i-1) + alpha_drv*(I_A_ref(i) - I_A_true(i-1));
end

%% 4. DERIVA TÉRMICA DE Kt (Caída de torque por calentamiento)
I_A_rated = 4.0 / Kt_A;        % Corriente de referencia para normalizar
tau_thermal = 10;              % [s] constante de tiempo térmica (acelerada para la simulación)
alpha_th = dt_sim / (tau_thermal + dt_sim);
kt_drift_A = 0.08;             % Fracción de caída de Kt a calentamiento pleno (8%)

heatA = zeros(N,1);
for i = 2:N
    heatA(i) = heatA(i-1) + alpha_th*((I_A_true(i)/I_A_rated)^2 - heatA(i-1));
end

Kt_A_actual = Kt_A * (1 - kt_drift_A*heatA);
T_A_true = Kt_A_actual .* I_A_true;   % Torque REAL (con Kt ya degradado)

%% MOSTRAR RESULTADOS EN CONSOLA
fprintf('=== PERFIL Y DERIVA TÉRMICA CALCULADOS ===\n');
fprintf('Vector de tiempo (N): %d muestras (dt = %.4f s)\n', N, dt_sim);
fprintf('Torque de referencia final: %.2f Nm\n', T_A_ref(end));
fprintf('Kt_A nominal: %.4f Nm/A | Kt_A final degradado: %.4f Nm/A\n', Kt_A, Kt_A_actual(end));
fprintf('Torque real final aplicado (con deriva): %.4f Nm\n', T_A_true(end));