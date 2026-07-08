-- ============================================================
-- 02_star_schema.sql
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE analytics.dim_patient AS
SELECT
    pat_id,
    birth_date,
    sex,
    race,
    zip_code,
    DATE_DIFF('year', birth_date, CURRENT_DATE) AS current_age
FROM raw.patient;

CREATE TABLE analytics.dim_department AS
SELECT department_id, department_name, specialty
FROM raw.clarity_dep;

CREATE TABLE analytics.dim_provider AS
SELECT prov_id, prov_name, department_id, specialty
FROM raw.clarity_ser;

CREATE TABLE analytics.dim_date AS
SELECT DISTINCT
    contact_date AS date_key,
    EXTRACT(year FROM contact_date)    AS year,
    EXTRACT(quarter FROM contact_date) AS quarter,
    EXTRACT(month FROM contact_date)   AS month,
    STRFTIME(contact_date, '%B')       AS month_name,
    EXTRACT(dow FROM contact_date)     AS day_of_week
FROM raw.pat_enc;


CREATE TABLE analytics.fact_encounter AS
SELECT
    e.pat_enc_csn_id,
    e.pat_id,
    e.department_id,
    e.prov_id,
    e.enc_type,
    e.contact_date,
    h.admit_date,
    h.disch_date,
    h.discharge_disposition,
    h.readmit_within_30d,
    h.satisfaction_score,
    CASE
        WHEN h.admit_date IS NOT NULL AND h.disch_date IS NOT NULL
        THEN DATE_DIFF('hour', h.admit_date, h.disch_date) / 24.0
        ELSE NULL
    END AS length_of_stay_days,
    CASE WHEN h.discharge_disposition = 'Expired' THEN 1 ELSE 0 END AS is_mortality,
    p.current_age AS patient_age
FROM raw.pat_enc e
LEFT JOIN raw.pat_enc_hsp h ON e.pat_enc_csn_id = h.pat_enc_csn_id
LEFT JOIN analytics.dim_patient p ON e.pat_id = p.pat_id;

CREATE TABLE analytics.fact_icu_stay AS
SELECT
    pat_enc_csn_id,
    department_id AS icu_department_id,
    event_time AS icu_admit_time
FROM raw.clarity_adt
WHERE event_type = 'Transfer'
  AND department_id IN ('D002', 'D003');


CREATE TABLE analytics.fact_diagnosis AS
SELECT pat_enc_csn_id, icd10_code, dx_name
FROM raw.dx_current_icd10;
