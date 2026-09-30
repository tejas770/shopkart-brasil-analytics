import logging
from config import LOG_DIR

LOG_DIR.mkdir(exist_ok=True)
logger = logging.getLogger("etl")
if not logger.handlers:
    logger.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")
    for h in (logging.FileHandler(LOG_DIR / "etl_pipeline.log"), logging.StreamHandler()):
        h.setFormatter(fmt)
        logger.addHandler(h)