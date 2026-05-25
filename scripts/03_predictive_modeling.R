# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: 03_Modelado Predictivo (Regresión Logística con Imputación Múltiple)
# Objetivo: Split estratificado → Imputación múltiple PMM → GLM (m modelos) →
#           Pooling de coeficientes (Rubin) → VIF → Métricas → Youden →
#           Brier/HL → Cook → CV k-fold → LASSO comparación → Curva ROC.
# ==============================================================================

library(readr)
library(dplyr)
library(mice)
library(ggplot2)
library(glmnet)

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

# Parámetros centralizados en CONFIG
prop_train <- CONFIG$proporcion_train
umbral     <- CONFIG$umbral_clasificacion
m_imp      <- CONFIG$m_imputaciones
k          <- CONFIG$k_folds

# =============================================================================
# 1. División train/test ESTRATIFICADA (mantiene proporción de clases)
# =============================================================================
set.seed(CONFIG$semilla)
idx_pos  <- which(datos[[CONFIG$variable_objetivo]] == 1)
idx_neg  <- which(datos[[CONFIG$variable_objetivo]] == 0)
indices  <- c(
  sample(idx_pos, size = floor(prop_train * length(idx_pos))),
  sample(idx_neg, size = floor(prop_train * length(idx_neg)))
)
datos_train <- datos[indices, ]
datos_test  <- datos[-indices, ]

cat(sprintf("Distribución original — Positivos: %d (%.1f%%) | Negativos: %d (%.1f%%)\n",
    length(idx_pos), 100 * length(idx_pos) / nrow(datos),
    length(idx_neg), 100 * length(idx_neg) / nrow(datos)))
cat("Train:", nrow(datos_train), "filas | Test:", nrow(datos_test), "filas\n\n")

# =============================================================================
# 2. Imputación MÚLTIPLE PMM (m imputaciones) — solo sobre TRAIN
# =============================================================================
predictores <- setdiff(names(datos_train), CONFIG$variable_objetivo)
set.seed(CONFIG$semilla)
imputacion_train <- mice(
  datos_train[, predictores], method = "pmm",
  m = m_imp, maxit = 5, printFlag = FALSE
)
cat(sprintf("Imputación múltiple: m=%d imputaciones completadas (método PMM, maxit=5).\n\n",
            m_imp))

# =============================================================================
# 3. Medianas de TRAIN para imputar test y nuevos datos en producción
# =============================================================================
medianas_train <- sapply(datos_train[, CONFIG$variables_con_nas], median, na.rm = TRUE)
saveRDS(medianas_train, file = CONFIG$archivo_medianas)

datos_test_imp <- datos_test
for (v in CONFIG$variables_con_nas) {
  nas_idx <- is.na(datos_test_imp[[v]])
  if (any(nas_idx)) datos_test_imp[[v]][nas_idx] <- medianas_train[v]
}
cat(sprintf("Imputación del test: medianas de TRAIN aplicadas a %d variables.\n\n",
            length(CONFIG$variables_con_nas)))

# =============================================================================
# 4. Entrenamiento: un GLM por imputación (m modelos)
# =============================================================================
formula_modelo <- as.formula(paste(CONFIG$variable_objetivo, "~ ."))

modelos_mi <- lapply(seq_len(m_imp), function(i) {
  d_imp <- cbind(
    complete(imputacion_train, action = i),
    setNames(data.frame(datos_train[[CONFIG$variable_objetivo]]), CONFIG$variable_objetivo)
  )
  glm(formula_modelo, data = d_imp, family = binomial)
})
cat(sprintf("Entrenados %d modelos GLM (imputación múltiple).\n\n", m_imp))

# =============================================================================
# 5. Pooling de coeficientes — Reglas de Rubin
# =============================================================================
coefs_mat <- do.call(rbind, lapply(modelos_mi, coef))
se_mat    <- do.call(rbind, lapply(modelos_mi, function(m) sqrt(diag(vcov(m)))))

Q_bar   <- colMeans(coefs_mat)
U_bar   <- colMeans(se_mat^2)
B       <- apply(coefs_mat, 2, var)
T_var   <- U_bar + (1 + 1 / m_imp) * B
se_pool <- sqrt(T_var)
t_stat  <- Q_bar / se_pool
df_br   <- (m_imp - 1) * (1 + U_bar / ((1 + 1 / m_imp) * B + 1e-10))^2
p_pool  <- 2 * pt(abs(t_stat), df = df_br, lower.tail = FALSE)

pool_summary <- data.frame(
  Coeficiente = names(Q_bar),
  Estimacion  = round(Q_bar,    5),
  SE_pool     = round(se_pool,  5),
  t           = round(t_stat,   3),
  p_valor     = round(p_pool,   4)
)
cat("--- COEFICIENTES POOLED (Reglas de Rubin, m=", m_imp, ") ---\n", sep = "")
print(pool_summary)
cat("\n")

