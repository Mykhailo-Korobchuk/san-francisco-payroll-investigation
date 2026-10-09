-- =====================================================
-- Question 1: What Are the Primary Cost Drivers of Municipal Expenditure?
-- Business Goal: Deconstruct the total $13.9B municipal compensation budget 
-- into Base Pay, Overtime, Other Pay, and Benefits to understand structural cost distribution.
-- =====================================================

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

-- =====================================================
-- Question 2: How Did Municipal Payroll Expenditure Evolve Over Time (YoY Dynamics)?
-- Business Goal: Measure annual workforce scaling, total payroll expansion, 
-- Year-over-Year (YoY) dollar change, YoY growth rate, and overtime budget dependency.
-- =====================================================

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

-- =====================================================
-- Question 3: Which Public Service Sectors Cost the Most to Taxpayers?
-- Business Goal: Classify 148k+ fragmented job titles into 8 cohesive municipal sectors 
-- using conditional pattern matching, and evaluate headcount, average earnings, overtime load, and total budget draw.
-- =====================================================

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

-- =====================================================
-- Question 4: Which Specific Job Roles Exhibit Chronic Overtime Inefficiency?
-- Business Goal: Identify high-volume municipal roles (>= 50 occurrences) with the highest 
-- overtime dependency ratio relative to base pay, highlighting understaffed operations.
-- =====================================================

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

-- =====================================================
-- Question 5: What Drives the Top 1% Municipal Earners: Base Pay vs Variable Compensation?
-- Business Goal: Segment the workforce into Top 1% vs the remaining 99% using NTILE(100) 
-- to evaluate wage inequality, base salary disparities, and reliance on variable pay.
-- =====================================================

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

-- =====================================================
-- Question 6: What Is the True Municipal Cost per Employee Including Benefits (2012–2014)?
-- Business Goal: Quantify non-wage benefits overhead, evaluate healthcare/pension 
-- expenditure scaling, and calculate the true total cost of municipal workforce.
-- =====================================================

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

