test_that("plate_time_to_seconds handles each time representation", {
  expect_equal(plate_time_to_seconds(c("0:00:00", "47:20:03")), c(0, 170403))
  expect_equal(plate_time_to_seconds(c(0, 1 / 72)), c(0, 1200))
  expect_equal(plate_time_to_seconds(hms::as_hms(c(0, 1200))), c(0, 1200))
  expect_error(plate_time_to_seconds("bad"), "elapsed time")
})

test_that("pad_well_id zero-pads", {
  expect_equal(pad_well_id(c("A1", "H12", "b3")), c("A01", "H12", "B03"))
})

test_that("read_logphase_txt returns tidy long data", {
  f <- system.file(
    "extdata",
    "logphase600_example.txt",
    package = "plateReadeR"
  )
  d <- read_logphase_txt(f)
  expect_named(d, c("seconds", "hours", "well", "od", "plate_id"))
  expect_equal(length(unique(d$well)), 96)
  expect_equal(unique(d$plate_id), "Plate 1")
  expect_equal(nrow(d), 96 * length(unique(d$seconds)))
  expect_equal(min(d$seconds), 0)
  expect_equal(sort(unique(d$seconds))[1:3], c(0, 1200, 2400))
  expect_equal(d$od[d$well == "A01" & d$seconds == 0], 0.116)
  expect_false(anyNA(d$od))
})

test_that("read_logphase_xlsx reads all raw data sheets", {
  f <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  d <- read_logphase_xlsx(f)
  expect_named(d, c("seconds", "hours", "well", "od", "plate_id"))
  expect_equal(sort(unique(d$plate_id)), c("Plate 1", "Plate 2"))
  expect_equal(sort(unique(d$seconds))[1:3], c(0, 1200, 2400))
  expect_equal(
    read_logphase_xlsx(f, sheet = "raw"),
    read_logphase_xlsx(f)
  )
})

test_that("sheet must be one of raw, results or procedure", {
  f <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  expect_error(read_logphase_xlsx(f, sheet = 2))
  expect_error(read_logphase_xlsx(f, sheet = "Plate 1 - Raw Data"))
  expect_error(read_logphase_xlsx("nope.xlsx"), "File not found")
})

test_that("plate_id falls back to the file name without a header", {
  expect_equal(logphase_txt_plate_id("no info", "/x/my_plate.txt"), "my_plate")
  expect_equal(
    logphase_txt_plate_id("  Plate Number:            3", "x.txt"),
    "Plate 3"
  )
})

test_that("txt and xlsx readers agree on shared data", {
  tf <- system.file(
    "extdata",
    "logphase600_example.txt",
    package = "plateReadeR"
  )
  xf <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  t1 <- read_logphase_txt(tf)
  x1 <- read_logphase_xlsx(xf)
  x1 <- x1[x1$plate_id == "Plate 1", ]
  expect_equal(
    t1[c("seconds", "well", "od", "plate_id")],
    x1[c("seconds", "well", "od", "plate_id")]
  )
})

test_that("thin_hours keeps reads on the coarser grid", {
  f <- system.file(
    "extdata",
    "logphase600_plate1.txt",
    package = "plateReadeR"
  )
  full <- read_logphase_txt(f)
  thin <- read_logphase_txt(f, thin_hours = 1)
  expect_equal(unique(thin$seconds %% 3600), 0)
  expect_equal(
    sort(unique(thin$seconds)),
    sort(unique(full$seconds[full$seconds %% 3600 == 0]))
  )
  expect_equal(nrow(thin), 96 * length(unique(thin$seconds)))
  expect_equal(
    thin$od,
    full$od[full$seconds %% 3600 == 0]
  )
  expect_equal(read_logphase_txt(f, thin_hours = 1 / 3), full)
})

test_that("thin_hours is validated", {
  f <- system.file(
    "extdata",
    "logphase600_example.txt",
    package = "plateReadeR"
  )
  expect_error(read_logphase_txt(f, thin_hours = 0.5), "whole multiple")
  expect_error(
    read_logphase_txt(f, interval_hours = NULL, thin_hours = 1),
    "interval_hours"
  )
  expect_error(read_logphase_txt(f, thin_hours = -1), "positive")
  xf <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  expect_error(read_logphase_xlsx(xf, thin_hours = 0.5), "whole multiple")
})

test_that("thin_hours works in the xlsx reader", {
  xf <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  d <- read_logphase_xlsx(xf, thin_hours = 2 / 3)
  expect_equal(sort(unique(d$seconds)), seq(0, by = 2400, length.out = 6))
})

