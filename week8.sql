CREATE DATABASE SALFORDBANKLTD;

USE SALFORDBANKLTD;

CREATE TABLE CUSTOMERS
(
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerFirstName NVARCHAR(50) NOT NULL,
    CustomerLastName NVARCHAR(50) NOT NULL,
    CustomerAddressID INT NOT NULL,
    CustomerBranchCode NVARCHAR(6) NOT NULL,
    CustomerDOB DATE NOT NULL,
    CustomerGender NVARCHAR(15) NOT NULL,
    CustomerEmail NVARCHAR(100) UNIQUE NOT NULL CHECK (CustomerEmail LIKE '%_@_%._%'),
    CustomerTelephone NVARCHAR(20) NOT NULL,
)

CREATE TABLE ACCOUNTTYPES
(
    AccountTypeID int IDENTITY NOT NULL PRIMARY KEY,
    AccountType NVARCHAR(50) UNIQUE NOT NULL,
    InterestRate DECIMAL(4, 2) NOT NULL,
)

CREATE TABLE ACCOUNTS
(
    AccountNumber NVARCHAR(8) NOT NULL PRIMARY KEY,
    AccountTypeID INT NOT NULL FOREIGN KEY (AccountTypeID) REFERENCES ACCOUNTTYPES (AccountTypeID),
    AccountBalance Money NOT NULL,
)

CREATE TABLE CUSTOMERACCOUNTS
(
    CustomerID INT NOT NULL FOREIGN KEY (CustomerID) REFERENCES CUSTOMERS(CustomerID),
    AccountNumber NVARCHAR(8) NOT NULL FOREIGN KEY (AccountNumber) REFERENCES ACCOUNTS(AccountNumber),
    PRIMARY KEY (CustomerID, AccountNumber)
)

CREATE TABLE BRANCHES
(
    BranchCode NVARCHAR(6) NOT NULL PRIMARY KEY,
    BranchName NVARCHAR(50) UNIQUE NOT NULL,
    BranchAddressID INT NOT NULL,
    BranchTelephone NVARCHAR(20) NOT NULL,
);
CREATE TABLE ADDRESSES
(
    AddressID INT IDENTITY NOT NULL PRIMARY KEY,
    Address1 NVARCHAR(50) NOT NULL,
    Address2 NVARCHAR(50) NULL,
    PostCode NVARCHAR(10) NOT NULL,
    City NVARCHAR(50) NULL,
    CONSTRAINT UC_Adress UNIQUE (Address1, PostCode),
);

ALTER TABLE BRANCHES ADD FOREIGN KEY (BranchAddressID) REFERENCES ADDRESSES(AddressID);
ALTER TABLE CUSTOMERS ADD FOREIGN KEY (CustomerAddressID)  REFERENCES ADDRESSES(AddressID);
ALTER TABLE CUSTOMERS ADD FOREIGN KEY (CustomerBranchCode)  REFERENCES BRANCHES(BranchCode);

/*markdown
## Bulk Import Data from CSV
*/

CREATE TABLE BankCSVData
(
    CustomerID INT,
    CustomerFirstName NVARCHAR(100),
    CustomerLastName NVARCHAR(100),
    CustomerAddress1 NVARCHAR(255),
    CustomerAddress2 NVARCHAR(255) NULL,
    CustomerCity NVARCHAR(100) NULL,
    CustomerPostcode NVARCHAR(20),
    CustomerEmail NVARCHAR(255),
    CustomerTelephone NVARCHAR(20),
    CustomerGender NVARCHAR(15),
    CustomerDOB NVARCHAR(20),
    AccountBalance DECIMAL(18, 2),
    AccountNumber NVARCHAR(20),
    AccountType NVARCHAR(50),
    AccountInterestRate DECIMAL(5, 2),
    BranchCode NVARCHAR(6),
    -- Updated to NVARCHAR(6)
    BranchName NVARCHAR(100),
    BranchAddress1 NVARCHAR(255),
    BranchAddress2 NVARCHAR(255) NULL,
    BranchCity NVARCHAR(100) NULL,
    BranchPostcode NVARCHAR(20),
    BranchTelephone NVARCHAR(20)
);


USE SALFORDBANKLTD;
BULK INSERT BankCSVData
FROM '/media/Bank_Data.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);


SELECT TOP 5
    *
FROM BankCSVData;

/*markdown
#
**Moving Data from Table to Salford Bank Ltd**
*/

INSERT INTO Addresses
    (Address1, Address2, City, Postcode)
    SELECT DISTINCT CustomerAddress1, CustomerAddress2, CustomerCity,
        CustomerPostcode
    FROM BANKCSVDATA
