-- Module 5: Assignment 2. Project Query Portfolio
-- Swastika Poudel and Bishnu Bahadur GC
-- CIT 406: Database Design (Fall "A" 2026)
-- Professor Anshu Sharma | October 2, 2026
-- Run against the existing restaurant schema and sample data.

-- Query 1: Which customers have placed orders and how many orders has each placed?
SELECT c.customer_id, c.first_name, c.last_name,
       COUNT(o.order_id) AS total_orders
FROM restaurant.customer AS c
INNER JOIN restaurant.restaurant_order AS o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_orders DESC, c.customer_id;

-- Query 2: How many orders did each employee handle on October 1 including employees with no orders?
SELECT e.employee_id, e.first_name, e.last_name,
       COUNT(o.order_id) AS orders_handled
FROM restaurant.employee AS e
LEFT JOIN restaurant.restaurant_order AS o
    ON o.employee_id = e.employee_id
    AND o.order_datetime >= TIMESTAMPTZ '2026-10-01 00:00:00-04'
    AND o.order_datetime < TIMESTAMPTZ '2026-10-02 00:00:00-04'
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY orders_handled DESC, e.employee_id;

-- Query 3: Which tables are associated with active orders and who placed them?
SELECT t.table_number, t.seating_capacity, o.order_id,
       c.first_name, c.last_name, o.status AS order_status
FROM restaurant.restaurant_table AS t
JOIN restaurant.restaurant_order AS o ON o.table_id = t.table_id
JOIN restaurant.customer AS c ON c.customer_id = o.customer_id
WHERE o.status IN ('Open', 'Preparing', 'Served')
ORDER BY t.table_number, o.order_id;

-- Query 4: Which menu items are in order 1 and what is each line cost?
SELECT oi.order_id, m.item_name, oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price AS line_total
FROM restaurant.order_item AS oi
JOIN restaurant.menu_item AS m
    ON m.menu_item_id = oi.menu_item_id
WHERE oi.order_id = 1
ORDER BY oi.order_item_id;

-- Query 5: How many units of each menu item were ordered including unsold items?
SELECT m.menu_item_id, m.item_name,
       COALESCE(SUM(oi.quantity), 0) AS units_ordered
FROM restaurant.menu_item AS m
LEFT JOIN restaurant.order_item AS oi
    ON oi.menu_item_id = m.menu_item_id
GROUP BY m.menu_item_id, m.item_name
ORDER BY units_ordered DESC, m.menu_item_id;

-- Query 6: What is the ordered sales value for each menu category?
SELECT mc.category_id, mc.category_name,
       SUM(oi.quantity * oi.unit_price) AS ordered_sales
FROM restaurant.menu_category AS mc
JOIN restaurant.menu_item AS m ON m.category_id = mc.category_id
JOIN restaurant.order_item AS oi ON oi.menu_item_id = m.menu_item_id
GROUP BY mc.category_id, mc.category_name
ORDER BY ordered_sales DESC, mc.category_id;

-- Query 7: Which customers have placed more than one order?
SELECT c.customer_id, c.first_name, c.last_name,
       COUNT(o.order_id) AS total_orders
FROM restaurant.customer AS c
JOIN restaurant.restaurant_order AS o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(o.order_id) > 1
ORDER BY total_orders DESC, c.customer_id;

-- Query 8: What is each order total and how does it compare with the average?
WITH totals AS (
    SELECT order_id, SUM(quantity * unit_price) AS order_total
    FROM restaurant.order_item
    GROUP BY order_id
)
SELECT order_id, order_total,
       ROUND((SELECT AVG(order_total) FROM totals), 2) AS average_total,
       CASE WHEN order_total > (SELECT AVG(order_total) FROM totals)
            THEN 'Above average' ELSE 'At or below average'
       END AS comparison
FROM totals
ORDER BY order_id;

-- Query 9: How much has each order received and what balance remains?
WITH totals AS (
    SELECT order_id, SUM(quantity * unit_price) AS order_total
    FROM restaurant.order_item GROUP BY order_id
), paid AS (
    SELECT order_id, SUM(amount) AS amount_paid
    FROM restaurant.payment
    WHERE payment_status = 'Completed' GROUP BY order_id
)
SELECT t.order_id, t.order_total,
       COALESCE(p.amount_paid, 0) AS amount_paid,
       t.order_total - COALESCE(p.amount_paid, 0) AS balance_due
FROM totals AS t
LEFT JOIN paid AS p ON p.order_id = t.order_id
ORDER BY t.order_id;

-- Query 10: How much money was received by payment method on October 1?
SELECT payment_method, COUNT(*) AS payment_count,
       SUM(amount) AS total_received
FROM restaurant.payment
WHERE payment_status = 'Completed'
  AND payment_datetime >= TIMESTAMPTZ '2026-10-01 00:00:00-04'
  AND payment_datetime < TIMESTAMPTZ '2026-10-02 00:00:00-04'
GROUP BY payment_method
ORDER BY total_received DESC, payment_method;
