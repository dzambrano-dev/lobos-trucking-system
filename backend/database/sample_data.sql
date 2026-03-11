-- Sample data
-- Fictional data for demonstration purposes only


-- Insert clients
INSERT INTO clients (id, company_name, contact_name, phone, email, address) VALUES
(1, 'Client Alpha', 'John Doe', '1-800-0101', 'alpha@example.com', 'Los Angeles'),
(2, 'Client Beta', 'Maria Ruiz', '1-800-0111', 'beta@example.com', 'Long Beach'),
(3, 'Client Delta', 'Chris Stone', '1-800-1000', 'delta@example.com', 'San Diego');


-- Insert jobs
INSERT INTO jobs (id, client_id, job_date, description, status) VALUES
(1, 1, '2024-05-06', 'Local freight delivery', 'completed'),
(2, 1, '2025-04-12', 'Flatbed transport', 'completed'),
(3, 2, '2025-10-09', 'Warehouse cargo transport', 'pending'),
(4, 3, '2025-10-20', 'Long distance delivery', 'cancelled');

FOREIGN KEY (client_id) REFERENCES clients(id)


-- Insert invoices
INSERT INTO invoices (id, job_id, amount, issued_date, paid) VALUES
(1, 1, 1200.00, '2024-05-07', 1),
(2, 2, 850.00, '2025-04-13', 0);