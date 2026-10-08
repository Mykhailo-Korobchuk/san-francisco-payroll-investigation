# 🏛️ San Francisco Municipal Payroll & Overtime Investigation

An end-to-end municipal compensation audit analyzing **148,650 public payroll records** ($2.9B annual municipal budget) for the City and County of San Francisco. 

This project covers the full analytics lifecycle: **raw data profiling**, **data cleaning & transformation in Power Query**, **staging-to-production modeling in PostgreSQL**, **in-depth SQL auditing**, and **strategic municipal policy recommendations**.

---

## 📌 Executive Summary & Key Findings
+++++++



## 🔄 End-to-End Pipeline Architecture

```text
┌─────────────────┐       ┌────────────────────┐       ┌─────────────────────┐       ┌──────────────────┐
│  Raw Data (CSV) │  ───► │    Power Query     │  ───► │  PostgreSQL Staging │  ───► │   SQL Analytics  │
│  148.6K Rows    │       │  Audit & Cleaning  │       │  & Clean Production │       │  YoY, Outliers   │
└─────────────────┘       └────────────────────┘       └─────────────────────┘       └──────────────────┘
```



# 🛠️ Phase 1: Data Audit & Cleaning Metrics
A systematic pre-ingestion audit was conducted using Power Query Data Profiling (Column Quality, Column Distribution, and Column Profile) to identify and resolve dirty data issues.

📊 Data Cleaning Metrics Log:
- Metric	Value	Business Justification / Impact
- Raw Observations	148,654	Initial Kaggle dataset (Salaries.csv).
- Input Columns	13	Initial raw schema width.
- Redundant Columns Dropped	3	Dropped Notes (100% empty), Status (100% empty), and Agency (zero variance: 100% "San Francisco").
- Identified Anomalous Errors	3,420	Non-numeric entries, whitespace strings, and 'Not Provided' edge cases (e.g., IDs 148647, 148651–148653).
- Errors Handled & Replaced	3,420	Replaced string errors with explicit ANSI null values to preserve row integrity.
- Whitespace Normalization	100%	Applied Text.Trim to EmployeeName and JobTitle to eliminate trailing whitespace.
- Final Clean Observations	148,650	Fully verified, type-safe dataset loaded into PostgreSQL.
# 📂 Repository File Structure

```text
san-francisco-payroll-investigation/
├── data/
│   ├── Salaries_raw.csv           # Original untransformed Kaggle dataset
│   └── Salaries_clean.csv         # Cleaned, standardized 10-column dataset
├── 01_schema_and_etl.sql          # DDL: Staging and production analytical schema
├── 02_analysis.sql                # Production SQL audit & business queries
└── README.md                      # Comprehensive project documentation
```

### 📊 Business Question 1: What Are the Primary Cost Drivers of Municipal Expenditure?

* **Business Objective:** Deconstruct the total multi-year municipal budget into core structural components (Base Pay, Overtime, Additional Pay, and Benefits) to evaluate where taxpayer dollars are concentrated.

```sql
SELECT
    ROUND(SUM(base_pay), 2)           AS total_base,
    ROUND(SUM(overtime_pay), 2)       AS total_overtime,
    ROUND(SUM(other_pay), 2)          AS total_other,
    ROUND(SUM(benefits), 2)           AS total_benefits,
    ROUND(SUM(total_pay_benefits), 2) AS grand_total,
    ROUND(100.0 * SUM(base_pay)     / NULLIF(SUM(total_pay_benefits), 0), 2) AS base_pct,
    ROUND(100.0 * SUM(overtime_pay) / NULLIF(SUM(total_pay_benefits), 0), 2) AS overtime_pct,
    ROUND(100.0 * SUM(other_pay)    / NULLIF(SUM(total_pay_benefits), 0), 2) AS other_pct,
    ROUND(100.0 * SUM(benefits)     / NULLIF(SUM(total_pay_benefits), 0), 2) AS benefits_pct
FROM sf_clean;
```
📈 Results & Cost Breakdown:
<img width="1150" height="81" alt="image" src="https://github.com/user-attachments/assets/7bfffb21-adad-4b57-b4ec-c41b95be2da5" />




