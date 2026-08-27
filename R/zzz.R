us_opt_defaults <- list(
  usaspend.base_url    = "https://api.usaspending.gov/api/v2",
  usaspend.archive_url = "https://files.usaspending.gov/award_data_archive",
  usaspend.cache_dir   = NULL,      # resolved lazily by us_cache_dir()
  usaspend.throttle    = 2,         # requests per second
  usaspend.max_tries   = 6,         # retries per request
  usaspend.timeout     = 180,       # seconds per request
  usaspend.batch_size  = 5,         # UEIs per download job; see us_download_run()
  usaspend.concurrent  = 3,         # download jobs in flight
  usaspend.verbose     = TRUE
)

.onLoad <- function(libname, pkgname) {
  op <- options()
  toset <- !(names(us_opt_defaults) %in% names(op))
  if (any(toset)) options(us_opt_defaults[toset])
  invisible()
}

us_opt <- function(name) getOption(paste0("usaspend.", name), us_opt_defaults[[paste0("usaspend.", name)]])

us_msg <- function(..., .envir = parent.frame()) {
  if (isTRUE(us_opt("verbose"))) cli::cli_inform(..., .envir = .envir)
}

#' Package options
#'
#' `usaspend` reads its configuration from `options()`. All option names are
#' prefixed `usaspend.`.
#'
#' @section Options:
#' \describe{
#'   \item{`usaspend.base_url`}{USAspending REST API root.}
#'   \item{`usaspend.archive_url`}{Award Data Archive file root.}
#'   \item{`usaspend.cache_dir`}{Where downloads are stored. Defaults to
#'     `tools::R_user_dir("usaspend", "cache")`.}
#'   \item{`usaspend.throttle`}{Requests per second. USAspending rate-limits
#'     sustained single-recipient calls; 2/s is the measured safe ceiling.}
#'   \item{`usaspend.max_tries`}{Retry attempts per request.}
#'   \item{`usaspend.timeout`}{Per-request timeout in seconds.}
#'   \item{`usaspend.batch_size`}{UEIs per bulk-download job. The API caps
#'     `recipient_search_text` near 20, but large recipients time out server-side
#'     well below that, so the default is deliberately conservative.}
#'   \item{`usaspend.concurrent`}{Download jobs in flight at once.}
#'   \item{`usaspend.verbose`}{Emit progress messages.}
#' }
#' @name usaspend-options
NULL
