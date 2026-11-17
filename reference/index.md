# Package index

## Read plate reader output

Read instrument files into tidy data frames.

- [`read_bioscreen()`](https://slhogle.github.io/plateReadeR/reference/read_bioscreen.md)
  : Read Bioscreen C output
- [`read_logphase_txt()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_txt.md)
  : Read LogPhase600 text export
- [`read_logphase_xlsx()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_xlsx.md)
  : Read LogPhase600 Excel export
- [`read_synergy_xlsx()`](https://slhogle.github.io/plateReadeR/reference/read_synergy_xlsx.md)
  : Read Synergy H1 time course Excel export
- [`read_synergy_endpoint()`](https://slhogle.github.io/plateReadeR/reference/read_synergy_endpoint.md)
  : Read Synergy H1 single time point Excel export
- [`snap_hours()`](https://slhogle.github.io/plateReadeR/reference/snap_hours.md)
  : Snap elapsed time onto a regular grid

## Quality control

Flag problem wells, blank-correct and smooth growth curves.

- [`flag_od_range()`](https://slhogle.github.io/plateReadeR/reference/flag_od_range.md)
  : Flag wells with saturated or negative OD
- [`blank_correct()`](https://slhogle.github.io/plateReadeR/reference/blank_correct.md)
  : Blank-correct OD
- [`smooth_od()`](https://slhogle.github.io/plateReadeR/reference/smooth_od.md)
  : Smooth growth curves with a centered rolling mean
- [`flag_no_growth()`](https://slhogle.github.io/plateReadeR/reference/flag_no_growth.md)
  : Flag wells whose blank-corrected signal never rises

## Plotting

- [`plot_plate()`](https://slhogle.github.io/plateReadeR/reference/plot_plate.md)
  : Plot growth curves for one plate
