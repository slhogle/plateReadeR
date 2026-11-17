# Read Synergy H1 single time point Excel export

Reads an Excel export of a single time point (endpoint) measurement from
a BioTek Synergy H1 plate reader and returns one row per well. Two
layouts are recognised and detected automatically: the Gen5 report
layout (a block of run details followed by a row of wells and a row of
readings) and a plain 8 by 12 grid with column numbers across the top
and row letters down the side. Every sheet in the file is read.

## Usage

``` r
read_synergy_endpoint(path)
```

## Arguments

- path:

  Path to the xlsx file.

## Value

A tibble with columns `plate_id`, `well` (zero-padded, such as `"A01"`),
`od` and `wavelength_nm`. `plate_id` is taken from the sheet name when
it starts with `Plate` (for example `"Plate 19 - Sheet1"` gives
`"Plate 19"`), otherwise the file name without its extension is used.
`wavelength_nm` is `NA` if the file does not record it.

## Details

For time course exports use
[`read_synergy_xlsx()`](https://slhogle.github.io/plateReadeR/reference/read_synergy_xlsx.md).

## Examples

``` r
f <- system.file("extdata", "synergy_endpoint_example.xlsx", package = "plateReadeR")
read_synergy_endpoint(f)
#> # A tibble: 96 × 4
#>    plate_id                 well     od wavelength_nm
#>    <chr>                    <chr> <dbl>         <dbl>
#>  1 synergy_endpoint_example A01   0.406           590
#>  2 synergy_endpoint_example B01   0.249           590
#>  3 synergy_endpoint_example C01   0.166           590
#>  4 synergy_endpoint_example D01   0.13            590
#>  5 synergy_endpoint_example E01   0.103           590
#>  6 synergy_endpoint_example F01   0.318           590
#>  7 synergy_endpoint_example G01   0.244           590
#>  8 synergy_endpoint_example H01   0.273           590
#>  9 synergy_endpoint_example A02   0.266           590
#> 10 synergy_endpoint_example B02   0.112           590
#> # ℹ 86 more rows
```
