## Annual Award Data Archive path -- the batch option.
##
## Measured 2026-08-27:
##   * list_monthly_files serves only two types, "assistance" and "contracts".
##     Direct payments, loans and "other" are folded into assistance; there is
##     NO bulk subaward archive, so pass-through has to come from the API
##     (see us_fetch_subawards_out()).
##   * FY2024_All_Assistance_Full is 1.37 GB zipped and unpacks to six CSV parts.
##   * Each fiscal year also has a "Delta" file covering changes since the last
##     full refresh.
##
## Crossover with the API path: a download job covers at most ~20 UEIs, so N
## recipients cost roughly N/5 jobs on the API path but a fixed ~36 archives
## (18 fiscal years x 2 types) on this one. Past a few thousand UEIs the archive
## wins outright. us_extract_plan() computes the comparison for a given input.

#' List available annual archive files
#'
#' @param fiscal_year Integer vector of fiscal years. `NULL` returns whatever
#'   the endpoint offers for the current year.
#' @param type `"assistance"`, `"contracts"`, or both.
#' @param full_only Drop the incremental "Delta" files.
#' @return A `data.table` with `fiscal_year`, `type`, `file_name`, `url`,
#'   `updated_date`, `is_delta`.
#' @export
#' @examples
#' \dontrun{
#' us_archive_manifest(2024)
#' }
us_archive_manifest <- function(fiscal_year = NULL,
                                type = c("assistance", "contracts"),
                                full_only = TRUE) {
  type <- match.arg(type, several.ok = TRUE)
  fy <- fiscal_year %||% as.integer(format(Sys.Date(), "%Y"))
  grid <- expand.grid(fiscal_year = as.integer(fy), type = type,
                      stringsAsFactors = FALSE)
  out <- data.table::rbindlist(lapply(seq_len(nrow(grid)), function(i) {
    r <- us_api_try("bulk_download/list_monthly_files/", body = list(
      agency = "all", fiscal_year = grid$fiscal_year[i], type = grid$type[i]))
    if (!r$ok) {
      cli::cli_warn("Manifest lookup failed for FY{grid$fiscal_year[i]} {grid$type[i]}.")
      return(NULL)
    }
    f <- r$result$monthly_files %||% list()
    if (!length(f)) return(NULL)
    dt <- rows_to_dt(f)
    data.table::data.table(
      fiscal_year  = as_int(dt$fiscal_year),
      type         = as_chr(dt$type),
      file_name    = as_chr(dt$file_name),
      url          = as_chr(dt$url),
      updated_date = as_date(dt$updated_date))
  }), fill = TRUE)
  if (!nrow(out)) return(out)
  out[, "is_delta" := grepl("_Delta_", file_name, fixed = TRUE)]
  if (full_only) out <- out[is_delta == FALSE]
  out[]
}

#' Size an archive pull before committing to it
#'
#' Issues HEAD requests so you can see the download volume before spending it.
#'
#' @param manifest Output of [us_archive_manifest()].
#' @return The manifest with a `size_mb` column and a printed total.
#' @export
us_archive_size <- function(manifest) {
  manifest <- data.table::as.data.table(manifest)
  sz <- vapply(manifest$url, function(u) {
    r <- tryCatch(
      httr2::req_perform(httr2::req_method(httr2::request(u), "HEAD")),
      error = function(e) NULL)
    if (is.null(r)) return(NA_real_)
    as.numeric(httr2::resp_header(r, "content-length") %||% NA)
  }, numeric(1), USE.NAMES = FALSE)
  manifest[, "size_mb" := round(sz / 1e6, 1)]
  us_msg("{nrow(manifest)} archive{?s}, {round(sum(manifest$size_mb, na.rm = TRUE) / 1000, 2)} GB compressed.")
  manifest[]
}

