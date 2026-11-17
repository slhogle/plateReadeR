# Flag wells with saturated or negative OD

Adds two well-level logical columns. Every row of a well carries the
same value, so wells can be filtered directly.

## Usage

``` r
flag_od_range(data, saturation, od = "od")
```

## Arguments

- data:

  Tidy data frame from one of the readers.

- saturation:

  OD at or above which a read counts as saturated.

- od:

  Name of the OD column.

## Value

`data` with added logical columns `flag_saturated` (any read at or above
`saturation`) and `flag_negative` (any read below zero).

## Details

Saturation depends on the instrument, plate and wavelength, so there is
no default threshold: supply one that suits your reader. Negative OD is
checked on the values as read, so run this before
[`blank_correct()`](https://slhogle.github.io/plateReadeR/reference/blank_correct.md),
which clips negatives to zero.

## Examples

``` r
f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
d <- flag_od_range(read_bioscreen(f), saturation = 2)
unique(d[c("plate_id", "well", "flag_saturated", "flag_negative")])
#> # A tibble: 200 × 4
#>    plate_id well  flag_saturated flag_negative
#>    <chr>    <chr> <lgl>          <lgl>        
#>  1 Plate 1  001   FALSE          FALSE        
#>  2 Plate 1  002   FALSE          FALSE        
#>  3 Plate 1  003   FALSE          FALSE        
#>  4 Plate 1  004   FALSE          FALSE        
#>  5 Plate 1  005   FALSE          FALSE        
#>  6 Plate 1  006   FALSE          FALSE        
#>  7 Plate 1  007   FALSE          FALSE        
#>  8 Plate 1  008   FALSE          FALSE        
#>  9 Plate 1  009   FALSE          FALSE        
#> 10 Plate 1  010   FALSE          FALSE        
#> # ℹ 190 more rows
```
