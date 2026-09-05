# B2B SaaS Customer Onboarding Causal Analysis

## Executive Summary
Using a balanced longitudinal panel of 100 enterprise accounts tracked over three fiscal years (2023–2025), this project evaluates the causal impact of subsidized technical onboarding programs on software adoption. Applying modern Staggered Difference-in-Differences (Callaway & Sant'Anna) with Doubly Robust estimation, the analysis reveals a massive immediate lift (+34.3 training hours/employee) during the subsidized year that completely decays to zero post-subsidy, demonstrating that subsidies accelerate short-term usage without creating autonomous long-term adoption habits.

## 1. Business Case

CloudMetrics, a B2B SaaS company specializing in enterprise analytics and operations infrastructure, observed persistent adoption bottlenecks among mid-market and enterprise clients. To accelerate time-to-value and ensure technical embedding, the Customer Success leadership launched a high-touch intervention: **a fully subsidized, 12-month Dedicated Technical Onboarding program**.

Due to capacity and staffing constraints within the Customer Success engineering team, the program was rolled out across accounts in staggered cohorts:
- **2023 (Baseline)**: Pure organic baseline; no enterprise accounts received dedicated onboarding.
- **2024 (Cohort 2024)**: First cohort of accounts enrolled in the subsidized onboarding program.
- **2025 (Cohort 2025)**: Second cohort of accounts enrolled in the subsidized onboarding program.
- **Never-Treated (Control)**: Accounts that relied strictly on standard self-serve technical documentation.

The executive team needs data-driven causal answers to two strategic questions:
- **Q1**: Did the subsidized onboarding program causally increase employee technical engagement and adoption?
- **Q2**: Does this adoption effect persist once the 12-month subsidy expires, or does engagement collapse back to baseline?

## 2. Data Structure

The analysis leverages a balanced panel of **100 corporate accounts** tracked consecutively over **3 fiscal periods (300 total observations)** stored in `data/saas_b2b_onboarding.csv`.

Here is a glimpse of the enterprise panel structure:

![image alt](https://github.com/GeorgeWLZD/saas_onboarding_did/blob/main/img/data_glimpse.png)

### Key Variables
- `id_cuenta_cliente`: Unique identifier for each enterprise account.
- `periodo_fiscal`: Fiscal year of observation (2023, 2024, 2025).
- `onboarding_bonificado`: Binary treatment indicator (1 if subsidized onboarding is active in that period, 0 otherwise).
- `horas_capacitacion_empleado`: Primary outcome metric ($Y$) measuring average annual technical training hours completed per licensed employee.
- `usuarios_licenciados`: Total seat license count, controlling for organizational scale.
- `facturacion_anual_cliente`: Total annual contract/sales volume, controlling for customer baseline financial size.

## 3. Econometric Methodology & Diagnostics

Because rollouts happened at different times and account enrollment was not purely random, traditional Two-Way Fixed Effects (TWFE) OLS regressions produce negative weighting biases. I implemented the **Callaway & Sant'Anna (2021) Staggered Difference-in-Differences** estimator with Doubly Robust (`dr`) estimation.

### Propensity Score Overlap & Covariate Balance (2023 Baseline)
To correct for selection bias (larger or higher-revenue accounts entering the pilot earlier), a baseline logistic regression estimated the Propensity Score across 2023 pre-treatment covariates.

Inverse Probability Weighting (IPW) was computed to verify the common support assumption between future treated accounts and never-treated accounts:

![image alt](https://github.com/GeorgeWLZD/saas_onboarding_did/blob/main/img/overlap_pscore.png)

Balance diagnostics confirmed high comparability across groups post-weighting:
- **Standardized Mean Difference (SMD) - Licensed Users**: 0.048 (< 0.1 threshold)
- **Standardized Mean Difference (SMD) - Client Revenue**: 0.062 (< 0.1 threshold)

## 4. Empirical Results

### Raw Trend Trajectories by Rollout Cohort
Aggregating unadjusted average training hours by rollout group illustrates the underlying trajectory and immediate adoption response:

![image alt](https://github.com/GeorgeWLZD/saas_onboarding_did/blob/main/img/parallel_trends_cohorts.png)

Both cohorts mirror the flat, stable pattern of the never-treated group prior to their respective intervention years, supporting the plausibility of the parallel trends assumption.

### Dynamic Event Study Estimation
Using `aggte(type = "dynamic")`, account timelines were realigned around relative event time ($e = 0$, the year dedicated onboarding goes live):

![image alt](https://github.com/GeorgeWLZD/saas_onboarding_did/blob/main/img/event_study_did.png)

| Relative Time ($e$) | Interpretation | ATT Estimate | Std. Error | 95% Confidence Interval | Statistically Significant |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **$e = -1$** | Pre-treatment Baseline Validation | **-0.85** | 1.82 | [-4.41, 2.71] | No ($p > 0.05$) |
| **$e = 0$** | Immediate Onboarding Year Impact | **+34.28** | 4.15 | [26.15, 42.41] | Yes ($p < 0.001$) |
| **$e = +1$** | Post-Subsidy Retention (Year 2) | **-1.42** | 2.94 | [-7.18, 4.34] | No ($p > 0.05$) |

### Core Empirical Findings
- **Pre-trends Validation ($e = -1$)**: The treatment effect prior to rollout is statistically indistinguishable from zero, confirming that accounts were not already trending upward before the onboarding pilot.
- **Immediate Adoption Shock ($e = 0$)**: Subsidized onboarding delivers an average boost of **+34.28 training hours per employee**, showing heavy client participation while professional services are actively provided.
- **Post-Subsidy Collapse ($e = +1$)**: One year after the subsidy expires, the incremental effect drops to **-1.42 hours** (statistically zero). Accounts immediately revert to self-serve consumption rates rather than maintaining autonomous training routines.

## 5. Business Recommendations

- **Transition Away from Full Subsidies to Shared-Cost Models**: Providing 100% free onboarding creates artificial engagement that fails to build internalized corporate habits. Implement a co-investment structure (e.g., 50% platform match) to select accounts genuinely committed to operational adoption.

- **Embed Workflow Automation Rather Than Human-Assisted Handholding**: Because dedicated consulting hours do not leave a lasting footprint, shift product development toward in-app interactive guidance, automated milestones, and role-based certifications that run independently of human consultants.

- **Introduce Gradual Ramp-Down Milestones at Month 9**: The immediate collapse in year two indicates a cliff effect when consulting contracts terminate. Establish transition playbooks in the final quarter of year one to hand off governance directly to client-side internal champions.

- **Tie Customer Success Compensation to Post-Onboarding Retention**: Realign CSM metrics so bonuses are contingent on sustained platform usage at month 18 and month 24, disincentivizing short-term usage inflation during the subsidized window.
