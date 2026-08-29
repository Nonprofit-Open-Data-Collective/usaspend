## Builds the two bundled imputation objects:
##   outlay_training -- the ground-truth training set from the imputation
##     experiment (VUMC + 50-nonprofit pilot, File C truth, two tiers)
##   outlay_model    -- the default liquidation-curve model fitted on it
##
## Run manually when the ground truth is refreshed. Reuses prefetched File C
## pulls via FUNDING_RDS / PILOT_FUNDING_RDS / PILOT_TX_RDS (see
## outlay-imputation-experiment.R); without them it fetches (~3,000 awards).
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
pilot_dir <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending/pilot"

load("data/vumc_transactions.rda")
tx_v <- suppressMessages(us_normalize_transactions(as.data.table(vumc_transactions)))

pt <- Sys.getenv("PILOT_TX_RDS")
tx_p <- if (nzchar(pt) && file.exists(pt)) {
  readRDS(pt)
} else {
  p <- read_download_dir(file.path(pilot_dir, "raw"))
  suppressMessages(us_normalize_transactions(p$transactions))
}
tx_p <- as.data.table(tx_p)[!award_key %in% unique(tx_v$award_key)]
tx <- rbindlist(list(tx_v, tx_p), use.names = TRUE, fill = TRUE)

read_funding <- function(env) {
  f <- Sys.getenv(env)
  if (nzchar(f) && file.exists(f)) {
    obj <- readRDS(f)
    if (is.data.frame(obj$funding)) as.data.table(obj$funding)
    else rbindlist(obj$funding, fill = TRUE)
  } else NULL
}
fund <- rbindlist(list(read_funding("FUNDING_RDS"), read_funding("PILOT_FUNDING_RDS")),
                  use.names = TRUE, fill = TRUE)
fund <- unique(fund)
if (!nrow(fund)) fund <- NULL

outlay_training <- us_outlay_training(tx, funding = fund, as_of = 2026L)
outlay_model <- us_impute_fit(outlay_training)
print(outlay_model)

ev <- us_impute_eval(outlay_training)
cat("\nbundled-model CV performance:\n")
print(ev$summary)

save(outlay_training, file = "data/outlay_training.rda", compress = "xz")
save(outlay_model, file = "data/outlay_model.rda", compress = "xz")
cat("\nsaved data/outlay_training.rda and data/outlay_model.rda\n")
