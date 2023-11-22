-- old step project

-- SQL степ-проект
-- Запросы
USE employees;
/*1. Покажите среднюю зарплату сотрудников за каждый год (средняя заработная плата
среди тех, кто работал в отчетный период - статистика с начала до 2005 года).*/

SELECT YEAR(from_date) salary_year, ROUND(AVG(salary), 2) avg_salary
FROM salaries
WHERE YEAR(from_date)<2005
GROUP BY salary_year
ORDER BY salary_year;

-- з віконною функцією
SELECT DISTINCT EXTRACT(YEAR FROM from_date) salary_year, 
				ROUND(AVG(salary) OVER (PARTITION BY EXTRACT(YEAR FROM from_date)), 2) avg_salary
FROM salaries;

/*2. Покажите среднюю зарплату сотрудников по каждому отделу. Примечание: принять в
расчет только текущие отделы и текущую заработную плату.*/
SET @cur:=curdate(); -- створення змінної для подальших обрахунків

SELECT DISTINCT dept_no, ROUND(AVG(salary) OVER (PARTITION BY dept_no), 2) avg_salary
FROM dept_emp de
LEFT JOIN salaries s USING(emp_no)
WHERE @cur BETWEEN s.from_date AND s.to_date
AND @cur BETWEEN de.from_date AND de.to_date;

--  варіант обрахунку без віконної функції
WITH cte_avg AS(
 SELECT  dept_no, ROUND(AVG(salary), 2) avg_salary
 FROM salaries s
 INNER JOIN dept_emp de USING (emp_no)
 WHERE @cur BETWEEN s.from_date AND s.to_date
 AND @cur BETWEEN de.from_date AND de.to_date
 GROUP BY dept_no
 )

SELECT dept_no, avg_salary
FROM cte_avg
ORDER BY dept_no;

/*3. Покажите среднюю зарплату сотрудников по каждому отделу за каждый год.
Примечание: для средней зарплаты отдела X в году Y нам нужно взять среднее
значение всех зарплат в году Y сотрудников, которые были в отделе X в году Y.*/

SELECT DISTINCT dept_no, YEAR(s.from_date) salary_year, 
						ROUND(AVG(salary) OVER (PARTITION BY dept_no ORDER BY YEAR(s.from_date)), 2) avg_salary
FROM dept_emp de
LEFT JOIN salaries s USING(emp_no);

-- варіант без віконної функції

SELECT dept_no, YEAR(s.from_date) salary_year, ROUND(AVG(salary), 2) avg_salary
FROM dept_emp de
INNER JOIN salaries s ON s.emp_no=de.emp_no
GROUP BY dept_no, salary_year
ORDER BY dept_no;


-- 4. Покажите для каждого года самый крупный отдел (по количеству сотрудников) в этом году и его среднюю зарплату.

-- 1 спосіб: сте, підзапит і віконними функціями
WITH cte_rank AS (
SELECT tt.*, DENSE_RANK() OVER (PARTITION BY year ORDER BY quantity DESC) rank_1
FROM (
		SELECT YEAR(from_date) year, dept_no, COUNT(emp_no) quantity
        FROM dept_emp
        GROUP BY year, dept_no) tt
   ),
   cte_avg AS (
SELECT DISTINCT dept_no, YEAR(s.from_date) salary_year, ROUND(AVG(salary) OVER (PARTITION BY dept_no ORDER BY YEAR(s.from_date)), 2) avg_salary
FROM dept_emp de
INNER JOIN salaries s ON s.emp_no=de.emp_no
)

SELECT year, cr.dept_no, quantity, avg_salary
FROM cte_rank cr
LEFT JOIN cte_avg ca ON cr.dept_no=ca.dept_no AND cr.year=ca.salary_year
WHERE rank_1=1
ORDER BY year;

-- 2 варіант без віконних функцій
WITH cte_1 AS (
SELECT dept_no, YEAR(s.from_date) salary_year, ROUND(AVG(salary), 2) avg_salary
FROM salaries s
INNER JOIN dept_emp de USING(emp_no)
GROUP BY dept_no, salary_year
ORDER BY dept_no, salary_year),

