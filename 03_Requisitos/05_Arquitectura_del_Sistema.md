# Arquitectura del Sistema

## Descripción general

CFD

↓

Base de datos aerodinámica

↓

Software de procesamiento

↓

Banco de ensayos

↓

Adquisición de datos

↓

Resultados


OFFLINE
+-------------------------------+
|                            		        |
|      OpenFOAM / CFD            |
|             │                 	        |
|             ▼                 	        |
|  Tablas aerodinámicas           |
|             │                 	        |
|             ▼                 		|
|  Procesamiento (Python)       |
+-------------┬-----------------+
              │
              │ Archivo CSV / JSON
              ▼
         ONLINE (Banco)
+------------------------------------+
|                                			|
|  Lectura de tablas             		|
|            │                   			|
|            ▼                   			|
|  Interpolación                 		|
|            │                   			|
|            ▼                   			|
|  Torque objetivo               		|
|            │                   			|
|            ▼                   			|
|  Controlador                  		|
|            │                   			|
|            ▼                   		    	|
|  Actuador + Instrumentación    	|
+------------------------------------+

## Subsistemas

### Módulo CFD

* Obtención de cargas aerodinámicas.
* Generación de tablas.

### Módulo de procesamiento

* Lectura de tablas.
* Interpolación.
* Selección de escenarios.

### Banco

* Aplicación del torque.
* Instrumentación.
* Medición.

### Adquisición de datos

* Registro.
* Exportación.
* Visualización.

## Interfaces

## Diagrama de bloques

## Supuestos de diseño
