--sample data
--- Fictional data for demonstration purposes only

-- insert clients
INSERT INTO clients (name, contact_email, phone) VALUES
('Client Alpha', 'alpha@example.com', '1-800-0101'),
('Client Beta', 'beta@example.com', '1-800-0111'),
('Client Delta', 'delta@example.com', '1-800-1000');

--insert jobs
INSERT INTO jobs (client_id, job_date, description, status) VALUES
(1, '2024-05-06', 'Local freight delivery', 'completed'),
(1, '2025-04-12', 'Flatbed transport', 'completed'),
(2, '2025-10-09', 'Warehouse cargo transport', 'pending'),
(3, '2025-10-20', 'Long distance delivery', 'cancelled');

--insert invoices
INSERT INTO invoices (job_id, amount, issued_date, paid) VALUES
(1,1200.00,'2024-05-07', 1),
(2,850.00,'2025-04-13', 0);