test_that("sheet = 'results' returns per-well summaries in hours", {
  f <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  r <- read_logphase_xlsx(f, sheet = "results")
  expect_named(
    r,
    c("plate_id", "well", "lag_hours", "max_rate", "stationary_hours")
  )
  expect_equal(sort(unique(r$plate_id)), c("Plate 1", "Plate 2"))
  expect_equal(nrow(r), 192)
  expect_equal(r$well[1], "A01")
  p2 <- r[r$plate_id == "Plate 2" & r$well == "A01", ]
  # Plate 2 A1: lag 8 h 10 min, stationary 30 h 23 min 37 s
  expect_equal(p2$lag_hours, 0.34027777777777773 * 24)
  expect_equal(p2$stationary_hours, 1.2664005 * 24, tolerance = 1e-6)
  # "?????" in the sheet means the software reported no lag time
  p1 <- r[r$plate_id == "Plate 1" & r$well == "A01", ]
  expect_true(is.na(p1$lag_hours))
  expect_equal(p1$max_rate, 1.907e-05)
  expect_equal(p1$stationary_hours, 0.19674768518518518 * 24)
})

test_that("sheet = 'procedure' returns one parsed row per plate", {
  f <- system.file(
    "extdata",
    "logphase600_example.xlsx",
    package = "plateReadeR"
  )
  p <- read_logphase_xlsx(f, sheet = "procedure")
  expect_equal(p$plate_id, c("Plate 1", "Plate 2"))
  expect_equal(p$runtime_hours, c(48, 48))
  expect_equal(p$interval_hours, rep(1 / 3, 2))
  expect_equal(p$max_reads, c(145L, 145L))
  expect_equal(p$wavelength_nm, c(600, 600))
  expect_true(all(p$incubator))
  expect_equal(p$temperature_setpoint_c, c(30, 30))
  expect_type(p$temperature_gradient, "logical")
  expect_equal(p$shaking_rpm, c(600, 600))
  expect_match(p$summary[1], "^Procedure Summary")
})

test_that("the procedure summary text is parsed into typed fields", {
  x <- paste0(
    "Procedure Summary  Plate Type: Corning 96 well for LogPhase600  ",
    "Plate Number: 3  Discontinuous Kinetics: Runtime 02:00:00 (D:HH:MM), ",
    "Interval 00:10:00 (HH:MM:SS), 289 Reads (max)  Read: 600 nm  ",
    "Incubator: Off  Temperature setpoint: 37 \u00b0C  ",
    "Temperature gradient: On  Shaking: Off  Shaking frequency: 800 RPMs"
  )
  p <- parse_logphase_procedure(x)
  expect_equal(p$plate_type, "Corning 96 well for LogPhase600")
  expect_equal(p$runtime_hours, 48)
  expect_equal(p$interval_hours, 1 / 6)
  expect_equal(p$max_reads, 289L)
  expect_false(p$incubator)
  expect_true(p$temperature_gradient)
  expect_false(p$shaking)
  expect_equal(p$temperature_setpoint_c, 37)
  expect_equal(p$shaking_rpm, 800)
  # Missing fields become NA rather than errors
  q <- parse_logphase_procedure("Procedure Summary  Read: 600 nm")
  expect_equal(q$wavelength_nm, 600)
  expect_true(is.na(q$runtime_hours))
  expect_true(is.na(q$incubator))
})

test_that("duration_to_hours reads the unit label", {
  expect_equal(duration_to_hours("02:00:00", "D:HH:MM"), 48)
  expect_equal(duration_to_hours("00:20:00", "HH:MM:SS"), 1 / 3)
  expect_true(is.na(duration_to_hours("00:20", "HH:MM:SS")))
  expect_true(is.na(duration_to_hours("00:20:00", "XX:MM:SS")))
})

test_that("four LogPhase600 plate files bind to four distinct plate_ids", {
  files <- sprintf(
    "../../test_data/logphase600/curves/Plate%d_logphase600_sample_output.txt",
    1:4
  )
  skip_if_not(all(file.exists(vapply(files, test_path, ""))))
  d <- do.call(
    rbind,
    lapply(files, function(f) read_logphase_txt(test_path(f)))
  )
  expect_equal(sort(unique(d$plate_id)), paste("Plate", 1:4))
  expect_equal(nrow(unique(d[c("plate_id", "well")])), 4 * 96)
  per_plate <- table(d$plate_id)
  expect_equal(length(unique(per_plate)), 1L)
})
