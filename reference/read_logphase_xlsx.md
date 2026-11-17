# Read LogPhase600 Excel export

Reads one kind of sheet from an Excel export of a LogPhase600 plate
reader. A run can hold up to four 96-well plates, and each plate has its
own `Results`, `Raw Data` and `Procedure` sheets (for example
`Plate 1 - Raw Data`). The `sheet` argument chooses which kind to read;
every plate in the file is read and the plates are stacked into one
table, identified by `plate_id`. To keep only some plates, filter on
`plate_id` afterwards.

## Usage

``` r
read_logphase_xlsx(
  path,
  sheet = c("raw", "results", "procedure"),
  interval_hours = 1/3,
  thin_hours = NULL
)
```

## Arguments

- path:

  Path to the xlsx file.

- sheet:

  Which kind of sheet to read: `"raw"` (default), `"results"` or
  `"procedure"`.

- interval_hours, thin_hours:

  Used only when `sheet = "raw"`. See
  [`read_logphase_txt()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_txt.md).

## Value

A tibble. The columns depend on `sheet`; all have `plate_id`, the sheet
name without the trailing sheet type (such as `"Plate 1"`).

- `"raw"`: `seconds`, `hours`, `well`, `od` and `plate_id`.

- `"results"`: one row per well with `plate_id`, `well` (zero-padded as
  for `"raw"`), `lag_hours`, `max_rate` (OD per minute) and
  `stationary_hours`. Join to the raw data by `plate_id` and `well`.

- `"procedure"`: one row per plate with `plate_id`, `plate_comment`,
  `plate_type`, `runtime_hours`, `interval_hours`, `max_reads`,
  `wavelength_nm`, `incubator`, `temperature_setpoint_c`,
  `temperature_gradient`, `shaking`, `shaking_rpm` and `summary`.

## Details

- `"raw"`: the optical density time courses, equivalent to the text
  files. Processing is the same as for
  [`read_logphase_txt()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_txt.md).

- `"results"`: the per-well summary the instrument software computed
  (lag time, maximum growth rate and stationary phase). These are rarely
  needed, since the package works from the raw reads, but they are
  available for comparison with your own estimates. The instrument
  stores lag time and stationary phase as Excel day fractions, which are
  converted to hours. Wells for which the software reported no value
  (`?????` in the sheet) are `NA`.

- `"procedure"`: the run settings recorded for each plate, parsed from
  the procedure summary text into one row per plate. Times are converted
  to hours and on/off settings to logicals. The original text is kept in
  `summary`, in case a setting is not covered by the parsed columns.

## Examples

``` r
f <- system.file("extdata", "logphase600_example.xlsx", package = "plateReadeR")
read_logphase_xlsx(f)
#> # A tibble: 2,304 × 5
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
#> # ℹ 2,294 more rows
read_logphase_xlsx(f, sheet = "results")
#> # A tibble: 192 × 5
#>    plate_id well  lag_hours    max_rate stationary_hours
#>    <chr>    <chr>     <dbl>       <dbl>            <dbl>
#>  1 Plate 1  A01       NA     0.0000191              4.72
#>  2 Plate 1  B01        4.60  0.00000241             4.69
#>  3 Plate 1  C01       30.1  -0.00000155            37.4 
#>  4 Plate 1  D01       22.5  -0.00000164            27.4 
#>  5 Plate 1  E01       NA    -0.00000270             2.33
#>  6 Plate 1  F01        7.42  0.00000121            11.7 
#>  7 Plate 1  G01       22.9  -0.00000177            28.2 
#>  8 Plate 1  H01       34.6  -0.00000357            35.2 
#>  9 Plate 1  A02        8.82  0.00000162             8.62
#> 10 Plate 1  B02       11.4   0.00000141             5.40
#> # ℹ 182 more rows
read_logphase_xlsx(f, sheet = "procedure")
#> # A tibble: 2 × 13
#>   plate_id plate_comment plate_type       runtime_hours interval_hours max_reads
#>   <chr>    <chr>         <chr>                    <dbl>          <dbl>     <int>
#> 1 Plate 1  NA            Corning 96 well…            48          0.333       145
#> 2 Plate 2  NA            Corning 96 well…            48          0.333       145
#> # ℹ 7 more variables: wavelength_nm <dbl>, incubator <lgl>,
#> #   temperature_setpoint_c <dbl>, temperature_gradient <lgl>, shaking <lgl>,
#> #   shaking_rpm <dbl>, summary <chr>
```
