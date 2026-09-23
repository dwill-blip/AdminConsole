CREATE TABLE IF NOT EXISTS SystemHealth(Id INTEGER PRIMARY KEY AUTOINCREMENT,CheckedOn TEXT,Component TEXT,Status TEXT,Message TEXT,DurationMs INTEGER);
CREATE INDEX IF NOT EXISTS IX_SystemHealth_Component ON SystemHealth(Component,CheckedOn);
