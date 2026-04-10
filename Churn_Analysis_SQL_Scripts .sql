
CREATE SCHEMA IF NOT EXISTS customer_data;


DROP TABLE IF EXISTS customer_data.customer_churn CASCADE;

CREATE TABLE customer_data.customer_churn (
    customer_id VARCHAR(20) PRIMARY KEY,
    gender VARCHAR(10),
    age INTEGER,
    married VARCHAR(5),
    state VARCHAR(50),
    number_of_referrals INTEGER,
    tenure_in_months INTEGER,
    value_deal VARCHAR(10),
    phone_service VARCHAR(5),
    multiple_lines VARCHAR(20),
    internet_service VARCHAR(5),
    internet_type VARCHAR(20),
    online_security VARCHAR(5),
    online_backup VARCHAR(5),
    device_protection_plan VARCHAR(5),
    premium_support VARCHAR(5),
    streaming_tv VARCHAR(5),
    streaming_movies VARCHAR(5),
    streaming_music VARCHAR(5),
    unlimited_data VARCHAR(5),
    contract VARCHAR(20),
    paperless_billing VARCHAR(5),
    payment_method VARCHAR(50),
    monthly_charge DECIMAL(10,2),
    total_charges DECIMAL(10,2),
    total_refunds DECIMAL(10,2),
    total_extra_data_charges DECIMAL(10,2),
    total_long_distance_charges DECIMAL(10,2),
    total_revenue DECIMAL(10,2),
    customer_status VARCHAR(20),
    churn_category VARCHAR(50),
    churn_reason VARCHAR(100)
);

SELECT COUNT(*) as total_records 
FROM customer_data.customer_churn;

-- View sample data
SELECT * 
FROM customer_data.customer_churn 
LIMIT 10;

-- Check for duplicate Customer IDs
SELECT 
    customer_id, 
    COUNT(*) as duplicate_count
FROM customer_data.customer_churn
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check NULL values in all columns
SELECT 
    COUNT(*) as total_rows,
    COUNT(*) FILTER (WHERE customer_id IS NULL) as null_customer_id,
    COUNT(*) FILTER (WHERE gender IS NULL) as null_gender,
    COUNT(*) FILTER (WHERE age IS NULL) as null_age,
    COUNT(*) FILTER (WHERE value_deal IS NULL) as null_value_deal,
    COUNT(*) FILTER (WHERE internet_type IS NULL) as null_internet_type,
    COUNT(*) FILTER (WHERE monthly_charge IS NULL) as null_monthly_charge,
    COUNT(*) FILTER (WHERE total_revenue IS NULL) as null_total_revenue
FROM customer_data.customer_churn;

-- Handle NULL values
UPDATE customer_data.customer_churn
SET value_deal = 'None'
WHERE value_deal IS NULL;

UPDATE customer_data.customer_churn
SET internet_type = 'None'
WHERE internet_type IS NULL;

-- Add calculated columns
ALTER TABLE customer_data.customer_churn
ADD COLUMN IF NOT EXISTS profit_margin DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS revenue_category VARCHAR(20),
ADD COLUMN IF NOT EXISTS tenure_category VARCHAR(20),
ADD COLUMN IF NOT EXISTS age_group VARCHAR(20);

-- Calculate profit margin
UPDATE customer_data.customer_churn
SET profit_margin = CASE 
    WHEN total_revenue > 0 THEN 
        ((total_revenue - total_refunds - total_extra_data_charges - total_long_distance_charges) / total_revenue) * 100
    ELSE 0 
END;

-- Categorize revenue
UPDATE customer_data.customer_churn
SET revenue_category = CASE
    WHEN total_revenue >= 5000 THEN 'High Value'
    WHEN total_revenue >= 2000 THEN 'Medium Value'
    ELSE 'Low Value'
END;

-- Categorize tenure
UPDATE customer_data.customer_churn
SET tenure_category = CASE
    WHEN tenure_in_months >= 36 THEN 'Long-term'
    WHEN tenure_in_months >= 12 THEN 'Medium-term'
    ELSE 'Short-term'
END;

-- Create age groups
UPDATE customer_data.customer_churn
SET age_group = CASE
    WHEN age < 30 THEN '18-29'
    WHEN age < 45 THEN '30-44'
    WHEN age < 60 THEN '45-59'
    ELSE '60+'
END;

-- Verify transformations
SELECT 
    revenue_category,
    tenure_category,
    age_group,
    COUNT(*) as customer_count
FROM customer_data.customer_churn
GROUP BY revenue_category, tenure_category, age_group
ORDER BY revenue_category, tenure_category, age_group;


