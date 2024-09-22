/*
Use a leading comma to seperate fields in the SELECT clause rather than a trailing comma.

Clearly defines that this is a new column vs code that's wrapped to multiple lines.

Visual cue to easily identify if the comma is missing or not. Varying line lengths makes it harder to determine.
*/
SELECT
employee_id
, employee_name
, job
, salary
FROM employees
;
