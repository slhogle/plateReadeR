#' Read Synergy H1 time course Excel export
#'
#' Reads one kind of sheet from an Excel export of a time course (kinetic) run
#' on a BioTek Synergy H1 plate reader. Each plate has `Setup`, `Results` and
#' `Raw Data` sheets (for example `Plate 1 - Raw Data`). The `sheet` argument
#' chooses which kind to read; every plate in the file is read and the plates
#' are stacked into one table, identified by `plate_id`. To keep only some
#' plates, filter on `plate_id` afterwards.
#'
#' * `"raw"`: the optical density time courses. Processing is the same as for
#'   [read_logphase_txt()]. The label row above the header (such as `OD590`) is
#'   skipped.
#' * `"results"`: the per-well summary computed by the instrument software
#'   (lag time, maximum growth rate, doubling time and stationary phase). Times
#'   are stored by the software as Excel day fractions (or, for negative
#'   values, as text such as `-3:13:23`) and are converted to hours. Wells with
#'   no value (`?????`) are `NA`. The `Well ID` and `Name` rows are not read.
#' * `"setup"`: the run protocol (temperature, interval, shaking, read
#'   settings and so on) as a table of `key` and `value`. A key that spans
#'   several lines of the sheet has one row per line. The plate layout and data
#'   reduction blocks that follow the protocol are not read.
#'
#' Single time point (endpoint) exports are read with
#' [read_synergy_endpoint()].
#'
#' @param path Path to the xlsx file.
#' @param sheet Which kind of sheet to read: `"raw"` (default), `"results"` or
#'   `"setup"`.
#' @param interval_hours,thin_hours Used only when `sheet = "raw"`. See
#'   [read_logphase_txt()]. The default interval is 20 minutes (`1/3`).
#'
#' @return A tibble. The columns depend on `sheet`; all have `plate_id`, the
#'   sheet name without the trailing sheet type (such as `"Plate 1"`).
#'
#'   * `"raw"`: `seconds`, `hours`, `well`, `od` and `plate_id`.
#'   * `"results"`: one row per well with `plate_id`, `well` (zero-padded),
#'     `lag_hours`, `max_v` (maximum slope of `ln(OD)`, as reported),
#'     `doubling_hours` and `stationary_hours`.
#'   * `"setup"`: `plate_id`, `key` and `value`.
#' @export
#' @examples
#' f <- system.file("extdata", "synergy_example.xlsx", package = "plateReadeR")
#' read_synergy_xlsx(f)
#' read_synergy_xlsx(f, sheet = "results")
#' read_synergy_xlsx(f, sheet = "setup")
read_synergy_xlsx <- function(
  path,
  sheet = c("raw", "results", "setup"),
  interval_hours = 1 / 3,
  thin_hours = NULL
) {
  sheet <- rlang::arg_match(sheet)
  if (!file.exists(path)) {
    rlang::abort(paste0("File not found: ", path))
  }
  kind <- c(raw = "Raw Data", results = "Results", setup = "Setup")
  sheets <- tryCatch(
    plate_sheets(path, kind[[sheet]]),
    error = function(e) {
      rlang::abort(
        paste0(
          conditionMessage(e),
          " Single time point exports are read with `read_synergy_endpoint()`."
        )
      )
    }
  )

  pieces <- lapply(seq_len(nrow(sheets)), function(i) {
    name <- sheets$sheet[i]
    plate_id <- sheets$plate_id[i]
    switch(
      sheet,
      raw = read_raw_sheet(path, name, plate_id, interval_hours, thin_hours),
      results = synergy_results_sheet(path, name, plate_id),
      setup = synergy_setup_sheet(path, name, plate_id)
    )
  })
  do.call(rbind, pieces)
}

# One Synergy Results sheet. Wells run across the columns and each statistic
# is a row.
synergy_results_sheet <- function(path, sheet, plate_id) {
  cells <- read_cells(path, sheet)
  well_row <- which(cells[[1]] == "Well")[1]
  if (is.na(well_row)) {
    rlang::abort(paste0("No 'Well' row found on sheet '", sheet, "'."))
  }
  wells <- unlist(cells[well_row, -1], use.names = FALSE)
  ok <- !is.na(wells)

  metric <- function(pattern, convert) {
    i <- which(grepl(pattern, cells[[1]]))[1]
    if (is.na(i)) {
      return(rep(NA_real_, sum(ok)))
    }
    convert(unlist(cells[i, -1], use.names = FALSE)[ok])
  }
  as_num <- function(x) suppressWarnings(as.numeric(x))

  tibble::tibble(
    plate_id = plate_id,
    well = pad_well_id(wells[ok]),
    lag_hours = metric("^Lagtime", day_fraction_to_hours),
    max_v = metric("^Max V \\[LnOD\\]", as_num),
    doubling_hours = metric("^Doubling Time", day_fraction_to_hours),
    stationary_hours = metric("^Stationary Phase", day_fraction_to_hours)
  )
}

# Excel stores durations as day fractions. Negative durations cannot be
# stored as dates, so the export holds them as text like "-3:13:23".
day_fraction_to_hours <- function(x) {
  out <- suppressWarnings(as.numeric(x)) * 24
  clock <- grepl("^-?[0-9]+:[0-9]{2}:[0-9]{2}$", x)
  parts <- strsplit(sub("^-", "", x[clock]), ":", fixed = TRUE)
  out[clock] <- vapply(
    parts,
    function(p) sum(as.numeric(p) / c(1, 60, 3600)),
    numeric(1)
  ) *
    ifelse(startsWith(x[clock], "-"), -1, 1)
  out
}

