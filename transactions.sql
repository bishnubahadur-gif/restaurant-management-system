-- Restaurant Management System: Order Transaction Demonstration
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Prerequisites: schema.sql, seed.sql, logic_layer.sql.
-- Run this demonstration separately from database installation.
-- Each successful run creates one additional order and two order-item rows.
-- On the original seed, the first successful run creates order 4, totaling 16.00.
-- If any statement fails, run ROLLBACK before continuing.

-- TRANSACTION: Create an order and two items as one unit.
-- These are the agreed demonstration prices, not a dynamic pricing service.
-- If any statement fails, this transaction cannot commit partial writes.
-- If the client stops on an error, execute ROLLBACK before continuing.
BEGIN;
DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    INSERT INTO restaurant.restaurant_order (
        customer_id, employee_id, table_id, status
    ) VALUES (3, 2, 1, 'Open') RETURNING order_id INTO v_order_id;
    INSERT INTO restaurant.order_item (
        order_id, menu_item_id, quantity, unit_price
    ) VALUES (v_order_id, 1, 1, 6.00);
    INSERT INTO restaurant.order_item (
        order_id, menu_item_id, quantity, unit_price
    ) VALUES (v_order_id, 4, 2, 5.00);
    RAISE NOTICE 'Created order % with two items', v_order_id;
END;
$$;
COMMIT;

-- Verify order totals after the successful transaction.
SELECT order_id, restaurant.calculate_order_total(order_id) AS order_total
FROM restaurant.restaurant_order
ORDER BY order_id;

-- OPTIONAL FAILURE TEST: Select ONLY the SQL inside this comment and run it.
-- It intentionally fails. Then run ROLLBACK separately to end the failed
-- transaction. Verify counts are unchanged from the values before the test.
-- Identity sequences may advance despite rollback; gaps are normal.
/*
SELECT COUNT(*) AS orders_before FROM restaurant.restaurant_order;
SELECT COUNT(*) AS items_before FROM restaurant.order_item;
BEGIN;
DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    INSERT INTO restaurant.restaurant_order (
        customer_id, employee_id, table_id, status
    ) VALUES (3, 2, 1, 'Open') RETURNING order_id INTO v_order_id;
    INSERT INTO restaurant.order_item (
        order_id, menu_item_id, quantity, unit_price
    ) VALUES (v_order_id, 1, 1, 6.00);
    INSERT INTO restaurant.order_item (
        order_id, menu_item_id, quantity, unit_price
    ) VALUES (v_order_id, 4, 0, 5.00);
END;
$$;
*/

-- OPTIONAL RECOVERY: Run separately after the deliberate error above.
/*
ROLLBACK;
SELECT COUNT(*) AS orders_after FROM restaurant.restaurant_order;
SELECT COUNT(*) AS items_after FROM restaurant.order_item;
*/
