-- Restaurant Management System: Migration 001
-- Add the logic layer and customer access policies to the original schema.
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Migration date: October 23, 2026
--
-- Prerequisites: the original eight tables from schema.sql already exist.
-- Run as their owner with CREATEROLE and authority to manage the project roles.
-- This is the upgrade route. For a fresh rebuild, use EITHER this migration
-- OR the separate logic_layer.sql and security_policies.sql files, not both.
-- The definitions below mirror those component files.
-- It does not insert demo orders, change prices, or delete existing records.
-- No secondary indexes were retained; primary/unique indexes come from their
-- constraints. Run indexes.sql after loading data to inspect them.
-- Version history: 001 = views, function, audit table/trigger, roles, and RLS.

BEGIN;

-- Migration 001, section A: logic objects.

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

-- Migration 001, section B: roles, grants, and RLS.

DO $$
DECLARE
    v_role TEXT;
BEGIN
    FOREACH v_role IN ARRAY ARRAY[
        'restaurant_viewer', 'restaurant_staff',
        'restaurant_customer_a', 'restaurant_customer_b'
    ] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role) THEN
            EXECUTE format(
                'CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS',
                v_role
            );
        END IF;
        -- Role names are reserved for this project. Refuse elevated roles.
        IF EXISTS (
            SELECT 1 FROM pg_roles
            WHERE rolname = v_role
              AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls)
        ) THEN
            RAISE EXCEPTION 'Role % has unexpected capabilities; review it before installation', v_role;
        END IF;
    END LOOP;
END;
$$;

GRANT USAGE ON SCHEMA restaurant TO
    restaurant_viewer, restaurant_staff,
    restaurant_customer_a, restaurant_customer_b;

-- Viewer reads menu information. Staff changes availability only.
GRANT SELECT ON restaurant.menu_item, restaurant.menu_category
    TO restaurant_viewer;
GRANT SELECT ON restaurant.menu_item TO restaurant_staff;
GRANT UPDATE (availability_status) ON restaurant.menu_item
    TO restaurant_staff;

-- Customer laboratory roles can read the base order table, subject to RLS.
-- No access to the owner-executed summary views is granted to these roles.
GRANT SELECT ON restaurant.restaurant_order
    TO restaurant_customer_a, restaurant_customer_b;

ALTER TABLE restaurant.restaurant_order ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS customer_own_orders ON restaurant.restaurant_order;
CREATE POLICY customer_own_orders
ON restaurant.restaurant_order
FOR SELECT TO restaurant_customer_a, restaurant_customer_b
USING (
    (current_user = 'restaurant_customer_a' AND customer_id = 1)
    OR
    (current_user = 'restaurant_customer_b' AND customer_id = 2)
);

-- Allow the installing administrator to SET ROLE for laboratory verification.
-- The customer roles do not receive membership in each other.
DO $$
BEGIN
    EXECUTE format(
        'GRANT restaurant_viewer, restaurant_staff, restaurant_customer_a, restaurant_customer_b TO %I',
        current_user
    );
END;
$$;

COMMIT;
