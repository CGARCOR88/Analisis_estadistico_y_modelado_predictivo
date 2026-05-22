# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 04_Inferencia y Predicción
# Objetivo: Cargar el modelo entrenado y generar predicciones sobre datos nuevos.
#
# Uso:
#   1. Ajusta CONFIG$archivo_nuevos_datos en main.R con la ruta a tus nuevos datos.
#   2. Ejecuta: source("scripts/04_predict.R")  (requiere CONFIG en el entorno)
#      O directamente desde main.R añadiendo la línea indicada al final.
# ==============================================================================

library(readr)
library(dplyr)

# --- Verificar que los artefactos del pipeline existen ---
if (!file.exists(CONFIG$archivo_modelo)) {
  stop("Modelo no encontrado. Ejecuta primero main.R para entrenar el pipeline.")
}
if (!file.exists(CONFIG$archivo_medianas)) {
  stop("Medianas de entrenamiento no encontradas. Ejecuta primero main.R.")
}
if (!file.exists(CONFIG$archivo_nuevos_datos)) {
  stop(paste("Archivo de datos nuevos no encontrado:", CONFIG$archivo_nuevos_datos))
}

# 1. Cargar artefactos del entrenamiento
modelo         <- readRDS(CONFIG$archivo_modelo)
medianas_train <- readRDS(CONFIG$archivo_medianas)

cat("Modelo cargado desde:", CONFIG$archivo_modelo, "\n")
cat("Medianas de entrenamiento cargadas.\n\n")

# 2. Cargar y preprocesar nuevos datos
nuevos_datos <- read_csv(CONFIG$archivo_nuevos_datos, show_col_types = FALSE)

# Excluir la variable objetivo si está presente (datos etiquetados)
if (CONFIG$variable_objetivo %in% names(nuevos_datos)) {
  etiquetas_reales <- nuevos_datos[[CONFIG$variable_objetivo]]
  nuevos_datos     <- nuevos_datos[, !names(nuevos_datos) %in% CONFIG$variable_objetivo]
} else {
  etiquetas_reales <- NULL
}

# Reemplazar ceros por NA (misma transformación que en 01_data_ingestion.R)
nuevos_datos <- nuevos_datos %>%
  mutate(across(any_of(CONFIG$variables_con_nas), ~ ifelse(. == 0, NA, .)))

# Imputar con medianas del TRAIN (garantiza consistencia con el entrenamiento)
for (v in CONFIG$variables_con_nas) {
  if (v %in% names(nuevos_datos)) {
    nas_idx <- is.na(nuevos_datos[[v]])
    if (any(nas_idx)) nuevos_datos[[v]][nas_idx] <- medianas_train[v]
  }
}

# 3. Generar predicciones
probs  <- predict(modelo, newdata = nuevos_datos, type = "response")
clases <- ifelse(probs > 0.5, 1, 0)

resultados <- nuevos_datos %>%
  mutate(
    prob_diabetes = round(probs, 4),
    prediccion    = clases,
    diagnostico   = ifelse(clases == 1, "Diabetes", "Sano")
  )

# 4. Guardar resultados
if (!dir.exists(dirname(CONFIG$archivo_predicciones))) {
  dir.create(dirname(CONFIG$archivo_predicciones), recursive = TRUE)
}
write_csv(resultados, CONFIG$archivo_predicciones)

cat(sprintf("Predicciones generadas: %d observaciones\n", nrow(resultados)))
cat(sprintf("  - Diabetes: %d (%.1f%%)\n", sum(clases == 1), 100 * mean(clases == 1)))
cat(sprintf("  - Sano:     %d (%.1f%%)\n", sum(clases == 0), 100 * mean(clases == 0)))
cat("Guardadas en:", CONFIG$archivo_predicciones, "\n")

# 5. Si había etiquetas reales, calcular accuracy como validación rápida
if (!is.null(etiquetas_reales)) {
  acc <- mean(clases == etiquetas_reales)
  cat(sprintf("\nValidación (etiquetas reales disponibles) — Accuracy: %.2f%%\n", acc * 100))
}
