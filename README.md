# SQL tips and tricks

A (somewhat opinionated) list of SQL tips and tricks I've picked up over the years.

Feel free to contribute your own by opening a pull requests!

## Table of contents

- [Use a leading comma to seperate fields](#use-a-leading-comma-to-separate-fields)

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
```

- Also use a leading `AND` in the `WHERE` clause, for the same reasons (following tip demonstrates this). 

## **Use a dummy value in the WHERE clause**
- Use a dummy value in the `WHERE` clause so you can dynamically add and remove conditions with ease:
```SQL
SELECT *
FROM employees
WHERE 1=1 -- Dummy value.
AND job in ('Clerk', 'Manager')
AND DEPT_NO != 5
;
```

## Ident your code
- Indent your code to make it more readable to colleagues and your future self:
``` SQL
-- Bad:
SELECT 
TIMESLOT_DATE
, TIMESLOT_CHANNEL 
, OVERNIGHT_FTA_SHARE
, IFF(DATEDIFF(DAY, TIMESLOT_DATE, CURRENT_DATE()) > 7, LAG(OVERNIGHT_FTA_SHARE, 1) OVER (PARTITION BY TIMESLOT_DATE, TIMESLOT_CHANNEL ORDER BY TIMESLOT_ACTIVITY), NULL) AS C7_FTA_SHARE
, IFF(DATEDIFF(DAY, TIMESLOT_DATE, CURRENT_DATE()) >= 29, LAG(OVERNIGHT_FTA_SHARE, 2) OVER (PARTITION BY TIMESLOT_DATE, TIMESLOT_CHANNEL ORDER BY TIMESLOT_ACTIVITY), NULL) AS C28_FTA_SHARE
;

-- Good:
SELECT 
TIMESLOT_DATE
, TIMESLOT_CHANNEL 
, OVERNIGHT_FTA_SHARE
, IFF(DATEDIFF(DAY, TIMESLOT_DATE, CURRENT_DATE()) > 7, -- First argument.
	LAG(OVERNIGHT_FTA_SHARE, 1) OVER (PARTITION BY TIMESLOT_DATE, TIMESLOT_CHANNEL ORDER BY TIMESLOT_ACTIVITY), -- Second argument.
		NULL) AS C7_FTA_SHARE -- Third argument.
, IFF(DATEDIFF(DAY, TIMESLOT_DATE, CURRENT_DATE()) >= 29, 
		LAG(OVERNIGHT_FTA_SHARE, 2) OVER (PARTITION BY TIMESLOT_DATE, TIMESLOT_CHANNEL ORDER BY TIMESLOT_ACTIVITY), 
			NULL) AS C28_FTA_SHARE
FROM timeslot_data
;
```

## Be aware of how NOT IN behaves with NULL values

- `NOT IN` doesn't work with `NULL` values as `NULL` means Unknown and so SQL can't verify that the value being checked isn't in in the data.
  - Instead use `NOT EXISTS`
  - With `IN (SELECT * FROM TRAVELLERS)` it doesn't matter if one of the values is Unknown, as we only need one of the values to evaluate to True.

``` SQL
-- Doesn't work due to NULL being present in travellers.
SELECT *
FROM tourists 
WHERE username NOT IN (SELECT * FROM TRAVELLERS)

-- Solution.
SELECT *
FROM tourists AS a
WHERE NOT EXISTS
(
SELECT 1
FROM travellers AS b
WHERE a.USERNAME = b.USERNAME
)
```
