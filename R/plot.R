#' Plot growth curves for one plate
#'
#' Draws one panel per well for a single plate, with the well laid out on the
#' plate grid when well ids are row-column names (such as `"A01"`, as from the
#' LogPhase600 readers) and in a square-ish grid otherwise (such as the
#' Bioscreen's `"001"` to `"100"`). Each curve is coloured by its QC status,
#' built from whichever of the flag columns added by [flag_od_range()] and
#' [flag_no_growth()] are present in `data`. Wells with no flags are `"ok"`;
#' wells with several flags show them joined with `+`.
#'
#' @param data Tidy data frame from a reader, optionally with QC columns.
#' @param plate `plate_id` of the plate to draw. Can be omitted if `data` holds
#'   a single plate or has no `plate_id` column.
#' @param od Name of the OD column to plot. Defaults to `"od_corrected"` if
#'   present, otherwise `"od"`.
#' @param flags Names of logical flag columns to colour by. Defaults to all of
#'   `flag_saturated`, `flag_negative` and `flag_no_growth` found in `data`.
#' @param smooth If `TRUE`, overlay the smoothed curve (solid) on the raw
#'   curve (dashed, faded). Uses the `<od>_rollmean` column if present,
#'   otherwise computes it with [smooth_od()].
#' @param window Window size used if the smoothed curve has to be computed.
#' @param scales Panel scales, passed to [ggplot2::facet_wrap()] or
#'   [ggplot2::facet_grid()]: `"fixed"` (default) or `"free_y"`.
#'
#' @return A ggplot object.
#' @export
#' @examples
#' f <- system.file("extdata", "logphase600_example.txt", package = "plateReadeR")
#' d <- read_logphase_txt(f)
#' d <- flag_no_growth(blank_correct(flag_od_range(d, saturation = 2)))
#' plot_plate(d)
plot_plate <- function(
  data,
  plate = NULL,
  od = NULL,
  flags = NULL,
  smooth = FALSE,
  window = 5,
  scales = "fixed"
) {
  if (!all(c("hours", "well") %in% names(data))) {
    rlang::abort("`data` must have `hours` and `well` columns.")
  }
  od <- od %||% if ("od_corrected" %in% names(data)) "od_corrected" else "od"
  if (!od %in% names(data)) {
    rlang::abort(paste0("Column `", od, "` not found."))
  }

  if ("plate_id" %in% names(data)) {
    plates <- unique(stats::na.omit(data$plate_id))
    if (is.null(plate)) {
      if (length(plates) != 1) {
        rlang::abort(paste0(
          "`data` has several plates; choose one with `plate`: ",
          paste(plates, collapse = ", ")
        ))
      }
      plate <- plates
    }
    if (!plate %in% plates) {
      rlang::abort(paste0(
        "Plate '",
        plate,
        "' not found. Available: ",
        paste(plates, collapse = ", ")
      ))
    }
    data <- data[!is.na(data$plate_id) & data$plate_id == plate, ]
  } else {
    plate <- plate %||% "plate"
  }

  flags <- flags %||%
    intersect(
      c("flag_saturated", "flag_negative", "flag_no_growth"),
      names(data)
    )
  data$qc_status <- qc_status(data, flags)
  data$.od <- data[[od]]

  smooth_col <- paste0(od, "_rollmean")
  if (smooth) {
    if (!smooth_col %in% names(data)) {
      data <- smooth_od(data, od = od, window = window)
    }
    data$.od_smooth <- data[[smooth_col]]
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(
      x = .data$hours,
      y = .data$.od,
      colour = .data$qc_status,
      group = .data$well
    )
  )
  p <- if (smooth) {
    p +
      ggplot2::geom_line(linetype = "dashed", alpha = 0.5) +
      ggplot2::geom_line(ggplot2::aes(y = .data$.od_smooth))
  } else {
    p + ggplot2::geom_line()
  }
  p <- p +
    ggplot2::scale_x_continuous(n.breaks = 3) +
    ggplot2::scale_y_continuous(n.breaks = 3) +
    ggplot2::labs(
      x = "Hours",
      y = od,
      colour = "QC status",
      title = plate,
      subtitle = if (smooth) "dashed = raw, solid = smoothed"
    ) +
    ggplot2::theme(
      axis.text = ggplot2::element_text(size = 5),
      strip.text = ggplot2::element_text(size = 6),
      panel.spacing = ggplot2::unit(0.1, "lines")
    )

  if (all(grepl("^[A-Ha-h][0-9]+$", data$well))) {
    data$.row <- toupper(substr(data$well, 1, 1))
    data$.col <- as.integer(substr(data$well, 2, nchar(data$well)))
    p$data <- data
    p + ggplot2::facet_grid(.row ~ .col, scales = scales)
  } else {
    n <- length(unique(data$well))
    p +
      ggplot2::facet_wrap(
        ggplot2::vars(.data$well),
        ncol = ceiling(sqrt(n)),
        scales = scales
      )
  }
}

# One label per row: "ok" or the flags that apply to that row's well joined
# with "+" (e.g. "saturated+no_growth")
qc_status <- function(data, flags) {
  if (length(flags) == 0) {
    return(rep("ok", nrow(data)))
  }
  missing <- setdiff(flags, names(data))
  if (length(missing) > 0) {
    rlang::abort(paste0(
      "Flag column(s) not found: ",
      paste(missing, collapse = ", ")
    ))
  }
  labels <- sub("^flag_", "", flags)
  status <- vapply(
    seq_len(nrow(data)),
    function(i) {
      hit <- vapply(flags, function(f) isTRUE(data[[f]][i]), logical(1))
      if (any(hit)) paste(labels[hit], collapse = "+") else "ok"
    },
    character(1)
  )
  status
}
