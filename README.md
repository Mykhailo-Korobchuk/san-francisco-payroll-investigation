# 🏛️ San Francisco Municipal Payroll & Overtime Investigation

An end-to-end compensation audit of 148,650 public payroll records (2011–2014, ~$2.9B annual payroll excluding benefits) for the City and County of San Francisco.

The project covers the full analytics lifecycle: raw data profiling, cleaning and transformation in Power Query, staging-to-production modeling in PostgreSQL, and SQL analysis (cost structure, year-over-year dynamics). Overtime outlier analysis and policy recommendations are planned as next steps.


---

## 📌 Executive Summary & Key Findings
- Base pay dominates cost: base wages are 70.5% of total compensation, benefits 20.2%, overtime 5.4%, other pay 3.9%.
- Overtime outweighs other pay: overtime ($753M) is about 39% larger than all other pay combined ($542M).
- Payroll grew, then dipped: total pay rose +5.0% in 2012 and +7.1% in 2013, then fell −1.4% in 2014 despite more records (+517).
- Overtime share is rising every year: from 6.32% of total pay in 2011 to 7.16% in 2014.
- ----------------++++++++++++++++++++++++++++++++++


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

Business objective: break the total 2011–2014 compensation into Base Pay, Overtime, Other Pay and Benefits to see where taxpayer money is concentrated.

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

```
Component	|Total (USD)	    |Share of grand total
Base Pay	|9,819,150,982.31	|70.50%
Overtime	|753,066,596.98 	|5.41%
Other Pay	|542,370,270.97	    |3.89%
Benefits	|2,813,149,454.79	|20.20%
Grand Total	|13,927,772,712.41	|100%
```

<img width="1150" height="81" alt="image" src="https://github.com/user-attachments/assets/7bfffb21-adad-4b57-b4ec-c41b95be2da5" />

**💡 Analytical Takeaways**
- The 70 / 20 split: base wages are 70.5% of cost and benefits (pensions, medical) are 20.2% ($2.81B). For every $3.50 of base pay, the city pays about $1.00 in benefits.
- Variable compensation: overtime plus other pay is 9.3% ($1.295B) of total spending. Overtime ($753M) exceeds all other pay combined ($542M).

### 📈 Business Question 2: How Did Payroll Evolve Over Time (YoY Dynamics)?

Business objective: evaluate payroll scaling across 2011–2014, track record counts, annual dollar shifts and YoY percentage growth.

```sql
SELECT 
    year,
    COUNT(*) AS total_workers,
    ROUND(SUM(total_pay), 2) AS total_payroll,
    ROUND(LAG(SUM(total_pay)) OVER (ORDER BY year), 2) AS prev_year_payroll,
    ROUND(SUM(total_pay) - LAG(SUM(total_pay)) OVER (ORDER BY year), 2) AS growth_amount,
    ROUND(
        (SUM(total_pay) - LAG(SUM(total_pay)) OVER (ORDER BY year)) * 100 
        / NULLIF(LAG(SUM(total_pay)) OVER (ORDER BY year), 0), 
        2
    ) AS growth_pct,
    ROUND(SUM(overtime_pay) * 100 / NULLIF(SUM(total_pay), 0), 2) AS overtime_share_pct
FROM sf_clean
GROUP BY year
ORDER BY year;
```
📊 Annual Municipal Growth Metrics:
```
Year	|Records	|Total Payroll	|Prev Year Payroll |YoY Change  	 |Growth %	    | Overtime Share*
2011	|36159	    |2594194970.89	|			       |                 |              | 6.32
2012	|36766	    |2724848116.46	|2594194970.89	   |130653145.57	 |5.04	        | 6.78
2013	|37606	    |2918655824.83	|2724848116.46	   |193807708.37	 |7.11	        | 6.81
2014	|38123	    |2876910873.87	|2918655824.83	   |-41744950.96	 |-1.43	        | 7.16
```


<img width="980" height="172" alt="image" src="https://github.com/user-attachments/assets/ef012020-f6d2-4193-b7bb-0d9f282db707" />

**💡 Key Takeaways**
- Peak in 2013: payroll reached $2.92B, up +7.11% (+$193.8M) while records grew by 840.
- Dip in 2014: payroll fell −1.43% (−$41.7M) even though records grew by 517. Average pay per record dropped about 2.8%. The data alone does not explain why.
- Rising overtime share: overtime grew roughly 25.7% over 2011–2014 against about +5.4% growth in records, lifting its share of total pay from 6.32% to 7.16%.




