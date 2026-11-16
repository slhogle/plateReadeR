# Shared helpers for plate readers that export a wide layout: elapsed time in
# the first column and one column per well (A1, A2, ...) across the top.

# Convert the Time column of a wide export to elapsed seconds. Handles
# "H:MM:SS" strings (hours may exceed 24), Excel day fractions (numeric),
# date-times and hms/difftime objects.
plate_time_to_seconds <- function(x) {
  secs <- if (inherits(x, "POSIXt")) {
    as.numeric(x)
  } else if (inherits(x, c("hms", "difftime"))) {
    as.numeric(x, units = "secs")
  } else if (is.numeric(x)) {
    x * 86400
  } else {
    suppressWarnings(
      lubridate::period_to_seconds(lubridate::hms(
        as.character(x),
        quiet = TRUE
      ))
    )
  }
  if (anyNA(secs)) {
    rlang::abort("Could not interpret the `Time` column as elapsed time.")
  }
  secs
}

# Zero-pad well ids so A1 becomes A01
pad_well_id <- function(x) {
  ok <- grepl("^[A-Ha-h][0-9]+$", x)
  out <- x
  out[ok] <- sprintf(
    "%s%02d",
    toupper(substr(x[ok], 1, 1)),
    as.integer(substr(x[ok], 2, nchar(x[ok])))
  )
  out
}

# Tidy a wide plate export (data frame with a `Time` column and one column per
# well) into a long tibble. Time is made relative to the first read and snapped
# to the nominal read interval so replicate plates align exactly.
tidy_plate_wide <- function(df, interval_hours = 1 / 3) {
  if (!"Time" %in% names(df)) {
    rlang::abort("Expected a column named 'Time'.")
  }
  well_cols <- grep("^[A-Ha-h][0-9]+$", names(df), value = TRUE)
  if (length(well_cols) == 0) {
    rlang::abort("No well columns (A1, A2, ...) found.")
  }

  secs <- plate_time_to_seconds(df$Time)
  secs <- secs - secs[1]
  if (!is.null(interval_hours)) {
    secs <- snap_hours(secs / 3600, interval_hours) * 3600
  }
  secs <- round(secs, 6)

  n <- length(secs)
  od <- suppressWarnings(as.numeric(unlist(df[well_cols], use.names = FALSE)))
  out <- tibble::tibble(
    seconds = rep(secs, times = length(well_cols)),
    hours = rep(secs, times = length(well_cols)) / 3600,
    well = rep(pad_well_id(well_cols), each = n),
    od = od
  )
  out[order(out$well, out$seconds), ]
}
