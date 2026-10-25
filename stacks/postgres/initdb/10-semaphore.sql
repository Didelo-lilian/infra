-- Runs once, as the superuser over the local socket, when the data directory is empty. The role has no password here:
-- Ansible sets it on every run (ADR 0021), and until it does the role cannot log in over the network.
CREATE ROLE semaphore LOGIN CONNECTION LIMIT 30;
CREATE DATABASE semaphore OWNER semaphore;
REVOKE ALL ON DATABASE semaphore FROM PUBLIC;
-- Nothing else needs the maintenance databases: PUBLIC may connect to them by default.
REVOKE CONNECT ON DATABASE postgres, template1 FROM PUBLIC;
