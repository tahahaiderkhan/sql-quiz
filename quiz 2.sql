--Task 1 
--Build the Sales Detail Dataset (6 marks)
--Management needs a detailed sales dataset for analysis. Return one row per order item containing:
--order_id and order_date
--customer full name
--store name
--staff full name
--product name
--category name
--brand name
--quantity, list_price, discount
--calculated net_line_revenue

SELECT
    o.order_id,
    o.order_date,

    c.first_name +' '+ c.last_name AS customer_name,

    s.store_name,

    st.first_name+ ' '+ st.last_name AS staff_name,

    p.product_name,
    cat.category_name,
    b.brand_name,

    oi.quantity,
    oi.list_price,
    oi.discount,

    oi.quantity * oi.list_price * (1 - oi.discount) AS net_line_revenue

    FROM sales.orders AS o

    INNER JOIN sales.customers AS c
    ON o.customer_id = c.customer_id

    INNER JOIN sales.stores AS s
    ON o.store_id = s.store_id

    INNER JOIN sales.staffs AS st
    ON o.staff_id = st.staff_id

     INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id

    INNER JOIN production.products AS p
    ON oi.product_id = p.product_id


    INNER JOIN production.categories AS cat
    ON p.category_id = cat.category_id

    INNER JOIN production.brands AS b
    ON p.brand_id = b.brand_id

    WHERE o.order_status = 4

    ORDER BY o.order_date DESC;



/* Task 2 
Store Performance Summary (5 marks)
Create a store-level performance report for completed orders showing:
store name
number of distinct orders
total units sold
total net revenue
average order value

Return one row per store and order the stores from highest to lowest total net revenue. */


SELECT
    s.store_name,
   

    COUNT(DISTINCT o.order_id) AS number_of_orders,

    SUM(oi.quantity) AS total_units_sold,

    SUM(
        oi.quantity * oi.list_price * (1 - oi.discount)
    ) AS total_net_revenue,

    SUM(
        oi.quantity * oi.list_price * (1 - oi.discount)
    )
    / COUNT(DISTINCT o.order_id) AS average_order_value

    FROM sales.stores AS s

    INNER JOIN sales.orders AS o
    ON s.store_id = o.store_id

    INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id

    WHERE o.order_status = 4

    GROUP BY s.store_id, s.store_name,o.order_status

    ORDER BY total_net_revenue DESC;



/* Task 3 — High-Value Customers (5 marks)
Management wants to identify high-value customers. Return customers whose total completed-order spending is greater than the average total spending of customers who have completed orders.

Show customer_id, customer name, completed order count, and total spending. Order the result by total spending descending.
 */

 WITH customer_spending AS
(
    SELECT
        c.customer_id,
        c.first_name+ ' '+c.last_name AS customer_name,

        COUNT(DISTINCT o.order_id) AS completed_order_count,

        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_spending

    FROM sales.customers AS c

    INNER JOIN sales.orders AS o
        ON c.customer_id = o.customer_id

    INNER JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 4

    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)

SELECT
    customer_id,
    customer_name,
    completed_order_count,
    total_spending

FROM customer_spending

WHERE total_spending >
(
    SELECT AVG(total_spending)
    FROM customer_spending
)

ORDER BY total_spending DESC;

/*
Task 4 — Inventory Risk Report (5 marks)
Operations wants to identify inventory risk. Return products where the stock quantity is below 5 in at least one store.
Show product name, store name, current quantity, category name, and brand name. Products with zero stock should appear first, followed by the lowest remaining quantities.


*/




SELECT
    p.product_name,
    s.store_name,
    st.quantity AS current_quantity,
    cat.category_name,
    b.brand_name


FROM production.stocks AS st

INNER JOIN production.products AS p
    ON st.product_id = p.product_id

INNER JOIN sales.stores AS s
    ON st.store_id = s.store_id

INNER JOIN production.categories AS cat
    ON p.category_id = cat.category_id

INNER JOIN production.brands AS b
    ON p.brand_id = b.brand_id

WHERE st.quantity < 5

ORDER BY
    st.quantity ASC,
    p.product_name;