cte_2 AS(
SELECT dept_no, YEAR(from_date) report_year, COUNT(emp_no) emp_quant
FROM dept_emp
GROUP BY dept_no, report_year
ORDER BY dept_no, report_year)

SELECT report_year, c2.dept_no, avg_salary, emp_quant max_quant
FROM cte_2 c2
INNER JOIN cte_1 c1 ON c2.dept_no=c1.dept_no
AND c2.report_year=c1.salary_year
WHERE (c2.report_year, c2.emp_quant) IN (
    SELECT report_year, MAX(emp_quant)
    FROM cte_2
    GROUP BY report_year
)
ORDER BY report_year;

-- 5. Покажите подробную информацию о менеджере, который дольше всех исполняет свои обязанности на данный момент.

-- 1 варіант з підзапитом
SELECT dm.emp_no, CONCAT_WS(' ', first_name, last_name) full_name, dm.dept_no, e.hire_date, salary,
	   TIMESTAMPDIFF(day, e.hire_date, @cur)/365 AS experience -- така формула обрахунку досвіду дозволила отримати більш точний результат 
FROM dept_manager dm
INNER JOIN employees e ON dm.emp_no = e.emp_no
INNER JOIN salaries s ON e.emp_no=s.emp_no
WHERE @cur BETWEEN dm.from_date AND dm.to_date
AND @cur BETWEEN s.from_date AND s.to_date
AND TIMESTAMPDIFF(day, e.hire_date, @cur)/365 = (
    SELECT MAX(TIMESTAMPDIFF(day, hire_date, @cur)/365) AS max_experience
    FROM dept_manager dm
    INNER JOIN employees e ON dm.emp_no = e.emp_no
    WHERE @cur BETWEEN dm.from_date AND dm.to_date
);

-- 2 варіант з використанням змінної. 
SET @max_experience := (
    SELECT MAX(TIMESTAMPDIFF(YEAR, hire_date, @cur)) AS max_experience
    FROM employees
);
SELECT dm.emp_no, CONCAT_WS(' ', first_name, last_name) full_name, dm.dept_no, hire_date, salary, 
TIMESTAMPDIFF(YEAR, hire_date, @cur) AS experience
FROM employees
INNER JOIN dept_manager dm USING(emp_no)
INNER JOIN salaries s USING (emp_no)
WHERE TIMESTAMPDIFF(YEAR, hire_date, @cur) = @max_experience
AND @cur BETWEEN dm.from_date AND dm.to_date
AND @cur BETWEEN s.from_date AND s.to_date
LIMIT 1;

/* 3 варіант з віконною, сте та підзапитом| цей варіант виводить результат по менеджеру, який найдовше працює саме МЕНЕДЖЕРОМ.
 Але результат всеодно співпадає.*/
WITH cte1 AS (
SELECT emp_no, last_name, salary, hire_date, ROUND (DATEDIFF(@cur, LAST_VALUE(dm.from_date) OVER (PARTITION BY emp_no ORDER BY dm.from_date 
								   RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING))/365, 2) as_manager,
                                   ROUND(DATEDIFF(@cur, hire_date)/365, 2) total_experience
FROM dept_manager dm
INNER JOIN employees USING(emp_no)
INNER JOIN salaries s USING(emp_no)
WHERE @cur BeTWEEN s.from_date AND s.to_date
AND  @cur BeTWEEN dm.from_date AND dm.to_date
ORDER BY as_manager DESC)

SELECT *
FROM cte1
WHERE as_manager=(SELECT MAX(as_manager) FROM cte1);

/*6. Покажите топ-10 нынешних сотрудников компании с наибольшей разницей между их
зарплатой и текущей средней зарплатой в их отделе.*/ 

-- варіант із використанням підзапиту
SELECT tt.*, ROUND(ABS(tt.salary-tt.avg_salary), 2) difference
FROM (SELECT DISTINCT de.emp_no, dept_no, salary,
	  AVG(salary) OVER (PARTITION BY dept_no) avg_salary
	FROM dept_emp de
	INNER JOIN salaries s USING(emp_no)
    WHERE @cur BETWEEN s.from_date AND s.to_date
    AND @cur BETWEEN de.from_date AND de.to_date ) tt
ORDER BY difference DESC
LIMIT 10; 

