"""
routers/graph.py — Link Analysis Graph Endpoint (Feature C).

POST /api/v1/graph
    Body: { "suspects": ["number1", "number2"], "depth": 1 }

POST is used (not GET) because the suspect list can be long.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.graph_service import build_contact_graph

router = APIRouter(prefix="/graph", tags=["Link Analysis"])


class GraphRequest(BaseModel):
    suspects: list[str] = Field(
        ...,
        min_length=1,
        max_length=20,
        description="List of suspect phone numbers to seed the graph",
    )
    depth: int = Field(
        1,
        ge=1,
        le=2,
        description="Graph expansion depth: 1 = direct contacts, 2 = contacts of contacts",
    )


@router.post(
    "",
    summary="Build a contact link-analysis graph",
    response_description="Nodes and edges of the contact network",
)
def get_graph(
    request: GraphRequest,
    db: Session = Depends(get_db),
):
    """
    Build a contact link-analysis graph for the provided suspect phone numbers.

    - **suspects**: Up to 20 seed phone numbers.
    - **depth**: `1` returns only direct contacts. `2` includes contacts-of-contacts.

    Returns a graph structure suitable for rendering with `graphview` in Flutter.
    """
    if not request.suspects:
        raise HTTPException(status_code=422, detail="At least one suspect number is required.")

    graph = build_contact_graph(
        suspect_numbers=request.suspects,
        db=db,
        depth=request.depth,
    )
    return graph
