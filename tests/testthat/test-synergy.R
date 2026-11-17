synergy_file <- function(name = "synergy_example.xlsx") {
  system.file("extdata", name, package = "plateReadeR")
}

test_that("read_synergy_xlsx reads raw time courses", {
  d <- read_synergy_xlsx(synergy_file())
  expect_named(d, c("seconds", "hours", "well", "od", "plate_id"))
  expect_equal(unique(d$plate_id), "Plate 1")
  expect_equal(length(unique(d$well)), 96)
  expect_equal(nrow(d), 96 * 12)
  # Excel day fractions are snapped to the 20 minute grid
  expect_equal(sort(unique(d$seconds))[1:3], c(0, 1200, 2400))
  expect_false(anyNA(d$od))
  expect_equal(read_synergy_xlsx(synergy_file(), sheet = "raw"), d)
})

test_that("read_synergy_xlsx thins reads", {
  d <- read_synergy_xlsx(synergy_file(), thin_hours = 2 / 3)
  expect_equal(sort(unique(d$seconds)), seq(0, by = 2400, length.out = 6))
})

test_that("read_synergy_xlsx results are in hours", {
  r <- read_synergy_xlsx(synergy_file(), sheet = "results")
  expect_named(
    r,
    c(
      "plate_id",
      "well",
      "lag_hours",
      "max_v",
      "doubling_hours",
      "stationary_hours"
    )
  )
  expect_equal(nrow(r), 96)
  expect_equal(r$well[1:2], c("A01", "B01"))
  expect_equal(r$lag_hours[1], 0.22590277777777779 * 24)
  expect_equal(r$stationary_hours[2], 0.96287037037037038 * 24)
  # "?????" is NA, and negative durations stored as text are parsed
  expect_true(is.na(r$lag_hours[3]))
  expect_equal(r$doubling_hours[3], -(3 + 13 / 60 + 23 / 3600))
})

test_that("day_fraction_to_hours handles numbers, clock text and junk", {
  expect_equal(
    day_fraction_to_hours(c("0.5", "-3:13:23", "1:00:00", "?????", NA)),
    c(12, -(3 + 13 / 60 + 23 / 3600), 1, NA, NA)
  )
})

test_that("read_synergy_xlsx setup is a key/value table", {
  s <- read_synergy_xlsx(synergy_file(), sheet = "setup")
  expect_named(s, c("plate_id", "key", "value"))
  expect_true("Set Temperature" %in% s$key)
  # The plate layout block is not included
  expect_false(any(s$key == "Plate Layout", na.rm = TRUE))
  expect_false(any(is.na(s$key)))
  # Continuation lines keep their key
  expect_equal(
    s$value[s$key == "Shake"],
    c("Orbital: 0:10 (MM:SS)", "Frequency: 425 cpm (3 mm)")
  )
})

test_that("read_synergy_xlsx validates its input", {
  expect_error(read_synergy_xlsx("nope.xlsx"), "File not found")
  expect_error(read_synergy_xlsx(synergy_file(), sheet = 1))
  expect_error(
    read_synergy_xlsx(synergy_file("synergy_endpoint_example.xlsx")),
    "read_synergy_endpoint"
  )
})

test_that("read_synergy_endpoint reads the plain grid layout", {
  d <- read_synergy_endpoint(synergy_file("synergy_endpoint_example.xlsx"))
  expect_named(d, c("plate_id", "well", "od", "wavelength_nm"))
  expect_equal(nrow(d), 96)
  expect_equal(unique(d$plate_id), "synergy_endpoint_example")
  expect_equal(unique(d$wavelength_nm), 590)
  expect_equal(d$od[d$well == "A01"], 0.406)
  expect_equal(d$od[d$well == "B01"], 0.249)
  expect_equal(d$od[d$well == "A02"], 0.266)
})

test_that("read_synergy_endpoint reads the report layout", {
  d <- read_synergy_endpoint(synergy_file(
    "synergy_endpoint_report_example.xlsx"
  ))
  expect_equal(nrow(d), 96)
  expect_equal(unique(d$plate_id), "Plate 19")
  expect_equal(unique(d$wavelength_nm), 590)
  expect_equal(d$od[d$well %in% c("A01", "A02", "A03")], c(0.248, 0.253, 0.413))
  expect_equal(d$od[d$well == "H12"], 0.196)
  expect_error(read_synergy_endpoint("nope.xlsx"), "File not found")
})
