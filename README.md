# Depressive Symptoms, Health Insurance, and Mental Health Service Use Among U.S. Adults

## Project Overview

This project examines the relationship between depressive symptom severity, health insurance coverage, usual source of healthcare, and mental health service use among U.S. adults.

Using data from the National Health and Nutrition Examination Survey (NHANES) 2021–2023, the analysis explores patterns in mental health service use and healthcare access.

## Research Questions

1. How does mental health service use vary by depressive symptom severity?
2. Does mental health service use differ by health insurance status?
3. Is having a usual source of healthcare associated with mental health service use?

## Data Source

National Health and Nutrition Examination Survey (NHANES), 2021–2023.

Data files used:
- Demographics (DEMO_L)
- Depression Screener (DPQ_L)
- Health Care Utilization (HUQ_L)
- Health Insurance (HIQ_L)

Source: https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx?Cycle=2021-2023

## Methods

- Adult participants aged 18 and older
- PHQ-9 depressive symptom scoring and severity categories
- Survey-weighted descriptive statistics
- Survey-weighted logistic regression
- NHANES sampling weights, strata, and primary sampling units

The adjusted regression model included 5,430 participants with complete data.

## Key Findings

- Approximately 32.7% of adults had at least mild depressive symptoms.
- Mental health service use increased with depressive symptom severity.
- Adults with severe symptoms had 9.22 times the adjusted odds of service use compared with adults with minimal symptoms.
- Uninsured adults had approximately 46% lower adjusted odds of mental health service use than insured adults.
- Adults without a usual source of care had approximately 42% lower adjusted odds of service use.

These findings represent associations, not causal relationships.

## Tools

- R
- RStudio
- Quarto
- Plotly
- dplyr
- survey
- haven
- ggplot2

## Project Deliverables

- Interactive Quarto dashboard
- Research report
- Reproducible R analysis script
- Data preparation and analysis outputs
- Visualizations and regression tables

## Limitations

This analysis uses cross-sectional survey data and self-reported measures. The PHQ-9 is a screening instrument, not a clinical diagnosis. Current insurance status and past-year service use have different reference periods.

## Author

Yusuf H. Omer