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


