# Hospital Executive Dashboard

An end-to-end healthcare BI pipeline: synthetic EHR data modeled on Epic
Clarity's table conventions, loaded into a SQL warehouse, transformed into a
star schema, and surfaced as an executive dashboard covering admissions,
length of stay, readmissions, mortality, ICU utilization, and patient
satisfaction.

No real patient data is used anywhere in this repo. All records are
generated with [Faker](https://faker.readthedocs.io/) and a set of clinical
reference lists I put together by hand (common ICD-10 codes, department
types, medications) so the numbers behave the way a hospital's actually do -
older patients skew toward longer stays, certain diagnoses cluster in
certain departments, chronic conditions have a higher readmission rate, etc.

## Why I built this

I work in clinical evaluation analytics at a medical school, which gave me
SQL, Power BI, Power Apps, Snowflake and Python experience, but all on
survey/evaluation data - not clinical/EHR data. This project exists to close
that specific gap and show I can work with the kind of admissions/encounter
data that hospital BI roles actually deal with day to day.

## Architecture

```
Faker-generated CSVs (data/raw/)
        |
        v
DuckDB warehouse  --  raw schema (Clarity-style tables)
        |
        v
Star schema        --  analytics schema (dim_patient, dim_department,
        |                fact_encounter, fact_icu_stay, ...)
        v
KPI views           --  vw_monthly_kpis, vw_department_performance,
        |                vw_icu_utilization, vw_top_diagnoses, ...
        v
   +----+----+
   |         |
   v         v
kpi_data.json   CSV exports
(dashboard/)    (data/exports/, for Power BI / Excel)
   |
   v
index.html (Chart.js dashboard)
```

I used DuckDB instead of an actual Snowflake account so anyone cloning this
can run the whole pipeline with `pip install` and no cloud credentials. The
SQL is close enough to Snowflake's dialect that porting it over is mostly a
find-and-replace on date functions - see `docs/snowflake_notes.md` for the
specifics if you want to actually stand this up on Snowflake and connect
Power BI to it directly.

## Data model

Table names follow Epic Clarity's naming conventions (`PAT_ENC`,
`PAT_ENC_HSP`, `DX_CURRENT_ICD10`, `CLARITY_ADT`, `CLARITY_DEP`) rather than
generic names, since that's the schema shape you'll actually run into at a
hospital. See `sql/01_schema.sql` for the raw layer and
`sql/02_star_schema.sql` for how it gets flattened into a proper dimensional
model (`dim_patient`, `dim_department`, `dim_provider`, `dim_date`,
`fact_encounter`, `fact_icu_stay`, `fact_diagnosis`).

## Running it yourself

```bash
git clone <this-repo>
cd hospital-analytics
pip install -r requirements.txt

# 1. generate synthetic data (defaults to 8,000 patients, ~2 years of encounters)
python data_generation/generate_synthetic_ehr.py --patients 8000 --seed 42

# 2. load it into DuckDB and build the star schema + KPI views
python etl/load_to_warehouse.py

# 3. export the KPI views to CSV + JSON
python etl/export_kpis.py

# 4. bake the JSON into the dashboard HTML
python dashboard/build_dashboard.py
```

Then open `dashboard/index.html` in a browser - the KPI data is baked
straight into the file so there's no local server or CORS issue to deal
with.

## What's in the dashboard

- Six headline KPIs with 12-month sparklines and month-over-month deltas:
  admissions, average length of stay, readmission rate, mortality rate, ICU
  utilization, and patient satisfaction
- Monthly trend of admissions vs. average length of stay
- Monthly readmission % and mortality % trend
- Department comparison (average LOS by department)
- ICU utilization over time
- Top 10 diagnoses by encounter volume, with readmission rate flagged by
  severity
- Physician performance table, filterable by department

`docs/power_bi_measures.md` has the DAX equivalents of every measure above,
in case you want to rebuild this as an actual `.pbix` against a real
Snowflake or SQL Server warehouse instead of the static HTML version here.

## Repo layout

```
data_generation/   synthetic EHR data generator
data/raw/          generated CSVs (gitignored - regenerate locally)
data/exports/      KPI views exported to CSV (Power BI / Excel ready)
sql/               raw schema, star schema, analytics views
etl/               load-to-warehouse and export scripts
dashboard/         HTML/Chart.js dashboard + build script
docs/              Snowflake porting notes, Power BI DAX reference
```

## Things I'd add with more time

- A proper slowly-changing-dimension pattern on `dim_patient` (right now it's
  a plain CTAS, no history tracking)
- Incremental loads instead of a full rebuild every run
- A second fact table for medication administration timing, to support a
  med-error / adverse-event analysis
- Swapping the synthetic generator for actual [Synthea](https://github.com/synthetichealth/synthea)
  output, which has more clinically realistic comorbidity patterns than my
  hand-rolled diagnosis list

## License

MIT - see LICENSE. Data is entirely synthetic; no real patient information
is included or was used to produce it.
