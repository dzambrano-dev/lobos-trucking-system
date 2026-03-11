from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import sqlite3

# Create FastAPI application
app = FastAPI()

# Allow frontend apps to access the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Path to SQLite database
DB_PATH = "../database/lobos.db"


# Client data model
class Client(BaseModel):
    company_name: str
    contact_name: str
    phone: str
    email: str
    address: str


# Helper function for database connection
def get_db():
    return sqlite3.connect(DB_PATH)


# Endpoint to add a client
@app.post("/clients")
def add_client(client: Client):

    conn = get_db()
    cursor = conn.cursor()

    cursor.execute(
        """
        INSERT INTO clients (company_name, contact_name, phone, email, address)
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            client.company_name,
            client.contact_name,
            client.phone,
            client.email,
            client.address,
        ),
    )

    conn.commit()

    # Get ID of inserted record
    client_id = cursor.lastrowid

    conn.close()

    return {
        "message": "Client added successfully",
        "client_id": client_id,
    }