# Local data setup

Data files are intentionally excluded from the public Git repository. This is both a reproducibility choice—the scripts should rebuild all derived products—and a privacy precaution because the EDDMapS records include personal information and precise locations.

Create this local structure after cloning:

```text
data/
  data_raw/
    ga_southern/
      dwca-gsu_herps-v6.1.zip
      eml-gsu_herps-v6.1 (1).xml
      rtf-gsu_herps-v6.1.rtf
    tegus/
      62459.zip
```

The Georgia Southern archive metadata identifies this VertNet IPT resource:

- [Georgia Southern University Herpetology Collection on VertNet IPT](http://ipt.vertnet.org:8080/ipt/resource?r=gsu_herps)

EDDMapS provides the species page and map/download interface here:

- [Argentine black and white tegu (*Salvator merianae*) on EDDMapS](https://www.eddmaps.org/species/subject.cfm?sub=82961)
- [EDDMapS tegu distribution and download page](https://www.eddmaps.org/distribution/viewmap.cfm?sub=82961)

EDDMapS may require a login before downloading. Its generated ZIP filename may differ from `62459.zip`; rename the downloaded archive to `62459.zip` locally or update the `eddmaps` filename near the top of `R/00_config.R`.

The supplied ZIP filename does not preserve its query filters. A new download should be accompanied locally by a short provenance note recording:

- source landing-page URL;
- species and geographic filters;
- download date and time;
- source terms or reuse restrictions;
- whether precise locations or reporter information are included.

Do not commit raw downloads, clean record-level tables, GeoJSON, interactive maps or logs unless they have received a separate privacy, ecological-sensitivity and licensing review.
