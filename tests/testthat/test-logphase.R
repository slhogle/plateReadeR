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
  one <- read_logphase_xlsx(f, sheet = "Plate 2 - Raw Data")
  expect_equal(unique(one$plate_id), "Plate 2")
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
  x1 <- read_logphase_xlsx(xf, sheet = "Plate 1 - Raw Data")
  expect_equal(
    t1[c("seconds", "well", "od", "plate_id")],
    x1[c("seconds", "well", "od", "plate_id")]
  )
})
