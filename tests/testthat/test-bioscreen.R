example_file <- function() {
  system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
}

test_that("read_bioscreen returns tidy long data", {
  d <- read_bioscreen(example_file())
  expect_named(d, c("seconds", "hours", "plate_id", "well", "well_index", "od"))
  expect_type(d$well, "character")
  expect_type(d$well_index, "integer")
  expect_equal(sort(unique(d$well_index)), 1:200)
  expect_equal(sort(unique(d$plate_id)), c("Plate 1", "Plate 2"))
  expect_equal(sort(unique(d$well)), sprintf("%03d", 1:100))
  expect_equal(nrow(unique(d[c("plate_id", "well")])), 200)
  expect_equal(nrow(d), 200 * length(unique(d$seconds)))
  expect_false(anyNA(d$od))
  expect_equal(d$od[d$well_index == 1 & d$seconds == 0], 0.072)
  expect_equal(
    d$od[d$plate_id == "Plate 2" & d$well == "001" & d$seconds == 0],
    d$od[d$well_index == 101 & d$seconds == 0]
  )
})

test_that("times are snapped and converted to hours", {
  d <- read_bioscreen(example_file())
  expect_equal(d$seconds %% 300, rep(0, nrow(d)))
  expect_equal(d$hours, d$seconds / 3600)
  raw <- read_bioscreen(example_file(), interval_hours = NULL)
  expect_true(any(raw$seconds %% 300 != 0))
})

test_that("snap_hours snaps to the nominal grid", {
  expect_equal(snap_hours(c(0.3336, 0.6661, 1.0003)), c(1, 2, 3) / 3)
  expect_equal(snap_hours(0.51, interval_hours = 0.5), 0.5)
})

test_that("keep_blank retains the blank column as well 'Blank'", {
  d <- read_bioscreen(example_file(), keep_blank = TRUE)
  expect_true("Blank" %in% d$well)
  expect_true(all(is.na(d$plate_id[d$well == "Blank"])))
  expect_true(all(d$well_index[d$well == "Blank"] == 0L))
})

test_that("bad input errors informatively", {
  expect_error(read_bioscreen("nope.txt"), "File not found")
  expect_equal(bioscreen_time_to_seconds("47:00:06"), 169206)
  expect_error(bioscreen_time_to_seconds("bad"), "HH:MM:SS")
  expect_equal(bioscreen_time_to_seconds(c("00:05:05", "00:00:00")), c(305, 0))
})

test_that("single-plate (100 well) runs are read as plate 1 only", {
  lines <- readr::read_lines(
    example_file(),
    locale = readr::locale(encoding = "UTF-16LE")
  )
  lines <- sub("^\ufeff", "", lines)
  keep <- function(l) {
    f <- strsplit(trimws(l), "\\s+")[[1]]
    paste(f[1:102], collapse = " ")
  }
  hdr <- grep("^\\s*Time", lines)
  lines[hdr:length(lines)] <- vapply(lines[hdr:length(lines)], keep, "")
  tmp <- tempfile(fileext = ".txt")
  writeBin(
    iconv(
      paste0(paste(lines, collapse = "\r\n"), "\r\n"),
      "UTF-8",
      "UTF-16LE",
      toRaw = TRUE
    )[[1]],
    tmp
  )
  d <- read_bioscreen(tmp, encoding = "UTF-16LE")
  expect_equal(sort(unique(d$well_index)), 1:100)
  expect_equal(unique(d$plate_id), "Plate 1")
})

test_that("encoding is detected from the byte-order mark", {
  expect_equal(guess_bioscreen_encoding(example_file()), "UTF-16LE")
  utf8 <- tempfile(fileext = ".txt")
  writeBin(as.raw(c(0xef, 0xbb, 0xbf, 0x41)), utf8)
  expect_equal(guess_bioscreen_encoding(utf8), "UTF-8")
  none <- tempfile(fileext = ".txt")
  writeBin(as.raw(c(0x41, 0x00)), none)
  expect_equal(guess_bioscreen_encoding(none), "UTF-16LE")
})

test_that("compressed and plain files read identically", {
  plain <- tempfile(fileext = ".txt")
  xz <- tempfile(fileext = ".txt.xz")
  con <- xzfile(xz, "wb")
  writeBin(readBin(example_file(), "raw", file.size(example_file())), con)
  close(con)
  expect_equal(read_bioscreen(xz), read_bioscreen(example_file()))
})

test_that("the bundled full run has two plates and 567 reads", {
  f <- system.file("extdata", "bioscreen_full.txt.xz", package = "plateReadeR")
  d <- read_bioscreen(f)
  expect_equal(sort(unique(d$plate_id)), c("Plate 1", "Plate 2"))
  expect_equal(length(unique(d$seconds)), 567)
  expect_equal(nrow(d), 567 * 200)
})

test_that("thin_hours thins after snapping", {
  full <- read_bioscreen(example_file())
  thin <- read_bioscreen(example_file(), thin_hours = 1 / 3)
  expect_equal(unique(thin$seconds %% 1200), 0)
  expect_equal(
    sort(unique(thin$seconds)),
    sort(unique(full$seconds[full$seconds %% 1200 == 0]))
  )
  expect_equal(nrow(thin), 200 * length(unique(thin$seconds)))
  expect_equal(
    thin$od,
    full$od[full$seconds %% 1200 == 0]
  )
  expect_equal(read_bioscreen(example_file(), thin_hours = 1 / 12), full)
  expect_error(
    read_bioscreen(example_file(), thin_hours = 0.1),
    "whole multiple"
  )
  expect_error(
    read_bioscreen(example_file(), interval_hours = NULL, thin_hours = 1),
    "interval_hours"
  )
})

test_that("unexpected well counts warn", {
  expect_warning(
    read_bioscreen(example_file(), wells_per_plate = 40),
    "Found 200 wells"
  )
  expect_no_warning(read_bioscreen(example_file()))
})

test_that("csv exports are read like text exports", {
  f <- system.file("extdata", "bioscreen_example.csv", package = "plateReadeR")
  d <- read_bioscreen(f)
  expect_named(d, c("seconds", "hours", "plate_id", "well", "well_index", "od"))
  expect_equal(length(unique(d$well_index)), 200)
  expect_equal(sort(unique(d$plate_id)), c("Plate 1", "Plate 2"))
  expect_false(anyNA(d$od))
  expect_true(all(d$od > 0 & d$od < 5))
  # comma decimals inside quoted csv fields: 0,124 is 0.124
  expect_equal(d$od[d$well_index == 1][1], 0.124)
})

test_that("a header-only file is an error", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c("Label,\"\"", "Info,\"\"", "Time,Blank,1,2"), tmp)
  expect_error(read_bioscreen(tmp, encoding = "UTF-8"), "no data rows")
})

test_that("a partly filled second plate does not warn", {
  tmp <- tempfile(fileext = ".txt")
  writeLines(
    c(
      "Label",
      "Info",
      paste("Time Blank", paste(1:140, collapse = " ")),
      paste("00:00:00 0,000", paste(rep("0,100", 140), collapse = " "))
    ),
    tmp
  )
  expect_no_warning(d <- read_bioscreen(tmp, encoding = "UTF-8"))
  expect_equal(sum(d$plate_id == "Plate 2"), 40)
})
