"""
models/sdr.py — Subscriber Detail Record (SDR)

Stores KYC-style information about a mobile subscriber.
phone_number is the primary key and is referenced by CDR caller/receiver fields.
"""
from sqlalchemy import Column, String, Text, Date
from app.database import Base


class SDR(Base):
    """
    Subscriber Detail Record.
    Identifies the human (or entity) behind a phone number.
    """
    __tablename__ = "sdr"

    # Primary key — E.164-style number recommended (e.g. "+919876543210")
    phone_number = Column(String(20), primary_key=True, index=True, nullable=False)

    # Subscriber identity
    subscriber_name = Column(String(255), nullable=True)
    address = Column(Text, nullable=True)

    # The date the SIM / subscription was first activated
    activation_date = Column(Date, nullable=True)

    def __repr__(self) -> str:
        return f"<SDR phone={self.phone_number!r} name={self.subscriber_name!r}>"
