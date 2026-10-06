# BBS & CBC species detection viewer

Draft R Shiny application by Logan Clark. Explore reported bird detections
through time with an alphabetical species selector, raw or harmonized names,
year playback and GIF/PNG/site-year display-table downloads.

[Open the hosted draft viewer](https://clarklog-bbs-cbc-species-viewer.share.connect.posit.cloud/).

- BBS: 1966–2025; CBC: 1900–2024, based on the downloaded releases.
- Reviewed map scope: lower 48 states/DC and Canada.
- BBS detections are gold; CBC detections blue; surveyed sites gray.
- Gray sites are source-reported surveys, not confirmed species absences.
- Default colored points use count-eligible, positive count-day records.
  The diagnostic option includes positive records on held surveys.
- CBC January counts use the preceding calendar year. Count-week-only records
  and records without a known comparison year are not mapped as detections.

The approximately 24 MB export is presence-only. It preserves coverage,
eligibility, representative site coordinates, taxonomy alternatives and release
provenance; it contains no full source counts or effort tables. Harmonized names
are practical comparison units, not a claim of uniform historical taxonomy.
These maps are not effort-adjusted population trends or independent estimates
of range shifts. Coordinate and sampling-history limitations apply.

## Run locally

Install R and the packages below, then run from this repository's directory:

```r
install.packages(c('shiny','data.table','ggplot2','sf','digest','gifski'))
shiny::runApp('.')
```

`renv.lock` records the tested package versions. To restore them into a writable
library, install `renv` and call `renv::restore(lockfile='renv.lock',prompt=FALSE)`.
System dependencies for `sf` and `gifski` may be required on Linux.

Playback waits for a loaded frame, updates its displayed year, then requests
the next frame. The speed setting is a live hold duration; rendering can slow
live playback. Downloaded GIFs use the exact selected frame delay. Full-history
exports can take several minutes and temporarily occupy the hosting worker.

## Reproducibility and hosting

This repository is a generated, app-only deployment snapshot of the developing
BBS/CBC database workflow. `data/provenance.json` identifies the source release,
source database/crosswalk/builder hashes and missing-year totals. Individual
species partitions are verified against stored SHA-256 hashes when loaded.
No raw downloads, full database, private development notes or source Git history
are included. The reproducible export builder is maintained in the main database
project and will accompany its future public workflow release.

Posit Connect Cloud deploys `app.R` using `manifest.json`. The stored basemap and
display data allow runtime without contacting survey providers. Data sources:
[USGS BBS](https://www.pwrc.usgs.gov/BBS/),
[Audubon CBC](https://survey123.arcgis.com/share/7dc33b4fff77468a8bba855291f86527),
and [Natural Earth](https://www.naturalearthdata.com/).
Provider attribution and terms continue to apply. No new license is assigned
to the source survey data by this draft repository.
