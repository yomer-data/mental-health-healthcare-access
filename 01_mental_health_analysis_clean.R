# ============================================================
# Project: Depressive Symptoms, Health Insurance, and
#          Mental Health Service Use Among U.S. Adults
#
# Data: NHANES 2021-2023
# Purpose: Examine associations between depressive symptom
#          severity, insurance coverage, usual source of care,
#          and mental health service use.
#
# Statistical software: R
# ============================================================


# 1. Load packages --------------------------------------------

library(haven)
library(dplyr)
library(ggplot2)
library(janitor)
library(survey)


# 2. Set project directory ------------------------------------

setwd("~/Documents/mental-health-healthcare-access")


# 3. Import NHANES datasets -----------------------------------

demo <- read_xpt("data/raw/DEMO_L.xpt")
dpq  <- read_xpt("data/raw/DPQ_L.xpt")
huq  <- read_xpt("data/raw/HUQ_L.xpt")
hiq  <- read_xpt("data/raw/HIQ_L.xpt")
# 4. Clean PHQ-9 responses and calculate total score -----------

dpq_clean <- dpq

dpq_items <- paste0(
  "DPQ",
  sprintf("%03d", seq(10, 90, 10))
)

# Keep valid responses (0-3); recode other values as missing

dpq_clean[dpq_items] <- lapply(
  dpq_clean[dpq_items],
  function(x) ifelse(x %in% 0:3, x, NA)
)

# Calculate PHQ-9 only when all nine items are answered

dpq_clean$phq9_score <- ifelse(
  rowSums(is.na(dpq_clean[dpq_items])) == 0,
  rowSums(dpq_clean[dpq_items], na.rm = TRUE),
  NA_real_
)

# Categorize symptom severity

dpq_clean$phq9_severity <- cut(
  dpq_clean$phq9_score,
  breaks = c(-1, 4, 9, 14, 19, 27),
  labels = c(
    "Minimal",
    "Mild",
    "Moderate",
    "Moderately severe",
    "Severe"
  )
)

# Check PHQ-9 results

summary(dpq_clean$phq9_score)

table(dpq_clean$phq9_severity, useNA = "ifany")
# 5. Merge NHANES datasets ------------------------------------

nhanes <- demo %>%
  left_join(dpq_clean, by = "SEQN") %>%
  left_join(huq, by = "SEQN") %>%
  left_join(hiq, by = "SEQN")

# Keep adults age 18 and older

nhanes_adult <- nhanes %>%
  filter(RIDAGEYR >= 18)

# Check merged dataset

dim(nhanes)

dim(nhanes_adult)

sum(duplicated(nhanes$SEQN))
# 6. Prepare survey design ------------------------------------

# Keep adults who participated in the Mobile Examination Center

mec_adults <- nhanes_adult %>%
  filter(WTMEC2YR > 0)

# Create analysis variables

analysis_base <- mec_adults %>%
  mutate(
    mental_health_service = case_when(
      HUQ090 == 1 ~ "Yes",
      HUQ090 == 2 ~ "No",
      TRUE ~ NA_character_
    ),

    insured = case_when(
      HIQ011 == 1 ~ "Insured",
      HIQ011 == 2 ~ "Uninsured",
      TRUE ~ NA_character_
    ),

    usual_care = case_when(
      HUQ030 == 1 ~ "One usual place",
      HUQ030 == 2 ~ "No usual place",
      HUQ030 == 3 ~ "More than one usual place",
      TRUE ~ NA_character_
    ),

    usual_care_binary = case_when(
      usual_care %in% c(
        "One usual place",
        "More than one usual place"
      ) ~ "Has usual place",

      usual_care == "No usual place" ~ "No usual place",

      TRUE ~ NA_character_
    )
  )

# Define NHANES complex survey design

nhanes_design <- survey::svydesign(
  ids = ~SDMVPSU,
  strata = ~SDMVSTRA,
  weights = ~WTMEC2YR,
  data = analysis_base,
  nest = TRUE
)

# Check survey design

summary(nhanes_design)

survey::degf(nhanes_design)
# 7. Weighted descriptive statistics -------------------------

# Distribution of PHQ-9 symptom severity

phq9_design <- subset(
  nhanes_design,
  !is.na(phq9_severity)
)

phq9_distribution <- survey::svymean(
  ~phq9_severity,
  design = phq9_design,
  na.rm = TRUE
)

print(phq9_distribution)


# Mental health service use by PHQ-9 severity

service_design <- subset(
  nhanes_design,
  !is.na(phq9_severity) &
    !is.na(mental_health_service)
)

service_by_severity <- survey::svyby(
  ~mental_health_service,
  ~phq9_severity,
  design = service_design,
  FUN = survey::svymean,
  na.rm = TRUE
)

print(service_by_severity)


# Mental health service use by insurance status

insurance_design <- subset(
  nhanes_design,
  !is.na(insured) &
    !is.na(mental_health_service)
)

service_by_insurance <- survey::svyby(
  ~mental_health_service,
  ~insured,
  design = insurance_design,
  FUN = survey::svymean,
  na.rm = TRUE
)

print(service_by_insurance)
# 8. Survey-weighted logistic regression ---------------------

# Select participants with complete data for the model

model_design <- subset(
  nhanes_design,
  !is.na(phq9_severity) &
    !is.na(mental_health_service) &
    !is.na(insured) &
    !is.na(usual_care_binary)
)

# Fit survey-weighted logistic regression

service_model_binary <- survey::svyglm(
  I(mental_health_service == "Yes") ~
    phq9_severity +
    insured +
    usual_care_binary,
  design = model_design,
  family = quasibinomial()
)

