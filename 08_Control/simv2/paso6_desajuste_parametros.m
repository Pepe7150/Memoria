% =========================================================================
% SCRIPT 6: DESAJUSTE DE PARÁMETROS (modelo del Kalman vs planta "real")
% =========================================================================
% El Kalman conserva los parámetros NOMINALES (paso1); la planta se perturba.
% Pregunta que responde: ¿cuánto se degrada la estimación (y la carga emulada)
% si k, J, Kt o c reales difieren de los que supone el filtro?  Sirve para
% decidir qué parámetros conviene medir primero cuando llegue el hardware.
%
% Modos:
%   modo = 1: UNO A UNO. Cada parámetro a (1 ± pct), el resto nominal.
%   modo = 2: MONTE CARLO. Todos a la vez, factor uniforme en [1-pct, 1+pct].
% Tiempo: cada corrida ~ lo que tarde main.m (decenas de segundos).
clc; clear; close all;

run('paso1_parametros_sistema.m');
escenario = 1;                       % 1, 2 o 3 (ver paso2)
run('paso2_perfiles_y_deriva.m');
run('paso3_modelo_y_kalman.m');

% ----------------------------- Configuración -----------------------------
d_pct   = 0.30;                      % desajuste relativo (±30 %)
d_modo  = 1;                         % 1: uno a uno | 2: Monte Carlo
d_nsem  = 3;                         % semillas de ruido por caso (modo 1)
d_nmc   = 20;                        % realizaciones (modo 2)
d_sel   = 1:7;                      % parámetros a incluir en modo 1 (ver nombres)
d_nombres = {'k (eje+acoples)','J_A','J_B','J_C','Kt_A','Kt_B','c (amortig.)'};
% -------------------------------------------------------------------------

% Casos: cada fila de d_F es el vector de factores [k J_A J_B J_C Kt_A Kt_B c]
d_F = ones(1,7);  d_lab = {'Nominal'};  d_par = 0;   % d_par: parámetro perturbado en cada caso (0 = nominal)
if d_modo == 1
    for d_p = d_sel
        for d_s = [-1, 1]
            d_f = ones(1,7);  d_f(d_p) = 1 + d_s*d_pct;
            d_F(end+1,:) = d_f;  d_par(end+1,1) = d_p;
            d_lab{end+1} = sprintf('%s %+d%%', d_nombres{d_p}, round(d_s*d_pct*100));
        end
    end
    d_sems = 1:d_nsem;
else
    rng(100);
    for d_r = 1:d_nmc
        d_F(end+1,:) = 1 + d_pct*(2*rand(1,7)-1);  d_par(end+1,1) = 0;
        d_lab{end+1} = sprintf('MC #%d', d_r);
    end
    d_sems = 1;
end
d_nc = size(d_F,1);  d_ns = numel(d_sems);
% Métricas: 1 T_AC, 2 T_A, 3 T_B [Nm]; 4 theta_C [deg]; 5 carga emulada [Nm]; 6 seguimiento [deg]; 7 fallo
d_R = nan(d_nc, d_ns, 7);

