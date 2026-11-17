# Plot growth curves for one plate

Draws one panel per well for a single plate, with the well laid out on
the plate grid when well ids are row-column names (such as `"A01"`, as
from the LogPhase600 readers) and in a square-ish grid otherwise (such
as the Bioscreen's `"001"` to `"100"`). Each curve is coloured by its QC
status, built from whichever of the flag columns added by
[`flag_od_range()`](https://slhogle.github.io/plateReadeR/reference/flag_od_range.md)
and
[`flag_no_growth()`](https://slhogle.github.io/plateReadeR/reference/flag_no_growth.md)
are present in `data`. Wells with no flags are `"ok"`; wells with
several flags show them joined with `+`.

## Usage

``` r
plot_plate(
  data,
  plate = NULL,
  od = NULL,
  flags = NULL,
  smooth = FALSE,
  window = 5,
  scales = "fixed"
)
```

## Arguments

- data:

  Tidy data frame from a reader, optionally with QC columns.

- plate:

  `plate_id` of the plate to draw. Can be omitted if `data` holds a
  single plate or has no `plate_id` column.

- od:

  Name of the OD column to plot. Defaults to `"od_corrected"` if
  present, otherwise `"od"`.

- flags:

  Names of logical flag columns to colour by. Defaults to all of
  `flag_saturated`, `flag_negative` and `flag_no_growth` found in
  `data`.

- smooth:

  If `TRUE`, overlay the smoothed curve (solid) on the raw curve
  (dashed, faded). Uses the `<od>_rollmean` column if present, otherwise
  computes it with
  [`smooth_od()`](https://slhogle.github.io/plateReadeR/reference/smooth_od.md).

- window:

  Window size used if the smoothed curve has to be computed.

- scales:

  Panel scales, passed to
  [`ggplot2::facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
  or
  [`ggplot2::facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html):
  `"fixed"` (default) or `"free_y"`.

## Value

A ggplot object.

## Examples

``` r
f <- system.file("extdata", "logphase600_example.txt", package = "plateReadeR")
d <- read_logphase_txt(f)
d <- flag_no_growth(blank_correct(flag_od_range(d, saturation = 2)))
plot_plate(d)
```
