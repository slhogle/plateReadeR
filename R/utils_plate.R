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
tidy_plate_wide <- function(df, interval_hours = 1 / 3, thin_hours = NULL) {
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
  out <- thin_reads(out, thin_hours, interval_hours)
  out[order(out$well, out$seconds), ]
}

# Keep only reads that fall on a coarser grid. This must run after snapping, so
# it needs the snapping interval and requires `thin_hours` to be a whole
# multiple of it.
thin_reads <- function(df, thin_hours, interval_hours) {
  if (is.null(thin_hours)) {
    return(df)
  }
  if (!is.numeric(thin_hours) || length(thin_hours) != 1 || thin_hours <= 0) {
    rlang::abort("`thin_hours` must be a single positive number or NULL.")
  }
  if (is.null(interval_hours)) {
    rlang::abort(
      "`thin_hours` needs times snapped to a grid; set `interval_hours`."
    )
  }
  ratio <- thin_hours / interval_hours
  if (abs(ratio - round(ratio)) > 1e-6) {
    rlang::abort("`thin_hours` must be a whole multiple of `interval_hours`.")
  }
  k <- df$hours / thin_hours
  df[abs(k - round(k)) < 1e-6, ]
}

# Find the sheets of one kind (for example "Raw Data") in a plate-reader
# workbook. Sheet names look like "Plate 1 - Raw Data"; the plate id is the
# part before the dash.
plate_sheets <- function(path, kind) {
  all_sheets <- readxl::excel_sheets(path)
  hit <- all_sheets[grepl(kind, all_sheets, fixed = TRUE)]
  if (length(hit) == 0) {
    rlang::abort(
      paste0(
        "No sheets with '",
        kind,
        "' in the name found. Sheets in this file: ",
        paste(all_sheets, collapse = ", ")
      )
    )
  }
  tibble::tibble(
    sheet = hit,
    plate_id = trimws(sub("\\s*[-\u2013].*$", "", hit))
  )
}

# Read a "Raw Data" sheet (a `Time` header row, optionally preceded by a label
# row such as "OD600") and tidy it.
read_raw_sheet <- function(path, sheet, plate_id, interval_hours, thin_hours) {
  top <- read_cells(path, sheet, n_max = 10)
  header_row <- which(top[[1]] == "Time")[1]
  if (is.na(header_row)) {
    rlang::abort(
      paste0("Could not find a 'Time' header row on sheet '", sheet, "'.")
    )
  }
  df <- readxl::read_xlsx(
    path,
    sheet = sheet,
    skip = header_row - 1,
    .name_repair = "minimal"
  )
  df <- df[!is.na(df$Time), ]
  out <- tidy_plate_wide(
    df,
    interval_hours = interval_hours,
    thin_hours = thin_hours
  )
  out$plate_id <- plate_id
  out
}

# Convert a duration like "02:00:00" with a format label like "D:HH:MM" to
# hours. The label says what each field means.
duration_to_hours <- function(value, format) {
  vals <- suppressWarnings(as.numeric(strsplit(value, ":", fixed = TRUE)[[1]]))
  units <- strsplit(format, ":", fixed = TRUE)[[1]]
  per_hour <- c(D = 24, HH = 1, MM = 1 / 60, SS = 1 / 3600)
  if (length(vals) != length(units) || !all(units %in% names(per_hour))) {
    return(NA_real_)
  }
  sum(vals * per_hour[units])
}

# Read a sheet as a grid of text cells with no header handling
read_cells <- function(path, sheet, ...) {
  suppressMessages(
    readxl::read_xlsx(
      path,
      sheet = sheet,
      col_names = FALSE,
      col_types = "text",
      ...
    )
  )
}
