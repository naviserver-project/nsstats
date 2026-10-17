# Nsstats: NaviServer Monitoring and Administration

**Release:** 1.15

Nsstats provides a web administration interface for inspecting a NaviServer
process and its virtual servers. Its pages cover utilization, connection pools
and drivers, memory and caches, database pools, locks, background work and logs.
Navigation groups related tasks and identifies whether information is global,
per server or specific to a log source.

Modules can add their own admin pages. For example, nsmcp supplies MCP tool
inspection and question answering, while nssmtpd can provide quarantine data for
inspection and manual release. These integrations are optional.

## Changes since version 1.0

### Navigation and administration

- Grouped menus, a searchable page directory and clickable breadcrumbs make
  process, server and diagnostic pages easier to reach on desktop and mobile.
- Scope labels distinguish process-wide information from server-specific data.
- Configuration parameters include descriptions from the core and installed
  module dictionaries; the configuration file can also be inspected directly.
- Direct JSON responses, downloads and redirects finish correctly under the
  OpenACS request processor. Global formatting helpers support namespaced
  OpenACS templates.

### Utilization, sampling and history

- A dedicated utilization page shows driver/socket state, connection-pool
  activity, queued/dropped requests, rates and queue/filter/run/trace timing.
- Shared core samples provide interval measurements independent of page
  refreshes. Display windows compare current counters with retained samples
  without changing the sampling cadence.
- Request-rate and CPU charts include recent memory or persistent history,
  with explicit gaps, restarts, resets, evictions and write-failure coverage.
- Persistence status, retained bounds, database usage and cleanup settings help
  assess storage budgets. Existing collectors remain available as a fallback.

### Process, memory and data inspection

- Per-server sections show pools, handlers, URL mappings, bindings and loaded
  module metadata, including versions and recognized Git build-tag links.
- Database pool diagnostics include client/database versions and local SQLite
  datasource file sizes, without reusing request-owned database handles.
- Cache statistics include access timings and reuse charts. Shared-variable
  size and lock information distinguishes scopes when supported by the core.
- Lock diagnostics include maximum/total wait and hold times; Linux thread
  diagnostics include CPU times, processor assignment and state. Values use
  human-readable units.

### Logs and background work

- System, HTTP client and SMTP log views support analysis and request-ID
  correlation; log severities can be inspected and changed.
- Scheduled procedures, running jobs, connection-channel work and nsproxy
  workers have dedicated views and links from process information.
- The SMTP sent-log page also offers quarantine inspection, message downloads
  and confirmed manual release when the installed mail module supports it.

### Module extensions

- A server-scoped registry lets modules publish reusable ADP pages, with menu
  placement, scope labels and the normal nsstats access checks.
- The MCP admin page now belongs to nsmcp, keeping tool descriptions, runtime
  switches, result inspection and question answering in sync with that package.
- Optional question interfaces support backend selection, sanitized Markdown,
  lazy evidence inspection and background-job progress with retained handles.

## Installation

1. **Enable the Module:**
   Set the `enabled` parameter to `1` in the configuration file to activate nsstats.

2. **Install the Pages:**
   Copy `nsstats.tcl` and the supplied ADP templates to the same
   administrative page directory (typically beneath
   `/usr/local/ns/pages`), or use `make install`.   

3. **Access the Module:**
   Open your web browser and navigate to the module’s URL.

**Security Notice:**

This module provides access to potentially sensitive information. Do
not deploy it on public-facing websites unless you implement
appropriate access controls. For OpenACS installations, it is
recommended to place the module file (e.g., `nsstats.tcl`) in a secure
directory such as `acs-subsite/www/admin/`, ensuring that only
authorized users can access it.

**Access Control Criteria:**

Access to the module is granted if it is enabled and at least one of
the following conditions is met:

- The module is installed within an OpenACS environment under an
  `/acs-admin/` or `/admin/` directory.
- The `nsperm` module is installed, a valid user is configured, and
  authentication is successful.
- A non-empty username is configured and is successfully authenticated
  using the password specified in the configuration file.
- The access request originates from a non-public direct peer IP address.

## Configuration

The nsstats module is configured via the NaviServer configuration
file. Below is an example configuration block:

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

- **user** (string, default: `"nsadmin"`) and **password** (string, default: `""`)
  Specify the credentials required to access the nsstats module. When
  non-empty values are provided, the module will prompt for authentication.

- **bglocks** (list, default: `""`)
  Specifies the mutex locks used by background processes. For example,
  the `oacs:sched_procs` lock in OpenACS is generally excluded from
  page request-related statistics due to its specialized role.

If these settings are not supplied in the NaviServer configuration
file, you can alternatively adjust the values at the top of the
nsstats script.

Access control for the default user can be managed using the `nsperm`
module or, for OpenACS installations, via URL path permissions.

## Core diagnostics integration

