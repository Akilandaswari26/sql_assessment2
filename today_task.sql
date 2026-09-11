create database session_reconstruct

use session_reconstruct



create table clickstream(event_id int, user_id int, event_time datetime, event_type varchar(200))

select * from clickstream

insert into clickstream(event_id, user_id, event_time, event_type)values
(1,101,'2026-09-09 09:00:00', 'page_view'),
(2,101,'2026-09-09 09:05:00','click'),
(3,101,'2026-09-09 09:15:00','page_view'),
(4,101,'2026-09-09 09:25:00','add_to_cart'),
(5,101,'2026-09-09 10:00:00','page_view'),
(6,101, '2026-09-09 10:10:00','click'),
(7, 101,'2026-09-09 11:00:00','page_view'),
(8,101,'2026-09-09 11:05:00','purchase'),
(9, 102, '2026-09-09 09:00:00', 'page_view'),
(10, 102, '2026-09-09 09:10:00', 'click'),
(11, 102, '2026-09-09 09:20:00', 'page_view'),
(12, 102, '2026-09-09 10:00:00', 'page_view'),
(13, 102, '2026-09-09 10:05:00', 'purchase'),
(14, 103, '2026-09-09 08:00:00', 'page_view'),
(15, 103, '2026-09-09 08:29:00', 'click'),
(16, 103, '2026-09-09 08:59:00', 'page_view'),
(17, 103, '2026-09-09 09:10:00', 'click')

select * from clickstream order by user_id,event_time


-- using CTE 

--complete process : find previous event >>> mark new session >>> generate session number >>>session start,end, duration:

WITH EventGaps AS (
    SELECT
        user_id,
        event_time,

        LAG(event_time) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS previous_event_time

    FROM clickstream
),

SessionFlags AS (
    SELECT
        user_id,
        event_time,

        CASE
            WHEN previous_event_time IS NULL
                 OR DATEDIFF(
                     MINUTE,
                     previous_event_time,
                     event_time
                 ) >= 30
            THEN 1
            ELSE 0
        END AS new_session

    FROM EventGaps
),

SessionNumbers AS (
    SELECT
        user_id,
        event_time,

        SUM(new_session) OVER (
            PARTITION BY user_id
            ORDER BY event_time
            ROWS UNBOUNDED PRECEDING
        ) AS session_id

    FROM SessionFlags
)

SELECT
    user_id,
    session_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    DATEDIFF(
        MINUTE,
        MIN(event_time),
        MAX(event_time)
    ) AS duration_minutes

FROM SessionNumbers

GROUP BY
    user_id,
    session_id

ORDER BY
    user_id,
    session_start;


--Q1 : Find the longest streak of consecutive days each user was active 

create table user_logins(
user_id int, login_date date) 


insert into user_logins(user_id, login_date) values
(101, '2026-09-01'),
(101, '2026-09-02'),
(101, '2026-09-03'),
(101, '2026-09-05'),
(101, '2026-09-06'),
(102, '2026-09-01'),
(102, '2026-09-03'),
(102, '2026-09-04'),
(102, '2026-09-05'),
(102, '2026-09-08'),
(103, '2026-09-10'),
(103, '2026-09-11'),
(103, '2026-09-12'),
(103, '2026-09-13'),
(103, '2026-09-15')

select * from user_logins order by user_id, login_date


--process : row number >>> identify island >>> group by >>> longest streak per user

WITH NumberedLogins AS (
    SELECT
        user_id,
        login_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS rn
    FROM user_logins
),

Islands AS (
    SELECT
        user_id,
        login_date,
        DATEADD(DAY, -rn, login_date) AS island_group
    FROM NumberedLogins
),

Streaks AS (
    SELECT
        user_id,
        island_group,
        COUNT(*) AS streak_length
    FROM Islands
    GROUP BY
        user_id,
        island_group
)

SELECT
    user_id,
    MAX(streak_length) AS longest_streak
FROM Streaks
GROUP BY user_id
ORDER BY user_id;



-- 2. RUNNING MEDIAN OF A SALES COLUMN ORDER BY DATE , WITHOUT USING BUILD-IN MEDIAN FUNCTION

CREATE TABLE SALES(sales_date date, sales int) 


ALTER TABLE Sales
ALTER COLUMN sales DECIMAL(10,2);

