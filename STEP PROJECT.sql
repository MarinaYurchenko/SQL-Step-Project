-- STEP PROJECT

-- 1. Покажіть середню зарплату співробітників за кожен рік, до 2005 року.

SELECT YEAR(from_date) salary_year, AVG(salary)
FROM salaries
WHERE YEAR(from_date)<2005
GROUP BY salary_year
ORDER BY salary_year;

-- з віконною функцією 

SELECT DISTINCT EXTRACT(YEAR FROM from_date) salary_year, 
				AVG(salary) OVER (PARTITION BY EXTRACT(YEAR FROM from_date)) avg_salary
FROM salaries;

/* 2. Покажіть середню зарплату співробітників по кожному відділу. Примітка: потрібно
розрахувати по поточній зарплаті, та поточному відділу співробітників*/
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
GROUP BY dept_no)

SELECT dept_no, avg_salary
FROM cte_avg
ORDER BY dept_no;

-- 3. Покажіть середню зарплату співробітників по кожному відділу за кожний рік
SELECT DISTINCT dept_no, EXTRACT(YEAR FROM s.from_date) salary_year, 
				ROUND(AVG(salary) OVER (PARTITION BY dept_no ORDER BY YEAR(s.from_date)), 2) avg_salary
FROM dept_emp de
LEFT JOIN salaries s USING(emp_no);

-- варіант без віконної функції

SELECT dept_no, EXTRACT(YEAR FROM s.from_date) salary_year, ROUND(AVG(salary), 2) avg_salary
FROM dept_emp de
INNER JOIN salaries s ON s.emp_no=de.emp_no
GROUP BY dept_no, salary_year
ORDER BY dept_no;

-- 4. Покажіть відділи в яких зараз працює більше 15000 співробітників. 
SELECT dept_no, COUNT(emp_no) emp_quantity
FROM dept_emp
WHERE @cur BETWEEN from_date AND to_date
GROUP BY dept_no  
HAVING emp_quantity>15000;
 

-- 5. Для менеджера який працює найдовше покажіть його номер, відділ, дату прийому на роботу, прізвище
-- примітка - в даному випадку виводиться інформація про менеджера, який має найбільший досвід роботи з моменту прийняття на роботу в компанію
SELECT dm.emp_no, dm.dept_no, e.hire_date, e.last_name, TIMESTAMPDIFF(day, e.hire_date, @cur)/365 AS experience -- така формула обрахунку досвіду дозволила отримати більш точний результат 
FROM dept_manager dm
INNER JOIN employees e ON dm.emp_no = e.emp_no
WHERE curdate() BETWEEN dm.from_date AND dm.to_date
AND TIMESTAMPDIFF(day, e.hire_date, @cur)/365 = (
    SELECT MAX(TIMESTAMPDIFF(day, hire_date, @cur)/365) AS max_experience
    FROM dept_manager dm
    INNER JOIN employees e ON dm.emp_no = e.emp_no
    WHERE curdate() BETWEEN dm.from_date AND dm.to_date
);

-- другий варіант з використанням змінної. 
SET @max_experience := (
    SELECT MAX(TIMESTAMPDIFF(YEAR, hire_date, @cur)) AS max_experience
    FROM employees
);
SELECT dm.emp_no, dm.dept_no, hire_date, last_name,  
TIMESTAMPDIFF(YEAR, hire_date, @cur) AS experience
FROM employees
INNER JOIN dept_manager dm USING(emp_no)
WHERE TIMESTAMPDIFF(YEAR, hire_date, @cur) = @max_experience
AND @cur BETWEEN dm.from_date AND dm.to_date
LIMIT 1;

/* 3 варіант з віконною, сте та підзапитом| цей варіант виводить результат по менеджеру, який найдовше працює саме МЕНЕДЖЕРОМ.
 Але результат співпадає.*/
WITH cte1 AS (
SELECT emp_no, last_name, salary, hire_date, DATEDIFF(curdate(), LAST_VALUE(dm.from_date) OVER (PARTITION BY emp_no ORDER BY dm.from_date 
								   RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING))/365 as_manager,
                                   DATEDIFF(curdate(), hire_date)/365 total_experience
FROM dept_manager dm
INNER JOIN employees USING(emp_no)
INNER JOIN salaries s USING(emp_no)
WHERE @cur BeTWEEN s.from_date AND s.to_date
AND  @cur BeTWEEN dm.from_date AND dm.to_date
ORDER BY total_experience DESC)

