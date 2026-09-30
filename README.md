# Olist SQL Project

A small data analysis project using the public Olist e-commerce dataset. The main focus is SQL: joining tables, checking totals, using window functions, and comparing delivery performance.

The data contains 99,441 orders from 2016–2018. Most comparisons use January 2017 to August 2018 because the first and last months have very few orders.

## Questions

1. How did sales and order counts change each month?
2. Which product categories had the highest sales?
3. Which states had more late deliveries?
4. How do review scores differ between late and on-time orders?
5. How many customers bought more than once?
6. Can joining several tables change the totals?

## Files

```text
sql/          table setup, cleaning, checks, and analysis queries
results/      CSV results and query plans
notes/        data notes and a short summary of the findings
scripts/      helpers for running SQL locally
data/         source file list; downloaded CSV files are not uploaded
```

The queries are numbered from `01_overview.sql` to `10_joins.sql`. The file names in `results/` match the SQL files.

## A few results

- Late orders had a low review score (1 or 2) in 62.42% of reviewed cases, compared with 9.25% for on-time orders. This is a relationship in the data, not proof of causation.
- Rio de Janeiro had 1,495 late orders and a late rate of 12.14% in the selected period. Both the percentage and the number of affected orders matter.
- In January 2018, directly joining items, payments, and reviews overstated item sales by 3.40%. Summing each table by order first gave the correct total.

More detail is in [notes/findings.md](notes/findings.md). Sales here means item value excluding freight, not the company's revenue or profit.

## Run it

Use Node.js 20+ and PowerShell on Windows:

```powershell
git clone https://github.com/WeixinChenDEV/olist-sql-project.git
cd olist-sql-project
.\run.ps1
.\run.ps1 -SqlFile sql/02_monthly_sales.sql
```

The first run downloads the data and a small PostgreSQL runtime called [PGlite](https://pglite.dev/). The analysis itself is written in SQL; JavaScript loads the files and saves the results. With the downloaded files present, it can run offline.

If you already have PostgreSQL, create a new empty database and run from the project folder:

```bash
psql -d olist -f sql/import.psql
psql -d olist -f sql/05_reviews.sql
```

The SQL was tested using PostgreSQL 18.3 through PGlite. The separate PostgreSQL-server import has not been tested here. Data details and calculation choices are in [notes/data.md](notes/data.md).

## Data source

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), available on Kaggle under CC BY-NC-SA 4.0. Source attribution and reuse details are in [DATA_LICENSE.md](DATA_LICENSE.md).
