-- Restaurant Management System: Logic Layer
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Requires the restaurant tables from schema.sql.
-- Installs two views, an order-total function, and a price-audit table/trigger.
-- Does not run price updates or create demonstration orders.

BEGIN;

-- VIEW 1: Itemized orders without repeatedly writing four-table joins.
CREATE OR REPLACE VIEW restaurant.v_order_details AS
SELECT o.order_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       m.item_name, oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price AS line_total,
       oi.order_item_id
FROM restaurant.restaurant_order AS o
JOIN restaurant.customer AS c ON c.customer_id = o.customer_id
JOIN restaurant.order_item AS oi ON oi.order_id = o.order_id
JOIN restaurant.menu_item AS m ON m.menu_item_id = oi.menu_item_id;

-- VIEW 2: Order totals, completed payments, and outstanding balances.
-- Aggregate independently before joining to avoid multiplying totals.
CREATE OR REPLACE VIEW restaurant.v_order_payment_summary AS
WITH totals AS (
    SELECT order_id, SUM(quantity * unit_price) AS order_total
    FROM restaurant.order_item GROUP BY order_id
), payments AS (
    SELECT order_id, SUM(amount) AS amount_paid
    FROM restaurant.payment
    WHERE payment_status = 'Completed' GROUP BY order_id
)
SELECT o.order_id, o.status AS order_status,
       COALESCE(t.order_total, 0) AS order_total,
       COALESCE(p.amount_paid, 0) AS amount_paid,
       COALESCE(t.order_total, 0) - COALESCE(p.amount_paid, 0) AS balance_due
FROM restaurant.restaurant_order AS o
LEFT JOIN totals AS t ON t.order_id = o.order_id
LEFT JOIN payments AS p ON p.order_id = o.order_id;

-- FUNCTION: Calculate an existing order's total from historical sale prices.
CREATE OR REPLACE FUNCTION restaurant.calculate_order_total(p_order_id INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM restaurant.restaurant_order WHERE order_id = p_order_id
    ) THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id;
    END IF;
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO v_total FROM restaurant.order_item WHERE order_id = p_order_id;
    RETURN v_total;
END;
$$;

-- AUDIT: Preserve item identity, before/after prices, database role, and time.
-- Deliberately no FK to the menu: audit history can outlive the source item.
-- current_user identifies the database role, not an individual person sharing it.
CREATE TABLE IF NOT EXISTS restaurant.menu_price_audit (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    menu_item_id INTEGER NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    old_price NUMERIC(10,2) NOT NULL,
    new_price NUMERIC(10,2) NOT NULL,
    changed_by TEXT NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION restaurant.audit_menu_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO restaurant.menu_price_audit (
        menu_item_id, item_name, old_price, new_price, changed_by
    ) VALUES (NEW.menu_item_id, NEW.item_name, OLD.price, NEW.price, current_user);
    RETURN NEW;
END;
$$;

-- Replace only this project's trigger when rerunning definitions.
DROP TRIGGER IF EXISTS trg_menu_price_audit ON restaurant.menu_item;
CREATE TRIGGER trg_menu_price_audit
AFTER UPDATE OF price ON restaurant.menu_item
FOR EACH ROW
WHEN (OLD.price IS DISTINCT FROM NEW.price)
EXECUTE FUNCTION restaurant.audit_menu_price_change();

COMMIT;
