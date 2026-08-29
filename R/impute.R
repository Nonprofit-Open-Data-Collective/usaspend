## Outlay imputation: liquidation curves fitted on File C ground truth.
##
## Everything here operationalizes the experiment in IMPUTATION.md
## (data-raw/outlay-imputation-experiment.R, measured 2026-08-29 on 1,189
## ground-truth awards). The winning model is the liquidation curve: the
## share of an award's NET OBLIGATIONS outlaid in each event-year, by
## duration x late-start cell. It carries level and timing in one object --
## its sum encodes the outlay/obligation ratio, its shape encodes the lag --
## and scored 0.27 mean misallocation (timing) and 0.29 unnormalized
## (level + timing) against 0.75 / 0.85 for treating obligations as cash.

## ---- feature engineering ---------------------------------------------------

#' Award-level features for outlay imputation
#'
#' Collapses a transaction ledger to one row per award carrying the traits
#' the imputation model uses (duration, start timing) and the modification
#' taxonomy defined by the imputation experiment (see `IMPUTATION.md` 6.4).
#'
#' @section The modification taxonomy:
#' `mod_class` is one label per award, first match wins:
#' \describe{
#'   \item{`reduced`}{De-obligations exceed 5% of gross positive.}
#'   \item{`extension_funded`}{Final `pop_end_date` pushed more than 90 days
#'     past the first reported one, with material new money (> 5% of prior
#'     positives) at or after the extension event.}
#'   \item{`extension_timeline`}{Extended as above without material new
#'     money -- a no-cost extension.}
#'   \item{`multi_year_incremental`}{Obligations in more than one fiscal
#'     year, no material extension or reduction.}
#'   \item{`single_year`}{All obligations in one fiscal year.}
#' }
#'
#' @param transactions A `data.table` matching `us_schema("transactions")`
#'   (normalized or raw canonical).
#' @return One row per award: identifiers, `first_fy`, `last_oblig_fy`,
#'   `first_month` (fiscal month of the first action, Oct = 1),
#'   `late_start` (first obligated Apr-Sep), obligation totals,
#'   period-of-performance fields, `duration`, `dur_bin` (capped at 6),
#'   extension/reduction booleans and `mod_class`.
#' @export
#' @examples
#' f <- us_outlay_features(us_sample_extract()$transactions)
#' f[, .N, by = mod_class]
us_outlay_features <- function(transactions) {
  stopifnot(is.data.frame(transactions))
  need <- c("award_key", "action_date", "federal_action_obligation")
  missing <- setdiff(need, names(transactions))
  if (length(missing)) {
    us_abort("{.arg transactions} is missing {.val {missing}}.")
  }
  x <- data.table::copy(data.table::as.data.table(transactions))
  x <- x[!is.na(award_key)]
  if (!nrow(x)) return(data.table::data.table(award_key = character(0)))
  if (!"action_fiscal_year" %in% names(x) || anyNA(x$action_fiscal_year)) {
    x[, "action_fiscal_year" := fiscal_year(action_date)]
  }
  x <- x[!is.na(action_fiscal_year)]
  x[, ".fy_month" := (data.table::month(action_date) + 2L) %% 12L + 1L]
  data.table::setorderv(x, c("award_key", "action_date"), na.last = TRUE)

  grab <- function(v, default = NA) if (v %in% names(x)) x[[v]] else default
  for (cc in c("award_group", "award_family", "award_type_code",
               "awarding_agency_name")) {
    if (!cc %in% names(x)) x[, (cc) := NA_character_]
  }
  if (!"pop_end_date" %in% names(x)) x[, "pop_end_date" := as.Date(NA)]

  feat <- x[, {
    pe <- pop_end_date[!is.na(pop_end_date)]
    pop0_end  <- if (length(pe)) pe[1] else as.Date(NA)
    pop_final <- if (length(pe)) pe[length(pe)] else as.Date(NA)
    pop_max   <- if (length(pe)) max(pe) else as.Date(NA)
    pos <- sum(federal_action_obligation[federal_action_obligation > 0], na.rm = TRUE)
    neg <- sum(federal_action_obligation[federal_action_obligation < 0], na.rm = TRUE)
    pe_all <- pop_end_date
    pe_all[is.na(pe_all)] <- as.Date("1900-01-01")
    ext_i <- if (!is.na(pop0_end)) which(pe_all > pop0_end + 90)[1] else NA_integer_
    ext_date <- if (!is.na(ext_i)) action_date[ext_i] else as.Date(NA)
    after <- !is.na(ext_date) & !is.na(action_date) & action_date >= ext_date
    fm_i <- which.min(action_date)
    .(first_fy = min(action_fiscal_year), last_oblig_fy = max(action_fiscal_year),
      first_month = if (length(fm_i)) .fy_month[fm_i] else NA_integer_,
      n_tx = .N, oblig = pos + neg, oblig_positive = pos, oblig_negative = neg,
      pop0_end = pop0_end, pop_final_end = pop_final,
      ext_days = as.numeric(pop_max - pop0_end),
      ext_fy = if (!is.na(ext_date)) fiscal_year(ext_date) else NA_integer_,
      money_after_ext = sum(federal_action_obligation[after], na.rm = TRUE),
      award_group = data.table::last(award_group),
      award_family = data.table::last(award_family),
      award_type_code = data.table::last(award_type_code),
      awarding_agency_name = data.table::last(awarding_agency_name))
  }, by = award_key]

  feat[, "extended"   := !is.na(ext_days) & ext_days > 90]
  feat[, "funded_ext" := extended & money_after_ext > 0.05 * pmax(oblig_positive, 1)]
  feat[, "reduced"    := oblig_negative < -0.05 * pmax(oblig_positive, 1)]
  feat[, "mod_class" := data.table::fcase(
    reduced,                  "reduced",
    funded_ext,               "extension_funded",
    extended,                 "extension_timeline",
    last_oblig_fy > first_fy, "multi_year_incremental",
    default =                 "single_year")]
  feat[, "pop_end_fy"  := fiscal_year(pop_final_end)]
  feat[, "pop0_end_fy" := fiscal_year(pop0_end)]
  feat[, "duration" := pmax(pop_end_fy - first_fy + 1L,
                            last_oblig_fy - first_fy + 1L, 1L)]
  feat[is.na(duration), "duration" := last_oblig_fy - first_fy + 1L]
  feat[, "dur_bin" := pmin(duration, 6L)]
  feat[, "late_start" := first_month >= 7L]
  feat[]
}

