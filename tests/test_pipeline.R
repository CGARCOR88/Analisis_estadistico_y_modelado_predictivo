library(testthat)
library(readr)

# Contexto de la prueba
context("Validación de Calidad del Pipeline de Datos")

test_that("El dataset limpio se ha generado correctamente", {
  
  # 1. Comprobar que el archivo existe en la ruta configurada
  # Nota: Usamos la ruta por defecto o cargamos CONFIG si está en memoria
  ruta_datos <- ifelse(exists("CONFIG"), CONFIG$archivo_datos_clean, "data/pima_diabetes_clean.csv")
  expect_true(file.exists(ruta_datos))
  
  # Cargar datos para evaluar su estructura
  datos <- read_csv(ruta_datos, show_col_types = FALSE)
  
  # 2. Test: Comprobar que la imputación funcionó y NO hay valores faltantes (NAs)
  # Evaluamos las variables críticas que antes tenían ceros/NAs
  variables_criticas <- c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI")
  num_nas <- sum(is.na(datos[, variables_criticas]))
  expect_equal(num_nas, 0)
  
  # 3. Test: Comprobar las dimensiones lógicas del dataset (Pima tiene 768 pacientes)
  expect_equal(nrow(datos), 768)
  expect_equal(ncol(datos), 9)
  
  # 4. Test: Comprobar que la variable objetivo sigue siendo binaria (0 o 1) antes del factor
  expect_true(all(datos$Outcome %in% c(0, 1)))
})