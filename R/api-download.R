## Bulk-download job machinery for POST /api/v2/download/transactions/.
##
## The job state machine, measured live:  ready -> running -> finished | failed
## "ready" is a queue state. Treating anything other than "running" as terminal
## reads a freshly queued job as done and throws the download away.

DOWNLOAD_INFLIGHT <- c("ready", "running")

#' Submit a bulk transaction download job
#'
#' Submits one job to `POST /api/v2/download/transactions/` and returns the
#' server-assigned file name, which is the job handle.
#'
#' `recipient_search_text` is capped near 20 values by the API, and that cap is
#' undocumented. In practice large recipients time out server-side well below
#' the cap, so [us_download_run()] defaults to 5 UEIs per job and retries
#' failures one UEI at a time.
#'
#' @param uei Character vector of UEIs (at most 20).
#' @param award_types Award type codes to include. Defaults to every type.
#' @param start_date,end_date Bounds on `action_date`. USAspending award search
#'   is floored at 2007-10-01; earlier data needs the Custom Award Download or
#'   the full database.
#' @return A single string, the job file name, or `NA` if submission failed.
#' @export
us_download_submit <- function(uei,
                               award_types = us_award_type_codes("all"),
                               start_date = "2007-10-01",
                               end_date = Sys.Date()) {
  uei <- us_validate_uei(uei)
  if (length(uei) > 20L) {
    us_abort(c("The API caps {.arg recipient_search_text} near 20 values; got {length(uei)}.",
               "i" = "Use {.fn us_download_run}, which batches and retries for you."))
  }
  body <- list(
    filters = list(
      recipient_search_text = I(uei),
      award_type_codes = I(award_types),
      ## a top-level date_range/date_type is accepted and then silently dropped;
      ## only the time_period form actually filters
      time_period = list(list(start_date = as.character(as_date(start_date)),
                              end_date   = as.character(as_date(end_date)),
                              date_type  = "action_date"))),
    columns = I(character(0)),
    file_format = "csv")
  r <- us_api_try("download/transactions/", body = body)
  if (!r$ok) return(NA_character_)
  r$result$file_name %||% NA_character_
}

#' Poll a download job
#'
#' @param file_name Job handle from [us_download_submit()].
#' @return A list with `status`, and when finished, `total_rows` and `file_url`.
#'   A transient transport failure is reported as `status = "running"` on
#'   purpose: a dropped poll must never be mistaken for a failed job.
#' @export
us_download_status <- function(file_name) {
  r <- us_api_try("download/status", query = list(file_name = file_name))
  if (!r$ok) return(list(status = "running", transient_error = r$error))
  r$result
}

#' Run a set of download jobs to completion
#'
#' Batches UEIs into jobs, keeps a bounded number in flight, polls each to a
#' terminal state, then retries any failed batch one UEI at a time -- a single
#' oversized recipient otherwise poisons its whole batch.
#'
#' @param uei Character vector of UEIs.
#' @param award_types Award type codes.
#' @param start_date,end_date Action-date bounds.
#' @param batch_size UEIs per job. Default from `usaspend.batch_size`.
#' @param concurrent Jobs in flight. Default from `usaspend.concurrent`.
#' @param timeout_min Give up after this many minutes.
#' @param retry_singly Retry failed batches one UEI at a time.
#' @return A `data.table` job manifest: one row per job with `state`, `rows`,
#'   `url`, and the UEIs it covered. Jobs that never finished are kept in the
#'   manifest with their failure state -- they are not dropped, because a
#'   swallowed failure is indistinguishable from a recipient with no awards.
#' @export
us_download_run <- function(uei,
                            award_types = us_award_type_codes("all"),
                            start_date = "2007-10-01",
                            end_date = Sys.Date(),
                            batch_size = us_opt("batch_size"),
                            concurrent = us_opt("concurrent"),
                            timeout_min = 120,
                            retry_singly = TRUE) {
  uei <- unique(us_validate_uei(uei))
  uei <- uei[!is.na(uei)]
  if (!length(uei)) us_abort("No valid UEIs supplied.")

  run <- function(batches, tag) {
    jobs <- data.table::data.table(
      tag = tag, batch = seq_along(batches), n_uei = lengths(batches),
      ueis = vapply(batches, paste, character(1), collapse = ","),
      file_name = NA_character_, state = "queued",
      rows = NA_integer_, url = NA_character_)
    t0 <- Sys.time()
    repeat {
      live <- jobs[state %in% DOWNLOAD_INFLIGHT, .N]
      nxt  <- jobs[state == "queued", which = TRUE]
      while (live < concurrent && length(nxt)) {
        i <- nxt[1L]; nxt <- nxt[-1L]
        fn <- us_download_submit(batches[[i]], award_types, start_date, end_date)
        if (is.na(fn)) {
          jobs[i, state := "submit_failed"]
        } else {
          jobs[i, c("file_name", "state") := list(fn, "ready")]
          live <- live + 1L
        }
      }
      for (i in jobs[state %in% DOWNLOAD_INFLIGHT, which = TRUE]) {
        s <- us_download_status(jobs$file_name[i])
        jobs[i, state := s$status %||% "running"]
        if (identical(s$status, "finished")) {
          jobs[i, c("rows", "url") := list(as_int(s$total_rows), s$file_url %||% NA_character_)]
        }
      }
      tally <- table(jobs$state)
      us_msg("{tag}: {paste0(names(tally), '=', as.integer(tally), collapse = ' ')} ({sum(jobs$state == 'finished')}/{nrow(jobs)} done)")
      if (!nrow(jobs[state %in% c("queued", DOWNLOAD_INFLIGHT)])) break
      if (as.numeric(difftime(Sys.time(), t0, units = "mins")) > timeout_min) {
        cli::cli_warn("Download timed out after {timeout_min} minutes with {nrow(jobs[state %in% DOWNLOAD_INFLIGHT])} job{?s} still running.")
        break
      }
      Sys.sleep(20)
    }
    jobs
  }

  jobs <- run(chunk(uei, batch_size), "main")
  bad <- jobs[state != "finished"]
  if (retry_singly && nrow(bad)) {
    singles <- unique(unlist(strsplit(bad$ueis, ","), use.names = FALSE))
    us_msg("Retrying {length(singles)} UEI{?s} from {nrow(bad)} failed batch{?es}, one at a time.")
    jobs <- data.table::rbindlist(list(jobs, run(as.list(singles), "retry")), fill = TRUE)
  }
  jobs[]
}

