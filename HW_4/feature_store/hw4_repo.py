# Это пример файла с определением признаков (feature definition)

import os

from datetime import timedelta

import numpy as np
import pandas as pd

from feast import (
    Entity,
    FeatureService,
    FeatureView,
    Field,
    FileSource,
    PushSource,
    RequestSource,
)
from feast.feature_logging import LoggingConfig
from feast.infra.offline_stores.file_source import FileLoggingDestination
from feast.on_demand_feature_view import on_demand_feature_view
from feast.types import Float32, Float64, Int64


REPO_PATH = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(REPO_PATH, "data")


driver = Entity(name="driver", join_keys=["driver_id"])

driver_stats_source = FileSource(
    name="driver_hourly_stats_source",
    path=os.path.join(DATA_PATH, "driver_stats.parquet"),
    timestamp_field="event_timestamp",
    created_timestamp_column="created",
)

driver_conversion_fv = FeatureView(
    name="driver_conversion_fv",
    entities=[driver],
    ttl=timedelta(days=1),
    schema=[
        Field(name="conv_rate", dtype=Float32),
        Field(name="acc_rate",  dtype=Float32),
    ],
    online=True,
    source=driver_stats_source,
    tags={"purpose": "churn_prediction"},
)

driver_activity_fv = FeatureView(
    name="driver_activity_fv",
    entities=[driver],
    ttl=timedelta(days=1),
    schema=[
        Field(name="avg_daily_trips", dtype=Int64),
    ],
    online=True,
    source=driver_stats_source,
    tags={"purpose": "activity_monitoring"},
)

input_request = RequestSource(
    name="input_request",
    schema=[
        Field(name="val_to_add",   dtype=Int64),
        Field(name="val_to_add_2", dtype=Int64),
    ],
)

@on_demand_feature_view(
    sources=[driver_conversion_fv, driver_activity_fv, input_request],
    schema=[
        Field(name="conv_rate_plus_val1", dtype=Float64),
        Field(name="conv_rate_plus_val2", dtype=Float64),
        Field(name="performance_score",   dtype=Float64),
        Field(name="trips_x_acc_rate",    dtype=Float64),
    ],
)
def driver_rt_odfv(inputs: pd.DataFrame) -> pd.DataFrame:
    df = pd.DataFrame()

    df["conv_rate_plus_val1"] = (
        inputs["conv_rate"].astype(float) + inputs["val_to_add"].astype(float)
    )
    df["conv_rate_plus_val2"] = (
        inputs["conv_rate"].astype(float) + inputs["val_to_add_2"].astype(float)
    )
    df["performance_score"] = (
        0.6 * inputs["conv_rate"].astype(float)
        + 0.4 * inputs["acc_rate"].astype(float)
    )
    df["trips_x_acc_rate"] = (
        inputs["avg_daily_trips"].astype(float)
        * inputs["acc_rate"].astype(float)
    )
    return df

driver_model_v1 = FeatureService(
    name="driver_model_v1",
    features=[driver_conversion_fv, driver_activity_fv, driver_rt_odfv],
)
