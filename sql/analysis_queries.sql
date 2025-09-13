/*
    analysis_queries.sql

    This file contains example T‑SQL queries to derive insights from the
    ECommerceMiniDW warehouse.  They correspond roughly to the metrics
    produced in the Python analysis: monthly revenue, top product
    categories by sales and a simple customer retention measure.
    Analysts can run these queries in SQL Server Management Studio or
    equivalent tools.
*/

USE ECommerceMiniDW;
GO

/*
    1. Monthly revenue by year and month
    Aggregates the payment_value from fact_payments joined to fact_orders
    and dim_date.  Results are ordered chronologically.
*/
SELECT
    d.year,
    d.month,
    SUM(fp.payment_value) AS total_revenue
FROM fact_payments fp
JOIN fact_orders fo ON fo.order_id = fp.order_id
JOIN dim_date d ON fo.order_date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

/*
    2. Top 10 product categories by sales
    Sales are calculated as the sum of the price column on the
    fact_order_items table.  Categories are looked up via dim_product and
    dim_category.  Order by descending total_sales to find the top
    categories.
*/
SELECT TOP (10)
    c.category_name,
    SUM(foi.price) AS total_sales
FROM fact_order_items foi
JOIN dim_product p ON p.product_key = foi.product_key
JOIN dim_category c ON c.category_key = p.category_key
GROUP BY c.category_name
ORDER BY total_sales DESC;

/*
    3. Customer retention rate
    For each customer, count the number of distinct purchase months.
    Customers with more than one month of purchases are considered
    repeat customers.  The retention rate is the fraction of repeat
    customers over the total number of customers.  Cast to decimal to
    obtain a fractional value.
*/
WITH customer_months AS (
    SELECT
        fo.customer_key,
        CONVERT(VARCHAR(7), d.full_date, 120) AS year_month
    FROM fact_orders fo
    JOIN dim_date d ON fo.order_date_key = d.date_key
    GROUP BY fo.customer_key, CONVERT(VARCHAR(7), d.full_date, 120)
), customer_counts AS (
    SELECT customer_key, COUNT(*) AS month_count
    FROM customer_months
    GROUP BY customer_key
)
SELECT
    CAST(SUM(CASE WHEN month_count > 1 THEN 1 ELSE 0 END) AS DECIMAL(10,2)) / CAST(COUNT(*) AS DECIMAL(10,2)) AS retention_rate
FROM customer_counts;

-- End of analysis_queries.sql