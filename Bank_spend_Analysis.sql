SELECT column_name,data_type
FROM information_schema.columns
WHERE table_name = 'dim_customers';

SELECT column_name,data_type
FROM information_schema.columns
WHERE table_name = 'fact_spends';

-- Data Analysis
-- No of Rows
select count(*)
FROM dim_customers;

select count(*)
FROM fact_spends;

-- No.of Customers , Month
select 
     count(distinct(customer_id)) as no_of_customers,
	 count(distinct(month)) as Months
	 from fact_spends;
-- (Insight:: 4000 Customers and Total 6 Monts)
	 
-- Total_Spend 
select SUM(spend) as Total_Spend
from fact_spends;

--OR if we want to see value in Million

select 
      CASE WHEN sum(spend) >=1000000
	  THEN (sum(spend)/1000000)::numeric(10,0) || ' Million'
	  ELSE sum(spend)::text 
	  END as Total_Spend
	  from fact_spends;

-- Save total Spend as a "Value" as Overall spend fpr further Use
-- Overall_spend 
DO $$
DECLARE Overall_Spend int;
BEGIN
       select sum(spend) INTO Overall_Spend
       from fact_spends as Overall_Spend;
END $$

-- Retrieve Overall_Spend
select * from Overall_Spend;

-- Spend by Gender
--Q1 : Who Spends More , Compare with Gender Count as well Spend by Gender
SELECT 
    d.gender,
    SUM(f.spend) AS Spend,
	(select * from Overall_Spend) as Overall_Spend,
	count(distinct(d.customer_id)) as gender_count,
	ROUND(SUM(f.spend) / CAST((SELECT * FROM Overall_Spend) AS NUMERIC) * 100, 2) AS spend_perc,
    ROUND((COUNT(DISTINCT d.customer_id) / (SELECT COUNT(DISTINCT customer_id)::NUMERIC FROM dim_customers) * 100), 2) AS gender_perc
FROM 
    fact_spends f
INNER JOIN 
    dim_customers d ON d.customer_id = f.customer_id
GROUP BY 
    d.gender
ORDER BY 
    Spend DESC;

-- OR in Million

SELECT 
    d.gender, 
    COUNT(DISTINCT d.customer_id) AS Gender_count,
	ROUND((select * from Overall_Spend)/1000000 :: NUMERIC) || ' Million' as Overall_Spend,
	CASE 
        WHEN SUM(f.spend) >= 1000000
        THEN (SUM(f.spend) / 1000000)::NUMERIC(10, 0) || ' Million'
        ELSE SUM(f.spend)::TEXT
    END AS Total_Spend,
	ROUND(sum(f.spend)/CAST((select * from Overall_Spend) AS NUMERIC)*100) as spend_perc,
	ROUND(COUNT(DISTINCT d.customer_id) / 4000::NUMERIC,2)*100 AS gender_perc
FROM 
    fact_spends f
INNER JOIN
    dim_customers d ON f.customer_id = d.customer_id
GROUP BY 
    d.gender
ORDER BY 
    Total_Spend DESC;
	
-- Insights : Total 4000 Customers , 2597(65%) Customers are Male and
-- 1403 are Female(35%) , And Spend Ratio is Male:(67.27%) , Female(32.73%)
-- Male Spend More Compared to Female

-- Q2: In Which Category People Spend More with Gender Comparison

with agg_table as(
      select * 
	  from dim_customers d
      INNER JOIN 
      fact_spends f on d.customer_id=f.customer_id)

select 
	   category,
	   sum(spend) as Spend,
	   ROUND(sum(spend)::NUMERIC/(select sum(spend) from fact_spends)::NUMERIC*100,2) as Spend_perc
	   from agg_table
	   group by category
	   ORDER BY spend DESC;

-- Insight (Spending is More for Bills , Groceries followed BY Others)

