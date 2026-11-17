# plateReadeR 0.0.0.9000

## Readers

* `read_bioscreen()` reads Bioscreen C text and csv exports (UTF-16, comma decimals) for one or two 100-well plates. The format is detected from the header line. Wells are named by a zero-padded `well` within `plate_id`, and the position in the run is kept as `well_index`. Compressed files are read directly.
* `read_logphase_txt()` reads LogPhase600 text exports, one plate per file.
* `read_logphase_xlsx(sheet = )` reads one kind of sheet, `"raw"`, `"results"` or `"procedure"`, from a LogPhase600 Excel export and stacks every plate in the file. `"results"` gives lag time and stationary phase in hours and max rate in OD/min. `"procedure"` parses the procedure summary into one row per plate (run time and interval in hours, wavelength, temperature, shaking).
* `read_synergy_xlsx(sheet = )` reads the `"raw"`, `"results"` or `"setup"` sheets of a Synergy H1 time course export in the same way.
* `read_synergy_endpoint()` reads Synergy H1 single time point exports, in either the Gen5 report layout or a plain 8 by 12 grid.
* All readers take `thin_hours` to keep only reads on a coarser grid. Thinning runs after snapping to `interval_hours`, so `thin_hours` must be a whole multiple of it.
* `read_bioscreen()` warns when there are more wells than two plates can hold (partly filled second plates are fine).
* All readers return a tidy tibble with `seconds`, `hours`, `plate_id`, `well` and `od`. Times are made relative to the first read and snapped to a regular grid.
* `snap_hours()` snaps elapsed hours onto the nominal read interval so timepoints line up across plates and runs.

## Quality control

* `flag_od_range()` adds well-level flags for saturated and negative OD.
* `blank_correct()` subtracts a blank, either named blank wells (time-matched, same plate, averaged if several) or the mean of each well's first reads, and clips at zero. It can also add a smoothed copy with `smooth = TRUE`.
* `smooth_od()` applies a centered rolling mean (5 points by default). Smoothing is off by default.
* `flag_no_growth()` flags wells whose blank-corrected OD never rises.

## Plotting

* `plot_plate()` draws growth curves for one plate, one panel per well, coloured by QC status, with an option to overlay the smoothed curve on the raw curve.

## Documentation

* A vignette, `vignette("plateReadeR")`, walks through the workflow on a LogPhase600 plate and a Bioscreen run.