fprintf('Desajuste: %d casos x %d semillas = %d corridas (escenario %d)\n', d_nc, d_ns, d_nc*d_ns, escenario);
d_t0 = tic;
for d_c = 1:d_nc
    d_f = d_F(d_c,:);
    k1p = k1*d_f(1);  k2p = k2*d_f(1);  c1p = c1*d_f(7);  c2p = c2*d_f(7);
    JAp = J_A*d_f(2); JBp = J_B*d_f(3); JCp = J_C*d_f(4);
    d_Ap = [0, 1, 0, 0, 0, 0;
           -k1p/JAp, -(c1p+b_A)/JAp,  k1p/JAp,  c1p/JAp, 0, 0;
            0, 0, 0, 1, 0, 0;
            k1p/JCp,  c1p/JCp, -(k1p+k2p)/JCp, -(c1p+c2p)/JCp,  k2p/JCp,  c2p/JCp;
            0, 0, 0, 0, 0, 1;
            0, 0, k2p/JBp, c2p/JBp, -k2p/JBp, -(c2p+b_B)/JBp];
    d_Bp = [0,0; 1/JAp,0; 0,0; 0,0; 0,0; 0,-1/JBp];
    d_E  = expm([d_Ap d_Bp; zeros(2,8)]*dt_sim);        % discretización ZOH exacta
    Ad6_true = d_E(1:6,1:6);  Bd6_true = d_E(1:6,7:8);
    C_torque_true = [k1p, c1p, -k1p, -c1p, 0, 0;
                      0,   0,   k2p,  c2p, -k2p, -c2p];
    fac_Kt_A = d_f(5);  fac_Kt_B = d_f(6);

    for d_k = 1:d_ns
        rng(d_sems(d_k));
        run('paso4_bucle_simulacion.m');
        d_R(d_c,d_k,1) = rmse(T_AC_kf, T_AC_true);
        d_R(d_c,d_k,2) = rmse(T_A_kf,  T_A_true);
        d_R(d_c,d_k,3) = rmse(T_B_kf,  T_B_true);
        d_R(d_c,d_k,4) = rmse(thetaC_kf, theta_C_true)*180/pi;
        d_R(d_c,d_k,5) = rmse(T_A_true, H_lut_deg(theta_C_true*180/pi));
        d_R(d_c,d_k,6) = rmse(theta_C_true*180/pi, delta_cmd_deg);
        d_R(d_c,d_k,7) = double(system_fault);
    end
    fprintf('  [%2d/%2d] %-22s listo (%.0f s)\n', d_c, d_nc, d_lab{d_c}, toc(d_t0));
end

% ------------------------------- Reporte ---------------------------------
d_m = squeeze(mean(d_R,2));  if d_ns == 1, d_m = reshape(d_R,d_nc,7); end
fprintf('\n=== DESAJUSTE DE PARÁMETROS: escenario %d, ±%d%% (promedio de %d semillas) ===\n', escenario, round(d_pct*100), d_ns);
fprintf('%-24s | %9s %9s %9s | %9s | %11s | %9s | %s\n', 'Caso', 'T_AC mNm', 'T_A mNm', 'T_B mNm', 'th_C deg', 'carga mNm', 'segu. deg', 'fallos');
for d_c = 1:d_nc
    fprintf('%-24s | %9.2f %9.2f %9.2f | %9.4f | %11.2f | %9.3f | %d\n', d_lab{d_c}, ...
        1e3*d_m(d_c,1), 1e3*d_m(d_c,2), 1e3*d_m(d_c,3), d_m(d_c,4), 1e3*d_m(d_c,5), d_m(d_c,6), round(sum(d_R(d_c,:,7))));
end
fprintf('(T_AC, T_A, T_B, th_C: RMSE de la ESTIMACIÓN Kalman vs verdad. carga: RMSE de T_A real vs H_LUT(theta_C real).\n');
fprintf(' segu.: RMSE del ángulo real de la aleta vs consigna.)\n');

if d_modo == 1
    fprintf('\nRanking de sensibilidad (peor caso de cada parámetro / nominal):\n');
    d_rat = zeros(numel(d_sel),1);
    for d_j = 1:numel(d_sel)
        d_rat(d_j) = max(d_m(d_par == d_sel(d_j), 1)) / d_m(1,1);
    end
    [~, d_ord] = sort(d_rat, 'descend');
    for d_j = d_ord(:)'
        fprintf('  %-18s  T_AC x%.2f\n', d_nombres{d_sel(d_j)}, d_rat(d_j));
    end
end
save(sprintf('desajuste_esc%d.mat', escenario), 'd_R', 'd_F', 'd_lab', 'd_pct', 'escenario');