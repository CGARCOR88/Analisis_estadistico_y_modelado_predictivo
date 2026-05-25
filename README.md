# Analisis_estadistico_y_modelado_predictivo 🧬💻

Este proyecto implementa un **pipeline de datos modular** y un modelo predictivo para el análisis del dataset **Pima Indians Diabetes**. El sistema está diseñado bajo principios de ingeniería de software: desacoplado, parametrizado, con gestión de entornos virtuales (`renv`), registro automatizado de logs, pruebas unitarias y script de inferencia.

## 📁 Estructura del Proyecto

```text
├── data/                        # Datasets preprocesados (ignorados en Git)
│   ├── .gitkeep
│   └── pima_diabetes_clean.csv  # CSV con ceros convertidos a NA
├── scripts/                     # Scripts del pipeline (ejecución secuencial)
│   ├── utils.R                  # Funciones compartidas (VIF, AUC, métricas, Brier, HL)
│   ├── 01_data_ingestion.R      # Descarga, validación, limpieza ceros → NA
│   ├── 02_exploratory_analysis.R# EDA: estadísticas, NAs, balanceo, boxplot
│   ├── 03_predictive_modeling.R # MI PMM → GLM pooled → VIF → métricas → CV → LASSO → ROC
│   └── 04_predict.R             # (Opcional) Inferencia sobre nuevos datos
├── tests/                       # Pruebas unitarias automatizadas (testthat)
│   └── test_pipeline.R          # 5 bloques de test, 31 aserciones
├── results/                     # Artefactos generados (ignorados en Git)
│   ├── logs/
│   │   ├── eda_processing.log
│   │   ├── model_training.log
│   │   └── pipeline_qa.log
│   ├── plots/
│   │   ├── boxplot_glucosa_vs_outcome.png
│   │   └── roc_curve.png        # Incluye marcador del umbral óptimo de Youden
│   ├── modelo_logistico.rds     # Lista de 5 modelos GLM (imputación múltiple)
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
| `utils.R` | Funciones compartidas: `calc_vif`, `calc_auc`, `calc_metricas`, `calc_brier_score`, `hosmer_lemeshow_test` |
| `01_data_ingestion.R` | Descarga CSV, **valida dimensiones y columnas**, convierte ceros fisiológicos a `NA` |
| `02_exploratory_analysis.R` | Estadísticas descriptivas, análisis de missings, balance de clases, boxplot |
| `03_predictive_modeling.R` | Split estratificado 70/30 → **MI PMM (m=5)** → Pooling Rubin → VIF → Youden → Brier/HL → Cook → **CV k=10** → **LASSO** → ROC |
| `04_predict.R` | Carga lista de modelos + medianas, preprocesa nuevos datos, promedia predicciones de los m modelos |

**Decisiones de diseño:**
- **Imputación múltiple real (m=5):** Se entrenan 5 modelos GLM (uno por imputación). Los coeficientes se combinan con las **Reglas de Rubin** para obtener estimaciones pooled con incertidumbre correcta.
- **Predicciones promediadas:** En test y en producción, las probabilidades de los 5 modelos se promedian (Rubin para predicciones), reduciendo la varianza de imputación.
- **Sin data leakage:** `mice` solo actúa sobre el train. El test y los datos de producción se imputan con medianas calculadas exclusivamente en train.
- **Parámetros centralizados en `CONFIG`:** `proporcion_train`, `umbral_clasificacion`, `m_imputaciones` y `k_folds` se definen en `main.R` y son accesibles por todos los scripts.
- Los logs se gestionan con `sink()` + `tryCatch/finally` para garantizar el cierre de conexiones incluso ante errores.

## 📊 Resultados del Modelo

**GLM con Imputación Múltiple PMM (m=5, Reglas de Rubin)** — dataset Pima Indians Diabetes, split estratificado 70/30:

### Métricas en el set de test (umbral por defecto vs. umbral óptimo de Youden)

| Métrica | Umbral 0.50 | Umbral óptimo 0.28 |
|---------|-------------|-------------------|
| Accuracy | 74.03% | 73.59% |
| **Sensibilidad (Recall)** | 50.62% | **79.01%** |
| Especificidad | 86.67% | 70.67% |
| Precisión Positiva (PPV) | 67.21% | 59.26% |
| **F1-Score** | 0.5775 | **0.6772** |
| **AUC-ROC** | **0.8244** | — |

> El umbral óptimo de Youden (0.28) mejora la Sensibilidad de 50.6% a 79.0% y el F1 de 0.58 a 0.68, a costa de reducir la Especificidad. En cribado de diabetes, maximizar Sensibilidad es prioritario.

### Robustez y calibración

| Análisis | Resultado |
|----------|-----------|
| **AUC-ROC CV (k=10)** | **0.8413 ± 0.0532** |
| Brier Score | 0.1650 (referencia nula: 0.2277) |
| Hosmer-Lemeshow χ²(df=8) | 12.08, p = 0.1475 ✅ Buen ajuste |
| Observaciones influyentes (Cook) | 36 / 537 (6.7%) |

### Comparación con LASSO (glmnet, α=1)

| Modelo | AUC-ROC | Variables |
|--------|---------|-----------|
| GLM (MI m=5) | **0.8244** | 8 predictores |
| LASSO (λ 1SE) | 0.8140 | 5 predictores (Pregnancies, Glucose, Insulin, BMI, Age) |

> LASSO elimina automáticamente BloodPressure, SkinThickness y DiabetesPedigreeFunction, reduciendo complejidad sin pérdida significativa de AUC.

### Multicolinealidad (VIF) y significancia

**VIF:** Todos los predictores < 2 (máx. 1.958 en BMI). Sin multicolinealidad problemática.

**Variables significativas en coeficientes pooled (p < 0.05):** Glucose (\*\*\*), BMI (\*\*\*), Age (\*\*), Pregnancies (\*), DiabetesPedigreeFunction (\*).

El historial detallado se guarda en `results/logs/model_training.log`.

## 🧪 Control de Calidad (QA)

Al finalizar el pipeline se ejecutan **31 aserciones** automáticas mediante `testthat` distribuidas en 5 bloques:

1. **Dataset preprocesado**: dimensiones correctas (768×9), outcome binario, ceros eliminados, NAs presentes
2. **Modelo entrenado**: es una lista de 5 modelos GLM binomiales, cada uno con 9 coeficientes
3. **Medianas de entrenamiento**: todas las variables críticas presentes, valores positivos
4. **Artefactos visuales y logs**: ambos logs no vacíos, ambas imágenes PNG generadas
5. **Contenido del log**: presencia de "Accuracy", "Sensibilidad", "AUC-ROC", "VIF", "Brier Score", "Hosmer-Lemeshow", "Youden" y "LASSO"

Resultado: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 31 ]`

