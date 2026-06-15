"""
routers/ingest.py — CSV Upload Endpoint (Feature A).

POST /api/v1/upload/{record_type}
    Accepts a multipart/form-data file upload.
    record_type path param: "cdr" | "sdr" | "tdr"
"""
from fastapi import APIRouter, Depends, File, HTTPException, Path, UploadFile
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.ingestion import ingest_csv, RecordType

router = APIRouter(prefix="/upload", tags=["Data Ingestion"])

VALID_TYPES = {"cdr", "sdr", "tdr"}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB hard limit


@router.post(
    "/{record_type}",
    summary="Upload a CSV file for bulk ingestion",
    response_description="Ingestion summary: rows inserted, skipped, and error details",
)
async def upload_csv(
    record_type: str = Path(
        ...,
        description="Type of record to ingest: cdr, sdr, or tdr",
        pattern="^(cdr|sdr|tdr)$",
    ),
    file: UploadFile = File(..., description="CSV file to upload"),
    db: Session = Depends(get_db),
):
    """
    Upload and ingest a CSV file containing CDR, SDR, or TDR records.

    - **record_type**: One of `cdr`, `sdr`, or `tdr`.
    - **file**: A CSV file with headers. Column names are flexible — see docs for aliases.

    Returns a summary of how many rows were inserted, skipped, and any per-row errors.
    """
    # Validate content type (loose check — also accept text/plain from some clients)
    if file.content_type not in ("text/csv", "application/csv", "text/plain", "application/octet-stream"):
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type: {file.content_type!r}. Please upload a CSV file.",
        )

    # Read content and enforce size limit
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"File too large ({len(content) / 1024 / 1024:.1f} MB). Maximum allowed is 50 MB.",
        )

    try:
        result = ingest_csv(content, record_type=record_type, db=db)  # type: ignore[arg-type]
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except RuntimeError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    return result
