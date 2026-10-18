% =========================================================================
% SCRIPT PRINCIPAL: EJECUCIÓN MODULAR COMPLETA
% =========================================================================
clc; clear; close all;

run('paso1_parametros_sistema.m');

escenario = 2;   % 1: rampa lenta ±15° | 2: carga máxima con escalones | 3: barrido senoidal ±5°
run('paso2_perfiles_y_deriva.m');
run('paso3_modelo_y_kalman.m');
run('paso4_bucle_simulacion.m');
run('paso5_graficos_y_metricas.m');