El reporte se almacena en `results/logs/pipeline_qa.log`.

## 🔍 Inferencia sobre Nuevos Datos

Para generar predicciones sobre un nuevo dataset, puedes invocar el script desde tu entorno interactivo o directamente desde la terminal del sistema:

```bash
# Desde la terminal usando Rscript
Rscript scripts/04_predict.R
```

```r
# O dentro de R
source("scripts/04_predict.R")
```

El script carga la lista de 5 modelos (`results/modelo_logistico.rds`) y las medianas de entrenamiento (`results/medianas_train.rds`), aplica el mismo preprocesamiento (ceros → NA, imputación por medianas de train), **promedia las probabilidades de los 5 modelos** y guarda las predicciones en `results/predicciones.csv`.

La ruta del archivo de entrada se configura en `CONFIG$archivo_nuevos_datos` dentro de `main.R`.

## 📈 Análisis Visual

El pipeline genera gráficos automáticamente en `results/plots/`:

* **`boxplot_glucosa_vs_outcome.png`** — Distribución de glucosa en plasma según diagnóstico.
* **`roc_curve.png`** — Curva ROC del modelo GLM (m=5), con AUC anotado y marcador del umbral óptimo de Youden.

<p align="center">
  <img src="results/plots/boxplot_glucosa_vs_outcome.png" width="45%" alt="Boxplot Glucosa" />
  <img src="results/plots/roc_curve.png" width="45%" alt="Curva ROC Youden" />
</p>

> **Nota:** Si acabas de clonar el repositorio, la carpeta `results/` se creará automáticamente tras la primera ejecución de `source("main.R")`.