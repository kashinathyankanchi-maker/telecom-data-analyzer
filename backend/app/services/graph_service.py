"""
services/graph_service.py — Link Analysis Graph Computation (Feature C).

Given one or more "suspect" phone numbers, this service builds a contact graph:
  - Nodes = phone numbers
  - Edges = direct call relationships (CDR row exists between the two numbers)
  - Node metadata = SDR subscriber info (if available)

The graph is returned as a plain dict (JSON-serialisable) that Flutter can
consume directly:
    {
        "nodes": [{"id": str, "label": str, "is_suspect": bool, "subscriber": {...}|null}],
        "edges": [{"source": str, "target": str, "call_count": int, "total_duration": int}]
    }

Depth control:
  - depth=1  → only direct contacts of suspects
  - depth=2  → contacts of contacts (can be large — use with caution)
"""
from __future__ import annotations

from sqlalchemy import or_, func, select
from sqlalchemy.orm import Session

from app.models.cdr import CDR
from app.models.sdr import SDR


def build_contact_graph(
    suspect_numbers: list[str],
    db: Session,
    depth: int = 1,
) -> dict:
    """
    Build a link-analysis graph centred on `suspect_numbers`.

    Args:
        suspect_numbers: The seed phone numbers to start from.
        db:             SQLAlchemy session.
        depth:          How many hops to expand (1 or 2).

    Returns:
        A JSON-serialisable dict with "nodes" and "edges" lists.
    """
    depth = max(1, min(depth, 2))  # clamp to 1–2

    all_numbers: set[str] = set(suspect_numbers)
    edges_raw: dict[tuple[str, str], dict] = {}

    def _expand(numbers: set[str]) -> set[str]:
        """Find all direct contacts of `numbers` and record edges."""
        new_contacts: set[str] = set()
        if not numbers:
            return new_contacts

        filter_clause = or_(
            CDR.caller_number.in_(numbers),
            CDR.receiver_number.in_(numbers),
        )
        # Aggregate edges: (caller, receiver) → (call_count, total_duration)
        agg_rows = db.execute(
            select(
                CDR.caller_number,
                CDR.receiver_number,
                func.count(CDR.id).label("call_count"),
                func.coalesce(func.sum(CDR.duration_seconds), 0).label("total_duration"),
            )
            .where(filter_clause)
            .group_by(CDR.caller_number, CDR.receiver_number)
        ).all()

        for row in agg_rows:
            # Canonical edge key: smaller number first (undirected)
            a, b = sorted([row.caller_number, row.receiver_number])
            key = (a, b)
            if key not in edges_raw:
                edges_raw[key] = {"call_count": 0, "total_duration": 0}
            edges_raw[key]["call_count"] += row.call_count
            edges_raw[key]["total_duration"] += row.total_duration

            new_contacts.add(row.caller_number)
            new_contacts.add(row.receiver_number)

        return new_contacts - numbers

    # Hop 1
    hop1 = _expand(all_numbers)
    all_numbers |= hop1

    # Hop 2 (optional)
    if depth >= 2:
        hop2 = _expand(hop1)
        all_numbers |= hop2

    # Fetch subscriber info for all discovered numbers in one query
    sdrs = db.execute(
        select(SDR).where(SDR.phone_number.in_(all_numbers))
    ).scalars().all()
    sdr_map = {s.phone_number: s for s in sdrs}

    suspect_set = set(suspect_numbers)

    nodes = []
    for num in all_numbers:
        sdr = sdr_map.get(num)
        nodes.append({
            "id": num,
            "label": sdr.subscriber_name if sdr and sdr.subscriber_name else num,
            "is_suspect": num in suspect_set,
            "subscriber": {
                "phone_number": sdr.phone_number,
                "subscriber_name": sdr.subscriber_name,
                "address": sdr.address,
                "activation_date": sdr.activation_date.isoformat() if sdr.activation_date else None,
            } if sdr else None,
        })

    edges = [
        {
            "source": k[0],
            "target": k[1],
            "call_count": v["call_count"],
            "total_duration": v["total_duration"],
        }
        for k, v in edges_raw.items()
    ]

    return {"nodes": nodes, "edges": edges}
