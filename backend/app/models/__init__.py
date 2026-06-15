# models/__init__.py
# Re-export all models so Alembic's env.py can discover them with a single import.
from app.models.cdr  import CDR   # noqa: F401
from app.models.sdr  import SDR   # noqa: F401
from app.models.tdr  import TDR   # noqa: F401
from app.models.user import User  # noqa: F401
