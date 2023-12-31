#' @title Convert from SingleCellExperiment to scmet object
#'
#' @description Helper function that converts SCE objects to scmet objects
#' that can be used as input to the scmet function. The structure of the
#' SCE object to store single cell methylation data is the following. We
#' create two sparse assays, `met` storing methylated CpGs and `total` storing
#' total number of CpGs. Rows correspond to features and columns to cells,
#' similar to scRNA-seq convention.To distinguish between a feature (in a cell)
#' having zero methylated CpGs vs not having CpG coverage at all (missing value),
#' we check if the corresponding entry in `total` is zero as well.
#' The `rownames` and `colnames` slots should store the feature and cell names,
#' respectively. Covariates `X` that might explain variability in mean
#' (methylation) should be stored in `metadata(rowData(sce)X`.
#'
#' @param sce SummarizedExperiment object
#'
#' @return A named list containing the matrix Y (methylation data in format
#' required by the `scmet` function) and the covariates X.
#'
#' @seealso \code{\link{scmet}}, \code{\link{scmet_differential}},
#'   \code{\link{scmet_hvf_lvf}}
#'
#' @author C.A.Kapourani \email{C.A.Kapourani@@ed.ac.uk}
#'
#' @examples
#' # Extract
#' sce <- scmet_to_sce(Y = scmet_dt$Y, X = scmet_dt$X)
#'
#' df <- sce_to_scmet(sce)
#'
#' @export
sce_to_scmet <- function(sce) {
  Feature = Cell = total_reads = met_reads <- NULL
  # Extract total and met reads
  met <- SummarizedExperiment::assay(sce, "met")
  total <- SummarizedExperiment::assay(sce, "total")
  # From idx to feature and cell names
  feature_names <- factor(total@i + 1, levels = seq_len(NROW(total)),
                          labels = rownames(total))
  cell_names <- factor(total@j + 1, levels = seq_len(NCOL(total)),
                       labels = colnames(total))

  # convert to data frame: convert to 1-based indexing
  Y <- data.table::data.table(Feature = feature_names, Cell = cell_names,
                              total_reads = total@x, met_reads = met@x)
  # Extract covariates X
  X <- S4Vectors::metadata(SummarizedExperiment::rowData(sce))$X
  return(list(Y = Y, X = X))
}


#' @title Convert from scmet to SingleCellExperiment object.
#'
#' @description Helper function that converts an scmet to SCE object. The
#' structure of the SCE object to store single cell methylation data is the
#' following. We create two assays, `met` storing methylated CpGs and `total`
#' storing total number of CpGs. Rows correspond to features and columns to
#' cells, similar to scRNA-seq convention. The `rownames` and `colnames` slots
#' should store the feature and cell names, respectively. Covariates `X`
#' that might explain variability in mean (methylation) should be stored
#' in `metadata(rowData(sce)$X`.
#'
#' @param Y Methylation data in data.table format.
#' @param X (Optional) Matrix of covariates.
#'
#' @return An SCE object with the structure described above.
#'
#' @seealso \code{\link{scmet}}, \code{\link{scmet_differential}},
#'   \code{\link{scmet_hvf_lvf}}
#'
#' @author C.A.Kapourani \email{C.A.Kapourani@@ed.ac.uk}
#'
#' @examples
#' # Extract
#' sce <- scmet_to_sce(Y = scmet_dt$Y, X = scmet_dt$X)
#'
#' @export
scmet_to_sce <- function(Y, X = NULL) {
  # First we create a wide format for methylated cpgs
  met_Y <- Y[, c("Feature", "Cell", "met_reads")]
  tot_Y <- Y[, c("Feature", "Cell", "total_reads")]

  i <- as.numeric(factor(tot_Y$Feature, levels = unique(tot_Y$Feature)))
  j <- as.numeric(factor(tot_Y$Cell, levels = unique(tot_Y$Cell)))

  met <- Matrix::sparseMatrix(i, j, x = met_Y$met_reads, repr = "T")
  total <- Matrix::sparseMatrix(i, j, x = tot_Y$total_reads, repr = "T")
  # Extract cell and feature names
  feature_names <- unique(tot_Y$Feature)
  cell_names <- unique(tot_Y$Cell)

  base::rownames(total) <- feature_names
  base::colnames(total) <- cell_names
  base::rownames(met) <- feature_names
  base::colnames(met) <- cell_names

  # Add covariate information
  if (is.null(X)) {
    X <- matrix(1, nrow = length(feature_names), ncol = 1)
    rownames(X) <- feature_names
  }
  row_data <- S4Vectors::DataFrame(feature_names)
  S4Vectors::metadata(row_data)$X <- X
  sce <- SingleCellExperiment::SingleCellExperiment(
    assays = list(met = met, total = total), rowData = row_data
  )
  return(sce)
}



