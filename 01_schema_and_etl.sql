-- =====================================================
-- Database: PostgreSQL 18
-- Project: San Francisco Municipal Payroll Investigation
-- Author: Mykhailo Korobchuk
-- Script: 01_schema_and_etl.sql
-- Goal: Create raw staging table and transform into production-ready analytical table.
-- =====================================================

-- -----------------------------------------------------
-- 1. STAGING TABLE (Raw Data Ingestion)
-- Purpose: Ingest CSV without strict type-casting failures.
-- -----------------------------------------------------

DROP TABLE IF EXISTS salaries;

CREATE TABLE salaries (
    id TEXT,
    employee_name TEXT,
    job_title TEXT,
    base_pay TEXT,
    overtime_pay TEXT,
    other_pay TEXT,
    benefits TEXT,
    total_pay TEXT,
    total_pay_benefits TEXT,
    year TEXT
);

-- Note: Data was loaded via PostgreSQL COPY command from Salaries_clean.csv (148,650 rows).


-- -----------------------------------------------------
-- 2. PRODUCTION ANALYTICAL TABLE (sf_clean)
-- Purpose: Clean numeric types, handle missing values and commas.
-- -----------------------------------------------------

DROP TABLE IF EXISTS sf_clean;

CREATE TABLE sf_clean AS
SELECT 
    id::INTEGER,
    employee_name,
    job_title,
    NULLIF(REPLACE(base_pay, ',', '.'), '')::NUMERIC AS base_pay,
    NULLIF(REPLACE(overtime_pay, ',', '.'), '')::NUMERIC AS overtime_pay,
    NULLIF(REPLACE(other_pay, ',', '.'), '')::NUMERIC AS other_pay,
    NULLIF(REPLACE(benefits, ',', '.'), '')::NUMERIC AS benefits,
    NULLIF(REPLACE(total_pay, ',', '.'), '')::NUMERIC AS total_pay,
    NULLIF(REPLACE(total_pay_benefits, ',', '.'), '')::NUMERIC AS total_pay_benefits,
    year::INTEGER
FROM salaries;

-- Add Primary Key constraint for indexing and data integrity
ALTER TABLE sf_clean ADD PRIMARY KEY (id);
