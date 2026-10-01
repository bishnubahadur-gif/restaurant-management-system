-- Restaurant Management System
-- Group: Swastika Poudel and Bishnu Bahadur GC
-- CIT 406: Database Design (Fall "A" 2026)
-- Professor: Anshu Sharma
-- Date: October 1, 2026
-- Sample data only. Run schema.sql first, then run this file once.

BEGIN;

INSERT INTO restaurant.customer
    (customer_id, first_name, last_name, phone, email)
VALUES
    (1, 'Aarav', 'Sharma', '305-555-0101', 'aarav@example.com'),
    (2, 'Maya', 'Poudel', '305-555-0102', 'maya@example.com'),
    (3, 'Daniel', 'Garcia', '305-555-0103', 'daniel@example.com');

INSERT INTO restaurant.employee
    (employee_id, first_name, last_name, role, phone)
VALUES
    (1, 'Priya', 'Thapa', 'Manager', '305-555-0111'),
    (2, 'James', 'Wilson', 'Server', '305-555-0112'),
    (3, 'Sofia', 'Lopez', 'Cashier', '305-555-0113');

INSERT INTO restaurant.restaurant_table
    (table_id, table_number, seating_capacity, status)
VALUES
    (1, 1, 2, 'Available'),
    (2, 2, 4, 'Occupied'),
    (3, 3, 6, 'Reserved');

INSERT INTO restaurant.menu_category
    (category_id, category_name, description)
VALUES
    (1, 'Appetizers', 'Small dishes served before the main meal'),
    (2, 'Main Courses', 'Main dishes'),
    (3, 'Beverages', 'Hot and cold drinks');

INSERT INTO restaurant.menu_item
    (menu_item_id, category_id, item_name,
     description, price, availability_status)
VALUES
    (1, 1, 'Vegetable Samosa', 'Two vegetable samosas', 6.00, 'Available'),
    (2, 2, 'Chicken Curry', 'Chicken curry with rice', 15.00, 'Available'),
    (3, 2, 'Vegetable Fried Rice', 'Rice with mixed vegetables', 12.00, 'Available'),
    (4, 3, 'Mango Lassi', 'Mango yogurt drink', 5.00, 'Available'),
    (5, 3, 'Masala Tea', 'Spiced milk tea', 3.00, 'Unavailable');

INSERT INTO restaurant.restaurant_order
    (order_id, customer_id, employee_id, table_id,
     order_datetime, status)
VALUES
    (1, 1, 2, 1, '2026-10-01 12:00:00-04', 'Completed'),
    (2, 2, 2, 2, '2026-10-01 13:00:00-04', 'Served'),
    (3, 1, 1, 1, '2026-10-01 14:00:00-04', 'Completed');

-- Preserve agreed sale prices independently of current menu prices.
-- Order 3 demonstrates a historical $14 Chicken Curry sale price.
INSERT INTO restaurant.order_item
    (order_item_id, order_id, menu_item_id, quantity, unit_price)
VALUES
    (1, 1, 1, 1, 6.00),
    (2, 1, 2, 2, 15.00),
    (3, 1, 4, 2, 5.00),
    (4, 2, 3, 2, 12.00),
    (5, 2, 4, 1, 5.00),
    (6, 3, 2, 1, 14.00),
    (7, 3, 4, 1, 5.00);

-- Order 1: total $46, paid in full.
-- Order 2: total $29, completed payment $10, remaining balance $19.
-- Pending payments are excluded from received money.
-- Order 3: total $19, paid through two completed payments.
INSERT INTO restaurant.payment
    (payment_id, order_id, payment_datetime,
     amount, payment_method, payment_status)
VALUES
    (1, 1, '2026-10-01 12:45:00-04', 46.00, 'Card', 'Completed'),
    (2, 2, '2026-10-01 13:30:00-04', 10.00, 'Cash', 'Completed'),
    (3, 2, '2026-10-01 13:35:00-04', 19.00, 'Card', 'Pending'),
    (4, 3, '2026-10-01 14:30:00-04', 10.00, 'Cash', 'Completed'),
    (5, 3, '2026-10-01 14:31:00-04', 9.00, 'Digital Wallet', 'Completed');

-- Advance identity sequences after inserting explicit sample IDs.
SELECT setval(
    pg_get_serial_sequence('restaurant.customer', 'customer_id'),
    (SELECT MAX(customer_id) FROM restaurant.customer)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.employee', 'employee_id'),
    (SELECT MAX(employee_id) FROM restaurant.employee)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.restaurant_table', 'table_id'),
    (SELECT MAX(table_id) FROM restaurant.restaurant_table)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.menu_category', 'category_id'),
    (SELECT MAX(category_id) FROM restaurant.menu_category)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.menu_item', 'menu_item_id'),
    (SELECT MAX(menu_item_id) FROM restaurant.menu_item)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.restaurant_order', 'order_id'),
    (SELECT MAX(order_id) FROM restaurant.restaurant_order)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.order_item', 'order_item_id'),
    (SELECT MAX(order_item_id) FROM restaurant.order_item)
);
SELECT setval(
    pg_get_serial_sequence('restaurant.payment', 'payment_id'),
    (SELECT MAX(payment_id) FROM restaurant.payment)
);

COMMIT;

-- Verify record counts after loading sample data.
SELECT 'customer' AS table_name, COUNT(*) AS row_count
FROM restaurant.customer
UNION ALL
SELECT 'employee', COUNT(*) FROM restaurant.employee
UNION ALL
SELECT 'restaurant_table', COUNT(*) FROM restaurant.restaurant_table
UNION ALL
SELECT 'menu_category', COUNT(*) FROM restaurant.menu_category
UNION ALL
SELECT 'menu_item', COUNT(*) FROM restaurant.menu_item
UNION ALL
SELECT 'restaurant_order', COUNT(*) FROM restaurant.restaurant_order
UNION ALL
SELECT 'order_item', COUNT(*) FROM restaurant.order_item
UNION ALL
SELECT 'payment', COUNT(*) FROM restaurant.payment
ORDER BY table_name;