-- 2 
WITH cte_avg_dept AS (
	SELECT DISTINCT de.dept_no, AVG(salary) OVER (PARTITION BY de.dept_no) avg_dept
	FROM dept_emp de
	INNER JOIN salaries s USING(emp_no)
	WHERE @cur BETWEEN de.from_date AND de.to_date
    AND @cur BETWEEN s.from_date AND s.to_date
)
SELECT de.emp_no, de.dept_no, salary, avg_dept, ROUND(ABS(salary-avg_dept),2) difference
FROM dept_emp de
INNER JOIN cte_avg_dept USING(dept_no)
INNER JOIN salaries s USING(emp_no)
ORDER BY difference DESC
LIMIT 10;


/*7. Из-за кризиса на одно подразделение на своевременную выплату зарплаты выделяется
всего 500 тысч долларов. Правление решило, что низкооплачиваемые сотрудники
будут первыми получать зарплату. Показать список всех сотрудников, которые будут
вовремя получать зарплату (обратите внимание, что мы должны платить зарплату за
один месяц, но в базе данных мы храним годовые суммы).*/ 
 
WITH cte_month AS (
SELECT dept_no, s.emp_no, ROUND(salary/12, 2) month_salary
FROM salaries s 
INNER JOIN dept_emp de ON s.emp_no=de.emp_no 
WHERE @cur BETWEEN s.from_date ANd s.to_date
AND @cur BETWEEN de.from_date ANd de.to_date
ORDER BY month_salary),

cte_sum AS (
SELECT *, SUM(month_salary) OVER  (PARTITION BY dept_no ORDER BY month_salary) cum_sum
FROM cte_month
ORDER BY dept_no, month_salary)

SELECT * 
FROM cte_sum
WHERE cum_sum<=500000;

/* таким чином знайдено співробітників, які мають найнижчу місячну зп в своєму департаменті
та отримають своєчасну виплату з загального бюджету на кожен департамент 500 000. 
Обрахунок кумулятивної суми в даному випадку слугує як фільтр для розмежування співробітників, котрі можуть отримати виплату з обумовленого бюджету
і котрі вже в цей список не входять.*/

/*Дизайн базы данных:
1. Разработайте базу данных для управления курсами. База данных содержит
следующие сущности:
a. students: student_no, teacher_no, course_no, student_name, email, birth_date.
b. teachers: teacher_no, teacher_name, phone_no
c. courses: course_no, course_name, start_date, end_date.
● Секционировать по годам, таблицу students по полю birth_date с помощью механизма range
● В таблице students сделать первичный ключ в сочетании двух полей student_no и birth_date
● Создать индекс по полю students.email
● Создать уникальный индекс по полю teachers.phone_no*/

CREATE DATABASE IF NOT EXISTS school_1; -- створюємо нову базу даних
SHOW DATABASES; -- перевіряємо наявність новоствореної бази в списку баз даних
USE school_1; -- переключаємось на нову бд
CREATE TABLE IF NOT EXISTS teachers (
	teacher_no INT AUTO_INCREMENT PRIMARY KEY,
	teacher_name VARCHAR(255) NOT NULL,
    phone_no INT NOT NULL
)
 ENGINE = INNODB;

CREATE TABLE IF NOT EXISTS courses (
	course_no INT PRIMARY KEY,
	course_name VARCHAR(255) NOT NULL,
    start_date DATE,
    end_date DATE
)
 ENGINE = INNODB;

CREATE TABLE IF NOT EXISTS students (
    student_no INT NOT NULL,
    teacher_no INT,
    course_no INT NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    email VARCHAR(65),
    birth_date DATE,
    PRIMARY KEY (student_no, birth_date)
)
PARTITION BY RANGE (YEAR(birth_date)) (
    PARTITION p0 VALUES LESS THAN (1998),
    PARTITION p1 VALUES LESS THAN (1999),
    PARTITION p2 VALUES LESS THAN (2000),
    PARTITION p3 VALUES LESS THAN (2001),
    PARTITION p4 VALUES LESS THAN (2002),
    PARTITION p5 VALUES LESS THAN (2003),
    PARTITION p6 VALUES LESS THAN (MAXVALUE)
) ;

SHOW TABLES; -- перевірка новостворених таблиць

