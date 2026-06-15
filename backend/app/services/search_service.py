"""
services/search_service.py — Global Search Business Logic (Feature B).

Given a phone number or IMEI, this service:
  1. Looks up the subscriber record (SDR) by phone number.
  2. Queries CDR for all call records involving that number.
  3. Computes a summary (total calls, duration, date range, unique contacts, towers).
  4. Returns up to `limit` individual CDR rows for the detailed call log.
"""
from __future__ import annotations

from sqlalchemy import or_, func, select
from sqlalchemy.orm import Session

from app.models.cdr import CDR
from app.models.sdr import SDR
from app.schemas.cdr import CDRRead, CDRSummary
from app.schemas.sdr import SDRRead


def search_by_phone(
    phone: str,
    db: Session,
    limit: int = 100,
    offset: int = 0,
) -> dict:
    """
    Search all records associated with a phone number.

    Returns:
        {
            "subscriber": SDRRead | None,
            "summary": CDRSummary,
            "call_log": [CDRRead, ...]   # paginated
        }
    """
    # 1. Subscriber lookup
    subscriber = db.get(SDR, phone)
    subscriber_out = SDRRead.model_validate(subscriber) if subscriber else None

    # 2. Base CDR filter — rows where this number appears as caller OR receiver
    cdr_filter = or_(CDR.caller_number == phone, CDR.receiver_number == phone)

    # 3. Aggregate summary (single DB round-trip)
    agg = db.execute(
        select(
            func.count(CDR.id).label("total_calls"),
            func.coalesce(func.sum(CDR.duration_seconds), 0).label("total_duration"),
            func.min(CDR.call_time).label("first_seen"),
            func.max(CDR.call_time).label("last_seen"),
            func.count(func.distinct(
                # unique contacts = the "other" party in each call
                # We concatenate caller+receiver and pick the one that != phone
                # PostgreSQL CASE approach
                CDR.caller_number
            )).label("unique_callers"),
            func.count(func.distinct(CDR.cell_id)).label("unique_towers"),
        ).where(cdr_filter)
    ).one()

    # Count unique contacts properly: union of callers and receivers excluding self
    unique_contacts_q = db.execute(
        select(func.count()).select_from(
            select(func.distinct(CDR.receiver_number).label("contact"))
            .where(CDR.caller_number == phone)
            .union(
                select(func.distinct(CDR.caller_number).label("contact"))
                .where(CDR.receiver_number == phone)
            )
            .subquery()
        )
    ).scalar() or 0

    summary = CDRSummary(
        phone_number=phone,
        total_calls=agg.total_calls or 0,
        total_duration_seconds=agg.total_duration or 0,
        first_seen=agg.first_seen,
        last_seen=agg.last_seen,
        unique_contacts=unique_contacts_q,
        unique_towers=agg.unique_towers or 0,
    )

    # 4. Paginated call log
    rows = (
        db.execute(
            select(CDR)
            .where(cdr_filter)
            .order_by(CDR.call_time.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .all()
    )
    call_log = [CDRRead.model_validate(r) for r in rows]

    return {
        "subscriber": subscriber_out,
        "summary": summary,
        "call_log": call_log,
    }


def search_by_imei(
    imei: str,
    db: Session,
    limit: int = 100,
    offset: int = 0,
) -> dict:
    """
    Search all CDR records associated with a specific IMEI number.

    Returns:
        {
            "imei": str,
            "associated_numbers": [str, ...],   # distinct phone numbers seen on this IMEI
            "call_log": [CDRRead, ...]
        }
    """
    imei_filter = CDR.imei_number == imei

    # Distinct numbers that have used this IMEI
    associated = (
        db.execute(
            select(func.distinct(CDR.caller_number)).where(imei_filter)
        )
        .scalars()
        .all()
    )

    rows = (
        db.execute(
            select(CDR)
            .where(imei_filter)
            .order_by(CDR.call_time.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .all()
    )

    return {
        "imei": imei,
        "associated_numbers": list(associated),
        "call_log": [CDRRead.model_validate(r) for r in rows],
    }
