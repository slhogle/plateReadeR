# Quality control helpers. These work on the tidy output of any reader: a data
# frame with `seconds`, `well`, an OD column and (optionally) `plate_id`. A well
# is identified by `plate_id` and `well`, or by `well` alone if there is no
# `plate_id` column.

#' Flag wells with saturated or negative OD
#'
#' Adds two well-level logical columns. Every row of a well carries the same
#' value, so wells can be filtered directly.
#'
#' Saturation depends on the instrument, plate and wavelength, so there is no
#' default threshold: supply one that suits your reader. Negative OD is
#' checked on the values as read, so run this before [blank_correct()], which
#' clips negatives to zero.
#'
#' @param data Tidy data frame from one of the readers.
#' @param saturation OD at or above which a read counts as saturated.
#' @param od Name of the OD column.
#'
#' @return `data` with added logical columns `flag_saturated` (any read at or
#'   above `saturation`) and `flag_negative` (any read below zero).
#' @export
#' @examples
#' f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
#' d <- flag_od_range(read_bioscreen(f), saturation = 2)
#' unique(d[c("plate_id", "well", "flag_saturated", "flag_negative")])
flag_od_range <- function(data, saturation, od = "od") {
  check_qc_data(data, od)
  if (!is.numeric(saturation) || length(saturation) != 1 || is.na(saturation)) {
    rlang::abort("`saturation` must be a single number.")
  }
  g <- well_group(data)
  x <- data[[od]]
  data$flag_saturated <- ave_well(x >= saturation, g, function(v) {
    any(v, na.rm = TRUE)
  })
  data$flag_negative <- ave_well(x < 0, g, function(v) any(v, na.rm = TRUE))
  data
}

#' Blank-correct OD
#'
#' Subtracts a blank from every read and clips the result at zero (negative OD
#' is not allowed). The original `od` is kept. Two ways to define the blank:
#'
#' * **Blank wells** (`blank` supplied): the blank is the OD of the specified
#'   well(s), matched by time point within the same plate. If several blank
#'   wells are given for a plate their ODs are averaged at each time point.
#'   Every well on a plate is corrected using the blank well(s) of that plate,
#'   so each plate in `data` needs at least one blank well. Times must line up
#'   between wells, which the readers ensure by snapping times (see
#'   [snap_hours()]).
#' * **Initial reads** (`blank = NULL`): each well is corrected by the mean of
#'   its own first `n_reads` reads.
#'
#' @param data Tidy data frame from one of the readers.
#' @param blank `NULL` to use each well's initial reads, or the blank well(s).
#'   Give a data frame with columns `plate_id` and `well`, or, when `data`
#'   has no `plate_id` column, a character vector of well ids.
#' @param n_reads Number of initial reads averaged when `blank = NULL`.
#' @param od Name of the OD column.
#' @param smooth If `TRUE`, also add a rolling-mean-smoothed copy of the
#'   corrected OD with [smooth_od()]. Off by default.
#' @param window Window size for smoothing; see [smooth_od()].
#'
#' @return `data` with added columns `blank_od` (the value subtracted at that
#'   row) and `od_corrected` (`od - blank_od`, never below zero), plus
#'   `od_corrected_rollmean` if `smooth = TRUE`.
#' @export
#' @examples
#' f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
#' d <- read_bioscreen(f)
#' # each well minus the mean of its first 5 reads
#' blank_correct(d)
#' # wells 001 and 002 on each plate are blanks
#' blanks <- data.frame(
#'   plate_id = rep(c("Plate 1", "Plate 2"), each = 2),
#'   well = c("001", "002", "001", "002")
#' )
#' blank_correct(d, blank = blanks)
blank_correct <- function(
  data,
  blank = NULL,
  n_reads = 5,
  od = "od",
  smooth = FALSE,
  window = 5
) {
  check_qc_data(data, od)
  has_plate <- "plate_id" %in% names(data)

  if (is.null(blank)) {
    if (!is.numeric(n_reads) || length(n_reads) != 1 || n_reads < 1) {
      rlang::abort("`n_reads` must be a single positive number.")
    }
    data$blank_od <- ave_well(
      data[[od]],
      well_group(data),
      function(v) mean(utils::head(v, n_reads), na.rm = TRUE),
      seconds = data$seconds
    )
  } else {
    blank <- normalise_blank(blank, has_plate)
    key_data <- plate_well_key(data)
    key_blank <- plate_well_key(blank)
    is_blank <- key_data %in% key_blank
    missing <- setdiff(key_blank, unique(key_data))
    if (length(missing) > 0) {
      rlang::abort(paste0(
        "Blank well(s) not found in `data`: ",
        paste(missing, collapse = ", ")
      ))
    }
    plates <- if (has_plate) {
      as.character(data$plate_id)
    } else {
      rep("all", nrow(data))
    }
    blank_plates <- if (has_plate) as.character(blank$plate_id) else "all"
    no_blank <- setdiff(unique(plates), blank_plates)
    if (length(no_blank) > 0) {
      rlang::abort(paste0(
        "No blank well given for plate(s): ",
        paste(no_blank, collapse = ", ")
      ))
    }

    bd <- data.frame(
      plate = plates[is_blank],
      seconds = data$seconds[is_blank],
      od = data[[od]][is_blank]
    )
    blank_curve <- stats::aggregate(
      od ~ plate + seconds,
      data = bd,
      FUN = mean,
      na.action = stats::na.pass
    )
    idx <- match(
      paste(plates, data$seconds),
      paste(blank_curve$plate, blank_curve$seconds)
    )
    if (anyNA(idx)) {
      rlang::abort(
        "Blank wells have no read at some time points; times do not line up. Check `seconds` or use the readers' `interval_hours` snapping."
      )
    }
    data$blank_od <- blank_curve$od[idx]
  }

  data$od_corrected <- pmax(data[[od]] - data$blank_od, 0)
  if (smooth) {
    data <- smooth_od(data, od = "od_corrected", window = window)
  }
  data
}