## ---- training data ---------------------------------------------------------

#' Build an outlay-imputation training set
#'
#' Assembles the ground truth the imputation model is fitted on: award
#' features from the transaction ledger, annual File C outlays per award,
#' and the two-tier truth screen from the imputation experiment
#' (`IMPUTATION.md` 1). Awards that fail the screen are kept in `awards`
#' with `tier = NA` but excluded from `grid`.
#'
#' @section The two tiers:
#' Both require **linkage** -- File C lifetime obligations within 10% of the
#' award's own ledger. `"reconciled"` additionally requires lifetime outlays
#' within 10% of lifetime obligations with cash no longer flowing.
#' `"shape_complete"` requires a first obligation FY2022+ (inside the monthly
#' reporting mandate), performance ended before the current fiscal year, and
#' a plateaued outlay series -- the timing profile is fully observed even
#' where the level fell short.
#'
#' @param transactions A `data.table` matching `us_schema("transactions")`.
#' @param funding Optional prefetched File C table from [us_fetch_outlays()];
#'   fetched (one paged request per candidate award) when `NULL`.
#' @param min_first_fy Earliest first-obligation fiscal year to consider.
#'   File C coverage begins in earnest FY2020; earlier awards cannot be truth.
#' @param min_oblig Minimum absolute net obligation.
#' @param as_of The current (incomplete) federal fiscal year; defaults to
#'   today's. Used by the censoring screens.
#' @return A list of class `usaspend_outlay_training`: `awards` (features +
#'   File C lifetime figures + `tier`), `grid` (award x fiscal year rows for
#'   truth awards: `oblig_fy`, `actual`, event time `t`), and `meta`.
#' @export
#' @examples
#' \dontrun{
#' tr <- us_outlay_training(us_normalize_transactions(vumc_transactions))
#' }
us_outlay_training <- function(transactions, funding = NULL,
                               min_first_fy = 2020L, min_oblig = 50000,
                               as_of = NULL) {
  feat <- us_outlay_features(transactions)
  as_of <- as.integer(as_of %||% fiscal_year(Sys.Date()))
  feat <- feat[first_fy >= min_first_fy & abs(oblig) > min_oblig]
  if (!nrow(feat)) us_abort("No awards pass the training screens.")

  if (is.null(funding)) funding <- us_fetch_outlays(feat$award_key)
  stopifnot(is.data.frame(funding))
  ann <- us_outlays_by_year(funding)
  ann <- ann[award_key %in% feat$award_key]

  x <- data.table::as.data.table(transactions)[!is.na(award_key)]
  if (!"action_fiscal_year" %in% names(x) || anyNA(x$action_fiscal_year)) {
    x[, "action_fiscal_year" := fiscal_year(action_date)]
  }
  obl_fy <- x[award_key %in% feat$award_key & !is.na(action_fiscal_year),
              .(oblig_fy = sum(federal_action_obligation, na.rm = TRUE)),
              by = .(award_key, fy = action_fiscal_year)]

  life <- merge(
    ann[, .(filec = sum(filec_obligation),
            outlay_total = sum(outlay, na.rm = TRUE),
            last_outlay_fy = {
              ok <- !is.na(outlay) & outlay > 0
              if (any(ok)) max(fiscal_year[ok]) else NA_integer_
            },
            sh_prev = sum(outlay[fiscal_year == as_of - 1L], na.rm = TRUE),
            sh_cur  = sum(outlay[fiscal_year >= as_of], na.rm = TRUE)),
        by = award_key],
    feat, by = "award_key", all.y = TRUE)
  life[, "sh_prev" := sh_prev / pmax(outlay_total, 1)]
  life[, "sh_cur"  := sh_cur / pmax(outlay_total, 1)]
  life[, "linked" := !is.na(filec) &
                     abs(filec - oblig) <= pmax(0.10 * abs(oblig), 1000)]
  life[, "tier" := data.table::fcase(
    linked & oblig > 0 & outlay_total >= 0.9 * oblig &
      outlay_total <= 1.1 * oblig & sh_cur <= 0.10,        "reconciled",
    linked & oblig > 0 & first_fy >= 2022L & !is.na(pop_end_fy) &
      pop_end_fy < as_of & outlay_total >= 0.25 * oblig &
      sh_cur <= 0.05 & sh_prev <= 0.20,                     "shape_complete",
    default = NA_character_)]

  gt <- life[!is.na(tier)]
  grid <- if (nrow(gt)) {
    win <- gt[, .(award_key, y0 = first_fy,
                  y1 = pmax(pop_end_fy, last_outlay_fy, last_oblig_fy, na.rm = TRUE))]
    g <- win[, .(fy = seq(y0, y1)), by = award_key]
    g <- merge(g, ann[!is.na(outlay), .(award_key, fy = fiscal_year, actual = outlay)],
               by = c("award_key", "fy"), all.x = TRUE)
    g <- merge(g, obl_fy, by = c("award_key", "fy"), all.x = TRUE)
    for (cc in c("actual", "oblig_fy")) g[is.na(get(cc)), (cc) := 0]
    g <- merge(g, gt[, .(award_key, first_fy, oblig, dur_bin, late_start,
                         mod_class, tier)], by = "award_key")
    g[, "t" := fy - first_fy]
    g[]
  } else {
    data.table::data.table(award_key = character(0), fy = integer(0),
                           actual = numeric(0), oblig_fy = numeric(0),
                           t = integer(0))
  }
  us_msg(c("Training set: {nrow(feat)} candidate{?s}, {sum(life$linked)} linked, {nrow(gt)} ground-truth award{?s}.",
           "*" = "{sum(gt$tier == 'reconciled')} reconciled, {sum(gt$tier == 'shape_complete')} shape-complete"))
  structure(list(awards = life[], grid = grid,
                 meta = list(as_of = as_of, min_first_fy = min_first_fy,
                             min_oblig = min_oblig, built_at = Sys.time())),
            class = "usaspend_outlay_training")
}

