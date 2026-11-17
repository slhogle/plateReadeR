# Snap elapsed time onto a regular grid

Each plate reader keeps its own clock, so the elapsed time for what is
meant to be the same nominal timepoint can drift by a second or more
between plates and runs. Left as is, that drift makes exact-value
grouping (for example `group_by(hours)` when pooling replicates across
plates) fracture into several near-duplicate groups, which shows up
downstream as an artificially jagged mean. Snapping elapsed hours onto
the nominal read interval grid makes timepoints line up exactly.

## Usage

``` r
snap_hours(hours, interval_hours = 1/3)
```

## Arguments

- hours:

  Numeric vector of elapsed time in hours.

- interval_hours:

  Nominal read interval in hours. Defaults to 20 minutes (`1/3`).

## Value

Numeric vector of hours, rounded to the nearest multiple of
`interval_hours`.

## Examples

``` r
snap_hours(c(0, 0.3336, 0.6661, 1.0003))
#> [1] 0.0000000 0.3333333 0.6666667 1.0000000
```
