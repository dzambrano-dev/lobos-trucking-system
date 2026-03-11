PRAGMA foreign_keys = ON;

-- Clients table
CREATE TABLE clients (
  client_id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_name TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  phone TEXT,
  email TEXT UNIQUE,
  address TEXT

  created_at TEXT DEFAULT CURRENT_TIMESTAMP
  updated_at TEXT
);


-- Jobs table
CREATE TABLE jobs(
  job_id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL,
  job_date TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK (status IN ('pending','completed','cancelled')) 
        NOT NULL DEFAULT 'pending',

  created_at TEXT DEFAULT CURRENT_TIMESTAMP
  updated_at TEXT

  FOREIGN KEY (client_id)
    REFERENCES clients(client_id)
    ON DELETE CASCADE
);


-- Invoices table
CREATE TABLE invoices(
  invoice_id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL UNIQUE,
  amount REAL NOT NULL CHECK (amount >= 0),
  issued_date TEXT NOT NULL,
  paid INTEGER NOT NULL DEFAULT 0 CHECK (paid IN (0,1)),

  created_at TEXT DEFAULT CURRENT_TIMESTAMP
  updated_at TEXT

  FOREIGN KEY (job_id)
    REFERENCES jobs(job_id)
    ON DELETE CASCADE
);