import pandas as pd


def clean_orders(df):
    df = df.copy()

    df["order_purchase_timestamp"] = pd.to_datetime(
        df["order_purchase_timestamp"],
        errors="coerce"
    )

    df["order_delivered_customer_date"] = pd.to_datetime(
        df["order_delivered_customer_date"],
        errors="coerce"
    )

    df["order_estimated_delivery_date"] = pd.to_datetime(
        df["order_estimated_delivery_date"],
        errors="coerce"
    )

    return df


def clean_reviews(df):
    df = df.copy()

    # Convert timestamp
    df["review_answer_timestamp"] = pd.to_datetime(
        df["review_answer_timestamp"],
        errors="coerce"
    )

    # Keep the latest review for each order
    df = (
        df.sort_values("review_answer_timestamp")
        .drop_duplicates(
            subset="order_id",
            keep="last"
        )
        .reset_index(drop=True)
    )

    return df
def clean_products(df, category_translation):
    df = df.copy()
    category_translation = category_translation.copy()

    # Fill missing category
    df["product_category_name"] = df[
        "product_category_name"
    ].fillna("unknown")

    # Merge English category names
    df = df.merge(
        category_translation,
        on="product_category_name",
        how="left"
    )

    # Fill missing English category
    df["product_category_name_english"] = df[
        "product_category_name_english"
    ].fillna("unknown")

    # Fill missing numerical values using median
    for col in [
        "product_weight_g",
        "product_length_cm",
        "product_height_cm",
        "product_width_cm"
    ]:
        df[col] = df[col].fillna(
            df[col].median()
        )

    return df