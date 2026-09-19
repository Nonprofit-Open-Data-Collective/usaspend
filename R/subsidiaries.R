## Subsidiaries surfaced by the parent-UEI match.
##
## recipient_search_text matches recipient_parent_uei as well as recipient_uei
## (measured; see us_download_submit()). A UEI-filtered API pull therefore
## returns, unasked, the transactions a requested organization's subsidiaries
## filed while it was recorded as their parent -- and only those. In the
## 1,000-UEI test run every one of the 4,727 unrequested transactions (18 UEIs)
## arrived this way. The extract records what it found in a crosswalk,
## `extract$org_map`, and either pulls those UEIs' full histories
## (`subsidiaries = TRUE`) or says it has not.

## The crosswalk an extract starts with: every requested UEI is its own root.
crosswalk_init <- function(uei) {
  uei <- unique(uei[!is.na(uei)])
  data.table::data.table(
    uei = uei, org_id = uei, relationship = "requested",
    parent_uei = NA_character_, root_uei = uei,
    recipient_name = NA_character_, extracted = TRUE,
    n_parent_matched = NA_integer_)
}

## Append the subsidiaries visible in `tx`: unrequested recipients whose
## recorded parent is already in the crosswalk. A subsidiary inherits its
## parent's root, so a grandchild found after its parent was extracted rolls
## up to the same requested UEI.
crosswalk_discover <- function(cw, tx) {
  cw <- data.table::copy(cw)
  if (!nrow(tx)) return(cw)
  tx <- data.table::as.data.table(tx)[, c("recipient_uei", "recipient_parent_uei",
                                          "recipient_name", "award_key")]
  repeat {
    s <- tx[!is.na(recipient_uei) & !recipient_uei %in% cw$uei &
              recipient_parent_uei %in% cw$uei]
    if (!nrow(s)) break
    ## an acquired firm can carry several parents over its life; the extract
    ## only holds rows under parents in the crosswalk, and the most frequent
    ## one is taken
    par <- s[, .N, by = .(recipient_uei, recipient_parent_uei)][
      order(recipient_uei, -N)][, .SD[1L], by = recipient_uei]
    nm <- s[!is.na(recipient_name), .N, by = .(recipient_uei, recipient_name)][
      order(recipient_uei, -N)][, .SD[1L], by = recipient_uei]
    cnt <- s[, .(n_parent_matched = .N), by = recipient_uei]
    new <- merge(par[, .(uei = recipient_uei, parent_uei = recipient_parent_uei)],
                 cnt, by.x = "uei", by.y = "recipient_uei")
    new <- merge(new, nm[, .(uei = recipient_uei, recipient_name)],
                 by = "uei", all.x = TRUE)
    new[, "root_uei" := cw$root_uei[match(parent_uei, cw$uei)]]
    new[, c("org_id", "relationship", "extracted") :=
          list(root_uei, "subsidiary", FALSE)]
    new[, "n_parent_matched" := as.integer(n_parent_matched)]
    cw <- data.table::rbindlist(list(cw, new[, names(cw), with = FALSE]),
                                use.names = TRUE)
  }
  cw[]
}

## The extract's crosswalk, rebuilt for extracts made before it was recorded.
extract_crosswalk <- function(extract) {
  cw <- extract$org_map
  if (is.null(cw)) {
    uei <- extract$meta$uei
    if (is.null(uei)) {
      us_abort(c("{.arg extract} records no requested UEIs ({.field meta$uei}).",
                 "i" = "Pass the result of {.fn us_extract}."))
    }
    cw <- crosswalk_init(uei)
  }
  crosswalk_discover(cw, extract$transactions)
}

#' Find subsidiaries surfaced by the parent-UEI match
#'
#' The API recipient filter also matches a transaction's *parent* UEI (see
#' [us_download_submit()]), so an extract holds some transactions of the
#' requested organizations' subsidiaries -- only those filed while a requested
#' UEI was recorded as their parent. This lists them: every unrequested
#' recipient whose `recipient_parent_uei` is a requested UEI (or, recursively,
#' an already-found subsidiary).
#'
#' [us_extract()] records the result in `extract$org_map`; this function
#' rebuilds it for any extract, including ones made before the crosswalk
#' existed. See `vignette("org-map")`.
#'
#' @param extract A `usaspend_extract` from [us_extract()].
#' @return A `data.table`, one row per subsidiary UEI: `uei`, `org_id` (the
#'   requested UEI it rolls up to, until [us_panel()] applies an `org_map`),
#'   `relationship`, `parent_uei` (the recorded parent), `root_uei` (the
#'   requested UEI at the top of the chain), `recipient_name`, `extracted`
#'   (whether its own full history is in the extract), and
#'   `n_parent_matched` (transactions that arrived through the parent match).
#' @export
#' @examples
#' us_find_subsidiaries(us_sample_extract())   # none in the sample
us_find_subsidiaries <- function(extract) {
  if (!is.list(extract) || !"transactions" %in% names(extract)) {
    us_abort("{.arg extract} must be a {.cls usaspend_extract} from {.fn us_extract}.")
  }
  cw <- extract_crosswalk(extract)
  cw[relationship == "subsidiary"][]
}

