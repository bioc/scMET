% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/scmet_differential.R
\name{scmet_differential}
\alias{scmet_differential}
\alias{differential_test,}
\alias{differential_methylation,}
\alias{differential_variability}
\title{Differential testing using scMET}
\usage{
scmet_differential(
  obj_A,
  obj_B,
  psi_m = log(1.5),
  psi_e = log(1.5),
  psi_g = log(1.5),
  evidence_thresh_m = 0.8,
  evidence_thresh_e = 0.8,
  evidence_thresh_g = 0.8,
  efdr_m = 0.05,
  efdr_e = 0.05,
  efdr_g = 0.05,
  group_label_A = "GroupA",
  group_label_B = "GroupB",
  features_selected = NULL,
  filter_outlier_features = FALSE,
  outlier_m = 0.05,
  outlier_g = 0.05
)
}
\arguments{
\item{obj_A}{The scMET posterior object for group A.}

\item{obj_B}{The scMET posterior object for group B.}

\item{psi_m}{Minimum log odds ratio tolerance threshold for detecting changes
in overall methylation (positive real number). Default value: \code{psi_m =
  log(1.5)} (i.e. 50\% increase).}

\item{psi_e}{Minimum log odds ratio tolerance threshold for detecting changes
in residual over-dispersion (positive real number).}

\item{psi_g}{Minimum log odds ratio tolerance threshold for detecting changes
in biological over-dispersion (positive real number).}

\item{evidence_thresh_m}{Optional parameter. Posterior evidence probability
threshold parameter \verb{alpha_\{M\}} for detecting changes in overall
methylation (between 0.6 and 1). If \code{efdr_m = NULL}, then threshold
will be set to \code{evidence_thresh_m}. If a value for \code{EFDR_M} is
provided, the posterior probability threshold is chosen to achieve an EFDR
equal to \code{efdr_m} and \code{evidence_thresh_m} defines a minimum
probability threshold for this calibration (this avoids low values of
\code{evidence_thresh_m} to be chosen by the EFDR calibration. Default
value \code{evidence_thresh_m = 0.8}.}

\item{evidence_thresh_e}{Optional parameter. Posterior evidence probability
threshold parameter \verb{alpha_\{G\}} for detecting changes in cell-to-cell
residual over-dispersion. Same usage as above.}

\item{evidence_thresh_g}{Optional parameter. Posterior evidence probability
threshold parameter \verb{alpha_\{G\}} for detecting changes in cell-to-cell
biological over-dispersion. Same usage as above.}

\item{efdr_m}{Target for expected false discovery rate related to the
comparison of means. If \code{efdr_m = NULL}, no calibration is performed,
and \verb{alpha_\{M\}} is set to \code{evidence_thresh_m}. Default value:
\code{efdr_m = 0.05}.}

\item{efdr_e}{Target for expected false discovery rate related to the
comparison of residual over-dispersions If \code{efdr_e = NULL}, no
calibration is performed, and `alpha_{E}`` is set to
\code{evidence_thresh_e}. Default value: \code{efdr_e = 0.05}.}

\item{efdr_g}{Target for expected false discovery rate related to the
comparison of biological over-dispersions If \code{efdr_g = NULL}, no
calibration is performed, and \verb{alpha_\{G\}} is set to
\code{evidence_thresh_g}. Default value: \code{efdr_g = 0.05}.}

\item{group_label_A}{Label assigned to group A.}

\item{group_label_B}{Label assigned to group B.}

\item{features_selected}{User defined list of selected features to perform
differential analysis. Should be the same length as the total number of
features, with TRUE for features included in the differential analysis, and
FALSE for those excluded from further analysis.}

\item{filter_outlier_features}{Logical, whether to filter features that have
either mean methylation levels \code{mu} or overdispersion \code{gamma} across both
groups near the range edges, i.e. taking values near 0 or 1. This mostly is
an issue due to taking the logit transformation which effectively makes
small changes in actual space (0, 1) to look really large in transformed
space (-Inf, Inf). In general we expect this will not remove many
interesting features with biological information.}

\item{outlier_m}{Value of average mean methylation across both groups so a
feature is considered as outlier. I.e. if set to 0.05, then will remove
features with \code{mu} < 0.05 or \code{mu} > 1 - 0.05. Only used if
\code{filter_outlier_features = TRUE}.}

\item{outlier_g}{Value of average overdispersion \code{gamma} across groups so a
feature is considered as outlier. Same as \code{outlier_m} parameter above.}
}
\value{
An \code{scmet_differential} object which is a list containing the
following elements: \itemize{ \item{ \code{diff_mu_summary}: A data.frame
containing differential mean methylation output information per feature
(rows), including posterior median parameters for each group and \code{mu_LOR}
containing the log odds-ratio between the groups. The \code{mu_tail_prob} column
contains the posterior tail probability of a feature being called as DM.
The \code{mu_diff_test} column informs the outcomes of the test.} \item{
\code{diff_epsilon_summary}: Same as above, but for differential
variability based on residual overdispersion. } \item{
\code{diff_gamma_summary}: The same as above but for DV analysis based on
overdispersion.} \item{ \code{diff_mu_thresh}: Information about optimal
posterior evidence threshold search for mean methylation mu. }
\item{\code{diff_epsilon_thresh}: Same as above but for residual
overdispersion epsilon..} \item{\code{diff_gamma_thresh}: Same as above but
for overdispersion gamma.} \item{\code{opts}: The parameters used for
testing. For reproducibility purposes.} }
}
\description{
Function for performing differential methylation testing to
identify differentially methylted (DM) and differentially variable (DV)
features across two groups of pre-specified cell populations.
}
\examples{
\dontrun{
# Fit scMET for each group
fit_A <- scmet(Y = scmet_diff_dt$scmet_dt_A$Y,
X = scmet_diff_dt$scmet_dt_A$X, L = 4, iter = 50, seed = 12)
fit_B <- scmet(Y = scmet_diff_dt$scmet_dt_B$Y,
X = scmet_diff_dt$scmet_dt_B$X, L = 4, iter = 50, seed = 12)

# Run differential test
diff_obj <- scmet_differential(obj_A = fit_A, obj_B = fit_B)
}

}
\seealso{
\code{\link{scmet}}, \code{\link{scmet_hvf_lvf}}
}
\author{
C.A.Kapourani \email{C.A.Kapourani@ed.ac.uk}
}