#' @title Create design matrix
#'
#' @description Generic function for crating a radial basis function (RBF)
#'   design matrix for input vector X.
#'
#' @param L Total number of basis functions, including the bias term.
#' @param X Vector of covariates
#' @param c Scaling parameter for variance of RBFs
#'
#' @return A design matrix object H.
#'
#' @seealso \code{\link{scmet}}, \code{\link{scmet_differential}},
#'   \code{\link{scmet_hvf_lvf}}
#'
#' @author C.A.Kapourani \email{C.A.Kapourani@@ed.ac.uk}
#'
#' @examples
#' # Extract
#' H <- create_design_matrix(L = 4, X = scmet_dt$X)
#'
#' @export
create_design_matrix <- function(L, X, c = 1.2) {
  H <- .rbf_design_matrix(L = L, X = X, c = c)
  return(H)
}


# RBF evaluation
.rbf_basis <- function(X, mus, h = 1){
  return(exp( -0.5 * sum(((X - mus) / h)^2) ))
}


# @title Create RBF design matrix
#
# @param L Total number of basis functions, including the bias term
# @param X Vector of covariates
# @param c Scaling parameter for variance of RBFs
.rbf_design_matrix <- function(L, X, c = 1){
  N <- length(X)  # Length of the dataset
  if (L > 1) {
    # Compute mean locations
    ms <- rep(0, L - 1)
    for (l in seq_len((L - 1))) {
      ms[l] <- l * ((max(X) - min(X)) / L ) + min(X)
    }
    # Compute scaling parameter
    h <- (ms[2] - ms[1]) * c
    H <- matrix(1, nrow = N, ncol = L)
    for (l in seq_len((L - 1))) {
      H[, l + 1] <- apply(as.matrix(X), 1, .rbf_basis, mus = ms[l], h = h)
    }
  } else {
    H <- matrix(1, nrow = N, ncol = L)
  }
  return(H)
}


# @title Create polynomial design matrix
#
# @param L The degree of the polynomial basis that will be applied to input X.
# @param X Vector of covariates
.poly_design_matrix <- function(L, X) {
  H <- matrix(1, nrow = length(X), ncol = L)
  if (L > 1) {
    for (l in 2:L) {
      H[, l] <- X ^ (l - 1)
    }
  }
  return(H)
}


# Infer penalized linear regression model
.lm_mle_penalized <- function(y, H, lambda = 0.5){
  if (lambda == 0) {
    qx <- qr(H)             # Compute QR decomposition of H
    W <- c(solve.qr(qx, y)) # Compute (H'H)^(-1)H'y
  }else{
    I <- diag(1, NCOL(H))   # Identity matrix
    # I[1,1]  <- 1e-10  # Do not change the intercept coefficient
    qx <- qr(lambda * I + t(H) %*% H) # Compute QR decomposition
    W <- c(solve.qr(qx, t(H) %*% y))  # Comp (lambda*I+H'H)^(-1)H'y
  }
  return(c(W))
}


# Evaluate EFDR for given evidence threshold and posterior tail probabilities
# Adapted from BASiCS package.
.eval_efdr <- function(evidence_thresh, prob) {
  return(sum((1 - prob) * I(prob > evidence_thresh)) /
           sum(I(prob > evidence_thresh)))
}


# Evaluate EFNR for given evidence threshold and posterior tail probabilities
# Adapted from BASiCS package.
.eval_efnr <- function(evidence_thresh, prob) {
  return(sum(prob * I(evidence_thresh >= prob)) /
           sum(I(evidence_thresh >= prob)))
}


# Compute posterior tail probabilities for the differential analysis task.
# Adapted from BASiCS. See also Bochina and Richardson (2007)
.tail_prob <- function(chain, tolerance_thresh) {
  if (tolerance_thresh > 0) {
    prob <- matrixStats::colMeans2(ifelse(abs(chain) > tolerance_thresh, 1, 0))
  } else {
    tmp <- matrixStats::colMeans2(ifelse(abs(chain) > 0, 1, 0))
    prob <- 2 * pmax(tmp, 1 - tmp) - 1
  }
  return(prob)
}


