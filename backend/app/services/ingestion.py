"""
services/ingestion.py — CSV Parsing and Bulk Insertion Service.

This module is the core of Feature A. It uses Pandas to:
  1. Read the uploaded CSV file-like object into a DataFrame.
  2. Normalise column names (strip whitespace, lowercase).
  3. Handle missing / null data.
  4. Map rows to the appropriate ORM model and bulk-insert into PostgreSQL.

Design decisions:
  - Uses pandas `read_csv` for robust parsing (handles quoted fields, mixed
    line-endings, BOM markers, etc.).
  - Bulk insert via SQLAlchemy's `Session.bulk_insert_mappings` — much faster
    than inserting ORM objects one at a time.
  - Returns a structured result dict so the API can report successes/skips/errors
    back to the Flutter client.
"""
from __future__ import annotations

import io
import logging
from datetime import datetime, date
from typing import IO, Literal

import pandas as pd
from sqlalchemy.orm import Session

from app.models.cdr import CDR, CallType
from app.models.sdr import SDR
from app.models.tdr import TDR

logger = logging.getLogger(__name__)

RecordType = Literal["cdr", "sdr", "tdr"]

# ── Column name aliases ─────────────────────────────────────────────────────────
# Maps all plausible CSV header variants → the canonical field name.
CDR_COLUMN_MAP: dict[str, str] = {
    "caller": "caller_number",
    "caller_no": "caller_number",
    "calling_number": "caller_number",
    "receiver": "receiver_number",
    "receiver_no": "receiver_number",
    "called_number": "receiver_number",
    "called_party": "receiver_number",
    "timestamp": "call_time",
    "date_time": "call_time",
    "call_datetime": "call_time",
    "duration": "duration_seconds",
    "call_duration": "duration_seconds",
    "type": "call_type",
    "direction": "call_type",
    "imei": "imei_number",
    "device_id": "imei_number",
    "cell": "cell_id",
    "tower_id": "cell_id",
    "site_id": "cell_id",
}

SDR_COLUMN_MAP: dict[str, str] = {
    "phone": "phone_number",
    "msisdn": "phone_number",
    "number": "phone_number",
    "name": "subscriber_name",
    "full_name": "subscriber_name",
    "customer_name": "subscriber_name",
    "addr": "address",
    "activation": "activation_date",
    "sim_activation_date": "activation_date",
}

TDR_COLUMN_MAP: dict[str, str] = {
    "cell": "cell_id",
    "tower_id": "cell_id",
    "site_id": "cell_id",
    "lat": "latitude",
    "lon": "longitude",
    "lng": "longitude",
    "long": "longitude",
    "bearing": "azimuth",
    "direction": "azimuth",
}


def _normalise_columns(df: pd.DataFrame, alias_map: dict[str, str]) -> pd.DataFrame:
    """Lowercase + strip column names, then apply alias mapping."""
    df.columns = [c.strip().lower() for c in df.columns]
    df = df.rename(columns=alias_map)
    return df


def _safe_str(val) -> str | None:
    if pd.isna(val):
        return None
    return str(val).strip() or None


def _safe_int(val) -> int | None:
    try:
        return int(float(val))
    except (ValueError, TypeError):
        return None


def _safe_float(val) -> float | None:
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


def _safe_datetime(val) -> datetime | None:
    if pd.isna(val):
        return None
    try:
        return pd.to_datetime(val, utc=True).to_pydatetime()
    except Exception:
        return None


def _safe_date(val) -> date | None:
    if pd.isna(val):
        return None
    try:
        return pd.to_datetime(val).date()
    except Exception:
        return None


# ── CDR ingestion ───────────────────────────────────────────────────────────────

def _process_cdr(df: pd.DataFrame) -> tuple[list[dict], list[str]]:
    """Convert a raw CDR DataFrame into a list of insert dicts."""
    df = _normalise_columns(df, CDR_COLUMN_MAP)
    required = {"caller_number", "receiver_number", "call_time", "call_type"}
    missing_cols = required - set(df.columns)
    if missing_cols:
        raise ValueError(f"CDR CSV missing required columns: {missing_cols}")

    rows, errors = [], []
    for idx, row in df.iterrows():
        caller = _safe_str(row.get("caller_number"))
        receiver = _safe_str(row.get("receiver_number"))
        call_time = _safe_datetime(row.get("call_time"))
        raw_type = _safe_str(row.get("call_type", ""))

        # Skip rows that are missing critical fields
        if not caller or not receiver or call_time is None:
            errors.append(f"Row {idx}: skipped — missing caller/receiver/call_time")
            continue

        # Normalise call_type to enum value
        call_type_val = (raw_type or "").lower()
        if call_type_val not in ("incoming", "outgoing"):
            call_type_val = "incoming"  # safe default

        rows.append({
            "caller_number": caller,
            "receiver_number": receiver,
            "call_time": call_time,
            "duration_seconds": _safe_int(row.get("duration_seconds")) or 0,
            "call_type": CallType(call_type_val),
            "imei_number": _safe_str(row.get("imei_number")),
            "cell_id": _safe_str(row.get("cell_id")),
        })
    return rows, errors


