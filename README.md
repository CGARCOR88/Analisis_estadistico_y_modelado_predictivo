# # Analisis_estadistico_y_modelado_predictivo 🧬💻

Este proyecto implementa un pipeline de datos modular y un modelo predictivo para el análisis del dataset **Pima Indians Diabetes**. El sistema está diseñado bajo principios de ingeniería de software: desacoplado, parametrizado, con gestión de entornos virtuales (`renv`), registro automatizado de logs y pruebas unitarias.

## 📁 Estructura del Proyecto

```text
├── data/               # Datasets originales e imputados (Ignorados en Git)
├── scripts/            # Scripts del pipeline
│   ├── 01_data_ingestion.R
│   ├── 02_exploratory_analysis.R
│   └── 03_predictive_modeling.R
├── tests/              # Pruebas unitarias automatizadas
│   ├── test_pipeline.R
├── results/            # Artefactos generados (Ignorados en Git)
│   ├── logs/           # Registros de ejecución (.log)
│   └── plots/          # Gráficos generados (.png)
├── main.R              # Orquestador principal (Fichero de configuración)
├── renv.lock           # Bloqueo de versiones de librerías
└── README.md

## 🚀 Instalación y Ejecución

Para garantizar la **reproducibilidad científica**, el proyecto utiliza `renv` para aislar las librerías necesarias (como `mice`, `testthat` o `tidyverse`).

1. **Clona el repositorio** en tu máquina local:
   ```bash
    git clone [https://github.com/CGARCOR88/Analisis_estadistico_y_modelado_predictivo.git](https://github.com/CGARCOR88/Analisis_estadistico_y_modelado_predictivo.git)
    cd Analisis_estadistico_y_modelado_predictivo

2. Abre el proyecto en tu entorno de R (VS Code o RStudio).

3. Restaura el entorno virtual ejecutando en la consola de R:
    R
    renv::restore()

4. Ejecuta el pipeline completo desde el orquestador raíz:
    R
    source("main.R")

Resultados y Control de Calidad
Control de Calidad (QA): Al finalizar el pipeline, se ejecutan pruebas unitarias automáticas mediante testthat que validan la integridad del dataset (ausencia de NAs tras la imputación por PMM y dimensiones correctas del set de datos). El reporte se almacena en results/logs/pipeline_qa.log.

Métricas del Modelo: El modelo base de Regresión Logística arroja actualmente una Precisión Global (Accuracy) del 74.89% en el set de prueba independiente (30% de los datos). El historial detallado se guarda en results/logs/model_training.log.

Análisis Visual
El pipeline genera análisis exploratorios automáticos. A continuación se muestra la distribución de los niveles de glucosa en plasma en función del diagnóstico clínico:

(Nota: Si acabas de clonar el repositorio, la carpeta results/ se creará automáticamente tras la primera ejecución).