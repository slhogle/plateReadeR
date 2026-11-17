# Smooth growth curves with a centered rolling mean

Smooths each well's curve with a centered rolling mean, which reduces
the jaggedness of the curves. Each smoothed point is the mean of the
focal read and the `(window - 1) / 2` reads on either side. Near the
start and end of a curve, where fewer reads are available, the mean uses
the reads that exist. Reads are taken in time order within each well,
whatever the row order.

## Usage

``` r
smooth_od(data, od = NULL, window = 5)
```

## Arguments

- data:

  Tidy data frame from one of the readers.

- od:

  Name of the OD column to smooth. Defaults to `"od_corrected"` if
  present, otherwise `"od"`.

- window:

  Number of reads in the rolling mean. Must be odd; the default of 5 is
  the focal read plus two on each side.

## Value

`data` with an added column named after `od` with `_rollmean` appended
(for example `od_rollmean` or `od_corrected_rollmean`).

## Details

Smoothing is not applied by default anywhere in the package. Methods
that infer growth rates can struggle when reads are very dense, so
smoothing is often used together with thinning to a coarser interval.

## Examples

``` r
f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
smooth_od(read_bioscreen(f))
#> # A tibble: 4,000 × 7
#>    seconds  hours plate_id well  well_index    od od_rollmean
#>      <dbl>  <dbl> <chr>    <chr>      <int> <dbl>       <dbl>
#>  1       0 0      Plate 1  001            1 0.072      0.072 
#>  2     300 0.0833 Plate 1  001            1 0.072      0.072 
#>  3     600 0.167  Plate 1  001            1 0.072      0.072 
#>  4     900 0.25   Plate 1  001            1 0.072      0.072 
#>  5    1200 0.333  Plate 1  001            1 0.072      0.072 
#>  6    1500 0.417  Plate 1  001            1 0.072      0.072 
#>  7    1800 0.5    Plate 1  001            1 0.072      0.072 
#>  8    2100 0.583  Plate 1  001            1 0.072      0.0722
#>  9    2400 0.667  Plate 1  001            1 0.072      0.0724
#> 10    2700 0.75   Plate 1  001            1 0.073      0.0726
#> # ℹ 3,990 more rows
```