When `ns_stats` is available and sampling is running with a ready
interval, nsstats reads the shared sample. Request/driver rates,
timing averages and CPU percentages use the measured sampling interval
and remain stable across page refreshes. The utilization page
distinguishes sample freshness from the measured period and warns
about stale samples. Beside Raw, select shared sampling or a live
snapshot. The Display window field (for example `60s`) compares a
fresh snapshot with the retained endpoint nearest that age; it does
not change the sampling cadence. The actual measured period is shown
in the table. The display window uses bounded memory history, up to 15
minutes, without SQLite. Insufficient history or a gap/restart leaves
interval measurements unknown while current gauges remain
visible. Ordinary measurements have no extra status line; warnings
remain visible. When sampling is stopped or live snapshot is selected,
rates use page-observation intervals.

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
or write SQLite history. Configure those through `ns_stats`. Optional
core capabilities and compatibility fallbacks are listed under
[Requirements and compatibility](#requirements-and-compatibility).

On installations without `ns_stats`, the existing collectors remain in use,
including Linux `/proc` CPU fallback. Linux network diagnostics and queue details
not exposed by the core remain supplemental, using their own observation interval.
Changing collector backend resets the page baseline. An unavailable core CPU
measurement stays unavailable; collector errors are not silently replaced by
legacy results.

## Process, modules and database pools

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
names, module names and types, versions, build tags, scopes, and
files. Missing optional metadata leaves blank cells. Earlier
NaviServer versions retain the sorted module-name list from `ns_ictl getmodules`.

On servers with `ns_module reload`, a circular-arrow button beside each Tcl
module in the current virtual server reloads its definitions and dependent Tcl
files, then publishes the updated blueprint. It uses the normal admin access,
POST and an admin-bound token. Reload errors are reported directly. Startup-only
`init.tcl` is excluded by the core loader; module code must support repeated
evaluation. Native/mixed modules and other virtual servers have no reload button.
Older NaviServer versions retain their existing display without this control.

Recognized Git build tags for core modules and nsdbpg, nsdbsqlite, nsdns, and
nssmtpd link to commits in their GitHub repositories. Unknown modules or tags
without a commit hash remain plain text.

Servers without available database pools display `{}`. Module tables include
only database drivers used by pools available to that server; globally loaded
drivers used exclusively by other servers are omitted.

## SMTP logs and quarantine

The updated nssmtpd module supplies the SMTP sent/event pages through the
page registry, including their parsing, styles and quarantine actions. Install
both updated packages and restart to register the existing URLs. Later SMTP UI
changes deploy with nssmtpd alone. Older modules without registered pages do
not supply SMTP menu entries.

When nssmtpd provides `smtpd::quarantine`, **Logs →
SMTP sent log** page offers **Delivery log** and **Quarantine** views. No additional
menu entry is added.

Quarantine shows storage/retention settings, a paged message list, policy findings,
recipient delivery states and audit metadata. Inspection presents escaped plain-text
source (up to 64KiB), plus a complete `.eml` attachment download. Mail HTML and
attachments are never rendered in the admin page.

After inspection, tick the confirmation checkbox and select **Release pending
recipients**. This uses the normal nsstats admin access, a POST and a server/admin-bound
CSRF token. Delivered or uncertain recipients are not automatically resent.
Interrupted/uncertain outcomes remain visible; recovery and explicit retry stay in
nscp after inspecting upstream logs. Deletion and cleanup also remain nscp actions.
Quarantine pages and downloads are sent with `Cache-Control: no-store`.

Install the updated nssmtpd quarantine support first and configure its persistent
spool; nsstats does not enable quarantine or change its policy, limits or retention.

## Module-provided admin pages

Modules can publish reusable ADP pages without copying their UI into nsstats.
The server-scoped `nsstats:plugins` NSV array is the extension registry. Each
provider owns one key containing a dictionary of page IDs and descriptors:

```tcl
nsv_set nsstats:plugins mymodule [dict create mymodule.status [dict create \
    label {My module} title {My module status} group administration scope server \
    requires ::mymodule::Service adp /absolute/module/lib/status.adp]]
```

Required descriptor fields are `label`, `title`, `group`, `scope`, and `adp`.
`requires` optionally names a command that must exist in the current interpreter.
Groups are `overview`, `memory`, `background`, `logs`, and `administration`;
scopes are `global`, `server`, `mixed`, and `source`. Page IDs use lowercase
letters, digits, dots, underscores and hyphens, starting with a letter. Built-in
page IDs cannot be replaced. Providers should use a module prefix for new IDs.

Register during module startup; nsstats need not have loaded first. Each request
reads the registry for its virtual server, validates descriptors, and adds
available pages to menus, the directory and breadcrumbs. Invalid registrations,
missing/unreadable ADPs and absent required commands are omitted. Remove a
provider with `nsv_unset nsstats:plugins mymodule`. Registry entries are trusted
module configuration and must never come from browser parameters.

Requests use the normal `?@page=mymodule.status` URL and the existing nsstats
access check. Only an authorized request evaluates the registered ADP, using
`ns_adp_parse -file`. The host supplies global `::_ns_stats.header`, `::_ns_stats.footer`
and its regular table styles. A page sets its title/navigation through the
header helper and returns body HTML. An ADP that sends JSON or a download must
produce **no ADP output**, including whitespace; the host will then skip HTML
wrapping and complete the request, including in OpenACS. Mutating or inspecting
handlers remain responsible for their POST/CSRF and application permission checks.
Module lib directories need not be publicly served.

The MCP page is supplied by nsmcp as `lib/nsstats.adp` with companion
`lib/nsstats.tcl`. Its existing `?@page=mcp` URL remains
unchanged. MCP page changes deploy with nsmcp; the host registry
interface stays independent of those changes. Nsstats no longer embeds
MCP-specific code or browser libraries.

Host helper definitions and plugin calls use fully qualified global command
names. OpenACS can therefore source nsstats from a namespaced template procedure
without hiding the formatting API.

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

The MCP tools table also providesserver-wide runtime Enable/Disable
switches when supported by nsmcp. They affect discovery and invocation
for all MCP clients on the current virtual server. Disabled tools
still have readable descriptions.  Changes require a protected POST
and the admin page token, survive module reloads, and reset on process
restart. Existing jobs and collectors continue. These switches control
tool availability for the server; question answering uses the enabled
tools through nsmcp.

MCP question answers render Markdown using pinned marked and DOMPurify browser
scripts from cdnjs, with Subresource Integrity and no-referrer requests. No npm
installation or build step is required. Only the configured question panel loads
these scripts. Answers use a restricted set of HTML elements and link protocols;
raw HTML and images are disabled. If either script is unavailable or blocked by
Content Security Policy, answers remain plain text. Tool evidence remains JSON.

The MCP question settings show both Codex App Server and native Chat Completions
options. Default question backend reports the selected model, endpoint, streaming
and execution limits without reading or displaying credential file contents.

The question backend selector uses the configured adapters reported by nsmcp.
Changing provider starts a new conversation; active questions cannot be switched.
Selection is local to the administrator's browser session, and provider-specific
history remains with its originating backend. No restart is needed to select an
already configured backend.

### Lazy question evidence

With the updated nsmcp service, large question-tool results are fetched only when
expanded. Polling carries metadata and opaque evidence handles; results up to
4KiB remain inline. The same admin/CSRF protection and conversation ownership
checks apply to evidence retrieval. Expired, forgotten, quota-omitted or unavailable
evidence is reported explicitly. The MCP configuration page shows
`questionMaxBytes`, `questionMaxEvidenceBytes` and `questionEvidenceDirectory`.
The nsmcp package supplies this interface through its registered admin page.

### Background question jobs

The question panel shows background-job status, scanned bytes and the job handle
while the backend waits. Intermediate polls do not consume model tool calls.
After a timeout or cancellation, the handle stays in the conversation; ask a
follow-up to retrieve it. Background log jobs continue independently and remain
subject to their normal expiry and permissions.

If a conversation becomes unavailable, the question panel clears its stale
handle, stops polling and unlocks New conversation and backend selection. The
visible transcript and job handles remain available for inspection. Temporary
network failures continue to retry and keep cancellation available.

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

## Authors

- **Vlad Seryakov** (<vlad@crystalballinc.com>)
- **Gustaf Neumann** (<neumann@wu-wien.ac.at>)

## Requirements and compatibility

- **Base interface:** NaviServer **4.99.27 or newer**, with Tcl **8.6 or newer**.
  Install the supplied ADP templates alongside `nsstats.tcl`; the compatibility
  template supports the 4.99 series.
- **No mandatory MCP or core sampler dependency:** base nsstats does not require
  nsmcp, NSF/NX, `ns_stats` or `ns_json`. Optional pages are omitted when their
  facilities are unavailable, and existing collectors remain the fallback.
- **Core sampling and history:** require a core providing `ns_stats` and its
  own runtime prerequisites. Display windows require `ns_stats sample -window`;
  older command versions can still expose the live samples or persisted history
  they support. Persistent history requires a configured SQLite history pool.
- **Optional runtime details:** module version metadata, process-scoped shared
  variables and other newer facilities are detected through their available
  APIs. Missing support does not raise the base runtime requirement.
- **Admin extensions:** discovery uses legacy server-scoped `nsv_array get` and
  ADP parsing APIs. An absent registry is harmless. Client modules such as nsmcp
  retain their own version requirements; they do not change nsstats' minimum.
- **SMTP quarantine:** inspection and release require an installed nssmtpd that
  provides `smtpd::quarantine`, with persistent quarantine storage configured.
- **Documentation builds:** require the shared NaviServer documentation tools
  and Tcllib DocTools. Ordinary installation uses committed parameter includes
  and does not require rendering the documentation.

The optional nsmcp question page loads its pinned browser Markdown libraries
from cdnjs. No npm installation or JavaScript build step is needed for nsstats.