#' @export
print.usaspend_outlay_training <- function(x, ...) {
  cli::cli_h1("outlay-imputation training set")
  cli::cli_bullets(c(
    "*" = "{nrow(x$awards)} candidate award{?s}, {sum(!is.na(x$awards$tier))} ground truth",
    "*" = "{sum(x$awards$tier == 'reconciled', na.rm = TRUE)} reconciled, {sum(x$awards$tier == 'shape_complete', na.rm = TRUE)} shape-complete",
    "*" = "{nrow(x$grid)} award-year rows, as of FY{x$meta$as_of}"))
  invisible(x)
}

## ---- fitting ---------------------------------------------------------------

#' Fit a liquidation-curve outlay model
#'
#' The model is a set of empirical liquidation curves: the mean share of an
#' award's **net obligations** outlaid in each event-year `t` (years since
#' first obligation), by cell. Because the target is a share of obligations,
#' not of the cash total, each curve's sum encodes the cell's
#' outlay/obligation ratio and its shape encodes the lag -- level and timing
#' in one object. This is the experiment's winning method (`IMPUTATION.md`
#' 4: 0.27 mean misallocation, best unnormalized level + timing).
#'
#' Prediction falls back hierarchically: the full cell where it has at least
#' `min_cell` training awards, then the duration-only curve, then the global
#' curve.
#'
#' @param training A `usaspend_outlay_training` from [us_outlay_training()].
#' @param cells Feature columns defining the cell. The default,
#'   duration x late-start, is what the experiment selected; `late_start`
#'   (first obligated Apr-Sep) shifts cash into the next fiscal year.
#' @param min_cell Minimum training awards for a cell to be used.
#' @return A list of class `usaspend_outlay_model`: the curve tables,
#'   per-duration support counts, the global outlay/obligation ratio (used
#'   by the even-spread fallback), and `meta`.
#' @export
#' @examples
#' m <- us_impute_fit(outlay_training)
#' m
us_impute_fit <- function(training, cells = c("dur_bin", "late_start"),
                          min_cell = 8L) {
  if (!inherits(training, "usaspend_outlay_training")) {
    us_abort("{.arg training} must come from {.fn us_outlay_training}.")
  }
  g <- data.table::copy(training$grid)
  if (!nrow(g)) us_abort("The training set has no ground-truth awards.")
  missing <- setdiff(cells, names(g))
  if (length(missing)) {
    us_abort("Cell column{?s} {.val {missing}} absent from the training grid.")
  }
  g <- g[oblig > 0]
  g[, ".share" := actual / oblig]

  curves_cell <- g[, .(share = mean(.share), n = data.table::uniqueN(award_key)),
                   by = c(cells, "t")]
  curves_dur  <- g[, .(share = mean(.share), n = data.table::uniqueN(award_key)),
                   by = .(dur_bin, t)]
  curve_global <- g[, .(share = mean(.share), n = data.table::uniqueN(award_key)),
                    by = t]
  support <- g[, .(n_awards = data.table::uniqueN(award_key)), by = dur_bin]

  structure(list(
    cells        = cells,
    min_cell     = as.integer(min_cell),
    curves_cell  = curves_cell[order(t)],
    curves_dur   = curves_dur[order(dur_bin, t)],
    curve_global = curve_global[order(t)],
    support      = support[order(dur_bin)],
    global_ratio = sum(g$actual) / sum(g[, oblig[1], by = award_key]$V1),
    meta = list(n_awards = data.table::uniqueN(g$award_key),
                tiers = table(training$awards$tier),
                as_of = training$meta$as_of, fitted_at = Sys.time())
  ), class = "usaspend_outlay_model")
}

