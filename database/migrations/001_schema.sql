-- Core schema for AdminConsole v8.
-- Add new tables in a NEW file (002_something.sql, 003_...). Never edit a migration
-- that has already been applied somewhere - it will not run again.

CREATE TABLE IF NOT EXISTS Audit (
    Id            INTEGER PRIMARY KEY AUTOINCREMENT,
    Timestamp     TEXT NOT NULL,
    Operator      TEXT COLLATE NOCASE,
    Action        TEXT,
    Target        TEXT,
    Result        TEXT,
    Details       TEXT,
    CorrelationId TEXT
);
CREATE INDEX IF NOT EXISTS IX_Audit_Timestamp ON Audit (Timestamp);

CREATE TABLE IF NOT EXISTS Roles (
    Id          INTEGER PRIMARY KEY AUTOINCREMENT,
    Name        TEXT NOT NULL UNIQUE COLLATE NOCASE,
    Description TEXT
);

CREATE TABLE IF NOT EXISTS RolePermissions (
    RoleId     INTEGER NOT NULL REFERENCES Roles (Id) ON DELETE CASCADE,
    Permission TEXT NOT NULL COLLATE NOCASE,
    PRIMARY KEY (RoleId, Permission)
);

CREATE TABLE IF NOT EXISTS UserRoles (
    Id         INTEGER PRIMARY KEY AUTOINCREMENT,
    Account    TEXT NOT NULL COLLATE NOCASE,
    RoleId     INTEGER NOT NULL REFERENCES Roles (Id) ON DELETE CASCADE,
    AssignedOn TEXT,
    AssignedBy TEXT,
    UNIQUE (Account, RoleId)
);

CREATE TABLE IF NOT EXISTS ApprovalRequests (
    Id            INTEGER PRIMARY KEY AUTOINCREMENT,
    CorrelationId TEXT UNIQUE,
    ActionName    TEXT NOT NULL,
    Target        TEXT NOT NULL,
    Details       TEXT,
    RequestedBy   TEXT NOT NULL COLLATE NOCASE,
    RequestedOn   TEXT NOT NULL,
    ExpiresOn     TEXT,
    Status        TEXT NOT NULL DEFAULT 'Pending',
    DecidedBy     TEXT,
    DecidedOn     TEXT,
    Notes         TEXT,
    ExecutedOn    TEXT
);
CREATE INDEX IF NOT EXISTS IX_Approvals_Lookup ON ApprovalRequests (ActionName, Target, Status);

CREATE TABLE IF NOT EXISTS Favorites (
    Account    TEXT NOT NULL COLLATE NOCASE,
    ReportName TEXT NOT NULL,
    CreatedOn  TEXT,
    PRIMARY KEY (Account, ReportName)
);

CREATE TABLE IF NOT EXISTS Schedules (
    Id             INTEGER PRIMARY KEY AUTOINCREMENT,
    Name           TEXT NOT NULL UNIQUE,
    ReportName     TEXT NOT NULL,
    ParametersJson TEXT,
    Frequency      TEXT NOT NULL,
    At             TEXT,
    DayOfWeek      TEXT,
    Format         TEXT NOT NULL DEFAULT 'csv',
    OutputFolder   TEXT,
    Enabled        INTEGER NOT NULL DEFAULT 1,
    LastRun        TEXT,
    NextRun        TEXT,
    LastResult     TEXT,
    CreatedBy      TEXT,
    CreatedOn      TEXT
);

CREATE TABLE IF NOT EXISTS Alerts (
    Id             INTEGER PRIMARY KEY AUTOINCREMENT,
    Name           TEXT NOT NULL UNIQUE,
    ReportName     TEXT NOT NULL,
    ParametersJson TEXT,
    MatchText      TEXT,
    MinRows        INTEGER NOT NULL DEFAULT 1,
    Severity       TEXT NOT NULL DEFAULT 'Warning',
    Enabled        INTEGER NOT NULL DEFAULT 1,
    LastRun        TEXT,
    LastMatches    INTEGER,
    LastResult     TEXT,
    CreatedBy      TEXT,
    CreatedOn      TEXT
);

CREATE TABLE IF NOT EXISTS AlertHistory (
    Id          INTEGER PRIMARY KEY AUTOINCREMENT,
    AlertId     INTEGER NOT NULL REFERENCES Alerts (Id) ON DELETE CASCADE,
    TriggeredOn TEXT NOT NULL,
    Severity    TEXT,
    MatchCount  INTEGER,
    Summary     TEXT
);

CREATE TABLE IF NOT EXISTS Notifications (
    Id        INTEGER PRIMARY KEY AUTOINCREMENT,
    Subject   TEXT NOT NULL,
    Body      TEXT,
    Severity  TEXT,
    Status    TEXT NOT NULL DEFAULT 'Queued',
    Attempts  INTEGER NOT NULL DEFAULT 0,
    CreatedOn TEXT,
    SentOn    TEXT,
    LastError TEXT
);
CREATE INDEX IF NOT EXISTS IX_Notifications_Status ON Notifications (Status);

CREATE TABLE IF NOT EXISTS HealthChecks (
    Id        INTEGER PRIMARY KEY AUTOINCREMENT,
    CheckedOn TEXT NOT NULL,
    Component TEXT,
    Status    TEXT,
    Message   TEXT
);
