#' Read LogPhase600 text export
#'
#' Reads a text file exported from a LogPhase600 plate reader. The file has a
#' header block (procedure summary) followed by a line starting with `Time` and
#' the well names, and then one row per read. The header block is located
#' automatically.
#'
#' Time is made relative to the first read and snapped to a regular grid with
#' [snap_hours()] so that replicate plates line up exactly. Well ids are
#' zero-padded (`A1` becomes `A01`).
#'
#' @param path Path to the text file.
#' @param interval_hours Nominal read interval in hours, passed to
#'   [snap_hours()]. Default is 20 minutes (`1/3`). Use `NULL` to keep the
#'   reported times.
#' @param thin_hours Optional coarser read interval in hours, for example `1`
#'   to keep one read per hour. Thinning happens after times are snapped to the
#'   `interval_hours` grid, keeps only reads that fall on the coarser grid, and
#'   requires `interval_hours` to be set and `thin_hours` to be a whole
#'   multiple of it. `NULL` (default) keeps every read.
#' @param encoding File encoding. Defaults to `"latin1"`, which these exports
#'   use (the header contains a degree sign).
#'
#' @return A tibble with columns `seconds`, `hours`, `well`, `od` and
#'   `plate_id`. `plate_id` is taken from the `Plate Number` line of the
#'   header (for example `"Plate 1"`), matching the sheet names in the Excel
#'   export. If that line is missing, the file name without its extension is
#'   used.
#' @export
#' @examples
#' f <- system.file("extdata", "logphase600_example.txt", package = "plateReadeR")
#' read_logphase_txt(f)
read_logphase_txt <- function(
  path,
  interval_hours = 1 / 3,
  thin_hours = NULL,
  encoding = "latin1"
) {
  if (!file.exists(path)) {
    rlang::abort(paste0("File not found: ", path))
  }
  lines <- readr::read_lines(
    path,
    locale = readr::locale(encoding = encoding),
    skip_empty_rows = TRUE
  )
  header_idx <- grep("^Time\\t", lines)[1]
  if (is.na(header_idx)) {
    rlang::abort("Could not find a header line starting with 'Time'.")
  }
  df <- readr::read_tsv(
    I(lines[header_idx:length(lines)]),
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )
  out <- tidy_plate_wide(
    df,
    interval_hours = interval_hours,
    thin_hours = thin_hours
  )
  out$plate_id <- logphase_txt_plate_id(lines[seq_len(header_idx - 1)], path)
  out
}

# Plate id from the "Plate Number:" header line, else the file name
logphase_txt_plate_id <- function(header_lines, path) {
  m <- regmatches(
    header_lines,
    regexpr("(?<=Plate Number:)\\s*[0-9]+", header_lines, perl = TRUE)
  )
  if (length(m) > 0) {
    paste("Plate", trimws(m[1]))
  } else {
    tools::file_path_sans_ext(basename(path))
  }
}

#' Read LogPhase600 Excel export
#'
#' Reads one kind of sheet from an Excel export of a LogPhase600 plate reader.
#' A run can hold up to four 96-well plates, and each plate has its own
#' `Results`, `Raw Data` and `Procedure` sheets (for example `Plate 1 - Raw
#' Data`). The `sheet` argument chooses which kind to read; every plate in the
#' file is read and the plates are stacked into one table, identified by
#' `plate_id`. To keep only some plates, filter on `plate_id` afterwards.
#'
#' * `"raw"`: the optical density time courses, equivalent to the text files.
#'   Processing is the same as for [read_logphase_txt()].
#' * `"results"`: the per-well summary the instrument software computed (lag
#'   time, maximum growth rate and stationary phase). These are rarely needed,
#'   since the package works from the raw reads, but they are available for
#'   comparison with your own estimates. The instrument stores lag time and
#'   stationary phase as Excel day fractions, which are converted to hours.
#'   Wells for which the software reported no value (`?????` in the sheet) are
#'   `NA`.
#' * `"procedure"`: the run settings recorded for each plate, parsed from the
#'   procedure summary text into one row per plate. Times are converted to
#'   hours and on/off settings to logicals. The original text is kept in
#'   `summary`, in case a setting is not covered by the parsed columns.
#'
#' @param path Path to the xlsx file.
#' @param sheet Which kind of sheet to read: `"raw"` (default), `"results"` or
#'   `"procedure"`.
#' @param interval_hours,thin_hours Used only when `sheet = "raw"`. See
#'   [read_logphase_txt()].
#'
#' @return A tibble. The columns depend on `sheet`; all have `plate_id`, the
#'   sheet name without the trailing sheet type (such as `"Plate 1"`).
#'
#'   * `"raw"`: `seconds`, `hours`, `well`, `od` and `plate_id`.
#'   * `"results"`: one row per well with `plate_id`, `well` (zero-padded as
#'     for `"raw"`), `lag_hours`, `max_rate` (OD per minute) and
#'     `stationary_hours`. Join to the raw data by `plate_id` and `well`.
#'   * `"procedure"`: one row per plate with `plate_id`, `plate_comment`,
#'     `plate_type`, `runtime_hours`, `interval_hours`, `max_reads`,
#'     `wavelength_nm`, `incubator`, `temperature_setpoint_c`,
#'     `temperature_gradient`, `shaking`, `shaking_rpm` and `summary`.
#' @export
#' @examples
#' f <- system.file("extdata", "logphase600_example.xlsx", package = "plateReadeR")
#' read_logphase_xlsx(f)
#' read_logphase_xlsx(f, sheet = "results")
#' read_logphase_xlsx(f, sheet = "procedure")
read_logphase_xlsx <- function(
  path,
  sheet = c("raw", "results", "procedure"),
  interval_hours = 1 / 3,
  thin_hours = NULL
) {
  sheet <- rlang::arg_match(sheet)
  if (!file.exists(path)) {
    rlang::abort(paste0("File not found: ", path))
  }
  kind <- c(raw = "Raw Data", results = "Results", procedure = "Procedure")
  sheets <- plate_sheets(path, kind[[sheet]])

  pieces <- lapply(seq_len(nrow(sheets)), function(i) {
    name <- sheets$sheet[i]
    plate_id <- sheets$plate_id[i]
    switch(
      sheet,
      raw = read_raw_sheet(path, name, plate_id, interval_hours, thin_hours),
      results = logphase_results_sheet(path, name, plate_id),
      procedure = logphase_procedure_sheet(path, name, plate_id)
    )
  })
  do.call(rbind, pieces)
}

