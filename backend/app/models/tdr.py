"""
models/tdr.py — Tower Detail Record (TDR)

cell_id is the primary key that CDR records reference (foreign key).
Stored first because CDR has a FK dependency on it.
"""
from sqlalchemy import Column, String, Float, Integer
from app.database import Base


class TDR(Base):
    """
    Tower Detail Record.
    Represents a physical cell tower / base station.
    """
    __tablename__ = "tdr"

    # Primary key — typically a string like "SITE-001" or "3456-7"
    cell_id = Column(String(64), primary_key=True, index=True, nullable=False)

    # Geographic coordinates of the tower
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    # Direction the antenna sector faces (0–359 degrees, 0 = North)
    azimuth = Column(Integer, nullable=True)

    def __repr__(self) -> str:
        return f"<TDR cell_id={self.cell_id!r} lat={self.latitude} lon={self.longitude}>"
