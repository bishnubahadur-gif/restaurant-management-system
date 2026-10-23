-- Restaurant Management System: Final Index Decisions
-- Bishnu Bahadur GC and Swastika Poudel
-- CIT 406: Database Design | Professor Anshu Sharma
-- Prerequisites: schema.sql and logic_layer.sql.
-- Run after seed.sql to refresh planner statistics and inspect installed indexes.
-- This file does not add an unproven secondary index.

-- RETAINED INDEXES
-- PostgreSQL creates an index for every PRIMARY KEY and UNIQUE constraint.
-- The definitions are maintained in schema.sql and logic_layer.sql.
-- Core primary-key indexes:
--   customer(customer_id), employee(employee_id), restaurant_table(table_id),
--   menu_category(category_id), menu_item(menu_item_id),
--   restaurant_order(order_id), order_item(order_item_id), payment(payment_id).
-- Unique constraint index:
--   restaurant_table(table_number).
-- Audit primary-key index:
--   menu_price_audit(audit_id), installed by logic_layer.sql.
-- Foreign keys do not automatically create indexes on referencing columns.

-- REMOVED CANDIDATE: idx_order_item_order_id ON restaurant.order_item(order_id).
-- Portfolio Query 4 recorded these Execution Time values:
--   Before candidate index: 2.622 ms.
--   With candidate index:   0.075 ms.
--   After index removal:    0.180 ms.
-- All three plans used a sequential scan on order_item. The candidate index
-- was not used, so the timing reduction did not demonstrate an index benefit.
-- These were single runs on a small dataset (3 customers, 4 orders, 9 lines).
-- Caching and system load can affect timings. No new secondary index was kept.
-- Existing primary-key indexes remained and served some joins.
-- Retest with larger, representative data before adding secondary indexes.

-- Refresh table statistics after loading data. This does not create indexes.
ANALYZE restaurant.customer;
ANALYZE restaurant.employee;
ANALYZE restaurant.restaurant_table;
ANALYZE restaurant.menu_category;
ANALYZE restaurant.menu_item;
ANALYZE restaurant.restaurant_order;
ANALYZE restaurant.order_item;
ANALYZE restaurant.payment;
ANALYZE restaurant.menu_price_audit;

-- Display the actual installed indexes and their definitions.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'restaurant'
ORDER BY tablename, indexname;

-- Confirm that the removed trial index is absent (expected result: NULL).
SELECT to_regclass('restaurant.idx_order_item_order_id') AS trial_index;

-- Optional manual experiment only; these statements are intentionally comments.
-- CREATE INDEX idx_order_item_order_id ON restaurant.order_item(order_id);
-- Run the identical portfolio query with EXPLAIN ANALYZE before and after.
-- DROP INDEX restaurant.idx_order_item_order_id;
-- Keep a candidate only if repeated measurements show a useful improvement.