#' @export
print.usaspend_outlay_model <- function(x, ...) {
  cli::cli_h1("liquidation-curve outlay model")
  cli::cli_bullets(c(
    "*" = "fitted on {x$meta$n_awards} ground-truth award{?s} (as of FY{x$meta$as_of})",
    "*" = "cells: {paste(x$cells, collapse = ' x ')}, min cell {x$min_cell}",
    "*" = "global outlay/obligation ratio {round(x$global_ratio, 2)}",
    "*" = "durations supported: {paste0(x$support$dur_bin, ' (n=', x$support$n_awards, ')', collapse = ', ')}"))
  invisible(x)
}

## ---- scoring ---------------------------------------------------------------

#' Misallocation share between an imputed and an actual annual series
#'
#' `0.5 * sum(|imputed - actual|) / sum(actual)`: the fraction of the
#' dollars placed in the wrong year. With `normalize = TRUE` the imputed
#' series is first rescaled to the actual total, isolating *timing*; with
#' `FALSE` the method is also charged for missing the cash *level*. See
#' `IMPUTATION.md` 3 for why this beats correlation for allocation tasks.
#'
#' @param imputed,actual Numeric vectors over the same years.
#' @param normalize Rescale `imputed` to the actual total first.
#' @return A scalar in `[0, Inf)` (`NA` if `sum(actual) <= 0`); values at or
#'   above 1 mean essentially none of the money was placed correctly.
#' @export
#' @examples
#' us_misallocation(c(50, 50), c(10, 90))
us_misallocation <- function(imputed, actual, normalize = TRUE) {
  tot <- sum(actual)
  if (!is.finite(tot) || tot <= 0) return(NA_real_)
  if (normalize && sum(imputed) > 0) imputed <- imputed * tot / sum(imputed)
  0.5 * sum(abs(imputed - actual)) / tot
}