# Search function for optimal posterior evidence threshold \alpha
# Adapted from BASiCS
.thresh_search <- function(evidence_thresh, prob, efdr, task, suffix = "") {
  # Summary of cases
  # 1. If EFDR is provided - run calibration
  #   1.1. If the calibration doesn't completely fail - search \alpha
  #     1.1.1. If optimal \alpha is not too low - set \alpha to optimal
  #     1.1.2. If optimal \alpha is too low - fix to input probs
  #   1.2 If calibration completely fails - default \alpha=0.9 (conservative)
  # 2. If EFDR is not provided - fix to input probs


  # 1. If EFDR is provided - run calibration
  if (!is.null(efdr)) {
    # If threshold is not set a priori (search)
    evidence_thresh_grid <- seq(0.6, 0.9995 , by = 0.00025)
    # Evaluate EFDR and EFNR on this grid
    efdr_grid <- vapply(evidence_thresh_grid, FUN = .eval_efdr,
                        FUN.VALUE = 1, prob = prob)
    efnr_grid <- vapply(evidence_thresh_grid, FUN = .eval_efnr,
                        FUN.VALUE = 1, prob = prob)

    # Compute absolute difference between supplied EFDR and grid search
    abs_diff <- abs(efdr_grid - efdr)
    # If we can estimate EFDR
    if (sum(!is.na(abs_diff)) > 0) {
      # Search EFDR closest to the desired value
      efdr_optimal <- efdr_grid[abs_diff == min(abs_diff, na.rm = TRUE) &
                                  !is.na(abs_diff)]
      # If multiple threholds lead to same EFDR, choose the lowest EFNR
      efnr_optimal <- efnr_grid[efdr_grid == mean(efdr_optimal) &
                                  !is.na(efdr_grid)]
      if (sum(!is.na(efnr_optimal)) > 0) {
        optimal <- which(efdr_grid == mean(efdr_optimal) &
                           efnr_grid == mean(efnr_optimal))
      } else {
        optimal <- which(efdr_grid == mean(efdr_optimal))
      }
      # Quick fix for EFDR/EFNR ties; possibly not an issue in real datasets
      optimal <- stats::median(round(stats::median(optimal)))

      # If calibrated threshold is above the minimum required probability
      if (evidence_thresh_grid[optimal] > evidence_thresh) {
        # 1.1.1. If optimal prob is not too low - set prob to optimal
        optimal_evidence_thresh <- c(evidence_thresh_grid[optimal],
                                     efdr_grid[optimal], efnr_grid[optimal])
        if (abs(optimal_evidence_thresh[2] - efdr) > 0.025) {
          # Message when different to desired EFDR is large
          message("For ", task, " task:\n",
                  "Not possible to find evidence probability threshold (>0.6)",
                  "\n that achieves desired EFDR level (tolerance +- 0.025)\n",
                  "Output based on the closest possible value. \n")
        }
      } else {
        # 1.1.2. If optimal prob is too low - fix to input probs
        efdr_grid <- .eval_efdr(evidence_thresh = evidence_thresh, prob = prob)
        efnr_grid <- .eval_efnr(evidence_thresh = evidence_thresh, prob = prob)
        optimal_evidence_thresh <- c(evidence_thresh, efdr_grid[1],
                                     efnr_grid[1])

        # Only required for differential test function
        if (suffix != "") { suffix <- paste0("_", suffix) }
        message("For ", task, " task:\n",
                "Evidence probability threshold chosen via EFDR valibration",
                " is too low. \n", "Probability threshold set automatically",
                " equal to 'evidence_thresh", suffix, "'.\n")
      }
    }
    else {
      # 1.2 If calibration completely fails - default prob = 0.9 (conservative)
      message("EFDR calibration failed for ", task, " task. \n",
              "Evidence probability threshold set equal to 0.9. \n")
      optimal_evidence_thresh <- c(0.90, NA, NA)
    }
  } else {
    # 2. If EFDR is not provided - fix to given probs
    efdr_grid <- .eval_efdr(evidence_thresh = evidence_thresh, prob = prob)
    efnr_grid <- .eval_efnr(evidence_thresh = evidence_thresh, prob = prob)
    optimal_evidence_thresh <- c(evidence_thresh, efdr_grid[1], efnr_grid[1])
    evidence_thresh_grid <- NULL
  }

  return(list("optimal_evidence_thresh" = optimal_evidence_thresh,
              "evidence_thresh_grid" = evidence_thresh_grid,
              "efdr_grid" = efdr_grid, "efnr_grid" = efnr_grid))
}


# Internal function to collect differential test results
.diff_test_results <- function(prob, evidence_thresh, estimate, group_label_A,
                               group_label_B, features_selected,
                               excluded = NULL) {

  # Which features are + in each group
  high_A <- which(prob > evidence_thresh & estimate > 0)
  high_B <- which(prob > evidence_thresh & estimate < 0)
  res_diff <- rep("NoDiff", length(estimate))
  res_diff[high_A] <- paste0(group_label_A, "+")
  res_diff[high_B] <- paste0(group_label_B, "+")
  if (!is.null(excluded)) { res_diff[excluded] <- "ExcludedFromTesting" }
  res_diff[!features_selected] <- "ExcludedByUser"
  return(res_diff)
}

# Odds Ratio function
.compute_odds_ratio <- function(p1, p2) {
  return((p1/(1 - p1) ) / (p2 / (1 - p2)))
}

# Log odds Ratio function
.compute_log_odds_ratio <- function(p1, p2) {
  return(log(.compute_odds_ratio(p1, p2)))
}


# Check if values in a vector are considered as outliers and
# set specifix min and max thresholds.
.fix_outliers <- function(x, xmin = 1e-02, xmax = 1 - 1e-2) {
  assertthat::assert_that(is.vector(x))
  idx <- which(x < xmin)
  if (length(idx) > 0) { x[idx] <- xmin }
  idx <- which(x > xmax)
  if (length(idx) > 0) { x[idx] <- xmax }
  return(x)
}

