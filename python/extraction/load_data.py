import pandas as pd
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).resolve().parents[2]

RAW_DIR = PROJECT_ROOT / "data" / "raw"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"


FILES = {
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}


def extract():
    """Load all raw CSV files into DataFrames."""

    dfs = {}

    for name, filename in FILES.items():

        try:
            dfs[name] = pd.read_csv(RAW_DIR / filename)

            print(
                f"Loaded {name}: "
                f"{dfs[name].shape[0]} rows, "
                f"{dfs[name].shape[1]} columns"
            )

        except FileNotFoundError:
            print(f"Missing file: {filename}")
            raise

    return dfs


def validate(dfs):
    """Basic validation of important datasets."""

    expected_min_rows = {
        "orders": 90000,
        "customers": 90000
    }

    for name, min_rows in expected_min_rows.items():

        actual_rows = dfs[name].shape[0]

        if actual_rows < min_rows:
            print(
                f"WARNING: {name} has fewer rows than expected: "
                f"{actual_rows}"
            )
        else:
            print(
                f"Validation passed: {name} = "
                f"{actual_rows} rows"
            )


def save_processed(dfs):
    """Save processed DataFrames as Parquet files."""

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    for name, df in dfs.items():

        output_file = PROCESSED_DIR / f"{name}.parquet"

        df.to_parquet(
            output_file,
            index=False
        )

        print(f"Saved processed: {name}")


def load_all():
    """Backward-compatible function."""

    return extract()


if __name__ == "__main__":
    dfs = extract()
    validate(dfs)
    save_processed(dfs)