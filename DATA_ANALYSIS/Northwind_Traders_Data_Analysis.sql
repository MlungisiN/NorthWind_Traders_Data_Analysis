USE Northwind
GO

-- SELECT Top 10 Products By name arranged in Descending Order

SELECT TOP 10 Products.ProductName, SUM([Order Details].Quantity) AS [Number Of Units Sold]
FROM [Order Details]
INNER JOIN Products
ON [Order Details].ProductID = Products.ProductID
GROUP BY Products.ProductName
ORDER BY [Number Of Units Sold] DESC

-- Locate the product with the second highest price in the company

SELECT ProductName, UnitPrice
FROM Products P1
WHERE 1 = (SELECT COUNT(DISTINCT UnitPrice)
FROM products P2
WHERE P2.UnitPrice > P1.UnitPrice)

-- Utilizing DENS_RANK() to find the rank of products sold in each city in the USA based on Quantity

SELECT Products.ProductName, Customers.City, [Order Details].Quantity,
DENSE_RANK() OVER (PARTITION BY Customers.City ORDER BY [Order Details].Quantity DESC) AS RANK_Product
FROM customers
INNER JOIN
Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN
[Order Details]
ON Orders.OrderID = [Order Details].OrderID
INNER JOIN
Products
ON [Order Details].ProductID = Products.ProductID
WHERE Country = 'USA'
ORDER BY [Order Details].Quantity DESC

-- Find Products that were shipped late to customers (Took more than 2 days), showing number of days, 
--Order ID, Order date, Customer ID and Country, where total sale value is more than 10000

SELECT Orders.OrderID, Orders.CustomerID, Orders.OrderDate, Orders.ShippedDate, Orders.ShipCountry,
DATEDIFF(DAY, OrderDate, ShippedDate) AS DurationToShip,
SUM([Order Details].Quantity * [Order Details].UnitPrice) AS TotalSaleAmount
FROM Orders
INNER JOIN 
[Order Details]
ON Orders.OrderID = [Order Details].OrderID
WHERE
DATEDIFF(DAY, OrderDate, ShippedDate) > 2
GROUP BY Orders.OrderID, CustomerID, OrderDate, ShippedDate, ShipCountry
HAVING SUM([Order Details].OrderID * [Order Details].UnitPrice) > 10000
ORDER BY DATEDIFF(DAY, OrderDate, ShippedDate) DESC

-- Use CASE statement to classify products based on their stock

SELECT ProductID, ProductName,
CASE
WHEN (UnitsInStock < UnitsOnOrder and Discontinued = 0)
THEN 'Negative Inventory - Order Now!'
WHEN ((UnitsInStock - UnitsOnOrder) < ReorderLevel and Discontinued = 0)
THEN 'Reorder level reached - Place Order'
WHEN (Discontinued = 1)
THEN '****Discontinued****'
ELSE 'In Stock'
END AS [Stock Status]
FROM Products

-- Find the number of Orders per product in 2017

