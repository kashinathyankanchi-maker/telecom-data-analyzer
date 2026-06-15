"""
models/cdr.py — Call Detail Record (CDR)

The primary fact table of the system. Each row represents a single phone call.
References TDR via cell_id (soft FK — no DB-level constraint to allow partial loads).
"""
import enum
from sqlalchemy import (
    Column, Integer, String, DateTime, Enum, ForeignKey, Index
)
from app.database import Base


class CallType(str, enum.Enum):
    """Direction of a call relative to the subscriber."""
    incoming = "incoming"
    outgoing = "outgoing"


class CDR(Base):
    """
    Call Detail Record.
    Captures metadata about every individual call event.
    """
    __tablename__ = "cdr"

    # Surrogate primary key
    id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Parties involved
    caller_number = Column(String(20), nullable=False, index=True)
    receiver_number = Column(String(20), nullable=False, index=True)

    # When the call happened (store in UTC)
    call_time = Column(DateTime(timezone=True), nullable=False, index=True)

    # How long the call lasted
    duration_seconds = Column(Integer, nullable=True, default=0)

    # Direction of the call
    call_type = Column(Enum(CallType), nullable=False)

    # Device identifier — useful for multi-SIM / cloned-SIM detection
    imei_number = Column(String(20), nullable=True, index=True)

    # Cell tower the call was routed through.
    # Declared as a soft FK (no DB-level constraint) so CDR rows can be
    # loaded before TDR data is fully populated.
    cell_id = Column(
        String(64),
        ForeignKey("tdr.cell_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ── Composite indices for common query patterns ────────────────────────
    __table_args__ = (
        # Quickly fetch all calls for a number sorted by time
        Index("ix_cdr_caller_time", "caller_number", "call_time"),
        Index("ix_cdr_receiver_time", "receiver_number", "call_time"),
        # Quickly look up all calls from a specific device
        Index("ix_cdr_imei_time", "imei_number", "call_time"),
    )

    def __repr__(self) -> str:
        return (
            f"<CDR id={self.id} "
            f"{self.caller_number!r}→{self.receiver_number!r} "
            f"@ {self.call_time}>"
        )
