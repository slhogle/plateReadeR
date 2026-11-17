# These run against the user's real exports in test_data/, which is not part of
# the built package, so they skip under R CMD check.
td <- function(...) test_path("..", "..", "test_data", ...)
skip_if_no_test_data <- function() {
  skip_if_not(dir.exists(td()), "test_data/ not available")
}

test_that("every Bioscreen export reads and passes QC", {
  skip_if_no_test_data()
  files <- list.files(td("bioscreen", "curves"), full.names = TRUE)
  skip_if(length(files) == 0)
  for (f in files) {
    if (grepl("Valine", f)) {
      # this export holds a header and no data
      expect_error(read_bioscreen(f), "no data rows")
      next
    }
    d <- read_bioscreen(f)
    expect_gt(nrow(d), 0)
    expect_false(anyNA(d$od), label = basename(f))
    expect_no_error(flag_no_growth(blank_correct(d)))
  }
})

test_that("every LogPhase600 export reads, in all sheet kinds", {
  skip_if_no_test_data()
  files <- list.files(td("logphase600", "curves"), full.names = TRUE)
  skip_if(length(files) == 0)
  for (f in files[grepl("txt$", files)]) {
    expect_gt(nrow(read_logphase_txt(f)), 0)
  }
  for (f in files[grepl("xlsx$", files)]) {
    raw <- read_logphase_xlsx(f)
    expect_gt(nrow(raw), 0)
    expect_lte(length(unique(raw$plate_id)), 4)
    sheets <- readxl::excel_sheets(f)
    if (any(grepl("Procedure", sheets))) {
      pr <- read_logphase_xlsx(f, sheet = "procedure")
      expect_equal(pr$plate_id, unique(raw$plate_id))
      expect_false(anyNA(pr$runtime_hours))
      expect_false(anyNA(pr$interval_hours))
      res <- read_logphase_xlsx(f, sheet = "results")
      expect_equal(nrow(res), 96 * nrow(pr))
    }
  }
})

test_that("every Synergy H1 export reads", {
  skip_if_no_test_data()
  curves <- list.files(td("synergyH1", "curves"), full.names = TRUE)
  skip_if(length(curves) == 0)
  for (f in curves) {
    raw <- read_synergy_xlsx(f)
    expect_equal(nrow(raw), 96 * 145)
    expect_equal(nrow(read_synergy_xlsx(f, sheet = "results")), 96)
    expect_gt(nrow(read_synergy_xlsx(f, sheet = "setup")), 0)
  }
  for (f in list.files(
    td("synergyH1", "single_measurements"),
    full.names = TRUE
  )) {
    d <- read_synergy_endpoint(f)
    expect_equal(nrow(d), 96)
    expect_false(anyNA(d$od))
  }
})
