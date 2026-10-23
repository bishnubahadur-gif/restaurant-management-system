-- Restaurant Management System: Roles, Privileges, and Row Level Security
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Run after schema.sql and logic_layer.sql as the database administrator.
-- The installer needs CREATEROLE and authority to manage these project roles.
-- NOLOGIN roles are tested with SET ROLE from an authorized administrator.
-- This laboratory maps database roles to sample customer IDs; it does not
-- implement Supabase Auth. Do not grant customer roles to application users.

BEGIN;

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

-- Read-only installation checks (run as administrator).
SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolbypassrls
FROM pg_roles
WHERE rolname IN (
    'restaurant_viewer', 'restaurant_staff',
    'restaurant_customer_a', 'restaurant_customer_b'
)
ORDER BY rolname;

SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'restaurant'
  AND tablename = 'restaurant_order';
