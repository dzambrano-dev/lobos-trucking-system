"""Legacy FastAPI/SQLite learning service.

The production Flutter app talks directly to Firebase. This small API remains
useful for studying parameterized SQL and HTTP basics, but it intentionally has
no production authentication or deployment configuration.
"""

from contextlib import asynccontextmanager
import os
from pathlib import Path
import sqlite3

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field


BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "database" / "lobos.db"
SCHEMA_PATH = BASE_DIR / "database" / "schema.sql"


def get_db() -> sqlite3.Connection:
    """Open a connection with the safety settings every request expects."""

    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Creating tables at startup keeps the demo's first run predictable. The
    # schema uses IF NOT EXISTS, so reopening the app does not erase any data.
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with get_db() as connection:
        connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
    yield


app = FastAPI(title="Lobos Trucking Legacy API", lifespan=lifespan)

allowed_origins = [
    origin.strip()
    for origin in os.getenv(
        "LOBOS_ALLOWED_ORIGINS",
        "http://localhost:3000,http://localhost:5000",
    ).split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Content-Type"],
)


class ClientCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    company_name: str = Field(min_length=1, max_length=150)
    contact_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(default="", max_length=40)
    email: str = Field(default="", max_length=254)
    address: str = Field(default="", max_length=300)


@app.get("/")
def root() -> dict[str, str]:
    return {"status": "Lobos Trucking legacy API running"}


@app.post("/clients", status_code=status.HTTP_201_CREATED)
def add_client(client: ClientCreate) -> dict[str, int | str]:
    try:
        with get_db() as connection:
            cursor = connection.execute(
                """
                INSERT INTO clients (
                    company_name,
                    contact_name,
                    phone,
                    email,
                    address
                )
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    client.company_name,
                    client.contact_name,
                    client.phone,
                    client.email or None,
                    client.address,
                ),
            )
            client_id = cursor.lastrowid
    except sqlite3.IntegrityError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A client with that email already exists.",
        ) from error

    return {"message": "Client added successfully", "client_id": client_id}


@app.get("/clients")
def get_clients() -> list[dict[str, int | str | None]]:
    with get_db() as connection:
        rows = connection.execute(
            """
            SELECT client_id, company_name, contact_name, phone, email, address
            FROM clients
            ORDER BY company_name COLLATE NOCASE
            """
        ).fetchall()

    return [
        {
            "id": row["client_id"],
            "company": row["company_name"],
            "contact": row["contact_name"],
            "phone": row["phone"],
            "email": row["email"],
            "address": row["address"],
        }
        for row in rows
    ]


@app.delete("/clients/{client_id}")
def delete_client(client_id: int) -> dict[str, str]:
    with get_db() as connection:
        cursor = connection.execute(
            "DELETE FROM clients WHERE client_id = ?",
            (client_id,),
        )

    if cursor.rowcount == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client not found.",
        )
    return {"message": "Client deleted"}