SELECT Products.ProductName, COUNT(Orders.OrderID) AS [Number Of Orders]
FROM Products
LEFT JOIN [Order Details]
ON Products.ProductID = [Order Details].ProductID
LEFT JOIN Orders
ON Orders.OrderID = [Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = '2017'
GROUP BY Products.ProductName
ORDER BY COUNT(Orders.OrderID) DESC

-- Create a List of Products with the current and future required Stock

WITH ItemStockList (ProductID, ProductName, UnitsInStock, Description)
AS
(
	SELECT ProductID, ProductName, UnitsInStock, 'Present Stock' AS UnitsInStock
	FROM Products
	WHERE UnitsInStock != 0

	UNION ALL

	SELECT ProductID, ProductName,
			(UnitsInStock + (UnitsInStock *20)/100) AS UnitsInStock,
			'Next Month Stock' As UnitsInStock
	FROM Products
	WHERE UnitsInStock != 0
)
SELECT *
FROM ItemStockList

--Find number of Orders, Revenue and Average Revenue per Order

SELECT COUNT(Orders.OrderID) AS [Number of Orders],
SUM([Order Details].UnitPrice * [Order Details].Quantity) AS [Revenue US Dollar],
AVG([Order Details].UnitPrice * [Order Details].Quantity) AS [Revenue Average per Order]
FROM Orders
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = '2017'

-- Find the top 10 valuable customers with their cities and countries in 2018

SELECT TOP 10 Customers.CompanyName, Customers.Country, Customers.City,
SUM([Order Details].Quantity * [Order Details].UnitPrice) AS [Total Sale]
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = '2018'
GROUP BY Customers.CompanyName, Customers.Country, Customers.City
ORDER BY [Total Sale] DESC

-- Find the products generated total sales greater than or equal to $30000

SELECT Products.ProductName, SUM([Order Details].Quantity) AS [Number of Units],
SUM([Order Details].Quantity * [Order Details].UnitPrice) AS [Total Sale Amount]
FROM Orders
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
INNER JOIN Products
ON [Order Details].ProductID = Products.ProductID
WHERE YEAR(Orders.OrderDate) = '2018'
GROUP BY Products.ProductName
HAVING SUM([Order Details].Quantity * [Order Details].UnitPrice) >= 30000
ORDER BY [Total Sale Amount] DESC

-- Classify Customers into 3 levels based on contribution of total sale

SELECT Customers.CompanyName,
SUM([Order Details].Quantity * [Order Details].UnitPrice) AS Total,
CASE
WHEN SUM([Order Details].Quantity * [Order Details].UnitPrice) >= 30000 THEN 'A'
WHEN SUM([Order Details].Quantity * [Order Details].UnitPrice) < 30000 AND SUM([Order Details].Quantity * [Order Details].UnitPrice) >= 20000 THEN 'B'
ELSE 'C'
END AS Customer_Grade
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
GROUP BY Customers.CompanyName
ORDER BY Total DESC

-- Find Customers who generated a totla sales amount greater than the average volume in 2018

SELECT Customers.CompanyName, Customers.City, Customers.Country,
SUM([Order Details].Quantity * [Order Details].UnitPrice) AS Total
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = '2018'
GROUP BY Customers.CompanyName, Customers.City, Customers.Country
HAVING SUM([Order Details].Quantity * [Order Details].UnitPrice) >=
(SELECT AVG(Quantity * UnitPrice) FROM [Order Details])
ORDER BY Total DESC

-- Find Sales Volume per customer for each year

IF OBJECT_ID('dbo.Sale_Year') IS NOT NULL
DROP VIEW Sale_Year
GO

CREATE VIEW Sale_Year AS
(
SELECT Customers.CompanyName AS [Customer Name], YEAR(Orders.OrderDate) AS Year, ([Order Details].UnitPrice * [Order Details].Quantity) AS Sale
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
)

SELECT *
FROM Sale_Year
PIVOT (SUM(sale) for Year in ([2016],[2017],[2018])) AS SumSalesPerYear
ORDER BY [Customer Name]

-- Find all customers that didn't place orders in the last 20 months

SELECT Customers.CompanyName, MAX(Orders.OrderDate) AS [Last Order Date],
DATEDIFF(MONTH, MAX(Orders.OrderDate), GETDATE()) AS [Months Since Last Order]
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
GROUP BY Customers.CompanyName
HAVING DATEDIFF(MONTH, MAX(Orders.OrderDate), GETDATE()) > 20
ORDER BY [Months Since Last Order]

-- Find the number of orders per customer

SELECT Customers.CompanyName, Customers.City,
(SELECT COUNT(OrderID) FROM Orders
WHERE Customers.CustomerID = Orders.CustomerID) AS [Number Of Orders] FROM Customers
ORDER BY [Number Of Orders] DESC

-- Find the customer with the third highest sale value

IF OBJECT_ID('dbo.Customer Sale') IS NOT NULL
DROP VIEW [dbo.Customer Sale]
GO

CREATE VIEW [Customer Sale] AS
(
SELECT Customers.CompanyName AS [Customer Name], Customers.Country, SUM([Order Details].UnitPrice * [Order Details].Quantity) AS Sale
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
GROUP BY Customers.CompanyName, Customers.Country
)

SELECT [Customer Name], Country, Sale FROM [Customer Sale] CS1
WHERE 2 = (SELECT COUNT(DISTINCT SALE)
FROM [Customer Sale] CS2
WHERE CS2.Sale > CS1.Sale)

-- Find Duration in days between every two orders for each customer

SELECT a.CustomerID, a.OrderDate,
DATEDIFF(DAY, a.OrderDate, b.OrderDate) AS [Days Between two orders]
FROM Orders a
INNER JOIN Orders b
ON a.OrderID = b.OrderID - 1
ORDER BY a.OrderDate

-- Sales Analysis over time period

IF OBJECT_ID('[Customer Sale]') IS NOT NULL
DROP VIEW [Customer Sale]
GO

CREATE VIEW [Customer Sale] AS
(
SELECT Customers.CompanyName AS [Customer Name], Customers.Country, YEAR(Orders.OrderDate) AS Year, MONTH(Orders.OrderDate) AS Month,
SUM([Order Details].UnitPrice * [Order Details].Quantity) AS Sale
FROM Customers
INNER JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
GROUP BY Customers.CompanyName, Customers.Country, YEAR(Orders.OrderDate), MONTH(Orders.OrderDate)
)
GO

SELECT SUM(SALE) AS SUM_SALE, MONTH, YEAR
FROM [Customer Sale]
WHERE YEAR = 2016
GROUP BY MONTH, YEAR
ORDER BY MONTH,SUM_SALE DESC

SELECT SUM(SALE) AS SUM_SALE, MONTH, YEAR
FROM [Customer Sale]
WHERE YEAR = 2017 AND MONTH IN (7,8,9,10,11,12)
GROUP BY MONTH, YEAR
ORDER BY MONTH,SUM_SALE DESC

--SELECT SUM(SALE) AS SUM_SALE, MONTH, YEAR
--FROM [Customer Sale]
--WHERE YEAR = 2018
--GROUP BY MONTH, YEAR
--ORDER BY MONTH,SUM_SALE DESC

-- Find number of orders per customer in each month of 2017

SELECT Customers.CompanyName,
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 1 THEN Orders.OrderID END) AS [JAN],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 2 THEN Orders.OrderID END) AS [FEB],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 3 THEN Orders.OrderID END) AS [MAR],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 4 THEN Orders.OrderID END) AS [APR],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 5 THEN Orders.OrderID END) AS [MAY],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 6 THEN Orders.OrderID END) AS [JUN],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 7 THEN Orders.OrderID END) AS [JUL],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 8 THEN Orders.OrderID END) AS [AUG],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 9 THEN Orders.OrderID END) AS [SEP],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 10 THEN Orders.OrderID END) AS [OCT],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 11 THEN Orders.OrderID END) AS [NOV],
COUNT(CASE WHEN MONTH(Orders.OrderDate) = 12 THEN Orders.OrderID END) AS [DEC]
FROM Customers
JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
WHERE YEAR(Orders.OrderDate) = '2017'
GROUP BY Customers.CompanyName
ORDER BY Customers.CompanyName