## Pull the full histories of unextracted subsidiaries in the crosswalk, then
## look again: a subsidiary's own pull can surface its subsidiaries. No
## outbound subaward pass -- us_extract() runs that once, over every award.
add_subsidiaries <- function(extract, max_rounds = 3L, dest = us_cache_dir("raw")) {
  m <- extract$meta
  cw <- extract_crosswalk(extract)
  requested <- m$uei_requested %||% m$uei
  years <- m$years
  start_date <- sprintf("%d-10-01", min(years) - 1L)
  end_date   <- sprintf("%d-09-30", max(years))
  tried <- character(0)

  for (round in seq_len(max_rounds)) {
    todo <- setdiff(cw[relationship == "subsidiary" & !extracted, uei], tried)
    if (!length(todo)) break
    us_msg("Extracting full histories for {length(todo)} subsidiary UEI{?s} (round {round}).")
    tried <- c(tried, todo)
    ## a fresh directory, so files from earlier pulls are not read back in
    d <- file.path(dest, sprintf("sub%s-%d", format(Sys.time(), "%y%m%d%H%M%S"), round))
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    jobs <- us_download_run(todo, m$award_types, start_date, end_date)
    fetched <- attr(us_download_fetch(jobs, dest = d), "fetched")
    parts <- read_download_dir(d)

    ## rows already present came in through the parent match; keep one copy
    tx <- extract$transactions
    tx_new <- parts$transactions
    seen <- !is.na(tx_new$transaction_key) &
      tx_new$transaction_key %in% tx$transaction_key
    extract$transactions <- data.table::rbindlist(list(tx, tx_new[!seen]),
                                                  use.names = TRUE, fill = TRUE)
    if (nrow(parts$subawards) && isTRUE(m$subawards %in% c("in", "both"))) {
      extract$subawards <- data.table::rbindlist(
        list(extract$subawards, parts$subawards), use.names = TRUE, fill = TRUE)
    }
    extract$jobs <- data.table::rbindlist(
      list(extract$jobs, data.table::as.data.table(jobs)[, "tag" := paste0("subsidiaries-", round)]),
      use.names = TRUE, fill = TRUE)

    ## extracted means the job's files reached the extract, not merely that
    ## the server finished it
    done <- jobs[state == "finished" & file_name %in% fetched,
                 unlist(strsplit(ueis, ","), use.names = FALSE)]
    failed <- setdiff(todo, done)
    if (length(failed)) {
      cli::cli_warn("{length(failed)} subsidiary UEI{?s} could not be extracted and stay{?s/} out of sample: {.val {failed}}.")
    }
    cw[uei %in% done, "extracted" := TRUE]
    cw <- crosswalk_discover(cw, extract$transactions)
  }
  left <- cw[relationship == "subsidiary" & !extracted & !uei %in% tried, .N]
  if (left) {
    us_msg("Stopped after {max_rounds} round{?s}; {left} further subsidiary UEI{?s} not extracted.")
  }

  extract$org_map <- cw
  extract$meta$uei_requested <- requested
  extract$meta$uei <- unique(c(requested, cw[extracted == TRUE, uei]))
  extract$meta$subsidiaries <- TRUE
  extract
}

