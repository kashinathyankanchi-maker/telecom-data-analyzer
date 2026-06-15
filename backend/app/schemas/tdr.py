"""
schemas/tdr.py — Pydantic schemas for Tower Detail Record.
"""
from pydantic import BaseModel, Field


class TDRBase(BaseModel):
    cell_id: str = Field(..., max_length=64, description="Unique cell tower identifier")
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    azimuth: int | None = Field(None, ge=0, le=359, description="Antenna direction in degrees")


class TDRCreate(TDRBase):
    """Schema used for creating / upserting a TDR row."""
    pass


class TDRRead(TDRBase):
    """Schema returned by API responses — identical to Base for TDR."""

    model_config = {"from_attributes": True}