#' Download and unpack annual archives
#'
#' Archives are cached under `us_cache_dir("archive")` and never re-fetched if
#' present -- these are gigabyte files and an accidental re-download is
#' expensive.
#'
#' A cached zip is trusted only if its central directory reads back cleanly
#' (`unzip(list = TRUE)`); a truncated file from an interrupted download is
#' deleted and re-fetched rather than silently unpacked. Downloads run with
#' `timeout` raised to `usaspend.download_timeout` (default 3600 s) -- R's
#' 60-second default truncates gigabyte files mid-stream -- and a failed or
#' short download is removed instead of being left to masquerade as a cache
#' hit.
#'
#' @param manifest Output of [us_archive_manifest()].
#' @param unpack Unzip after downloading.
#' @return The manifest with `zip_path` and `csv_dir` columns.
#' @export
us_archive_download <- function(manifest, unpack = TRUE) {
  manifest <- data.table::as.data.table(manifest)
  root <- us_cache_dir("archive")
  manifest[, "zip_path" := file.path(root, file_name)]
  manifest[, "csv_dir" := file.path(root, tools::file_path_sans_ext(file_name))]
  zip_ok <- function(z) {
    !inherits(try(utils::unzip(z, list = TRUE), silent = TRUE), "try-error")
  }
  old <- options(timeout = max(us_opt("download_timeout"), getOption("timeout")))
  on.exit(options(old), add = TRUE)
  for (i in seq_len(nrow(manifest))) {
    z <- manifest$zip_path[i]
    if (file.exists(z) && !zip_ok(z)) {
      cli::cli_warn("Cached {.file {basename(z)}} is corrupt (interrupted download?); re-fetching.")
      unlink(z)
    }
    if (file.exists(z)) {
      us_msg("Cached: {.file {basename(z)}} ({round(file.size(z) / 1e6)} MB).")
    } else {
      us_msg("Downloading {.file {basename(z)}} ...")
      r <- try(utils::download.file(manifest$url[i], z, mode = "wb", quiet = FALSE), silent = TRUE)
      if (inherits(r, "try-error") || !file.exists(z) || !zip_ok(z)) {
        unlink(z)
        cli::cli_warn("Download failed: {.file {basename(z)}}")
        next
      }
    }
    if (unpack) {
      d <- manifest$csv_dir[i]
      if (!dir.exists(d) || !length(list.files(d, pattern = "[.]csv$"))) {
        dir.create(d, recursive = TRUE, showWarnings = FALSE)
        try(utils::unzip(z, exdir = d), silent = TRUE)
      }
    }
  }
  manifest[]
}

#' Check that an archive matches the canonical field map
#'
#' The package assumes the annual archive CSVs carry the same column names as
#' the bulk download endpoint. That assumption is stated, not measured -- the
#' probe that established the download schema used the API path, and verifying
#' the archive means unpacking a gigabyte file. Run this once against a real
#' archive to confirm, and it will tell you exactly which mapped columns are
#' missing.
#'
#' @param csv_dir Directory of unpacked archive CSVs.
#' @param group `"assistance"` or `"contract"`.
#' @return A `data.table` of `canonical_field`, `raw_column`, `present`.
#' @export
us_archive_verify_schema <- function(csv_dir, group = c("assistance", "contract")) {
  group <- match.arg(group)
  f <- list.files(csv_dir, pattern = "[.]csv$", full.names = TRUE)
  if (!length(f)) us_abort("No CSV files in {.path {csv_dir}}.")
  cols <- names(data.table::fread(f[1], nrows = 0L))
  map  <- if (group == "assistance") tx_map_assistance() else tx_map_contract()
  out  <- data.table::data.table(canonical_field = names(map),
                                 raw_column = unname(map),
                                 present = unname(map) %in% cols)
  miss <- out[present == FALSE]
  if (nrow(miss)) {
    cli::cli_warn(c("{nrow(miss)} mapped column{?s} absent from the archive:",
                    "x" = "{.val {miss$raw_column}}"))
  } else {
    us_msg("All {nrow(out)} mapped columns present.")
  }

  ## Matching names are necessary, not sufficient: archive contract files are
  ## known to transpose the (code, description) pairs below. Sample values and
  ## report, so a new transposition surfaces here rather than as silent
  ## misclassification downstream. The harmonizer un-swaps these on its own.
  if (group == "contract") {
    pairs <- list(c("action_type_code", "action_type"),
                  c("idv_type_code", "idv_type"))
    smp <- data.table::fread(f[1], nrows = 10000L,
                             select = intersect(unlist(pairs), cols),
                             colClasses = "character")
    for (p in pairs) {
      if (!all(p %in% names(smp))) next
      v <- smp[[p[1]]]; v <- v[!is.na(v) & nzchar(v)]
      if (length(v) && mean(nchar(v) <= 1L) <= 0.5) {
        cli::cli_warn(c("Values in {.field {p[1]}} look like descriptions, not codes.",
                        "i" = "This archive transposes {.field {p[1]}}/{.field {p[2]}}; {.fn us_harmonize_transactions} detects and un-swaps this automatically."))
      }
    }
  }
  out[]
}

