# Restaurant Management System

**Bishnu Bahadur GC and Swastika Poudel**  
Atlantis University - CIT 406: Database Design (Fall "A" 2026)  
Professor Anshu Sharma  
Final project documentation: October 23, 2026

This PostgreSQL project manages restaurant customers, employees, seating tables, menu categories, menu items, orders, order lines, and payments. It includes ten business queries, reusable views, an order-total function, menu-price auditing, an order transaction, and database-role security demonstrations.

The completed database has **eight core tables, one audit table, two views, two PL/pgSQL functions** (including the trigger function), **one audit trigger, and one customer SELECT RLS policy**. The four project roles include viewer, staff, and two customer laboratory roles.

## Repository files

| File | Purpose |
|---|---|
| `schema.sql` | Original eight tables, identity primary keys, unique table number, checks, and seven foreign keys. |
| `seed.sql` | Original sample records and identity-sequence adjustments. |
| `query_portfolio.sql` | Ten labeled business queries. |
| `logic_layer.sql` | Two views, calculation function, audit table, trigger function, and trigger. Installs objects without running demo updates. |
| `transactions.sql` | Optional order-creation demonstration and commented failure/rollback test. |
| `security_policies.sql` | Four NOLOGIN roles, least-privilege grants, and the order SELECT RLS policy. |
| `indexes.sql` | Statistics refresh, installed-index inspection, and reasons for removing the unproven trial index. |
| `migrations.sql` | Migration 001: upgrades the original eight-table schema with the logic and security definitions. Alternative to running the two component installers. |
| `verification.sql` | Read-only checks of objects, constraints, sample counts, totals, and security configuration. |
| `security_tests.sql` | Permitted/denied role tests and customer row-isolation tests, rolled back afterward. |
| `data_dictionary.md` | All nine tables and 47 stored columns, view outputs, defaults, constraints, and business-rule limits. |
| `erd.md` | Updated Mermaid ERD matching the installed tables and foreign keys. Open the rendered file on GitHub to view it. |
| `README.md` | Build order, prerequisites, expected results, migration instructions, and limitations. |

## Prerequisites

1. A PostgreSQL database, either locally hosted or a Supabase project, with PL/pgSQL available.
2. A database owner/administrator connection that can create the `restaurant` schema, tables, functions, triggers, and policies. The installer also needs `CREATEROLE` and authority to manage/grant the four project roles. A login with only ordinary read/write access is insufficient.
3. pgAdmin, the Supabase SQL editor, or the PostgreSQL `psql` client.
4. Download and extract this repository from GitHub, or clone it. Keep the SQL files together.
5. For a fresh build, use a database where the `restaurant` schema has not already been installed. Other existing schemas are not deleted by these scripts. Project role names must be unused or belong to this same coursework project and have the documented capabilities.

Use your own connection settings. Passwords, service keys, and connection secrets do not belong in this repository. The customer laboratory roles do not need passwords because they are NOLOGIN roles tested through an administrator connection.

## Fresh rebuild using pgAdmin or a SQL editor

Connect as the administrator. Open and execute each **complete file**, in this order. Wait for each file to finish successfully before continuing.

| Order | File | Expected effect |
|---|---|---|
| 1 | `schema.sql` | Creates the eight core tables and their constraints. |
| 2 | `seed.sql` | Inserts the original sample records and advances identity sequences. Run once on the fresh tables. |
| 3 | `logic_layer.sql` | Adds the audit table, two views, calculation function, trigger function, and audit trigger. |
| 4 | `security_policies.sql` | Creates/checks roles, grants permissions, enables order RLS, and creates the customer policy. |
| 5 | `indexes.sql` | Refreshes statistics and lists the retained constraint indexes. Adds no secondary index. |
| 6 | `verification.sql` | Displays read-only checks described below. |
| 7 | `security_tests.sql` | Tests permissions and different customer results, then rolls back its availability changes. |
| 8 | `query_portfolio.sql` | Executes the ten business queries. Run as the owner/administrator so all sample orders are visible. |

**Do not run `migrations.sql` in addition to steps 3 and 4.** It is the alternative upgrade route below. **Do not run `transactions.sql` as part of the initial seed load.** It deliberately creates another order each time its success example runs.

If a statement fails, stop and inspect the message. If the session is in a failed transaction, run `ROLLBACK;` before continuing. `schema.sql` and `seed.sql` are one-time fresh-install scripts, not reset scripts. Do not rerun them over the existing sample tables. Reproduce a clean build in another empty database when needed; these instructions do not require deleting a working project.

## Fresh rebuild using psql

Open a terminal in the extracted repository directory. Replace HOST, PORT, DATABASE, and ADMIN with your own connection settings. For Supabase, use the database connection settings supplied for your project, not an API key. The command prompts for your database password.

```sh
psql -X -W -v ON_ERROR_STOP=1 "host=HOST port=PORT dbname=DATABASE user=ADMIN sslmode=require" -f schema.sql -f seed.sql -f logic_layer.sql -f security_policies.sql -f indexes.sql -f verification.sql -f security_tests.sql -f query_portfolio.sql
```

For a local PostgreSQL server without TLS configured, change `sslmode=require` to `sslmode=prefer`. `-X` avoids local psql startup customizations, and `ON_ERROR_STOP=1` stops processing when an error occurs. Each installer manages its own transaction; the entire multi-file command is not one transaction. If it stops after earlier files committed, inspect which files completed before resuming.

## Migration / existing-project route

Migration 001 is for the original eight-table project. It does not recreate or delete the core tables or reload sample records. It mirrors the definitions in `logic_layer.sql` and `security_policies.sql`.

