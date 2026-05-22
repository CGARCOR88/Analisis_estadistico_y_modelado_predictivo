# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 03_Modelado Predictivo (Regresión Logística)
# Objetivo: Entrenar el modelo, evaluar métricas y registrar resultados en LOG.
# ==============================================================================

library(readr)
library(dplyr)
library(mice)
library(ggplot2)

# Configurar el archivo de LOG para el modelo
log_model <- file(CONFIG$log_modelo, open = "wt")
sink(log_model, type = "output")
sink(log_model, type = "message")

tryCatch({

cat("========================================================\n")
cat("INICIO DEL ENTRENAMIENTO:", as.character(Sys.time()), "\n")
cat("========================================================\n\n")

cat("--- ENTORNO DE EJECUCIÓN ---\n")
print(sessionInfo())
cat("\n")

datos <- read_csv(CONFIG$archivo_datos_clean, show_col_types = FALSE)

# 1. División train/test ESTRATIFICADA (mantiene proporción de clases)
set.seed(CONFIG$semilla)
idx_pos  <- which(datos[[CONFIG$variable_objetivo]] == 1)
idx_neg  <- which(datos[[CONFIG$variable_objetivo]] == 0)
indices  <- c(
  sample(idx_pos, size = floor(0.7 * length(idx_pos))),
  sample(idx_neg, size = floor(0.7 * length(idx_neg)))
)
datos_train <- datos[indices, ]
datos_test  <- datos[-indices, ]

cat(sprintf("Distribución original — Positivos: %d (%.1f%%) | Negativos: %d (%.1f%%)\n",
    length(idx_pos), 100 * length(idx_pos) / nrow(datos),
    length(idx_neg), 100 * length(idx_neg) / nrow(datos)))
cat("Train:", nrow(datos_train), "filas | Test:", nrow(datos_test), "filas\n\n")

# 2. Imputación PMM sobre el conjunto de TRAIN únicamente
predictores <- setdiff(names(datos_train), CONFIG$variable_objetivo)
set.seed(CONFIG$semilla)
imputacion_train <- mice(
  datos_train[, predictores], method = "pmm", m = 1, printFlag = FALSE
)
datos_train_imp <- cbind(
  complete(imputacion_train),
  setNames(data.frame(datos_train[[CONFIG$variable_objetivo]]), CONFIG$variable_objetivo)
)

# 3. Imputar test usando medianas del TRAIN (sin filtración de información)
medianas_train <- sapply(datos_train[, CONFIG$variables_con_nas], median, na.rm = TRUE)
saveRDS(medianas_train, file = CONFIG$archivo_medianas)
datos_test_imp <- datos_test
for (v in CONFIG$variables_con_nas) {
  nas_idx <- is.na(datos_test_imp[[v]])
  if (any(nas_idx)) datos_test_imp[[v]][nas_idx] <- medianas_train[v]
}

# 4. Entrenamiento del modelo
formula_modelo <- as.formula(paste(CONFIG$variable_objetivo, "~ ."))
modelo <- glm(formula_modelo, data = datos_train_imp, family = binomial)
print(summary(modelo))

# Verificación de multicolinealidad (VIF) — supuesto de la regresión logística
calc_vif <- function(datos, vars) {
  sapply(vars, function(v) {
    formula_aux <- as.formula(paste(v, "~", paste(setdiff(vars, v), collapse = " + ")))
    r2 <- summary(lm(formula_aux, data = datos))$r.squared
    if (r2 >= 1) Inf else round(1 / (1 - r2), 3)
  })
}

cat("\n--- VERIFICACIÓN DE MULTICOLINEALIDAD (VIF) ---\n")
vars_pred   <- setdiff(names(datos_train_imp), CONFIG$variable_objetivo)
vif_valores <- calc_vif(datos_train_imp, vars_pred)
print(vif_valores)
vif_altos <- names(vif_valores[vif_valores > 10])
if (length(vif_altos) > 0) {
  cat("AVISO: Variables con VIF > 10 (alta multicolinealidad):", paste(vif_altos, collapse = ", "), "\n")
} else {
  cat("OK: Ninguna variable supera el umbral VIF > 10.\n")
}

# 5. Persistir el modelo entrenado
saveRDS(modelo, file = CONFIG$archivo_modelo)
cat("\nModelo guardado en:", CONFIG$archivo_modelo, "\n")

# 6. Evaluación en conjunto de test
predicciones_prob  <- predict(modelo, newdata = datos_test_imp, type = "response")
predicciones_clase <- ifelse(predicciones_prob > 0.5, 1, 0)

real             <- datos_test_imp[[CONFIG$variable_objetivo]]
matriz_confusion <- table(Real = real, Predicho = predicciones_clase)
print(matriz_confusion)

# --- Métricas completas ---
vp <- ifelse("1" %in% rownames(matriz_confusion) & "1" %in% colnames(matriz_confusion),
             matriz_confusion["1", "1"], 0)
vn <- ifelse("0" %in% rownames(matriz_confusion) & "0" %in% colnames(matriz_confusion),
             matriz_confusion["0", "0"], 0)
fp <- ifelse("0" %in% rownames(matriz_confusion) & "1" %in% colnames(matriz_confusion),
             matriz_confusion["0", "1"], 0)
fn <- ifelse("1" %in% rownames(matriz_confusion) & "0" %in% colnames(matriz_confusion),
             matriz_confusion["1", "0"], 0)

precision_global <- (vp + vn) / sum(matriz_confusion)
sensibilidad     <- vp / (vp + fn)
especificidad    <- vn / (vn + fp)
precision_pos    <- vp / (vp + fp)
f1               <- 2 * (precision_pos * sensibilidad) / (precision_pos + sensibilidad)

# AUC-ROC (regla del trapecio, sin dependencias externas)
orden    <- order(predicciones_prob, decreasing = TRUE)
real_ord <- real[orden]
n_pos    <- sum(real_ord == 1)
n_neg    <- sum(real_ord == 0)
tpr      <- c(0, cumsum(real_ord == 1) / n_pos)
fpr      <- c(0, cumsum(real_ord == 0) / n_neg)
auc      <- sum(diff(fpr) * (tpr[-length(tpr)] + tpr[-1]) / 2)

cat("\n--- MÉTRICAS DE EVALUACIÓN ---\n")
cat(sprintf("Accuracy (Precisión Global):  %.2f%%\n", precision_global * 100))
cat(sprintf("Sensibilidad (Recall):        %.2f%%\n", sensibilidad     * 100))
cat(sprintf("Especificidad:                %.2f%%\n", especificidad    * 100))
cat(sprintf("Precisión Positiva (PPV):     %.2f%%\n", precision_pos    * 100))
cat(sprintf("F1-Score:                     %.4f\n",   f1))
cat(sprintf("AUC-ROC:                      %.4f\n",   auc))

# --- Curva ROC ---
roc_df <- data.frame(FPR = fpr, TPR = tpr)
grafico_roc <- ggplot(roc_df, aes(x = FPR, y = TPR)) +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_abline(linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.75, y = 0.15,
           label = sprintf("AUC = %.3f", auc), size = 5, color = "steelblue") +
  labs(
    title = "Curva ROC — Regresión Logística",
    x     = "Tasa de Falsos Positivos (1 - Especificidad)",
    y     = "Sensibilidad (TPR)"
  ) +
  theme_minimal()

ggsave(CONFIG$grafico_roc, plot = grafico_roc, width = 7, height = 6)
cat("Curva ROC guardada en:", CONFIG$grafico_roc, "\n")

cat("\n========================================================\n")
cat("FIN DEL ENTRENAMIENTO:", as.character(Sys.time()), "\n")
cat("========================================================\n")

}, finally = {
  sink(type = "message")
  sink(type = "output")
  close(log_model)
})