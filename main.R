# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT PRINCIPAL: main.R (Orquestador Modular)
# Objetivo: Definir parámetros globales y ejecutar secuencialmente el pipeline.
# ==============================================================================

# --- PARAMETRIZACIÓN GLOBAL (Modifica solo aquí si cambias de proyecto) ---


CONFIG <- list(
  url_datos          = "https://raw.githubusercontent.com/jbrownlee/Datasets/master/pima-indians-diabetes.data.csv",
  columnas_input     = c("Pregnancies", "Glucose", "BloodPressure", "SkinThickness", 
                         "Insulin", "BMI", "DiabetesPedigreeFunction", "Age", "Outcome"),
  variables_con_nas  = c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI"),
  variable_objetivo  = "Outcome",
  semilla            = 123,

  # Parámetros del modelo
  proporcion_train     = 0.7,   # Proporción de datos para entrenamiento
  umbral_clasificacion = 0.5,   # Umbral de clasificación (optimizable con Youden)
  m_imputaciones       = 5,     # Número de imputaciones PMM (imputación múltiple)
  k_folds              = 10,    # Folds para validación cruzada k-fold

  # Rutas de almacenamiento
  archivo_datos_clean  = "data/pima_diabetes_clean.csv",
  archivo_modelo       = "results/modelo_logistico.rds",
  archivo_medianas     = "results/medianas_train.rds",
  archivo_nuevos_datos = "data/pima_diabetes_clean.csv",  # Sustituir por nuevos datos en producción
  archivo_predicciones = "results/predicciones.csv",
  grafico_output       = "results/plots/boxplot_glucosa_vs_outcome.png",
  grafico_roc          = "results/plots/roc_curve.png",
  log_eda              = "results/logs/eda_processing.log",
  log_modelo           = "results/logs/model_training.log"
)

# Cargar funciones de utilidad compartidas
source("scripts/utils.R")

print("🚀 INICIANDO PIPELINE DE DATOS MODULAR...")

# Crear la estructura de carpetas de resultados si no existen
if(!dir.exists("results")) dir.create("results")
if(!dir.exists("results/logs")) dir.create("results/logs")
if(!dir.exists("results/plots")) dir.create("results/plots")

# 1. Ejecutar Ingesta y Limpieza
print("--> Ejecutando Script 01: Ingesta de Datos...")
tryCatch(
  source("scripts/01_data_ingestion.R", local = FALSE),
  error = function(e) stop(paste("FALLO en Script 01:", conditionMessage(e)))
)

# 2. Ejecutar Análisis Exploratorio (EDA)
print("--> Ejecutando Script 02: Análisis Exploratorio...")
tryCatch(
  source("scripts/02_exploratory_analysis.R", local = FALSE),
  error = function(e) stop(paste("FALLO en Script 02:", conditionMessage(e)))
)

# 3. Ejecutar Modelado Predictivo
print("--> Ejecutando Script 03: Modelado Predictivo...")
tryCatch(
  source("scripts/03_predictive_modeling.R", local = FALSE),
  error = function(e) stop(paste("FALLO en Script 03:", conditionMessage(e)))
)

# 4. Ejecutar Tests Unitarios de Calidad
print("--> Ejecutando Tests Unitarios de Calidad...")

log_qa <- file("results/logs/pipeline_qa.log", open = "wt")
sink(log_qa, type = "output")
sink(log_qa, type = "message")

tryCatch({
  library(testthat)
  test_results <- test_file("tests/test_pipeline.R")
}, finally = {
  sink(type = "message")
  sink(type = "output")
  close(log_qa)
})

print("🏁 ¡PIPELINE FINALIZADO! Reporte de calidad guardado en results/logs/pipeline_qa.log")

# INFERENCIA (opcional): Para predecir sobre datos nuevos, ajusta
# CONFIG$archivo_nuevos_datos y ejecuta:
#   source("scripts/04_predict.R")