UNION
    SELECT DISTINCT BranchAddress1, BranchAddress2, BranchCity, BranchPostcode
    FROM BANKCSVDATA;


INSERT INTO ACCOUNTTYPES
    ( AccountType, InterestRate)
SELECT DISTINCT AccountType, AccountInterestRate
FROM BANKCSVDATA;
INSERT INTO Accounts
    (AccountNumber, AccountBalance, AccountTypeID)
SELECT DISTINCT b.AccountNumber, b.AccountBalance, t.AccountTypeID
FROM BANKCSVDATA b INNER JOIN AccountTypes t
    ON b.AccountType = t.AccountType;

INSERT INTO Branches
    (BranchCode, BranchName, BranchAddressID, BranchTelephone)
SELECT DISTINCT b.BranchCode, b.BranchName, a.AddressID, b.BranchTelephone
FROM BANKCSVDATA b
INNER JOIN Addresses a
    ON b.BranchAddress1 = a.Address1 AND b.BranchPostcode = a.PostCode;

SELECT BranchCode, COUNT(*)
FROM BANKCSVDATA
GROUP BY BranchCode
HAVING COUNT(*) > 1;

-- You should write a similar query to insert the branch data into the Branches table
-- (note that in this case we know the combination of Address1 and Postcode uniquely
-- identifies a row so we can use this to join the two tables to give us the AddressID.)


INSERT INTO Branches
    (BranchCode, BranchName, BranchAddressID, BranchTelephone)
SELECT DISTINCT b.BranchCode, b.BranchName, a.AddressID, b.BranchTelephone
FROM BankCSVData b
    INNER JOIN Addresses a
    ON b.BranchAddress1 = a.Address1 AND b.BranchPostcode = a.Postcode
WHERE NOT EXISTS (
    SELECT 1
FROM Branches br
WHERE br.BranchCode = b.BranchCode
);

INSERT INTO Customers
    (CustomerID, CustomerFirstName,
    CustomerLastName, CustomerEmail, CustomerGender, CustomerDOB,
    CustomerTelephone, CustomerAddressID, CustomerBranchCode)
SELECT DISTINCT
    b.CustomerID,
    b.CustomerFirstName,
    b.CustomerLastName,
    b.CustomerEmail,
    b.CustomerGender,
    -- Convert CustomerDOB to a valid date format
    CONVERT(DATE, b.CustomerDOB, 103) AS CustomerDOB,
    b.CustomerTelephone,
    a.AddressID,
    b.BranchCode
FROM BANKCSVDATA b
    INNER JOIN Addresses a
    ON (b.CustomerAddress1 = a.Address1 AND b.CustomerPostcode = a.Postcode)


INSERT INTO CustomerAccounts
    (CustomerID, AccountNumber)
SELECT b.CustomerID, a. AccountNumber
FROM BANKCSVDATA b INNER JOIN Accounts a
    ON b.AccountNumber= a.AccountNumber;

DROP TABLE BANKCSVDATA

/*markdown
# Some Queries for displaying data
*/

WITH
    CustomerCTE(CustomerID, NumberOfAccounts)
    AS
    (
        SELECT CustomerID, COUNT(*)
        FROM CustomerAccounts
        GROUP BY CustomerID
        HAVING COUNT(*) > 1
    )
SELECT COUNT(*) as 'Number Customers with more than one Account'
FROM CustomerCTE;

SELECT COUNT(DISTINCT c1.CustomerID) as 'Number Customers with more than one Account'
FROM CustomerAccounts c1
WHERE c1.CustomerID IN (SELECT c2.CustomerID
FROM CustomerAccounts c2
WHERE c1.CustomerID=c2.CustomerID
GROUP BY CustomerID
HAVING COUNT(*) > 1);

-- What is the most popular account type?

SELECT top 1
    t.AccountType, COUNT(*) AS NumberOfAccounts
FROM AccountTypes t INNER JOIN Accounts a
    ON t.AccountTypeID=a.AccountTypeID
GROUP BY t.AccountType
ORDER BY NumberOfAccounts DESC;

-- What is the average account balance for customers over the age of 50?

SELECT AVG(a.AccountBalance) As 'Average Bal for Customer > 50yrs'
FROM Accounts a INNER JOIN CustomerAccounts ca
    ON a.AccountNumber = ca.AccountNumber INNER JOIN Customers c
    ON c.CustomerID = ca.CustomerID
WHERE DATEDIFF(YEAR,c.CustomerDOB,GETDATE()) > 50;

-- How many accounts are there with a balance of more than £10,000?
SELECT COUNT(*)
FROM Accounts
WHERE AccountBalance > 10000;

