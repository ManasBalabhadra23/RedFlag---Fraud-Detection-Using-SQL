-- =====================================================================
-- RedFlag — Fraud Detection Submission
-- Student: Manas Balabhadra | Batch: DA-DS-1
-- =====================================================================

use redflag;

select count(*) as total_transactions from transactions;

select count(distinct user_id) as total_users from transactions;

select min(txn_time) as first_transaction, max(txn_time) as last_transaction from transactions;

-- =====================================================================
-- PATTERN 1 - VELOCITY FRAUD
-- What I'm looking for: users with 30+ transactions in a single day
-- Expected suspects: ~50
-- =====================================================================

select user_id, date(txn_time) as transaction_date, count(txn_id) as total_transactions
from transactions 
group by user_id, date(txn_time)
having count(txn_id) >= 30
order by total_transactions desc, user_id;

-- My findings: 52 suspect user-days flagged.
-- Top 3 fraudsters by transaction count: user 14523 (45 txns on 2024-04-12),
-- user 14508 (44 txns on 2024-02-28), user 14515 (43 txns on 2024-05-19).

-- =====================================================================
-- pattern 2 - round-amount clustering
-- what i'm looking for: users with 15 or more transactions having exactly round amounts (100, 200, 500, 1000, 2000, 5000, 10000).
-- expected suspects: exactly 25
-- =====================================================================

select user_id, count(txn_id) as round_transactions from transactions
where amount in (100, 200, 500, 1000, 2000, 5000, 10000)
group by user_id
having count(txn_id) >= 15
order by round_transactions desc, user_id;

-- My findings: 25 suspect users flagged.
-- Top 3 users: 14533 (30 transactions), 14534 (30 transactions),
-- and 14535 (30 transactions).

-- =====================================================================
-- pattern 3 - card testing
-- what i'm looking for: users making 30 or more transactions below ₹10 in a single day.
-- expected suspects: exactly 20
-- =====================================================================

select user_id, date(txn_time) as transaction_date, count(txn_id) as small_transactions
from transactions
where amount < 10
group by user_id, date(txn_time)
having count(txn_id) >= 30
order by small_transactions desc, user_id;

-- My findings: 20 suspect user-days flagged.
-- Top 3 fraudsters by transaction count:
-- user 14556 (60 transactions on 2024-05-28),
-- user 14569 (60 transactions on 2024-04-03),
-- user 14559 (59 transactions on 2024-06-04).

-- =====================================================================
-- pattern 4 - failed-then-succeeded
-- what i'm looking for: users with 20 or more failed transactions.
-- (simplified week 3 version)
-- expected suspects: exactly 25
-- =====================================================================

select user_id, count(txn_id) as failed_transactions from transactions
where status = 'failed'
group by user_id
having count(txn_id) >= 20
order by failed_transactions desc, user_id;

-- My findings: 25 suspect users were flagged with 20 or more failed transactions.
-- Top 3 fraudsters by failed transaction count:
-- user 14595 (35 failed transactions),
-- user 14593 (34 failed transactions),
-- user 14576 (33 failed transactions).

-- =====================================================================
-- pattern 5 - odd-hour concentration
-- what i'm looking for: users with at least 30 transactions where 80% or more occur between 2 am and 4 am.
-- expected suspects: exactly 20
-- =====================================================================

select user_id, count(*) as total_transactions,
sum(case
		when hour(txn_time) between 2 and 4 then 1
		else 0
        end) as odd_hour_transactions,
round(
	(sum(case
		when hour(txn_time) between 2 and 4 then 1
		else 0
		end) * 100.0) / count(*),
	2
) as odd_hour_percentage
from transactions
group by user_id
having count(*) >= 30
and (sum(case
	when hour(txn_time) between 2 and 4 then 1
	else 0
	end) * 1.0 / count(*)) >= 0.80
order by odd_hour_percentage desc;

-- My findings: 20 suspect users were flagged with at least 30 transactions where 80% or more occurred between 2 AM and 4 AM.
-- Top 3 fraudsters by odd-hour concentration:
-- user 14606 (49 of 52 transactions, 94.23%),
-- user 14609 (45 of 48 transactions, 93.75%),
-- user 14608 (58 of 63 transactions, 92.06%).

-- =====================================================================
-- pattern 6 - mule accounts
-- what i'm looking for: users with 8 or more credit transactions
-- (simplified week 3 version)
-- expected suspects: about 30
-- =====================================================================

select user_id, count(*) as credit_transactions from transactions
where txn_type = 'credit'
group by user_id
having count(*) >= 8
order by credit_transactions desc;

-- My findings:
-- 30 suspect users were flagged with 8 or more credit transactions indicating potential mule account activity.
-- Top 3 suspects by credit transaction count:
-- user 14630 (15 credit transactions),
-- user 14637 (15 credit transactions),
-- user 14640 (15 credit transactions).

-- =====================================================================
-- pattern 7 - refund abuse
-- what i'm looking for: users with at least 20 transactions and refund rate greater than 40%.
-- expected suspects: about 25
-- =====================================================================

