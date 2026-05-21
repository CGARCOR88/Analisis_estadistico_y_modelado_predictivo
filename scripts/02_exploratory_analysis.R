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

cat("========================================================\n")
cat("INICIO DEL PROCESAMIENTO EDA:", as.character(Sys.time()), "\n")
cat("========================================================\n\n")

datos <- read_csv(CONFIG$archivo_datos_clean, show_col_types = FALSE)

# Convertir variable objetivo en factor dinámicamente
datos[[CONFIG$variable_objetivo]] <- factor(datos[[CONFIG$variable_objetivo]], levels = c(0, 1), labels = c("Sano", "Diabetes"))

cat("\n--- MEDIAS DE VARIABLES SEGÚN EL DIAGNÓSTICO ---\n")
resumen_grupos <- datos %>%
  group_by(across(all_of(CONFIG$variable_objetivo))) %>%
  summarise(Total = n(), Media_Glucosa = mean(Glucose), Media_BMI = mean(BMI))
print(resumen_grupos)

# Gráfico usando la estructura genérica
grafico_glucosa <- ggplot(datos, aes(x = .data[[CONFIG$variable_objetivo]], y = Glucose, fill = .data[[CONFIG$variable_objetivo]])) +
  geom_boxplot(alpha = 0.7) +
  theme_minimal()

ggsave(CONFIG$grafico_output, plot = grafico_glucosa, width = 8, height = 6)

sink(type = "message")
sink(type = "output")
close(log_file)