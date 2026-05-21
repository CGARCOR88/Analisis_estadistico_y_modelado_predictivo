# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 03_Modelado Predictivo (Regresión Logística)
# Objetivo: Entrenar el modelo, evaluar métricas y registrar resultados en LOG.
# ==============================================================================


library(readr)
library(dplyr)

# Configurar el archivo de LOG para el modelo
log_model <- file(CONFIG$log_modelo, open = "wt")
sink(log_model, type = "output")
sink(log_model, type = "message")

datos <- read_csv(CONFIG$archivo_datos_clean, show_col_types = FALSE)

set.seed(123)
indices <- sample(1:nrow(datos), size = 0.7 * nrow(datos))
datos_train <- datos[indices, ]
datos_test  <- datos[-indices, ]

# Ajustar fórmula dinámicamente basada en la variable objetivo
formula_modelo <- as.formula(paste(CONFIG$variable_objetivo, "~ ."))
modelo <- glm(formula_modelo, data = datos_train, family = binomial)

print(summary(modelo))

# Evaluación
predicciones_prob <- predict(modelo, newdata = datos_test, type = "response")
predicciones_clase <- ifelse(predicciones_prob > 0.5, 1, 0)

matriz_confusion <- table(Real = datos_test[[CONFIG$variable_objetivo]], Predicho = predicciones_clase)
print(matriz_confusion)

precision <- sum(diag(matriz_confusion)) / sum(matriz_confusion)
cat("\nPrecisión Global (Accuracy):", round(precision * 100, 2), "%\n")

sink(type = "message")
sink(type = "output")
close(log_model)