-- View 1: Overall Business Metrics
CREATE OR REPLACE VIEW customer_data.vw_business_metrics AS
SELECT 
    COUNT(DISTINCT customer_id) as total_customers,
    SUM(total_revenue) as total_revenue,
    AVG(total_revenue) as avg_revenue_per_customer,
    SUM(total_charges) as total_charges,
    SUM(total_refunds) as total_refunds,
    AVG(profit_margin) as avg_profit_margin,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_customers,
    COUNT(CASE WHEN customer_status = 'Stayed' THEN 1 END) as retained_customers,
    ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          COUNT(*)::NUMERIC * 100, 2) as churn_rate
FROM customer_data.customer_churn;

-- View 2: Revenue by Category
CREATE OR REPLACE VIEW customer_data.vw_revenue_by_category AS
SELECT 
    revenue_category,
    COUNT(*) as customer_count,
    SUM(total_revenue) as total_revenue,
    AVG(total_revenue) as avg_revenue,
    ROUND(SUM(total_revenue) / (SELECT SUM(total_revenue) FROM customer_data.customer_churn) * 100, 2) as revenue_percentage
FROM customer_data.customer_churn
GROUP BY revenue_category
ORDER BY total_revenue DESC;

-- View 3: Churn Analysis by State
CREATE OR REPLACE VIEW customer_data.vw_churn_by_state AS
SELECT 
    state,
    COUNT(*) as total_customers,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_customers,
    ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          COUNT(*)::NUMERIC * 100, 2) as churn_rate,
    SUM(total_revenue) as total_revenue,
    AVG(monthly_charge) as avg_monthly_charge
FROM customer_data.customer_churn
GROUP BY state
ORDER BY churn_rate DESC;

-- View 4: Top Revenue Drivers (Top 20% using NTILE)
CREATE OR REPLACE VIEW customer_data.vw_top_revenue_drivers AS
WITH ranked_customers AS (
    SELECT 
        customer_id,
        total_revenue,
        customer_status,
        state,
        contract,
        monthly_charge,
        tenure_in_months,
        NTILE(5) OVER (ORDER BY total_revenue DESC) as revenue_quintile
    FROM customer_data.customer_churn
)
SELECT 
    customer_id,
    total_revenue,
    customer_status,
    state,
    contract,
    monthly_charge,
    tenure_in_months
FROM ranked_customers
WHERE revenue_quintile = 1
ORDER BY total_revenue DESC;

-- View 5: Tenure Revenue Trend
CREATE OR REPLACE VIEW customer_data.vw_tenure_revenue_trend AS
SELECT 
    tenure_category,
    COUNT(*) as customer_count,
    SUM(total_revenue) as total_revenue,
    AVG(monthly_charge) as avg_monthly_charge,
    AVG(profit_margin) as avg_profit_margin,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_count
FROM customer_data.customer_churn
GROUP BY tenure_category
ORDER BY 
    CASE tenure_category
        WHEN 'Short-term' THEN 1
        WHEN 'Medium-term' THEN 2
        WHEN 'Long-term' THEN 3
    END;

-- View 6: Churn Reasons Analysis
CREATE OR REPLACE VIEW customer_data.vw_churn_reasons AS
SELECT 
    churn_category,
    churn_reason,
    COUNT(*) as customer_count,
    SUM(total_revenue) as lost_revenue,
    ROUND(AVG(tenure_in_months), 1) as avg_tenure_months,
    AVG(monthly_charge) as avg_monthly_charge
FROM customer_data.customer_churn
WHERE customer_status = 'Churned'
GROUP BY churn_category, churn_reason
ORDER BY customer_count DESC;

-- View 7: Customer Segmentation
CREATE OR REPLACE VIEW customer_data.vw_customer_segmentation AS
SELECT 
    age_group,
    gender,
    revenue_category,
    COUNT(*) as customer_count,
    SUM(total_revenue) as total_revenue,
    ROUND(AVG(profit_margin), 2) as avg_profit_margin,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_count,
    ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          COUNT(*)::NUMERIC * 100, 2) as segment_churn_rate
FROM customer_data.customer_churn
GROUP BY age_group, gender, revenue_category
ORDER BY total_revenue DESC;

-- View 8: Contract Type Performance
CREATE OR REPLACE VIEW customer_data.vw_contract_performance AS
SELECT 
    contract,
    COUNT(*) as customer_count,
    SUM(total_revenue) as total_revenue,
    AVG(monthly_charge) as avg_monthly_charge,
    AVG(tenure_in_months) as avg_tenure_months,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_count,
    ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          COUNT(*)::NUMERIC * 100, 2) as churn_rate
