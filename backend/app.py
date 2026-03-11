import sqlite3
from pathlib import Path

#The database file we will read and write from
DB_FILE = "lobos.db"

def get_connection():
  #This function opens a connection to the database, every time we wish to connect
  conn = sqlite3.connect(DB_FILE)

  #SQLite does not enforce foreign keys so we apply PRAGMA
  conn.execute("PRAGMA foreign_keys = ON;")

  # return the called function
  return conn

def initialize_database():
  #this function checks if the database already exists,if not we create and load schema and sample data

  if not Path(DB_FILE).exists():
    print("Database not found. Creating new database...")

    # open a new connection
    conn = get_connection()

    #read sample_data.sql, and insert demo records
    with open("schema.sql", "r") as f:
        conn.executescript(f.read())
    #insert sample data
    with open ("sample_data.sql", "r") as f:
        conn.executescript(f.read())

    #close the connection when finished
    conn.close()
    print("Database created and populated.\n")

# Client functions
def add_client(name, email, phone):
  # function inserts a new client into the clinets table

  conn = get_connection()
  cursor = conn.cursor()

  #this placeholder prevents SQL injection
  #the values are safely inserted by SQLite
  cursor.execute(
    "INSERT INTO clients (name,contact_email, phone) VALUES (?, ?, ?)",
    (name, email, phone)
  )

  #save the changes to database
  conn.commit()
  conn.close()
  
  print("Client added.\n")

def list_clients():
  #This function retrives and prints all clients

  conn = get_connection()
  cursor = conn.cursor()

  #ask SQLite for all client IDs , names, and emails
  cursor.execute("SELECT client_id, name, contact_email FROM clients")

  #fetch all rows returned by the query
  clients = cursor.fetchall()

  conn.close()

  print("\nClients:")
  for client in clients:
    print(client)
  print()

#invoice functions
def list_unpaid_invoices():
    #this function will show invoices that have not been yet paid.
    #it will join three tabels so we can see client with invoices

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT invoices.invoice_id,
               clients.name,
               invoices.amount
        FROM invoices
        JOIN jobs ON invoices.job_id = jobs.job_id
        JOIN clients ON jobs.client_id = clients.client_id
        WHERE invoices.paid = 0
    """)

    invoices = cursor.fetchall()
    conn.close()

    print("\nUnpaid Invoices:")
    for invoice in invoices:
        print(invoice)
    print()

def mark_invoice_paid(invoice_id):
    #this function updates an invoice as paid

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "UPDATE invoices SET paid = 1 WHERE invoice_id =?",
        (invoice_id,)
    )

    conn.commit()
    conn.close()

    print("Invoice marked as paid.\n")

# Menu and Program loop
def main_menu():
    #this prints menu options
    print("Lobos Trucking Database")
    print("1. List clients")
    print("2. Add client")
    print("3. List unpaid invoices")
    print("4. Mark invoice as paid")
    print("5. Exit")

#program starts running here
def main():

    #make sure database exits first
    initialize_database()

    #loop forever until user exits
    while True:
        main_menu()

        #get the user's menu choice
        choice = input("Select an option: ").strip()

        if choice == "1":
            list_clients()
        elif choice == "2":
            name = input("Client name: ")
            email = input("Email: ")
            phone = input("Phone: ")
            add_client(name, email, phone)
        elif choice == "3":
            list_unpaid_invoices()
        elif choice == "4":
            invoice_id = input("Invoice ID: ")
            mark_invoice_paid(invoice_id)
        elif choice == "5":
            print("Exiting Program...")
            break
        else:
            print("Invalid option.\n")

#only run main() if this file is executed directly"
if __name__ == "__main__":
    main()