#' Smooth growth curves with a centered rolling mean
#'
#' Smooths each well's curve with a centered rolling mean, which reduces the
#' jaggedness of the curves. Each smoothed point is the mean of the focal read
#' and the `(window - 1) / 2` reads on either side. Near the start and end of a
#' curve, where fewer reads are available, the mean uses the reads that exist.
#' Reads are taken in time order within each well, whatever the row order.
#'
#' Smoothing is not applied by default anywhere in the package. Methods that
#' infer growth rates can struggle when reads are very dense, so smoothing is
#' often used together with thinning to a coarser interval.
#'
#' @param data Tidy data frame from one of the readers.
#' @param od Name of the OD column to smooth. Defaults to `"od_corrected"` if
#'   present, otherwise `"od"`.
#' @param window Number of reads in the rolling mean. Must be odd; the default
#'   of 5 is the focal read plus two on each side.
#'
#' @return `data` with an added column named after `od` with `_rollmean`
#'   appended (for example `od_rollmean` or `od_corrected_rollmean`).
#' @export
#' @examples
#' f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
#' smooth_od(read_bioscreen(f))
smooth_od <- function(data, od = NULL, window = 5) {
  od <- od %||% if ("od_corrected" %in% names(data)) "od_corrected" else "od"
  check_qc_data(data, od)
  if (
    !is.numeric(window) || length(window) != 1 || window < 1 || window %% 2 != 1
  ) {
    rlang::abort("`window` must be a single odd positive number.")
  }
  half <- (window - 1) / 2
  data[[paste0(od, "_rollmean")]] <- ave_well(
    data[[od]],
    well_group(data),
    function(v) slider::slide_dbl(v, mean, .before = half, .after = half),
    seconds = data$seconds
  )
  data
}

#' Flag wells whose blank-corrected signal never rises
#'
#' A well is flagged when its blank-corrected OD never climbs more than
#' `min_rise` above its starting level, where the starting level is the mean of
#' its first `n_reads` reads. Wells with a flat curve (for example wells with no
#' inoculum) are flagged. The threshold is a judgement call that depends on
#' your instrument noise and culture density, so check it against known growing
#' and non-growing wells.
#'
#' @param data Data frame with blank-corrected OD, from [blank_correct()].
#' @param min_rise Smallest rise in OD (maximum minus starting level) for a
#'   well to count as growing.
#' @param n_reads Number of initial reads averaged to get the starting level.
#' @param od Name of the blank-corrected OD column.
#'
#' @return `data` with added well-level logical column `flag_no_growth`. It is
#'   `NA` for wells with no readings (for example unused wells).
#' @export
#' @examples
#' f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
#' d <- flag_no_growth(blank_correct(read_bioscreen(f)))
#' unique(d[c("plate_id", "well", "flag_no_growth")])
flag_no_growth <- function(
  data,
  min_rise = 0.05,
  n_reads = 5,
  od = "od_corrected"
) {
  if (!od %in% names(data)) {
    rlang::abort(paste0(
      "Column `",
      od,
      "` not found; run blank_correct() first."
    ))
  }
  check_qc_data(data, od)
  g <- well_group(data)
  rise <- ave_well(
    data[[od]],
    g,
    function(v) {
      if (all(is.na(v))) {
        return(NA_real_)
      }
      max(v, na.rm = TRUE) - mean(utils::head(v, n_reads), na.rm = TRUE)
    },
    seconds = data$seconds
  )
  data$flag_no_growth <- rise < min_rise
  data
}

# Helpers ----------------------------------------------------------------

check_qc_data <- function(data, od) {
  needed <- c("seconds", "well", od)
  absent <- setdiff(needed, names(data))
  if (length(absent) > 0) {
    rlang::abort(paste0(
      "`data` is missing column(s): ",
      paste(absent, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

# Grouping factor identifying each well
well_group <- function(data) {
  if ("plate_id" %in% names(data)) {
    interaction(data$plate_id, data$well, drop = TRUE, lex.order = TRUE)
  } else {
    factor(data$well)
  }
}

# Apply `fn` to the values of each well and return a vector aligned with the
# rows of `data` (`fn` returns one value per well, recycled over its rows). If
# `seconds` is supplied, each well's values are in time order when `fn` is
# called, so "first n reads" is correct.
ave_well <- function(x, g, fn, seconds = NULL) {
  idx <- split(seq_along(x), g)
  if (!is.null(seconds)) {
    idx <- lapply(idx, function(i) i[order(seconds[i])])
  }
  vals <- lapply(idx, function(i) fn(x[i]))
  out <- vector(mode(vals[[1]]), length(x))
  for (k in seq_along(idx)) {
    out[idx[[k]]] <- vals[[k]]
  }
  out
}

plate_well_key <- function(df) {
  if ("plate_id" %in% names(df)) {
    paste(df$plate_id, df$well, sep = "|")
  } else {
    as.character(df$well)
  }
}

normalise_blank <- function(blank, has_plate) {
  if (is.character(blank) && !has_plate) {
    blank <- data.frame(well = blank)
  }
  if (
    !is.data.frame(blank) ||
      !"well" %in% names(blank) ||
      (has_plate && !"plate_id" %in% names(blank))
  ) {
    rlang::abort(
      "`blank` must be a data frame with `plate_id` and `well` columns (or a character vector of wells if `data` has no `plate_id`)."
    )
  }
  blank$well <- as.character(blank$well)
  blank
}
