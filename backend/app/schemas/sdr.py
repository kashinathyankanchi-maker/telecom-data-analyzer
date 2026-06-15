"""
schemas/sdr.py — Pydantic schemas for Subscriber Detail Record.
"""
from datetime import date
from pydantic import BaseModel, Field


class SDRBase(BaseModel):
    phone_number: str = Field(..., max_length=20, description="Subscriber phone number (E.164 recommended)")
    subscriber_name: str | None = Field(None, max_length=255)
    address: str | None = None
    activation_date: date | None = None


class SDRCreate(SDRBase):
    """Schema used when creating / upserting an SDR row."""
    pass


class SDRRead(SDRBase):
    """Schema returned in API responses."""

    model_config = {"from_attributes": True}