CREATE INDEX email ON students(email); -- створення індексу на імейл
CREATE UNIQUE INDEX phone ON teachers (phone_no); -- створення унікального індексу на телефон вчителів

DESC students;
-- 2. На свое усмотрение добавить тестовые данные (7-10 строк) в наши три таблицы.
INSERT INTO teachers VALUES 
(1, 'Albus Dumbledore', 5553455),
(2, 'Severus Snape', 5556523),
(3, 'Minerva Mcgonagall', 5557892),
(4, 'Rubeus Hagrid', 5558598),
(5, 'Remus Lupin', 5552307),
(6, 'Pomona Sprout', 5554421),
(7, 'Sibilla Trelawney', 5559967),
(8, 'Quirinus Quirrell', 5558154);
SELECT * from teachers; -- перевірка результату


INSERT INTO courses (course_no, course_name, start_date, end_date)
VALUES (10121, 'English', '2023-09-01', '2024-02-28'), -- dumbledore
(10122, 'Statistics', '2023-10-01', '2024-03-31'), -- minerva
(10123, 'Soft Skills', '2023-11-01', '2024-04-30'), -- hagrid
(10124, 'Python core', '2023-12-01', '2024-05-31'), -- remus
(10125, 'SQL basics', '2023-09-01', '2024-02-28'), -- pomona
(10126, 'Cybersecurity', '2023-10-01', '2024-03-31'), -- severus
(10127, 'Machine Learning', '2023-11-01', '2024-04-30'), -- trelawney
(10128, 'Computer Design', '2023-12-01', '2024-05-31'); -- quirrel

SELECT * FROM courses;

INSERT INTO students (student_no, teacher_no, course_no, student_name, email, birth_date) 
VALUES 
(101, 1, 10121, 'Ivan Forlano', 'ivanf@email.com', '2000-01-23'),
(102, 2, 10126, 'Igor Gamula', 'igamula@email.com', '2001-08-15'),
(103, 1, 10121, 'Leonard Nimoy', 'lennim@email.com', '2001-01-16'),
(104, 3, 10122, 'Andrew Dawson', 'and.daw@email.com', '2002-01-01'),
(105, 2, 10126, 'Margo Stevens', 'margo22@email.com', '1999-12-25'),
(106, 5, 10124, 'Victoria Brunelli', 'bruni@email.com', '2000-07-11'),
(107, 1, 10121, 'Astoria Greengrass', 'asteri@email.com', '2000-03-04'),
(108, 8, 10128, 'Billius Weasley', 'billweas@email.com', '2002-02-28'),
(109, 7, 10127, 'Violet Sorrengail', 'violence@email.com', '2001-09-02'),
(110, 6, 10125, 'Xaden Riorson', 'xaden1@email.com', '2001-11-11'),
(111, 7, 10127, 'Dain Traitor', 'dainseer@email.com', '2000-05-18'),
(112, 5, 10124, 'Ginny Potter', 'reddy@email.com', '2002-04-25'),
(113, 3, 10122, 'Malena Leedle', 'malena_leedle@email.com', '2001-10-10'),
(114, 3, 10122, 'Mira Flaws', 'pawsmira@email.com', '1998-12-19'),
(115, 2, 10126, 'Imogen Poots', 'emogy@email.com', '1999-08-21'),
(116, 1, 10121, 'Tamlin Beaston', 'springbeast@email.com', '2001-02-02'),
(117, 7, 10127, 'Rhysand Best', 'night_court@email.com', '2002-03-11'),
(118, 6, 10125, 'Elisabeth Darcy', 'lizzy25@email.com', '2003-07-11'),
(119, 2, 10126, 'Torin Oakshield', 'torin_king@email.com', '1998-01-23'),
(120, 5, 10124, 'Bilbo Baggins', 'thethief@email.com', '2002-06-17'),
(121, 3, 10122, 'Gandalf Grey', 'thewizard@email.com', '2003-09-03'),
(122, 4, 10123, 'Pippa Took', 'pippaTook@email.com', '1999-12-31'),
(123, 4, 10123, 'Antonio Lacelli', 'lacelli@email.com', '2001-02-03'),
(124, 5, 10124, 'Angie Pitt', 'angel@email.com', '2002-08-30'),
(125, 8, 10128, 'Jennifer White', 'jenny_white@email.com', '2001-05-17'),
(126, 6, 10125, 'Elayne Trakand', 'elaynet11@email.com', '2000-04-25'),
(127, 1, 10121, 'Min Farshaw', 'minfarshaw@email.com', '1998-05-02'),
(128, 5, 10124, 'Dean Thomas', 'westham@email.com', '2001-11-30'),
(129, 3, 10122, 'Seamus Finnigan', 'banshee@email.com', '2003-01-09'),
(130, 2, 10126, 'Michael Corner', 'corner_M.25@email.com', '2000-10-06'),
(131, 3, 10122, 'Nigel Black', 'n.black@email.com', '2001-03-08'),
(132, 6, 10125, 'Lavanda Brown', 'lavandaBrown@email.com', '2002-07-21'),
(133, 7, 10127, 'Deanna Troy', 'counselor@email.com', '2003-06-26'),
(134, 5, 10124, 'Kathy Janeway', 'coffeecaptain@email.com', '2001-09-28'),
(135, 7, 10127, 'James Kirk', 'enterpriseNC1701@email.com', '2002-03-16'),
(136, 1, 10121, 'Nyota Uhura', 'n.uhura@email.com', '2000-11-27');

