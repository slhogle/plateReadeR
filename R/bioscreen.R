#' Read Bioscreen C output
#'
#' Reads a plain text export from a Bioscreen C plate reader and returns a
#' tidy (long) table with one row per well per time point.
#'
#' Bioscreen exports are UTF-16LE text files with two preamble lines (`Label`
#' and `Info`), a header line (`Time`, `Blank`, then well numbers) and
#' space-separated rows of readings. The instrument computer often uses a comma
#' as the decimal mark, which is why `decimal_mark` defaults to `","`.
#'
#' A Bioscreen run holds either one or two 100-well plates, so files contain
#' either 100 or 200 wells. Wells 1-100 belong to plate 1 and wells 101-200 to
#' plate 2. Wells are named within each plate by a zero-padded string (`"001"`
#' to `"100"`), so a well is identified by `plate_id` and `well`, as for the
#' LogPhase600 readers. The 1-200 position in the run is kept as `well_index`.
#'
#' The Bioscreen does not report perfectly regular time intervals (for example
#' 00:30:06 versus 00:30:05), which makes it hard to combine runs. By default
#' times are therefore snapped onto a regular grid with [snap_hours()]; see
#' `interval_hours`.
#'
#' @param path Path to the Bioscreen text file. Compressed files (`.gz`, `.xz`,
#'   `.bz2`, `.zip`) are read directly.
#' @param decimal_mark Decimal mark used in the file, `","` or `"."`.
#' @param encoding File encoding. If `NULL` (default) it is detected from the
#'   byte-order mark, falling back to `"UTF-16LE"`, which Bioscreen exports use.
#' @param interval_hours Nominal read interval in hours (default `1/12`, five
#'   minutes). Elapsed times are snapped to multiples of this with
#'   [snap_hours()] so that timepoints match exactly across plates and runs.
#'   Use `NULL` to keep the reported times.
#' @param wells_per_plate Number of wells in each Bioscreen plate (100 for the
#'   Honeycomb plates).
#' @param keep_blank If `TRUE`, keep the `Blank` column as well `"Blank"` (with
#'   `well_index` 0 and `plate_id` `NA`). The
#'   instrument reports this column as all zeros, so it is dropped by default.
#'
#' @return A tibble with columns `seconds`, `hours`, `plate_id` (`"Plate 1"`
#'   or `"Plate 2"`, the same format as the LogPhase600 readers), `well`
#'   (zero-padded well within the plate, `"001"` to `"100"`), `well_index`
#'   (integer position in the run, 1 to 100 or 1 to 200) and `od` (optical
#'   density).
#' @export
#' @examples
#' f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
#' read_bioscreen(f)
read_bioscreen <- function(
  path,
  decimal_mark = ",",
  encoding = NULL,
  interval_hours = 1 / 12,
  wells_per_plate = 100,
  keep_blank = FALSE
) {
  if (!file.exists(path)) {
    rlang::abort(paste0("File not found: ", path))
  }
  encoding <- encoding %||% guess_bioscreen_encoding(path)

  lines <- readr::read_lines(
    path,
    locale = readr::locale(encoding = encoding),
    skip_empty_rows = TRUE
  )
  lines <- trimws(sub("^\ufeff", "", lines))

  header_idx <- grep("^Time\\b", lines)[1]
  if (is.na(header_idx)) {
    rlang::abort("Could not find a header line starting with 'Time'.")
  }

  header <- strsplit(lines[header_idx], "\\s+")[[1]]
  rows <- strsplit(lines[-seq_len(header_idx)], "\\s+")
  rows <- rows[lengths(rows) > 0]
  if (!all(lengths(rows) == length(header))) {
    rlang::abort(
      "Data rows do not all have the same number of fields as the header."
    )
  }

  mat <- matrix(
    unlist(rows, use.names = FALSE),
    nrow = length(rows),
    byrow = TRUE
  )
  colnames(mat) <- header

  seconds <- bioscreen_time_to_seconds(mat[, "Time"])
  if (!is.null(interval_hours)) {
    seconds <- round(snap_hours(seconds / 3600, interval_hours) * 3600, 6)
  }

  well_cols <- setdiff(header, c("Time", if (!keep_blank) "Blank"))
  vals <- readr::parse_double(
    as.vector(mat[, well_cols, drop = FALSE]),
    locale = readr::locale(decimal_mark = decimal_mark)
  )
  well_index <- ifelse(
    well_cols == "Blank",
    0L,
    suppressWarnings(as.integer(well_cols))
  )
  if (anyNA(well_index)) {
    rlang::abort(
      "Well columns must be named by number (and optionally 'Blank')."
    )
  }

  n <- length(seconds)
  index_long <- rep(well_index, each = n)
  seconds_long <- rep(seconds, times = length(well_index))
  is_blank <- index_long == 0L
  width <- nchar(as.character(wells_per_plate))
  out <- tibble::tibble(
    seconds = seconds_long,
    hours = seconds_long / 3600,
    plate_id = ifelse(
      is_blank,
      NA_character_,
      paste("Plate", (index_long - 1L) %/% wells_per_plate + 1L)
    ),
    well = ifelse(
      is_blank,
      "Blank",
      sprintf("%0*d", width, (index_long - 1L) %% wells_per_plate + 1L)
    ),
    well_index = index_long,
    od = vals
  )
  out[order(out$well_index, out$seconds), ]
}

# Convert "HH:MM:SS" (hours may exceed 24) to seconds
bioscreen_time_to_seconds <- function(x) {
  secs <- suppressWarnings(
    lubridate::period_to_seconds(lubridate::hms(x, quiet = TRUE))
  )
  if (anyNA(secs)) {
    rlang::abort("Times must be formatted as HH:MM:SS.")
  }
  secs
}

#' Snap elapsed time onto a regular grid
#'
#' Each plate reader keeps its own clock, so the elapsed time for what is meant
#' to be the same nominal timepoint can drift by a second or more between
#' plates and runs. Left as is, that drift makes exact-value grouping (for
#' example `group_by(hours)` when pooling replicates across plates) fracture
#' into several near-duplicate groups, which shows up downstream as an
#' artificially jagged mean. Snapping elapsed hours onto the nominal read
#' interval grid makes timepoints line up exactly.
#'
#' @param hours Numeric vector of elapsed time in hours.
#' @param interval_hours Nominal read interval in hours. Defaults to 20
#'   minutes (`1/3`).
#'
#' @return Numeric vector of hours, rounded to the nearest multiple of
#'   `interval_hours`.
#' @export
#' @examples
#' snap_hours(c(0, 0.3336, 0.6661, 1.0003))
snap_hours <- function(hours, interval_hours = 1 / 3) {
  round(hours / interval_hours) * interval_hours
}

# Bioscreen exports are UTF-16LE with a byte-order mark. Detect the encoding
# from the BOM and default to UTF-16LE when there is none.
guess_bioscreen_encoding <- function(path) {
  bom <- readBin(path, what = "raw", n = 3)
  if (length(bom) >= 3 && identical(bom[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
    "UTF-8"
  } else if (length(bom) >= 2 && identical(bom[1:2], as.raw(c(0xfe, 0xff)))) {
    "UTF-16BE"
  } else {
    "UTF-16LE"
  }
}
