# SQL tips and tricks

A (somewhat opinionated) list of SQL tips and tricks that I've picked up over the years in my job as a data analyst.

Please note that some of these tips might not be relevant for all RDBMs. For example, the `::` syntax ([tip 5](#you-can-use-the--operator-to-cast-the-data-type-of-a-value)) does not work in SQLite. 

## Table of contents

### Formatting/readability

1) [Use a leading comma to separate fields](#use-a-leading-comma-to-separate-fields)
2) [Use a dummy value in the WHERE clause](#use-a-dummy-value-in-the-where-clause)
3) [Indent your code where appropriate](#indent-your-code-where-appropriate)
4) [Consider CTEs when writing complex queries](#consider-ctes-when-writing-complex-queries)

### Useful features

5) [You can use the `::` operator to cast the data type of a value](#you-can-use-the--operator-to-cast-the-data-type-of-a-value)
6) [Anti-joins are your friend](#anti-joins-are-your-friend)
7) [Use `QUALIFY` to filter window functions](#use-qualify-to-filter-window-functions)
8) [You can (but shouldn't always) `GROUP BY` column position](#you-can-but-shouldnt-always-group-by-column-position)

### Avoid pitfalls

9)  [Be aware of how `NOT IN` behaves with NULL values](#be-aware-of-how-not-in-behaves-with-null-values)
10) [Rename calculated fields to avoid ambiguity](#rename-calculated-fields-to-avoiding-ambiguity)
11) [Always specify which column belongs to which table](#always-specify-which-column-belongs-to-which-table)
12) [Understand the order of execution](#understand-the-order-of-execution)
13) [Comment your code!](#comment-your-code)
14) [Read the documentation (in full)](#read-the-documentation-in-full)
15) [Use descriptive names for your saved queries](#use-descriptive-names-for-your-saved-queries)

## Formatting/readability

### Use a leading comma to separate fields

Use a leading comma to seperate fields in the `SELECT` clause rather than a trailing comma.

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

### **Use a dummy value in the WHERE clause**

Use a dummy value in the `WHERE` clause so you can dynamically add and remove conditions with ease:

```SQL
SELECT *
FROM employees
WHERE 1=1 -- Dummy value.
    AND job IN ('Clerk', 'Manager')
    AND dept_no != 5
;
```

### Indent your code where appropriate

Indent your code to make it more readable to colleagues and your future self:

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
    , IFF(
        DATEDIFF(DAY, timeslot_date, CURRENT_DATE()) > 7 -- First argument of IFF.
        , LAG(overnight_fta_share, 1) OVER (PARTITION BY timeslot_date, timeslot_channel ORDER BY timeslot_activity) -- Second argument of IFF.
        , NULL -- Third argument of IFF.
    ) AS C7_fta_share
    , IFF(
        DATEDIFF(DAY, timeslot_date, CURRENT_DATE()) >= 29
        , LAG(overnight_fta_share, 2) OVER (PARTITION BY timeslot_date, timeslot_channel ORDER BY timeslot_activity)
        , NULL
    ) AS C28_fta_share
FROM timeslot_data
;
```

### Consider CTEs when writing complex queries

For longer than I'd care to admit I would nest inline views, which would lead to
queries that were hard to understand, particularly if revisted after a few weeks.

If you find yourself nesting inline views more than 2 or 3 levels deep, 
consider using common table expressions, which can help you keep your code more organised and readable.

```SQL
/*
The following query doesn't actually need to use an inline view or CTE but I'm just
demonstrating the difference between the two.
*/

-- Using nested inline views.
SELECT
    VHS.movie
    , VHS.vhs_revenue
    , CS.cinema_revenue
FROM (
    SELECT
        movie_id
        , SUM(ticket_sales) AS cinema_revenue
    FROM tickets
    GROUP BY movie_id
) AS CS
INNER JOIN (
    SELECT 
        movie
        , movie_id
        , SUM(revenue) AS vhs_revenue
    FROM blockbuster
    GROUP BY movie, movie_id
) AS VHS
ON CS.movie_id = VHS.movie_id
;

-- Using CTEs.
WITH cinema_sales AS
    (
        SELECT 
        movie_id
        , SUM(ticket_sales) AS cinema_revenue
        FROM tickets
        GROUP BY movie_id
    ),
    vhs_sales AS
    (
        SELECT 
        movie
        , movie_id
        , SUM(revenue) AS vhs_revenue
        FROM blockbuster
        GROUP BY movie, movie_id
    )
SELECT
    VHS.movie
    , VHS.vhs_revenue
    , CS.cinema_revenue
FROM cinema_sales AS CS
INNER JOIN vhs_sales AS VHS
ON CS.movie_id = VHS.movie_id
;
```

## Useful features 

### You can use the `::` operator to cast the data type of a value 

In some RDBMs you can use the `::` operator to cast a value from one data type to another:

```SQL
SELECT CAST('5' AS INTEGER); -- Using the CAST function.
SELECT '5'::INTEGER; -- Using :: syntax.
```

### Anti-joins are your friend

Anti-joins are incredibly useful, mostly (in my experience) for when you only want to return rows/values from one table that aren't present in another table.

- You could instead use a subquery although conventional wisdom dictates that
anti-joins are faster.

- `EXCEPT` is an interesting operator for removing rows from one table which appear in another query table but I suggest you read up on it further before using it.

```SQL
-- Anti-join.
SELECT 
    video_content.*
FROM video_content
LEFT JOIN archive ON video_content.series_id = archive.series_id
WHERE 1=1
    AND archive.series_id IS NULL -- Any rows with no match will have a NULL value.

-- Subquery.
SELECT
    *
FROM video_content
WHERE 1=1
    AND series_id NOT IN (SELECT DISTINCT SERIES_ID FROM archive) -- Be mindful of NULL values (see tip 9).

-- Correlated subquery.
SELECT 
    *
FROM video_content VC
WHERE 1=1
AND NOT EXISTS (
        SELECT 1
        FROM archive A
        WHERE A.series_id = VC.series_id
    )

-- EXCEPT.
SELECT series_id
FROM video_content
EXCEPT
SELECT series_id
FROM archive
```

### Use QUALIFY to filter window functions

`QUALIFY` lets you filter the results of a query based on a window function. This is useful for a variety of reasons, including to
reduce the number of lines of code needed.

For example, if I want to return the top 10 markets per product I can use
`QUALIFY` rather than an inline view:

```SQL
-- Using QUALIFY:
SELECT 
    product
    , market
    , SUM(revenue) AS market_revenue 
FROM sales
GROUP BY product, market
QUALIFY DENSE_RANK() OVER (PARTITION BY product ORDER BY SUM(revenue) DESC)  <= 10
ORDER BY product, market_revenue
;

-- Without QUALIFY:
SELECT 
    product
    , market
    , market_revenue 
FROM (
    SELECT 
        product
        , market
        , SUM(revenue) as market_revenue
        , DENSE_RANK() OVER (PARTITION BY product ORDER BY SUM(revenue) DESC) AS market_rank
    FROM sales
    GROUP BY product, market
)
WHERE market_rank <= 10
ORDER BY product, market_revenue
;
```

### You can (but shouldn't always) `GROUP BY` column position

Instead of using the column name, you can `GROUP BY` or `ORDER BY` using the
column position.

- This can be useful for ad-hoc/one-off queries, but for production code
you should always refer to a column by its name.

```SQL
SELECT 
    dept_no
    , SUM(salary) AS dept_salary
FROM employees
GROUP BY 1 -- dept_no is the first column in the SELECT clause.
ORDER BY 2 DESC
;
```

## Common pitfalls

### Be aware of how `NOT IN` behaves with `NULL` values

`NOT IN` doesn't work if `NULL` is present in the values being checked against. As `NULL` represents Unknown the SQL engine can't verify that the value being checked is not present in the list.

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
FROM employees E
WHERE NOT EXISTS (
    SELECT 1 
    FROM departments D
    WHERE D.id = E.department_id
)
;
```

### Rename calculated fields to avoiding ambiguity 

When creating a calculated field, you might be tempted to rename it to an
existing column, but this can lead to unexpected behaviour, such as a 
window function operating on the wrong field:

```SQL
INSERT INTO products (product, revenue)
VALUES 
    ('Shark', 100)
    , ('Robot', 150)
    , ('Alien', 90);

-- The window function will rank the 'Robot' product as 1 when it should be 3.
SELECT 
    product
    , CASE product WHEN 'Robot' THEN 0 ELSE revenue END AS revenue
    , RANK() OVER (ORDER BY revenue DESC)
FROM products 
```

### Always specify which column belongs to which table

When you have complex queries with multiple joins, it pays to be able to 
trace back an issue with a value to its source. 

Additionally, your RDBMS might raise an error if two tables share the same
column name and you don't specify which column you are using.

```SQL
SELECT
    VC.video_id
    , VC.series_name
    , metadata.season
    , metadata.episode_number
FROM video_content AS VC 
INNER JOIN video_metadata AS metadata
    ON VC.video_id = metadata.video_id
```

### Understand the order of execution

If I had to give one piece of advice to someone learning SQL, it'd be to understand the order of 
execution (of clauses). It will completely change how you write queries. This [blog post](https://blog.jooq.org/a-beginners-guide-to-the-true-order-of-sql-operations/) is a fantastic resource for learning.

### Comment your code!

While in the moment you know why you did something, if you revisit
the code weeks, months or years later you might not remember.

- In general you should strive to write comments that explain why you did something, not how.

- Your colleagues and future self will thank you!

```SQL
SELECT 
    video_content.*
FROM video_content
LEFT JOIN archive -- New CMS cannot process archive video formats. 
    ON video_content.series_id = archive.series_id
WHERE 1=1
    AND archive.series_id IS NULL
```

### Read the documentation (in full)

Using Snowflake I once needed to return the latest date from a list of columns 
and so I decided to use `GREATEST()`.

What I didn't realise was that if one of the
arguments is `NULL` then the function returns `NULL`. 

If I'd read the documentation in full I'd have known! In many cases it can take just a minute or less to scan
the documentation and it will save you the headache of having to work
out why something isn't working the way you expected:

```SQL
-- If I'd read the documentation further I'd also have realised that my solution
--to the NULL problem with GREATEST()...

SELECT COALESCE(GREATEST(signup_date, consumption_date), signup_date, consumption_date)

-- ... could have been solved with the following function:
SELECT GREATEST_IGNORE_NULLS(signup_date, consumption_date)
```

### Use descriptive names for your saved queries

There's almost nothing worse than not being able to find a query you need to re-run/refer back to.

Use a descriptive name when saving your queries so you can easily find what you're looking for.

I usually will write the subject of the query, the month the query was ran and the name of the requester (if they exist).
For example: `Lapsed users analysis - 2023-09-01 - Olivia Roberts`