insert into sales(sales_date,sales) values
('2026-01-01', 100),
('2026-01-02',300),
('2026-01-03',200),
('2026-01-04',500),
('2026-01-05',400),
('2026-01-06',600),
('2026-01-07',800),
('2026-01-08',700),
('2026-01-09',900),
('2026-01-10',1000)

select* from sales order by sales_date


--RUNNING MEAN WITHPUT USING BUILD_IN FUNCTION

SELECT
    s1.sales_date,
    s1.sales,

    (
        SELECT AVG(CAST(x.sales AS DECIMAL(10,2)))
        FROM
        (
            SELECT
                s2.sales,
                ROW_NUMBER() OVER (ORDER BY s2.sales) AS rn,
                COUNT(*) OVER () AS total_count
            FROM Sales s2
            WHERE s2.sales_date <= s1.sales_date
        ) AS x

        WHERE x.rn IN
        (
            (x.total_count + 1) / 2,
            (x.total_count + 2) / 2
        )
    ) AS running_median

FROM Sales s1
ORDER BY s1.sales_date;


--3.3rd highest salary :

create table employees(
    EmployeeID INT, 
	EmployeeName VARCHAR(200),
	Department VARCHAR(200),
	Salary DECIMAL(10,2))


INSERT INTO EMPLOYEES(EmployeeID, Employeename, Department, Salary)values
(1,'Arun','IT',80000),
(2,'Akila','IT',70000),
(3,'Tharun','IT',60000),
(4,'Ravi','IT', 50000),
(5,'Priya','HR', 90000),
(6,'Kavitha','HR',75000),
(7, 'Saravana', 'HR',55000)

SELECT * FROM EMPLOYEES ORDER BY DEPARTMENT, SALARY DESC


--USING DENSE_RANK (WINDOW FUNCTION)

SELECT
    EmployeeName,
	Department,
	Salary,
	DENSE_RANK() OVER(
	PARTITION BY DEPARTMENT
	ORDER BY SALARY DESC
	) AS SALARYRANK
	FROM EMPLOYEES
	)


-- 4. recursive CTE:

create table employees_data(emp_id int, managaer_id int)

insert into employees_data(emp_id,managaer_id)values
(1,NULL),
(2,1),
(3,1),
(4,2),
(5,2),
(6,4)

WITH EMPLOYEEHIERARCHY AS
(
  SELECT 
  EMP_ID AS MANAGAER_ID,
  EMP_ID AS EMPLOYEE_ID,
  0 AS LEVEL
FROM employees_data

UNION ALL

SELECT
   eh.managaer_id,
   e.emp_id as employee_id,
   eh.level+1
   from EMPLOYEEHIERARCHY eh
   join employees_data e
   on e.managaer_id = eh.employee_id
)
select
    managaer_id,
	count(*) as total_reports
from EMPLOYEEHIERARCHY
where level > 0
group by managaer_id
order by managaer_id
option(maxrecursion 100)


--6. Pivoting with pivot operator

create table student_scores(student_id int, subject varchar(200))

alter table student_scores add score int

select * from student_scores

insert into student_scores(student_id,subject,score) values
(101, 'maths',90),
(101,'science',95),
(101,'social',70),
(101,'tamil',80),
(101,'english',95),
(102,'maths',85),
(102,'science',100),
(102,'social',65),
(102,'tamil',90),
(102,'english',95),
(103,'maths',97),
(103,'science',94),
(103,'social',77),
(103,'tamil',89),
(103,'english',90)

select *  from student_scores order by student_id, subject

select
    student_id,

	max(case
	  when subject = 'maths'
	  then score
	  end) as maths,

    max(case
	when subject = 'science'
	then score
	end) as science,


	max(case
	when subject='social'
	then score
	end) as social,

	max(case
	when subject ='english'
	then score 
	end) as english,


	max(case
	when subject ='tamil'
	then score
	end) as tamil


	from student_scores
	group by student_id



	-- 6. self-join anomaly detection
create table transactions(transaction_id varchar(200),account_id varchar(200),transaction_time datetime, amount decimal(10,2))


insert into transactions (transaction_id, account_id, transaction_time,amount)values
('T1','A101','2026-01-01 10:00:00',1000.00),
('T2','A101','2026-01-01 10:00:30',1005.00),
('T3','A101','2026-01-01 10:05:00',2000.00),
('T4','A102','2026-01-01 10:00:00',1002.00),
('T5','A101','2026-01-01 10:01:00',995.00),
('T6','A101','2026-01-01 10:10:00',3000.00)