-- Use Cross tab for Viewing this as Matrix format
SELECT * FROM crosstab(
    $$
    WITH agg_table AS (
        SELECT *
        FROM 
            dim_customers d
        INNER JOIN 
            fact_spends f ON d.customer_id = f.customer_id
    )
    SELECT 
        category,
        gender,
	    ROUND(SUM(spend)/1000000)::text || 'M' AS total_spend
    FROM 
        agg_table
    GROUP BY 
        category, gender
    ORDER BY 
        category, total_spend DESC
    $$,
    $$ 
    VALUES ('Male'::text), ('Female'::text)
    $$
) AS category_spend(category varchar, male text, female text);


-- Insight :: 1. For Every Category Male Spend More except "Health & Wellness" and Apparel

-- Q3 Which month has the Highest Spend All Over

select month,
       sum(spend) as Total_Spend, 
	   ROUND((sum(spend)/((select * from Overall_Spend)::Numeric))*100,2) as Overall_Spend
from fact_spends
GROUP BY month
ORDER BY Total_Spend DESC;
-- Insight In September Customers spend more 
-- Q4 In September Customers spend more and top 3 categories for spending

select month , 
       category,
       sum(spend)as spend
from fact_spends
WHERE month = 'September'
GROUP BY month, category
ORDER BY spend DESC
LIMIT 3;

-- Q5 For every month Which Category leads the top 
with rank_table as (
select month , 
       category,
       sum(spend)as spend,
	   DENSE_RANK() OVER (PARTITION BY month ORDER BY sum(spend) DESC) as ranks
from fact_spends
-- WHERE month = 'September'
GROUP BY month, category
ORDER BY spend DESC
)
select category,
       month,
	   ranks
from rank_table
WHERE ranks IN (1,2,3)
ORDER BY month, ranks;

-- Insight 1. Bills , 2. Groceries , 3.Electronics are the top spending category for all the month

-- Q6 Which payment type is widely used
select payment_type,
       count(customer_id) as no_of_transaction,
       sum(spend) as spend,
	   ROUND((sum(spend)/((select * from Overall_Spend)::Numeric))*100) as perc_spend
       from fact_spends
GROUP BY payment_type
ORDER BY spend DESC;

-- Spend is more in Credit Cards, most 41% of total spend was done by credit cards,
 -- Now lets see how many transaction have happend total for all the payment method

-- Through Credit Card Who paid more top 10 customers
with credit_table as(
select customer_id,payment_type,
sum(spend) as spend
from fact_spends
GROUP BY customer_id,payment_type
HAVING payment_type = 'Credit Card'
ORDER by spend DESC
limit 10) 

select ct.customer_id,
       d.city,
	   d.gender,
	   ct.spend
from credit_table ct
LEFT JOIN 
      dim_customers d on ct.customer_id = d.customer_id;
	  
-- Insight All top Credit card Spending Customers are from Mumbai and all are Male


-- Q7 Top 3 cities for Spending through Credit Card
with agg_table as (
	select d.city,
       d.customer_id,
	   f.spend,
	   f.payment_type
from dim_customers d
INNER JOIN fact_spends f on d.customer_id=f.customer_id
WHERE f.payment_type = 'Credit Card')

select city,
       sum(spend) as spend
from agg_table
GROUP BY city
ORDER by spend DESC
--LIMIT 3
;

-- Insight 1. Mumbai, 2.Delhi,3.Bangalore

-- Q8 Which Age Group Spends More and Uses Credit Card the Most
with agg_table as (
	select d.city,
       d.customer_id,
	   f.spend,
	   f.payment_type,
	   d.age_group
from dim_customers d
INNER JOIN fact_spends f on d.customer_id=f.customer_id
WHERE f.payment_type = 'Credit Card')

select age_group,
       sum(spend) as spend
from agg_table
GROUP BY age_group
ORDER by spend DESC;

-- Insight In Credit Card 25-34 People spends the most , followed by 35-45 age people

-- age_group vs spend vs payment method