/*
Task 5 — Top Products Within Each Category (6 marks)
For each product category, identify the top 3 products by total net revenue from completed orders.
*/
WITH product_sales AS
(
    SELECT
        cat.category_name,
        p.product_id,
        p.product_name,

        SUM(oi.quantity) AS total_units_sold,

        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue

    FROM production.products AS p

    INNER JOIN production.categories AS cat
        ON p.category_id = cat.category_id

    INNER JOIN sales.order_items AS oi
        ON p.product_id = oi.product_id

    INNER JOIN sales.orders AS o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 4

    GROUP BY
        cat.category_name,
        p.product_id,
        p.product_name
),

ranked_products AS
(
    SELECT
        category_name,
        product_name,
        total_units_sold,
        total_net_revenue,

        DENSE_RANK() OVER
        (
            PARTITION BY category_name
            ORDER BY total_net_revenue DESC
        ) AS product_position

    FROM product_sales
)

SELECT
    category_name,
    product_name,
    total_units_sold,
    total_net_revenue,
    product_position

FROM ranked_products

WHERE product_position <= 3

ORDER BY
    category_name,
    product_position,
    total_net_revenue DESC;

/*
Task 6 — Monthly Sales Trend (6 marks)
Create a monthly sales trend for completed orders.

For each calendar month return:
year
month
total net revenue
previous months total net revenue
revenue change from the previous month
The first month may have NULL for the previous-month comparison. Sort chronologically.
*/


WITH monthly_sales AS
(
    SELECT
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,

        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue

    FROM sales.orders AS o

    INNER JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 4

    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
)

SELECT
    sales_year AS [year],
    sales_month AS [month],
    total_net_revenue,

    LAG(total_net_revenue) OVER
    (
        ORDER BY sales_year, sales_month
    ) AS previous_month_revenue,

    total_net_revenue
    -
    LAG(total_net_revenue) OVER
    (
        ORDER BY sales_year, sales_month
    ) AS revenue_change

FROM monthly_sales

ORDER BY
    sales_year,
    sales_month;

/*
Task 8 — Safe Data Modification (4 marks)
A customer with customer_id = 1 has requested that their phone number be changed to '(999) 555-0101'.
*/

BEGIN TRANSACTION;

UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;


SELECT
    customer_id,
    first_name,
    last_name,
    phone
FROM sales.customers
WHERE customer_id = 1;



ROLLBACK TRANSACTION;
/*

Task 9 — Store Sales Procedure (6 marks)
Create a stored procedure named sales.usp_store_sales_report with these input parameters:
@store_id
@start_date
@end_date

The procedure should return completed-order sales for the requested store and date range, grouped by product. Return product name, total units sold, and total net revenue, ordered by revenue descending.

Add appropriate error handling for invalid date ranges where @start_date is later than @end_date
*/

CREATE PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN

    SET NOCOUNT ON;

    SELECT
        p.product_name,

        SUM(oi.quantity) AS total_units_sold,

        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue

    FROM sales.orders AS o

    INNER JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id

    INNER JOIN production.products AS p
        ON oi.product_id = p.product_id

    WHERE o.store_id = @store_id
      AND o.order_status = 4
      AND o.order_date >= @start_date
      AND o.order_date < DATEADD(DAY, 1, @end_date)

    GROUP BY
        p.product_id,
        p.product_name

    ORDER BY
        total_net_revenue DESC;

END;



EXEC sales.usp_store_sales_report
    @store_id = 1,
    @start_date = '2016-01-01',
    @end_date = '2016-12-31';








/*
Task 10 — Management Insight Query (3 marks)
Write one additional SQL query that you believe would provide useful insight to BikeStores management using at least three tables.

Below the query, add a SQL comment of no more than three lines explaining:
1. the business question,
2. what the result measures, and
3. why management should care about it. &*/ 


SELECT
    s.store_name,
    cat.category_name,

    SUM(oi.quantity) AS total_units_sold,

    SUM(
        oi.quantity * oi.list_price * (1 - oi.discount)
    ) AS total_net_revenue

FROM sales.stores AS s

INNER JOIN sales.orders AS o
    ON s.store_id = o.store_id

INNER JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id

INNER JOIN production.products AS p
    ON oi.product_id = p.product_id

INNER JOIN production.categories AS cat
    ON p.category_id = cat.category_id

WHERE o.order_status = 4

GROUP BY
    s.store_name,
    cat.category_name

ORDER BY
    total_net_revenue DESC;














