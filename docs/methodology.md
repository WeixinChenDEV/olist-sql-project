# Analytical methodology

## Source and processing

The original nine CSVs remain unchanged. Eight are loaded to `raw`; the million-row geolocation file is not imported because state-level analysis does not need its many-to-one ZIP ambiguity. A manifest stores source headers, exact parsed record counts and SHA-256 hashes. Reviews contain quoted, multiline text: PostgreSQL CSV COPY handles them; physical line counting would be wrong.

`raw` preserves text values and source-row identity. `core` converts blanks to NULL, parses TIMESTAMP WITHOUT TIME ZONE, stores money as NUMERIC(14,2), and enforces primary keys, six foreign keys and price/score checks. Source timestamp timezone is unspecified; exports preserve text timestamps without inventing a UTC zone.

`mart.order_fact` has exactly one row for every source order. `mart.seller_order_fact` has one row per seller/order combination. Both are materialized views. The static build creates them once; refresh them explicitly after changing core data.

## Analysis windows

Source purchases range from 2016-09-04 to 2018-10-17. Executive KPIs, source audits, payment reconciliation and the January 2018 fanout demonstration state their own full-source or specific windows.

Monthly growth, categories, state delivery, reviews, seller watchlist and repeat purchasing use **2017-01-01 inclusive to 2018-09-01 exclusive**. This excludes sparse edge months and yields 20 observed calendar months, but does not establish completeness of the original business population. The supplied order status is a snapshot; delivered GMV assigned to purchase month is retrospective, not an as-of-month revenue ledger. Recent orders may have different follow-up.

Cohort assignment uses earlier delivered history as well, so a customer first seen in 2016 is not assigned to a 2017 acquisition cohort. Cohorts are first **observed** delivered-purchase cohorts, not verified lifetime acquisition cohorts. Later cells beyond August 2018 are omitted, not recorded as zero. Only compare matching observable month ages; snapshot truncation remains a limitation.

## Metric contracts

| Metric | Definition and denominator |
|---|---|
| Delivered item GMV | Sum of item prices for orders whose source status is delivered; excludes freight |
| Average delivered order GMV | Delivered item GMV divided by delivered orders, including any itemless delivered source orders if present |
| Recorded payment total | Sum of payment values; not assumed to be net revenue or delivered GMV |
| Cancellation rate | Canceled source orders / all orders purchased in the selected month |
| Delivery days | Elapsed seconds between purchase and delivery / 86,400, for delivered orders with nonnegative elapsed duration |
| Eligible delivery | Delivered status, valid delivered_at >= purchased_at and non-null estimated_at |
| Late rate | Eligible delivered orders where delivery calendar date exceeds estimated calendar date / all eligible deliveries |
| Low-score rate | Orders with selected score 1 or 2 / orders with a selected review in the relevant eligible delivery group |
| Repeat-customer share | Distinct customers with at least two delivered orders in the window / customers with at least one delivered order in that window |
| Purchase retention | Customers with a delivered purchase in month age N / initial observed cohort size; month 0 is 100% |

All financial values are BRL. Costs, marketplace commissions, marketing spend, refunds and visitor events are absent: profit, company revenue, ROAS and visit-to-purchase conversion are not computed.

## One-to-many relations

An order may have multiple item rows, payment records and reviews. A direct join produces item × payment × review rows. The SQL demonstration uses actual source data to quantify the error; missing reviews can also remove orders from an inner join. Its net 3.40% error is not a pure count of duplicated rows.

Items and payments are independently aggregated by order_id. Reviews are ranked by answered_at descending, created_at descending, review_id descending and original source row descending; the first row is selected. The source row is a deterministic fallback for this exact file, not an assertion that file order conveys business recency. All raw reviews remain available for alternate sensitivity analyses.

The seller watchlist includes only single-seller orders, at least 100 eligible orders per seller, and ranks primarily by late-order volume. Shipping carriers, destination mix, category and time can affect results; this is an investigation queue, not proof of seller fault. Category order counts overlap when an order contains multiple categories and must not be summed as total orders.

## Quality and verification

The audit deliberately reports real missing data and chronology anomalies rather than forcing them to zero. Examples include 8 delivered orders without delivery timestamps, 166 carrier timestamps before purchase, and multiple-payment / multiple-review orders. Missing translated categories fall back to the Portuguese name; missing categories become `unknown` in category analysis.

All import counts are reconciled to independently parsed CSV record counts. SQL verifies order grain, exact GMV/freight/payment totals, selected-review uniqueness/coverage, seller GMV totals and metric eligibility. The runner also checks cohort bounds, month-zero retention, source hashes, native FK presence and optimization-result equivalence. A failed invariant makes the build exit nonzero.

Payment vs item-plus-freight mismatches are retained and reported with cent and BRL 1 tolerance bands. These are unexplained source differences, not fraud findings. Missing payments are separately counted rather than treated as a real zero payment.

## Optimization experiment

Three stages count purchases on 2018-01-15:

1. `purchased_at::date = DATE '2018-01-15'`, before a timestamp index.
2. Equivalent half-open timestamp range, before the index.
3. The same range, after a B-tree index on purchased_at and ANALYZE.

Each stage executes one warm-up and three `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` runs. The result count must stay 307. Full plans and median execution times are saved. The index changes the measured plan from a sequential scan to an indexed bitmap scan in the verified local run. The comparison between stages 2 and 3 isolates the index more clearly than comparing stages 1 and 3.

Measurements describe warm-cache, single-process WASM execution on this machine. They are not production latency estimates or general speedup guarantees. Other supporting indexes are not individually benchmarked and carry storage/write overhead. An expression index on the date cast is another possible design; this project uses a timestamp range to support ordinary timestamp filtering.
