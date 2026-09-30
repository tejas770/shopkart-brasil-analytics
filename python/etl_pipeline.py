import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from Python.Extraction.load_data import extract, validate, save_processed
from Python.Cleaning.clean import clean_orders, clean_reviews, clean_products
from logger_setup import logger
from sqlalchemy import create_engine, text, inspect

DB_URL = "postgresql://postgres:Olist%40123@localhost:5432/shopkart_analytics"
engine = create_engine(DB_URL)

LOAD_ORDER = [
    "customers",
    "sellers",
    "products",
    "category_translation",
    "orders",
    "order_items",
    "order_payments",
    "order_reviews",
    "geolocation",
]


def load_to_postgres(dfs):
    logger.info("Clearing old PostgreSQL data...")
    tables = ", ".join(f"olist.{t}" for t in LOAD_ORDER)
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {tables} CASCADE;"))
    logger.info("Old PostgreSQL data cleared")

    insp = inspect(engine)
    for name in LOAD_ORDER:
        db_cols = [c["name"] for c in insp.get_columns(name, schema="olist")]
        missing = [c for c in db_cols if c not in dfs[name].columns]
        if missing:
            raise ValueError(f"{name}: columns missing in DataFrame: {missing}")
        logger.info(f"Loading {name} to PostgreSQL...")
        rows = dfs[name][db_cols].to_sql(
            name,
            engine,
            schema="olist",
            if_exists="append",
            index=False,
            chunksize=5000,
            method="multi",
        )
        logger.info(f"Loaded {rows} rows into olist.{name}")


def run_pipeline():
    logger.info("=" * 40)
    logger.info("ETL Pipeline started")
    logger.info("=" * 40)

    logger.info("STEP 1: Extracting data")
    dfs = extract()

    logger.info("STEP 2: Validating data")
    validate(dfs)

    logger.info("STEP 3: Cleaning data")
    dfs["orders"] = clean_orders(dfs["orders"])
    dfs["order_reviews"] = clean_reviews(dfs["order_reviews"])
    dfs["products"] = clean_products(dfs["products"], dfs["category_translation"])

    dup_orders = dfs["order_reviews"]["order_id"].duplicated().sum()
    logger.info(f"Duplicate order_id in reviews after cleaning: {dup_orders}")
    if dup_orders != 0:
        raise ValueError("Duplicate order_id still exists in reviews!")

    logger.info("STEP 4: Saving processed Parquet files")
    save_processed(dfs)

    logger.info("STEP 5: Loading data into PostgreSQL")
    load_to_postgres(dfs)

    logger.info("=" * 40)
    logger.info("ETL Pipeline completed successfully")
    logger.info("=" * 40)


if __name__ == "__main__":
    run_pipeline()