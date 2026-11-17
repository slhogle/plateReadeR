# Read LogPhase600 text export

Reads a text file exported from a LogPhase600 plate reader. The file has
a header block (procedure summary) followed by a line starting with
`Time` and the well names, and then one row per read. The header block
is located automatically.

## Usage

``` r
read_logphase_txt(
  path,
  interval_hours = 1/3,
  thin_hours = NULL,
  encoding = "latin1"
)
```

## Arguments

- path:

  Path to the text file.

- interval_hours:

  Nominal read interval in hours, passed to
  [`snap_hours()`](https://slhogle.github.io/plateReadeR/reference/snap_hours.md).
  Default is 20 minutes (`1/3`). Use `NULL` to keep the reported times.

- thin_hours:

  Optional coarser read interval in hours, for example `1` to keep one
  read per hour. Thinning happens after times are snapped to the
  `interval_hours` grid, keeps only reads that fall on the coarser grid,
  and requires `interval_hours` to be set and `thin_hours` to be a whole
  multiple of it. `NULL` (default) keeps every read.

- encoding:

  File encoding. Defaults to `"latin1"`, which these exports use (the
  header contains a degree sign).

## Value

A tibble with columns `seconds`, `hours`, `well`, `od` and `plate_id`.
`plate_id` is taken from the `Plate Number` line of the header (for
example `"Plate 1"`), matching the sheet names in the Excel export. If
that line is missing, the file name without its extension is used.

## Details

Time is made relative to the first read and snapped to a regular grid
with
[`snap_hours()`](https://slhogle.github.io/plateReadeR/reference/snap_hours.md)
so that replicate plates line up exactly. Well ids are zero-padded (`A1`
becomes `A01`).

## Examples

``` r
f <- system.file("extdata", "logphase600_example.txt", package = "plateReadeR")
read_logphase_txt(f)
#> # A tibble: 1,152 × 5
#>    seconds hours well     od plate_id
#>      <dbl> <dbl> <chr> <dbl> <chr>   
#>  1       0 0     A01   0.116 Plate 1 
#>  2    1200 0.333 A01   0.116 Plate 1 
#>  3    2400 0.667 A01   0.116 Plate 1 
#>  4    3600 1     A01   0.117 Plate 1 
#>  5    4800 1.33  A01   0.117 Plate 1 
#>  6    6000 1.67  A01   0.118 Plate 1 
#>  7    7200 2     A01   0.119 Plate 1 
#>  8    8400 2.33  A01   0.119 Plate 1 
#>  9    9600 2.67  A01   0.119 Plate 1 
#> 10   10800 3     A01   0.119 Plate 1 
#> # ℹ 1,142 more rows
```