#' Cross-validated evaluation of an outlay-imputation configuration
#'
#' K-fold (by award) evaluation of the liquidation-curve model against the
#' two reference rules: `as_obligated` (cash booked in the commitment year)
#' and `even_spread` (the fitted global ratio spread evenly over the
#' performance window). Reports both metrics from the experiment: `timing`
#' (misallocation share, imputed series rescaled to the actual total) and
#' `level_timing` (no rescaling -- the method is charged for the level too).
#'
#' @param training A `usaspend_outlay_training`.
#' @param cells,min_cell Passed to [us_impute_fit()].
#' @param folds Number of CV folds.
#' @param seed RNG seed for fold assignment.
#' @return A list: `summary` (mean/median/dollar-weighted by method and
#'   metric), `by_class` (mean timing misallocation by `mod_class`), and
#'   `scores` (per award).
#' @export
#' @examples
#' ev <- us_impute_eval(outlay_training)
#' ev$summary
us_impute_eval <- function(training, cells = c("dur_bin", "late_start"),
                           min_cell = 8L, folds = 5L, seed = 1L) {
  if (!inherits(training, "usaspend_outlay_training")) {
    us_abort("{.arg training} must come from {.fn us_outlay_training}.")
  }
  g <- data.table::copy(training$grid)[oblig > 0]
  if (!nrow(g)) us_abort("The training set has no ground-truth awards.")
  set.seed(seed)
  fmap <- g[, .(fold = 0L), by = award_key]
  fmap[, "fold" := sample(rep_len(seq_len(folds), .N))]
  g <- merge(g, fmap, by = "award_key")

  aw <- training$awards[award_key %in% g$award_key]
  preds <- vector("list", folds)
  for (f in seq_len(folds)) {
    tr <- training
    tr$grid <- g[fold != f]
    m <- us_impute_fit(tr, cells = cells, min_cell = min_cell)
    te_feat <- aw[award_key %in% g[fold == f]$award_key]
    p <- impute_from_features(te_feat, m)
    preds[[f]] <- p[, .(award_key, fy, outlay_imputed)]
  }
  pred <- data.table::rbindlist(preds)

  ev <- merge(g, pred, by = c("award_key", "fy"), all = TRUE)
  ev <- merge(ev[, -c("first_fy", "oblig", "dur_bin", "mod_class", "tier"),
                 with = FALSE],
              aw[, .(award_key, first_fy, oblig, dur_bin, mod_class, tier,
                     pop_end_fy, last_oblig_fy)],
              by = "award_key")
  for (cc in c("actual", "oblig_fy", "outlay_imputed")) {
    ev[is.na(get(cc)), (cc) := 0]
  }
  ev[, "pop_n" := pmax(pmax(pop_end_fy, last_oblig_fy, na.rm = TRUE) - first_fy + 1L, 1L)]
  ev[, "in_pop" := fy < first_fy + pop_n]
  gr <- attr(pred, "global_ratio") %||% 1

  sc <- ev[, {
    even <- sum(oblig_fy) * as.numeric(in_pop) / max(sum(in_pop), 1)
    .(timing_model = us_misallocation(outlay_imputed, actual),
      timing_as_obligated = us_misallocation(pmax(oblig_fy, 0), actual),
      timing_even_spread = us_misallocation(even, actual),
      level_model = us_misallocation(outlay_imputed, actual, normalize = FALSE),
      level_as_obligated = us_misallocation(pmax(oblig_fy, 0), actual, normalize = FALSE),
      level_even_spread = us_misallocation(even, actual, normalize = FALSE))
  }, by = award_key]
  sc <- merge(sc, aw[, .(award_key, mod_class, dur_bin, tier, oblig)],
              by = "award_key")

  mcols <- setdiff(names(sc), c("award_key", "mod_class", "dur_bin", "tier", "oblig"))
  summary <- data.table::rbindlist(lapply(mcols, function(m) {
    v <- sc[[m]]
    data.table::data.table(
      metric = sub("_.*$", "", m), method = sub("^[a-z]+_", "", m),
      mean = round(mean(v, na.rm = TRUE), 3),
      median = round(stats::median(v, na.rm = TRUE), 3),
      dollar_weighted = round(sum(v * sc$oblig, na.rm = TRUE) /
                              sum(sc$oblig[!is.na(v)]), 3))
  }))
  by_class <- sc[, .(n = .N,
                     model = round(mean(timing_model, na.rm = TRUE), 3),
                     as_obligated = round(mean(timing_as_obligated, na.rm = TRUE), 3),
                     even_spread = round(mean(timing_even_spread, na.rm = TRUE), 3)),
                 by = mod_class][order(mod_class)]
  list(summary = summary[order(metric, mean)], by_class = by_class, scores = sc[])
}

