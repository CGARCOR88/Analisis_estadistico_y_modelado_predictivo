# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 01_Ingesta de Datos y Limpieza de Calidad
# ==============================================================================

# 1. Cargar librerías necesarias
library(readr)
library(dplyr)

# Descarga con manejo de errores (red caída, URL inválida, etc.)
datos_originales <- tryCatch(
  read_csv(CONFIG$url_datos, col_names = CONFIG$columnas_input, show_col_types = FALSE),
  error = function(e) stop(paste("Error al descargar datos desde URL:", conditionMessage(e)))
)

# Validar estructura del dataset descargado
if (nrow(datos_originales) == 0) {
  stop("Error de validación: el dataset descargado está vacío.")
}
cols_faltantes <- setdiff(CONFIG$columnas_input, names(datos_originales))
if (length(cols_faltantes) > 0) {
  stop(paste("Error de validación: columnas no encontradas:",
             paste(cols_faltantes, collapse = ", ")))
}
cat(sprintf("Dataset descargado: %d filas × %d columnas. Validación OK.\n",
            nrow(datos_originales), ncol(datos_originales)))

# Reemplazar ceros por NA en variables fisiológicamente imposibles
datos <- datos_originales %>%
  mutate(across(all_of(CONFIG$variables_con_nas), ~ ifelse(. == 0, NA, .)))

# Guardar datos preprocesados (ceros → NA, SIN imputar).
# NOTA: La imputación PMM se realiza en 03_predictive_modeling.R DESPUÉS del
# split train/test para evitar data leakage del conjunto de test al de entrenamiento.
if (!dir.exists("data")) dir.create("data")
write_csv(datos, CONFIG$archivo_datos_clean)