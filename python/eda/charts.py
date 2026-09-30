import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine

# PostgreSQL connection
engine = create_engine(
    "postgresql://postgres:Olist%40123@localhost:5432/shopkart_analytics"
)

sns.set_style("whitegrid")

# Chart 1 data
df = pd.read_sql("""
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
        100.0 * AVG(is_late::int) AS late_rate_pct
    FROM olist.v_delivered_orders
    WHERE order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp < '2018-09-01'
    GROUP BY 1
    ORDER BY 1
""", engine)

# Create chart
plt.figure(figsize=(10, 4))

plt.plot(
    df["month"],
    df["late_rate_pct"],
    marker="o"
)

plt.title("Monthly Late Delivery Rate (Jan 2017 - Aug 2018)")
plt.xlabel("Month")
plt.ylabel("Late Rate (%)")
plt.xticks(rotation=45)

plt.tight_layout()

# Save chart
plt.savefig(
    "reports/chart1_late_rate_trend.png",
    dpi=150,
    bbox_inches="tight"
)

plt.show()

# Chart 2 — Late vs On-time Review Score Distribution
# Chart 2 — Late vs On-time Review Score Distribution

df = pd.read_sql("""
    SELECT
        v.is_late,
        r.review_score
    FROM olist.v_delivered_orders v
    JOIN olist.order_reviews r
        ON r.order_id = v.order_id
""", engine)

df["group"] = df["is_late"].map({
    True: "Late",
    False: "On-time"
})

# Calculate percentage within each group
dist = (
    df.groupby(["group", "review_score"])
      .size()
      .groupby(level=0)
      .transform(lambda x: 100 * x / x.sum())
      .reset_index(name="percentage")
)

plt.figure(figsize=(7, 4))

sns.barplot(
    data=dist,
    x="review_score",
    y="percentage",
    hue="group"
)

plt.title("Review Score Distribution: Late vs On-time Orders")
plt.xlabel("Review Score")
plt.ylabel("% within group")

plt.tight_layout()

plt.savefig(
    "reports/chart2_review_distribution.png",
    dpi=150,
    bbox_inches="tight"
)

plt.show()


df = pd.read_sql("""
    WITH d AS (
        SELECT DATE_TRUNC('month', v.order_purchase_timestamp)::date AS month,
               (o.order_estimated_delivery_date::date - v.order_delivered_customer_date::date) AS buffer,
               v.is_late
        FROM olist.v_delivered_orders v
        JOIN olist.orders o ON o.order_id = v.order_id
        WHERE v.order_purchase_timestamp >= '2017-01-01' AND v.order_purchase_timestamp < '2018-09-01'
    )
    SELECT month, AVG(buffer) AS avg_buffer_days, 100.0*AVG(is_late::int) AS late_rate_pct
    FROM d GROUP BY month ORDER BY month
""", engine)

plt.figure(figsize=(6,5))
sns.regplot(data=df, x="avg_buffer_days", y="late_rate_pct")
plt.title("Monthly Promise Buffer vs Late Rate (r = -0.61)")
plt.xlabel("Avg Buffer (days)")
plt.ylabel("Late Rate (%)")
plt.tight_layout()
plt.savefig("reports/chart3_buffer_vs_late.png")
plt.show()


from scipy import stats

r, p_value = stats.pearsonr(
    df["avg_buffer_days"],
    df["late_rate_pct"]
)

print(f"r = {r:.3f}")
print(f"p-value = {p_value:.4f}")



import numpy as np

def ci_proportion(p_pct, n, z=1.96):
    p = p_pct / 100
    se = np.sqrt(p * (1 - p) / n)
    margin = z * se
    return (p - margin) * 100, (p + margin) * 100

print("SE:", ci_proportion(15.22, 335))
print("PI:", ci_proportion(13.87, 476))
print("BA:", ci_proportion(12.16, 3256))