-- Find the number of orders per date, week and day in 2017

SELECT
CONVERT(DATE, OrderDate) AS [Order Date],
DATEPART(WEEK, OrderDate) AS Week,
DATEPART(DAY, OrderDate) AS Day,
COUNT(OrderID) AS [Number Of Orders]
FROM Orders
WHERE YEAR(OrderDate) = '2017'
GROUP BY CONVERT(DATE, OrderDate), DATEPART(WEEK,OrderDate), DATEPART(DAY,OrderDate)

-- Find revenue and revenue percentage per customer in 2017

DECLARE @Total_Rev money
SET @Total_Rev = (SELECT COUNT(UnitPrice * Quantity)
FROM [Order Details])

SELECT Customers.CompanyName AS [Customer Name], SUM([Order Details].UnitPrice * [Order Details].Quantity) AS [Revenue by Customer],
SUM([Order Details].UnitPrice * [Order Details].Quantity)/@Total_Rev AS [Revenue Percentage per Customer]
FROM Customers
LEFT JOIN Orders
ON Customers.CustomerID = Orders.CustomerID
LEFT JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = '2017'
GROUP BY Customers.CompanyName
ORDER BY [Revenue Percentage per Customer] DESC

-- Find the employees that have achieved the highest sales volume and their bonuses

SELECT TOP 3 Employees.FirstName + ' ' + Employees.LastName AS [Full Name], Employees.City,
SUM([Order Details].Quantity * [Order Details].UnitPrice) AS [Total Sale],
ROUND(SUM([Order Details].Quantity * [Order Details].UnitPrice)* .02, 0) AS [Bonus]
FROM Employees
INNER JOIN Orders
ON Employees.EmployeeID = Orders.EmployeeID
INNER JOIN [Order Details]
ON Orders.OrderID = [Order Details].OrderID
WHERE YEAR(Orders.OrderDate) = '2018' AND MONTH (Orders.OrderDate) = '1'
GROUP BY Employees.FirstName + ' ' + Employees.LastName, Employees.City
ORDER BY [Total Sale] DESC

-- Find the Number of employees per title for each city

SELECT Title, City, COUNT(Title) AS [Number Of Employees]
FROM Employees
GROUP BY Title, City

-- List the company's employees and their work duration in Years

SELECT LastName, FirstName, Title, DATEDIFF(YEAR, HireDate, GETDATE()) AS [Work Years In The Company]
FROM Employees

-- Find the employees and their ages for those older than 70 in every city

SELECT LastName, FirstName, Title, DATEDIFF(YEAR, BirthDate, GETDATE()) AS [Age]
FROM Employees
WHERE DATEDIFF(YEAR, BirthDate, GETDATE()) >= 70