SELECT *
FROM cte1
WHERE total_experience=(SELECT MAX(total_experience) FROM cte1);

/*6. Покажіть топ-10 діючих співробітників компанії з найбільшою різницею між їх зарплатою і
середньою зарплатою в їх відділі.*/
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

/*7. Для кожного відділу покажіть другого по порядку менеджера. Необхідно вивести відділ,
прізвище ім’я менеджера, дату прийому на роботу менеджера і дату коли він став
менеджером відділу*/
WITH cte_sec_man AS (
SELECT emp_no, dept_no, from_date,  ROW_NUMBER() OVER (
         PARTITION BY dept_no
         ORDER BY from_date) next_manager
FROM dept_manager
)
SELECT c.emp_no, CONCAT_WS(' ', first_name, last_name) full_name, c.dept_no, c.from_date manager_promotion, hire_date 
FROM cte_sec_man c
INNER JOIN employees e USING(emp_no)
WHERE next_manager=2;

-- Дизайн бази даних:
/*1. Створіть базу даних для управління курсами. База має включати наступні таблиці:
- students: student_no, teacher_no, course_no, student_name, email, birth_date.
- teachers: teacher_no, teacher_name, phone_no
- courses: course_no, course_name, start_date, */
CREATE DATABASE IF NOT EXISTS school; -- створюємо нову базу даних
SHOW DATABASES; -- перевіряємо наявність новоствореної бази в списку баз даних
USE school; -- переключаємось на нову бд
CREATE TABLE IF NOT EXISTS teachers (
	teacher_no INT AUTO_INCREMENT PRIMARY KEY,
	teacher_name VARCHAR(255) NOT NULL,
    phone_no INT NOT NULL
)
 ENGINE = INNODB;

CREATE TABLE IF NOT EXISTS courses (
	course_no INT PRIMARY KEY,
	course_name VARCHAR(255) NOT NULL,
    start_date DATE
)
 ENGINE = INNODB;
 
CREATE TABLE IF NOT EXISTS students (
    student_no INT NOT NULL,
    teacher_no INT,
    course_no INT NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    email VARCHAR(65),
    birth_date DATE,
    FOREIGN KEY (teacher_no) REFERENCES teachers (teacher_no) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (course_no) REFERENCES courses (course_no) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = INNODB;

SHOW TABLES;
DESC students;
-- 2. Додайте будь-які данні (7-10 рядків) в кожну таблицю.
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

INSERT INTO courses (course_no, course_name, start_date)
VALUES (10121, 'English', '2023-09-01'), -- dumbledore
(10122, 'Statistics', '2023-09-01'), -- minerva
(10123, 'Soft Skills', '2023-09-01'), -- hagrid
(10124, 'Python core', '2023-09-01'), -- remus
(10125, 'SQL basics', '2023-09-01'), -- pomona
(10126, 'Cybersecurity', '2023-09-01'), -- severus
(10127, 'Machine Learning', '2023-09-01'), -- trelawney
(10128, 'Computer Design', '2023-09-01'); -- quirrel

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
(119, 2, 10126, 'Torin Oakshield', 'torin_king@email.com', '1996-01-23'),
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

SELECT * FROM students;

-- 3. По кожному викладачу покажіть кількість студентів з якими він працював
WITH cte AS (
SELECT teacher_no, COUNT(*) count
FROM students
GROUP BY teacher_no
ORDER BY count DESC, teacher_no)

SELECT t.teacher_no, t.teacher_name, count
FROM teachers t
INNER JOIN cte USING(teacher_no);

-- 4. Спеціально зробіть 3 дубляжі в таблиці students (додайте ще 3 однакові рядки)
INSERT INTO students (student_no, teacher_no, course_no, student_name, email, birth_date) 
VALUES 
(137, 2, 10126, 'Andrew Yurchenko', 'andyou@email.com', '2001-06-13'),
(137, 2, 10126, 'Andrew Yurchenko', 'andyou@email.com', '2001-06-13'),
(137, 2, 10126, 'Andrew Yurchenko', 'andyou@email.com', '2001-06-13');
-- 5. Напишіть запит який виведе дублюючі рядки в таблиці students.

SELECT student_no, COUNT(*) dublicate
FROM students
GROUP BY  student_no
HAVING COUNT(*)>1;

SELECT student_no, row_num
FROM (
    SELECT student_no, ROW_NUMBER() OVER (PARTITION BY student_no ORDER BY student_no) AS row_num
    FROM students
) AS subquery
WHERE row_num > 1;