FROM customer_data.customer_churn
GROUP BY contract
ORDER BY churn_rate;

-- View 9: Customer Cohort Analysis using CTEs
CREATE OR REPLACE VIEW customer_data.vw_cohort_analysis AS
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        total_revenue,
        tenure_in_months,
        customer_status,
        CASE 
            WHEN tenure_in_months <= 6 THEN '0-6 months'
            WHEN tenure_in_months <= 12 THEN '7-12 months'
            WHEN tenure_in_months <= 24 THEN '13-24 months'
            ELSE '25+ months'
        END as cohort
    FROM customer_data.customer_churn
),
cohort_stats AS (
    SELECT 
        cohort,
        COUNT(*) as customer_count,
        SUM(total_revenue) as total_revenue,
        AVG(total_revenue) as avg_revenue,
        MIN(total_revenue) as min_revenue,
        MAX(total_revenue) as max_revenue,
        STDDEV(total_revenue) as stddev_revenue,
        COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_count
    FROM customer_cohorts
    GROUP BY cohort
)
SELECT 
    cohort,
    customer_count,
    total_revenue,
    ROUND(avg_revenue, 2) as avg_revenue,
    ROUND(min_revenue, 2) as min_revenue,
    ROUND(max_revenue, 2) as max_revenue,
    ROUND(stddev_revenue, 2) as stddev_revenue,
    churned_count,
    ROUND(churned_count::NUMERIC / customer_count::NUMERIC * 100, 2) as churn_rate
FROM cohort_stats
ORDER BY 
    CASE cohort
        WHEN '0-6 months' THEN 1
        WHEN '7-12 months' THEN 2
        WHEN '13-24 months' THEN 3
        ELSE 4
    END;

-- View 10: Running Total and Moving Average using Window Functions
CREATE OR REPLACE VIEW customer_data.vw_revenue_trends AS
WITH ordered_customers AS (
    SELECT 
        customer_id,
        tenure_in_months,
        monthly_charge,
        total_revenue,
        customer_status,
        ROW_NUMBER() OVER (ORDER BY tenure_in_months, customer_id) as row_num
    FROM customer_data.customer_churn
)
SELECT 
    customer_id,
    tenure_in_months,
    monthly_charge,
    total_revenue,
    customer_status,
    SUM(monthly_charge) OVER (ORDER BY row_num ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total,
    AVG(monthly_charge) OVER (ORDER BY row_num ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as moving_avg_3m,
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) as revenue_dense_rank,
    NTILE(10) OVER (ORDER BY total_revenue DESC) as revenue_decile,
    PERCENT_RANK() OVER (ORDER BY total_revenue) as revenue_percentile
FROM ordered_customers;

-- View 11: Churn Risk Score using Multiple Criteria
CREATE OR REPLACE VIEW customer_data.vw_churn_risk_score AS
SELECT 
    customer_id,
    tenure_in_months,
    monthly_charge,
    total_revenue,
    customer_status,
    contract,
    number_of_referrals,
    -- Calculate risk score based on multiple factors
    (CASE WHEN tenure_in_months < 12 THEN 30 ELSE 0 END +
     CASE WHEN contract = 'Month-to-Month' THEN 25 ELSE 0 END +
     CASE WHEN paperless_billing = 'Yes' THEN 10 ELSE 0 END +
     CASE WHEN payment_method = 'Bank Withdrawal' THEN 15 ELSE 0 END +
     CASE WHEN number_of_referrals = 0 THEN 20 ELSE 0 END) as churn_risk_score,
    -- Revenue percentile
    PERCENT_RANK() OVER (ORDER BY total_revenue DESC) * 100 as revenue_percentile,
    -- Tenure quartile
    NTILE(4) OVER (ORDER BY tenure_in_months) as tenure_quartile,
    -- Customer rank by value
    ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as customer_value_rank
FROM customer_data.customer_churn;

-- View 12: Customer Value Segmentation (RFM-like)
CREATE OR REPLACE VIEW customer_data.vw_customer_value_segmentation AS
WITH customer_scores AS (
    SELECT 
        customer_id,
        total_revenue,
        tenure_in_months,
        monthly_charge,
        customer_status,
        state,
        -- Score each dimension on 1-5 scale
        NTILE(5) OVER (ORDER BY total_revenue DESC) as revenue_score,
        NTILE(5) OVER (ORDER BY tenure_in_months DESC) as tenure_score,
        NTILE(5) OVER (ORDER BY monthly_charge DESC) as engagement_score
    FROM customer_data.customer_churn
),
scored_customers AS (
    SELECT 
        customer_id,
        total_revenue,
        tenure_in_months,
        monthly_charge,
        customer_status,
        state,
        revenue_score,
        tenure_score,
        engagement_score,
        ROUND((revenue_score + tenure_score + engagement_score) / 3.0, 2) as overall_value_score
    FROM customer_scores
)
SELECT 
    customer_id,
    total_revenue,
    tenure_in_months,
    monthly_charge,
    customer_status,
    state,
    revenue_score,
    tenure_score,
    engagement_score,
    overall_value_score,
    CASE 
        WHEN overall_value_score >= 4.0 THEN 'Champions'
        WHEN overall_value_score >= 3.0 THEN 'Loyal Customers'
        WHEN overall_value_score >= 2.0 THEN 'Potential Loyalists'
        ELSE 'At Risk'
    END as value_segment
FROM scored_customers
ORDER BY overall_value_score DESC;

-- View 13: Service Adoption Analysis
CREATE OR REPLACE VIEW customer_data.vw_service_adoption AS
SELECT 
    customer_id,
    -- Count of services adopted
    (CASE WHEN phone_service = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN internet_service = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN online_security = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN online_backup = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN device_protection_plan = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN premium_support = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN streaming_tv = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN streaming_movies = 'Yes' THEN 1 ELSE 0 END +
     CASE WHEN streaming_music = 'Yes' THEN 1 ELSE 0 END) as total_services,
    total_revenue,
    customer_status,
    tenure_in_months
FROM customer_data.customer_churn;

-- View 14: Service Adoption Summary
CREATE OR REPLACE VIEW customer_data.vw_service_adoption_summary AS
SELECT 
    total_services,
    COUNT(*) as customer_count,
    AVG(total_revenue) as avg_revenue,
    COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END) as churned_count,
    ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          COUNT(*)::NUMERIC * 100, 2) as churn_rate
