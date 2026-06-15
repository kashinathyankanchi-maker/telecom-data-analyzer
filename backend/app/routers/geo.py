"""
routers/geo.py — Geo-Mapping Tower Data Endpoint (Feature D).

GET /api/v1/towers?phone=<number>&start_date=<ISO>&end_date=<ISO>
"""
from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.geo_service import get_tower_map

router = APIRouter(prefix="/towers", tags=["Geo Mapping"])


@router.get(
    "",
    summary="Get cell tower geo data for a phone number",
    response_description="Tower locations and chronological call timeline",
)
def get_towers(
    phone: str = Query(..., min_length=3, description="Phone number to map"),
    start_date: datetime | None = Query(
        None,
        description="Filter calls from this UTC datetime (ISO 8601)",
    ),
    end_date: datetime | None = Query(
        None,
        description="Filter calls up to this UTC datetime (ISO 8601)",
    ),
    db: Session = Depends(get_db),
):
    """
    Return cell tower geographic data for a given phone number.

    The response contains:
    - **towers**: Unique towers used, with lat/lon and usage stats.
    - **timeline**: Every CDR event in chronological order, linked to a tower.

    Use this data to render:
    - Markers on a `flutter_map` for each tower.
    - A `Polyline` connecting towers in order of call time.
    """
    return get_tower_map(
        phone=phone,
        db=db,
        start_date=start_date,
        end_date=end_date,
    )
