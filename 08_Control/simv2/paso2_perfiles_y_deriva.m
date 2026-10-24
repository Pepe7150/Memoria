% =========================================================================
% SCRIPT 2: CONFIGURACIÓN TEMPORAL, ESCENARIO DE ENSAYO Y LUT DE CARGA
% =========================================================================
% Cambios respecto de la versión anterior:
%   - La rampa de torque en lazo abierto (0 -> 4 Nm) se reemplaza por la LUT
%     de momento de bisagra del CFD, evaluada en línea con el ángulo
%     ESTIMADO de la aleta (theta_C_hat). Ver paso4.
%   - El actuador bajo ensayo (B) sigue una consigna de ángulo delta_cmd(t).
%   - Planta a fs_sim; sensores muestreados y Kalman a fs_kf (tasa de adquisición real).

fs_sim = 5000;
dt_sim = 1/fs_sim;
fs_kf  = 1000;                       % Tasa de adquisición y del Kalman [Hz] (AJUSTAR al ODR real medido)
decim  = round(fs_sim/fs_kf);
dt_kf  = decim*dt_sim;
T_sim  = 20;                         % Tiempo total de simulación [s]
t = (0:dt_sim:T_sim-dt_sim)';
N = length(t);

semilla = 1;  rng(semilla);          % Reproducibilidad (antes cada corrida daba cifras distintas)

% --- Escenario de ensayo ------------------------------------------------
%  1: M=0.3, AoA=0°  | rampa lenta 0 -> +15 -> -15 -> 0° (cruza el cero de la carga)
%  2: M=0.3, AoA=10° | mantener +15° (carga máxima) con escalones de 5°
%  3: M=0.3, AoA=0°  | barrido senoidal ±5°, 1 -> 10 Hz (dinámico)
if ~exist('escenario','var'), escenario = 1; end

switch escenario
    case 1
        M_test = 0.3; aoa_test = 0;
        tb = [0  1  5   13  17  20];
        db = [0  0  15 -15  0   0 ];
        delta_cmd_deg = interp1(tb, db, t, 'linear');
    case 2
        M_test = 0.3; aoa_test = 10;
        tb = [0 1 3  8  8.2 12 12.2 16 16.2 20];
        db = [0 0 15 15 10  10 15   15 5    5 ];
        delta_cmd_deg = interp1(tb, db, t, 'linear');
    case 3
        M_test = 0.3; aoa_test = 0;
        f0 = 1; f1 = 10;
        delta_cmd_deg = 5*sin(2*pi*(f0*t + (f1-f0)/(2*T_sim)*t.^2)) .* min(t/1, 1);
    otherwise
        error('escenario debe ser 1, 2 o 3');
end

delta_cmd = delta_cmd_deg*pi/180;                    % [rad]
omega_cmd = [0; diff(delta_cmd)]/dt_sim;             % [rad/s]

if max(abs(omega_cmd)) > w_servo_max
    warning('La consigna pide %.2f rad/s y el servo da ~%.2f rad/s: reducir amplitud o frecuencia.', ...
        max(abs(omega_cmd)), w_servo_max);
end

% --- LUT de momento de bisagra (CFD) -------------------------------------
% Se reconstruye en N·m desde ChHinge (adimensional) con la geometría REAL del banco.
% Columnas de resultados.csv: delta_deg, mach, aoa_deg, Cl, Cd, CmPitch, ChHinge, HingeMoment_Nm
archivo_lut = 'resultados.csv';
c_real = 0.15;  b_real = 0.15;       % Cuerda y envergadura de la aleta [m]
rho_real = 1.225;  a_sound = 340.3;  % Aire a nivel del mar (ISA), igual que el barrido CFD

tab = readmatrix(archivo_lut, 'NumHeaderLines', 1);
dl = tab(:,1);  mc = tab(:,2);  al = tab(:,3);  Ch = tab(:,7);

dv = unique(dl);  mv = unique(mc);  av = unique(al);
[~,id] = ismember(dl, dv);  [~,im] = ismember(mc, mv);  [~,ia] = ismember(al, av);
Ch3 = nan(numel(dv), numel(mv), numel(av));
Ch3(sub2ind(size(Ch3), id, im, ia)) = Ch;
if any(isnan(Ch3(:)))
    error('La LUT no es una malla completa (delta x Mach x AoA).');
end
if M_test < mv(1) || M_test > mv(end) || aoa_test < av(1) || aoa_test > av(end)
    error('M_test o aoa_test fuera del rango de la LUT.');
end

% Ch es casi independiente de M: se interpola linealmente en (M, AoA) y luego
% se dimensionaliza con la presión dinámica del caso.
ch_delta = zeros(numel(dv),1);
for k = 1:numel(dv)
    ch_delta(k) = interp2(av, mv, squeeze(Ch3(k,:,:)), aoa_test, M_test, 'linear');
end
q_test = 0.5*rho_real*(M_test*a_sound)^2;
H_tab  = ch_delta * q_test * c_real^2 * b_real;     % [Nm] vs delta [deg]

% H(delta): momento de bisagra con signo, en el sentido de +delta. Satura en el rango de la LUT.
H_pp = pchip(dv, H_tab);
H_lut_deg = @(d_deg) ppval(H_pp, min(max(d_deg, dv(1)), dv(end)));

% --- Parámetros Temporales para Dinámicas ---
tau_drv = 1/(2*pi*bw_driver);
alpha_drv = dt_sim / (tau_drv + dt_sim);

tau_thermal = 10;                 % Constante de tiempo de calentamiento [s]
alpha_th = dt_sim / (tau_thermal + dt_sim);

fprintf('=== PERFIL TEMPORAL Y LUT GENERADOS ===\n');
fprintf('Pasos de simulación: %d | Planta: %d Hz | Kalman/sensores: %d Hz\n', N, fs_sim, fs_kf);
fprintf('Escenario %d: M=%.2f, AoA=%d° | LUT: H en [%.3f, %.3f] Nm para delta en [%d, %d]°\n\n', ...
    escenario, M_test, aoa_test, min(H_tab), max(H_tab), dv(1), dv(end));
