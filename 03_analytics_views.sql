-- ============================================================
-- 03_analytics_views.sql
-- ============================================================

-- Monthly admissions, average LOS, readmission rate, mortality rate
CREATE OR REPLACE VIEW analytics.vw_monthly_kpis AS
SELECT
    EXTRACT(year FROM contact_date)  AS year,
    EXTRACT(month FROM contact_date) AS month,
    COUNT(*)                                              AS total_encounters,
    SUM(CASE WHEN enc_type = 'Inpatient' THEN 1 ELSE 0 END)  AS admissions,
    ROUND(AVG(length_of_stay_days), 2)                    AS avg_length_of_stay,
    ROUND(100.0 * SUM(readmit_within_30d) /
          NULLIF(SUM(CASE WHEN enc_type = 'Inpatient' THEN 1 ELSE 0 END), 0), 2)
                                                            AS readmission_rate_pct,
    ROUND(100.0 * SUM(is_mortality) /
          NULLIF(SUM(CASE WHEN enc_type IN ('Inpatient','Emergency') THEN 1 ELSE 0 END), 0), 2)
                                                            AS mortality_rate_pct,
    ROUND(AVG(satisfaction_score), 2)                     AS avg_satisfaction_score
FROM analytics.fact_encounter
GROUP BY 1, 2
ORDER BY 1, 2;

-- Department-level comparison
CREATE OR REPLACE VIEW analytics.vw_department_performance AS
SELECT
    d.department_name,
    d.specialty,
    COUNT(*)                                    AS total_encounters,
    ROUND(AVG(f.length_of_stay_days), 2)        AS avg_length_of_stay,
    ROUND(100.0 * SUM(f.readmit_within_30d) / NULLIF(COUNT(*), 0), 2) AS readmission_rate_pct,
    ROUND(AVG(f.satisfaction_score), 2)         AS avg_satisfaction_score,
    ROUND(100.0 * SUM(f.is_mortality) / NULLIF(COUNT(*), 0), 2)       AS mortality_rate_pct
FROM analytics.fact_encounter f
JOIN analytics.dim_department d ON f.department_id = d.department_id
GROUP BY 1, 2
ORDER BY total_encounters DESC;

-- ICU utilization: distinct ICU transfers per month vs total inpatient encounters
CREATE OR REPLACE VIEW analytics.vw_icu_monthly_transfers AS
SELECT
    EXTRACT(year FROM icu_admit_time)  AS year,
    EXTRACT(month FROM icu_admit_time) AS month,
    COUNT(DISTINCT pat_enc_csn_id)      AS icu_transfers
FROM analytics.fact_icu_stay
GROUP BY 1, 2;

CREATE OR REPLACE VIEW analytics.vw_inpatient_monthly_volume AS
SELECT
    EXTRACT(year FROM contact_date)  AS year,
    EXTRACT(month FROM contact_date) AS month,
    COUNT(*) AS total_inpatient_encounters
FROM analytics.fact_encounter
WHERE enc_type = 'Inpatient'
GROUP BY 1, 2;

CREATE OR REPLACE VIEW analytics.vw_icu_utilization AS
SELECT
    v.year,
    v.month,
    v.icu_transfers,
    i.total_inpatient_encounters,
    ROUND(100.0 * v.icu_transfers / NULLIF(i.total_inpatient_encounters, 0), 2) AS icu_utilization_pct
FROM analytics.vw_icu_monthly_transfers v
JOIN analytics.vw_inpatient_monthly_volume i ON v.year = i.year AND v.month = i.month
ORDER BY 1, 2;

-- Top diagnoses by volume (feeds the "Top Conditions" chart)
CREATE OR REPLACE VIEW analytics.vw_top_diagnoses AS
SELECT
    dx.icd10_code,
    dx.dx_name,
    COUNT(*)                              AS encounter_count,
    ROUND(AVG(f.length_of_stay_days), 2)  AS avg_length_of_stay,
    ROUND(100.0 * SUM(f.readmit_within_30d) / NULLIF(COUNT(*), 0), 2) AS readmission_rate_pct
FROM analytics.fact_diagnosis dx
JOIN analytics.fact_encounter f ON dx.pat_enc_csn_id = f.pat_enc_csn_id
GROUP BY 1, 2
ORDER BY encounter_count DESC;

-- Physician-level performance
CREATE OR REPLACE VIEW analytics.vw_physician_performance AS
SELECT
    pr.prov_name,
    d.department_name,
    COUNT(*)                                    AS total_encounters,
    ROUND(AVG(f.length_of_stay_days), 2)        AS avg_length_of_stay,
    ROUND(AVG(f.satisfaction_score), 2)         AS avg_satisfaction_score,
    ROUND(100.0 * SUM(f.readmit_within_30d) / NULLIF(COUNT(*), 0), 2) AS readmission_rate_pct
FROM analytics.fact_encounter f
JOIN analytics.dim_provider pr ON f.prov_id = pr.prov_id
JOIN analytics.dim_department d ON pr.department_id = d.department_id
GROUP BY 1, 2
ORDER BY total_encounters DESC;

-- Bed occupancy proxy: overlapping inpatient stays per department per day
-- (a simplified daily census - counts any stay whose admit/discharge window
-- includes that calendar day)
CREATE OR REPLACE VIEW analytics.vw_daily_census AS
SELECT
    d.department_id,
    d.department_name,
    CAST(f.admit_date AS DATE) AS census_date,
    COUNT(*) AS patients_in_house
FROM analytics.fact_encounter f
JOIN analytics.dim_department d ON f.department_id = d.department_id
WHERE f.enc_type IN ('Inpatient', 'Emergency')
  AND f.admit_date IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY 3, 1;
