# 🏛️ San Francisco Municipal Payroll & Overtime Investigation

An end-to-end compensation audit of 148,650 public payroll records (2011–2014, ~$2.9B annual payroll excluding benefits) for the City and County of San Francisco.

The project covers the full analytics lifecycle: raw data profiling, cleaning and transformation in Power Query, staging-to-production modeling in PostgreSQL, and SQL analysis (cost structure, year-over-year dynamics). Overtime outlier analysis and policy recommendations are planned as next steps.

**Tech Stack:** `Power Query` · `PostgreSQL 18` · `pgAdmin 4` · `SQL` (`CTEs`, `Window Functions`, `CASE`, `Pattern Matching`

---

## 📌 Executive Summary & Key Findings
- Base pay dominates cost: base wages are 70.5% of total compensation, benefits 20.2%, overtime 5.4%, other pay 3.9%.
- Overtime outweighs other pay: overtime ($753M) is about 39% larger than all other pay combined ($542M).
- Payroll grew, then dipped: total pay rose +5.0% in 2012 and +7.1% in 2013, then fell −1.4% in 2014 despite more records (+517).
- Overtime share is rising every year: from 6.32% of total pay in 2011 to 7.16% in 2014.
- Emergency services carry the pay premium: Fire & Rescue averages ~$151.7K and Police ~$120.0K per record, about 2.0x and 1.6x the overall average (~$74.8K, derived).
- Overtime is concentrated: Fire and Police together account for ~$320M of overtime, roughly 42% of all overtime in the dataset.
- Muni transit leads the overtime-to-base ratio: 9 of the top 10 job-title entries are transit roles, with overtime equal to roughly 30–44% of base pay.


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
**💡 Key Takeaways**
- Peak in 2013: payroll reached $2.92B, up +7.11% (+$193.8M) while records grew by 840.
- Dip in 2014: payroll fell −1.43% (−$41.7M) even though records grew by 517. Average pay per record dropped about 2.8%. The data alone does not explain why.
- Rising overtime share: overtime grew roughly 25.7% over 2011–2014 against about +5.4% growth in records, lifting its share of total pay from 6.32% to 7.16%.

### 🏢 Business Question 3: Which Municipal Sectors Cost the Most to Taxpayers?

* **Business Objective:** Aggregate fragmented civil service job titles into 8 primary functional sectors using pattern matching (`ILIKE`) to evaluate compensation equity, overtime reliance, and gross budgetary impact across municipal domains.

```sql
WITH sect AS (
    SELECT 
        CASE 
            WHEN job_title ILIKE '%POLICE%' OR 
                 job_title ILIKE '%SHERIFF%' OR 
                 job_title ILIKE '%SERGEANT%' THEN 'Police & Law Enforcement'
            WHEN job_title ILIKE '%FIRE%' THEN 'Fire & Rescue'
            WHEN job_title ILIKE '%NURSE%' OR
                 job_title ILIKE '%MEDICAL%' OR
                 job_title ILIKE '%HEALTH%' OR 
                 job_title ILIKE '%PHYSICIAN%' THEN 'Medical & Healthcare'
            WHEN job_title ILIKE '%TRANSIT%' OR 
                 job_title ILIKE '%OPERATOR%' OR
                 job_title ILIKE '%MECHANIC%' OR
                 job_title ILIKE '%CUSTODIAN%' OR    
                 job_title ILIKE '%MAINTENANCE%' THEN 'Transit & Public Works'
            WHEN job_title ILIKE '%ATTORNEY%' OR
                 job_title ILIKE '%COUNSEL%' OR
                 job_title ILIKE '%LEGAL%' THEN 'Legal & Judicial'
            WHEN job_title ILIKE '%RECREATION%' OR 
                 job_title ILIKE '%LIBRAR%' OR 
                 job_title ILIKE '%PARK%' THEN 'Community & Recreation'
            WHEN job_title ILIKE '%MANAGER%' OR 
                 job_title ILIKE '%DIRECTOR%' OR 
                 job_title ILIKE '%ADMINISTRATIVE%' OR 
                 job_title ILIKE '%CLERK%' OR 
                 job_title ILIKE '%ANALYST%' THEN 'Management & Admin'       
            ELSE 'Other' 
        END AS sector,
        total_pay,
        overtime_pay
    FROM sf_clean
)
SELECT 
    sector,
    COUNT(*) AS total_records,
    ROUND(AVG(total_pay), 2) AS avg_pay,
    ROUND(AVG(overtime_pay), 2) AS avg_overtime,
    ROUND(SUM(total_pay), 2) AS total_sector_spend 
FROM sect
GROUP BY sector
ORDER BY total_records DESC;
```
📊 Sector Compensation Benchmark Results:
```
Sector                      |Records	|Avg Pay         |Avg Overtime	|Total Sector Spend
"Other"	                    |63393	    |65008.56	     |2769.02	    |4120437520.19
"Medical & Healthcare"	    |20073	    |70290.68	     |2079.60	    |1410734008.57
"Transit & Public Works"	|17621	    |69118.72	     |10909.37	    |1217664497.84
"Management & Admin"	    |17424	    |74462.44	     |499.55	    |1297061184.58
"Police & Law Enforcement"	|13130	    |119967.94	     |12549.28	    |1575179096.81
"Community & Recreation"	|7737	    |34572.85	     |1422.91	    |267386457.13
"Fire & Rescue"	            |5879	    |151711.62	     |26383.32	    |891760885.18
"Legal & Judicial"	        |3397	    |98435.72	     |1648.86	    |334386135.75
```
**💡 Executive Insights:**
- Emergency services pay premium: Fire & Rescue ($151.7K avg) and Police ($120.0K avg) are the highest-paid sectors, about 2.0x and 1.6x the overall average of ~$74.8K per record.
- Overtime density in emergency services: Fire records average $26,383 in overtime (about 17.4% of average pay) and Police $12,549 (about 10.5%). Together they account for roughly $320M of overtime, around 42% of all overtime in the dataset.
- Largest spend among defined sectors: Police ($1.58B), followed by Medical & Healthcare ($1.41B). The Other bucket is larger than any of them ($4.12B, ~37% of spend), so sector results are directional rather than exact.
- Low overtime in administration: Management & Admin averages only $499.55 in overtime per record.

### 🚇 Business Question 4: Which Specific Roles Exhibit Chronic Overtime Inefficiency?

* **Business Objective:** Surface specific high-volume municipal job titles (minimum 50 recorded employees) with the highest overtime dependency ratios (`Overtime / Base Pay`) to pinpoint operational bottlenecks, understaffing, and systemic schedule mismanagement.

```sql
SELECT 
    job_title,
    COUNT(*) AS employee_count,
    ROUND(AVG(base_pay), 2) AS avg_base_pay,
    ROUND(AVG(overtime_pay), 2) AS avg_overtime_pay,
    ROUND(100 * SUM(overtime_pay) / NULLIF(SUM(base_pay), 0), 2) AS overtime_burden_pct
FROM sf_clean
GROUP BY job_title
HAVING COUNT(*) >= 50
ORDER BY overtime_burden_pct DESC
LIMIT 10;
```
📊 Top 10 Overtime-Dependent Municipal Roles:
```
Job Title	                          |Employee Count	|Avg Base 	|Avg Overtime	|Overtime Burden
"ELECTRICAL TRANSIT SYSTEM MECHANIC"  |204	            |71452.34	|31643.19	    |43.85 %
"TRANSIT POWER LINE WORKER"	          |75	            |87510.65	|33432.57	    |38.72 %
"TRAIN CONTROLLER"	                  |65	            |88167.51	|32408.12	    |36.76 %
"TRANSIT SUPERVISOR"	              |812	            |77941.73	|28266.40	    |36.27 %
"STATION AGENT, MUNICIPAL RAILWAY"	  |52	            |67222.53	|23972.48	    |35.66 %
"TRACK MAINTENANCE WORKER"	          |129	            |49306.83	|16433.41	    |34.40 %
"Station Agent, Muni Railway"	      |164	            |66841.19	|22438.57	    |34.20 %
"Electrl Trnst Mech, Asst Sprv"	      |68	            |85956.63	|28705.15	    |33.39 %
"Electrical Transit System Mech"	  |631	            |75272.25	|22437.37	    |29.90 %
"Battalion Chief, Fire Suppress"	  |65	            |179084.05	|49453.05	    |28.49 %
```
**💡 Operational Inefficiency Takeaways:**
- Muni transit concentration: 9 of the top 10 entries belong to the municipal railway and transit system (SFMTA / Muni). Their overtime equals roughly 30–44% of base pay.
- Transit Supervisors: 812 records average $28.3K in overtime, about $23M cumulatively over 2011–2014.
- Senior fire ranks: Battalion Chiefs average $49.5K in overtime on top of a $179.1K base (28.5%).
- Interpretation: a high overtime ratio is consistent with understaffing, round-the-clock coverage requirements or scheduled premiums, and this dataset cannot tell these apart. Whether converting overtime into additional full-time headcount would save money depends on benefit and hiring costs, which are not included in the overtime figures.

### 💎 Business Question 5: What Drives the Top 1% Municipal Earners: Base Pay vs. Variable Pay?

* **Business Objective:** Segment 148,650 employees into the Top 1% compensation tier versus the remaining 99% using `NTILE(100)` to dissect income inequality and evaluate whether elite earnings stem from contractual base wages or aggressive variable pay stacking (Overtime & Bonuses).

```sql
WITH presentil AS (
    SELECT 
        base_pay,
        overtime_pay,
        other_pay,
        total_pay,
        NTILE(100) OVER (ORDER BY total_pay DESC) AS ntile
    FROM sf_clean
)
SELECT 
    CASE 
        WHEN ntile = 1 THEN 'Top 1% Earners'
        ELSE 'Rest of Workforce' 
    END AS earning_tier,
    COUNT(*) AS total_records,
    ROUND(AVG(base_pay), 2) AS avg_base,
    ROUND(AVG(overtime_pay), 2) AS avg_overtime,
    ROUND(AVG(other_pay), 2) AS avg_other,
    ROUND(AVG(total_pay), 2) AS avg_total_pay,
    ROUND(100 * (AVG(overtime_pay) + AVG(other_pay)) / NULLIF(AVG(total_pay), 0), 2) AS variable_pay_pct
FROM presentil
GROUP BY 
    CASE 
        WHEN ntile = 1 THEN 'Top 1% Earners'
        ELSE 'Rest of Workforce' 
    END
ORDER BY avg_total_pay DESC;
```
📊 Top 1% vs. 99% Compensation Comparison:
```
Earning Tier	        |Headcount	|Avg Base    	|Avg Overtime	|Avg Other    |Avg Total    |Variable Pay Share
Top 1% Earners	        |1,487	    |164,431.94	    |41,183.89	    |26,265.02	  |234,202.68	|28.80 %
Rest of Workforce (99%)	|147,167	|65,340.62	    |4,709.44	    |3,469.64	  |73,198.74	|11.17 %
```
**💡 Structural Inequality Insights:**
The 3.2x Earnings Multiplier: The Top 1% municipal elite averages **
234.2K∗∗incashcompensation,earning∗∗3.2x∗∗thestandardcivicemployee(
73.2K).
Variable Pay Leverage: While base pay for the top tier is 2.5x higher than the median, their overtime earnings are 8.7x higher ($41.2K vs 4.7K)∗∗,andotherpay/bonusesare∗∗7.6xhigher(
26.3K vs $3.5K).
The Variable Pay Ceiling: Over 28.8% of the Top 1%’s compensation package is derived from variable add-ons (adding an average of $67,448 above base contract wages), proving that municipal top compensation is heavily driven by supplemental pay maximization rather than base salary alone.

### 🏥 Business Question 6: What Is the True Cost of an Employee Including Benefits (2012–2014)?

* **Business Objective:** Evaluate the municipal "benefits surcharge" (healthcare, dental, pensions) following mandatory disclosure in 2012, determining how much supplemental compensation adds on top of cash wages.

```sql
SELECT 
    year,
    COUNT(*) AS total_workers,
    ROUND(AVG(total_pay), 2) AS avg_cash_pay,
    ROUND(AVG(benefits), 2) AS avg_benefits,
    ROUND(AVG(total_pay_benefits), 2) AS avg_true_cost,
    ROUND(100.0 * AVG(benefits) / NULLIF(AVG(total_pay), 0), 2) AS benefits_load_pct,
    ROUND(SUM(benefits), 2) AS total_city_benefits,
    ROUND(SUM(benefits) - LAG(SUM(benefits)) OVER (ORDER BY year), 2) AS yoy_benefits_change
FROM sf_clean
WHERE year >= 2012
GROUP BY year
ORDER BY year;
```
📊 True Workforce Cost Breakdown (2012–2014):
```
Year	|Total Workforce	|Avg Cash	|Avg Benefits 	|Avg True	|Benefits Overhea	|Total City Benefits	|YoY Benefits Change
2012	|36,766	            |74,125.36	|26,596.17	    |100,721.53	|35.88%	            |972,089,942.84	        |null
2013	|37,606	            |77,630.02	|24,253.26	    |101,883.28	|31.24%	            |896,109,608.49	        |-75,980,334.35
2014	|38,123	            |75,475.79	|25,159.08	    |100,634.87	|33.33%	            |944,949,903.46	        |+48,840,294.97
```
**💡 Executive Insights:**
The $100K True Cost Threshold: While average base/cash earnings hover around 

26,600peremployee∗∗,pushingtheaverageannualcostofmaintainingacivilservantpast∗∗
100,000**.
The 31%–36% Surcharge: Across all departments, supplemental benefits represent a 31.2% to 35.9% surcharge on top of cash wages.
Nearly 

1BillionAnnualHealthcare/PensionBill:∗∗Totalcityexpenditureonbenefitsaloneexceeded∗∗
972M in 2012 and reached $945M in 2014, making non-wage compensation the second-largest line item in municipal budget planning.
