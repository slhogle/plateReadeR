plate_data <- function() {
  f <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  d <- read_logphase_xlsx(f)
  flag_no_growth(blank_correct(flag_od_range(d, saturation = 0.12)))
}

test_that("plot_plate returns a ggplot for one plate", {
  d <- plate_data()
  p <- plot_plate(d, plate = "Plate 2")
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "Plate 2")
  expect_equal(unique(p$data$plate_id), "Plate 2")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("plot_plate colours by combined QC status", {
  d <- plate_data()
  p <- plot_plate(d, plate = "Plate 1")
  expect_true(all(
    p$data$qc_status %in%
      c(
        "ok",
        "saturated",
        "no_growth",
        "negative",
        "saturated+no_growth",
        "saturated+negative",
        "negative+no_growth",
        "saturated+negative+no_growth"
      )
  ))
  expect_true(
    any(grepl("\\+", p$data$qc_status)) || any(p$data$qc_status != "ok")
  )
})

test_that("plot_plate uses a plate-grid facet for row-column wells and wraps otherwise", {
  d <- plate_data()
  expect_s3_class(plot_plate(d, plate = "Plate 1")$facet, "FacetGrid")
  b <- read_bioscreen(system.file(
    "extdata",
    "bioscreen_example.txt",
    package = "plateReadeR"
  ))
  expect_s3_class(plot_plate(b, plate = "Plate 1")$facet, "FacetWrap")
})

test_that("plot_plate handles plate selection and missing columns", {
  d <- plate_data()
  expect_error(plot_plate(d), "several plates")
  expect_error(plot_plate(d, plate = "Plate 9"), "not found")
  expect_error(plot_plate(d, plate = "Plate 1", od = "nope"), "not found")
  one <- d[d$plate_id == "Plate 1", ]
  expect_no_error(plot_plate(one))
  expect_equal(
    unique(plot_plate(one[1:4 + 0, ], flags = character())$data$qc_status),
    "ok"
  )
})

test_that("qc_status combines flags", {
  df <- data.frame(
    flag_saturated = c(TRUE, FALSE, TRUE),
    flag_no_growth = c(FALSE, FALSE, TRUE)
  )
  expect_equal(
    qc_status(df, names(df)),
    c("saturated", "ok", "saturated+no_growth")
  )
})

test_that("plot_plate overlays the smoothed curve when asked", {
  d <- plate_data()
  p0 <- plot_plate(d, plate = "Plate 1")
  p1 <- plot_plate(d, plate = "Plate 1", smooth = TRUE)
  expect_length(p0$layers, 1)
  expect_length(p1$layers, 2)
  expect_equal(p1$labels$subtitle, "dashed = raw, solid = smoothed")
  expect_true(".od_smooth" %in% names(p1$data))
  expect_no_error(ggplot2::ggplot_build(p1))
  # uses an existing smoothed column rather than recomputing
  ds <- blank_correct(d, smooth = TRUE)
  expect_equal(
    plot_plate(ds, plate = "Plate 1", smooth = TRUE)$data$.od_smooth,
    ds[ds$plate_id == "Plate 1", ]$od_corrected_rollmean
  )
})