#' Extract the full histories of an extract's subsidiaries
#'
#' Pulls, through the API, every subsidiary UEI in the extract's crosswalk
#' whose own history is not yet in it, and adds them to the requested set so
#' [us_panel()] counts them as part of their parent organization. Equivalent
#' to having run [us_extract()] with `subsidiaries = TRUE`, without repeating
#' the main pull.
#'
#' A query on the subsidiary's own UEI returns its whole history, including
#' years before the parent relationship existed (for an acquired firm, the
#' years before the acquisition). Those years are counted to the parent
#' organization; see `vignette("org-map")` for how to drop them.
#'
#' @param extract A `usaspend_extract` from [us_extract()].
#' @param max_rounds A subsidiary's own pull can surface subsidiaries of its
#'   own; they are pulled in further rounds, up to this many in total.
#' @param dest Directory for intermediate files. Defaults to the package cache.
#' @return The extract with transactions (and, per `meta$subawards`,
#'   subawards) added, `org_map` updated, and `meta$uei` extended;
#'   `meta$uei_requested` keeps the original request.
#' @export
#' @examples
#' \dontrun{
#' ex <- us_extract("JJHCMK4NT5N3", years = 2008:2025)   # RTI
#' us_find_subsidiaries(ex)                               # IRG, among others
#' ex <- us_add_subsidiaries(ex)
#' }
us_add_subsidiaries <- function(extract, max_rounds = 3L, dest = us_cache_dir("raw")) {
  if (!inherits(extract, "usaspend_extract")) {
    us_abort("{.arg extract} must be a {.cls usaspend_extract} from {.fn us_extract}.")
  }
  stopifnot(is.numeric(max_rounds), length(max_rounds) == 1L, max_rounds >= 1)
  keys0 <- unique(extract$transactions$award_key)
  extract <- add_subsidiaries(extract, max_rounds = max_rounds, dest = dest)
  if (isTRUE(extract$meta$subawards %in% c("out", "both"))) {
    keys <- setdiff(unique(extract$transactions$award_key), keys0)
    keys <- keys[!is.na(keys)]
    if (length(keys)) {
      us_msg("Fetching pass-through subawards for {length(keys)} subsidiary award{?s}.")
      out <- us_fetch_subawards_out(keys)
      if (nrow(out)) {
        out[, "direction" := "out"]
        extract$subawards <- data.table::rbindlist(list(extract$subawards, out),
                                                   use.names = TRUE, fill = TRUE)
      }
    }
  }
  extract
}

## The notice us_extract() gives when it found subsidiaries and did not pull
## them. Always shown: it changes what the panel means.
report_subsidiaries <- function(cw) {
  s <- cw[relationship == "subsidiary" & !extracted]
  if (!nrow(s)) return(invisible())
  n_par <- data.table::uniqueN(s$root_uei)
  cli::cli_inform(c(
    "!" = "{nrow(s)} subsidiary UEI{?s} of {n_par} requested organization{?s} {?was/were} added to the crosswalk ({.code $org_map}), but {?its/their} full transactions have not been extracted.",
    "i" = "The API matches parent UEIs, so the extract holds only the {sum(s$n_parent_matched)} transaction{?s} they filed while a requested UEI was recorded as parent -- not their earlier history.",
    "i" = "Their awards are left out of the panel, and {.fn us_reconcile} labels them {.val out_of_sample}: with truncated histories they could not reconcile to the awards' lifetime totals.",
    ">" = "To count them as part of their parents, pass the extract to {.fn us_add_subsidiaries} or extract with {.code subsidiaries = TRUE}.",
    ">" = "See {.code vignette(\"org-map\", package = \"usaspend\")}."))
  invisible()
}

## The organization map us_panel() nets on, returned as the full crosswalk.
## Every UEI whose own history was extracted is in sample. A subsidiary takes
## the org_id the user's org_map gives it, else its root's; subsidiaries the
## extract recorded but did not pull stay listed, out of sample, so the panel
## shows what it left out.
resolve_crosswalk <- function(ext_uei, org_map, cw) {
  ext_uei <- unique(us_validate_uei(ext_uei))
  ext_uei <- ext_uei[!is.na(ext_uei)]
  cw <- if (is.null(cw)) crosswalk_init(ext_uei) else
    data.table::copy(data.table::as.data.table(cw))
  ## extracted UEIs the crosswalk does not know (hand-built extracts)
  miss <- setdiff(ext_uei, cw$uei)
  if (length(miss)) {
    cw <- data.table::rbindlist(list(cw, crosswalk_init(miss)), use.names = TRUE)
  }
  um <- if (is.null(org_map)) NULL else data.table::as.data.table(org_map)
  user_uei <- if (is.null(um)) character(0) else us_validate_uei(um$uei)
  if (length(user_uei)) {
    stray <- setdiff(user_uei, cw$uei)
    if (length(stray)) {
      us_msg("{length(stray)} {.arg org_map} UEI{?s} {?is/are} not in the extract and {?is/are} ignored; request {?it/them} in {.fn us_extract} to include {?its/their} awards.")
    }
  }

  inherit <- cw$relationship == "subsidiary" & !cw$uei %in% user_uei
  own <- us_org_map(setdiff(ext_uei, cw$uei[inherit]), org_map)
  org_of <- function(u) own$org_id[match(u, own$uei)]
  cw[, "org_id" := org_of(uei)]
  cw[inherit, "org_id" := org_of(root_uei)]
  if (length(user_uei)) {
    ## subsidiaries mapped by hand but not extracted: informational only
    cw[is.na(org_id) & uei %in% user_uei,
       "org_id" := um$org_id[match(uei, user_uei)]]
  }
  cw[, "in_sample" := uei %in% ext_uei]
  cw[]
}
