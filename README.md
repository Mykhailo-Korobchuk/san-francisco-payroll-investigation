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
