library(testthat)
library(readr)

# testthat::test_file() cambia el working directory al directorio del test.
# Nos aseguramos de estar en la raíz del proyecto para que las rutas relativas funcionen.
if (basename(getwd()) == "tests") setwd("..")

# Helper: accede a CONFIG si existe, si no usa el valor por defecto
cfg <- function(key, default) if (exists("CONFIG")) CONFIG[[key]] else default

# ==============================================================================
# TEST 1: Dataset preprocesado (script 01)
# ==============================================================================
test_that("El dataset preprocesado existe y tiene estructura correcta", {

  ruta_datos <- cfg("archivo_datos_clean", "data/pima_diabetes_clean.csv")
  expect_true(file.exists(ruta_datos))

  datos <- read_csv(ruta_datos, show_col_types = FALSE)

  # Dimensiones Pima: 768 filas, 9 columnas
  expect_equal(nrow(datos), 768)
  expect_equal(ncol(datos), 9)

  # Variable objetivo binaria (0 o 1)
  expect_true(all(datos$Outcome %in% c(0, 1), na.rm = TRUE))

  variables_criticas <- cfg("variables_con_nas",
    c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI"))

  # Los ceros deben haberse convertido en NA (no quedar como 0)
  ceros_restantes <- sum(datos[, variables_criticas] == 0, na.rm = TRUE)
  expect_equal(ceros_restantes, 0)

  # Deben existir NAs (confirma conversión, no eliminación de filas)
  expect_gt(sum(is.na(datos[, variables_criticas])), 0)
})

# ==============================================================================
# TEST 2: Modelo entrenado (script 03)
# ==============================================================================
test_that("El modelo entrenado es válido y tiene la estructura correcta", {

  ruta_modelo <- cfg("archivo_modelo", "results/modelo_logistico.rds")
  expect_true(file.exists(ruta_modelo))

  modelo_obj <- readRDS(ruta_modelo)
  m_imp      <- cfg("m_imputaciones", 5)

  # modelo_obj es una lista con m modelos GLM (imputación múltiple)
  expect_true(is.list(modelo_obj))
  expect_true("modelos" %in% names(modelo_obj))
  expect_equal(length(modelo_obj$modelos), m_imp)

  # Cada modelo individual es un GLM binomial con 9 coeficientes
  expect_s3_class(modelo_obj$modelos[[1]], "glm")
  expect_equal(modelo_obj$modelos[[1]]$family$family, "binomial")
  # 8 predictores + intercepto = 9 coeficientes
  expect_equal(length(coef(modelo_obj$modelos[[1]])), 9)
})

# ==============================================================================
# TEST 3: Artefacto de imputación — medianas del train (script 03)
# ==============================================================================
test_that("Las medianas de entrenamiento están guardadas y son válidas", {

  ruta_medianas <- cfg("archivo_medianas", "results/medianas_train.rds")
  expect_true(file.exists(ruta_medianas))

  medianas        <- readRDS(ruta_medianas)
  vars_esperadas  <- cfg("variables_con_nas",
    c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI"))

  # Contiene exactamente las variables de imputación
  expect_true(all(vars_esperadas %in% names(medianas)))

  # Todos los valores son positivos (medidas fisiológicas no pueden ser <= 0)
  expect_true(all(medianas > 0))
})

# ==============================================================================
# TEST 4: Artefactos visuales y logs generados (scripts 02 y 03)
# ==============================================================================
test_that("Los logs y gráficos del pipeline se han generado correctamente", {

  ruta_log_eda    <- cfg("log_eda",        "results/logs/eda_processing.log")
  ruta_log_modelo <- cfg("log_modelo",     "results/logs/model_training.log")
  ruta_boxplot    <- cfg("grafico_output", "results/plots/boxplot_glucosa_vs_outcome.png")
  ruta_roc        <- cfg("grafico_roc",    "results/plots/roc_curve.png")

  expect_true(file.exists(ruta_log_eda))
  expect_gt(file.size(ruta_log_eda), 0)

  expect_true(file.exists(ruta_log_modelo))
  expect_gt(file.size(ruta_log_modelo), 0)

  expect_true(file.exists(ruta_boxplot))
  expect_true(file.exists(ruta_roc))
})

# ==============================================================================
# TEST 5: El log de entrenamiento registra métricas y verificación VIF (script 03)
# ==============================================================================
test_that("El log de entrenamiento contiene las métricas clave y el análisis VIF", {

  ruta_log_modelo <- cfg("log_modelo", "results/logs/model_training.log")
  log_texto       <- paste(readLines(ruta_log_modelo), collapse = "\n")

  expect_true(grepl("Accuracy",       log_texto))
  expect_true(grepl("Sensibilidad",   log_texto))
  expect_true(grepl("AUC-ROC",        log_texto))
  expect_true(grepl("VIF",            log_texto))
  expect_true(grepl("Brier Score",    log_texto))
  expect_true(grepl("Hosmer-Lemeshow",log_texto))
  expect_true(grepl("Youden",         log_texto))
  expect_true(grepl("LASSO",          log_texto))
  expect_true(grepl("VALIDACI",       log_texto, ignore.case = TRUE))
})