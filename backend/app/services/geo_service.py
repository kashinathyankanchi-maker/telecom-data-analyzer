"""
services/geo_service.py — Tower Geo-Mapping Data (Feature D).

Joins CDR with TDR to produce a chronological sequence of tower connections
for a given phone number. The Flutter client renders this as:
  - Circle markers on a flutter_map for each tower.
  - A Polyline layer connecting towers in chronological call order.

Response shape:
    {
        "phone_number": str,
        "towers": [
            {
                "cell_id": str,
                "latitude": float,
                "longitude": float,
                "azimuth": int | null,
                "first_contact": datetime,
                "last_contact": datetime,
                "call_count": int,
            },
            ...
        ],
        "timeline": [
            {
                "call_time": datetime,
                "cell_id": str,
                "caller_number": str,
                "receiver_number": str,
                "duration_seconds": int,
            },
            ...
        ]
    }
"""
from __future__ import annotations

from datetime import datetime
from sqlalchemy import or_, select, func
from sqlalchemy.orm import Session

from app.models.cdr import CDR
from app.models.tdr import TDR


def get_tower_map(
    phone: str,
    db: Session,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> dict:
    """
    Return geo data (towers + timeline) for a phone number.

    Args:
        phone:      The phone number to query.
        db:         SQLAlchemy session.
        start_date: Optional lower bound for call_time filter (UTC).
        end_date:   Optional upper bound for call_time filter (UTC).
    """
    cdr_filter = or_(CDR.caller_number == phone, CDR.receiver_number == phone)

    if start_date:
        cdr_filter = cdr_filter & (CDR.call_time >= start_date)
    if end_date:
        cdr_filter = cdr_filter & (CDR.call_time <= end_date)

    # ── 1. Tower summary ────────────────────────────────────────────────────
    tower_rows = db.execute(
        select(
            TDR.cell_id,
            TDR.latitude,
            TDR.longitude,
            TDR.azimuth,
            func.min(CDR.call_time).label("first_contact"),
            func.max(CDR.call_time).label("last_contact"),
            func.count(CDR.id).label("call_count"),
        )
        .join(CDR, CDR.cell_id == TDR.cell_id)
        .where(cdr_filter)
        .group_by(TDR.cell_id, TDR.latitude, TDR.longitude, TDR.azimuth)
        .order_by(func.min(CDR.call_time))
    ).all()

    towers = [
        {
            "cell_id": r.cell_id,
            "latitude": r.latitude,
            "longitude": r.longitude,
            "azimuth": r.azimuth,
            "first_contact": r.first_contact.isoformat() if r.first_contact else None,
            "last_contact": r.last_contact.isoformat() if r.last_contact else None,
            "call_count": r.call_count,
        }
        for r in tower_rows
    ]

    # ── 2. Chronological timeline ────────────────────────────────────────────
    timeline_rows = db.execute(
        select(
            CDR.call_time,
            CDR.cell_id,
            CDR.caller_number,
            CDR.receiver_number,
            CDR.duration_seconds,
        )
        .where(cdr_filter)
        .where(CDR.cell_id.is_not(None))
        .order_by(CDR.call_time.asc())
    ).all()

    timeline = [
        {
            "call_time": r.call_time.isoformat() if r.call_time else None,
            "cell_id": r.cell_id,
            "caller_number": r.caller_number,
            "receiver_number": r.receiver_number,
            "duration_seconds": r.duration_seconds,
        }
        for r in timeline_rows
    ]

    return {
        "phone_number": phone,
        "towers": towers,
        "timeline": timeline,
    }