# One LogPhase600 Results sheet: one row per well
logphase_results_sheet <- function(path, sheet, plate_id) {
  df <- readxl::read_xlsx(
    path,
    sheet = sheet,
    col_types = "text",
    .name_repair = "minimal"
  )
  needed <- c("Well", "Lagtime", "Max Rate (OD/min)", "Stationary Phase")
  if (!all(needed %in% names(df))) {
    rlang::abort(
      paste0(
        "Sheet '",
        sheet,
        "' is missing columns: ",
        paste(setdiff(needed, names(df)), collapse = ", "),
        ". Synergy H1 exports are read with `read_synergy_xlsx()`."
      )
    )
  }
  num <- function(x) suppressWarnings(as.numeric(x))
  tibble::tibble(
    plate_id = plate_id,
    well = pad_well_id(df$Well),
    lag_hours = num(df$Lagtime) * 24,
    max_rate = num(df$`Max Rate (OD/min)`),
    stationary_hours = num(df$`Stationary Phase`) * 24
  )
}

# One LogPhase600 Procedure sheet: a single row. The sheet holds a "Plate
# Comment:" label in column 1 and the procedure summary text in column 2.
logphase_procedure_sheet <- function(path, sheet, plate_id) {
  cells <- read_cells(path, sheet)
  all_text <- unlist(cells, use.names = FALSE)
  all_text <- all_text[!is.na(all_text)]
  summary <- all_text[grepl("^\\s*Procedure Summary", all_text)][1]
  if (is.na(summary)) {
    rlang::abort(
      paste0("No 'Procedure Summary' text found on sheet '", sheet, "'.")
    )
  }
  comment <- trimws(sub("^\\s*Plate Comment:?", "", cells[[1]]))
  comment <- comment[!is.na(comment) & nzchar(comment)]
  comment <- if (length(comment)) {
    paste(comment, collapse = "\n")
  } else {
    NA_character_
  }

  out <- parse_logphase_procedure(summary)
  tibble::add_column(
    out,
    plate_id = plate_id,
    plate_comment = comment,
    .before = 1
  )
}

# Parse the procedure summary text. Fields are separated by runs of two or
# more spaces and look like "Key: value".
parse_logphase_procedure <- function(x) {
  parts <- trimws(strsplit(sub("^\\s*Procedure Summary", "", x), "\\s{2,}")[[
    1
  ]])
  parts <- parts[grepl(":", parts, fixed = TRUE)]
  key <- trimws(sub("^([^:]*):.*$", "\\1", parts))
  value <- trimws(sub("^[^:]*:", "", parts))
  get <- function(k) {
    v <- value[key == k]
    if (length(v) > 0) v[[1]] else NA_character_
  }
  on_off <- function(v) if (is.na(v)) NA else tolower(v) == "on"
  num <- function(v) readr::parse_number(v)

  kinetics <- value[grepl("Kinetics$", key)][1]
  duration <- function(label) {
    m <- regmatches(
      kinetics,
      regexec(
        paste0(label, "\\s+([0-9:]+)\\s*\\(([A-Z:]+)\\)"),
        kinetics
      )
    )[[1]]
    if (length(m) == 3) duration_to_hours(m[2], m[3]) else NA_real_
  }
  max_reads <- regmatches(kinetics, regexec("([0-9]+)\\s*Reads", kinetics))[[1]]

  tibble::tibble(
    plate_type = get("Plate Type"),
    runtime_hours = duration("Runtime"),
    interval_hours = duration("Interval"),
    max_reads = if (length(max_reads) == 2) {
      as.integer(max_reads[2])
    } else {
      NA_integer_
    },
    wavelength_nm = num(get("Read")),
    incubator = on_off(get("Incubator")),
    temperature_setpoint_c = num(get("Temperature setpoint")),
    temperature_gradient = on_off(get("Temperature gradient")),
    shaking = on_off(get("Shaking")),
    shaking_rpm = num(get("Shaking frequency")),
    summary = trimws(x)
  )
}