# Display model results

summary(service_model_binary)

# Calculate adjusted odds ratios and 95% confidence intervals

binary_ci <- confint(service_model_binary)

binary_results <- data.frame(
  predictor = names(coef(service_model_binary)),
  odds_ratio = exp(coef(service_model_binary)),
  lower_95 = exp(binary_ci[, 1]),
  upper_95 = exp(binary_ci[, 2]),
  p_value = coef(summary(service_model_binary))[, 4]
)

# Remove the intercept

binary_results <- binary_results[-1, ]

print(binary_results)

# Export model results

write.csv(
  binary_results,
  "outputs/tables/adjusted_logistic_regression_binary_care.csv",
  row.names = FALSE
)
# 9. Generate and save visualizations -------------------------

# Chart 1: PHQ-9 symptom severity distribution

phq9_plot_data <- data.frame(
  severity = levels(analysis_base$phq9_severity),
  percentage = 100 * as.numeric(coef(phq9_distribution))
)

phq9_plot_data$severity <- factor(
  phq9_plot_data$severity,
  levels = phq9_plot_data$severity
)

phq9_chart <- ggplot(
  phq9_plot_data,
  aes(x = severity, y = percentage)
) +
  geom_col(fill = "steelblue") +
  geom_text(
    aes(label = paste0(round(percentage, 1), "%")),
    vjust = -0.5
  ) +
  labs(
    title = "Depressive Symptom Severity Among U.S. Adults",
    subtitle = "NHANES 2021–2023 | Survey-weighted estimates",
    x = "PHQ-9 Symptom Severity",
    y = "Weighted Percentage (%)",
    caption = "PHQ-9 is a screening measure, not a clinical diagnosis."
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1)) +
  coord_cartesian(ylim = c(0, 80))

ggsave(
  "outputs/figures/phq9_severity_distribution.png",
  phq9_chart, width = 10, height = 6, dpi = 300
)


# Chart 2: Service use by symptom severity

service_plot_data <- as.data.frame(service_by_severity)

service_plot_data$percentage <-
  100 * service_plot_data$mental_health_serviceYes

service_plot_data$phq9_severity <- factor(
  service_plot_data$phq9_severity,
  levels = levels(analysis_base$phq9_severity)
)

service_chart <- ggplot(
  service_plot_data,
  aes(x = phq9_severity, y = percentage)
) +
  geom_col(fill = "darkcyan") +
  geom_text(
    aes(label = paste0(round(percentage, 1), "%")),
    vjust = -0.5
  ) +
  labs(
    title = "Mental Health Service Use by Depressive Symptom Severity",
    subtitle = "NHANES 2021–2023 | Survey-weighted estimates",
    x = "PHQ-9 Symptom Severity",
    y = "Reporting Counseling or Therapy (%)",
    caption = "Service use refers to the past 12 months."
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1)) +
  coord_cartesian(ylim = c(0, 60))

ggsave(
  "outputs/figures/service_use_by_severity.png",
  service_chart, width = 10, height = 6, dpi = 300
)


# Chart 3: Service use by insurance status

insurance_plot_data <- as.data.frame(service_by_insurance)

insurance_plot_data$percentage <-
  100 * insurance_plot_data$mental_health_serviceYes

insurance_chart <- ggplot(
  insurance_plot_data,
  aes(x = insured, y = percentage)
) +
  geom_col(fill = "slateblue") +
  geom_text(
    aes(label = paste0(round(percentage, 1), "%")),
    vjust = -0.5
  ) +
  labs(
    title = "Mental Health Service Use by Insurance Status",
    subtitle = "NHANES 2021–2023 | Survey-weighted estimates",
    x = "Current Health Insurance Status",
    y = "Reporting Counseling or Therapy (%)",
    caption = "Service use covers the past 12 months; insurance reflects current coverage."
  ) +
  theme_minimal() +
  coord_cartesian(ylim = c(0, 22))

ggsave(
  "outputs/figures/service_use_by_insurance.png",
  insurance_chart, width = 10, height = 6, dpi = 300
)


# Chart 4: Adjusted odds ratios with confidence intervals

model_plot_data <- binary_results %>%
  mutate(
    label = case_when(
      predictor == "phq9_severityMild" ~ "Mild symptoms",
      predictor == "phq9_severityModerate" ~ "Moderate symptoms",
      predictor == "phq9_severityModerately severe" ~ "Moderately severe",
      predictor == "phq9_severitySevere" ~ "Severe symptoms",
      predictor == "insuredUninsured" ~ "Uninsured",
      predictor == "usual_care_binaryNo usual place" ~ "No usual place of care",
      TRUE ~ predictor
    )
  )

model_plot_data$label <- factor(
  model_plot_data$label,
  levels = rev(model_plot_data$label)
)

model_chart <- ggplot(
  model_plot_data,
  aes(y = label)
) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
  geom_segment(
    aes(x = lower_95, xend = upper_95, yend = label)
  ) +
  geom_point(aes(x = odds_ratio), size = 3, color = "darkcyan") +
  scale_x_log10() +
  labs(
    title = "Factors Associated With Mental Health Service Use",
    subtitle = "Adjusted odds ratios with 95% confidence intervals",
    x = "Adjusted Odds Ratio (log scale)",
    y = NULL,
    caption = "Reference groups: minimal symptoms, insured, and having a usual place of care."
  ) +
  theme_minimal()

ggsave(
  "outputs/figures/adjusted_odds_ratios.png",
  model_chart, width = 11, height = 7, dpi = 300
)

# End of visualization section
