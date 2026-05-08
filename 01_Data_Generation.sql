-- 1. To wipe old data to start fresh
TRUNCATE transactions, subscriptions, users RESTART IDENTITY CASCADE;

-- 2. Generate 100 Users with Dirty Countries
INSERT INTO users (user_id, signup_date, country, marketing_channel)
SELECT 
    s.id,
    CURRENT_DATE - (random() * 365)::int, 
    (ARRAY['Germany', 'DE', 'Deutschland', 'France', 'FR', 'UK', 'United Kingdom', 'USA'])[floor(random() * 8 + 1)],
    (ARRAY['Google Ads', 'Social Media', 'Organic', 'Affiliate'])[floor(random() * 4 + 1)]
FROM generate_series(1, 100) AS s(id);

-- 3. Generate Subscriptions 
INSERT INTO subscriptions (sub_id, user_id, plan_type, start_date, end_date, status)
SELECT 
    u.user_id + 100,
    u.user_id,
    (ARRAY['Basic', 'Pro', 'Enterprise'])[floor(random() * 3 + 1)],
    u.signup_date,
    CASE WHEN random() < 0.2 THEN u.signup_date + interval '3 months' ELSE NULL END, 
    (ARRAY['active', 'Active', 'CANCELLED', 'expired', 'Active_User'])[floor(random() * 5 + 1)]
FROM users u;

-- 4. Generate Transactions
INSERT INTO transactions (transaction_id, sub_id, amount_eur, payment_date, payment_status)
SELECT 
    row_number() OVER (),
    sub_id,
    CASE WHEN plan_type = 'Basic' THEN 9.99 WHEN plan_type = 'Pro' THEN 29.99 ELSE 99.99 END,
    start_date + (m || ' month')::interval,
    (ARRAY['Success', 'Success', 'Success', 'Failed', 'Pending'])[floor(random() * 5 + 1)]
FROM subscriptions
CROSS JOIN generate_series(0, 3) AS m;

-- 5. Injecting errors
-- This creates 15 double-billing rows
INSERT INTO transactions 
SELECT transaction_id + 5000, sub_id, amount_eur, payment_date, 'Success'
FROM transactions 
WHERE payment_status = 'Success'
LIMIT 15;
-- to verify data:
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM transactions;

SELECT sub_id, payment_date, COUNT(*) 
FROM transactions 
WHERE payment_status = 'Success'
GROUP BY sub_id, payment_date 
HAVING COUNT(*) > 1;


-- To see  users 
SELECT * FROM users LIMIT 10;

-- To see the subscription plans
SELECT * FROM subscriptions LIMIT 10;

-- To ee the payments (Check for duplicates and failures)
SELECT * FROM transactions LIMIT 10;