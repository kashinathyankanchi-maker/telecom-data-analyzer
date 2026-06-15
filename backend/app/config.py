"""
config.py — Application settings loaded from environment variables / .env file.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Database
    database_url: str = "postgresql://postgres:password@localhost:5432/telecom_analyzer"

    # Server
    app_env: str = "development"
    app_host: str = "0.0.0.0"
    app_port: int = 8000

    # CORS — accept a comma-separated string and split it
    allowed_origins: str = "http://localhost,http://localhost:8080"

    # ── JWT Auth ────────────────────────────────────────────────────
    jwt_secret_key: str = "CHANGE_ME_TO_A_STRONG_RANDOM_SECRET_KEY"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440  # 24 hours

    # Default admin user seeded on first startup
    admin_username: str = "admin"
    admin_email: str = "admin@telecom.local"
    admin_password: str = "Admin@1234!"

    @property
    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings singleton (reads .env once)."""
    return Settings()
