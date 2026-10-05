% =========================================================================
% SCRIPT 3: MATRICES DEL SISTEMA, FILTRO DE KALMAN Y OBSERVABILIDAD
% =========================================================================

% --- Planta Mecánica Real (6 Estados) ---
Ac6 = [0, 1, 0, 0, 0, 0;
      -k1/J_A, -(c1+b_A)/J_A,  k1/J_A,  c1/J_A, 0, 0;
       0, 0, 0, 1, 0, 0;
       k1/J_C,  c1/J_C, -(k1+k2)/J_C, -(c1+c2)/J_C,  k2/J_C,  c2/J_C;
       0, 0, 0, 0, 0, 1;
       0, 0, k2/J_B, c2/J_B, -k2/J_B, -(c2+b_B)/J_B];
Bc6 = [0,0; 1/J_A,0; 0,0; 0,0; 0,0; 0,-1/J_B];

C_torque = [k1, c1, -k1, -c1,  0,   0; 
             0,  0,  k2,  c2, -k2, -c2];

sys_c = ss(Ac6, Bc6, eye(6), zeros(6,2));
sys_d = c2d(sys_c, dt_sim, 'zoh');
Ad6 = sys_d.A; 
Bd6 = sys_d.B;

% --- Modelo Ampliado del Kalman (14 Estados Ordenados) ---
nx = 14; 
Ac14 = zeros(nx,nx);

Ac14(1:6, 1:6) = Ac6;
Ac14(1:6, 7:8) = Bc6;

tau_imu_c = 1/(2*pi*bw_imu); 
tau_sg_c = 1/(2*pi*bw_strain);

Ac14(9,4)  = 1/tau_imu_c;    Ac14(9,9)   = -1/tau_imu_c;      
Ac14(10,1:6) = C_torque(1,:) / tau_sg_c;
Ac14(10,10)  = -1/tau_sg_c;                                   

Ac14(11,11) = -1 / tau_b_IA;   
Ac14(12,12) = -1 / tau_b_IB;   
Ac14(13,13) = -1 / tau_b_imu;  
Ac14(14,14) = -1 / tau_b_sg;   

Adk = expm(Ac14*dt_sim); 

H = zeros(6,nx); 
H(1,1)  = 1;               
H(2,5)  = 1;               
H(3,7)  = 1; H(3,11) = Kt_A;  % <- CORREGIDO: Escalamiento por Kt_A
H(4,8)  = 1; H(4,12) = Kt_B;  % <- CORREGIDO: Escalamiento por Kt_B
H(5,9)  = 1; H(5,13) = 1;  
H(6,10) = 1; H(6,14) = 1;  

noise_hall_std = 0.002; noise_current_std = 0.03;
noise_gyro_std = 0.02;  noise_strain_std  = 0.005;

bias_hallA = 0.05;     bias_hallB = -0.03;
bias_currentA_0 = 0.1; bias_currentB_0 = -0.08;
bias_imu_0 = 0.2;      bias_sg_0 = 0.15;

O_mat = obsv(Adk, H);
rank_O = rank(O_mat);
cond_O = cond(O_mat);

tau_hall = 1/(2*pi*bw_hall);       alpha_hall = dt_sim/(tau_hall+dt_sim);
tau_cs = 1/(2*pi*bw_current_filt);   alpha_cs = dt_sim/(tau_cs+dt_sim);
tau_imu = 1/(2*pi*bw_imu);         alpha_imu = dt_sim/(tau_imu+dt_sim);
tau_sg = 1/(2*pi*bw_strain);       alpha_sg = dt_sim/(tau_sg+dt_sim);

var_hall = noise_hall_std^2 * alpha_hall/(2-alpha_hall);
var_IA   = noise_current_std^2 * alpha_cs/(2-alpha_cs);
var_imu  = noise_gyro_std^2 * alpha_imu/(2-alpha_imu);
var_sg   = noise_strain_std^2 * alpha_sg/(2-alpha_sg);

R = diag([var_hall, var_hall, (Kt_A^2)*var_IA, (Kt_B^2)*var_IA, var_imu, var_sg]);

% <- CORREGIDO: q_b ahora se define puramente en Amperes, sin multiplicar por Kt
q_b_IA  = (2 * sigma_b_IA^2)           / tau_b_IA;
q_b_IB  = (2 * sigma_b_IB^2)           / tau_b_IB;
q_b_imu = (2 * sigma_b_imu^2)          / tau_b_imu;
q_b_sg  = (2 * sigma_b_sg^2)           / tau_b_sg;

% <- CORREGIDO: Se reemplaza q_b_TA por q_b_IA y q_b_TB por q_b_IB
Q = diag([1e-10, 5e-5, 1e-10, 5e-5, 1e-10, 5e-5, ... 
          0.01*dt_sim, 0.01*dt_sim, ...              
          1e-8, 1e-8, ...                            
          q_b_IA * dt_sim, q_b_IB * dt_sim, ...      
          q_b_imu * dt_sim, q_b_sg * dt_sim]);       

P_temp = diag([1e-4, 1, 1e-4, 1, 1e-4, 1, 10, 10, 1, 1, 1, 1, 1, 1]);                  

for iter = 1:500 
    P_pred = Adk*P_temp*Adk' + Q;
    S = H*P_pred*H' + R;
    K_kalman_steady = (P_pred*H') / S;
    P_temp = (eye(nx) - K_kalman_steady*H)*P_pred;
end

fprintf('=== CONFIGURACIÓN DE KALMAN Y OBSERVABILIDAD COMPLETADA ===\n');
fprintf('Rango de Observabilidad: %d/%d (Condición: %.2e)\n\n', rank_O, nx, cond_O);