def _process_sdr(df: pd.DataFrame) -> tuple[list[dict], list[str]]:
    """Convert a raw SDR DataFrame into a list of upsert dicts."""
    df = _normalise_columns(df, SDR_COLUMN_MAP)
    if "phone_number" not in df.columns:
        raise ValueError("SDR CSV missing required column: phone_number")

    rows, errors = [], []
    for idx, row in df.iterrows():
        phone = _safe_str(row.get("phone_number"))
        if not phone:
            errors.append(f"Row {idx}: skipped — missing phone_number")
            continue
        rows.append({
            "phone_number": phone,
            "subscriber_name": _safe_str(row.get("subscriber_name")),
            "address": _safe_str(row.get("address")),
            "activation_date": _safe_date(row.get("activation_date")),
        })
    return rows, errors


def _process_tdr(df: pd.DataFrame) -> tuple[list[dict], list[str]]:
    """Convert a raw TDR DataFrame into a list of upsert dicts."""
    df = _normalise_columns(df, TDR_COLUMN_MAP)
    required = {"cell_id", "latitude", "longitude"}
    missing_cols = required - set(df.columns)
    if missing_cols:
        raise ValueError(f"TDR CSV missing required columns: {missing_cols}")

    rows, errors = [], []
    for idx, row in df.iterrows():
        cell_id = _safe_str(row.get("cell_id"))
        lat = _safe_float(row.get("latitude"))
        lon = _safe_float(row.get("longitude"))

        if not cell_id or lat is None or lon is None:
            errors.append(f"Row {idx}: skipped — missing cell_id/lat/lon")
            continue
        rows.append({
            "cell_id": cell_id,
            "latitude": lat,
            "longitude": lon,
            "azimuth": _safe_int(row.get("azimuth")),
        })
    return rows, errors


# ── Public entry point ──────────────────────────────────────────────────────────

def ingest_csv(
    file_content: bytes,
    record_type: RecordType,
    db: Session,
) -> dict:
    """
    Parse the uploaded CSV bytes, clean data, and bulk-insert into the DB.

    Returns:
        {
            "record_type": str,
            "inserted": int,
            "skipped": int,
            "errors": [str, ...]
        }
    """
    # 1. Parse CSV
    try:
        df = pd.read_csv(
            io.BytesIO(file_content),
            encoding="utf-8-sig",  # strips BOM if present
            dtype=str,             # read everything as string first — we convert later
            keep_default_na=True,
        )
    except Exception as exc:
        raise ValueError(f"Failed to parse CSV: {exc}") from exc

    if df.empty:
        return {"record_type": record_type, "inserted": 0, "skipped": 0, "errors": ["CSV is empty"]}

    # 2. Process rows according to record type
    if record_type == "cdr":
        rows, errors = _process_cdr(df)
        model_cls = CDR
    elif record_type == "sdr":
        rows, errors = _process_sdr(df)
        model_cls = SDR
    elif record_type == "tdr":
        rows, errors = _process_tdr(df)
        model_cls = TDR
    else:
        raise ValueError(f"Unknown record_type: {record_type!r}")

    if not rows:
        return {
            "record_type": record_type,
            "inserted": 0,
            "skipped": len(df),
            "errors": errors,
        }

    # 3. Bulk insert
    #    For SDR and TDR (which have natural PKs) we use merge / upsert logic.
    #    For CDR (surrogate PK) we just bulk insert.
    try:
        if record_type == "cdr":
            db.bulk_insert_mappings(model_cls, rows)
        else:
            # Use merge (upsert) for SDR and TDR so re-uploading a CSV is idempotent
            for row in rows:
                db.merge(model_cls(**row))
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.exception("Bulk insert failed for %s", record_type)
        raise RuntimeError(f"Database insert failed: {exc}") from exc

    skipped = len(df) - len(rows)
    logger.info(
        "Ingested %s: inserted=%d skipped=%d errors=%d",
        record_type, len(rows), skipped, len(errors),
    )
    return {
        "record_type": record_type,
        "inserted": len(rows),
        "skipped": skipped,
        "errors": errors,
    }
