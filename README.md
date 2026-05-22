# Analisis_estadistico_y_modelado_predictivo 🧬💻

Este proyecto implementa un **pipeline de datos modular** y un modelo predictivo para el análisis del dataset **Pima Indians Diabetes**. El sistema está diseñado bajo principios de ingeniería de software: desacoplado, parametrizado, con gestión de entornos virtuales (`renv`), registro automatizado de logs, pruebas unitarias y script de inferencia.

## 📁 Estructura del Proyecto

```text
├── data/                        # Datasets preprocesados (ignorados en Git)
│   ├── .gitkeep                 # Mantiene la estructura en el repositorio
│   └── pima_diabetes_clean.csv  # CSV con ceros convertidos a NA
├── scripts/                     # Scripts del pipeline (ejecución secuencial)
│   ├── 01_data_ingestion.R      # Descarga, limpieza de ceros → NA y guardado
│   ├── 02_exploratory_analysis.R# EDA: estadísticas, NAs, balanceo, boxplot
│   ├── 03_predictive_modeling.R # Split estratificado, imputación, GLM, métricas
│   └── 04_predict.R             # (Opcional) Inferencia sobre nuevos datos
├── tests/                       # Pruebas unitarias automatizadas (testthat)
│   └── test_pipeline.R          # 5 bloques de test, 23 aserciones
├── results/                     # Artefactos generados (ignorados en Git)
│   ├── logs/                    # Registros de ejecución (.log)
│   │   ├── eda_processing.log
│   │   ├── model_training.log
│   │   └── pipeline_qa.log
│   ├── plots/                   # Gráficos generados (.png)
│   │   ├── boxplot_glucosa_vs_outcome.png
│   │   └── roc_curve.png
│   ├── modelo_logistico.rds     # Modelo GLM serializado
│   └── medianas_train.rds       # Medianas del set de entrenamiento
├── main.R                       # Orquestador principal + CONFIG global
├── renv.lock                    # Bloqueo de versiones de librerías
└── README.md
```

## 🚀 Instalación y Ejecución

Para garantizar la **reproducibilidad científica**, el proyecto utiliza `renv` para aislar las librerías necesarias.

1. **Clona el repositorio** en tu máquina local:

    ```bash
    git clone https://github.com/CGARCOR88/Analisis_estadistico_y_modelado_predictivo.git
    cd Analisis_estadistico_y_modelado_predictivo
    ```

2. Abre el proyecto en tu entorno de R (VS Code o RStudio).

3. **Restaura el entorno virtual** ejecutando en la consola de R:

    ```r
    renv::restore()
    ```

4. **Ejecuta el pipeline completo** desde el orquestador raíz:

    ```r
    source("main.R")
    ```

## ⚙️ Diseño del Pipeline

| Script | Responsabilidad |
|--------|----------------|
| `01_data_ingestion.R` | Descarga CSV desde URL, convierte ceros fisiológicamente imposibles en `NA`, guarda dataset limpio |
| `02_exploratory_analysis.R` | Estadísticas descriptivas, análisis de missings, balance de clases, boxplot Glucosa vs Outcome |
| `03_predictive_modeling.R` | Split **estratificado** 70/30, imputación **mice (PMM)** solo en train, imputación por medianas en test, regresión logística `glm`, verificación de **VIF**, métricas completas, curva ROC |
| `04_predict.R` | (Opcional) Carga modelo + medianas, preprocesa nuevos datos, genera predicciones con probabilidad y clase |

**Decisiones de diseño relevantes:**
- La imputación múltiple (`mice`) se aplica **únicamente al set de entrenamiento** para evitar data leakage. El test se imputa con las medianas calculadas en train.
- Toda la configuración (rutas, semilla, nombres de columnas) se centraliza en el objeto `CONFIG` de `main.R`.
- Los logs se gestionan con `sink()` + `tryCatch/finally` para garantizar el cierre de conexiones incluso ante errores.

## 📊 Resultados del Modelo

Regresión Logística (`glm`, familia binomial) entrenada sobre el 70% del dataset con split estratificado:

| Métrica | Valor |
|---------|-------|
| Accuracy (Precisión Global) | **73.59%** |
| Sensibilidad (Recall) | 49.38% |
| Especificidad | 86.67% |
| Precisión Positiva (PPV) | 66.67% |
| F1-Score | 0.5674 |
| **AUC-ROC** | **0.8226** |

**Multicolinealidad (VIF):** Todos los predictores presentan VIF < 2 (máx. 1.847 en BMI). No se detecta multicolinealidad problemática.

**Variables significativas (p < 0.05):** Glucose (\*\*\*), BMI (\*\*\*), Age (\*\*), Pregnancies (\*).

El historial detallado se guarda en `results/logs/model_training.log`.

## 🧪 Control de Calidad (QA)

Al finalizar el pipeline se ejecutan **23 aserciones** automáticas mediante `testthat` distribuidas en 5 bloques:

1. **Dataset preprocesado**: dimensiones correctas (768×9), outcome binario, ceros eliminados, NAs presentes
2. **Modelo entrenado**: clase `glm`, familia binomial, 9 coeficientes
3. **Medianas de entrenamiento**: todas las variables críticas presentes, valores positivos
4. **Artefactos visuales y logs**: ambos logs no vacíos, ambas imágenes PNG generadas
5. **Contenido del log de entrenamiento**: presencia de "Accuracy", "Sensibilidad", "AUC-ROC" y "VIF"

Resultado: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 23 ]`

El reporte se almacena en `results/logs/pipeline_qa.log`.

## 🔍 Inferencia sobre Nuevos Datos

Para generar predicciones sobre un nuevo dataset, ejecuta el script opcional:

```r
source("scripts/04_predict.R")
```

El script carga el modelo (`results/modelo_logistico.rds`) y las medianas de entrenamiento (`results/medianas_train.rds`), aplica el mismo preprocesamiento (ceros → NA, imputación por medianas de train) y guarda las predicciones en `results/predicciones.csv`.

La ruta del archivo de entrada se configura en `CONFIG$archivo_nuevos_datos` dentro de `main.R`.

## 📈 Análisis Visual

El pipeline genera gráficos exploratorios automáticamente. La distribución de glucosa en plasma según el diagnóstico y la curva ROC del modelo se guardan en `results/plots/`.

> **Nota:** Si acabas de clonar el repositorio, la carpeta `results/` se creará automáticamente tras la primera ejecución de `source("main.R")`.