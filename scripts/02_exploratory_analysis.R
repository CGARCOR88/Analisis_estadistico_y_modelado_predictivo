# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 02_Análisis Exploratorio de Datos (EDA)
# Objetivo: Analizar descriptivos, generar boxplots y registrar traza en LOG.
# ==============================================================================

library(readr)
library(dplyr)
library(ggplot2)

log_file <- file(CONFIG$log_eda, open = "wt")
sink(log_file, type = "output")
sink(log_file, type = "message")

tryCatch({

cat("========================================================\n")
cat("INICIO DEL PROCESAMIENTO EDA:", as.character(Sys.time()), "\n")
cat("========================================================\n\n")

cat("--- ENTORNO DE EJECUCIÓN ---\n")
print(sessionInfo())
cat("\n")

datos <- read_csv(CONFIG$archivo_datos_clean, show_col_types = FALSE)

# --- Análisis de valores faltantes (NAs generados al reemplazar ceros) ---
cat("\n--- VALORES FALTANTES POR VARIABLE (tras reemplazar ceros) ---\n")
nas_por_variable <- sapply(datos, function(x) sum(is.na(x)))
print(nas_por_variable[nas_por_variable > 0])

# Convertir variable objetivo en factor dinámicamente
datos[[CONFIG$variable_objetivo]] <- factor(
  datos[[CONFIG$variable_objetivo]], levels = c(0, 1), labels = c("Sano", "Diabetes")
)

# --- Balance de clases ---
cat("\n--- DISTRIBUCIÓN DE LA VARIABLE OBJETIVO ---\n")
print(table(datos[[CONFIG$variable_objetivo]]))

# --- Medias por grupo (dinámico, sin nombres hardcodeados) ---
cat("\n--- MEDIAS DE VARIABLES NUMÉRICAS SEGÚN EL DIAGNÓSTICO ---\n")
vars_numericas <- setdiff(names(datos)[sapply(datos, is.numeric)], CONFIG$variable_objetivo)
resumen_grupos <- datos %>%
  group_by(across(all_of(CONFIG$variable_objetivo))) %>%
  summarise(
    Total = n(),
    across(all_of(vars_numericas), ~ mean(.x, na.rm = TRUE)),
    .groups = "drop"
  )
print(resumen_grupos)

# --- Gráfico: Boxplot de Glucosa vs Diagnóstico ---
grafico_glucosa <- ggplot(datos, aes(
    x    = .data[[CONFIG$variable_objetivo]],
    y    = Glucose,
    fill = .data[[CONFIG$variable_objetivo]]
  )) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Distribución de Glucosa por Diagnóstico",
    x     = "Diagnóstico",
    y     = "Glucosa en plasma",
    fill  = "Diagnóstico"
  ) +
  theme_minimal()

ggsave(CONFIG$grafico_output, plot = grafico_glucosa, width = 8, height = 6)
cat("\nGráfico guardado en:", CONFIG$grafico_output, "\n")

cat("\n========================================================\n")
cat("FIN DEL PROCESAMIENTO EDA:", as.character(Sys.time()), "\n")
cat("========================================================\n")

}, finally = {
  sink(type = "message")
  sink(type = "output")
  close(log_file)
})