#' Download and unzip finished jobs
#'
#' @param jobs Manifest from [us_download_run()].
#' @param dest Directory for the unzipped CSVs. Defaults to the package cache.
#' @return Character vector of extracted CSV paths.
#' @export
us_download_fetch <- function(jobs, dest = us_cache_dir("raw")) {
  jobs <- data.table::as.data.table(jobs)
  ok <- jobs[state == "finished" & !is.na(url)]
  if (!nrow(ok)) {
    cli::cli_warn("No finished jobs to fetch.")
    return(character(0))
  }
  zipdir <- us_cache_dir("jobs")
  for (i in seq_len(nrow(ok))) {
    z <- file.path(zipdir, ok$file_name[i])
    if (!file.exists(z)) {
      r <- try(utils::download.file(ok$url[i], z, mode = "wb", quiet = TRUE), silent = TRUE)
      if (inherits(r, "try-error")) {
        cli::cli_warn("Failed to download {.file {ok$file_name[i]}}.")
        next
      }
    }
    try(utils::unzip(z, exdir = dest), silent = TRUE)
  }
  f <- list.files(dest, pattern = "[.]csv$", full.names = TRUE)
  us_msg("Extracted {length(f)} CSV file{?s} ({round(sum(file.size(f)) / 1e6, 1)} MB) to {.path {dest}}.")
  f
}

## Read the four file families the download endpoint emits and harmonize each.
read_download_dir <- function(dir) {
  pick <- function(pat) list.files(dir, pattern = pat, full.names = TRUE)
  rd <- function(f) data.table::fread(f, colClasses = "character", showProgress = FALSE)
  bind <- function(files, fn, group) {
    if (!length(files)) return(NULL)
    data.table::rbindlist(
      lapply(files, function(f) fn(rd(f), group, source_file = basename(f))),
      use.names = TRUE, fill = TRUE)
  }
  list(
    transactions = data.table::rbindlist(Filter(Negate(is.null), list(
      bind(pick("Assistance_PrimeTransactions.*[.]csv$"), us_harmonize_transactions, "assistance"),
      bind(pick("Contracts_PrimeTransactions.*[.]csv$"),  us_harmonize_transactions, "contract"))),
      use.names = TRUE, fill = TRUE) %||% us_empty("transactions"),
    subawards = data.table::rbindlist(Filter(Negate(is.null), list(
      bind(pick("Assistance_Subawards.*[.]csv$"), us_harmonize_subawards, "assistance"),
      bind(pick("Contracts_Subawards.*[.]csv$"),  us_harmonize_subawards, "contract"))),
      use.names = TRUE, fill = TRUE) %||% us_empty("subawards")
  )
}
