-- Restaurant Management System: Read-Only Verification
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Run as the installing administrator after the rebuild files.
-- Run the entire file. It changes no records or permissions.
-- Missing objects may cause an error: stop and check the earlier build steps.

-- 1. Installed object counts. These expected counts describe this project.
WITH observed AS (
    SELECT 'Base tables' AS object_type, COUNT(*) AS actual, 9::BIGINT AS expected
    FROM information_schema.tables
    WHERE table_schema = 'restaurant' AND table_type = 'BASE TABLE'
    UNION ALL
    SELECT 'Views', COUNT(*), 2
    FROM information_schema.views WHERE table_schema = 'restaurant'
    UNION ALL
    SELECT 'Named logic functions', COUNT(*), 2
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'restaurant'
      AND p.proname IN ('calculate_order_total', 'audit_menu_price_change')
    UNION ALL
    SELECT 'Audit trigger', COUNT(*), 1
    FROM pg_trigger AS t
    JOIN pg_class AS c ON c.oid = t.tgrelid
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'restaurant' AND NOT t.tgisinternal
      AND t.tgname = 'trg_menu_price_audit'
    UNION ALL
    SELECT 'Customer SELECT policy', COUNT(*), 1
    FROM pg_policies
    WHERE schemaname = 'restaurant' AND tablename = 'restaurant_order'
      AND policyname = 'customer_own_orders' AND cmd = 'SELECT'
    UNION ALL
    SELECT 'Project roles', COUNT(*), 4
    FROM pg_roles
    WHERE rolname IN ('restaurant_viewer', 'restaurant_staff',
                      'restaurant_customer_a', 'restaurant_customer_b')
)
SELECT object_type, actual, expected, actual = expected AS matches_expected
FROM observed ORDER BY object_type;

-- 2. Sample counts. Exact fresh-build counts change after optional demos.
WITH counts AS (
    SELECT 'customer' AS table_name, COUNT(*) AS actual, 3::BIGINT AS fresh_expected
    FROM restaurant.customer
    UNION ALL SELECT 'employee', COUNT(*), 3 FROM restaurant.employee
    UNION ALL SELECT 'restaurant_table', COUNT(*), 3 FROM restaurant.restaurant_table
    UNION ALL SELECT 'menu_category', COUNT(*), 3 FROM restaurant.menu_category
    UNION ALL SELECT 'menu_item', COUNT(*), 5 FROM restaurant.menu_item
    UNION ALL SELECT 'restaurant_order', COUNT(*), 3 FROM restaurant.restaurant_order
    UNION ALL SELECT 'order_item', COUNT(*), 7 FROM restaurant.order_item
    UNION ALL SELECT 'payment', COUNT(*), 5 FROM restaurant.payment
    UNION ALL SELECT 'menu_price_audit', COUNT(*), 0 FROM restaurant.menu_price_audit
)
SELECT table_name, actual, fresh_expected,
       actual = fresh_expected AS matches_fresh_seed
FROM counts ORDER BY table_name;

-- 3. Full stored-column inventory for comparison with data_dictionary.md.
-- Expected: 47 columns across the nine base tables, excluding view outputs.
SELECT c.table_name, c.ordinal_position, c.column_name, c.data_type,
       c.character_maximum_length, c.numeric_precision, c.numeric_scale,
       c.is_nullable, c.column_default, c.is_identity, c.identity_generation
FROM information_schema.columns AS c
JOIN information_schema.tables AS t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema = 'restaurant' AND t.table_type = 'BASE TABLE'
ORDER BY c.table_name, c.ordinal_position;

-- 4. Constraints, including checks, keys, and exact referential actions.
SELECT c.relname AS table_name, con.conname AS constraint_name,
       con.contype AS constraint_type,
       pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint AS con
JOIN pg_class AS c ON c.oid = con.conrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'restaurant'
ORDER BY c.relname, con.contype, con.conname;

-- Expected: seven foreign keys, all DELETE RESTRICT and UPDATE CASCADE.
SELECT COUNT(*) AS foreign_keys,
       COUNT(*) FILTER (WHERE con.confdeltype = 'r' AND con.confupdtype = 'c')
           AS restrict_delete_cascade_update,
       COUNT(*) = 7 AND
       COUNT(*) FILTER (WHERE con.confdeltype = 'r' AND con.confupdtype = 'c') = 7
           AS all_expected_actions