SELECT * FROM crosstab(
    $$
    WITH agg_table AS (
        SELECT
            d.age_group,
            f.payment_type,
            SUM(f.spend) AS spend
        FROM
            dim_customers d
        LEFT JOIN
            fact_spends f ON d.customer_id = f.customer_id
        GROUP BY
            d.age_group, f.payment_type
        ORDER BY
            d.age_group, spend DESC
    )
    SELECT
        age_group,
        payment_type,
        (spend/1000000)::text 
    FROM
        agg_table
    $$,
    $$
    VALUES ('Credit Card'::text), ('Debit Card'::text), ('UPI'::text), ('Net Banking'::text)
    $$
) AS ct_age(age_group varchar(10), Credit int, Debit int, UPI int, NetBanking int)
ORDER BY credit DESC;

-- All payment type vs ag spend
-- 25-34 spends most in Credit Card followed by UPI
-- 35-45 spends most in Credit Card , Debit Card followed byU UPI
--  45+ spend more on Credit followed by Debit
-- 21-24 spend more in UPI followed by credit
 
-- Q9 Occupation Vs spend Percentage
WITH agg_table AS (
    SELECT
        cd.customer_id,
        cd.occupation,
        f.spend,
        f.payment_type,
        CASE 
            WHEN cd.occupation = 'Salaried IT Employees' THEN 'IT'
            WHEN cd.occupation = 'Business Owners' THEN 'Business'
            WHEN cd.occupation = 'Salaried Other Employees' THEN 'Salaried_Other'
            WHEN cd.occupation = 'Government Employess' THEN 'Government'
            ELSE cd.occupation
        END AS occupation_new
    FROM
        fact_spends f
    INNER JOIN
        dim_customers cd ON f.customer_id = cd.customer_id
--    WHERE
--        f.payment_type = 'Credit Card'
)

SELECT
    agg_table.occupation_new,
    SUM(agg_table.spend) AS Spend,
    ROUND((SUM(agg_table.spend) / (SELECT * FROM Overall_Spend)::numeric) * 100, 2) AS spend_perc
FROM
    agg_table
GROUP BY
    occupation_new
ORDER BY
    Spend DESC;


-- Insight IT Employees Spends 45.91 % of total Spend,
--  Business and Salaries_Other comes with almost 16 % each
-- Freelancers spends 14% and finally Government Employees spends 6%
-- Note: Through Credit card also the Spending Order seems to be same as above

-- Customer Segment
with top_100_customers as(
	select customer_id,
       sum(spend) as spend
	   from fact_spends
	   GROUP BY customer_id
	   ORDER BY spend DESC
	   LIMIT 100)
select t_100.customer_id,
       cd.gender,
	   cd.occupation,
	   cd.city,
	   t_100.spend,
	   cd.avg_income * 6 AS income_6_months
from dim_customers cd
INNER JOIN top_100_customers t_100
ON t_100.customer_id = cd.customer_id
ORDER by t_100.spend DESC;

-- Last But Not least.. Take Average Income Vs spend Analysis to get Income Utilization
--Calculate top 100 customers with high Income Utilization
with tbl as (SELECT
    customer_id,
    ROUND(SUM(spend)) AS spend,
	month
FROM
    fact_spends
GROUP BY
    customer_id,month
-- HAVING customer_id = 'ATQCUS0918'
ORDER BY spend DESC),
tbl2 as (select cd.customer_id,
		cd.avg_income,
		tbl.spend,
		cd.gender,
		cd.occupation,
		cd.city,
		cd.age_group,
		cd.marital_status
		from dim_customers cd
		INNER JOIN tbl on cd.customer_id = tbl.customer_id)

select customer_id,
      gender, occupation,city,age_group,marital_status,
      ROUND(avg(spend)) as avg_spend,
	  ROUND(avg(avg_income)) as avg_income,
	  ROUND(avg(spend)/ ROUND(avg(avg_income))*100) as income_utilization
from tbl2
group by customer_id,gender,occupation,city,age_group,marital_status
ORDER BY income_utilization DESC
LIMIT 100;

-- Insight - IT employees, from Mumbai and Male spends more and and Income Utilization also More
-- Even though Salary is High for 45+ customers, 
-- spend ratio and Income Utilization ratio is more for 34-45 & 25-34 Age group Customers
-- Marital_Status , Married Customers spend more
	   
  
	 



	 
  