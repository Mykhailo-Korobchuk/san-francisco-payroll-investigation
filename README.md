# 🏛️ San Francisco Municipal Payroll & Overtime Analysis

An end-to-end compensation analysis of 148,650 public payroll records (2011–2014, ~$2.6–2.9B annual payroll excluding benefits) for the City and County of San Francisco.

The project covers the full analytics lifecycle: raw data profiling, cleaning and transformation in Power Query, staging-to-production modeling in PostgreSQL, and SQL analysis (cost structure, year-over-year dynamics).

**Tech Stack:** `Power Query` · `PostgreSQL 18` · `pgAdmin 4` · `SQL` (CTEs, window functions `LAG` / `NTILE`, `CASE`, `ILIKE`)

---

## 📌 Executive Summary & Key Findings

- **Base pay dominates cost:** base wages are 70.5% of total compensation (pay + benefits, 2011–2014), benefits 20.2%, overtime 5.4%, other pay 3.9%. Benefits are reported only for 2012–2014, where they make up about 24.8% of the total.
- **Payroll grew, then dipped:** cash pay rose 5.0% in 2012 and 7.1% in 2013, then fell 1.4% in 2014 despite 517 more records.
- **Overtime share keeps rising:** from 6.32% of cash pay in 2011 to 7.16% in 2014 (2012→2013 is almost flat: 6.78% → 6.81%).
- **Emergency services carry the pay premium:** Fire & Rescue averages ≈$151.7K and Police ≈$120.0K per record, about 2.0x and 1.6x the overall average of ≈$74.8K (derived; job groups are keyword-based).
- **Overtime is concentrated:** Fire and Police together account for ≈$320M of overtime, roughly 42% of the total, while making up only about 13% of records.
- **Muni transit leads the overtime-to-base ratio:** 9 of the top 10 job-title entries are transit roles (some are spelling variants of the same role), with overtime equal to roughly 30–44% of base pay.
- **Top 1% earners average 3.2x the rest:** about 70% of their pay is base wages, but variable pay (overtime + other pay) makes up 28.8% of it versus 11.2% for everyone else.
- **True cost of a record is ≈$100–102K:** benefits add 31–36% on top of cash pay in 2012–2014.
- **Only 3 records exceed $500K:** 70–75% of their package is non-base, mainly Other Pay (and overtime in one case). Ranks 4–10 are mostly high base salaries ($257K–$319K) and include repeat officials.


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
| Metric | Value | Notes |
|---|---|---|
| Raw rows | 148,654 | Kaggle dataset `Salaries.csv` |
| Raw columns | 13 | Initial schema |
| Columns dropped | 3 | `Notes` (100% empty), `Status` (100% empty), `Agency` (single value: "San Francisco") |
| Columns kept | 10 | |
| Anomalous values found | 3,420 | Non-numeric entries, whitespace-only strings, and `Not Provided` |
| Anomalous values handled | 3,420 | Replaced with SQL `NULL` so the rows stay in the dataset |
| Rows removed | 4 |
| Final rows | 148,650 | Loaded into PostgreSQL |

Text fields `EmployeeName` and `JobTitle` were also trimmed of leading and trailing whitespace (`Text.Trim`).

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

### 📊 Business Question 1: What Are the Main Components of Payroll Cost?

**Business objective:** break total 2011–2014 compensation into Base Pay, Overtime, Other Pay and Benefits to see how payroll spend is distributed. Note: benefits are reported only for 2012–2014, so their share here is understated.

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


|Component	    |Total (USD)	    |Share of grand total|
|---------------|-------------------|--------------------|
|Base Pay	    |9,819,150,982.31	|70.50%              |
|Overtime	    |753,066,596.98 	|5.41%               |
|Other Pay	    |542,370,270.97	    |3.89%               |
|Benefits	    |2,813,149,454.79	|20.20%              |
|Grand Total	|13,927,772,712.41	|100%                |

*Components sum to $13,927,737,305.05, about $35K (0.0003%) below the grand total, most likely due to NULLs.*

**💡 Analytical Takeaways**

- **Base pay dominates:** base wages are 70.5% of total cost and benefits 20.2% ($2.81B). Benefits are missing for 2011, so for 2012–2014 alone their share is higher (about 24.8%).
- **Variable compensation:** overtime plus other pay is 9.3% ($1.295B) of total spending. Overtime ($753M) exceeds other pay ($542M).

### 📈 Business Question 2: How Did Payroll Evolve Over Time?

**Business objective:** track record counts, annual dollar change and year-over-year growth in cash pay (`total_pay`, excluding benefits) for 2011–2014. All figures are nominal, not adjusted for inflation.

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

|Year	|Records	|Total Payroll	|Prev Year Payroll |YoY Change  	 |Growth %	    | Overtime Share*|
|-------|-----------|---------------|------------------|-----------------|--------------|----------------|
|2011	|36159	    |2594194970.89	|			       |                 |              | 6.32 %         |
|2012	|36766	    |2724848116.46	|2594194970.89	   |130653145.57	 |5.04 %        | 6.78 %         |
|2013	|37606	    |2918655824.83	|2724848116.46	   |193807708.37	 |7.11 %        | 6.81 %         |
|2014	|38123	    |2876910873.87	|2918655824.83	   |-41744950.96	 |-1.43	%       | 7.16 %         |

*Overtime share is overtime as a percentage of cash pay (benefits excluded).*

