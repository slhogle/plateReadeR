# Blank-correct OD

Subtracts a blank from every read and clips the result at zero (negative
OD is not allowed). The original `od` is kept. Two ways to define the
blank:

## Usage

``` r
blank_correct(
  data,
  blank = NULL,
  n_reads = 5,
  od = "od",
  smooth = FALSE,
  window = 5
)
```

## Arguments

- data:

  Tidy data frame from one of the readers.

- blank:

  `NULL` to use each well's initial reads, or the blank well(s). Give a
  data frame with columns `plate_id` and `well`, or, when `data` has no
  `plate_id` column, a character vector of well ids.

- n_reads:

  Number of initial reads averaged when `blank = NULL`.

- od:

  Name of the OD column.

- smooth:

  If `TRUE`, also add a rolling-mean-smoothed copy of the corrected OD
  with
  [`smooth_od()`](https://slhogle.github.io/plateReadeR/reference/smooth_od.md).
  Off by default.

- window:

  Window size for smoothing; see
  [`smooth_od()`](https://slhogle.github.io/plateReadeR/reference/smooth_od.md).

## Value

`data` with added columns `blank_od` (the value subtracted at that row)
and `od_corrected` (`od - blank_od`, never below zero), plus
`od_corrected_rollmean` if `smooth = TRUE`.

## Details

- **Blank wells** (`blank` supplied): the blank is the OD of the
  specified well(s), matched by time point within the same plate. If
  several blank wells are given for a plate their ODs are averaged at
  each time point. Every well on a plate is corrected using the blank
  well(s) of that plate, so each plate in `data` needs at least one
  blank well. Times must line up between wells, which the readers ensure
  by snapping times (see
  [`snap_hours()`](https://slhogle.github.io/plateReadeR/reference/snap_hours.md)).

- **Initial reads** (`blank = NULL`): each well is corrected by the mean
  of its own first `n_reads` reads.

## Examples

``` r
f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
d <- read_bioscreen(f)
# each well minus the mean of its first 5 reads
blank_correct(d)
#> # A tibble: 4,000 × 8
#>    seconds  hours plate_id well  well_index    od blank_od od_corrected
#>      <dbl>  <dbl> <chr>    <chr>      <int> <dbl>    <dbl>        <dbl>
#>  1       0 0      Plate 1  001            1 0.072    0.072      0      
#>  2     300 0.0833 Plate 1  001            1 0.072    0.072      0      
#>  3     600 0.167  Plate 1  001            1 0.072    0.072      0      
#>  4     900 0.25   Plate 1  001            1 0.072    0.072      0      
#>  5    1200 0.333  Plate 1  001            1 0.072    0.072      0      
#>  6    1500 0.417  Plate 1  001            1 0.072    0.072      0      
#>  7    1800 0.5    Plate 1  001            1 0.072    0.072      0      
#>  8    2100 0.583  Plate 1  001            1 0.072    0.072      0      
#>  9    2400 0.667  Plate 1  001            1 0.072    0.072      0      
#> 10    2700 0.75   Plate 1  001            1 0.073    0.072      0.00100
#> # ℹ 3,990 more rows
# wells 001 and 002 on each plate are blanks
blanks <- data.frame(
  plate_id = rep(c("Plate 1", "Plate 2"), each = 2),
  well = c("001", "002", "001", "002")
)
blank_correct(d, blank = blanks)
#> # A tibble: 4,000 × 8
#>    seconds  hours plate_id well  well_index    od blank_od od_corrected
#>      <dbl>  <dbl> <chr>    <chr>      <int> <dbl>    <dbl>        <dbl>
#>  1       0 0      Plate 1  001            1 0.072   0.0715     0.000500
#>  2     300 0.0833 Plate 1  001            1 0.072   0.0715     0.000500
#>  3     600 0.167  Plate 1  001            1 0.072   0.072      0       
#>  4     900 0.25   Plate 1  001            1 0.072   0.0715     0.000500
#>  5    1200 0.333  Plate 1  001            1 0.072   0.0715     0.000500
#>  6    1500 0.417  Plate 1  001            1 0.072   0.0715     0.000500
#>  7    1800 0.5    Plate 1  001            1 0.072   0.0715     0.000500
#>  8    2100 0.583  Plate 1  001            1 0.072   0.0715     0.000500
#>  9    2400 0.667  Plate 1  001            1 0.072   0.072      0       
#> 10    2700 0.75   Plate 1  001            1 0.073   0.0725     0.000500
#> # ℹ 3,990 more rows
```
