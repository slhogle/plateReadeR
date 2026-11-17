# Read Synergy H1 time course Excel export

Reads one kind of sheet from an Excel export of a time course (kinetic)
run on a BioTek Synergy H1 plate reader. Each plate has `Setup`,
`Results` and `Raw Data` sheets (for example `Plate 1 - Raw Data`). The
`sheet` argument chooses which kind to read; every plate in the file is
read and the plates are stacked into one table, identified by
`plate_id`. To keep only some plates, filter on `plate_id` afterwards.

## Usage

``` r
read_synergy_xlsx(
  path,
  sheet = c("raw", "results", "setup"),
  interval_hours = 1/3,
  thin_hours = NULL
)
```

## Arguments

- path:

  Path to the xlsx file.

- sheet:

  Which kind of sheet to read: `"raw"` (default), `"results"` or
  `"setup"`.

- interval_hours, thin_hours:

  Used only when `sheet = "raw"`. See
  [`read_logphase_txt()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_txt.md).
  The default interval is 20 minutes (`1/3`).

## Value

A tibble. The columns depend on `sheet`; all have `plate_id`, the sheet
name without the trailing sheet type (such as `"Plate 1"`).

- `"raw"`: `seconds`, `hours`, `well`, `od` and `plate_id`.

- `"results"`: one row per well with `plate_id`, `well` (zero-padded),
  `lag_hours`, `max_v` (maximum slope of `ln(OD)`, as reported),
  `doubling_hours` and `stationary_hours`.

- `"setup"`: `plate_id`, `key` and `value`.

## Details

- `"raw"`: the optical density time courses. Processing is the same as
  for
  [`read_logphase_txt()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_txt.md).
  The label row above the header (such as `OD590`) is skipped.

- `"results"`: the per-well summary computed by the instrument software
  (lag time, maximum growth rate, doubling time and stationary phase).
  Times are stored by the software as Excel day fractions (or, for
  negative values, as text such as `-3:13:23`) and are converted to
  hours. Wells with no value (`?????`) are `NA`. The `Well ID` and
  `Name` rows are not read.

- `"setup"`: the run protocol (temperature, interval, shaking, read
  settings and so on) as a table of `key` and `value`. A key that spans
  several lines of the sheet has one row per line. The plate layout and
  data reduction blocks that follow the protocol are not read.

Single time point (endpoint) exports are read with
[`read_synergy_endpoint()`](https://slhogle.github.io/plateReadeR/reference/read_synergy_endpoint.md).

## Examples

``` r
f <- system.file("extdata", "synergy_example.xlsx", package = "plateReadeR")
read_synergy_xlsx(f)
#> # A tibble: 1,152 × 5
#>    seconds hours well     od plate_id
#>      <dbl> <dbl> <chr> <dbl> <chr>   
#>  1       0 0     A01   0.089 Plate 1 
#>  2    1200 0.333 A01   0.089 Plate 1 
#>  3    2400 0.667 A01   0.089 Plate 1 
#>  4    3600 1     A01   0.089 Plate 1 
#>  5    4800 1.33  A01   0.089 Plate 1 
#>  6    6000 1.67  A01   0.089 Plate 1 
#>  7    7200 2     A01   0.089 Plate 1 
#>  8    8400 2.33  A01   0.089 Plate 1 
#>  9    9600 2.67  A01   0.089 Plate 1 
#> 10   10800 3     A01   0.089 Plate 1 
#> # ℹ 1,142 more rows
read_synergy_xlsx(f, sheet = "results")
#> # A tibble: 96 × 6
#>    plate_id well  lag_hours  max_v doubling_hours stationary_hours
#>    <chr>    <chr>     <dbl>  <dbl>          <dbl>            <dbl>
#>  1 Plate 1  A01        5.42  0              26.5             9.33 
#>  2 Plate 1  B01       15.7   0.007           1.60           23.1  
#>  3 Plate 1  C01       NA    -0.004          -3.22            0.456
#>  4 Plate 1  D01       30.1  -0.003          -3.96           26.1  
#>  5 Plate 1  E01        6.96  0              25.6             9.57 
#>  6 Plate 1  F01        5.48  0.002           6.96           10.8  
#>  7 Plate 1  G01       15.0   0.008           1.42           21.8  
#>  8 Plate 1  H01       27.9   0.002           7.69           34.5  
#>  9 Plate 1  A02       21.1   0.008           1.47           28.7  
#> 10 Plate 1  B02       NA     0              40.8             2.41 
#> # ℹ 86 more rows
read_synergy_xlsx(f, sheet = "setup")
#> # A tibble: 12 × 3
#>    plate_id key                       value                                     
#>    <chr>    <chr>                     <chr>                                     
#>  1 Plate 1  Plate Type                96 WELL PLATE (Use plate lid)             
#>  2 Plate 1  Eject plate on completion NA                                        
#>  3 Plate 1  Set Temperature           Setpoint 30°C, Gradient 0,0 °C            
#>  4 Plate 1  Set Temperature           Preheat before moving to next step        
#>  5 Plate 1  Start Kinetic             Runtime 48:00:00 (HH:MM:SS), Interval 0:2…
#>  6 Plate 1  Shake                     Orbital: 0:10 (MM:SS)                     
#>  7 Plate 1  Shake                     Frequency: 425 cpm (3 mm)                 
#>  8 Plate 1  Read                      Absorbance Endpoint                       
#>  9 Plate 1  Read                      Full Plate                                
#> 10 Plate 1  Read                      Wavelengths: 590                          
#> 11 Plate 1  Read                      Read Speed: Normal, Delay: 100 msec, Meas…
#> 12 Plate 1  End Kinetic               NA                                        
```