## ---- imputation ------------------------------------------------------------

## Core: award features + model -> award x fiscal-year imputed outlays.
## Model path when the award's duration has enough training support and a
## start year exists; otherwise the even-spread fallback (global ratio x
## even allocation over the performance window). Never returns NA dollars.
impute_from_features <- function(feat, model) {
  f <- data.table::copy(data.table::as.data.table(feat))
  if (!nrow(f)) {
    out <- data.table::data.table(award_key = character(0), fy = integer(0),
                                  t = integer(0), outlay_imputed = numeric(0),
                                  imputation_method = character(0),
                                  imputation_flags = character(0))
    data.table::setattr(out, "global_ratio", model$global_ratio)
    return(out)
  }
  sup <- model$support
  f <- merge(f, sup, by = "dur_bin", all.x = TRUE)
  f[is.na(n_awards), "n_awards" := 0L]

  f[, "method" := data.table::fcase(
    is.na(first_fy) | is.na(oblig) | oblig <= 0, "none",
    n_awards >= model$min_cell,                  "liquidation_curve",
    default =                                    "even_spread")]
  f[, "flags" := trimws(paste(
    data.table::fifelse(method == "even_spread" & n_awards < model$min_cell &
                          !is.na(first_fy) & !is.na(oblig) & oblig > 0,
                        "duration_outside_support", ""),
    data.table::fifelse(is.na(pop_end_fy), "pop_end_missing", ""),
    data.table::fifelse(is.na(late_start), "start_month_missing", ""),
    data.table::fifelse(method == "none", "nonpositive_obligation", "")))]
  f[, "flags" := gsub("\\s+", ";", flags)]

  out <- list()

  ## -- model path -----------------------------------------------------------
  mp <- f[method == "liquidation_curve"]
  if (nrow(mp)) {
    hor <- model$curves_dur[, .(tmax = max(t)), by = dur_bin]
    mp <- merge(mp, hor, by = "dur_bin", all.x = TRUE)
    ## the window covers the curve AND the award's own performance period
    mp[, "tmax" := pmax(tmax, pop_end_fy - first_fy, 0L, na.rm = TRUE)]
    g <- mp[, .(t = 0:tmax[1]), by = award_key]
    g <- merge(g, mp[, c("award_key", "first_fy", "oblig", "flags",
                         model$cells), with = FALSE], by = "award_key")
    cc <- model$curves_cell[n >= model$min_cell,
                            c(model$cells, "t", "share"), with = FALSE]
    g <- merge(g, cc, by = c(model$cells, "t"), all.x = TRUE)
    g <- merge(g, model$curves_dur[, .(dur_bin, t, share_dur = share)],
               by = c("dur_bin", "t"), all.x = TRUE)
    g <- merge(g, model$curve_global[, .(t, share_glob = share)],
               by = "t", all.x = TRUE)
    g[, "sh" := data.table::fifelse(!is.na(share), share,
                 data.table::fifelse(!is.na(share_dur), share_dur,
                  data.table::fifelse(!is.na(share_glob), share_glob, 0)))]
    out$model <- g[, .(award_key, fy = first_fy + t, t,
                       outlay_imputed = sh * oblig,
                       imputation_method = "liquidation_curve",
                       imputation_flags = flags)]
  }

  ## -- even-spread fallback: ratio x (net obligations / n periods) ----------
  ep <- f[method == "even_spread"]
  if (nrow(ep)) {
    ep[, "end_fy" := pmax(pop_end_fy, last_oblig_fy, first_fy, na.rm = TRUE)]
    g <- ep[, .(fy = seq(first_fy[1], end_fy[1])), by = award_key]
    g <- merge(g, ep[, .(award_key, first_fy, oblig, flags, end_fy)],
               by = "award_key")
    g[, "n_periods" := end_fy - first_fy + 1L]
    out$even <- g[, .(award_key, fy, t = fy - first_fy,
                      outlay_imputed = model$global_ratio * oblig / n_periods,
                      imputation_method = "even_spread",
                      imputation_flags = flags)]
  }

  ## -- nothing to allocate --------------------------------------------------
  np <- f[method == "none" & !is.na(first_fy)]
  if (nrow(np)) {
    out$none <- np[, .(award_key, fy = first_fy, t = 0L, outlay_imputed = 0,
                       imputation_method = "none", imputation_flags = flags)]
  }
  res <- data.table::rbindlist(out, use.names = TRUE)
  data.table::setorderv(res, c("award_key", "fy"))
  data.table::setattr(res, "global_ratio", model$global_ratio)
  res[]
}

