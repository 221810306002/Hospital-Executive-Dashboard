-- ============================================================
-- 01_schema.sql

-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.clarity_dep (
    department_id   VARCHAR PRIMARY KEY,
    department_name VARCHAR,
    specialty        VARCHAR
);

CREATE TABLE raw.clarity_ser (
    prov_id         VARCHAR PRIMARY KEY,
    prov_name       VARCHAR,
    department_id   VARCHAR REFERENCES raw.clarity_dep(department_id),
    specialty       VARCHAR
);

CREATE TABLE raw.patient (
    pat_id      VARCHAR PRIMARY KEY,
    birth_date  DATE,
    sex         VARCHAR,
    race        VARCHAR,
    zip_code    VARCHAR
);

CREATE TABLE raw.pat_enc (
    pat_enc_csn_id  VARCHAR PRIMARY KEY,
    pat_id          VARCHAR REFERENCES raw.patient(pat_id),
    department_id   VARCHAR REFERENCES raw.clarity_dep(department_id),
    enc_type        VARCHAR,   -- Inpatient / Outpatient / Emergency
    contact_date    DATE,
    prov_id         VARCHAR REFERENCES raw.clarity_ser(prov_id)
);

CREATE TABLE raw.pat_enc_hsp (
    pat_enc_csn_id          VARCHAR PRIMARY KEY REFERENCES raw.pat_enc(pat_enc_csn_id),
    adt_pat_class           VARCHAR,
    admit_date              TIMESTAMP,
    disch_date              TIMESTAMP,
    discharge_disposition   VARCHAR,
    readmit_within_30d      BOOLEAN,
    satisfaction_score      DECIMAL(3,1)
);

CREATE TABLE raw.clarity_adt (
    pat_enc_csn_id  VARCHAR REFERENCES raw.pat_enc(pat_enc_csn_id),
    event_type      VARCHAR,  -- Admission / Transfer / Discharge
    event_time      TIMESTAMP,
    department_id   VARCHAR REFERENCES raw.clarity_dep(department_id)
);

CREATE TABLE raw.dx_current_icd10 (
    pat_enc_csn_id  VARCHAR REFERENCES raw.pat_enc(pat_enc_csn_id),
    icd10_code      VARCHAR,
    dx_name         VARCHAR
);

CREATE TABLE raw.order_med (
    pat_enc_csn_id      VARCHAR REFERENCES raw.pat_enc(pat_enc_csn_id),
    medication_id       VARCHAR,
    medication_name     VARCHAR,
    order_time          TIMESTAMP
);

CREATE TABLE raw.order_results (
    pat_enc_csn_id      VARCHAR REFERENCES raw.pat_enc(pat_enc_csn_id),
    component_id        VARCHAR,
    component_name       VARCHAR,
    ord_value            DECIMAL(10,2),
    units                 VARCHAR,
    result_time           TIMESTAMP
);
