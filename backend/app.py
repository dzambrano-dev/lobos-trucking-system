from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import sqlite3


# Create FastAPI application
app = FastAPI()


# Allow frontend apps (Flutter) to access the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # allow all during development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Path to SQLite database
DB_PATH = "../database/lobos.db"


# ---------------------------
# Data models
# ---------------------------

class Client(BaseModel):
    company_name: str
    contact_name: str
    phone: str
    email: str
    address: str


# ---------------------------
# Database helper
# ---------------------------

def get_db():
    return sqlite3.connect(DB_PATH)


# ---------------------------
# Health check
# ---------------------------

@app.get("/")
def root():
    return {"status": "Lobos Trucking API running"}


# ---------------------------
# CREATE CLIENT
# ---------------------------

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

    client_id = cursor.lastrowid

    conn.close()

    return {
        "message": "Client added successfully",
        "client_id": client_id,
    }


# ---------------------------
# GET ALL CLIENTS
# ---------------------------

@app.get("/clients")
def get_clients():

    conn = get_db()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT client_id, company_name, contact_name, phone, email
        FROM clients
        """
    )

    rows = cursor.fetchall()

    conn.close()

    clients = [
        {
            "id": row[0],
            "company": row[1],
            "contact": row[2],
            "phone": row[3],
            "email": row[4],
        }
        for row in rows
    ]

    return clients


# ---------------------------
# DELETE CLIENT
# ---------------------------

@app.delete("/clients/{client_id}")
def delete_client(client_id: int):

    conn = get_db()
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM clients WHERE client_id = ?",
        (client_id,),
    )

    conn.commit()
    conn.close()

    return {"message": "Client deleted"}