SELECT * FROM students
ORDER BY student_no;

/*3. Отобразить данные за любой год из таблицы students и зафиксировать в виду
комментария план выполнения запроса, где будет видно что запрос будет выполняться по
конкретной секции.*/
/*EXPLAIN*/ SELECT * 
FROM students
PARTITION (p5); -- пошук відбувся по одній партиції р5, rows 8

/*EXPLAIN*/ SELECT * 
FROM students
WHERE YEAR(birth_date)=2002; -- partitions p0, p1, p2, p3, p4, p5, p6, rows 36

/*4. Отобразить данные учителя, по любому одному номеру телефона и зафиксировать план
выполнения запроса, где будет видно, что запрос будет выполняться по индексу, а не
методом ALL. Далее индекс из поля teachers.phone_no сделать невидимым и
зафиксировать план выполнения запроса, где ожидаемый результат - метод ALL. В итоге
индекс оставить в статусе - видимый.*/

EXPLAIN SELECT * FROM teachers
WHERE phone_no=5553455; -- пошук по замовчуванню відбувався по індексу (type/ref: const,  rows: 1, filtered 100.00)

EXPLAIN SELECT * FROM teachers IGNORE INDEX (phone)
WHERE phone_no=5553455; -- -- пошук відбувався по всім даним (type: all, rows: 8, filtered 12,5)

EXPLAIN SELECT * FROM teachers FORCE INDEX (phone) -- якщо треба задіяти один із кількох індексів
WHERE phone_no=5553455;

ALTER TABLE teachers
ALTER INDEX phone INVISIBLE; -- якщо треба вимкнути індекс взагалі, а не просто в межах запиту

ALTER TABLE teachers
ALTER INDEX phone VISIBLE; -- залишаємо цей індекс робочим

/*5. Специально сделаем 3 дубляжа в таблице students (добавим еще 3 одинаковые строки).*/

ALTER TABLE students -- видаляємо PRIMARY KEY, який блокує створення дублікатів
DROP PRIMARY KEY;

INSERT INTO students (student_no, teacher_no, course_no, student_name, email, birth_date) 
VALUES 
(137, 2, 10126, 'Andrew Yurchenko', 'andyou@email.com', '2001-06-13'),
(137, 2, 10126, 'Andrew Yurchenko', 'andyou@email.com', '2001-06-13'),
(137, 2, 10126, 'Andrew Yurchenko', 'andyou@email.com', '2001-06-13'); -- успішно створено

-- 6. Написать запрос, который выводит строки с дубляжами.

SELECT student_no, COUNT(*) dublicate
FROM students
GROUP BY  student_no
HAVING COUNT(*)>1;

SELECT student_no, row_num -- альтернативний варіант 
FROM (
    SELECT student_no, ROW_NUMBER() OVER (PARTITION BY student_no ORDER BY student_no) AS row_num
    FROM students
) AS subquery
WHERE row_num > 1;
