# Statistical_Analysis_and_Predictive_Modeling

This project implements a **modular data pipeline** and a predictive model to analyze the **Pima Indians Diabetes** dataset. The system is designed following software engineering principles: decoupled, parameterized, featuring virtual environment management (`renv`), automated logging, unit testing, and an inference script.

## 📁 Project Structure

```text
├── data/                        # Preprocessed datasets (Git ignored)
│   ├── .gitkeep
│   └── pima_diabetes_clean.csv  # CSV with zeros converted to NA
├── scripts/                     # Pipeline scripts (sequential execution)
│   ├── utils.R                  # Shared functions (VIF, AUC, metrics, Brier, HL)
│   ├── 01_data_ingestion.R      # Download, validation, zero → NA cleaning
│   ├── 02_exploratory_analysis.R# EDA: statistics, NAs, class balance, boxplots
│   ├── 03_predictive_modeling.R # MI PMM → GLM pooled → VIF → metrics → CV → LASSO → ROC
│   └── 04_predict.R             # (Optional) Inference on new data
├── tests/                       # Automated unit tests (testthat)
│   └── test_pipeline.R          # 5 test blocks, 31 assertions
├── results/                     # Generated artifacts (Git ignored)
│   ├── logs/
│   │   ├── eda_processing.log
│   │   ├── model_training.log
│   │   └── pipeline_qa.log
│   ├── plots/
│   │   ├── boxplot_glucosa_vs_outcome.png
│   │   └── roc_curve.png        # Includes optimal Youden threshold marker
│   ├── modelo_logistico.rds     # List of 5 GLM models (multiple imputation)
│   └── medianas_train.rds       # Training set medians
├── main.R                       # Main orchestrator + global CONFIG
├── renv.lock                    # Library version lockfile
└── README.md
```

## Installation and Execution

To guarantee scientific reproducibility, this project uses renv to isolate the required libraries.

1. **Clone the repository** to your local machine:

    ```bash
    git clone https://github.com/CGARCOR88/Analisis_estadistico_y_modelado_predictivo.git
    cd Analisis_estadistico_y_modelado_predictivo
    ```

2.Open the project in your R environment (VS Code or RStudio).

3. **Restore the virtual environment** by running the following in the R console

    ```r
    renv::restore()
    ```

4. **Run the complete pipeline** from the root orchestrator:
    ```r
    source("main.R")
    ```

## Pipeline Design

| Script | Responsabilidad |
|--------|----------------|
| `utils.R` | Shared functions: `calc_vif`, `calc_auc`, `calc_metricas`, `calc_brier_score`, `hosmer_lemeshow_test` |
| `01_data_ingestion.R` | Downloads CSV, **validates dimensions and columns**, converts physiological zeros to NA |
| `02_exploratory_analysis.R` | EDescriptive statistics, missing values analysis, class balance, boxplots |
| `03_predictive_modeling.R` | Stratified 70/30 split → **MI PMM (m=5)** → Rubin's Pooling → VIF → Youden → Brier/HL → Cook's D → **10-fold CV** → LASSO → ROC |
| `04_predict.R` | Loads model list + medians, preprocesses new data, averages predictions across the m models |

