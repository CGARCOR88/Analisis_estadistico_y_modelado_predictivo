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
  
  # Rutas de almacenamiento
  archivo_datos_clean = "data/pima_diabetes_clean.csv",
  grafico_output      = "results/plots/boxplot_glucosa_vs_outcome.png",
  log_eda             = "results/logs/eda_processing.log",
  log_modelo          = "results/logs/model_training.log"
)

print("🚀 INICIANDO PIPELINE DE DATOS MODULAR...")

# Crear la estructura de carpetas de resultados si no existen
if(!dir.exists("results")) dir.create("results")
if(!dir.exists("results/logs")) dir.create("results/logs")
if(!dir.exists("results/plots")) dir.create("results/plots")

# 1. Ejecutar Ingesta y Limpieza
print("--> Ejecutando Script 01: Ingesta de Datos...")
source("scripts/01_data_ingestion.R", local = FALSE)

# 2. Ejecutar Análisis Exploratorio (EDA)
print("--> Ejecutando Script 02: Análisis Exploratorio...")
source("scripts/02_exploratory_analysis.R", local = FALSE)

# 3. Ejecutar Modelado Predictivo
print("--> Ejecutando Script 03: Modelado Predictivo...")
source("scripts/03_predictive_modeling.R", local = FALSE)

# 4. Ejecutar Tests Unitarios de Calidad
print("--> Ejecutando Tests Unitarios de Calidad...")

# Abrimos un log específico para el control de calidad (QA)
log_qa <- file("results/logs/pipeline_qa.log", open = "wt")
sink(log_qa, type = "output")
sink(log_qa, type = "message")

library(testthat)
# Ejecutamos el test (la salida se escribirá en el log)
test_results <- test_file("tests/test_pipeline.R")

# Cerramos el log y devolvemos el control a la pantalla
sink(type = "message")
sink(type = "output")
close(log_qa)

print("🏁 ¡PIPELINE FINALIZADO! Reporte de calidad guardado en results/logs/pipeline_qa.log")