# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 01_Ingesta de Datos y Limpieza de Calidad
# ==============================================================================

# 1. Cargar librerías necesarias
library(readr)
library(dplyr)
library(mice)

# Usamos las variables genéricas de CONFIG
datos_originales <- read_csv(CONFIG$url_datos, col_names = CONFIG$columnas_input, show_col_types = FALSE)
datos <- datos_originales

# Reemplazar ceros por NA
datos <- datos %>%
  mutate(across(all_of(CONFIG$variables_con_nas), ~ ifelse(. == 0, NA, .)))

# Imputación: excluir la variable objetivo para evitar data leakage
datos_predictores <- datos[, !names(datos) %in% CONFIG$variable_objetivo]
imputacion        <- mice(datos_predictores, method = "pmm", m = 5, printFlag = FALSE)
datos_limpios     <- cbind(
  complete(imputacion),
  setNames(data.frame(datos[[CONFIG$variable_objetivo]]), CONFIG$variable_objetivo)
)

# Guardar usando la ruta genérica
if(!dir.exists("data")) dir.create("data")
write_csv(datos_limpios, CONFIG$archivo_datos_clean)