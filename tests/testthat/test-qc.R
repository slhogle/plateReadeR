toy <- function() {
  tibble::tibble(
    plate_id = rep(c("Plate 1", "Plate 2"), each = 12),
    well = rep(rep(c("001", "002", "003"), each = 4), times = 2),
    seconds = rep(c(0, 1200, 2400, 3600), times = 6),
    od = c(
      0.1,
      0.1,
      0.1,
      0.1, # blank
      0.1,
      0.2,
      0.5,
      1.0, # growing
      0.1,
      0.1,
      0.1,
      0.1, # flat
      0.2,
      0.2,
      0.2,
      0.2, # blank, plate 2
      0.2,
      0.3,
      0.9,
      2.5, # growing and saturated
      0.2,
      0.2,
      0.1,
      -0.1 # negative
    )
  )
}

test_that("flag_od_range flags wells, not just rows", {
  d <- flag_od_range(toy(), saturation = 2)
  s <- unique(d[c("plate_id", "well", "flag_saturated", "flag_negative")])
  expect_equal(nrow(s), 6)
  expect_equal(s$flag_saturated, c(F, F, F, F, T, F))
  expect_equal(s$flag_negative, c(F, F, F, F, F, T))
  expect_error(flag_od_range(toy(), saturation = "a"), "single number")
  expect_error(flag_od_range(toy()[-1], saturation = 2), NA)
  expect_error(flag_od_range(toy(), saturation = 2, od = "nope"), "missing")
})

test_that("blank_correct subtracts a time-matched blank within each plate", {
  blank <- data.frame(plate_id = c("Plate 1", "Plate 2"), well = "001")
  d <- blank_correct(toy(), blank = blank)
  p1 <- d[d$plate_id == "Plate 1" & d$well == "002", ]
  expect_equal(p1$od_corrected, c(0, 0.1, 0.4, 0.9))
  p2 <- d[d$plate_id == "Plate 2" & d$well == "002", ]
  expect_equal(p2$blank_od, rep(0.2, 4))
  expect_equal(d$od, toy()$od)
})

test_that("blank_correct averages several blanks and clips negatives", {
  d0 <- toy()
  d0$od[d0$plate_id == "Plate 1" & d0$well == "003" & d0$seconds == 3600] <- 0.3
  blank <- data.frame(plate_id = "Plate 1", well = c("001", "003"))
  d <- blank_correct(d0[d0$plate_id == "Plate 1", ], blank = blank)
  b <- d[d$well == "002", ]
  expect_equal(b$blank_od, c(0.1, 0.1, 0.1, 0.2))
  expect_true(all(d$od_corrected >= 0))
})

test_that("blank_correct with blank = NULL uses each well's first reads", {
  d <- blank_correct(toy(), n_reads = 2)
  w <- d[d$plate_id == "Plate 2" & d$well == "002", ]
  expect_equal(w$blank_od, rep(0.25, 4))
  expect_equal(w$od_corrected, c(0, 0.05, 0.65, 2.25), tolerance = 1e-8)
  neg <- d[d$plate_id == "Plate 2" & d$well == "003", ]
  expect_true(all(neg$od_corrected >= 0))
  expect_equal(min(neg$od_corrected), 0)
})

test_that("blank_correct handles first reads regardless of row order", {
  shuffled <- toy()[sample(nrow(toy())), ]
  d <- blank_correct(shuffled, n_reads = 1)
  expect_equal(
    unique(d$blank_od[d$plate_id == "Plate 1" & d$well == "002"]),
    0.1
  )
})

test_that("blank_correct validates blanks", {
  expect_error(
    blank_correct(
      toy(),
      blank = data.frame(plate_id = "Plate 1", well = "999")
    ),
    "not found"
  )
  expect_error(
    blank_correct(
      toy(),
      blank = data.frame(plate_id = "Plate 1", well = "001")
    ),
    "No blank well given"
  )
  expect_error(blank_correct(toy(), blank = "001"), "must be a data frame")
  no_plate <- toy()[toy()$plate_id == "Plate 1", -1]
  expect_equal(
    blank_correct(no_plate, blank = "001")$od_corrected[5:8],
    c(0, 0.1, 0.4, 0.9)
  )
  misaligned <- toy()
  misaligned$seconds[
    misaligned$well == "001" & misaligned$seconds == 1200
  ] <- 1201
  expect_error(
    blank_correct(
      misaligned,
      blank = data.frame(plate_id = c("Plate 1", "Plate 2"), well = "001")
    ),
    "line up"
  )
})

test_that("flag_no_growth flags flat wells", {
  d <- flag_no_growth(blank_correct(toy()), n_reads = 1)
  s <- unique(d[c("plate_id", "well", "flag_no_growth")])
  expect_equal(s$flag_no_growth, c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE))
  expect_error(flag_no_growth(toy()), "blank_correct")
  d2 <- flag_no_growth(blank_correct(toy()), min_rise = 5)
  expect_true(all(d2$flag_no_growth))
})

test_that("QC helpers work on reader output", {
  f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
  d <- flag_no_growth(blank_correct(flag_od_range(
    read_bioscreen(f),
    saturation = 2
  )))
  expect_true(all(
    c(
      "flag_saturated",
      "flag_negative",
      "blank_od",
      "od_corrected",
      "flag_no_growth"
    ) %in%
      names(d)
  ))
  expect_equal(nrow(d), nrow(read_bioscreen(f)))
  expect_true(all(d$od_corrected >= 0))
})

test_that("smooth_od is a centered 5 point rolling mean with partial edges", {
  d <- tibble::tibble(
    well = "001",
    seconds = 0:6 * 1200,
    od = c(1, 2, 4, 8, 16, 32, 64)
  )
  s <- smooth_od(d)
  expect_equal(
    s$od_rollmean,
    c(
      mean(c(1, 2, 4)),
      mean(c(1, 2, 4, 8)),
      mean(c(1, 2, 4, 8, 16)),
      mean(c(2, 4, 8, 16, 32)),
      mean(c(4, 8, 16, 32, 64)),
      mean(c(8, 16, 32, 64)),
      mean(c(16, 32, 64))
    )
  )
  expect_equal(smooth_od(d, window = 3)$od_rollmean[2], mean(c(1, 2, 4)))
  expect_equal(smooth_od(d, window = 1)$od_rollmean, d$od)
  expect_error(smooth_od(d, window = 4), "odd")
})

test_that("smooth_od works per well and ignores row order", {
  d <- toy()
  shuffled <- d[sample(nrow(d)), ]
  a <- smooth_od(d)
  b <- smooth_od(shuffled)
  key <- function(x) paste(x$plate_id, x$well, x$seconds)
  expect_equal(b$od_rollmean[match(key(a), key(b))], a$od_rollmean)
  w <- a[a$plate_id == "Plate 1" & a$well == "002", ]
  expect_equal(w$od_rollmean[1], mean(c(0.1, 0.2, 0.5)))
})

test_that("smoothing is off by default and opt-in in blank_correct", {
  expect_false("od_corrected_rollmean" %in% names(blank_correct(toy())))
  d <- blank_correct(toy(), smooth = TRUE)
  expect_true("od_corrected_rollmean" %in% names(d))
  expect_equal(
    d$od_corrected_rollmean,
    smooth_od(blank_correct(toy()), "od_corrected")$od_corrected_rollmean
  )
})