#' Filter unpacked archives down to a set of UEIs
#'
#' Streams the archive CSVs through duckdb, keeps only rows whose
#' `recipient_uei` is in `uei`, and harmonizes the result to
#' `us_schema("transactions")`. Memory stays bounded because duckdb reads the
#' CSVs lazily and the UEI list is joined as a table rather than pasted into a
#' giant `IN` clause.
#'
#' @param uei Character vector of UEIs to keep.
#' @param csv_dir One or more directories of unpacked archive CSVs.
#' @param group `"assistance"` or `"contract"` -- which family these files hold.
#' @param memory_limit duckdb memory ceiling.
#' @param parquet_out Optional path; if given, the filtered rows are also
#'   written to parquet so later runs skip the CSV scan entirely.
#' @return A `data.table` matching `us_schema("transactions")`.
#' @export
us_archive_filter <- function(uei, csv_dir, group = c("assistance", "contract"),
                              memory_limit = "8GB", parquet_out = NULL) {
  group <- match.arg(group)
  uei <- unique(us_validate_uei(uei))
  uei <- uei[!is.na(uei)]
  files <- unlist(lapply(csv_dir, list.files, pattern = "[.]csv$", full.names = TRUE),
                  use.names = FALSE)
  if (!length(files)) us_abort("No CSV files found under {.path {csv_dir}}.")

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, sprintf("SET memory_limit='%s'", memory_limit))

  glob <- paste0("['", paste(gsub("\\\\", "/", files), collapse = "','"), "']")
  DBI::dbExecute(con, sprintf(
    "CREATE VIEW raw AS SELECT * FROM read_csv(%s, header=true, all_varchar=true,
     union_by_name=true, filename=true)", glob))
  DBI::dbWriteTable(con, "keep", data.frame(uei = uei, stringsAsFactors = FALSE))

  us_msg("Scanning {length(files)} archive file{?s} for {length(uei)} UEI{?s} ...")
  raw <- DBI::dbGetQuery(con, "
    SELECT r.* FROM raw r
    JOIN keep k ON upper(trim(r.recipient_uei)) = k.uei")
  us_msg("Matched {nrow(raw)} transaction{?s}.")

  out <- us_harmonize_transactions(raw, group,
                                   source_file = paste0("archive:", group))
  if (!is.null(parquet_out)) {
    dir.create(dirname(parquet_out), recursive = TRUE, showWarnings = FALSE)
    DBI::dbWriteTable(con, "out", as.data.frame(out), overwrite = TRUE)
    DBI::dbExecute(con, sprintf("COPY out TO '%s' (FORMAT PARQUET)",
                                gsub("\\\\", "/", parquet_out)))
    us_msg("Wrote {.path {parquet_out}}.")
  }
  out[]
}
