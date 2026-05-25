# ==============================================================================
# PROYECTO: Análisis Estadístico y Modelado Predictivo
# SCRIPT: utils.R — Funciones de utilidad compartidas por el pipeline
# Cargado por main.R antes de ejecutar los demás scripts.
# ==============================================================================

# ------------------------------------------------------------------------------
# Calcula el Factor de Inflación de la Varianza (VIF) para cada predictor.
# Detecta multicolinealidad: valores > 10 son problemáticos.
# ------------------------------------------------------------------------------
calc_vif <- function(datos, vars) {
  sapply(vars, function(v) {
    formula_aux <- as.formula(paste(v, "~", paste(setdiff(vars, v), collapse = " + ")))
    r2 <- summary(lm(formula_aux, data = datos))$r.squared
    if (r2 >= 1) Inf else round(1 / (1 - r2), 3)
  })
}

# ------------------------------------------------------------------------------
# Calcula el AUC-ROC mediante la regla trapezoidal (sin dependencias externas).
# ------------------------------------------------------------------------------
calc_auc <- function(prob, real) {
  ord    <- order(prob, decreasing = TRUE)
  real_o <- real[ord]
  n_pos  <- sum(real_o == 1)
  n_neg  <- sum(real_o == 0)
  if (n_pos == 0 || n_neg == 0) return(NA_real_)
  tpr <- c(0, cumsum(real_o == 1) / n_pos)
  fpr <- c(0, cumsum(real_o == 0) / n_neg)
  round(sum(diff(fpr) * (tpr[-length(tpr)] + tpr[-1]) / 2), 4)
}

# ------------------------------------------------------------------------------
# Calcula un conjunto completo de métricas de clasificación.
# Devuelve una lista con confusion, accuracy, sensibilidad, especificidad,
# ppv (precisión positiva), f1 y auc.
# ------------------------------------------------------------------------------
calc_metricas <- function(prob, real, umbral = 0.5) {
  clase <- ifelse(prob > umbral, 1, 0)
  mat   <- table(Real = real, Predicho = clase)

  vp <- if ("1" %in% rownames(mat) && "1" %in% colnames(mat)) mat["1", "1"] else 0
  vn <- if ("0" %in% rownames(mat) && "0" %in% colnames(mat)) mat["0", "0"] else 0
  fp <- if ("0" %in% rownames(mat) && "1" %in% colnames(mat)) mat["0", "1"] else 0
  fn <- if ("1" %in% rownames(mat) && "0" %in% colnames(mat)) mat["1", "0"] else 0

  acc   <- (vp + vn) / sum(mat)
  sens  <- if ((vp + fn) > 0) vp / (vp + fn) else 0
  espec <- if ((vn + fp) > 0) vn / (vn + fp) else 0
  ppv   <- if ((vp + fp) > 0) vp / (vp + fp) else 0
  f1    <- if ((ppv + sens) > 0) 2 * ppv * sens / (ppv + sens) else 0

  list(
    confusion     = mat,
    accuracy      = round(acc,   4),
    sensibilidad  = round(sens,  4),
    especificidad = round(espec, 4),
    ppv           = round(ppv,   4),
    f1            = round(f1,    4),
    auc           = calc_auc(prob, real)
  )
}

# ------------------------------------------------------------------------------
# Brier Score: mide calibración probabilística. Rango [0, 1].
# Referencia nula = mean(y) * (1 - mean(y)). Cuanto menor, mejor.
# ------------------------------------------------------------------------------
calc_brier_score <- function(prob, real) {
  round(mean((prob - real)^2), 4)
}

# ------------------------------------------------------------------------------
# Test de Hosmer-Lemeshow (implementación manual, sin paquetes extra).
# Un p-valor > 0.05 indica buen ajuste (no se rechaza H0 de calibración).
# ------------------------------------------------------------------------------
hosmer_lemeshow_test <- function(prob, real, g = 10) {
  breaks  <- quantile(prob, probs = seq(0, 1, length.out = g + 1), na.rm = TRUE)
  grupos  <- cut(prob, breaks = breaks, include.lowest = TRUE, labels = FALSE)
  hl_stat <- 0
  for (k in seq_len(g)) {
    idx <- which(grupos == k)
    if (length(idx) == 0) next
    obs_pos <- sum(real[idx])
    obs_neg <- sum(1 - real[idx])
    exp_pos <- sum(prob[idx])
    exp_neg <- sum(1 - prob[idx])
    if (exp_pos > 0) hl_stat <- hl_stat + (obs_pos - exp_pos)^2 / exp_pos
    if (exp_neg > 0) hl_stat <- hl_stat + (obs_neg - exp_neg)^2 / exp_neg
  }
  p_value <- pchisq(hl_stat, df = g - 2, lower.tail = FALSE)
  list(
    estadistico = round(hl_stat, 4),
    df          = g - 2,
    p_value     = round(p_value, 4)
  )
}