FROM pg_constraint AS con
JOIN pg_namespace AS n ON n.oid = con.connamespace
WHERE n.nspname = 'restaurant' AND con.contype = 'f';

-- 5. Function and views. Original order 1 should return 46.00.
SELECT restaurant.calculate_order_total(1) AS order_1_total,
       restaurant.calculate_order_total(1) = 46.00 AS matches_original_order_1;

SELECT * FROM restaurant.v_order_details ORDER BY order_id, order_item_id;
SELECT * FROM restaurant.v_order_payment_summary ORDER BY order_id;

-- Original three-order totals: 94.00 ordered, 75.00 completed, 19.00 balance.
-- Restricting to original IDs keeps this comparison meaningful after the demo
-- adds an order. Changed original seed records will change these values.
SELECT SUM(order_total) AS original_ordered_value,
       SUM(amount_paid) AS original_completed_payments,
       SUM(balance_due) AS original_balance_due,
       SUM(order_total) = 94.00 AND SUM(amount_paid) = 75.00
           AND SUM(balance_due) = 19.00 AS matches_original_sample
FROM restaurant.v_order_payment_summary WHERE order_id IN (1, 2, 3);

-- 6. Audit configuration and any existing audit records.
SELECT t.tgname, t.tgenabled, pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger AS t
WHERE t.tgrelid = 'restaurant.menu_item'::regclass
  AND NOT t.tgisinternal AND t.tgname = 'trg_menu_price_audit';
SELECT * FROM restaurant.menu_price_audit ORDER BY audit_id;

-- 7. Actual indexes. Fresh build: ten constraint indexes, no trial index.
SELECT tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'restaurant' ORDER BY tablename, indexname;
SELECT to_regclass('restaurant.idx_order_item_order_id') IS NULL
       AS removed_trial_index_is_absent;

-- 8. Roles should have no login, superuser, role-creation, DB-creation, or
-- RLS-bypass capabilities. Membership and effective permissions are tested
-- separately by security_tests.sql.
SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolbypassrls,
       NOT (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls)
           AS expected_capabilities
FROM pg_roles
WHERE rolname IN ('restaurant_viewer', 'restaurant_staff',
                  'restaurant_customer_a', 'restaurant_customer_b')
ORDER BY rolname;

-- RLS enabled should be true. FORCE RLS is not used in this laboratory.
SELECT n.nspname AS schema_name, c.relname AS table_name,
       c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS force_rls
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'restaurant' AND c.relname = 'restaurant_order';
SELECT policyname, roles, cmd, qual FROM pg_policies
WHERE schemaname = 'restaurant' AND tablename = 'restaurant_order';

-- 9. Effective grants should match the documented responsibilities.
SELECT 'Viewer reads menu' AS test,
       has_table_privilege('restaurant_viewer', 'restaurant.menu_item', 'SELECT')
           AS matches_expected
UNION ALL
SELECT 'Viewer cannot update availability',
       NOT has_column_privilege('restaurant_viewer', 'restaurant.menu_item',
                                'availability_status', 'UPDATE')
UNION ALL
SELECT 'Staff reads menu',
       has_table_privilege('restaurant_staff', 'restaurant.menu_item', 'SELECT')
UNION ALL
SELECT 'Staff updates availability',
       has_column_privilege('restaurant_staff', 'restaurant.menu_item',
                            'availability_status', 'UPDATE')
UNION ALL
SELECT 'Staff cannot update price',
       NOT has_column_privilege('restaurant_staff', 'restaurant.menu_item',
                                'price', 'UPDATE')
UNION ALL
SELECT 'Customer A SELECT grant',
       has_table_privilege('restaurant_customer_a', 'restaurant.restaurant_order', 'SELECT')
UNION ALL
SELECT 'Customer B SELECT grant',
       has_table_privilege('restaurant_customer_b', 'restaurant.restaurant_order', 'SELECT');

-- Continue with security_tests.sql to execute the allowed/denied operations
-- and prove that the two ordinary customer roles receive different rows.