1. Confirm that the original `schema.sql` tables already exist.
2. Run `migrations.sql` once as an administrator. Its logic and security changes are inside one transaction.
3. Run `indexes.sql`, then `verification.sql` and `security_tests.sql`.
4. Do not reload `seed.sql` into tables containing the original sample IDs.
5. Record the migration application in your project change notes. This project uses one numbered SQL migration and does not include an automatic migration runner or migration-history table.

For an empty database, the alternative valid sequence is `schema.sql`, `seed.sql`, `migrations.sql`, `indexes.sql`, and the verification files. Choose this sequence **or** the component sequence above. If updating the definitions in the future, keep the migration snapshot and documentation consistent or add a new numbered migration.

## Expected fresh-build results

Immediately after the initial build, before running optional demonstrations:

| Table | Rows |
|---|---:|
| customer | 3 |
| employee | 3 |
| restaurant_table | 3 |
| menu_category | 3 |
| menu_item | 5 |
| restaurant_order | 3 |
| order_item | 7 |
| payment | 5 |
| menu_price_audit | 0 |

`verification.sql` should report nine base tables, two views, the two named functions, one audit trigger, one order SELECT policy, and four project roles with no elevated capabilities. The fresh schema normally has ten constraint indexes: nine primary-key indexes and the unique table-number index. The removed candidate `restaurant.idx_order_item_order_id` should be absent.

The function call below returns **46.00**:

```sql
SELECT restaurant.calculate_order_total(1);
```

The payment summary contains:

| Order | Total | Completed payments | Balance |
|---|---:|---:|---:|
| 1 | 46.00 | 46.00 | 0.00 |
| 2 | 29.00 | 10.00 | 19.00 |
| 3 | 19.00 | 19.00 | 0.00 |

Ordered value totals **94.00**, completed payments total **75.00**, and the unpaid balance totals **19.00**. Pending payments do not count as receipts. Existing databases may have more records after demonstrations; use the catalog checks and current results rather than assuming their counts still match a fresh seed.

## Security test expectations

`security_tests.sql` runs permitted and denied operations as the ordinary project roles. Expected permission errors are caught and reported as passing checks; an unexpectedly successful forbidden operation makes the test fail. Its transaction ends with ROLLBACK so menu availability is restored.

- Viewer: menu SELECT succeeds; availability UPDATE is denied.
- Staff: menu SELECT and availability UPDATE succeed; price UPDATE is denied.
- Customer A: only customer 1's orders are visible (orders 1 and 3 in the original sample).
- Customer B: only customer 2's orders are visible (order 2 in the original sample).
- Both customer tests read the base order table without a customer WHERE filter. The policy performs row filtering.

The installing administrator receives membership so it can `SET ROLE` for testing. Customer roles are not members of each other. RLS tests must use these ordinary roles: superusers, BYPASSRLS roles, and normally the table owner bypass RLS. The current policy is a fixed database-role laboratory and **does not implement Supabase Auth**. Customer roles receive no access to the owner-executed views. Do not treat these scripts as a complete application authentication system.

## Optional transaction and audit demonstrations

After verifying the fresh build, you may run `transactions.sql` separately. On the original seed, its first successful run creates order 4 for customer 3, with two order lines totaling **16.00**. The database then contains four orders and nine order items. Each additional successful run adds another order and two lines.

The failure example in that file is commented out deliberately. Select only the SQL inside that example and execute it. It attempts a line with quantity zero and should fail. Then execute the separate commented recovery block containing `ROLLBACK;` and count verification. No header or lines from the failed transaction should remain. Identity values may be skipped after rollback.

To test the price audit separately, run this example as administrator. It restores the original price, while committing two audit entries:

```sql
BEGIN;
UPDATE restaurant.menu_item SET price = price + 1.00 WHERE menu_item_id = 2;
UPDATE restaurant.menu_item SET price = price - 1.00 WHERE menu_item_id = 2;
COMMIT;
SELECT * FROM restaurant.menu_price_audit ORDER BY audit_id;
```

`current_user` records the database role. It does not distinguish individual people using a shared login. The audit entry and its update belong to the same transaction, so a rollback also removes that transaction's audit entry.

## Index decisions and query performance

Primary-key and unique-constraint indexes are defined by the constraints in the schema/logic files. No additional secondary index was retained. A trial on `order_item(order_id)` recorded Query 4 execution times of 2.622 ms before the candidate, 0.075 ms with it, and 0.180 ms after removal. The candidate was not used: `order_item` still had a sequential scan. The difference therefore did not demonstrate an index benefit.

Those measurements used a small coursework dataset after the transaction demonstration (three customers, four orders, nine lines) and were single runs. Fresh-build timings will differ. Prefix each portfolio SELECT, including queries beginning with WITH, with `EXPLAIN ANALYZE` to collect a current plan. Compare repeated runs on representative data before retaining any new index. `indexes.sql` refreshes statistics and displays actual definitions without forcing an index choice.

## Design decisions and limits

- Line totals are `quantity * unit_price`; order totals are sums of line totals. They are not stored in the core tables.
- Historical order-item prices remain independent of current menu prices.
- All seven foreign keys use DELETE RESTRICT to preserve referenced history and UPDATE CASCADE to propagate corrected keys.
- The audit table has no menu-item FK, so the stored item identity and name remain historical snapshots.
- A confirmed order should contain items, but the current foreign keys do not enforce a minimum line count for every possible write path. The transaction file demonstrates atomic header-and-line creation.
- Table status and order status do not automatically synchronize. Complete status transitions and seating conflicts need further workflow rules.
- The current payment calculation excludes non-Completed records. Net refunds, taxes, tips, discounts, overpayment controls, inventory, recipe costs, payroll, and profit reporting require additional design work.

Read [the data dictionary](data_dictionary.md) for column-level detail and [the ERD](erd.md) for the exact built relationships.
