import argparse
import logging
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger(__name__)

BUCKET = "hw-bucket-sishabalova"
S3_DATA_PATH = f"s3a://{BUCKET}/2019-08-22.txt"
S3_CLEAN_DATA_PATH = f"s3a://{BUCKET}/cleaned_transactions"

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input",  default=S3_DATA_PATH)
    p.add_argument("--output", default=S3_CLEAN_DATA_PATH)
    return p.parse_args()

def main():
    args = parse_args()

    spark = SparkSession.builder.appName("FraudCleaner").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")

    log.info(f"Чтение файла: {args.input}")
    raw_data = spark.read.text(args.input)
    raw_data_clean = raw_data.filter(~F.col("value").startswith("#"))
    split_col = F.split(F.col("value"), ",")

    df = raw_data_clean.select(
        split_col.getItem(0).cast("long").alias("tranaction_id"),
        split_col.getItem(1).alias("tx_datetime"),
        split_col.getItem(2).cast("long").alias("customer_id"),
        split_col.getItem(3).cast("long").alias("terminal_id"),
        split_col.getItem(4).cast("double").alias("tx_amount"),
        split_col.getItem(5).cast("long").alias("tx_time_seconds"),
        split_col.getItem(6).cast("long").alias("tx_time_days"),
        split_col.getItem(7).cast("int").alias("tx_fraud"),
        split_col.getItem(8).cast("int").alias("tx_fraud_scenario"),
    )

    initial = df.count()
    log.info(f"Строк до очистки: {initial:,}")

    df = df.dropDuplicates()
    log.info(f"После удаления дубликатов: {df.count():,}")

    df = df.filter(F.col("tx_amount") > 0)
    log.info(f"После удаления неположительных 'tx_amount': {df.count():,}")

    df = df.withColumn("tx_ts", F.to_timestamp("tx_datetime"))
    df = df.filter(F.col("tx_ts").isNotNull()).drop("tx_ts")
    log.info(f"После удаления некорректного tx_datetime: {df.count():,}")

    df = df.na.fill({"tx_fraud": 0, "tx_fraud_scenario": 0})

    log.info(f"Строк после очистки: {df.count():,} ({df.count()/initial*100:.1f}%)")

    log.info(f"Сохранено в: {args.output}")
    df.write.mode("overwrite").parquet(args.output)

    spark.stop()

if __name__ == "__main__":
    main()