# =============================================================================
# 6. Verificación de multicolinealidad (VIF) — sobre primer dataset imputado
# =============================================================================
datos_imp1 <- cbind(
  complete(imputacion_train, action = 1),
  setNames(data.frame(datos_train[[CONFIG$variable_objetivo]]), CONFIG$variable_objetivo)
)
cat("--- VERIFICACIÓN DE MULTICOLINEALIDAD (VIF) ---\n")
vif_valores <- calc_vif(datos_imp1, predictores)
print(vif_valores)
vif_altos <- names(vif_valores[vif_valores > 10])
if (length(vif_altos) > 0) {
  cat("AVISO: Variables con VIF > 10:", paste(vif_altos, collapse = ", "), "\n\n")
} else {
  cat("OK: Ninguna variable supera el umbral VIF > 10.\n\n")
}

# =============================================================================
# 7. Guardar conjunto de modelos (lista compatible con 04_predict.R)
# =============================================================================
modelo_obj <- list(
  modelos     = modelos_mi,
  m           = m_imp,
  predictores = predictores,
  familia     = "binomial"
)
saveRDS(modelo_obj, file = CONFIG$archivo_modelo)
cat("Modelos guardados en:", CONFIG$archivo_modelo, "\n\n")

# =============================================================================
# 8. Predicciones: promedio de las m probabilidades (Rubin para predicciones)
# =============================================================================
probs_lista       <- lapply(modelos_mi, function(m)
  predict(m, newdata = datos_test_imp, type = "response"))
predicciones_prob <- Reduce("+", probs_lista) / m_imp
real              <- datos_test_imp[[CONFIG$variable_objetivo]]

# =============================================================================
# 9. Optimización del umbral — Índice de Youden (J = Sens + Espec - 1)
# =============================================================================
thresholds  <- seq(0.1, 0.9, by = 0.01)
youden_vals <- sapply(thresholds, function(u) {
  m <- calc_metricas(predicciones_prob, real, u)
  m$sensibilidad + m$especificidad - 1
})
umbral_optimo <- thresholds[which.max(youden_vals)]

cat(sprintf("Umbral por defecto: %.2f | Umbral óptimo (Youden): %.2f\n\n",
            umbral, umbral_optimo))

metricas_def <- calc_metricas(predicciones_prob, real, umbral)
metricas_opt <- calc_metricas(predicciones_prob, real, umbral_optimo)

cat("--- MATRIZ DE CONFUSIÓN (umbral por defecto:", umbral, ") ---\n")
print(metricas_def$confusion)
cat("\n--- MATRIZ DE CONFUSIÓN (umbral óptimo:", umbral_optimo, ") ---\n")
print(metricas_opt$confusion)

cat(sprintf("\n%-35s %-14s %s\n", "Métrica",
            paste0("u=", umbral), paste0("u=", umbral_optimo)))
cat(sprintf("%-35s %-14s %s\n", "Accuracy (Precisión Global):",
  sprintf("%.2f%%", metricas_def$accuracy     * 100),
  sprintf("%.2f%%", metricas_opt$accuracy     * 100)))
cat(sprintf("%-35s %-14s %s\n", "Sensibilidad (Recall):",
  sprintf("%.2f%%", metricas_def$sensibilidad * 100),
  sprintf("%.2f%%", metricas_opt$sensibilidad * 100)))
cat(sprintf("%-35s %-14s %s\n", "Especificidad:",
  sprintf("%.2f%%", metricas_def$especificidad * 100),
  sprintf("%.2f%%", metricas_opt$especificidad * 100)))
cat(sprintf("%-35s %-14s %s\n", "Precisión Positiva (PPV):",
  sprintf("%.2f%%", metricas_def$ppv          * 100),
  sprintf("%.2f%%", metricas_opt$ppv          * 100)))
cat(sprintf("%-35s %-14s %s\n", "F1-Score:",
  sprintf("%.4f",  metricas_def$f1),
  sprintf("%.4f",  metricas_opt$f1)))
cat(sprintf("%-35s %-14s\n", "AUC-ROC:", sprintf("%.4f", metricas_def$auc)))

# =============================================================================
# 10. Brier Score y Test de Hosmer-Lemeshow (calibración probabilística)
# =============================================================================
brier      <- calc_brier_score(predicciones_prob, real)
brier_null <- mean(real) * (1 - mean(real))

cat(sprintf("\n--- CALIBRACIÓN DEL MODELO ---\n"))
cat(sprintf("Brier Score: %.4f  (referencia nula: %.4f)\n", brier, brier_null))

hl <- hosmer_lemeshow_test(predicciones_prob, real)
cat(sprintf("Hosmer-Lemeshow: χ²(df=%d) = %.4f, p = %.4f %s\n",
            hl$df, hl$estadistico, hl$p_value,
            ifelse(hl$p_value < 0.05, "<-- POSIBLE MAL AJUSTE", "<-- Buen ajuste")))

# =============================================================================
# 11. Distancias de Cook — observaciones influyentes (sobre primer modelo)
# =============================================================================
cooks_d         <- cooks.distance(modelos_mi[[1]])
umbral_cook     <- 4 / nrow(datos_imp1)
obs_influyentes <- which(cooks_d > umbral_cook)

