"""
routers/search.py — Global Search Endpoint (Feature B).

GET /api/v1/search?q=<phone_or_imei>&type=phone|imei&limit=100&offset=0
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.search_service import search_by_phone, search_by_imei

router = APIRouter(prefix="/search", tags=["Search"])


@router.get(
    "",
    summary="Search CDR/SDR by phone number or IMEI",
)
def search(
    q: str = Query(..., min_length=3, description="Phone number or IMEI to search"),
    type: str = Query(
        "phone",
        pattern="^(phone|imei)$",
        description="Search mode: 'phone' or 'imei'",
    ),
    limit: int = Query(100, ge=1, le=500, description="Max CDR rows to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    db: Session = Depends(get_db),
):
    """
    Search telecom records.

    - **q**: A phone number (e.g. `+919876543210`) or IMEI (15-digit number).
    - **type**: `phone` returns subscriber details + call log summary.
               `imei` returns all numbers associated with that device.
    - **limit** / **offset**: Pagination controls for the call log.
    """
    if type == "phone":
        return search_by_phone(phone=q, db=db, limit=limit, offset=offset)
    elif type == "imei":
        return search_by_imei(imei=q, db=db, limit=limit, offset=offset)
    else:
        raise HTTPException(status_code=400, detail="Invalid search type")
