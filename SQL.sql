SELECT * FROM transactions;
SELECT * FROM customers;

# 1. список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, 
# средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;
# информацию в разрезе месяцев:
SELECT
    ID_client,
    ROUND(AVG(Sum_payment), 2) AS avg_check,  
    ROUND(SUM(Sum_payment)/12, 2) AS avg_monthly_sum, 
    COUNT(*) AS total_ops 
FROM transactions
WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'
GROUP BY ID_client
HAVING COUNT(DISTINCT DATE_FORMAT(data_new, '%Y-%m')) = 12 # показывает регулярность, т.е. данные есть во всех 12ти месяцах
ORDER BY ID_client;

#2.
# средняя сумма чека в месяц;
# среднее количество операций в месяц;
# среднее количество клиентов, которые совершали операции;
# долю от общего количества операций за год и долю в месяц от общей суммы операций;
SELECT
    DATE_FORMAT(data_new, '%Y-%m-01') AS month_start,
    ROUND(AVG(Sum_payment),2) AS avg_check_per_month,
    COUNT(*) AS total_ops,
    COUNT(DISTINCT ID_client) AS clients_with_ops,
    ROUND(COUNT(*)/COUNT(DISTINCT ID_client),2) AS avg_ops_per_client,
    ROUND(100 * COUNT(*)/(
        SELECT COUNT(*) FROM transactions
        WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'),2) AS pct_of_year_ops,
    ROUND(100 * SUM(Sum_payment)/(
        SELECT SUM(Sum_payment) FROM transactions
        WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'),2) AS pct_of_year_sum
FROM transactions
WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'
GROUP BY month_start
ORDER BY month_start;

# вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
SELECT m.month_start, m.gender_group, m.ops_count,
    ROUND(100 * m.ops_count / mt.total_ops, 2) AS pct_ops_share,
    ROUND(m.spend_amount, 2) AS spend_amount,
    ROUND(100 * m.spend_amount / mt.total_spend, 2) AS pct_spend_share
FROM (                                       
    SELECT            
        DATE_FORMAT(t.data_new, '%Y-%m-01') AS month_start,
        CASE WHEN c.Gender IS NULL THEN 'NA' ELSE c.Gender END AS gender_group,
        COUNT(*) AS ops_count,
        SUM(t.Sum_payment) AS spend_amount
    FROM transactions t
    LEFT JOIN customers c ON c.Id_client = t.ID_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-05-01'
    GROUP BY month_start, gender_group
) AS m      # операции и суммы по каждой паре (месяц, пол)
JOIN (
    SELECT
        DATE_FORMAT(data_new, '%Y-%m-01') AS month_start,
        COUNT(*)          AS total_ops,
        SUM(Sum_payment)  AS total_spend
    FROM transactions
    WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'
    GROUP BY month_start
) AS mt ON mt.month_start = m.month_start      # итоги по каждому месяцу (для расчёта долей)
ORDER BY m.month_start,
	CASE m.gender_group WHEN 'M' THEN 1 WHEN 'F' THEN 2 ELSE 3 END;

#3. возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, с параметрами сумма и количество операций 
# за весь период, и поквартально - средние показатели и %.
-- за весь период 
WITH age_stats AS (
    SELECT CASE
            WHEN c.Age IS NULL THEN 'NA'
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age BETWEEN 70 AND 79 THEN '70-79'
            WHEN c.Age BETWEEN 80 AND 89 THEN '80-89'
            ELSE '90+'
        END AS age_group,
        COUNT(*) AS total_ops,
        SUM(t.Sum_payment) AS total_sum
    FROM transactions t
    LEFT JOIN customers c ON c.Id_client = t.ID_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-05-01'
    GROUP BY age_group
),
totals AS (
    SELECT
        COUNT(*) AS grand_ops,
        SUM(Sum_payment) AS grand_sum
    FROM transactions
    WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'
)
SELECT a.age_group, a.total_ops, a.total_sum,
    ROUND(100 * a.total_ops / tot.grand_ops, 2) AS pct_ops_share,
    ROUND(100 * a.total_sum / tot.grand_sum, 2) AS pct_sum_share
FROM age_stats a CROSS JOIN totals tot
ORDER BY a.age_group;

-- поквартально 
WITH quarter_age AS (
    SELECT CASE
            WHEN t.data_new BETWEEN '2015-06-01' AND '2015-08-01' THEN 'Q1'
            WHEN t.data_new BETWEEN '2015-09-01' AND '2015-11-01' THEN 'Q2'
            WHEN t.data_new BETWEEN '2015-12-01' AND '2016-02-01' THEN 'Q3'
            WHEN t.data_new BETWEEN '2016-03-01' AND '2016-05-01' THEN 'Q4'
        END AS quarter_label,
        CASE
            WHEN c.Age IS NULL THEN 'NA'
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN c.Age BETWEEN 70 AND 79 THEN '70-79'
            WHEN c.Age BETWEEN 80 AND 89 THEN '80-89'
            ELSE '90+'
        END AS age_group,
        COUNT(*) AS ops_count,
        SUM(t.Sum_payment) AS sum_amount
    FROM transactions t
    LEFT JOIN customers c ON c.Id_client = t.ID_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-05-01'
    GROUP BY quarter_label, age_group
),
quarter_totals AS (
    SELECT CASE
            WHEN data_new BETWEEN '2015-06-01' AND '2015-08-01' THEN 'Q1'
            WHEN data_new BETWEEN '2015-09-01' AND '2015-11-01' THEN 'Q2'
            WHEN data_new BETWEEN '2015-12-01' AND '2016-02-01' THEN 'Q3'
            WHEN data_new BETWEEN '2016-03-01' AND '2016-05-01' THEN 'Q4'
        END AS quarter_label,
        COUNT(*) AS total_ops,
        SUM(Sum_payment) AS total_sum
    FROM transactions
    WHERE data_new BETWEEN '2015-06-01' AND '2016-05-01'
    GROUP BY quarter_label
)
SELECT q.quarter_label, q.age_group,
    ROUND(q.ops_count / 3, 2) AS avg_ops_per_month,
    ROUND(q.sum_amount / 3, 2) AS avg_sum_per_month,
    ROUND(100 * q.ops_count / qt.total_ops, 2) AS pct_ops_share,
    ROUND(100 * q.sum_amount / qt.total_sum, 2) AS pct_sum_share
FROM quarter_age q
JOIN quarter_totals qt ON qt.quarter_label = q.quarter_label
ORDER BY q.quarter_label, q.age_group;