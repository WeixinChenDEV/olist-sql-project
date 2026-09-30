# Delivery reliability and metric integrity: an Olist SQL study

## Decision

Prioritize delivery investigation using both affected-order volume and lateness rates, while fixing analytical JOIN grain before relying on any financial KPI. The SQL evidence identifies candidate priorities; it does not prove that a specific seller or carrier caused the problem.

The main comparison window is January 2017–August 2018. Executive/source totals and the payment audit use the full snapshot. Amounts are BRL; delivered item GMV excludes freight. Files under `results/` contain the exact query outputs.

## Findings and actions

### 1. Metric integrity comes first

In January 2018, source item prices total **BRL 950,030.36**. Directly joining item rows to payments and reviews yields **BRL 982,295.30**, a net **3.40%** overstatement. The order-grain mart returns exactly **BRL 950,030.36**.

The source contains 2,961 orders with multiple payments, 547 orders with multiple review rows and 9,803 orders with multiple items. Direct joins can repeat amounts, and inner joins can exclude orders lacking a corresponding record.

**Action:** use the reconciled order mart for order-level KPIs. Keep a separate item-grain analysis for category GMV. Require total reconciliation before adding dimensions.

Evidence: `sql/analysis/10_join_fanout_demo.sql`, `results/10_join_fanout_demo.csv`, `results/quality_audit.csv`.

### 2. Late deliveries are associated with low ratings

| Group | Eligible delivered orders | Reviewed orders | Average selected score | Score 1–2 share of reviewed orders |
|---|---:|---:|---:|---:|
| Late | 6,531 | 6,378 | 2.27 | 62.42% |
| On time | 89,672 | 89,182 | 4.29 | 9.25% |

The gap is **53.17 percentage points**. Review coverage differs: 97.66% in the late group versus 99.45% in the on-time group. Latest available reviews are selected once per order.

**Action:** investigate fulfillment stages and the accuracy of estimated dates. Obtain carrier scans and promised-date changes to distinguish shipping delays from unrealistic estimates. Test corrective actions with a design that measures delivery and customer outcomes.

The comparison is observational. Product mix, region, seller and season can affect both lateness and ratings. No causal effect or implemented improvement is claimed.

Evidence: `sql/analysis/05_lateness_and_reviews.sql`, `results/05_lateness_and_reviews.csv`.

### 3. Rank regions by volume as well as rate

Alagoas (AL) has **21.46%** lateness among **396** eligible orders, with **85** late orders. Rio de Janeiro (RJ) has **12.14%** lateness among **12,310** eligible orders, with **1,495** late orders. São Paulo (SP) has a lower **4.50%** lateness rate but **1,817** late orders because its volume is much larger.

**Action:** consider RJ a candidate for a volume-and-rate investigation; also inspect SP for high absolute affected volume. Treat small high-rate states as a separate service-reliability question. The analysis suppresses states below 100 eligible deliveries, but that is a practical threshold, not a statistical confidence guarantee.

Evidence: `sql/analysis/04_delivery_by_state.sql`, `results/04_delivery_by_state.csv`.

### 4. Seller diagnostics need the correct attribution

The watchlist contains **201 sellers** with at least 100 eligible single-seller orders in the window. The highest late-volume seller has **168 late orders out of 1,673**, a **10.04%** rate. The source also contains **1,278 multi-seller orders** overall; assigning a shared late delivery or review to every seller could be misleading.

**Action:** investigate the top-volume watchlist using destination and category breakdowns. Request carrier and seller-handoff data before blaming a seller. The watchlist is an investigation tool, not a penalty score.

Evidence: `sql/analysis/06_seller_watchlist.sql`, `results/06_seller_watchlist.csv`.

### 5. Customer behavior requires the right identity and observation window

Within the main window, **2,789 of 93,104** observed purchasing customers placed at least two delivered orders: **3.00%**. These customers account for **5.50%** of delivered item GMV. The analysis uses customer_unique_id; grouping only by customer_id would misidentify order-linked records as distinct customers.

**Action:** examine customer purchase intervals and category needs before proposing a repeat-purchase campaign. Do not interpret this bounded historical share as a lifetime retention rate. The cohort table gives comparable month-age cells and omits future, unobserved cells.

Evidence: `sql/analysis/07_repeat_purchase.sql`, `sql/analysis/08_purchase_cohorts.sql`.

## Technical experiment

For the same date-filter result of **307 orders**, the recorded local run changed the plan from sequential scan to indexed bitmap scan after adding a timestamp index and using a half-open range. Three warm executions per stage and buffer information are saved in `results/query_optimization.json`.

Exact timings vary by run; the committed result file is the source of timing claims. The WASM engine shares PostgreSQL SQL/planner behavior but these timings are not production-server benchmarks. Predicate rewrite and index addition are measured in separate stages.

## Limits and next data needed

- Historical public snapshot; sparse boundary months and recent-order follow-up can affect comparisons.
- No cost, commission, refund ledger, marketing spend or site visits. GMV is not company revenue; profit and visitor conversion are unavailable.
- 8 delivered orders lack delivery timestamps and are excluded from lateness eligibility, not from all source totals.
- 249 orders with both items and payments differ by more than BRL 1. Those source discrepancies are visible and are not forced to reconcile to each other.
- Stronger delivery diagnosis needs carrier-level events, promises/changes, dispatch times and regional/product controls.

This project produces reproducible analysis and proposed actions. It does not report real operational changes or business uplift.
