#' Cache location
#'
#' Everything `usaspend` downloads is written under a cache directory so that a
#' re-run costs nothing. Annual archives in particular are 1-2 GB each and must
#' never be re-fetched by accident.
#'
#' Layout:
#' ```
#' <cache>/jobs/      API download job zips and their manifests
#' <cache>/raw/       unzipped CSVs from API jobs
#' <cache>/archive/   annual Award Data Archive zips
#' <cache>/parquet/   archive CSVs converted to partitioned parquet
#' <cache>/duckdb/    on-disk duckdb databases
#' ```
#'
#' @param ... Path components appended to the cache root.
#' @param create Create the directory if it does not exist.
#' @return A file path.
#' @export
us_cache_dir <- function(..., create = TRUE) {
  root <- us_opt("cache_dir") %||% tools::R_user_dir("usaspend", "cache")
  p <- if (length(list(...))) file.path(root, ...) else root
  if (create && !dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
  p
}

#' @rdname us_cache_dir
#' @param what Which subdirectory to clear, or `"all"`.
#' @export
us_cache_clear <- function(what = c("jobs", "raw", "archive", "parquet", "duckdb", "all")) {
  what <- match.arg(what)
  subs <- if (what == "all") c("jobs", "raw", "archive", "parquet", "duckdb") else what
  for (s in subs) {
    p <- us_cache_dir(s, create = FALSE)
    if (dir.exists(p)) {
      n <- length(list.files(p, recursive = TRUE))
      unlink(p, recursive = TRUE)
      us_msg("Cleared {.path {s}} ({n} file{?s}).")
    }
  }
  invisible(TRUE)
}

#' @rdname us_cache_dir
#' @export
us_cache_status <- function() {
  subs <- c("jobs", "raw", "archive", "parquet", "duckdb")
  out <- data.table::rbindlist(lapply(subs, function(s) {
    p <- us_cache_dir(s, create = FALSE)
    f <- if (dir.exists(p)) list.files(p, recursive = TRUE, full.names = TRUE) else character(0)
    data.table::data.table(dir = s, n_files = length(f),
                           size_mb = round(sum(file.size(f), na.rm = TRUE) / 1e6, 1))
  }))
  out[]
}
