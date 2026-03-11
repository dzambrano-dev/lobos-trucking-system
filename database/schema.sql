--Schema of the tables needed, minimalistic but nessessary.

PRAGMA foreign_keys = ON;

-- Clients: we implement unique ID, Basic contact info, and prevent duplicates
CREATE TABLE clients (
  client_id INTEGER PRIMARY KEY AUTOINCREMENT, --no ID collisions
  name TEXT NOT NULL, -- no unnamed clients
  contact_email TEXT UNIQUE, --basic intergrity
  phone TEXT
  );

-- Jobs: Enforce relationship to clients, track job statues, store description safely
CREATE TABLE jobs(
  job_id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL,
  job_date TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK (status IN ('pending', 'completed', 'cancelled')) NOT NULL DEFAULT 'pending', --CHECK will prevent garbage status values

FOREIGN KEY (client_id) -- relational thinking
  REFERENCES clients(client_id) 
  ON DELETE CASCADE --cleanup safely
  );

CREATE TABLE invoices(
  invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL UNIQUE, --one invoice per job
  amount REAL NOT NULL CHECK (amount >= 0),
  issued_data TEXT NOT NULL,
  paid INTEGER NOT NULL DEFAULT 0 CHECK (paid IN(0,1)), --BOOLEAN SAFETY

  FOREIGN KEY (job_id)
    REFERENCES jobs(job_id)
    ON DELETE CASCADE
  );
  
