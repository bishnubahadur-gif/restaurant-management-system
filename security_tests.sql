-- Restaurant Management System: Executed Security Tests
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Prerequisites: schema.sql, seed.sql, logic_layer.sql, security_policies.sql.
-- Run the COMPLETE file in an administrator connection, outside any existing
-- transaction. The installer must be authorized to SET ROLE for the four roles.
-- Expected permission errors are caught and reported as PASS notices.
-- Unexpected results raise errors. If execution stops, run ROLLBACK; RESET ROLE;
-- before continuing. Do not replace the final ROLLBACK with COMMIT.
-- Availability changes made by these tests are rolled back.

RESET ROLE;
BEGIN;

-- Preflight: tests need the original sample records and ordinary test roles.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM restaurant.menu_item WHERE menu_item_id = 1) THEN
        RAISE EXCEPTION 'Missing sample menu item 1; load seed.sql before testing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM restaurant.restaurant_order WHERE customer_id = 1)
       OR NOT EXISTS (SELECT 1 FROM restaurant.restaurant_order WHERE customer_id = 2) THEN
        RAISE EXCEPTION 'Missing orders for sample customers 1 and 2';
    END IF;
    IF (SELECT COUNT(*) FROM pg_roles WHERE rolname IN (
          'restaurant_viewer', 'restaurant_staff',
          'restaurant_customer_a', 'restaurant_customer_b')) <> 4 THEN
        RAISE EXCEPTION 'Project roles are missing; run security_policies.sql first';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname IN (
          'restaurant_viewer', 'restaurant_staff',
          'restaurant_customer_a', 'restaurant_customer_b')
          AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls)
    ) THEN
        RAISE EXCEPTION 'A test role has unexpected elevated capabilities';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_class
        WHERE oid = 'restaurant.restaurant_order'::regclass
          AND (NOT relrowsecurity OR pg_get_userbyid(relowner) IN (
              'restaurant_customer_a', 'restaurant_customer_b'))
    ) THEN
        RAISE EXCEPTION 'RLS must be enabled and customer roles must not own orders';
    END IF;
    IF pg_has_role('restaurant_customer_a', 'restaurant_customer_b', 'MEMBER')
       OR pg_has_role('restaurant_customer_b', 'restaurant_customer_a', 'MEMBER') THEN
        RAISE EXCEPTION 'Customer roles must not have membership in each other';
    END IF;
    RAISE NOTICE 'PASS: sample records and ordinary customer test roles are ready';
END;
$$;

-- 1. Viewer permitted SELECT on menu items and categories.
SET LOCAL ROLE restaurant_viewer;
SELECT current_user AS testing_role,
       menu_item_id, item_name, price, availability_status
FROM restaurant.menu_item ORDER BY menu_item_id;
SELECT current_user AS testing_role, category_id, category_name
FROM restaurant.menu_category ORDER BY category_id;

DO $$
DECLARE v_items BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_items FROM restaurant.menu_item;
    IF v_items < 1 THEN RAISE EXCEPTION 'FAIL: viewer read returned no sample items'; END IF;
    RAISE NOTICE 'PASS: viewer can SELECT menu items (% rows)', v_items;
END;
$$;

-- 2. Viewer forbidden UPDATE: expect insufficient_privilege (SQLSTATE 42501).
DO $$
BEGIN
    BEGIN
        UPDATE restaurant.menu_item SET availability_status = 'Unavailable'
        WHERE menu_item_id = 1;
        RAISE EXCEPTION 'FAIL: viewer unexpectedly updated availability';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: viewer availability UPDATE denied (SQLSTATE 42501)';
    END;
END;
$$;

RESET ROLE;

-- 3. Staff permitted SELECT and availability UPDATE.
SET LOCAL ROLE restaurant_staff;
SELECT current_user AS testing_role,
       menu_item_id, item_name, availability_status
FROM restaurant.menu_item ORDER BY menu_item_id;

DO $$
DECLARE v_status TEXT;
BEGIN
    UPDATE restaurant.menu_item SET availability_status = 'Unavailable'
    WHERE menu_item_id = 1
    RETURNING availability_status INTO v_status;
    IF v_status IS DISTINCT FROM 'Unavailable' THEN
        RAISE EXCEPTION 'FAIL: staff availability UPDATE did not affect the sample item';
    END IF;
    RAISE NOTICE 'PASS: staff can UPDATE availability only';
END;
$$;

SELECT current_user AS testing_role, menu_item_id, item_name, availability_status
FROM restaurant.menu_item WHERE menu_item_id = 1;

-- 4. Staff forbidden price UPDATE: expect insufficient_privilege.
DO $$
BEGIN
    BEGIN
        UPDATE restaurant.menu_item SET price = price + 1.00
        WHERE menu_item_id = 1;
        RAISE EXCEPTION 'FAIL: staff unexpectedly updated a price';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: staff price UPDATE denied (SQLSTATE 42501)';
    END;
END;
$$;

RESET ROLE;

-- 5. Customer A runs an unrestricted SELECT on the base order table.
-- Fresh seed: orders 1 and 3, both belonging to customer 1.
SET LOCAL ROLE restaurant_customer_a;
SELECT current_user AS testing_role, order_id, customer_id, status
FROM restaurant.restaurant_order ORDER BY order_id;

DO $$
DECLARE v_visible BIGINT; v_other BIGINT;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE customer_id IS DISTINCT FROM 1)
    INTO v_visible, v_other FROM restaurant.restaurant_order;
    IF v_visible = 0 OR v_other <> 0 THEN
        RAISE EXCEPTION 'FAIL: Customer A saw % rows, including % other-customer rows', v_visible, v_other;
    END IF;
    RAISE NOTICE 'PASS: Customer A sees % rows and zero other-customer rows', v_visible;
END;
$$;

RESET ROLE;

-- 6. Customer B runs the SAME unrestricted SELECT on the base order table.
-- Fresh seed: order 2, belonging to customer 2.
SET LOCAL ROLE restaurant_customer_b;
SELECT current_user AS testing_role, order_id, customer_id, status
FROM restaurant.restaurant_order ORDER BY order_id;

DO $$
DECLARE v_visible BIGINT; v_other BIGINT;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE customer_id IS DISTINCT FROM 2)
    INTO v_visible, v_other FROM restaurant.restaurant_order;
    IF v_visible = 0 OR v_other <> 0 THEN
        RAISE EXCEPTION 'FAIL: Customer B saw % rows, including % other-customer rows', v_visible, v_other;
    END IF;
    RAISE NOTICE 'PASS: Customer B sees % rows and zero other-customer rows', v_visible;
END;
$$;

RESET ROLE;

-- Undo the permitted staff change and any transaction-local role settings.
ROLLBACK;
RESET ROLE;

-- Original availability and price should remain after the test transaction.
-- On the unmodified seed: Vegetable Samosa, Available, price 6.00.
SELECT current_user AS restored_role,
       menu_item_id, item_name, price, availability_status
FROM restaurant.menu_item WHERE menu_item_id = 1;

-- Capture the Customer A and Customer B Data Output results, plus the PASS
-- notices. Ordinary RLS roles, not the administrator's own SELECT, demonstrate
-- isolation. This is a database-role laboratory, not Supabase Auth integration.
