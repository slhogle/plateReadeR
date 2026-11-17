# plateReadeR

`plateReadeR` reads output files (plain text, csv, Microsoft Excel) from
different microplate readers with a target audience of scientists who
are using these to analyze microbial growth curves. Currently I have
implemented parsers for the [Bioscreen C
MBR](https://www.bioscreen.fi/about/), [Agilent BioTek LogPhase
600](https://www.agilent.com/en/video/logphase600) and the [BioTek
Synergy H1 Multimode
Reader](https://www.agilent.com/en/product/microplate-instrumentation/microplate-readers/multimode-microplate-readers/biotek-synergy-h1-multimode-reader-1623193).

These parsers convert files from these instruments into tidy data
frames, and runs basic quality control checks with sensible defaults.
The user can then join the plate tidied results to sample metadata for
downstream analysis.

| Function | Instrument | Format |
|----|----|----|
| [`read_logphase_txt()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_txt.md) | LogPhase600 | text, one file per plate |
| [`read_logphase_xlsx()`](https://slhogle.github.io/plateReadeR/reference/read_logphase_xlsx.md) | LogPhase600 | Excel; `sheet = "raw"`, `"results"` or `"procedure"`, all plates stacked |
| [`read_synergy_xlsx()`](https://slhogle.github.io/plateReadeR/reference/read_synergy_xlsx.md) | Synergy H1 | Excel time course; `sheet = "raw"`, `"results"` or `"setup"` |
| [`read_synergy_endpoint()`](https://slhogle.github.io/plateReadeR/reference/read_synergy_endpoint.md) | Synergy H1 | Excel single time point |
| [`read_bioscreen()`](https://slhogle.github.io/plateReadeR/reference/read_bioscreen.md) | Bioscreen C | UTF-16 text or csv, one or two 100-well plates |

The time course readers return one row per well per time point, with
`plate_id` and `well` identifying the well.

## Installation

You can install the development version from GitHub with:

``` r

# install.packages("pak")
pak::pkg_install("slhogle/plateReadeR")
```

## Example

``` r

library(plateReadeR)

f <- system.file("extdata", "logphase600_plate1.txt", package = "plateReadeR")

read_logphase_txt(f) |>
  flag_od_range(saturation = 2) |>
  blank_correct(smooth = TRUE) |>
  flag_no_growth() |>
  plot_plate(plate = "Plate 1", smooth = TRUE)
```

See
[`vignette("plateReadeR")`](https://slhogle.github.io/plateReadeR/articles/plateReadeR.md)
for the full workflow, including the Bioscreen reader.