FROM customer_data.vw_service_adoption
GROUP BY total_services
ORDER BY total_services;

-- Test all views
SELECT 'vw_business_metrics' as view_name, COUNT(*) as row_count FROM customer_data.vw_business_metrics
UNION ALL
SELECT 'vw_revenue_by_category', COUNT(*) FROM customer_data.vw_revenue_by_category
UNION ALL
SELECT 'vw_churn_by_state', COUNT(*) FROM customer_data.vw_churn_by_state
UNION ALL
SELECT 'vw_top_revenue_drivers', COUNT(*) FROM customer_data.vw_top_revenue_drivers
UNION ALL
SELECT 'vw_tenure_revenue_trend', COUNT(*) FROM customer_data.vw_tenure_revenue_trend
UNION ALL
SELECT 'vw_churn_reasons', COUNT(*) FROM customer_data.vw_churn_reasons
UNION ALL
SELECT 'vw_customer_segmentation', COUNT(*) FROM customer_data.vw_customer_segmentation
UNION ALL
SELECT 'vw_contract_performance', COUNT(*) FROM customer_data.vw_contract_performance
UNION ALL
SELECT 'vw_cohort_analysis', COUNT(*) FROM customer_data.vw_cohort_analysis
UNION ALL
SELECT 'vw_revenue_trends', COUNT(*) FROM customer_data.vw_revenue_trends
UNION ALL
SELECT 'vw_churn_risk_score', COUNT(*) FROM customer_data.vw_churn_risk_score
UNION ALL
SELECT 'vw_customer_value_segmentation', COUNT(*) FROM customer_data.vw_customer_value_segmentation
UNION ALL
SELECT 'vw_service_adoption', COUNT(*) FROM customer_data.vw_service_adoption
UNION ALL
SELECT 'vw_service_adoption_summary', COUNT(*) FROM customer_data.vw_service_adoption_summary;

-- Quick KPI Summary
SELECT 
    'Total Customers' as metric,
    COUNT(*)::TEXT as value
FROM customer_data.customer_churn
UNION ALL
SELECT 
    'Total Revenue',
    CONCAT('$', ROUND(SUM(total_revenue), 2))
FROM customer_data.customer_churn
UNION ALL
SELECT 
    'Churn Rate',
    CONCAT(ROUND(COUNT(CASE WHEN customer_status = 'Churned' THEN 1 END)::NUMERIC / 
          COUNT(*)::NUMERIC * 100, 2), '%')
FROM customer_data.customer_churn
UNION ALL
SELECT 
    'Avg Revenue per Customer',
    CONCAT('$', ROUND(AVG(total_revenue), 2))
FROM customer_data.customer_churn;