# Statistics Module for NaviServer 4.99.27 or Newer

**Release:** 1.15  

## Overview

**Nsstats** is a pure Tcl module that delivers comprehensive insights into the performance and activity of your NaviServer installation. It collects and displays a variety of metrics to help you monitor and optimize your server, including:

- Cache utilization
- Active configuration parameters
- Mutex lock statistics
- NSV usage and lock details
- Runtime metrics from virtual servers and connection pools
- Scheduled procedures and task performance
- Thread activity and details
- Driver usage information
- Web-accessible data:
  - The current configuration file
  - Recent error log entries

## Changes Since Version 1.0

- Separate utilization page including including driver and server/pool
  specific diagnostics
- Added per-server and per-pool process statistics
- Introduced queueing and spooling metrics
- Included queuing time and filter time measurements per pool
- Expanded cache statistics (e.g., recorded access times)
- Enabled direct access to the configuration file from the module
- Reported maximum wait time, total wait time, total lock time, and average lock time
- Mapped NSV locks from variable names to specific buckets and locks
- Enhanced thread statistics with details such as user time, system time, processor assignment, and thread state (Linux only)
- Added comprehensive log statistics and pages for displaying/toggling log levels
- Provided a page to display URLs mapped to connection thread pools
- Included additional driver information, such as thread details and performance metrics
- Formatted values in a human-readable manner
- Displayed information on running writer tasks, connection channel jobs, and nsproxy jobs
- Added database pool statistics
- Reported NSV size metrics
- Introduced cache reuse charts
- Enabled quick log file analysis (e.g., searching error.log and access.log for request IDs)
- Included HTTP client log statistics

## Installation Instructions

1. **Enable the Module:**  
   Set the `enabled` parameter to `1` in the configuration file to activate nsstats.

2. **Place the Module File:**  
   Copy the module file to a directory within your NaviServer pages directory (typically `/usr/local/ns/pages`).

3. **Access the Module:**  
   Open your web browser and navigate to the module’s URL.

**Security Notice:**

This module provides access to potentially sensitive information. Do not deploy it on public-facing websites unless you implement appropriate access controls. For OpenACS installations, it is recommended to place the module file (e.g., `nsstats.tcl`) in a secure directory such as `acs-subsite/www/admin/`, ensuring that only authorized users can access it.

**Access Control Criteria:**

Access to the module is granted if it is enabled and at least one of the following conditions is met:

- The module is installed within an OpenACS environment under an `/acs-admin/` or `/admin/` directory.
- The `nsperm` module is installed, a valid user is configured, and authentication is successful.
- A non-empty username is configured and is successfully authenticated using the password specified in the configuration file.
- The access request originates from a non-public, routable IP address.

## Configuration

The nsstats module is configured via the NaviServer configuration file. Below is an example configuration block:

```tcl
ns_section "ns/module/nsstats" {
   ns_param enabled  1
   ns_param user     "nsadmin"
   ns_param password ""
   ns_param bglocks  {oacs:sched_procs}
}
```

### Configuration Variables

- **enabled** (boolean, default: `1`)  
  Enables or disables the nsstats module.

- **user** (string, default: `""`) and **password** (string, default: `""`)  
  Specify the credentials required to access the nsstats module. When non-empty values are provided, the module will prompt for authentication.

- **bglocks** (list, default: `""`)  
  Specifies the mutex locks used by background processes. For example, the `oacs:sched_procs` lock in OpenACS is generally excluded from page request-related statistics due to its specialized role.

If these settings are not supplied in the NaviServer configuration file, you can alternatively adjust the values at the top of the nsstats script.

Access control for the default user can be managed using the `nsperm` module or, for OpenACS installations, via URL path permissions.

## Authors

- **Vlad Seryakov** (<vlad@crystalballinc.com>)
- **Gustaf Neumann** (<neumann@wu-wien.ac.at>)

## Database versions

The main Process page shows client and database versions beside each pool's
statistics when the driver implements `ns_db info` version reporting. SQLite
versions are shown as dotted release numbers; PostgreSQL 10 and later use
`major.minor`. Other encodings are shown numerically.

Collection briefly borrows a handle with a 1 ms pool wait timeout and releases
it even if version lookup fails. Busy or inaccessible pools and drivers without
version support show `Versions: unavailable`; their statistics remain visible.
This timeout bounds waiting for a free handle, not connecting to a database or
executing a driver's version query.

When the rendering request already owns a pool handle (as OpenACS commonly
owns a pool1 handle), version collection runs in a separate NaviServer thread
and borrows its own connection. It does not query, release, or reset the
request-owned handle. The 1 ms pool wait and unavailable fallback still apply.

Unavailable version lookups include an HTML-escaped diagnostic distinguishing
pool wait timeouts, connection/lookup failures, and missing driver support.
For SQLite open failures, the server log records the actual datasource path and
SQLite error. Relative datasources require the `<home>/data/sqlite` directory
(and any subdirectories) to exist and be writable by the NaviServer account.

Each virtual server section has an `Available DB-Pools` row. For the current
server it uses runtime access from `ns_db pools`; for other servers it resolves
the first configured `pools` value, expanding `*` or filtering comma-separated
names against known global pools, following NaviServer's initialization rules.
The `DB-Pools` statistics table remains global. This helps diagnose duplicate or
incorrect server `pools` entries independently of OpenACS `pools_main` mappings.

For each virtual server, `Loaded Modules` displays a metadata table from
`ns_server -server <server> modules` when supported. It includes registration
names, module names and types, versions, build tags, scopes, and files. Missing optional metadata leaves blank cells. Earlier
NaviServer versions retain the sorted module-name list from `ns_ictl getmodules`.

Recognized Git build tags for core modules and nsdbpg, nsdbsqlite, nsdns, and
nssmtpd link to commits in their GitHub repositories. Unknown modules or tags
without a commit hash remain plain text.

Servers without available database pools display `{}`. Module tables include
only database drivers used by pools available to that server; globally loaded
drivers used exclusively by other servers are omitted.
