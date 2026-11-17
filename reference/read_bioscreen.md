# Read Bioscreen C output

Reads a text or csv export from a Bioscreen C plate reader and returns a
tidy (long) table with one row per well per time point.

## Usage

``` r
read_bioscreen(
  path,
  decimal_mark = ",",
  encoding = NULL,
  interval_hours = 1/12,
  thin_hours = NULL,
  wells_per_plate = 100,
  keep_blank = FALSE
)
```

## Arguments

- path:

  Path to the Bioscreen text or csv file. Compressed files (`.gz`,
  `.xz`, `.bz2`, `.zip`) are read directly.

- decimal_mark:

  Decimal mark used in the file, `","` or `"."`.

- encoding:

  File encoding. If `NULL` (default) it is detected from the byte-order
  mark, falling back to `"UTF-16LE"`, which Bioscreen exports use.

- interval_hours:

  Nominal read interval in hours (default `1/12`, five minutes). Elapsed
  times are snapped to multiples of this with
  [`snap_hours()`](https://slhogle.github.io/plateReadeR/reference/snap_hours.md)
  so that timepoints match exactly across plates and runs. Use `NULL` to
  keep the reported times.

- thin_hours:

  Optional coarser read interval in hours, for example `1/3` to keep one
  read every 20 minutes. Thinning happens after times are snapped to the
  `interval_hours` grid, keeps only reads that fall on the coarser grid,
  and requires `interval_hours` to be set and `thin_hours` to be a whole
  multiple of it. `NULL` (default) keeps every read.

- wells_per_plate:

  Number of wells in each Bioscreen plate (100 for the Honeycomb
  plates).

- keep_blank:

  If `TRUE`, keep the `Blank` column as well `"Blank"` (with
  `well_index` 0 and `plate_id` `NA`). The instrument reports this
  column as all zeros, so it is dropped by default.

## Value

A tibble with columns `seconds`, `hours`, `plate_id` (`"Plate 1"` or
`"Plate 2"`, the same format as the LogPhase600 readers), `well`
(zero-padded well within the plate, `"001"` to `"100"`), `well_index`
(integer position in the run, 1 to 100 or 1 to 200) and `od` (optical
density).

## Details

Bioscreen exports are UTF-16LE files with two preamble lines (`Label`
and `Info`), a header line (`Time`, `Blank`, then well numbers) and one
row of readings per time point. Text exports separate fields with
spaces; csv exports separate them with commas and quote each value. The
format is detected from the header line, so both are read by the same
call. The instrument computer often uses a comma as the decimal mark,
which is why `decimal_mark` defaults to `","`.

A Bioscreen run holds either one or two 100-well plates, so files
contain either 100 or 200 wells. Wells 1-100 belong to plate 1 and wells
101-200 to plate 2. Wells are named within each plate by a zero-padded
string (`"001"` to `"100"`), so a well is identified by `plate_id` and
`well`, as for the LogPhase600 readers. The 1-200 position in the run is
kept as `well_index`.

The Bioscreen does not report perfectly regular time intervals (for
example 00:30:06 versus 00:30:05), which makes it hard to combine runs.
By default times are therefore snapped onto a regular grid with
[`snap_hours()`](https://slhogle.github.io/plateReadeR/reference/snap_hours.md);
see `interval_hours`.

## Examples

``` r
f <- system.file("extdata", "bioscreen_example.txt", package = "plateReadeR")
read_bioscreen(f)
#> # A tibble: 4,000 × 6
#>    seconds  hours plate_id well  well_index    od
#>      <dbl>  <dbl> <chr>    <chr>      <int> <dbl>
#>  1       0 0      Plate 1  001            1 0.072
#>  2     300 0.0833 Plate 1  001            1 0.072
#>  3     600 0.167  Plate 1  001            1 0.072
#>  4     900 0.25   Plate 1  001            1 0.072
#>  5    1200 0.333  Plate 1  001            1 0.072
#>  6    1500 0.417  Plate 1  001            1 0.072
#>  7    1800 0.5    Plate 1  001            1 0.072
#>  8    2100 0.583  Plate 1  001            1 0.072
#>  9    2400 0.667  Plate 1  001            1 0.072
#> 10    2700 0.75   Plate 1  001            1 0.073
#> # ℹ 3,990 more rows
```
