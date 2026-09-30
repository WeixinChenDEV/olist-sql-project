# Findings

Most comparisons below use purchases from January 2017 to August 2018. Prices are in Brazilian reais (BRL). Item sales exclude shipping fees. The order status comes from the dataset snapshot.

## Sales

The top three categories by delivered item value were health and beauty, watches and gifts, and bed/bath/table products. Together they accounted for about 25.92% of delivered sales in the selected period.

The monthly query uses `LAG` to compare each month with the previous one. For example, November 2017 was 52.37% above October, followed by a 26.50% decrease in December. The data alone does not explain the change.

Queries: `02_monthly_sales.sql`, `03_products.sql`.

## Delivery and reviews

| Delivery | Reviewed orders | Average score | Score 1 or 2 |
|---|---:|---:|---:|
| Late | 6,378 | 2.27 | 62.42% |
| On time | 89,182 | 4.29 | 9.25% |

Late deliveries had more low reviews. This comparison does not control for region, product, or seller, so it should not be treated as a causal result.

Rio de Janeiro had 1,495 late orders out of 12,310 eligible orders, or 12.14%. Alagoas had a higher rate of 21.46%, but only 396 eligible orders. Looking only at the highest percentage would miss the different group sizes.

The seller query keeps single-seller orders and sellers with at least 100 eligible deliveries. It is a way to choose cases for further investigation, not evidence that a particular seller caused the delay.

Queries: `04_delivery.sql`, `05_reviews.sql`, `06_sellers.sql`.

## Repeat customers

Of the 93,104 customers who bought at least once in the selected window, 2,789 bought more than once: 3.00%. They accounted for 5.50% of delivered item value.

The customer key is `customer_unique_id`. Using `customer_id` would separate order-linked records that belong to the same person. The cohort query uses the first purchase visible in the source and leaves out later months that are not observed. This is not a lifetime retention estimate.

Queries: `07_repeat_customers.sql`, `08_cohorts.sql`.

## A JOIN issue

An order can have several items, payments, and reviews. Joining all three detail tables directly repeats rows and may also exclude orders with missing records.

For January 2018, item prices totalled BRL 950,030.36. The direct join returned BRL 982,295.30, which was 3.40% too high. Grouping items and payments by order first, then selecting one review, kept the correct total.

Query: `10_joins.sql`. The order summary is built in `cleaning.sql`.

## Query plans

The date-filter experiment returns the same 307 orders in all three versions: date cast, timestamp range, and timestamp range with an index. The indexed range uses a bitmap index scan in the local run. Each version is measured three times after a warm-up; the plans are in `results/query_plans.json`.

These are local PGlite measurements. The exact times can change between runs and are not a production benchmark.

## Limits

There is no cost, commission, or visitor data, so this project does not calculate profit or website conversion. Eight delivered orders lack delivery timestamps and are excluded from the late-rate denominator. Payment differences are reported in `09_payments.csv` rather than silently changed.
