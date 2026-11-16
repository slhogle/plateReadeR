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
  out <- tidy_plate_wide(df, interval_hours = interval_hours)
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
#' Reads the raw data sheets from an Excel export of a LogPhase600 plate
#' reader. A run can hold up to four 96-well plates. Each plate has its own
#' `Results`, `Raw Data` and `Procedure` sheets (for example `Plate 1 - Raw
#' Data`). Only the `Raw Data` sheets are read, one per plate; these are
#' equivalent to the text files.
#'
#' Processing is the same as for [read_logphase_txt()].
#'
#' @param path Path to the xlsx file.
#' @param sheet Sheet names or numbers to read. If `NULL` (default), every
#'   sheet with `Raw Data` in its name.
#' @param skip Rows to skip before the header row on each sheet.
#' @inheritParams read_logphase_txt
#'
#' @return A tibble with columns `seconds`, `hours`, `well`, `od` and
#'   `plate_id` (the sheet name without the `- Raw Data` suffix, such as
#'   `"Plate 1"`).
#' @export
#' @examples
#' f <- system.file("extdata", "logphase600_example.xlsx", package = "plateReadeR")
#' read_logphase_xlsx(f)
read_logphase_xlsx <- function(
  path,
  sheet = NULL,
  skip = 0,
  interval_hours = 1 / 3
) {
  if (!file.exists(path)) {
    rlang::abort(paste0("File not found: ", path))
  }
  if (is.null(sheet)) {
    sheet <- grep("Raw Data", readxl::excel_sheets(path), value = TRUE)
    if (length(sheet) == 0) {
      rlang::abort(
        "No sheets with 'Raw Data' in the name found; supply `sheet`."
      )
    }
  }
  names(sheet) <- if (is.character(sheet)) {
    trimws(sub("[-\u2013 ]*Raw Data.*$", "", sheet))
  } else {
    paste("Sheet", sheet)
  }

  pieces <- lapply(seq_along(sheet), function(i) {
    df <- readxl::read_xlsx(path, sheet = sheet[[i]], skip = skip)
    out <- tidy_plate_wide(df, interval_hours = interval_hours)
    out$plate_id <- names(sheet)[i]
    out
  })
  do.call(rbind, pieces)
}
