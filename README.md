# SQL tips and tricks

A (somewhat opinionated) list of SQL tips and tricks I've picked up over the years.

Feel free to contribute your own by opening a pull requests!

## Table of contents

- [Use a leading comma to seperate fields](#use-a-leading-comma-to-separate-fields)
- [Use a dummy value in the WHERE clause](#use-a-dummy-value-in-the-where-clause)
- [Ident your code where appropriate](#ident-your-code-where-appropriate)
- [Be aware of how NOT IN behaves with NULL values](#be-aware-of-how-not-in-behaves-with-null-values)
- [Rename calculated fields to avoid ambiguity](#rename-calculated-fields-to-avoiding-ambiguity)

## Use a leading comma to separate fields

- Use a leading comma to seperate fields in the `SELECT` clause rather than a trailing comma.

    - Clearly defines that this is a new column vs code that's wrapped to multiple lines.
    
    - Visual cue to easily identify if the comma is missing or not. Varying line lengths makes it harder to determine.
 
```SQL
SELECT
employee_id
, employee_name
, job
, salary
FROM employees
;
```

- Also use a leading `AND` in the `WHERE` clause, for the same reasons (following tip demonstrates this). 

## **Use a dummy value in the WHERE clause**
- Use a dummy value in the `WHERE` clause so you can dynamically add and remove conditions with ease:
```SQL
SELECT *
FROM employees
WHERE 1=1 -- Dummy value.
AND job in ('Clerk', 'Manager')
AND dept_no != 5
;
```

## Ident your code where appropriate
- Indent your code to make it more readable to colleagues and your future self:
``` SQL
-- Bad:
SELECT 
timeslot_date
, timeslot_channel 
, overnight_fta_share
, IFF(DATEDIFF(DAY, timeslot_date, CURRENT_DATE()) > 7, LAG(overnight_fta_share, 1) OVER (PARTITION BY timeslot_date, timeslot_channel ORDER BY timeslot_activity), NULL) AS C7_fta_share
, IFF(DATEDIFF(DAY, timeslot_date, CURRENT_DATE()) >= 29, LAG(overnight_fta_share, 2) OVER (PARTITION BY timeslot_date, timeslot_channel ORDER BY timeslot_activity), NULL) AS C28_fta_share
FROM timeslot_data
;

-- Good:
SELECT 
timeslot_date
, timeslot_channel 
, overnight_fta_share
, IFF(DATEDIFF(DAY, timeslot_date, CURRENT_DATE()) > 7, -- First argument of IFF.
	LAG(overnight_fta_share, 1) OVER (PARTITION BY timeslot_date, timeslot_channel ORDER BY timeslot_activity), -- Second argument of IFF.
		NULL) AS C7_fta_share -- Third argument of IFF.
, IFF(DATEDIFF(DAY, timeslot_date, CURRENT_DATE()) >= 29, 
		LAG(overnight_fta_share, 2) OVER (PARTITION BY timeslot_date, timeslot_channel ORDER BY timeslot_activity), 
			NULL) AS C28_fta_share
FROM timeslot_data
;
```

## Be aware of how `NOT IN` behaves with `NULL` values

- `NOT IN` doesn't work if `NULL` is present in the values being checked against. As `NULL` represents Unknown the SQL engine can't verify that the value being checked is not present in the list.
  - Instead use `NOT EXISTS`.

``` SQL
INSERT INTO departments (id)
VALUES (1), (2), (NULL);

-- Doesn't work due to NULL being present.
SELECT * 
FROM employees 
WHERE department_id NOT IN (SELECT DISTINCT id from departments)

-- Solution.
SELECT * 
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 
    FROM departments d 
    WHERE d.id = e.department_id
)
;
```

## Rename calculated fields to avoiding ambiguity 

- When creating a calculated field you might be tempted to rename it to an
existing column but this can lead to unexpected behaviour, such as a 
window function operating on the wrong field:

```SQL
INSERT INTO products (product, revenue)
VALUES 
    ('Shark', 100),
    ('Robot', 150),
    ('Alien', 90);

-- The window function will rank the 'Robot' product as 1 when it should be 3
SELECT 
product
, CASE product WHEN 'Robot' THEN 0 ELSE revenue END AS revenue
, RANK() OVER (ORDER BY revenue DESC)
FROM products 
```