#' Impute annual outlays from obligations data
#'
#' Allocates each award's net obligations across fiscal years as imputed
#' cash, using a fitted liquidation-curve model where the award's data
#' supports it and an explicit fallback where it does not. Dollars are never
#' `NA`: awards outside the model's support envelope get the basic rule
#' *global outlay/obligation ratio x (net obligations / performance
#' periods)*, and `imputation_method` says which rule produced each row.
#'
#' @section When the model steps aside:
#' The model path requires a first-obligation year, positive net
#' obligations, and a duration the training data supports (at least
#' `min_cell` ground-truth awards of that duration -- the support envelope).
#' Everything else -- missing period-of-performance dates, a missing start
#' month, durations beyond the envelope -- falls back to even spread, with
#' the reason in `imputation_flags`. An award still in progress is *not* a
#' fallback case: the curve projects its remaining cash, including fiscal
#' years after the data pull; those rows simply carry future `fy` values.
#'
#' @param transactions A `data.table` matching `us_schema("transactions")`,
#'   or a precomputed feature table from [us_outlay_features()].
#' @param model A `usaspend_outlay_model`; `NULL` uses the bundled
#'   [outlay_model], fitted on the packaged experiment's 1,189 ground-truth
#'   awards.
#' @return A `data.table`, one row per award x fiscal year: `outlay_imputed`
#'   (dollars), event time `t`, `imputation_method`
#'   (`"liquidation_curve"` / `"even_spread"` / `"none"`) and
#'   `imputation_flags`.
#' @export
#' @examples
#' tx <- us_normalize_transactions(us_sample_extract()$transactions)
#' imp <- us_impute_outlays(tx)
#' imp[, .(dollars = sum(outlay_imputed)), by = imputation_method]
us_impute_outlays <- function(transactions, model = NULL) {
  model <- model %||% usaspend::outlay_model
  if (!inherits(model, "usaspend_outlay_model")) {
    us_abort("{.arg model} must be a {.cls usaspend_outlay_model} from {.fn us_impute_fit}.")
  }
  feat <- if (is.data.frame(transactions) && "dur_bin" %in% names(transactions)) {
    data.table::as.data.table(transactions)
  } else {
    us_outlay_features(transactions)
  }
  res <- impute_from_features(feat, model)
  tally <- table(unique(res[, .(award_key, imputation_method)])$imputation_method)
  us_msg(c("Imputed outlays for {data.table::uniqueN(res$award_key)} award{?s}.",
           "*" = "{paste0(names(tally), '=', as.integer(tally), collapse = ' ')}"))
  res
}

