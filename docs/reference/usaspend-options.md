# Package options

`usaspend` reads its configuration from
[`options()`](https://rdrr.io/r/base/options.html). All option names are
prefixed `usaspend.`.

## Options

- `usaspend.base_url`:

  USAspending REST API root.

- `usaspend.archive_url`:

  Award Data Archive file root.

- `usaspend.cache_dir`:

  Where downloads are stored. Defaults to
  `tools::R_user_dir("usaspend", "cache")`.

- `usaspend.throttle`:

  Requests per second. USAspending rate-limits sustained
  single-recipient calls; 2/s is the measured safe ceiling.

- `usaspend.max_tries`:

  Retry attempts per request.

- `usaspend.timeout`:

  Per-request timeout in seconds.

- `usaspend.download_timeout`:

  Seconds allowed per archive-file download (default 3600). R's own
  60-second default truncates gigabyte files mid-stream.

- `usaspend.batch_size`:

  UEIs per bulk-download job. The API caps `recipient_search_text` near
  20, but large recipients time out server-side well below that, so the
  default is deliberately conservative.

- `usaspend.concurrent`:

  Download jobs in flight at once.

- `usaspend.verbose`:

  Emit progress messages.