**💡 Key Takeaways**
- **Peak in 2013:** payroll reached $2.92B, the highest of the four years, up 7.11% (+$193.8M) while records grew by 840.
- **Dip in 2014:** payroll fell 1.43% (−$41.7M) even though records grew by 517. Average pay per record dropped about 2.8% (from ≈$77.6K to ≈$75.5K). The data alone does not explain why.
- **Overtime share trends up:** overtime grew roughly 25.7% over 2011–2014 against about 5.4% growth in records, lifting its share of cash pay from 6.32% to 7.16%. The increase is uneven: 2012→2013 is almost flat (6.78% → 6.81%).

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
**💡 Pay Concentration Insights**
- 3.2x multiplier: the top 1% averages $234.2K in total pay versus $73.2K for the rest.
- Where the gap comes from: of the roughly $158K difference in average component pay, about 63% is base pay ($99.1K), 23% overtime ($36.5K) and 14% other pay ($22.8K). Base pay of the top tier is 2.5x the rest-of-workforce average, so top earners are largely better-paid on contract wages too.
- Variable pay leverage: overtime is 8.7x and other pay 7.6x higher than for the rest of the workforce ($41.2K vs $4.7K and $26.3K vs $3.5K). Variable pay makes up 28.8% of top-tier pay (about $67.4K above base) versus 11.2% for everyone else.
- Open question: the data shows composition, not who these workers are. A job-title breakdown of the top tier is the natural next step.

### 🏥 Business Question 6: What Is the True Cost of an Employee Including Benefits (2012–2014)?

**Business Objective:** Evaluate the municipal "benefits surcharge" (healthcare, dental, pensions) following mandatory disclosure in 2012, determining how much supplemental compensation adds on top of cash wages.

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
**💡 Executive Insights**
- ~$100K true cost: adding benefits pushes the average annual cost of a payroll record to $100.6K–$101.9K, against $74.1K–$77.6K in cash pay.
- 31%–36% benefits load: benefits add $24.3K–$26.6K on average, a 31.2% to 35.9% surcharge on cash pay.
- $0.9–1.0B per year: total city spend on benefits was $972M in 2012, $896M in 2013 and $945M in 2014. Benefits are the second-largest component of total compensation after base pay.
- Volatile 2013–2014: total benefits fell 7.8% in 2013 (−$76.0M) even though cash payroll rose 7.1%, then rebounded +5.4% in 2014 (+$48.8M). The data does not explain why.


### 🏆 Business Question 7: Who Are the Top 10 Most Expensive Employees for Taxpayers?

* **Business Objective:** Surface the ten highest Total Compensation packages in San Francisco history and deconstruct their pay architecture into contractual Base Pay, Overtime, Other Pay (stipends/severance), and Benefits.

```sql
SELECT 
    employee_name,
    job_title,
    year,
    base_pay,
    overtime_pay,
    other_pay,
    benefits,
    total_pay_benefits,
    ROUND(
        (100.0 * (total_pay_benefits - base_pay) / NULLIF(total_pay_benefits, 0)), 
        2
    ) AS non_base_pct
FROM sf_clean
WHERE total_pay_benefits IS NOT NULL
ORDER BY total_pay_benefits DESC
LIMIT 10;
```
📊 Top 10 All-Time Highest Total Compensation Packages:
```
Employee Name	         |Job Title	                                        |Year	|Base	   |Overtime  |Other	  |Benefits	|Compensation |Non-Base
"NATHANIEL FORD"	     |"GENERAL MANAGER-METROPOLITAN TRANSIT AUTHORITY"	|2011	|167411.18 |0	      |400184.25  |null     |567595.43	  |70.51
"GARY JIMENEZ"	         |"CAPTAIN III (POLICE DEPARTMENT)"	                |2011	|155966.02 |245131.88 |137811.38  |null     |538909.28	  |71.06
"DAVID SHINN"	         |"Deputy Chief 3"	                                |2014	|129150.01 |0	      |342802.63  |38780.04	|510732.68	  |74.71
"Amy P Hart"	         |"Asst Med Examiner"	                            |2014	|318835.49 |10712.95  |60563.54	  |89540.23	|479652.21	  |33.53
"William J Coaker Jr."	 |"Chief Investment Officer"	                    |2014	|257340	   |0	      |82313.7	  |96570.66	|436224.36	  |41.01
"Gregory P Suhr"	     |"CHIEF OF POLICE"	                                |2013	|319275.01 |0	      |20007.06	  |86533.21	|425815.28	  |25.02
"Joanne M Hayes-White"	 |"Chief, Fire Department"	                        |2013	|313686.01 |0	      |23236	  |85431.39	|422353.4	  |25.73
"Gregory P Suhr"	     |"CHIEF OF POLICE"	                                |2014	|307450.04 |0	      |19266.72	  |91302.46	|418019.22	  |26.45
"Joanne M Hayes-White"	 |"Chief, Fire Department"	                        |2014	|302068	   |0	      |24165.44	  |91201.66	|417435.1	  |27.64
"Ellen G Moffatt"	     |"Asst Med Examiner"	                            |2014	|270222.04 |6009.22	  |67956.2	  |71580.48	|415767.94	  |35.01
```
**💡 Executive Insights**
- Only 3 records exceed $500K: Ford (2011), Jimenez (2011) and Shinn (2014). For them, non-base compensation is 70.5%–74.7% of the package.
- Other Pay drives the top two single-source outliers: Ford's $400.2K and Shinn's $342.8K in Other Pay are far above their base pay. The dataset does not itemize what Other Pay contains (it can include lump-sum payouts), so the cause cannot be determined from the data.
- Overtime outlier: Jimenez earned $245.1K in overtime and $137.8K in other pay on a $156.0K base, so his total is about 3.5x his base pay.
- Ranks 4–10 are base-driven: base pay of $257K–$319K plus benefits of $72K–$97K, with non-base shares of 25%–41%. These are senior leadership and medical positions.
- Repeat entries: the same senior officials recur across 2013 and 2014, a reminder that record-level rankings can overstate how many people are at the top.