#' Attach imputed outlays to a panel
#'
#' Runs [us_impute_outlays()] on the panel's own transaction ledger and
#' joins the result onto the org x award x year table as `outlay_imputed`,
#' with `imputation_method` per award. Money measures already in the panel
#' are never touched. Rows are added (flagged `imputed_outlay_only_year`)
#' for fiscal years the curve allocates cash to but the panel has no row
#' for -- including *future* years of awards still in progress, which is
#' the point of imputation.
#'
#' @param panel A `usaspend_panel` built with `period = "fiscal"` (curves
#'   are fitted in fiscal event time).
#' @param model A `usaspend_outlay_model`; `NULL` uses the bundled
#'   [outlay_model].
#' @param fill_gaps Add rows for imputed-cash years the panel lacks.
#' @return The panel with `outlay_imputed` and `imputation_method` columns
#'   and `meta$imputation` recording the model and method tally.
#' @export
#' @examples
#' p <- us_panel(us_sample_extract(), period = "fiscal")
#' p <- us_add_imputed_outlays(p)
#' p$panel[, .(oblig = sum(obligation_net), imputed = sum(outlay_imputed))]
us_add_imputed_outlays <- function(panel, model = NULL, fill_gaps = TRUE) {
  if (!inherits(panel, "usaspend_panel")) {
    us_abort("{.arg panel} must be a {.cls usaspend_panel} from {.fn us_panel}.")
  }
  if (!identical(panel$meta$period, "fiscal")) {
    us_abort(c("Liquidation curves are fitted in fiscal event time.",
               "i" = "Rebuild with {.code us_panel(extract, period = \"fiscal\")} before imputing."))
  }
  model <- model %||% usaspend::outlay_model
  imp <- us_impute_outlays(panel$transactions, model = model)
  p <- data.table::copy(panel$panel)
  imp <- imp[award_key %in% unique(p$award_key)]

  p <- merge(p, imp[, .(award_key, year = fy, outlay_imputed)],
             by = c("award_key", "year"), all.x = TRUE)
  ## multi-recipient award-years: dominant row carries the imputed cash
  p[, "n_org_rows" := .N, by = .(award_key, year)]
  if (any(p$n_org_rows > 1L & !is.na(p$outlay_imputed))) {
    data.table::setorderv(p, c("award_key", "year"))
    p[n_org_rows > 1L & !is.na(outlay_imputed), "outlay_imputed" := {
        keep <- which.max(abs(obligation_net) + n_transactions / 1e9)
        outlay_imputed * (seq_len(.N) == keep)
      }, by = .(award_key, year)]
  }
  p[, "n_org_rows" := NULL]
  p[is.na(outlay_imputed), "outlay_imputed" := 0]
  p <- merge(p, unique(imp[, .(award_key, imputation_method)]),
             by = "award_key", all.x = TRUE)
  p[is.na(imputation_method), "imputation_method" := "none"]

  orphan <- imp[outlay_imputed != 0][!p, on = c("award_key", fy = "year")]
  if (nrow(orphan) && fill_gaps) {
    dom <- p[order(-abs(obligation_net), -n_transactions), .SD[1L], by = award_key]
    dom[, c("year", "outlay_imputed") := NULL]
    add <- merge(orphan[, .(award_key, year = fy, outlay_imputed)],
                 dom, by = "award_key")
    zero_num <- c("n_actions_positive", "n_actions_negative",
                  "obligation_positive", "obligation_negative", "obligation_net",
                  "deobligation_prior_year", "loan_face_value", "loan_subsidy_cost",
                  "subaward_out_amount", "subaward_in_amount", "net_revenue",
                  "outlay_amount")
    zero_int <- c("n_transactions", "n_subawards_out", "n_subawards_in")
    for (cc in intersect(zero_num, names(add))) add[, (cc) := 0]
    for (cc in intersect(zero_int, names(add))) add[, (cc) := 0L]
    add[, "flags" := "imputed_outlay_only_year"]
    add <- add[, names(p), with = FALSE]
    p <- data.table::rbindlist(list(p, add), use.names = TRUE)
    us_msg("Added {nrow(add)} imputed-outlay year{?s} outside the panel's activity rows.")
  } else if (nrow(orphan)) {
    us_msg("Dropping {nrow(orphan)} imputed year{?s} outside the panel; use {.code fill_gaps = TRUE} to keep them.")
  }
  data.table::setorderv(p, c("org_id", "award_key", "year"))
  tally <- table(unique(p[, .(award_key, imputation_method)])$imputation_method)
  panel$panel <- p[]
  panel$meta$imputation <- list(model = model$meta, methods = tally,
                                imputed_at = Sys.time())
  panel
}