# One Synergy Setup sheet: key in column 1 (blank on continuation lines) and
# value in column 2, ending at the "Plate Layout" block.
synergy_setup_sheet <- function(path, sheet, plate_id) {
  cells <- read_cells(path, sheet)
  key <- cells[[1]]
  value <- if (ncol(cells) >= 2) cells[[2]] else rep(NA_character_, nrow(cells))
  stop_row <- which(key == "Plate Layout")[1]
  if (!is.na(stop_row)) {
    key <- key[seq_len(stop_row - 1)]
    value <- value[seq_len(stop_row - 1)]
  }

  # Carry each key down over its continuation lines. Blank lines are dropped
  # first, so they do not inherit a key.
  keep <- !(is.na(key) & is.na(value)) & !(key %in% "Procedure Summary")
  last_key <- cummax(ifelse(is.na(key), 0L, seq_along(key)))
  key <- ifelse(last_key == 0L, NA_character_, key[pmax(last_key, 1L)])
  tibble::tibble(
    plate_id = plate_id,
    key = key[keep],
    value = value[keep]
  )
}

#' Read Synergy H1 single time point Excel export
#'
#' Reads an Excel export of a single time point (endpoint) measurement from a
#' BioTek Synergy H1 plate reader and returns one row per well. Two layouts
#' are recognised and detected automatically: the Gen5 report layout (a block
#' of run details followed by a row of wells and a row of readings) and a plain
#' 8 by 12 grid with column numbers across the top and row letters down the
#' side. Every sheet in the file is read.
#'
#' For time course exports use [read_synergy_xlsx()].
#'
#' @param path Path to the xlsx file.
#'
#' @return A tibble with columns `plate_id`, `well` (zero-padded, such as
#'   `"A01"`), `od` and `wavelength_nm`. `plate_id` is taken from the sheet
#'   name when it starts with `Plate` (for example `"Plate 19 - Sheet1"` gives
#'   `"Plate 19"`), otherwise the file name without its extension is used.
#'   `wavelength_nm` is `NA` if the file does not record it.
#' @export
#' @examples
#' f <- system.file("extdata", "synergy_endpoint_example.xlsx", package = "plateReadeR")
#' read_synergy_endpoint(f)
read_synergy_endpoint <- function(path) {
  if (!file.exists(path)) {
    rlang::abort(paste0("File not found: ", path))
  }
  pieces <- lapply(readxl::excel_sheets(path), function(sheet) {
    cells <- read_cells(path, sheet)
    plate_id <- if (grepl("^Plate\\s*[0-9]+", sheet)) {
      trimws(sub("\\s*[-\u2013].*$", "", sheet))
    } else {
      tools::file_path_sans_ext(basename(path))
    }
    out <- if (ncol(cells) >= 2 && any(cells[[2]] == "Well", na.rm = TRUE)) {
      synergy_endpoint_report(cells)
    } else if (any(grepl("^[A-Ha-h]$", cells[[1]]))) {
      synergy_endpoint_grid(cells)
    } else {
      rlang::abort(
        paste0("Sheet '", sheet, "' is not a recognised endpoint layout.")
      )
    }
    out$plate_id <- plate_id
    out[c("plate_id", "well", "od", "wavelength_nm")]
  })
  do.call(rbind, pieces)
}

# Report layout: a "Well" label in column 2 with well ids to its right, then
# one row per wavelength with the label in column 2 and readings to the right.
synergy_endpoint_report <- function(cells) {
  well_row <- which(cells[[2]] == "Well")[1]
  well_cols <- which(
    !is.na(unlist(cells[well_row, ])) & seq_len(ncol(cells)) > 2
  )
  wells <- unlist(cells[well_row, well_cols], use.names = FALSE)

  below <- cells[[2]][-seq_len(well_row)]
  n_reads <- if (anyNA(below)) which(is.na(below))[1] - 1 else length(below)
  rows <- well_row + seq_len(n_reads)

  pieces <- lapply(rows, function(i) {
    tibble::tibble(
      well = pad_well_id(wells),
      od = suppressWarnings(as.numeric(unlist(cells[i, well_cols]))),
      wavelength_nm = suppressWarnings(readr::parse_number(cells[[2]][i]))
    )
  })
  do.call(rbind, pieces)
}

# Grid layout: column numbers in row 1, row letters in column 1. An optional
# extra column to the right holds the wavelength.
synergy_endpoint_grid <- function(cells) {
  header <- unlist(cells[1, ], use.names = FALSE)
  col_idx <- which(!is.na(header) & seq_along(header) > 1)
  row_idx <- which(grepl("^[A-Ha-h]$", cells[[1]]))
  extra <- setdiff(seq_len(ncol(cells))[-1], col_idx)

  tibble::tibble(
    well = pad_well_id(paste0(
      rep(toupper(cells[[1]][row_idx]), times = length(col_idx)),
      rep(as.integer(header[col_idx]), each = length(row_idx))
    )),
    od = suppressWarnings(as.numeric(unlist(cells[row_idx, col_idx]))),
    wavelength_nm = if (length(extra) > 0) {
      suppressWarnings(readr::parse_number(cells[[extra[1]]][row_idx[1]]))
    } else {
      NA_real_
    }
  )
}