**Design Decisions:**
- **True Multiple Imputation (m=5):** 5 GLM models are trained (one per imputation). Coeficients are combined using **Rubin's Rules** to obtain pooled estimates with correct uncertainty propagation.
- **Averaged Predictions:**In testing and production, probabilities from the 5 models are averaged (Rubin's approach for predictions), reducing imputation variance.
- **No Data Leakage:** `mice` only operates on the training set. The test set and production data are imputed using medians calculated exclusively from the training set.
- **Centralized Parameters in `CONFIG`:** `proporcion_train`, `umbral_clasificacion`, `m_imputaciones` and `k_folds` are defined in `main.R` and are globally accessible by all scripts.
- Logs are managed via `sink()` + `tryCatch/finally` to guarantee that connections close properly even if an error occurs.

## Model Results

**GLM with PMM Multiple Imputation (m=5, Rubin's Rules)** — Pima Indians Diabetes dataset, stratified 70/30 split:

### Test Set Metrics (Default Threshold vs. Optimal Youden Threshold)

| Metric | Threshold 0.50 | Optimal Threshold 0.28 |
|---------|------------|-------------------|
| Accuracy | 74.03% | 73.59% |
| **Sensitivity (Recall)** | 50.62% | **79.01%** |
| Specificity | 86.67% | 70.67% |
| Positive Predictive Value (PPV) | 67.21% | 59.26% |
| **F1-Score** | 0.5775 | **0.6772** |
| **AUC-ROC** | **0.8244** | — |

> The optimal Youden threshold (0.28) improves Sensitivity from 50.6% to 79.0% and the F1-Score from 0.58 to 0.68, at the cost of lower Specificity. For diabetes screening, maximizing Sensitivity is the priority.

### Robustness and Calibration

| Análysis | Result |
|----------|-----------|
| **AUC-ROC CV (k=10)** | **0.8413 ± 0.0532** |
| Brier Score | 0.1650 (referencia nula: 0.2277) |
| Hosmer-Lemeshow χ²(df=8) | 12.08, p = 0.1475 ✅ Buen ajuste |
| Influential Observations (Cook) | 36 / 537 (6.7%) |

### Comparación con LASSO (glmnet, α=1)

| Model | AUC-ROC | Features |
|--------|---------|-----------|
| GLM (MI m=5) | **0.8244** | 8 predictores |
| LASSO (λ 1SE) | 0.8140 | 5 predictors (Pregnancies, Glucose, Insulin, BMI, Age) |

> LASSO automatically drops BloodPressure, SkinThickness, and DiabetesPedigreeFunction, reducing model complexity without any significant drop in AUC.

### Multicollinearity (VIF) and Significance

**VIF:** All predictors < 2 (max. 1.958 for BMI). No problematic multicollinearity detected.

**Significant variables in pooled coefficients (p < 0.05):** Glucose (\*\*\*), BMI (\*\*\*), Age (\*\*), Pregnancies (\*), DiabetesPedigreeFunction (\*).

The detailed execution history is saved in `results/logs/model_training.log`.

## Quality Control (QA)

At the end of the pipeline, **31 automated** assertions are executed via testthat, distributed across 5 blocks:

1. **Preprocessed Dataset:**: correct dimensions (768×9), binary outcome, zeros removed, NAs present.
2. **Trained Model**: confirms it is a list of 5 binomial GLM models, each with 9 coefficients.
3. **Training Medians**: all critical variables present, values are positive
4. **Visual Artifacts and Logs**: both logs are non-empty, both PNG plots are generated.
5. **Log Content**: checks for the presence of "Accuracy", "Sensibilidad", "AUC-ROC", "VIF", "Brier Score", "Hosmer-Lemeshow", "Youden", and "LASSO".

Output: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 31 ]`

The QA report is stored in `results/logs/pipeline_qa.log`.

## Inference on New Data

To generate predictions on a new dataset, you can invoke the script from your interactive environment or directly from the system terminal:

```bash
# Desde la terminal usando Rscript
Rscript scripts/04_predict.R
```

```r
# O dentro de R
source("scripts/04_predict.R")
```

he script loads the list of 5 models (`results/modelo_logistico.rds`) and the training medians (`results/medianas_train.rds`), applies the same preprocessing steps (zeros → NA, training median imputation), **averages the probabilities across the 5 models**, and saves the predictions to `results/predicciones.csv`.

The input file path can be configured via `CONFIG$archivo_nuevos_datos` inside `main.R`.

## Visual Analysis

The pipeline automatically generates plots in `results/plots/`:

* **`boxplot_glucosa_vs_outcome.png`** — Plasma glucose distribution grouped by diagnosis outcome.
* **`roc_curve.png`** — ROC curve for the GLM model (m=5), complete with annotated AUC and the optimal Youden threshold marker.

<p align="center">
  <img src="results/plots/boxplot_glucosa_vs_outcome.png" width="45%" alt="Boxplot Glucosa" />
  <img src="results/plots/roc_curve.png" width="45%" alt="Curva ROC Youden" />
</p>

> **Note:** If you have just cloned the repository, the `results/` folder will be created automatically after running `source("main.R")` for the first time.