SELECT
    t1.transaction_id as transaction_1,
	t2.transaction_id as transaction_t2,
	t1.account_id,
	t1.transaction_time as time_1,
	t2.transaction_time as time_2,
	datediff(
	second,
	t1.transaction_time,
	t2.transaction_time
	) as time_difference_seconds,
	t1.amount as amount_1,
	t2.amount as amount_2,
	ABS(t1.amount-t2.amount) as amount_difference
	from transactions t1
	join transactions t2
	on t1.account_id = t2.account_id
	and t1.transaction_id < t2.transaction_id
	and datediff(
	ss,
	t1.transaction_time,
	t2.transaction_time
	) <= 60
	and ABS(t1.amount - t2.amount)/nullif(t1.amount,0)<0.01

	--- 8. use single delete statement:

	create table users(id int primary key, email varchar(100),created_at datetime)


	insert into users (id, email,created_at) values
	(1,'akila@gmail.com','2026-09-01 10:00:00'),
	(2,'saravana@gmail.com','2026-09-02 11:00:00'),
	(3,'akila@gmail.com','2026-09-03 15:00:00'),
	(4,'akila@gmail.com','2026-09-05 09:00:00'),
	(5,'saravana@gmail.com','2026-09-06 12:00:00')


	select * from users order by email,created_at


	DELETE FROM USERS  
	          WHERE ID IN 
			  (
			  SELECT ID FROM 
			  (
			  SELECT 
			  ID,
			  ROW_NUMBER() OVER (PARTITION BY EMAIL
			  ORDER BY CREATED_AT DESC)
			  AS RN
			  FROM USERS
			  )X
			  WHERE RN>1
			  )



SELECT * FROM USERS ORDER BY EMAIL,CREATED_AT


---9. FIND MEDIAN SALARY FOR EACH DEPARTMENT WITHOUT USING PERCENTILE/MEDIAN

CREATE TABLE Data_Employees (
  Employee_name varchar(200), department varchar(200),
  salary INT
);
INSERT INTO data_employees VALUES
('Arjun','Sales',120000),
('Priya','Sales',110000),
('Rahul','Sales',110000),
('Kiran','Sales',95000),
('Divya','Sales',80000),
('Sneha','Engineering',150000),
('Vikram','Engineering',14000),
('Meera','Engineering',130000),
('Ravi','Engineering',130000),
('Tara','Engineering',100000),
('Aman','Marketing',90000),
('Zoya','Marketing',85000),
('Farhan','Marketing',75000),
('Nikita','Marketing',70000)


select * from data_employees order by department,salary


--- WHAT I DO WITHOUT USING PERCENTILE AND MEDIAN INBUILD FUNCTION:
--- I USE : ROW_NUMBER>>> WE NEED TO KNOW POSITION OF EACH SALARY AFTER SORTING
--- ORDER BY >>> SORT SALARY
--- PARTITION BY >>> CREATES A GROUP FOR CALCULATION  BUT KEEPS EVERY INDIVIDUAL ROW
--- GROUP BY >> GROUPS ROWS AND USUALLY DIVES ONE RESULT PER GROUP


WITH SALARY_RANK AS
(
SELECT 
    DEPARTMENT,
	SALARY,
	ROW_NUMBER() OVER (PARTITION BY DEPARTMENT
	ORDER BY SALARY) AS RN,
	COUNT(*) OVER (PARTITION BY DEPARTMENT ) AS TOTAL_COUNT FROM Data_Employees)
	SELECT 
	    DEPARTMENT,
		AVG(SALARY) AS MEDIAN_SALARY FROM SALARY_RANK WHERE RN IN
		(
		(TOTAL_COUNT +1)/2,
		(TOTAL_COUNT +2)/2
		)
		GROUP BY department
		ORDER BY department



-- 10. USE WINDOW FUNCTION FOR PERCENTAGD OD THE DEPARTMENT_TOTAL, RUNNING TOTAL OF SALARY PARTICULAR SALES DEPARTMENT :

SELECT
   EMPLOYEE_NAME,
   SALARY,
   SALARY * 100.0/
     SUM(SALARY) OVER(
	 PARTITION BY DEPARTMENT) AS SALARY_PERCENTAGE,
