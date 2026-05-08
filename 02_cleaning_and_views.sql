-- Clean View for Users
CREATE OR REPLACE VIEW vw_clean_users AS
SELECT 
    user_id,
    signup_date,
    -- This CASE statement standardizes the country names
    CASE 
        WHEN country IN ('DE', 'Deutschland', 'DEU', 'Ger') THEN 'Germany'
        WHEN country IN ('FR') THEN 'France'
        WHEN country IN ('UK', 'United Kingdom') THEN 'UK'
        WHEN country IN ('USA', 'US', 'United States') THEN 'USA'
        ELSE country 
    END AS country_clean,
    marketing_channel
FROM users;

-- Quick check to see if it worked
SELECT DISTINCT country_clean FROM vw_clean_users;


-- Clean View for Subscriptions
CREATE OR REPLACE VIEW vw_clean_subscriptions AS
SELECT 
    sub_id,
    user_id,
    plan_type,
    start_date,	
    -- If end_date is NULL, it means they are still active. 
    end_date,
    LOWER(status) AS status_clean
FROM subscriptions;

-- Quick check:
SELECT DISTINCT status_clean FROM vw_clean_subscriptions;

-- Clean View for Transactions
CREATE OR REPLACE VIEW vw_clean_transactions AS
WITH cte_dedup AS (
    SELECT *,
           -- This assigns a '1' to the first record and '2' to duplicates
           ROW_NUMBER() OVER (
               PARTITION BY sub_id, payment_date, amount_eur 
               ORDER BY transaction_id
           ) as row_num
    FROM transactions
    WHERE payment_status = 'Success'
)
SELECT 
    transaction_id,
    sub_id,
    amount_eur,
    payment_date
FROM cte_dedup
WHERE row_num = 1; -- To remove the duplicates

-- Quick check:
SELECT COUNT(*) FROM transactions WHERE payment_status = 'Success';

SELECT COUNT(*) FROM vw_clean_transactions;

-- Monthly Recurring Revenue (MRR) Report
DROP VIEW IF EXISTS vw_mrr_report;

CREATE VIEW vw_mrr_report AS
SELECT 
    DATE_TRUNC('month', t.payment_date)::DATE AS revenue_month,
    u.country_clean, 
    COUNT(DISTINCT t.sub_id) AS active_subscribers,
    SUM(t.amount_eur) AS total_mrr
FROM vw_clean_transactions t
JOIN vw_clean_subscriptions s ON t.sub_id = s.sub_id
JOIN vw_clean_users u ON s.user_id = u.user_id
GROUP BY 1, 2
ORDER BY 1;

-- Quick check:
SELECT * FROM vw_mrr_report;

-- Churn Analysis: Who is staying and who is leaving?
DROP VIEW IF EXISTS vw_churn_report;

CREATE VIEW vw_churn_report AS
SELECT 
    u.marketing_channel,
    u.country_clean, 
    COUNT(u.user_id) AS total_customers,
    COUNT(s.end_date) AS churned_customers,
    ROUND((COUNT(s.end_date)::DECIMAL / COUNT(u.user_id)) * 100, 2) AS churn_rate_pct
FROM vw_clean_users u
JOIN vw_clean_subscriptions s ON u.user_id = s.user_id
GROUP BY 1, 2
ORDER BY churn_rate_pct DESC;

-- Quick check:
SELECT * FROM vw_churn_report;

-- Average Revenue Per User (ARPU) by Country
CREATE OR REPLACE VIEW vw_country_performance AS
SELECT 
    u.country_clean,
    SUM(t.amount_eur) AS total_revenue,
    COUNT(DISTINCT u.user_id) AS unique_customers,
    ROUND(SUM(t.amount_eur) / COUNT(DISTINCT u.user_id), 2) AS arpu
FROM vw_clean_users u
JOIN vw_clean_subscriptions s ON u.user_id = s.user_id
JOIN vw_clean_transactions t ON s.sub_id = t.sub_id
GROUP BY 1
ORDER BY total_revenue DESC;

-- Quick check:
SELECT * FROM vw_country_performance;


-- Final Audit for GitHub Report
SELECT 
    'Global' as metric_scope,
    (SELECT SUM(amount_eur) FROM vw_clean_transactions) as total_lifetime_revenue,
    (SELECT ROUND(AVG(arpu), 2) FROM vw_country_performance) as average_arpu,
    (SELECT MAX(total_mrr) FROM vw_mrr_report) as peak_monthly_revenue,
    (SELECT ROUND(AVG(churn_rate_pct), 2) FROM vw_churn_report) as avg_churn_rate
UNION ALL
SELECT 
    country_clean,
    total_revenue,
    arpu,
    NULL, -- Peaks are harder to split here
    NULL
FROM vw_country_performance;
