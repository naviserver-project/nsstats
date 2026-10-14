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

## Core diagnostics integration

When `ns_stats` is available and sampling is running with a ready interval,
nsstats reads the shared sample. Request/driver rates, timing averages and CPU
percentages use the measured sampling interval and remain stable across page
refreshes. The utilization page distinguishes sample freshness from the measured
period and warns about stale samples. Beside Raw, select shared sampling or a
live snapshot. The Display window field (for example `60s`) compares a fresh snapshot with the retained endpoint nearest that age; it does not change the sampling cadence. The
actual measured period is shown in the table. This requires the updated core
`ns_stats sample -window` support and uses bounded memory history, up to 15
minutes, without SQLite. Insufficient history or a gap/restart leaves interval
measurements unknown while current gauges remain visible. Ordinary measurements have no extra status
line; warnings remain visible. When sampling is
stopped or live snapshot is selected, rates use page-observation intervals.

The utilization page also shows recent request-rate and measured CPU charts,
the latest 20 intervals (including queue/filter/run/trace averages), and coverage.
Without persistence it uses the core's bounded memory buffer (180 samples,
at most 15 minutes at publication). With configured SQLite history it follows
all pages up to 10,000 samples and includes retained records from earlier
process instances. Choose 15 minutes, one hour, six hours or 24 hours.
Chart lines break across gaps/restarts; absent/reset measurements remain unknown.
Coverage includes retained bounds, baseline/reset records, gaps, restarts,
eviction/failure overlap, paging limits and persistence write failures.
Persistent history is queried from its configured owner virtual server.

Viewing nsstats does not start sampling, change its baseline, enable persistence
or write SQLite history. Configure those through `ns_stats`. The new memory
history command requires the updated core `ns_stats.tcl`; older command versions
can still show persisted history and live samples.

On installations without `ns_stats`, the existing collectors remain in use,
including Linux `/proc` CPU fallback. Linux network diagnostics and queue details
not exposed by the core remain supplemental, using their own observation interval.
Changing collector backend resets the page baseline. An unavailable core CPU
measurement stays unavailable; collector errors are not silently replaced by
legacy results.

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

### MCP tool inspection

When nsmcp is active, Administration → MCP lists its tools and configuration.
Each tool's Details dialog offers **Inspect result** when the MCP protocol is
initialized. Edit its JSON arguments and click Run to view the JSON-RPC response,
including errors, coverage and redacted output. Page loading does not execute tools.

Inspection uses the existing nsstats admin access and the current virtual server.
It passes calls through nsmcp's protocol validation and authorization with an admin
identity, including peer-read permission. No bearer token is required or exposed.
Job, result and window handles belong to that admin identity; handles issued to a
bearer-token client cannot be reused here. Follow-up buttons poll jobs, read result
pages and follow history paging. Each call requires an explicit click.

Responses are shown in a scrollable panel and can be copied or downloaded as JSON.
Tool limits and paging still apply; a displayed page is not necessarily the complete
result. Reset arguments returns to the original tool without executing a call.

## Parameter documentation

This repository owns `doc/tcl/config-parameters.tcl`; its committed generated
reference is `doc/src/include/parameters.man`. The complete module manual is
`doc/src/nsstats.man`. With the updated NaviServer development tools:

```sh
make regen-config-parameters-includes
make check-doc
make build-doc
```

HTML is written to `doc/html`, nroff to `doc/man`. Ordinary builds and installation
use the committed fragment without running the documentation generator.
`DOC_TOOLS=/path/to/naviserver/doc/tools` selects source-checkout tools.
For combined documentation, run NaviServer's `make build-doc` with
`EXTERNAL_MODULE_DOCS` listing the selected local module repository directories.

The configuration page loads the core dictionary and installed module dictionaries
from the shared/private Tcl library locations. Missing optional dictionaries are
ignored; malformed dictionaries are reported without breaking the page.

The MCP tools table also provides server-wide runtime Enable/Disable switches
when supported by nsmcp. They affect discovery and invocation for all MCP clients
on the current virtual server. Disabled tools still have readable descriptions.
Changes require a protected POST and the admin page token, survive module reloads,
and reset on process restart. Existing jobs and collectors continue. These are
server availability controls; a conversational assistant has not yet been added.