--- RUNNING TOTAL

    SUM(SALARY) OVER (ORDER BY SALARY DESC
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RUNNING_TOTAL
	FROM DATA_EMPLOYEES
	WHERE DEPARTMENT = 'SALES'
	ORDER BY SALARY DESC


	---11. FIND ALLEMPLOYEES EARNING MORE THAN THE AVAERAGE SALRY OF THEIR OWN DEPARTMENT, DO NOT CORRELATED SUBQUERY:

	---I USE WINDOW FINCTION:


	SELECT 
	   DEPARTMENT,
	   EMPLOYEE_NAME,
	   SALARY

	FROM
	(
	SELECT
	    DEPARTMENT,
		EMPLOYEE_NAME,
		SALARY,
		AVG(SALARY) OVER(PARTITION BY DEPARTMENT ) AS DEPARTMENT_AVG
		FROM DATA_EMPLOYEES
		) AS E
		WHERE SALARY > DEPARTMENT_AVG
		ORDER BY DEPARTMENT, SALARY DESC



--- 12. FOR EACH USER WE NEED TO FIND (FIRST LOGIN_DATE, LAST LOGIN_DATE,CALENDER DATE BETWEEN FIRST AND LAST LOGIN , ACTUAL ACTIVE DAYS)
--- I USE AGGREGATE FUNCTION (MIN, MAX,COUNT) ALONG WITH GROUP BY


CREATE TABLE UserLogins (user_id INT, login_date DATE);
INSERT INTO UserLogins VALUES
(1,'2024-03-01'),(1,'2024-03-02'),(1,'2024-03-03'),(1,'2024-03-05'),(1,'2024-03-06'),
(2,'2024-03-01'),(2,'2024-03-02'),(2,'2024-03-03'),(2,'2024-03-04'),(2,'2024-03-05'),
(2,'2024-03-09'),
(3,'2024-03-04'),
(4,'2024-03-01'),(4,'2024-03-03'),(4,'2024-03-05'),(4,'2024-03-07');

SELECT * FROM USERLOGINS

SELECT
    User_ID,
    MIN(Login_Date) AS First_Login_Date,
    MAX(Login_Date) AS Last_Login_Date,

    -- Calendar days between first and last login
    DATEDIFF(
        DAY,
        MIN(Login_Date),
        MAX(Login_Date)
    ) AS Calendar_Days,

    -- Number of unique days the user actually logged in
    COUNT(DISTINCT CAST(Login_Date AS DATE)) AS Active_Days

FROM USERLOGINS
GROUP BY User_ID;


--- 13. WE NEED TO FIND MISSING DAYS BETWEEN DAYS (LOGIN_DATE) OF THE SAME USER
--- FORMULA : DAYSMISSED = DATEDIFF(DAY, DATEBEFORE GAP, DATEAFTER GAP) - 1
--- USING WINDOW FUNCTION(LEAD) >> Gets next login_date for the same user.

WITH LOGINGAP AS
(
SELECT 
    USER_ID,
	LOGIN_DATE AS DATEBEFOREGAP,
	LEAD(LOGIN_DATE) OVER(PARTITION BY USER_ID
	   ORDER BY LOGIN_DATE
	   ) AS DATEAFTERGAP
	   FROM USERLOGINS
	   )
	   SELECT
	       USER_ID,
		   DATEBEFOREGAP,
		   DATEAFTERGAP,
		   DATEDIFF(DAY,DATEBEFOREGAP,DATEAFTERGAP)-1 AS DAYS_MISSED

		FROM LOGINGAP

		WHERE DATEDIFF(DAY,DATEBEFOREGAP,DATEAFTERGAP)>1

---14.FIND THE SECOND_HIGHEST DISTICT SALARY ALL EMPLOYEES 
-- WITHOUT USING WINDOW FUNCTION, LIMIT OR OFFSET
--- USE MAX(), DISTINCT(), WHERE, SUBQUERY
		CREATE TABLE workers (
  emp_id int PRIMARY KEY, emp_name varchar(200), 
  salary int
);
INSERT INTO workers (emp_id,emp_name,salary)values
(1,'Arjun',120000),
(2,'Priya',110000),
(3,'Rahul',110000),
(4,'Kiran',95000),
(5,'Divya',80000),
(6,'Sneha',150000),
(7,'Vikram',140000),
(8,'Meera',130000),
(9,'Ravi',130000),
(10,'Tara',100000),
(11,'Aman',90000),
(12,'Zoya',85000),
(13,'Farhan',75000),
(14,'Nikita',70000)


SELECT
    MAX(SALARY) AS SECOND_HIGHEST_SALARY
	FROM WORKERS
	WHERE SALARY<(
	SELECT MAX(SALARY) FROM WORKERS)
