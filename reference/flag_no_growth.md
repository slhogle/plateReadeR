# Flag wells whose blank-corrected signal never rises

A well is flagged when its blank-corrected OD never climbs more than
`min_rise` above its starting level, where the starting level is the
mean of its first `n_reads` reads. Wells with a flat curve (for example
wells with no inoculum) are flagged. The threshold is a judgement call
that depends on your instrument noise and culture density, so check it
against known growing and non-growing wells.

## Usage

``` r
flag_no_growth(data, min_rise = 0.05, n_reads = 5, od = "od_corrected")
```

## Arguments

- data:

  Data frame with blank-corrected OD, from
  [`blank_correct()`](https://slhogle.github.io/plateReadeR/reference/blank_correct.md).

- min_rise:

  Smallest rise in OD (maximum minus starting level) for a well to count
  as growing.

- n_reads:

  Number of initial reads averaged to get the starting level.

- od:

  Name of the blank-corrected OD column.

## Value

`data` with added well-level logical column `flag_no_growth`. It is `NA`
for wells with no readings (for example unused wells).

## Examples

``` r
f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
d <- flag_no_growth(blank_correct(read_bioscreen(f)))
unique(d[c("plate_id", "well", "flag_no_growth")])
#> # A tibble: 200 × 3
#>    plate_id well  flag_no_growth
#>    <chr>    <chr> <lgl>         
#>  1 Plate 1  001   TRUE          
#>  2 Plate 1  002   TRUE          
#>  3 Plate 1  003   TRUE          
#>  4 Plate 1  004   TRUE          
#>  5 Plate 1  005   TRUE          
#>  6 Plate 1  006   TRUE          
#>  7 Plate 1  007   TRUE          
#>  8 Plate 1  008   TRUE          
#>  9 Plate 1  009   TRUE          
#> 10 Plate 1  010   TRUE          
#> # ℹ 190 more rows
```