cat(sprintf("\n--- OBSERVACIONES INFLUYENTES (Cook > 4/n = %.4f) ---\n", umbral_cook))
cat(sprintf("Observaciones influyentes: %d de %d (%.1f%%)\n",
            length(obs_influyentes), nrow(datos_imp1),
            100 * length(obs_influyentes) / nrow(datos_imp1)))
if (length(obs_influyentes) > 0 && length(obs_influyentes) <= 15) {
  cat("Índices:", paste(obs_influyentes, collapse = ", "), "\n")
}

# =============================================================================
# 12. Validación cruzada k-fold (imputación por medianas dentro de cada fold)
# =============================================================================
cat(sprintf("\n--- VALIDACIÓN CRUZADA %d-FOLD ---\n", k))
set.seed(CONFIG$semilla)
fold_ids <- sample(rep(seq_len(k), length.out = nrow(datos)))
cv_aucs  <- numeric(k)

for (fold_i in seq_len(k)) {
  train_f <- datos[fold_ids != fold_i, ]
  test_f  <- datos[fold_ids == fold_i, ]

  med_f <- sapply(train_f[, CONFIG$variables_con_nas], median, na.rm = TRUE)
  for (v in CONFIG$variables_con_nas) {
    nas_tr <- is.na(train_f[[v]]); if (any(nas_tr)) train_f[[v]][nas_tr] <- med_f[v]
    nas_te <- is.na(test_f[[v]]);  if (any(nas_te)) test_f[[v]][nas_te]  <- med_f[v]
  }

  m_fold         <- suppressWarnings(glm(formula_modelo, data = train_f, family = binomial))
  prob_f         <- predict(m_fold, newdata = test_f, type = "response")
  cv_aucs[fold_i] <- calc_auc(prob_f, test_f[[CONFIG$variable_objetivo]])
}

cat(sprintf("AUC-ROC CV (k=%d):          %.4f ± %.4f\n", k,
            mean(cv_aucs), sd(cv_aucs)))
cat(sprintf("AUC-ROC Test set (MI m=%d): %.4f\n\n", m_imp, metricas_def$auc))

# =============================================================================
# 13. Comparación con LASSO (glmnet, regularización L1)
# =============================================================================
cat("--- COMPARACIÓN: LASSO (glmnet, alpha=1) ---\n")

x_train <- model.matrix(formula_modelo, data = datos_imp1)[, -1]
y_train <- datos_imp1[[CONFIG$variable_objetivo]]
x_test  <- model.matrix(formula_modelo, data = datos_test_imp)[, -1]

set.seed(CONFIG$semilla)
lasso_cv    <- cv.glmnet(x_train, y_train, family = "binomial",
                         alpha = 1, nfolds = k)
lasso_model <- glmnet(x_train, y_train, family = "binomial",
                      alpha = 1, lambda = lasso_cv$lambda.1se)

coefs_lasso <- coef(lasso_model)
vars_lasso  <- rownames(coefs_lasso)[
  coefs_lasso[, 1] != 0 & rownames(coefs_lasso) != "(Intercept)"
]
prob_lasso  <- as.vector(predict(lasso_model, newx = x_test,
                                 type = "response", s = lasso_cv$lambda.1se))
met_lasso   <- calc_metricas(prob_lasso, real, umbral)

cat(sprintf("Lambda óptimo (1 SE):          %.6f\n", lasso_cv$lambda.1se))
cat(sprintf("Variables seleccionadas LASSO: %d/%d — %s\n",
            length(vars_lasso), length(predictores),
            paste(vars_lasso, collapse = ", ")))
cat(sprintf("AUC-ROC LASSO:                 %.4f\n",   met_lasso$auc))
cat(sprintf("AUC-ROC GLM (MI m=%d):          %.4f\n\n", m_imp, metricas_def$auc))

# =============================================================================
# 14. Curva ROC con marcador del umbral óptimo de Youden
# =============================================================================
ord_roc <- order(predicciones_prob, decreasing = TRUE)
r_ord   <- real[ord_roc]
n_pos   <- sum(r_ord == 1); n_neg <- sum(r_ord == 0)
tpr_v   <- c(0, cumsum(r_ord == 1) / n_pos)
fpr_v   <- c(0, cumsum(r_ord == 0) / n_neg)

roc_df  <- data.frame(FPR = fpr_v, TPR = tpr_v)
fpr_opt <- 1 - metricas_opt$especificidad
tpr_opt <- metricas_opt$sensibilidad

grafico_roc <- ggplot(roc_df, aes(x = FPR, y = TPR)) +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_abline(linetype = "dashed", color = "gray50") +
  annotate("point", x = fpr_opt, y = tpr_opt, color = "tomato", size = 3.5) +
  annotate("text", x = fpr_opt + 0.07, y = tpr_opt - 0.06,
           label = sprintf("Youden\n(u=%.2f)", umbral_optimo),
           size = 3.5, color = "tomato") +
  annotate("text", x = 0.72, y = 0.14,
           label = sprintf("AUC = %.3f", metricas_def$auc),
           size = 5, color = "steelblue") +
  labs(
    title = sprintf("Curva ROC — GLM (Imputación Múltiple, m=%d)", m_imp),
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