select user_id, count(*) as total_transactions,
sum(case
	when txn_type = 'refund' then 1
	else 0
end) as refund_transactions,
round(
	(sum(case
		when txn_type = 'refund' then 1
		else 0
	end) * 100.0) / count(*),
	2
) as refund_percentage
from transactions
group by user_id
having count(*) >= 20
and (sum(case
		when txn_type = 'refund' then 1
		else 0
	end) * 1.0 / count(*)) > 0.40
order by refund_percentage desc;

-- My findings: 24 suspect users were flagged with 20 or more transactions and refund rate greater than 40%, indicating potential refund abuse.
-- Top 3 suspects by refund rate:
-- user 14662 (25 refunds out of 39 transactions, 64.10%),
-- user 14670 (32 refunds out of 50 transactions, 64.00%),
-- user 14665 (23 refunds out of 36 transactions, 63.89%).

-- =====================================================================
-- pattern 8 - merchant collusion
-- what i'm looking for: merchants with unusually high transaction volume
-- expected suspects: partial solution
-- =====================================================================

select merchant_id, count(*) as total_transactions, sum(amount) as total_amount, 
avg(amount) as average_amount from transactions
group by merchant_id
having sum(amount) > 1000000
order by total_amount desc;

-- My findings: 15 merchants were identified as potential colluding merchants based on unusually high transaction volumes.
-- Top 3 suspicious merchants:
-- merchant 12 (₹2,177,212.35 total transaction value),
-- merchant 9 (₹2,139,820.91 total transaction value),
-- merchant 5 (₹2,125,209.64 total transaction value).

-- =====================================================================
-- pattern 9 - just-under-threshold (structuring)
-- what i'm looking for: users with 10 or more transactions of exactly ₹9999.00.
-- expected suspects: exactly 20
-- =====================================================================

select user_id, count(*) as suspicious_transactions from transactions
where amount = 9999.00
group by user_id
having count(*) >= 10
order by suspicious_transactions desc;

-- My findings:
-- 20 suspect users were flagged with 10 or more transactions of exactly ₹9,999.00,
-- indicating possible transaction structuring to avoid regulatory reporting thresholds.
-- Top 3 suspects by transaction count:
-- user 14680 (25 transactions),
-- user 14690 (25 transactions),
-- user 14693 (22 transactions).

-- =====================================================================
-- pattern 10 - dormant-then-active
-- what i'm looking for: users with unusually high transaction activity.
-- (simplified week 3 version)
-- expected suspects: partial solution
-- =====================================================================

select user_id, count(*) as total_transactions from transactions
group by user_id
having count(*) >= 50
order by total_transactions desc;

-- My findings: 150 suspect users were flagged with 50 or more transactions, indicating unusually
-- high account activity that may require further investigation.
-- Top 3 suspects by transaction count:
-- user 11066 (96 transactions),
-- user 458 (95 transactions),
-- user 8630 (93 transactions).

-- =====================================================================
-- pattern 11 - velocity spike
-- what i'm looking for: users whose peak monthly transaction count is at least 5 times their 
-- average monthly transaction count.
-- expected suspects: 35-45
-- =====================================================================

with monthly_txns as (
    select user_id, date_format(txn_time, '%Y-%m') as txn_month, count(*) as monthly_count
    from transactions
    group by user_id, date_format(txn_time, '%Y-%m')
),
user_stats as (
    select user_id, avg(monthly_count) as avg_monthly_txns,  
    max(monthly_count) as peak_monthly_txns from monthly_txns
    group by user_id
)
select user_id, round(avg_monthly_txns,2) as average_monthly_transactions, peak_monthly_txns from user_stats
where peak_monthly_txns >= 20
and peak_monthly_txns >= avg_monthly_txns * 5
order by peak_monthly_txns desc;

-- My findings: 3 suspect users were flagged whose peak monthly transaction count was at least
-- 5 times their average monthly transaction count, indicating a significant velocity spike.
-- Top 3 suspects:
-- user 14504 (peak: 45 transactions, average: 8.83),
-- user 14517 (peak: 41 transactions, average: 8.00),
-- user 14528 (peak: 39 transactions, average: 7.67).

-- =====================================================================
-- pattern 12 · geographic impossibility
-- what i'm looking for: users making transactions in different cities
-- within 60 minutes.
-- expected suspects: exactly 15
-- =====================================================================

with location_history as (
    select
        user_id, txn_time, city, 
        lag(city) over(partition by user_id order by txn_time) as previous_city,
        lag(txn_time) over(partition by user_id order by txn_time) as previous_time
    from transactions
)
select user_id, previous_city, city, previous_time, txn_time, 
timestampdiff(minute, previous_time, txn_time) as time_gap from location_history
where previous_city is not null and city <> previous_city 
and timestampdiff(minute, previous_time, txn_time) <= 60
order by user_id, txn_time;

-- My findings: 15 suspect users were flagged for making transactions from different cities
-- within 60 minutes, indicating geographically impossible transaction activity and 
-- potential account compromise.
-- Top 3 suspects:
-- user 14743 (7 impossible location changes),
-- user 14746 (7 impossible location changes),
-- user 14751 (7 impossible location changes).