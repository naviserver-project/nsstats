#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#

#
# nsstats.tcl --
#
#   Simple web-based interface for NaviServer runtime statistics.
#   The whole application is implemented as a single file.
#
#   To use it, set enabled to 1 and place this file somewhere under
#   NaviServer pageroot which is usually /usr/local/ns/pages and point
#   browser to it.
#

# If this page needs to be restricted assign username and password in
# the config file in the section "ns/module/nsstats" or here locally
# in this file.
#
set user     [ns_config ns/module/nsstats user "nsadmin"]
set password [ns_config ns/module/nsstats password ""]
set enabled  [ns_config ns/module/nsstats enabled 1]
set debug    0

set ::templateFile nsstats

if { ![nsv_exists _ns_stats threads_0] } {
    nsv_set _ns_stats thread_0      "OK"
    nsv_set _ns_stats thread_-1     "ERROR"
    nsv_set _ns_stats thread_-2     "TIMEOUT"
    nsv_set _ns_stats thread_200    "MAXTLS"
    nsv_set _ns_stats thread_1      "DETACHED"
    nsv_set _ns_stats thread_2      "JOINED"
    nsv_set _ns_stats thread_4      "EXITED"
    nsv_set _ns_stats thread_32     "NAMESIZE"

    nsv_set _ns_stats sched_1       "thread"
    nsv_set _ns_stats sched_2       "once"
    nsv_set _ns_stats sched_4       "daily"
    nsv_set _ns_stats sched_8       "weekly"
    nsv_set _ns_stats sched_16      "paused"
    nsv_set _ns_stats sched_32      "running"

    nsv_set _ns_stats sched_thread  1
    nsv_set _ns_stats sched_once    2
    nsv_set _ns_stats sched_daily   4
    nsv_set _ns_stats sched_weekly  8
    nsv_set _ns_stats sched_paused  16
    nsv_set _ns_stats sched_running 32
}
set severity [expr {$debug ? "notice" : "debug"}]

# One hierarchy shared by the menus, directory and breadcrumbs. Existing page
# identifiers remain unchanged; optional pages are omitted when unavailable.
set ::navGroups {
    overview {Overview {
        process {Process and servers} utilization Utilization threads Threads
        list-lsof {Open files}
    }}
    memory {{Memory & storage} {
        mem.tcl {Allocator memory} dbpools {Database pools}
        mem.cache Caches mem.nsvsize {Shared variables} mem.adp ADP
    }}
    background {Background {
        background.jobs Jobs background.sched {Scheduled procedures}
        proxy-workers {Proxy workers}
    }}
    logs {Logs {
        log.logfile {System log} log.httpclient {HTTP client log}
        log.smtpsent {SMTP sent log} log.smtpevents {SMTP events}
        log.levels {Log severities}
    }}
    administration {Administration {
        config.file {Configuration file} config.params {Configuration parameters}
        locks.mutex {Mutex and RW-locks} locks.nsv {NSV locks} mcp MCP
    }}
}
set ::navScopes {
    process global utilization global threads global list-lsof global
    mem.tcl global dbpools global mem.cache server mem.nsvsize server mem.adp server
    background.jobs global background.sched global proxy-workers global
    config.file global config.params global locks.mutex server locks.nsv server mcp server
    log.logfile global log.httpclient source log.smtpsent source log.smtpevents source
    log.levels global
}

proc _ns_stats.navigation.scope {page} {
    if {$page eq "mem.nsvsize" && ![catch {nsv_array scope _ns_stats}]} {
        return mixed
    }
    return [dict get $::navScopes $page]
}

proc _ns_stats.navigation.scopeLabel {scope} {
    return [dict get {global Global server {Current server} mixed {Both scopes} source {Log source}} $scope]
}

# Preserve label lookup for templates that consume navLinks.
set ::navLinks {}
dict for {group definition} $::navGroups {
    lassign $definition label entries
    foreach {page title} $entries {
        dict set ::navLinks [lindex [split $page #] 0] $title
    }
}

proc _ns_stats.navigation.groups {} {
    set result {}
    dict for {group definition} $::navGroups {
        lassign $definition label entries
        set available {}
        foreach {target title} $entries {
            set page [lindex [split $target #] 0]
            if {[info procs _ns_stats.$page] eq ""} {
                continue
            }
            if {$page eq "mcp" && [info commands ::nsmcp::ToolRegistry] eq ""} {
                continue
            }
            if {$page eq "utilization" && [info commands ns_json] eq ""} {
                continue
            }
            if {$page eq "dbpools" && [info commands ns_db] eq ""} {
                continue
            }
            if {$page eq "proxy-workers" && [info commands ns_proxy] eq ""} {
                continue
            }
            lappend available $target $title
        }
        if {$available ne ""} {
            dict set result $group [list $label $available]
        }
    }
    return $result
}

proc _ns_stats.navigation.url {target} {
    lassign [split $target #] page anchor
    set url "?@page=$page$::rawparam"
    if {$anchor ne ""} {
        append url #$anchor
    }
    return [ns_quotehtml $url]
}

proc _ns_stats.navigation {} {
    set groups ""
    dict for {group definition} [_ns_stats.navigation.groups] {
        lassign $definition label entries
        append groups "<details class='ns-nav-group'><summary>[ns_quotehtml $label]</summary><div class='ns-nav-items'>"
        foreach {target title} $entries {
            set current ""
            if {$target eq $::page} {
                set current " aria-current='page'"
            }
            set scope [_ns_stats.navigation.scope $target]
            append groups "<a href='[_ns_stats.navigation.url $target]'$current><span>[ns_quotehtml $title]</span><span class='ns-scope'>[_ns_stats.navigation.scopeLabel $scope]</span></a>"
        }
        append groups "</div></details>"
    }
    # Named details form exclusive groups: opening a menu closes its sibling.
    # Keep desktop and mobile groups separate so hidden copies do not interfere.
    set desktop [string map {"class='ns-nav-group'" "class='ns-nav-group' name='nsstats-desktop'"} $groups]
    set mobile [string map {"class='ns-nav-group'" "class='ns-nav-group' name='nsstats-mobile'"} $groups]
    set html "<nav class='ns-navigation' aria-label='Statistics navigation'><div class='ns-nav-desktop'>$desktop</div><details class='ns-nav-mobile'><summary>Menu</summary><div>$mobile</div></details></nav>"
    append html "<div class='ns-server-context'>Current server: <strong>[ns_quotehtml [ns_info server]]</strong></div>"
    append html {<script>
(function () {
  document.addEventListener('click', function (event) {
    if (event.target.closest('.ns-navigation')) return;
    document.querySelectorAll('.ns-navigation details[open]').forEach(function (menu) {
      menu.open = false;
    });
  });
  document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    const focused = document.activeElement.closest('.ns-navigation details[open]');
    document.querySelectorAll('.ns-navigation details[open]').forEach(function (menu) {
      menu.open = false;
    });
    if (focused) focused.querySelector('summary').focus();
  });
})();
</script>}
    return $html
}

proc _ns_stats.navigation.breadcrumb {} {
    if {$::page eq "index"} {
        return "<span aria-current='page'>Main menu</span>"
    }
    set title [expr {[dict exists $::titles $::page] ? [dict get $::titles $::page] : "Main menu"}]
    set label ""
    set destination index
    dict for {group definition} [_ns_stats.navigation.groups] {
        lassign $definition groupLabel entries
        if {$::page in $entries} {
            set label $groupLabel
            set destination index#nav-$group
            break
        }
    }
    if {$::page in {mapped requestprocs url2file}} {
        set label Process
        set destination process
    }
    set html "<a href='[_ns_stats.navigation.url index]'>Main menu</a>"
    if {$label ne ""} {
        append html " &gt; <a href='[_ns_stats.navigation.url $destination]'>[ns_quotehtml $label]</a>"
    }
    append html " &gt; <span aria-current='page'>[ns_quotehtml $title]</span>"
    return $html
}

proc _ns_stats.navigation.style {} {
    return {<style>
.ns-navigation {background:var(--color-menubar-bg,#00376f);color:#fff;padding:0 12px;position:relative;z-index:20;font:14px Arial,sans-serif;}
.ns-nav-desktop {display:flex;flex-wrap:wrap;gap:4px;}
.ns-nav-group {position:relative;}
.ns-navigation summary {cursor:pointer;padding:14px 12px;min-height:20px;}
.ns-navigation summary:focus-visible,.ns-navigation a:focus-visible {outline:2px solid #ffcc00;outline-offset:-2px;}
.ns-nav-items {position:absolute;min-width:220px;background:var(--color-dropdown-content-bg,#fff);border:1px solid var(--color-border,#ccc);box-shadow:0 4px 12px #0003;}
.ns-nav-items a {display:flex;justify-content:space-between;align-items:center;gap:16px;padding:12px;color:var(--color-anchor,#004080);text-decoration:none;}
.ns-nav-items a:hover,.ns-nav-items a[aria-current] {background:var(--color-dropdown-hover-bg,#e6eef7);}
.ns-nav-mobile {display:none;}
.mcp-tools th:nth-child(1),.mcp-tools td:nth-child(1) {width:18%;}
.mcp-tools th:nth-child(2),.mcp-tools td:nth-child(2) {width:10%;}
.mcp-tools th:nth-child(3),.mcp-tools td:nth-child(3) {width:38%;}
.mcp-tools th:nth-child(4),.mcp-tools td:nth-child(4) {width:26%;}
.mcp-tools th:nth-child(5),.mcp-tools td:nth-child(5) {width:8%;}
.ns-mcp-dialog {width:min(1000px,calc(100vw - 48px));max-height:85vh;overflow:auto;box-sizing:border-box;padding:24px;border:1px solid var(--color-border,#ccc);border-radius:6px;background:var(--color-body-bg,#fff);color:var(--color-body-text,#000);}
.ns-mcp-dialog::backdrop {background:#0007;}
.ns-mcp-close {float:right;padding:6px 12px;}
.ns-mcp-dialog pre {white-space:pre-wrap;overflow-wrap:anywhere;}
.mcp-result {max-height:50vh;overflow:auto;padding:12px;border:1px solid var(--color-border,#ccc);}
.mcp-followups button {margin:4px 8px 4px 0;}
.ns-mcp-dialog .data-table {table-layout:auto;}
.ns-mcp-dialog .data-table th:first-child,.ns-mcp-dialog .data-table td:first-child {width:auto;}
.ns-scope {font-size:11px;white-space:nowrap;opacity:.75;}
.ns-server-context {padding:8px 15px;font-size:13px;background:var(--color-secondary-bg,#f1f1f1);color:var(--color-body-text,#000);}
.ns-directory li a {display:flex;justify-content:space-between;gap:12px;}
.ns-directory-filter {display:block;margin-bottom:16px;}
.ns-directory-filter select {padding:8px;font:inherit;}
.ns-directory {display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:20px;}
.ns-directory section {border:1px solid var(--color-border,#ccc);padding:16px;border-radius:4px;}
.ns-directory li {margin:12px 0;}
.ns-directory-search {display:block;margin:0 0 20px;}
.ns-directory-search input {display:block;box-sizing:border-box;width:100%;max-width:480px;padding:10px;margin-top:6px;font:inherit;}
@media(max-width:800px) {
 .ns-nav-desktop {display:none;}
 .ns-nav-mobile {display:block;}
 .ns-nav-items {position:static;box-shadow:none;min-width:0;}
 .ns-nav-group {border-top:1px solid #ffffff40;}
 .ns-navigation summary {padding:14px 8px;}
 .ns-directory {grid-template-columns:1fr;}
}
</style>}
}

set ::titles {
    index             "Main menu"
    dbpools           "Database pools"
    background.jobs   "Jobs"
    background.sched  "Scheduled Procedures"
    config.file       "Configuration File"
    config.params     "Configuration Parameters"
    list-lsof         "Open Files"
    locks.mutex       "Memory Lock Statistics (Mutex and RW-Locks)"
    locks.nsv         "Shared Variable Lock Statistics (nsv)"
    log.httpclient    "HTTP Client Logfile Analysis"
    log.levels        "Log Severities"
    log.logfile       "System Logfile"
    log.smtpsent      "SMTP Sent Logfile Analysis"
    log.smtpevents    "SMTP Event Logfile Analysis"
    mapped            "Connection Pool Mappings"
    mem.adp           "ADP"
    mem.cache         "Cache Statistics (ns_cache)"
    mem.nsvsize       "Shared Variable Statistics (nsv)"
    mem.tcl           "Allocated Memory"
    mcp               "MCP configuration and tools"
    process           "Process Information"
    proxy-workers     "nsproxy Workers"
    requestprocs      "Request Handlers"
    threads           "Running Threads"
    utilization       "Utilization"
    url2file          "Url2File Mappings"
}

#
# Version compatibility proc
#
catch {ns_config} errorMsg
if {[lsearch $errorMsg ?-all?]} {
    proc ns_config_get_all {section key} {ns_config -all $section $key}
} {
    # Older versions of NaviServer don't support the "-all" flag,
    # continue to return just the first value as before
    proc ns_config_get_all {section key} {ns_config $section $key}
}

proc _ns_stats.header {args} {
    if {[llength $args] == 1} {
        set ::title "NaviServer Stats: [ns_info hostname] - [lindex $args 0]"
        set ::nav "<a href='?@page=index$::rawparam'>Main Menu</a> &gt; <span class='current'>[lindex $args 0]</span>"
        set ::current_page [lindex $args 0]
    } elseif {[llength $args] == 2} {
        set node [lindex $args 0]
        if {[llength $node] > 1} {
            lassign $node node link
            set menu_entry "<a href='$link'>$node</a>"
        } else {
            set menu_entry $node
        }
        set ::current_page [lindex $args 1]
        set ::title "NaviServer Stats: [ns_info hostname] - $node - [lindex $args 1]"
        set ::nav "<a href='?@page=index$::rawparam'>Main Menu</a> &gt; $menu_entry &gt; <span class='current'>[lindex $args 1]</span>"
    } else {
        set ::title "NaviServer Stats: [ns_info hostname]"
        set ::nav "<span class='current'>Main Menu</span>"
    }
    set ::rawLabel [expr {$::raw ? "true" : "false"}]
    set s [ns_getform]
    ns_set update $s raw [expr {!$::raw}]
    set ::rawUrl [ns_conn url]?[join [lmap {k v} [ns_set array $s] {set _ [ns_urlencode $k]=[ns_urlencode $v]}] &]
    if {![info exists ::extraHeadEntries]} {
        set ::extraHeadEntries ""
    }
    return ""
}
set ::fallbackTemplate {
<!DOCTYPE html>
<html>
<head>
<title><%= $::title %></title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style type='text/css'>
/* tooltip styling. by default the element to be styled is .tooltip  */
.tip {
   cursor: help;
   text-decoration:underline;
   color: #777777;
}
body { font-family: verdana,arial,helvetica,sans-serif; font-size: 8pt; color: #000000; background-color: #ffffff;}
td,th   { font-family: verdana,arial,helvetica,sans-serif; font-size: 8pt; padding: 4px;}
pre     { font-family: courier new, courier; font-size: 10pt; }
form    { font-family: verdana,helvetica,arial,sans-serif; font-size: 10pt; }
i       { font-style: italic; }
b       { font-style: bold; }
hl      { font-family: verdana,arial,helvetica,sans-serif; font-style: bold; font-size: 12pt; }
small   { font-size: smaller; }

table {background-color: #cccccc; padding:0px; border-spacing: 1px;}
td td.subtitle {
   text-align: right; white-space: nowrap; font-style: italic; font-size: 7pt; background-color: #f5f5f5;
}
td.coltitle {text-align: right; background-color: #eaeaea;}
td.colsection {font-size: 12pt; font-style: bold;}
td.colsection h3 {margin-top:2px;margin-bottom:2px;}
td.colsection h4 {margin-top:2px;;margin-bottom:2px;}
td.colvalue {background-color: #ffffff;}
td.defaulted {color: #aaa;}
td.unread {color: red;}
td.notneeded {color: orange;}

tr.sortable td.selected   { background: #666666; color: #ffffff; }
tr.sortable td.unselected { background: #999999; color: #ffffff; }
tr.data td.selected       { background: #ececec; }
tr.data td.unselected     { background: #ffffff; }

.tooltip {
  position: relative;
  /*display: inline-block;*/
  /*border-bottom: 1px dotted black;*/ /* If you want dots under the hoverable text */
}

.tooltip .tooltiptext {
   visibility: hidden;
   width: 200px;
   background-color: #999;
   color: #fff;
   text-align: center;
   padding: 5px 0;
   margin-left: 15px;
   margin-top: -5px;
   border-radius: 6px;
   position: absolute;
   z-index: 1;
}
.tooltip.unread .tooltiptext { background-color: #900;}
.tooltip.unread .tooltiptext::after {border-color: transparent #900 transparent transparent;}
.tooltip.defaulted .tooltiptext { background-color: #aaa;}
.tooltip.defaulted .tooltiptext::after { border-color: transparent #aaa transparent transparent;}
.tooltip.notneeded .tooltiptext { background-color: orange;}
.tooltip.notneeded .tooltiptext::after { border-color: transparent orange transparent transparent;}

.tooltip:hover .tooltiptext {visibility: visible;}
.tooltip .tooltiptext::after {
   content: " ";
   position: absolute;
   top: 50%;
   right: 100%; /* To the left of the tooltip */
   margin-top: -5px;
   border-width: 5px;
   border-style: solid;
   border-color: transparent #999 transparent transparent;
}

table.navbar {border: 1px; padding: 2px; border-spacing: 0px; width: 100%;}
table.navbar td {padding: 5px; background: #666699; color: #ffffff; font-size: 10px;}
table.navbar td .current {color: #ffcc00;}
table.navbar td a {color: #ffffff; text-decoration: none;}

table.data {padding: 0px; border-spacing: 1px}
table.data td.coltitle {width: 110px; text-align: right; background-color: #eaeaea;}
table.data td td.subtitle {text-align: right; white-space: nowrap; font-style: italic; font-size: 7pt; background-color: #f5f5f5;}
table.data th {background-color: #999999; color: #ffffff; font-weight: normal; text-align: left;}
table.data td {background-color: #ffffff; padding: 4px;}
table.data td table {background-color: #ffffff; border-spacing: 0px;}
table.data td table td {padding: 2px;}

table.requestprocs td.Arg { white-space: pre; font-size: 6pt; }
div.methodfilter .w3-check { width: 12px; height: 12px; top: 2px; }
div.methodfilter label { margin-right: 6px; }
</style>
<%= $::extraHeadEntries %>
<%= [_ns_stats.navigation.style] %>
</head>

<body>
<%= [_ns_stats.navigation] %>
  <table class='navbar table table-responsive w-100 d-block d-md-table'>
    <tr>
      <td valign='middle'><b><%= [_ns_stats.navigation.breadcrumb] %></b></td>
      <td valign='middle' align='right'>Raw: <a class='current' href='<%= $::rawUrl %>'><%= $::rawLabel %></a>
       &middot; <b><%= [_ns_stats.fmtTime [ns_time]] %></b></td>
    </tr>
  </table>
  <br>

<%= $html %>
<%= $::footer %>
}

proc _ns_stats.footer {} {
    set ::footer "" ;#"</body></html>"
}

proc _ns_stats.index {} {
    _ns_stats.header
    set html {<label class='ns-directory-search'>Find a page<input type='search' id='ns-directory-search' placeholder='Search pages' aria-controls='ns-directory'></label><label class='ns-directory-filter'>Scope <select id='ns-directory-scope' aria-controls='ns-directory'><option value='all'>All scopes</option><option value='global'>Global</option><option value='server'>Current server</option></select></label><div class='ns-directory' id='ns-directory'>}
    dict for {group definition} [_ns_stats.navigation.groups] {
        lassign $definition label entries
        append html "<section id='nav-$group'><h3>[ns_quotehtml $label]</h3><ul>"
        foreach {target title} $entries {
            set scope [_ns_stats.navigation.scope $target]
            append html "<li data-scope='$scope'><a href='[_ns_stats.navigation.url $target]'><span>[ns_quotehtml $title]</span><span class='ns-scope'>[_ns_stats.navigation.scopeLabel $scope]</span></a></li>"
        }
        append html "</ul></section>"
    }
    append html {</div><script>
(function () {
 const input = document.getElementById('ns-directory-search');
 const directory = document.getElementById('ns-directory');
 const scope = document.getElementById('ns-directory-scope');
 function filterPages() {
   const query = input.value.trim().toLowerCase();
   directory.querySelectorAll('section').forEach(function (section) {
     let visible = false;
     section.querySelectorAll('li').forEach(function (item) {
       const matchesScope = scope.value === 'all' || item.dataset.scope === scope.value || item.dataset.scope === 'mixed';
       item.hidden = !matchesScope || !(section.querySelector('h3').textContent + ' ' + item.textContent).toLowerCase().includes(query);
       visible = visible || !item.hidden;
     });
     section.hidden = !visible;
   });
 }
 input.addEventListener('input', filterPages);
 scope.addEventListener('change', filterPages);
})();
</script>}
    _ns_stats.footer
    return $html
}

proc _ns_stats.dbpools {} {
    _ns_stats.header "Database pools"
    set rows [_ns_stats.process.dbpools]
    if {$rows eq ""} {
        set html "<p>Database pool statistics are unavailable.</p>"
    } else {
        set html "<p>Database pool statistics are process-wide. A pool can be shared by multiple virtual servers; Process shows which pools each server can access.</p><table class='data'><tbody>[join $rows \n]</tbody></table>"
    }
    _ns_stats.footer
    return $html
}

#
# MCP administration is read-only and uses the normal nsstats access checks.
# Configuration and credential fields are explicitly selected so secret values
# and token digests never enter the rendered page.
#
proc _ns_stats.mcp.toolSummary {tool} {
    # Short admin summaries; full MCP discovery descriptions remain available.
    switch -- [dict get $tool name] {
        server_describe {return "Basic runtime and package versions."}
        configuration {return "Inspect configuration, policy scripts, limits and pool settings; redact credentials."}
        server_topology {return "Versions, loaded modules and server configuration."}
        server_runtime {return "Current gauges or sampled rates, timings and CPU usage."}
        server_history {return "Persisted runtime samples and their coverage."}
        smtp_logs {return "Inspect recent SMTP send results and session events."}
        log_errors {return "Search the system log for errors."}
        log_request_context {return "Correlate log entries by request or thread identifier."}
        log_results {return "Check a search job or read a redacted result page."}
        access_summary {return "Summarize traffic, status codes, timings and peer bursts."}
        default {return [dict get $tool description]}
    }
}

proc _ns_stats.mcp.toolExample {name} {
    switch -- $name {
        server_describe {return "Use server_describe to report runtime and package versions."}
        configuration {return "Use configuration with scope process and follow nextArguments to inspect current settings across all virtual servers. Pair with server_topology and server_runtime for configuration and scaling advice."}
        server_topology {return "Use server_topology to report NaviServer, Tcl, platform and loaded module versions."}
        server_runtime {return "Use server_topology and server_runtime with mode snapshot. Show pool limits, active and waiting requests, and cumulative counters."}
        server_history {return "Use server_history for the last five completed minutes. Follow all pages using nextArguments and report coverage, gaps, restarts and write failures."}
        smtp_logs {return "Use smtp_logs with log event for the last 15 minutes. Show SMTP deferrals, rejections, TLS failures and transaction outcomes; include coverage."}
        log_errors {return "Use log_errors to search for errors, then poll log_results with the returned jobHandle and read the result pages."}
        log_request_context {return "Use log_request_context with the identifier from the selected log entry. Retrieve the correlated system and access records using log_results."}
        log_results {return "Use log_results with the jobHandle from the preceding search. When complete, use its resultHandle to retrieve a result page."}
        access_summary {return "Use access_summary for the last ten completed minutes. Show request frequency, status and pool distributions, timing averages and coverage."}
        default {return ""}
    }
}

# Use the existing nsstats access check; no bearer credentials are exposed or
# stored by this interface. Bind handles and the POST token to this admin.
proc _ns_stats.mcp.identity {} {
    set identity [ns_conn authuser]
    if {[info commands ad_conn] ne "" && ![catch {ad_conn user_id} userId] && $userId > 0} {
        set identity "openacs:$userId"
    } elseif {$identity eq ""} {
        set identity "peer:[ns_conn peeraddr -source direct]"
    }
    return "nsstats:[ns_info server]:$identity"
}

proc _ns_stats.mcp.token {} {
    set key mcp-inspect:[_ns_stats.mcp.identity]
    if {![nsv_exists _ns_stats $key]} {
        nsv_set _ns_stats $key [ns_crypto::randombytes -encoding hex 32]
    }
    return [nsv_get _ns_stats $key]
}

# This handler is reached only after the normal nsstats authorization check.
# Require a POST and a page-issued token before passing the exact JSON-RPC body
# through MCP's protocol, validation, authorization and result handling.
proc _ns_stats.mcp.inspect {} {
    if {[ns_conn method] ne "POST"} {
        ns_return 405 text/plain "Use POST for tool inspection."
        return ""
    }
    set key mcp-inspect:[_ns_stats.mcp.identity]
    set token [ns_set iget [ns_conn headers] X-Nsstats-MCP-Token]
    if {$token eq "" || ![nsv_exists _ns_stats $key] || $token ne [nsv_get _ns_stats $key]} {
        ns_return 403 text/plain "Invalid inspection token; reload the MCP page."
        return ""
    }
    if {[info commands ::nsmcp::protocol] eq ""} {
        ns_return 503 text/plain "MCP protocol is not initialized."
        return ""
    }
    # nsstats routes POST requests through ns_queryget/ns_getform. Keep the
    # page selector and JSON-RPC payload together in the submitted form.
    set body [ns_queryget mcpRequest ""]
    if {[string bytelength $body] > 131072} {
        ns_return 413 text/plain "Inspection request is too large."
        return ""
    }
    # Limit this administration endpoint to tools/call. Protocol.handle performs
    # the full JSON-RPC validation, including duplicate-member checks.
    if {[catch {
        set request [ns_json parse -- $body]
        if {[dict get $request method] ne "tools/call"} {
            error "Expected tools/call"
        }
    }]} {
        ns_return 400 text/plain "Supply a JSON-RPC tools/call request."
        return ""
    }
    set server [ns_info server]
    set permissions {diagnostics.logs.peers.read diagnostics.configuration.process.read}
    foreach tool [::nsmcp::tools describe] {
        lappend permissions [dict get $tool permission]
    }
    set context [::nsmcp::RequestContext new -principal [_ns_stats.mcp.identity] \
        -permissions [lsort -unique $permissions] -targets [list $server] -server $server]
    try {
        set response [::nsmcp::protocol handle $context $body]
        ns_set iupdate [ns_conn outputheaders] Cache-Control no-store
        ns_return [dict get $response status] application/json [dict get $response body]
    } finally {
        $context destroy
    }
    return ""
}

# Runtime tool switches use the same protected admin identity and page-issued
# token as inspection. They are intentionally not callable through MCP itself.
proc _ns_stats.mcp.toolState {} {
    if {[ns_conn method] ne "POST"} {
        ns_return 405 text/plain "Use POST to change tool availability."
        return ""
    }
    set key mcp-inspect:[_ns_stats.mcp.identity]
    set token [ns_set iget [ns_conn headers] X-Nsstats-MCP-Token]
    if {$token eq "" || ![nsv_exists _ns_stats $key] || $token ne [nsv_get _ns_stats $key]} {
        ns_return 403 text/plain "Invalid administration token; reload the MCP page."
        return ""
    }
    if {[info commands ::nsmcp::tools] eq ""
        || [catch {::nsmcp::tools controlsAvailable} available]
        || ![string is boolean -strict $available] || !$available} {
        ns_return 503 text/plain "Runtime tool controls are not available."
        return ""
    }
    set name [ns_queryget mcpToolState ""]
    set enabled [ns_queryget mcpEnabled ""]
    set known false
    foreach tool [::nsmcp::tools describe] {
        if {[dict get $tool name] eq $name} {
            set known true
            break
        }
    }
    if {!$known || $enabled ni {0 1}} {
        ns_return 400 text/plain "Supply a registered tool and mcpEnabled=0 or 1."
        return ""
    }
    if {[catch {::nsmcp::tools setEnabled $name $enabled} result]} {
        ns_log error "nsstats: tool availability update failed for $name: $result"
        ns_return 500 text/plain "Tool availability could not be changed; consult the server log."
        return ""
    }
    ns_log notice "nsstats: [_ns_stats.mcp.identity] set tool $name enabled=$result"
    ns_set iupdate [ns_conn outputheaders] Cache-Control no-store
    ns_return 200 application/json [ns_json value -- [list {} object \
        [list server string [ns_info server] tool string $name enabled boolean $result]]]
    return ""
}

proc _ns_stats.mcp.toolControlScript {} {
    return {<script>
(function () {
 document.querySelectorAll('.mcp-tool-toggle').forEach(function (button) {
   const status = button.parentElement.querySelector('.mcp-tool-state-status');
   button.addEventListener('click', async function () {
     button.disabled = true; status.textContent = 'Applying…';
     try {
       const url = new URL(window.location.href);
       url.searchParams.set('@page', 'mcp'); url.searchParams.delete('mcpInspect'); url.hash = '';
       const response = await fetch(url, {
         method:'POST', credentials:'same-origin', cache:'no-store',
         headers:{'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8', 'X-Nsstats-MCP-Token':button.dataset.token},
         body:new URLSearchParams({'@page':'mcp', mcpToolState:button.dataset.tool, mcpEnabled:button.dataset.enabled}).toString()
       });
       const text = await response.text();
       if (!response.ok) throw new Error('HTTP ' + response.status + ': ' + text);
       const result = JSON.parse(text);
       if (result.tool !== button.dataset.tool || typeof result.enabled !== 'boolean') throw new Error('Unexpected tool-state response.');
       window.location.reload();
     } catch (error) {
       status.textContent = error.message; button.disabled = false;
     }
   });
 });
})();
</script>}
}

proc _ns_stats.mcp.arguments {schema} {
    set rows {}
    set required {}
    if {[dict exists $schema required]} {
        set required [dict get $schema required]
    }
    if {[dict exists $schema properties]} {
        dict for {name property} [dict get $schema properties] {
            set type [expr {[dict exists $property type] ? [dict get $property type] : ""}]
            set description [expr {[dict exists $property description] ? [dict get $property description] : ""}]
            foreach key {default minimum maximum enum} {
                if {[dict exists $property $key]} {
                    append description " $key: [dict get $property $key]."
                }
            }
            lappend rows [list $name $type [expr {$name in $required ? "Yes" : "No"}] [string trim $description]]
        }
    }
    if {$rows eq ""} {
        set html "<p>No named arguments.</p>"
    } else {
        set html [_ns_stats.mcp.table Arguments {Argument Type Required Description} $rows]
    }
    if {[dict exists $schema oneOf] || [dict exists $schema anyOf]} {
        append html "<p>Argument combinations have additional requirements; see the input schema.</p>"
    }
    append html "<details><summary>Input schema</summary><pre>[ns_quotehtml $schema]</pre></details>"
    return $html
}

proc _ns_stats.mcp.table {heading columns rows} {
    set dialogs ""
    set rowIndex 0
    set classes "data data-table mcp w3-table w3-hoverable"
    if {"Tool name" in $columns} {
        append classes " mcp-tools"
    }
    set html "<h3>[ns_quotehtml $heading]</h3><div class='w3-responsive'><table class='$classes'><thead><tr>"
    foreach column $columns {
        append html "<th>[ns_quotehtml $column]</th>"
    }
    append html "</tr></thead><tbody>"
    foreach row $rows {
        append html "<tr>"
        set index 0
        foreach value $row {
            set content [ns_quotehtml $value]
            if {[lindex $columns $index] eq "Tool name"} {
                set content "<code>$content</code>"
            }
            if {[lindex $columns $index] eq "Server availability"} {
                lassign $value name enabled token
                set label [expr {$enabled ? "Disable" : "Enable"}]
                set next [expr {!$enabled}]
                set content "<button type='button' class='mcp-tool-toggle' data-tool='[ns_quotehtml $name]' data-enabled='$next' data-token='[ns_quotehtml $token]'>$label</button> <span class='mcp-tool-state-status' role='status'></span>"
            }
            if {[lindex $columns $index] eq "Tool details"} {
                lassign $value description schema example token
                set id ns-mcp-tool-$rowIndex
                set title [ns_quotehtml [lindex $row 0]]
                set content "<button type='button' data-mcp-dialog='$id' aria-haspopup='dialog'>Details</button>"
                append dialogs "<dialog class='ns-mcp-dialog' id='$id' aria-labelledby='$id-title'><form method='dialog'><button class='ns-mcp-close' aria-label='Close tool details'>Close</button></form><h3 id='$id-title'>$title</h3><p>[ns_quotehtml $description]</p>"
                append dialogs [_ns_stats.mcp.arguments $schema]
                if {$token ne ""} {
                    append dialogs "<details class='mcp-inspect' data-tool='$title' data-token='[ns_quotehtml $token]'><summary>Inspect result</summary><p>Edit JSON arguments and run this tool. Results use the admin identity; handles belong to this identity. Peer disclosure is available to this trusted admin interface when requested.</p><label>Arguments (JSON)<textarea class='mcp-arguments' rows='6' style='box-sizing:border-box;width:100%'>{}</textarea></label><button type='button' class='mcp-run'>Run tool</button> <button type='button' class='mcp-reset'>Reset arguments</button><p class='mcp-inspect-status' role='status'></p><div class='mcp-followups'></div><details class='mcp-response' hidden><summary>Tool result</summary><button type='button' class='mcp-copy'>Copy complete response</button> <button type='button' class='mcp-download'>Download complete response</button><pre class='mcp-result' tabindex='0'></pre><details class='mcp-envelope'><summary>Complete JSON-RPC response</summary><pre class='mcp-result mcp-raw-result' tabindex='0'></pre></details></details></details>"
                }
                if {$example ne ""} {
                    append dialogs "<h4>Example query</h4><textarea readonly rows='4' aria-label='Example query' style='box-sizing:border-box;width:100%'>[ns_quotehtml $example]</textarea>"
                }
                append dialogs "</dialog>"
            }
            if {[lindex $columns $index] eq "Argument schema"} {
                set content "<details><summary>Arguments</summary><div>$content</div></details>"
            }
            append html "<td style='overflow-wrap:anywhere;vertical-align:top'>$content</td>"
            incr index
        }
        append html "</tr>"
        incr rowIndex
    }
    append html "</tbody></table></div>" $dialogs
    if {$dialogs ne ""} {
        append html {<script>
(function () {
 document.querySelectorAll('[data-mcp-dialog]').forEach(function (button) {
   button.addEventListener('click', function () {
     document.getElementById(button.dataset.mcpDialog).showModal();
   });
 });
 document.querySelectorAll('.ns-mcp-dialog').forEach(function (dialog) {
   dialog.addEventListener('click', function (event) {
     if (event.target !== dialog) return;
     const bounds = dialog.getBoundingClientRect();
     if (event.clientX < bounds.left || event.clientX > bounds.right ||
         event.clientY < bounds.top || event.clientY > bounds.bottom) dialog.close();
   });
 });
})();
</script>}
    }
    if {$dialogs ne ""} {
        append html [_ns_stats.mcp.inspectionScript]
    }
    return $html
}

proc _ns_stats.mcp.inspectionScript {} {
    return {<script>
(function () {
 document.querySelectorAll('.mcp-inspect').forEach(function (panel) {
   const input = panel.querySelector('.mcp-arguments');
   const status = panel.querySelector('.mcp-inspect-status');
   const result = panel.querySelector('.mcp-result');
   const responsePanel = panel.querySelector('.mcp-response');
   const rawResult = panel.querySelector('.mcp-raw-result');
   const envelopePanel = panel.querySelector('.mcp-envelope');
   const followups = panel.querySelector('.mcp-followups');
   const runButton = panel.querySelector('.mcp-run');
   let json = '', currentTool = panel.dataset.tool;
   runButton.textContent = 'Run ' + currentTool;
   function offer(label, tool, args) {
     const button = document.createElement('button');
     button.type = 'button'; button.textContent = label;
     button.addEventListener('click', function () {
       input.value = JSON.stringify(args, null, 2);
       run(tool, args);
     });
     followups.appendChild(button);
   }
   async function run(tool, args) {
     currentTool = tool; runButton.textContent = 'Run ' + tool;
     runButton.disabled = true; panel.querySelector('.mcp-reset').disabled = true; status.textContent = 'Running ' + tool + '…';
     followups.replaceChildren(); responsePanel.hidden = true; json = '';
     try {
       const url = new URL(window.location.href);
       url.searchParams.set('@page', 'mcp'); url.searchParams.set('mcpInspect', '1');
       url.hash = '';
       const response = await fetch(url, {
         method: 'POST', credentials: 'same-origin', cache: 'no-store',
         headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8', 'X-Nsstats-MCP-Token': panel.dataset.token},
         body: new URLSearchParams({
           '@page':'mcp', mcpInspect:'1',
           mcpRequest:JSON.stringify({jsonrpc:'2.0', id:1, method:'tools/call', params:{name:tool, arguments:args}})
         }).toString()
       });
       const body = await response.text();
       let envelope;
       try { envelope = JSON.parse(body); }
       catch (error) { throw new Error('HTTP ' + response.status + ': ' + body); }
       json = JSON.stringify(envelope, null, 2); rawResult.textContent = json;
       const displayed = envelope.error || (envelope.result && envelope.result.structuredContent) || envelope.result || envelope;
       result.textContent = JSON.stringify(displayed, null, 2); envelopePanel.open = false;
       responsePanel.hidden = false; responsePanel.open = true; currentTool = tool;
       status.textContent = envelope.error ? 'MCP returned an error.' : 'Response received from ' + tool + '.';
       const data = envelope.result && envelope.result.structuredContent;
       if (!data) return;
       if (data.jobHandle && data.status !== 'complete') {
         offer('Poll job', 'log_results', {jobHandle:data.jobHandle});
       }
       if (data.nextArguments) offer('Next history page', 'server_history', data.nextArguments);
       const handles = new Set();
       function pages(value, path) {
         if (!value || typeof value !== 'object') return;
         if (typeof value.resultHandle === 'string' && (!value.records || value.more) && !handles.has(value.resultHandle)) {
           handles.add(value.resultHandle);
           const next = {resultHandle:value.resultHandle, limit:args.limit || 20};
           if (args.includePeerAddresses === true) next.includePeerAddresses = true;
           if (value.more && value.nextCursor !== '' && value.nextCursor != null) next.cursor = value.nextCursor;
           offer((next.cursor != null ? 'Next page' : 'Read results') + (path ? ' (' + path + ')' : ''), 'log_results', next);
         }
         Object.keys(value).forEach(key => pages(value[key], path ? path + '.' + key : key));
       }
       pages(data, '');
     } catch (error) {
       status.textContent = error.message;
     } finally { runButton.disabled = false; panel.querySelector('.mcp-reset').disabled = false; }
   }
   runButton.addEventListener('click', function () {
     try {
       const args = JSON.parse(input.value);
       if (!args || Array.isArray(args) || typeof args !== 'object') throw new Error('Arguments must be a JSON object.');
       run(currentTool, args);
     } catch (error) { status.textContent = error.message; }
   });
   panel.querySelector('.mcp-reset').addEventListener('click', function () {
     currentTool = panel.dataset.tool; input.value = '{}'; runButton.textContent = 'Run ' + currentTool;
     followups.replaceChildren(); status.textContent = 'Arguments reset; no call made.';
   });
   panel.querySelector('.mcp-copy').addEventListener('click', async function () {
     try { await navigator.clipboard.writeText(json); status.textContent = 'JSON copied.'; }
     catch (error) { status.textContent = 'Copy unavailable; select the response text to copy it.'; }
   });
   panel.querySelector('.mcp-download').addEventListener('click', function () {
     const url = URL.createObjectURL(new Blob([json], {type:'application/json'}));
     const link = document.createElement('a'); link.href = url; link.download = currentTool + '.json';
     link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
   });
 });
})();
</script>}
}

proc _ns_stats.mcp {} {
    if {[info commands ::nsmcp::ToolRegistry] eq ""} {
        return "[_ns_stats.header MCP]<p>The nsmcp module is not active.</p>[_ns_stats.footer]"
    }
    if {[ns_queryget mcpToolState ""] ne ""} {
        return [_ns_stats.mcp.toolState]
    }
    if {[ns_queryget mcpInspect ""] ne ""} {
        return [_ns_stats.mcp.inspect]
    }
    set html [_ns_stats.header "MCP"]
    set server [ns_info server]
    set section ns/server/$server/module/nsmcp
    append html "<p>Server: <strong>[ns_quotehtml $server]</strong>. Open Inspect result in a tool’s Details to execute it on demand; page loading does not execute tools. Tool switches take effect at runtime; other configuration changes require module initialization or restart.</p>"

    if {[info commands ::nsmcp::tools] ne ""} {
        if {[catch {::nsmcp::tools describe} tools]} {
            append html "<p>Tool inspection unavailable; update nsmcp to provide registry describe.</p>"
        } else {
            set rows {}
            set token ""
            if {[info commands ::nsmcp::protocol] ne ""} {
                set token [_ns_stats.mcp.token]
            }
            set controls false
            if {$token ne "" && ![catch {::nsmcp::tools controlsAvailable} supported]
                && [string is boolean -strict $supported] && $supported} {
                set controls true
            }
            foreach tool $tools {
                set enabled [expr {![dict exists $tool enabled] || [dict get $tool enabled]}]
                set state [expr {[dict exists $tool enabled] ? ($enabled ? "Enabled" : "Disabled") : "Registered"}]
                set inspectToken [expr {$enabled ? $token : ""}]
                set row [list [dict get $tool name] $state \
                    [_ns_stats.mcp.toolSummary $tool] [dict get $tool permission] \
                    [list [dict get $tool description] [dict get $tool inputSchema] \
                        [_ns_stats.mcp.toolExample [dict get $tool name]] $inspectToken]]
                if {$controls} {
                    lappend row [list [dict get $tool name] $enabled $token]
                }
                lappend rows $row
            }
            set columns {{Tool name} Status Purpose {Required permission} {Tool details}}
            append html "<p>Use these exact tool names in client queries. Open Details for arguments and a selectable example query.</p>"
            if {$controls} {
                lappend columns {Server availability}
                append html "<p>Tool switches affect all MCP clients on this virtual server. Runtime changes survive reloads but reset on process restart. Disabling a tool prevents new calls; existing jobs and collectors continue. Clients may need to refresh their tool list.</p>"
            }
            append html [_ns_stats.mcp.table "Available tools" $columns $rows]
            if {$controls} {
                append html [_ns_stats.mcp.toolControlScript]
            }
        }
    }

    set version Unknown
    set tag Unknown
    if {![catch {ns_server -server $server modules} modules]
        && [dict exists $modules nsmcp]} {
        set module [dict get $modules nsmcp]
        foreach key {version tag} {
            if {[dict exists $module $key] && [dict get $module $key] ne ""} {
                set $key [dict get $module $key]
            }
        }
    }
    append html [_ns_stats.mcp.table "Module version" {Module Version {Build tag}} \
        [list [list nsmcp $version $tag]]]
    append html "<p>Version and build tag come from NaviServer's loaded-module metadata. Unknown means the module does not report that information. Individual tools have no separate version.</p>"

    set objects {
        auth Authentication {Authenticate bearer tokens.}
        credentials Credentials {Load named token files and permission policies.}
        server {HTTP endpoint} {Receive MCP HTTP requests.}
        database {SQLite cache} {Store bounded analytics data.}
        logService {Log service} {Manage log searches, correlation and redaction.}
        accessAnalytics {Access analytics} {Ingest and aggregate access-log records.}
    }
    set rows {}
    foreach {name label purpose} $objects {
        set present [expr {[info commands ::nsmcp::$name] ne ""}]
        lappend rows [list $label [expr {$present ? "Initialized" : "Not initialized"}] $purpose]
    }
    append html [_ns_stats.mcp.table "Runtime components" {Component Status Purpose} $rows]
    append html "<p>Initialized means the component object exists; it is not a health or coverage guarantee.</p>"

    foreach {heading options} {
        {HTTP and authentication} {
            enableHttp false path /mcp allowedOrigins {} credentials {}
        }
        {Log tools} {
            enableLogTools false systemLog {} accessLog {} cacheDirectory {}
        }
        {SMTP log tools} {
            enableSmtpTools false smtpLogReadBytes 1MiB
        }
        {Access analytics and database} {
            enableAccessAnalytics false databasePool {} databaseMaxBytes 1GiB
            accessIngestInterval 5s accessMaxRows 2000000 accessRetention 24h
            accessTimingColumn -1
        }
        {Runtime diagnostics and history} {
            enableStatsTools true
        }
    } {
        set rows {}
        foreach {key default} $options {
            set configured [ns_config $section $key ""]
            if {$configured eq ""} {
                lappend rows [list $key $default "Default / unset"]
            } else {
                lappend rows [list $key $configured "Configured"]
            }
        }
        append html [_ns_stats.mcp.table $heading {Parameter Value Source} $rows]
    }

    set rows {}
    foreach {key default} [list server [lindex [ns_info servers] 0] \
                              sampling false samplingInterval 10s \
                              historyPool {} historyRetention 24h historyMaxBytes 64MiB] {
        set value [ns_config ns/stats $key $default]
        lappend rows [list $key $value]
    }
    append html [_ns_stats.mcp.table "Core diagnostics startup settings (ns/stats)" {Parameter Value} $rows]
    append html "<p>Sampling and persistence are configured by ns_stats, independently of MCP. Runtime status below may differ from startup settings.</p>"

    set rows {}
    foreach {object properties} {
        server {path}
        http {allowedOrigins maxBodyBytes}
        database {pool maxBytes}
        logService {queue lifetime maxJobs}
        accessAnalytics {path maxRows retentionSeconds maxReadBytes maxLineBytes maxSeconds}
    } {
        set command ::nsmcp::$object
        if {[info commands $command] eq ""} {
            continue
        }
        foreach property $properties {
            if {![catch {$command cget -$property} value]} {
                lappend rows [list $object $property $value]
            }
        }
    }
    append html [_ns_stats.mcp.table "Active component settings" {Component Setting Value} $rows]
    append html "<p>Active component settings reflect initialized objects; configuration tables above show startup values and defaults.</p>"

    if {[info commands ::nsmcp::logDiscovery] ne ""} {
        if {[catch {::nsmcp::logDiscovery discover} discovery]} {
            append html "<p>Log discovery unavailable.</p>"
        } else {
            set rows {}
            foreach kind {system access} {
                set entry [dict get $discovery $kind]
                lappend rows [list $kind [dict get $entry path] [dict get $entry origin] \
                    [dict get $entry exists] [dict get $entry readable]]
            }
            append html [_ns_stats.mcp.table "Discovered logs" {Log Path Origin Exists Readable} $rows]
        }
    }

    if {[info commands ::nsmcp::credentials] ne ""} {
        if {[catch {::nsmcp::credentials describe} credentials]} {
            append html "<p>Credential policy status unavailable.</p>"
        } else {
            set rows {}
            dict for {name entry} $credentials {
                set row [list $name]
                foreach key {principal permissions targets expires status tokenFile} {
                    lappend row [expr {[dict exists $entry $key] ? [dict get $entry $key] : "unknown"}]
                }
                lappend rows $row
            }
            append html [_ns_stats.mcp.table "Credential policies" \
                {Name Principal Permissions Servers {Expiry epoch (0: none)} Status {Token file path}} $rows]
            append html "<p>Token contents and digests are omitted. Tool visibility depends on each credential's permissions.</p>"
        }
    }

    if {[info commands ::ns_stats] ne ""} {
        foreach {command heading} {sampling Sampling history {History persistence}} {
            if {[catch {ns_stats $command status} status]} {
                append html "<p>[ns_quotehtml $heading] status unavailable.</p>"
            } else {
                set rows {}
                dict for {key value} $status {
                    lappend rows [list $key $value]
                }
                append html [_ns_stats.mcp.table $heading {Metric Value} $rows]
            }
        }
    }
    append html [_ns_stats.footer]
    return $html
}

proc _ns_stats.mem.adp {} {
    set col         [ns_queryget col 1]
    set reverseSort [ns_queryget reversesort 1]

    set numericSort 1
    set colTitles   [list File Device Inode "Modify Time" "Ref Count" Evals Size Blocks Scripts]

    if {$col == 1} {
        set numericSort 0
    }

    set results ""

    foreach {file stats} [ns_adp_stats] {
        set s  ""

        foreach {k v} $stats {
            if {"mtime" eq $k} {
                lappend s [_ns_stats.fmtTime $v]
            } else {
                lappend s $v
            }
        }
        lappend results [concat $file $s]
    }

    set rows [_ns_stats.sortResults $results [expr {$col - 1}] $numericSort $reverseSort]

    append html \
        [_ns_stats.header ADP] \
        [_ns_stats.results mem $col $colTitles ?@page=mem.adp $rows $reverseSort] \
        [_ns_stats.footer]

    return $html
}

proc _ns_stats.mem.cache.histogram {cacheName sorted} {
    set nrEntries [llength $sorted]
    if {$nrEntries < 1} {
        return ""
    }
    set stats [ns_cache_stats $cacheName]
    set utilization [format %.2f [expr {[dict get $stats size]*100.0/[dict get $stats maxsize]}]]
    set nrBuckets [expr {$nrEntries > 50 ? 50 : $nrEntries}]
    set bucketSize [expr {$nrEntries/$nrBuckets}]
    set r ""
    #append r "<pre>nrEntries $nrEntries bucketSize $bucketSize\n"
    set reuses {}
    set labels {}
    set reused 0
    for {set b 0} {$b < $nrBuckets} {incr b} {
        set subset [lrange $sorted [expr {$b*$bucketSize}] [expr {($b+1)*$bucketSize - 1}]]
        set sumHits 0
        foreach e $subset {
            set hits [lindex $e 2]
            incr sumHits $hits
            if {$hits > 1} {
                incr reused
            }
        }
        set avgHits [expr {$sumHits*1.0/$bucketSize}]
        lappend reuses $avgHits
        #lappend labels '[expr {$b+1}]'
        lappend labels '[format %.2f [expr {(($b+1)*100.0)*$bucketSize*($utilization/100)/$nrEntries}]]'
        #append r "$b: from [expr {$b*$bucketSize}] to [expr {($b+1)*$bucketSize - 1}] sumHits $sumHits avgHits $avgHits\n"
    }
    #append r </pre>\n
    set ::extraHeadEntries {
        <script src="https://code.highcharts.com/highcharts.js"></script>
        <script src="https://code.highcharts.com/modules/exporting.js"></script>
        <script src="https://code.highcharts.com/modules/export-data.js"></script>
    }
    set data [join $reuses ,]
    set categories [join $labels ,]
    set maxSize [_ns_stats.hr [dict get $stats maxsize]]B
    set sufficient [_ns_stats.hr [expr {[dict get $stats size] * 1.1 * $reused / $nrEntries }] %.0f]B
    # margin: 0 auto
    set config "[ns_cache_configure $cacheName]"
    append r [subst -nocommands {
        <div id="histogram" style="min-width: 310px; height: 400px; width: 70%; "></div>
        <script>
        Highcharts.chart('histogram', {
            chart:    { type: 'column' },
            title:    { text: 'Cache-entry reuse in $cacheName' },
            subtitle: { text: '$config<br>(Entries: $nrEntries, reused: $reused, bucket size: $bucketSize, utilization: $utilization%, cache size: $maxSize, sufficient: $sufficient)' },
            yAxis:    { min: 1, title: { text: 'Hits' }, type: 'logarithmic', minorTickInterval: 0.1 },
            xAxis:    { title: { text: 'Percent'}, categories: [$categories] },
            legend:   {enabled: false},
            tooltip:  {
                headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
                pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
                '<td style="padding:0"><b>{point.y:.1f} hits</b></td></tr>',
                footerFormat: '</table>',
                shared: true,
                useHTML: true
            },
            plotOptions: { column: { pointPadding: 0, borderWidth: 0, groupPadding: 0, shadow: false } },
            series: [{ name: 'Reuse', data: [$data] }]
        });
        </script>
    }]
    return $r
}

proc _ns_stats.mem.cache {} {
    set col         [ns_queryget col 1]
    set reverseSort [ns_queryget reversesort 1]
    set statDetails [ns_queryget statDetails ""]
    set currentUrl  "./[lindex [ns_conn urlv] end]?@page=mem.cache&col=$col&reverseSort=$reverseSort"

    if {$statDetails ne ""} {
        set max  [ns_queryget max 50]
        set body ""
        set stats [ns_cache_stats -contents $statDetails]
        set sorted [lsort -decreasing -integer -index 2 $stats]
        set h [ _ns_stats.mem.cache.histogram $statDetails $sorted]
        append body \
            $h \
            "<h4>$max most frequently used entries from cache '$statDetails'</h4>\n" \
            "<table class='data' width='70%'><tr><th>Key</th><th>Size</th><th>Hits</th><th>Expire</th></tr>\n"
        foreach row [lrange $sorted 0 $max] {
            lassign $row key hits size expire
            if {$expire == 0} {
                set expire -1
            } else {
                lassign [split [ns_time format $expire] .] secs usecs
                set expire [_ns_stats.fmtTime $secs]
            }
            append body "<tr><td>[ns_quotehtml $key]</td>" \
                "<td align='right'>$hits</td>" \
                "<td align='right'>$size</td>" \
                "<td align='center'>$expire</td>"\
                "</tr>\n"
        }
        append body <table>

        append html \
            [_ns_stats.header [list Cache $currentUrl] $statDetails] \
            $body \
            [_ns_stats.footer]


    } else {

        set numericSort 1
        if {$col == 1} {
            set numericSort 0
        }

        set results ""
        set totalRequests [_ns_stats.totalRequests]

        array set t {saved ""}
        set totalSaved 0
        foreach cache [ns_cache_names] {
            array set t {commit 0 rollback 0 collisions 0 waits 0 rewaits 0 timeouts 0}
            array set t [ns_cache_stats $cache]
            set avgSize [expr {$t(entries) > 0 ? $t(size)/$t(entries) : 0}]
            lappend results [list $cache $t(maxsize) $t(size) \
                                 [expr {$t(size)*100.0/$t(maxsize)}] \
                                 $t(entries) $avgSize $t(flushed) \
                                 $t(hits) \
                                 [format %.4f [expr {$totalRequests > 0 ? $t(hits)*1.0/$totalRequests : 0}]] \
                                 [format %.f [expr {$t(entries)>0 ? $t(hits)*1.0/$t(entries) : 0}]] \
                                 $t(missed) $t(hitrate) $t(expired) $t(pruned) \
                                 $t(commit) $t(rollback) \
                                 $t(collisions) $t(waits) $t(rewaits) $t(timeouts) \
                                 [expr {$t(hits) > 0 ? $t(saved)*1.0/$t(hits) : 0}] \
                                 [expr {$totalRequests > 0 ? $t(saved)/$totalRequests : 0}] \
                                ]
            set totalSaved [expr {$totalSaved + $t(saved)}]
        }

        set colTitles   {
            Cache Max Current Utilization Entries "Avg Size" Flushes Hits Hits/Req Reuse Misses
            "Hit Rate" Expired Pruned Commit Rollback Collisions Waits Rewaits Timeouts
            "Saved/Hit" "Saved/Req"
        }
        set rows [_ns_stats.sortResults $results [expr {$col - 1}] $numericSort $reverseSort]

        set table {}
        foreach row $rows {
            set cache_name [lindex $row 0]
            lset row 0 "<a href='$currentUrl&statDetails=$cache_name'>$cache_name</a>"
            lset row 1 [_ns_stats.hr [lindex $row 1]]
            lset row 2 [_ns_stats.hr [lindex $row 2]]
            lset row 3 [format %.2f [lindex $row 3]]%
            lset row 4 [_ns_stats.hr [lindex $row 4]]
            lset row 5 [_ns_stats.hr [lindex $row 5]]
            lset row 6 [_ns_stats.hr [lindex $row 6]]
            lset row 7 [_ns_stats.hr [lindex $row 7]]
            lset row 10 [_ns_stats.hr [lindex $row 10]]
            lset row 11 [format %.2f [lindex $row 11]]%
            lset row 12 [_ns_stats.hr [lindex $row 12]]
            lset row 13 [_ns_stats.hr [lindex $row 13]]
            lset row 16 [_ns_stats.hr [lindex $row 16]]
            lset row 17 [_ns_stats.hr [lindex $row 17]]
            lset row 18 [_ns_stats.hr [lindex $row 18]]
            lset row 19 [_ns_stats.hr [lindex $row 19]]
            lset row 20 [_ns_stats.hr [lindex $row 20]]s
            lset row 21 [_ns_stats.hr [lindex $row 21]]s
            lappend table $row
        }

        append html \
            [_ns_stats.header Cache] \
            "<p class='summary'>ns_cache operations saved since the start of the server [_ns_stats.fmtSeconds $totalSaved] on [_ns_stats.hr $totalRequests] requests " \
            "([_ns_stats.hr [expr {$totalSaved/$totalRequests}]]s per request on average)</p>" \n \
            [_ns_stats.results cache $col $colTitles ?@page=mem.cache $table $reverseSort {
                left
                right right right right right
                right right right right right
                right right right right right
                right right right right right
                right
            }] \
            [_ns_stats.footer]
    }
    return $html
}

# Prefer a ready shared sample while sampling runs; allow an explicit snapshot.
# Neither read changes sampling. An absent command selects the legacy collector.
proc _ns_stats.runtimeSnapshot {} {
    if {[info commands ::ns_stats] eq ""} {
        return {}
    }
    set mode auto
    if {[info commands ns_queryget] ne ""} {
        set mode [ns_queryget statsMode auto]
    }
    if {$mode ni {auto snapshot}} {
        set mode auto
    }
    set status [ns_stats sampling status]
    if {$mode eq "auto" && [dict get $status running]} {
        set sample [ns_stats sample]
        if {[dict get $sample sampling ready]} {
            dict set sample collectorMode sample
            dict set sample samplingStatus $status
            return $sample
        }
    }
    set snapshot [ns_stats snapshot]
    dict set snapshot collectorMode snapshot
    dict set snapshot samplingStatus $status
    return $snapshot
}

proc _ns_stats.sampled {snapshot} {
    return [expr {[dict exists $snapshot collectorMode] && [dict get $snapshot collectorMode] eq "sample"}]
}

# Reconstruct only the preceding counter values needed by the existing tables.
# Unknown/reset deltas produce decreased counters and remain unknown in renderers.
proc _ns_stats.utilization.samplePrevious {current snapshot} {
    set previous $current
    dict for {thread data} [dict get $snapshot drivers] {
        dict for {key value} [dict get $data counters] {
            set delta [_ns_stats.dictGetDef $data deltas $key {}]
            dict set previous drivers $thread $key [expr {$delta eq "" ? $value+1 : $value-$delta}]
        }
    }
    dict for {server data} [dict get $snapshot servers] {
        dict for {pool entry} [dict get $data pools] {
            dict for {key value} [dict get $entry counters] {
                if {![string is double -strict $value]} continue
                set delta [_ns_stats.dictGetDef $entry deltas $key {}]
                dict set previous servers $server pools $pool stats $key [expr {$delta eq "" ? $value+1 : $value-$delta}]
            }
        }
    }
    dict set previous timestamp [expr {[dict get $snapshot timestamp]-int([dict get $snapshot sampling elapsedSeconds]*1000000)}]
    return $previous
}

proc _ns_stats.utilization.sampleTotal {snapshot role key} {
    set total 0.0
    dict for {server data} [dict get $snapshot servers] {
        dict for {pool entry} [dict get $data pools] {
            set value [_ns_stats.dictGetDef $entry $role $key {}]
            if {$value eq ""} {return -1.0}
            set total [expr {$total+$value}]
        }
    }
    return $total
}

# Source controls do not start/stop sampling or configure persistence.
proc _ns_stats.utilization.sourcePanel {sample {page utilization}} {
    set snapshot [_ns_stats.dictGetDef $sample coreSnapshot {}]
    if {$snapshot eq ""} {return {}}
    set status [_ns_stats.dictGetDef $snapshot samplingStatus {}]
    set sampled [_ns_stats.sampled $snapshot]
    set label [expr {$sampled ? "Shared interval sample" : "Live snapshot"}]
    set details "Gauges are observations at collection time."
    if {$sampled} {
        set age [dict get $snapshot sampling ageSeconds]
        set interval [dict get $snapshot sampling elapsedSeconds]
        set details "Sample age: [format %.2f $age]s; measured interval: [format %.3f $interval]s. Rates and CPU use this interval, independently of page refreshes."
        if {$age>2*[dict get $status interval]} {
            append details " <strong>Sample is stale.</strong>"
        }
    } elseif {[_ns_stats.dictGetDef $status running false]} {
        append details " Sampling is running; the first usable interval is not ready, or live snapshot was selected."
    } else {
        append details " Sampling is stopped; rates use page observations."
    }
    set selectedAuto [expr {$sampled || [ns_queryget statsMode auto] ne "snapshot" ? " selected" : ""}]
    set selectedSnapshot [expr {$selectedAuto eq "" ? " selected" : ""}]
    return "<p><strong>$label.</strong> $details Collection time: [clock format [expr {[dict get $snapshot timestamp]/1000000}] -format {%Y-%m-%d %H:%M:%S %Z}].</p><form method='get'><input type='hidden' name='@page' value='[ns_quotehtml $page]'><label>Measurements <select name='statsMode'><option value='auto'$selectedAuto>Use shared sampling when running</option><option value='snapshot'$selectedSnapshot>Live snapshot / page interval</option></select></label> <button type='submit'>Apply</button></form>"
}

# Reduce stored records to plot/table data while paging, rather than retaining
# thousands of complete thread/driver snapshots in the page interpreter.
proc _ns_stats.utilization.historyPoint {record} {
    set ready [dict get $record sampling ready]
    set requests -1.0
    set poolRates {}
    dict for {server data} [dict get $record servers] {
        dict for {pool entry} [dict get $data pools] {
            set rate [_ns_stats.dictGetDef $entry rates requests {}]
            dict set poolRates $server/$pool $rate
        }
    }
    if {$ready} {set requests [_ns_stats.utilization.sampleTotal $record rates requests]}
    set n [_ns_stats.utilization.sampleTotal $record deltas requests]
    set timings {}
    foreach key {queuetime filtertime runtime tracetime} {
        set total [_ns_stats.utilization.sampleTotal $record deltas $key]
        dict set timings $key [expr {$ready && $n>0 && $total>=0 ? 1000.0*$total/$n : -1.0}]
    }
    set groups [_ns_stats.dictGetDef $record cpuPercent groups {}]
    set cpu -1.0
    if {$ready && $groups ne ""} {
        set cpu 0.0
        dict for {group value} $groups {set cpu [expr {$cpu+$value}]}
    }
    return [dict create timestamp [dict get $record timestamp] instance [dict get $record instance] \
        sampling [dict get $record sampling] requests $requests pools $poolRates timings $timings cpu $cpu groups $groups]
}

proc _ns_stats.utilization.readHistory {minutes} {
    set to [clock seconds]
    set from [expr {$to-$minutes*60}]
    set status [ns_stats history status]
    set source memory
    if {[_ns_stats.dictGetDef $status pool {}] ne ""} {
        if {[dict get $status owner] ne [ns_info server]} {
            return [dict create available false reason "Persistent history belongs to virtual server '[dict get $status owner]'; open nsstats there."]
        }
        set source sqlite
    }
    set points {}
    set cursor 0
    set coverage {}
    set gaps {}
    set restarts {}
    set events {}
    set resets 0
    set overlap false
    set more true
    set pages 0
    # Bound request work; at ten-second cadence this covers a full day.
    while {$more && [llength $points]<10000} {
        if {$source eq "sqlite"} {
            set page [ns_stats history query -from $from -to $to -limit 1000 -cursor $cursor]
        } else {
            set page [ns_stats sampling history -from $from -to $to -limit 180 -cursor $cursor]
        }
        incr pages
        foreach record [dict get $page records] {
            lappend points [_ns_stats.utilization.historyPoint $record]
        }
        set current [dict get $page coverage]
        set gaps [concat $gaps [_ns_stats.dictGetDef $current gaps {}]]
        set restarts [concat $restarts [_ns_stats.dictGetDef $current restartBoundaries {}]]
        set events [concat $events [_ns_stats.dictGetDef $current events {}]]
        incr resets [_ns_stats.dictGetDef $current resetSamples 0]
        set overlap [expr {$overlap || [_ns_stats.dictGetDef $current evictionOrFailureOverlap false]}]
        set coverage $current
        set more [dict get $page more]
        if {$more} {
            set next [dict get $page nextCursor]
            if {$next eq "" || $next<=$cursor} {error "History paging did not advance"}
            set cursor $next
        }
    }
    dict set coverage gaps [lsort -unique $gaps]
    dict set coverage restartBoundaries [lsort -unique $restarts]
    dict set coverage events [lsort -unique $events]
    dict set coverage resetSamples $resets
    dict set coverage evictionOrFailureOverlap $overlap
    # Current core final-page coverage supersedes page-local diagnostics.
    # Older cores still require conservative aggregation across pages.
    if {[_ns_stats.dictGetDef $current windowExamined false]} {
        set coverage $current
    } elseif {$pages>1} {
        dict set coverage complete false
    }
    if {$more} {dict set coverage complete false}
    return [dict create available true source $source persistence $status points $points from $from to $to \
        coverage $coverage storage [_ns_stats.dictGetDef $page storage {}] truncated $more pages $pages]
}

# Produce literal JSON, including nulls for unknown observations and gaps.
proc _ns_stats.utilization.historyChart {id title unit points kind} {
    set names {Total}
    if {$kind eq "pools"} {
        set names {}
        foreach point $points {set names [concat $names [dict keys [dict get $point pools]]]}
        set names [lsort -unique $names]
    } elseif {$kind eq "cpu"} {
        set names {connection driver writer spooler other}
    }
    set series {}
    set seriesIndex 0
    foreach name $names {
        set data {}
        set index 0
        set previous {}
        foreach point $points {
            set stamp [expr {[dict get $point timestamp]/1000}]
            set sampling [dict get $point sampling]
            if {$previous ne ""} {
                set elapsed [expr {([dict get $point timestamp]-[dict get $previous timestamp])/1000000.0}]
                if {[dict get $point instance] ne [dict get $previous instance]
                    || $elapsed>1.5*max([dict get $sampling intervalSeconds],[dict get $previous sampling intervalSeconds])} {
                    lappend data $index array [list 0 number [expr {[dict get $previous timestamp]/1000+1}] 1 null {}]
                    incr index
                }
            }
            set value {}
            if {[dict get $sampling ready]} {
                switch -- $kind {
                    pools {set value [_ns_stats.dictGetDef $point pools $name {}]}
                    cpu {set value [_ns_stats.dictGetDef $point groups $name {}]}
                    default {set value [dict get $point requests]}
                }
            }
            set type number
            if {$value eq "" || $value<0} {set type null; set value {}}
            lappend data $index array [list 0 number $stamp 1 $type $value]
            incr index
            set previous $point
        }
        lappend series $seriesIndex object [list name string $name data array $data]
        incr seriesIndex
    }
    set config [list {} object [list chart object {type string line height number 300} \
        title object [list text string $title] time object {useUTC boolean false} \
        xAxis object {type string datetime} yAxis object [list title object [list text string $unit]] \
        plotOptions object {series object {connectNulls boolean false marker object {enabled boolean false}}} \
        series array $series]]
    set json [string map [list < {\u003c} > {\u003e} & {\u0026}] [ns_json value -- $config]]
    set jsonId [ns_json value -- [list {} string $id]]
    return "<div id='[ns_quotehtml $id]' class='utilization-chart'></div><script>Highcharts.chart($jsonId,$json);</script>"
}

proc _ns_stats.utilization.historyPanel {} {
    if {[info commands ::ns_stats] eq ""} {return {}}
    set minutes [ns_queryget historyMinutes 15]
    if {$minutes ni {15 60 360 1440}} {set minutes 15}
    set options {}
    foreach {value label} {15 {Last 15 minutes} 60 {Last hour} 360 {Last 6 hours} 1440 {Last 24 hours}} {
        set selected [expr {$minutes==$value ? " selected" : ""}]
        append options "<option value='$value'$selected>$label</option>"
    }
    set html "<h2>Recent sampled history</h2><form method='get'><input type='hidden' name='@page' value='utilization'><input type='hidden' name='statsMode' value='[ns_quotehtml [ns_queryget statsMode auto]]'><label>Period <select name='historyMinutes'>$options</select></label> <button type='submit'>Show history</button></form>"
    if {[catch {_ns_stats.utilization.readHistory $minutes} result]} {
        return "$html<p>History unavailable: [ns_quotehtml $result]</p>"
    }
    if {![dict get $result available]} {return "$html<p>[ns_quotehtml [dict get $result reason]]</p>"}
    set points [dict get $result points]
    set coverage [dict get $result coverage]
    set source [dict get $result source]
    set status [dict get $result persistence]
    set label [expr {$source eq "sqlite" ? "Persistent SQLite history (including retained samples before restart)" : "Process memory: at most 180 samples / 15 minutes; lost on process restart"}]
    append html "<p>[ns_quotehtml $label]. [llength $points] samples returned. No sampling or persistence settings are changed by this page.</p>"
    set rows [list [list Source $label] \
        [list "Paging complete" [expr {![dict get $result truncated]}]] \
        [list "Coverage reported complete" [_ns_stats.dictGetDef $coverage complete false]] \
        [list Gaps [llength [dict get $coverage gaps]]] \
        [list "Restart boundaries" [llength [dict get $coverage restartBoundaries]]] \
        [list "Baseline/reset samples" [dict get $coverage resetSamples]] \
        [list "Eviction or failure overlap" [dict get $coverage evictionOrFailureOverlap]] \
        [list "Dropped through (epoch microseconds)" [_ns_stats.dictGetDef $coverage droppedThrough {}]]]
    if {$source eq "sqlite"} {
        lappend rows [list "Persistence enabled" [dict get $status enabled]] \
            [list "Write failures since persistence started" [dict get $status failures]]
    }
    foreach {key label} {sampleCount {Retained samples} retainedSeconds {Retained seconds}
                         allocatedBytes {SQLite allocated bytes} usedBytes {SQLite used bytes}
                         databaseLimitBytes {SQLite database cap (bytes)} bytesPerSample {Bytes per retained sample}} {
        if {[dict exists $result storage $key]} {
            lappend rows [list $label [dict get $result storage $key]]
        }
    }
    foreach {key label} {retainedFrom {Oldest retained sample} retainedTo {Newest retained sample}} {
        set value [_ns_stats.dictGetDef $coverage $key 0]
        lappend rows [list $label [expr {$value>0 ? [clock format [expr {int($value)}] -format {%Y-%m-%d %H:%M:%S %Z}] : "unknown"}]]
    }
    append html [_ns_stats.results history-coverage 0 {Metric Value} {?@page=utilization} $rows 0 {left left}]
    if {[dict get $result truncated]} {append html "<p><strong>History limited to 10,000 samples; select a shorter period.</strong></p>"}
    if {$points eq ""} {return "$html<p>No retained samples in this interval. Start sampling to collect observations; enable persistence for longer history and restart survival.</p>"}
    append html "<p>Rates and timings describe each measured sampling interval. Gauges describe its end. Missing/reset intervals are unknown; chart lines break across gaps and restarts. CPU percentages show measured thread groups relative to one core.</p>"
    append html "<div class='utilization-charts'>" \
        [_ns_stats.utilization.historyChart history-requests {Requests per second by server/pool} requests/s $points pools] \
        [_ns_stats.utilization.historyChart history-cpu {Measured CPU by thread group} {CPU % of one core} $points cpu] "</div>"
    set rows {}
    foreach point [lreverse [lrange $points end-19 end]] {
        set row [list [clock format [expr {[dict get $point timestamp]/1000000}] -format {%Y-%m-%d %H:%M:%S %Z}] \
            [_ns_stats.dictGetDef $point sampling elapsedSeconds {}] \
            [_ns_stats.utilization.displayRate [dict get $point requests]]]
        foreach key {queuetime filtertime runtime tracetime} {
            set value [dict get $point timings $key]
            lappend row [expr {$value>=0 ? [format %.3f $value] : "unknown"}]
        }
        set cpu [dict get $point cpu]
        lappend row [expr {$cpu>=0 ? [format %.1f $cpu] : "unknown"}]
        lappend rows $row
    }
    append html "<h3>Latest 20 retained intervals</h3>" \
        [_ns_stats.results history-intervals 0 {{Interval ending} {Seconds} {Requests/s} {Queue ms} {Filter ms} {Run ms} {Trace ms} {Measured CPU %}} {?@page=utilization} $rows 0 {left right right right right right right right}]
    return $html
}

proc _ns_stats.requestCounts {} {
    set snapshot [_ns_stats.runtimeSnapshot]
    set total 0
    set servers {}
    if {$snapshot ne ""} {
        dict for {server data} [dict get $snapshot servers] {
            set count 0
            dict for {pool entry} [dict get $data pools] {
                incr count [dict get $entry counters requests]
            }
            dict set servers $server $count
            incr total $count
        }
        set timestamp [dict get $snapshot timestamp]
    } else {
        foreach server [ns_info servers] {
            set count 0
            foreach pool [ns_server -server $server pools] {
                incr count [dict get [ns_server -server $server -pool $pool stats] requests]
            }
            dict set servers $server $count
            incr total $count
        }
        set timestamp [clock microseconds]
    }
    return [dict create timestamp $timestamp total $total servers $servers coreSnapshot $snapshot]
}

proc _ns_stats.requestRates {sampleKey} {
    set counts       [_ns_stats.requestCounts]
    set total        [dict get $counts total]
    set serverCounts [dict get $counts servers]
    set linuxNetwork [_ns_stats.linuxNetworkSnapshot]
    set now          [dict get $counts timestamp]

    set snapshot [dict get $counts coreSnapshot]
    if {[_ns_stats.sampled $snapshot]} {
        set rates {}
        dict for {server data} [dict get $snapshot servers] {
            set totalRate 0.0
            dict for {pool entry} [dict get $data pools] {
                set value [_ns_stats.dictGetDef $entry rates requests {}]
                if {$value eq ""} {set totalRate -1.0; break}
                set totalRate [expr {$totalRate+$value}]
            }
            dict set rates $server $totalRate
        }
        return [dict create available 1 elapsed [dict get $snapshot sampling elapsedSeconds] \
            total [_ns_stats.utilization.sampleTotal $snapshot rates requests] servers $rates \
            linuxNetwork $linuxNetwork previousLinuxNetwork {}]
    }

    set sample [dict create \
                    timestamp    $now \
                    total        $total \
                    servers      $serverCounts \
                    linuxNetwork $linuxNetwork \
                   ]

    set previousSample \
        [nsv_set -reset _ns_stats $sampleKey $sample]

    set result [dict create \
                    available            0 \
                    elapsed              -1.0 \
                    total                -1.0 \
                    servers              {} \
                    linuxNetwork         $linuxNetwork \
                    previousLinuxNetwork {}]

    if {[dict exists $previousSample linuxNetwork]} {
        dict set result previousLinuxNetwork \
            [dict get $previousSample linuxNetwork]
    }

    if {![dict exists $previousSample timestamp]} {
        return $result
    }

    set previousTimestamp \
        [dict get $previousSample timestamp]

    set elapsed [expr {($now - $previousTimestamp) / 1000000.0}]

    if {$elapsed <= 0.0} {
        return $result
    }

    set previousTotal [_ns_stats.dictGetDef $previousSample total -1]
    set totalRate     [_ns_stats.intervalRate $total $previousTotal $elapsed]

    set serverRates  {}
    foreach server [dict keys $serverCounts] {
        set rate -1.0

        if {[dict exists $previousSample servers $server]} {
            set rate \
                [_ns_stats.intervalRate \
                     [dict get $serverCounts $server] \
                     [dict get $previousSample servers $server] \
                     $elapsed]
        }

        dict set serverRates $server $rate
    }

    dict set result available 1
    dict set result elapsed   $elapsed
    dict set result total     $totalRate
    dict set result servers   $serverRates

    return $result
}

proc _ns_stats.totalRequests {} {
    set totalRequests [dict get [_ns_stats.requestCounts] total]
    if {$totalRequests == 0} {
        # avoid division by 0
        incr totalRequests
    }
    return $totalRequests
}


proc _ns_stats.utilizationSample {} {
    set drivers {}
    set queues  {}
    set servers {}

    set snapshot [_ns_stats.runtimeSnapshot]
    set collector legacy
    if {$snapshot ne ""} {
        set collector [expr {[_ns_stats.sampled $snapshot] ? "ns_stats-sample" : "ns_stats"}]
        dict for {thread entry} [dict get $snapshot drivers] {
            set stats [dict merge [dict get $entry counters] \
                [dict create thread $thread module [dict get $entry module]]]
            foreach {source target} {reading reading waitingForConnection waiting closing closing} {
                dict set stats $target [dict get $entry socketStates $source]
            }
            dict set drivers $thread $stats
        }
        dict for {server data} [dict get $snapshot servers] {
            dict for {pool entry} [dict get $data pools] {
                set gauges [dict get $entry gauges]
                dict set servers $server pools $pool [dict create \
                    stats [dict get $entry counters] threads [dict get $gauges threads] \
                    waiting [dict get $gauges waitingRequests] active [dict get $gauges activeRequests]]
            }
        }
    } else {
        foreach stats [ns_driver stats] {
            dict set drivers [dict get $stats thread] $stats
        }
    }

    # Queue diagnostics are not currently exposed by ns_stats.
    foreach kind {driver writer spooler} {
        if {![catch {ns_driver queues $kind} entries]} {
            foreach entry $entries {
                dict set queues $kind [dict get $entry thread] $entry
            }
        }
    }

    if {$snapshot eq ""} {
        foreach server [ns_info servers] {
            foreach pool [ns_server -server $server pools] {
                set stats   [ns_server -server $server -pool $pool stats]
                set threads [ns_server -server $server -pool $pool threads]

                dict set servers $server pools $pool \
                    [dict create \
                         stats   $stats \
                         threads $threads \
                         waiting [ns_server -server $server -pool $pool waiting] \
                         active  [llength \
                                      [ns_server -server $server \
                                           -pool $pool all]]]
            }
        }
    }

    set linuxNetwork [_ns_stats.linuxNetworkSnapshot]
    set now          [expr {$snapshot eq "" ? [clock microseconds] : [dict get $snapshot timestamp]}]

    set sample [dict create \
                    timestamp    $now \
                    collector    $collector \
                    drivers      $drivers \
                    queues       $queues \
                    servers      $servers \
                    linuxNetwork $linuxNetwork \
                    supplementalTimestamp [clock microseconds]]
    set previous \
        [nsv_set -reset _ns_stats utilizationSample $sample]

    # Do not compare differently shaped pool keys when the collector changes.
    if {$previous ne "" && [_ns_stats.dictGetDef $previous collector legacy] ne $collector} {
        set previous {}
    }

    #
    # The stored sample may predate the linuxNetwork addition.
    #
    if {![dict exists $previous linuxNetwork]} {
        dict set previous linuxNetwork {}
    }

    set elapsed 0.0
    if {[dict exists $previous timestamp]} {
        set elapsed [expr {($now - [dict get $previous timestamp]) / 1000000.0}]
    }

    set supplementalElapsed 0.0
    if {[dict exists $previous supplementalTimestamp]} {
        set supplementalElapsed [expr {([dict get $sample supplementalTimestamp]-[dict get $previous supplementalTimestamp])/1000000.0}]
    }
    set supplementalPrevious $previous
    if {[_ns_stats.sampled $snapshot]} {
        set previous [_ns_stats.utilization.samplePrevious $sample $snapshot]
        set elapsed [dict get $snapshot sampling elapsedSeconds]
    }

    return [dict create \
                current  $sample \
                previous $previous \
                elapsed  $elapsed \
                coreSnapshot $snapshot \
                supplementalPrevious $supplementalPrevious \
                supplementalElapsed $supplementalElapsed]
}

#
# Return the non-negative difference between two cumulative counters.
# A negative result indicates a counter reset and is reported as -1.
#
proc _ns_stats.intervalDelta {current previous} {
    return [expr {
        $current >= $previous
        ? $current - $previous
        : -1.0
    }]
}

#
# Return the change per second between two cumulative counter samples.
#
proc _ns_stats.intervalRate {current previous elapsed} {
    if {$elapsed <= 0.0} {
        return -1.0
    }

    set delta [_ns_stats.intervalDelta $current $previous]

    return [expr {
        $delta >= 0.0
        ? $delta / $elapsed
        : -1.0
    }]
}

proc _ns_stats.utilization.colorize {severity value {bold 0}} {
    switch $severity {
        critical { set color red }
        warning  { set color orange }
        default  { return $value }
    }

    if {$bold} {
        set value "<b>$value</b>"
    }

    return "<font color='$color'>$value</font>"
}

proc _ns_stats.dictGetDef {dictionary args} {
    set default [lindex $args end]
    set path    [lrange $args 0 end-1]

    if {[dict exists $dictionary {*}$path]} {
        return [dict get $dictionary {*}$path]
    }
    return $default
}


proc _ns_stats.utilization.sumPoolCounter {sample counter} {
    set total 0

    if {![dict exists $sample servers]} {
        return $total
    }

    dict for {server serverData} [dict get $sample servers] {
        dict for {pool poolData} [dict get $serverData pools] {
            set total [expr {$total + [_ns_stats.dictGetDef $poolData stats $counter 0]}]
        }
    }

    return $total
}

proc _ns_stats.utilization.sumDriverCounter {sample counter} {
    set total 0
    if {![dict exists $sample drivers]} {
        return $total
    }
    dict for {driver stats} [dict get $sample drivers] {
        incr total [_ns_stats.dictGetDef $stats $counter 0]
    }
    return $total
}



proc _ns_stats.utilization.displayRate {rate {suffix /s}} {
    if {$rate < 0.0} {
        return "\u2014"
    } elseif {$rate < 0.1} {
        return "[format %.3f $rate]$suffix"
    } elseif {$rate < 10.0} {
        return "[format %.2f $rate]$suffix"
    } elseif {$rate < 100.0} {
        return "[format %.1f $rate]$suffix"
    } else {
        return "[format %.0f $rate]$suffix"
    }
}

proc _ns_stats.utilization.formatWorker {count measured cpu} {
    if {$count == 0} {
        return "\u2014"
    }
    set cpuDisplay [expr { $measured > 0 ? "[format %.1f $cpu]%" : "\u2014"}]
    return "<span class='nowrap'>$count / $cpuDisplay</span>"
}

#
# Read a file, returning an empty string when it is unavailable.
#
proc _ns_stats.linuxReadFile {path} {
    set content ""
    if {[file readable $path]} {
        try {
            set f [open $path r]
            set content [read $f]
        } on error {errorMsg} {
            # ignore errors
        } finally {
            close $f
        }
    }
    return $content
}
#
# Parse files such as /proc/net/snmp and /proc/net/netstat. These
# contain pairs of lines, with names in the first line and values in
# the second line.
#
proc _ns_stats.linuxReadNamedCounters {path} {
    set content [_ns_stats.linuxReadFile $path]
    set result  {}

    if {$content eq ""} {
        return $result
    }

    set lines [split [string trim $content] \n]
    set count [llength $lines]

    for {set i 0} {$i + 1 < $count} {incr i} {
        set nameFields  [regexp -all -inline {\S+} [lindex $lines $i]]
        set valueFields [regexp -all -inline {\S+} [lindex $lines [expr {$i + 1}]]]

        if {[llength $nameFields] < 2
            || [llength $valueFields] < 2} {
            continue
        }

        set nameSection  [string trimright [lindex $nameFields 0] :]
        set valueSection [string trimright [lindex $valueFields 0] :]

        if {$nameSection ne $valueSection
            || [llength $nameFields] != [llength $valueFields]} {
            continue
        }

        foreach name [lrange $nameFields 1 end] value [lrange $valueFields 1 end] {
            if {[string is integer -strict $value]} {
                dict set result $nameSection $name $value
            }
        }

        incr i
    }

    return $result
}
#
# Parse /proc/net/snmp6. Unlike /proc/net/snmp, this file has one
# name/value pair per line.
#
proc _ns_stats.linuxReadSnmp6 {} {
    set content [_ns_stats.linuxReadFile /proc/net/snmp6]
    set result  {}

    foreach line [split [string trim $content] \n] {
        set fields [regexp -all -inline {\S+} $line]

        if {[llength $fields] == 2
            && [string is integer -strict [lindex $fields 1]]} {
            dict set result [lindex $fields 0] [lindex $fields 1]
        }
    }

    return $result
}

#
# Return aggregate counters from all non-loopback network interfaces.
#
proc _ns_stats.linuxReadDeviceCounters {} {
    set content [_ns_stats.linuxReadFile /proc/net/dev]
    set result  {}

    if {$content eq ""} {
        return $result
    }

    set rxDrops  0
    set txDrops  0
    set rxErrors 0
    set txErrors 0
    set found    0

    foreach line [split $content \n] {
        if {![regexp {^\s*([^:]+):\s*(.*)$} $line _ interface values]} {
            continue
        }

        set interface [string trim $interface]
        if {$interface eq "lo"} {
            continue
        }

        set fields [regexp -all -inline {\S+} $values]

        #
        # /proc/net/dev fields:
        #
        # RX: bytes packets errors dropped fifo frame compressed multicast
        # TX: bytes packets errors dropped fifo colls carrier compressed
        #
        if {[llength $fields] < 16} {
            continue
        }

        incr rxErrors [lindex $fields 2]
        incr rxDrops  [lindex $fields 3]
        incr txErrors [lindex $fields 10]
        incr txDrops  [lindex $fields 11]
        set found 1
    }

    if {$found} {
        set result [dict create \
                        interfaceRxDrops  $rxDrops \
                        interfaceTxDrops  $txDrops \
                        interfaceRxErrors $rxErrors \
                        interfaceTxErrors $txErrors]
    }

    return $result
}

#
# Return the inode numbers of sockets owned by the NaviServer process.
#
proc _ns_stats.linuxProcessSocketInodes {} {
    set result {}

    foreach fd [glob -nocomplain /proc/self/fd/*] {
        if {[catch {file readlink $fd} target]} {
            continue
        }

        if {[regexp {^socket:\[([0-9]+)\]$} $target _ inode]} {
            dict set result $inode 1
        }
    }

    return $result
}

#
# Return aggregate kernel queues for sockets owned by NaviServer.
#
# For TCP listeners, rx_queue is an accept-queue count. For connected
# TCP and UDP sockets, tx_queue and rx_queue describe queued data.
#
proc _ns_stats.linuxReadSocketQueues {} {
    set socketInodes [_ns_stats.linuxProcessSocketInodes]

    if {[dict size $socketInodes] == 0} {
        return {}
    }

    set result [dict create \
                    tcpListenQueued     0 \
                    tcpListenMax        0 \
                    tcpListeners        0 \
                    tcpReceiveBytes     0 \
                    tcpReceiveMax       0 \
                    tcpSendBytes        0 \
                    tcpSendMax          0 \
                    udpReceiveBytes     0 \
                    udpReceiveMax       0 \
                    udpSendBytes        0 \
                    udpSendMax          0 \
                    udpSocketDrops      0 \
                    udpSocketsWithDrops 0 \
                    udpSocketDropMax    0
               ]

    set tablesRead 0

    foreach protocol {tcp udp} {
        foreach path [list \
                          /proc/self/net/$protocol \
                          /proc/self/net/${protocol}6] {
            set content [_ns_stats.linuxReadFile $path]

            if {$content eq ""} {
                continue
            }
            incr tablesRead

            foreach line [lrange [split [string trim $content] \n] 1 end] {
                set fields [regexp -all -inline {\S+} $line]

                #
                # Relevant fields:
                #
                #  3: socket state
                #  4: tx_queue:rx_queue
                #  9: socket inode
                #
                if {[llength $fields] < 10} {
                    continue
                }

                set inode [lindex $fields 9]

                if {![dict exists $socketInodes $inode]} {
                    continue
                }

                set state      [lindex $fields 3]
                set queueField [lindex $fields 4]

                if {[scan $queueField %x:%x txQueue rxQueue] != 2} {
                    continue
                }

                if {$protocol eq "tcp" && $state eq "0A"} {
                    dict incr result tcpListeners
                    dict incr result tcpListenQueued $rxQueue

                    if {$rxQueue > [dict get $result tcpListenMax]} {
                        dict set result tcpListenMax $rxQueue
                    }

                } elseif {$protocol eq "tcp"} {
                    dict incr result tcpReceiveBytes $rxQueue
                    dict incr result tcpSendBytes    $txQueue

                    if {$rxQueue > [dict get $result tcpReceiveMax]} {
                        dict set result tcpReceiveMax $rxQueue
                    }
                    if {$txQueue > [dict get $result tcpSendMax]} {
                        dict set result tcpSendMax $txQueue
                    }

                } else {
                    dict incr result udpReceiveBytes $rxQueue
                    dict incr result udpSendBytes    $txQueue

                    if {$rxQueue > [dict get $result udpReceiveMax]} {
                        dict set result udpReceiveMax $rxQueue
                    }
                    if {$txQueue > [dict get $result udpSendMax]} {
                        dict set result udpSendMax $txQueue
                    }

                    #
                    # Linux exposes the cumulative socket drop counter
                    # as the final field in /proc/net/udp{,6}.
                    #
                    set drops [lindex $fields end]
                    if {[string is integer -strict $drops]} {
                        dict incr result udpSocketDrops $drops

                        if {$drops > 0} {
                            dict incr result udpSocketsWithDrops
                        }
                        if {$drops > [dict get $result udpSocketDropMax]} {
                            dict set result udpSocketDropMax $drops
                        }
                    }
                }
            }
        }
    }

    return [expr {$tablesRead > 0 ? $result : {}}]
}

proc _ns_stats.linuxNetworkSnapshot {} {

    if {![string match -nocase *linux*$::tcl_platform(platform)]} {
        return {}
    }

    set snmp    [_ns_stats.linuxReadNamedCounters /proc/net/snmp]
    set netstat [_ns_stats.linuxReadNamedCounters /proc/net/netstat]
    set snmp6   [_ns_stats.linuxReadSnmp6]
    set devices [_ns_stats.linuxReadDeviceCounters]
    set queues  [_ns_stats.linuxReadSocketQueues]

    set counters {}

    foreach {target source section name} {
        tcpListenOverflows netstat TcpExt ListenOverflows
        tcpListenDrops     netstat TcpExt ListenDrops
        tcpBacklogDrops    netstat TcpExt TCPBacklogDrop
        tcpReceiveDrops    netstat TcpExt TCPRcvQDrop
        tcpRetransmits     snmp    Tcp    RetransSegs
        tcpInputErrors     snmp    Tcp    InErrs
        udpReceiveDrops4   snmp    Udp    RcvbufErrors
        udpSendDrops4      snmp    Udp    SndbufErrors
        udpInputErrors4    snmp    Udp    InErrors
    } {
        set data [set $source]

        if {[dict exists $data $section $name]} {
            dict set counters $target [dict get $data $section $name]
        }
    }

    foreach {target name} {
        udpReceiveDrops6 Udp6RcvbufErrors
        udpSendDrops6    Udp6SndbufErrors
        udpInputErrors6  Udp6InErrors
    } {
        if {[dict exists $snmp6 $name]} {
            dict set counters $target [dict get $snmp6 $name]
        }
    }

    #
    # Provide combined IPv4/IPv6 UDP counters for the summary.
    #
    foreach {combined ipv4 ipv6} {
        udpReceiveDrops udpReceiveDrops4 udpReceiveDrops6
        udpSendDrops    udpSendDrops4    udpSendDrops6
        udpInputErrors  udpInputErrors4  udpInputErrors6
    } {
        set found 0
        set total 0

        foreach name [list $ipv4 $ipv6] {
            if {[dict exists $counters $name]} {
                incr total [dict get $counters $name]
                set found 1
            }
        }

        if {$found} {
            dict set counters $combined $total
        }
    }

    dict for {name value} $devices {
        dict set counters $name $value
    }

    if {[dict size $counters] == 0
        && [dict size $queues] == 0} {
        return {}
    }

    if {[dict exists $queues udpSocketDrops]} {
        dict set counters udpSocketDrops [dict get $queues udpSocketDrops]
        dict unset queues udpSocketDrops
    }

    return [dict create \
                counters $counters \
                gauges   $queues]
}

proc _ns_stats.utilization.tooltip {text tooltip} {
    return [format {<span title="%s">%s</span>} [ns_quotehtml $tooltip] [ns_quotehtml $text]]
}

proc _ns_stats.utilization.displayIntervalCounter {delta rate label} {
    if {$delta < 0} {
        return "\u2014"
    }

    set noun [expr {$delta == 1 ? $label : "${label}s"}]

    if {$delta == 0} {
        return "0 $noun"
    }

    if {$rate >= 0.0} {
        set rateDisplay [expr {$rate > 0.0 && $rate < 0.001
                              ? "<0.001/s"
                              : [_ns_stats.utilization.displayRate $rate]}]
        return "$delta $noun in interval ($rateDisplay)"
    }

    return "$delta $noun in interval"
}

proc _ns_stats.utilization.linuxRows {current previous elapsed severityVar reasonsVar} {
    upvar 1 $severityVar severity
    upvar 1 $reasonsVar  reasons

    set linuxRows {}
    set linuxNetwork [_ns_stats.dictGetDef $current linuxNetwork {}]

    if {[dict size $linuxNetwork] > 0} {
        set previousLinuxNetwork [_ns_stats.dictGetDef $previous linuxNetwork {}]

        set currentCounters  [_ns_stats.dictGetDef $linuxNetwork counters {}]
        set previousCounters [_ns_stats.dictGetDef $previousLinuxNetwork counters {}]
        set gauges           [_ns_stats.dictGetDef $linuxNetwork gauges {}]

        foreach {counter deltaVariable rateVariable} {
            tcpListenOverflows tcpListenOverflowsDelta tcpListenOverflowsRate
            tcpListenDrops     tcpListenDropsDelta     tcpListenDropsRate
            tcpBacklogDrops    tcpBacklogDropsDelta    tcpBacklogDropsRate
            tcpReceiveDrops    tcpReceiveDropsDelta    tcpReceiveDropsRate
            udpReceiveDrops    udpReceiveDropsDelta    udpReceiveDropsRate
            udpSocketDrops     udpSocketDropsDelta     udpSocketDropsRate
            udpSendDrops       udpSendDropsDelta       udpSendDropsRate
            interfaceRxDrops   interfaceRxDropsDelta   interfaceRxDropsRate
            interfaceTxDrops   interfaceTxDropsDelta   interfaceTxDropsRate
            interfaceRxErrors  interfaceRxErrorsDelta  interfaceRxErrorsRate
            interfaceTxErrors  interfaceTxErrorsDelta  interfaceTxErrorsRate
        } {
            set $deltaVariable -1
            set $rateVariable  -1.0

            if {[dict exists $currentCounters $counter]
                && [dict exists $previousCounters $counter]} {

                set currentValue  [dict get $currentCounters $counter]
                set previousValue [dict get $previousCounters $counter]
                set delta         [_ns_stats.intervalDelta $currentValue $previousValue]

                set $deltaVariable $delta

                if {$delta >= 0 && $elapsed > 0.0} {
                    set $rateVariable [expr {$delta / $elapsed}]
                }
            }
        }

        #
        # TCP kernel state.
        #
        set tcpAlerts  {}
        set tcpDetails {}

        foreach {delta rate label tooltip alert} \
            [list \
                 $tcpListenDropsDelta \
                 $tcpListenDropsRate \
                 "listen drop" \
                 "TCP packets discarded while being processed by listening sockets. Interpret this counter together with listen overflows, request-queue drops, queue occupancy, and memory-pressure indicators." \
                 false \
                 \
                 $tcpListenOverflowsDelta \
                 $tcpListenOverflowsRate \
                 "listen overflow" \
                 "Connections discarded because a TCP accept queue was full. Check the NaviServer driver backlog and net.core.somaxconn." \
                 true \
                 \
                 $tcpBacklogDropsDelta \
                 $tcpBacklogDropsRate \
                 "backlog drop" \
                 "TCP packets discarded from an established socket's processing backlog." \
                 true \
                 \
                 $tcpReceiveDropsDelta \
                 $tcpReceiveDropsRate \
                 "receive-queue drop" \
                 "TCP packets discarded because receive-queue resources were unavailable." \
                 true \
                ] \
            {

                set text [_ns_stats.utilization.displayIntervalCounter $delta $rate $label]
                set display [_ns_stats.utilization.tooltip $text $tooltip]

                if {$delta > 0 && $alert} {
                    lappend tcpAlerts [_ns_stats.utilization.colorize warning $display 1]
                } elseif {$delta >= 0} {
                    lappend tcpDetails $display
                }
            }

        if {[dict size $gauges] > 0} {
            set listeners          [_ns_stats.dictGetDef $gauges tcpListeners 0]
            set listenQueued       [_ns_stats.dictGetDef $gauges tcpListenQueued 0]
            set largestListenQueue [_ns_stats.dictGetDef $gauges tcpListenMax 0]
            set tcpReceiveBytes    [_ns_stats.dictGetDef $gauges tcpReceiveBytes 0]
            set tcpSendBytes       [_ns_stats.dictGetDef $gauges tcpSendBytes 0]
            set tcpRxDisplay [_ns_stats.utilization.tooltip \
                                  "RX [_ns_stats.hr $tcpReceiveBytes]B" \
                                  "Total unread TCP payload currently queued for NaviServer across all open non-listening TCP sockets. This is queue occupancy, not kernel memory usage or configured capacity."]
            set tcpTxDisplay [_ns_stats.utilization.tooltip \
                                  "TX [_ns_stats.hr $tcpSendBytes]B" \
                                  "Total TCP payload currently queued or awaiting acknowledgment across all open non-listening TCP sockets owned by NaviServer. This is queue occupancy, not kernel memory usage or configured capacity."]

            lappend tcpDetails \
                "$listenQueued queued across $listeners listeners, busiest accept queue $largestListenQueue" \
                "data queues $tcpRxDisplay, $tcpTxDisplay"
        }

        set tcpSeverity [expr {[llength $tcpAlerts] > 0 ? "warning" : "ok"}]
        set tcpLabel    [_ns_stats.utilization.colorize $tcpSeverity "Linux TCP"]
        set tcpDisplay  [join [concat $tcpAlerts $tcpDetails] {; }]

        foreach {delta rate label} [list \
                                        $tcpListenOverflowsDelta $tcpListenOverflowsRate "TCP listen overflow" \
                                        $tcpBacklogDropsDelta    $tcpBacklogDropsRate    "TCP backlog drop" \
                                        $tcpReceiveDropsDelta    $tcpReceiveDropsRate    "TCP receive-queue drop"] {
            if {$delta > 0} {
                lappend reasons [_ns_stats.utilization.displayIntervalCounter $delta $rate $label]
                if {$severity eq "ok"} {
                    set severity warning
                }
            }
        }

        #
        # UDP kernel state.
        #
        set udpAlerts  {}
        set udpQueues  {}
        set udpDetails {}
        set udpSocketsWithDrops 0
        set udpSocketDropMax    0

        if {[dict size $gauges] > 0} {
            set udpReceiveBytes [_ns_stats.dictGetDef $gauges udpReceiveBytes 0]
            set udpReceiveMax   [_ns_stats.dictGetDef $gauges udpReceiveMax 0]
            set udpSendBytes    [_ns_stats.dictGetDef $gauges udpSendBytes 0]
            set udpSendMax      [_ns_stats.dictGetDef $gauges udpSendMax 0]
            set udpSocketsWithDrops [_ns_stats.dictGetDef $gauges udpSocketsWithDrops 0]
            set udpSocketDropMax    [_ns_stats.dictGetDef $gauges udpSocketDropMax 0]

            lappend udpQueues \
                "RX queue [_ns_stats.hr $udpReceiveBytes]B total, [_ns_stats.hr $udpReceiveMax]B largest" \
                "TX queue [_ns_stats.hr $udpSendBytes]B total, [_ns_stats.hr $udpSendMax]B largest"
        }

       #
        # Namespace-wide receive-buffer drops, supplemented with the
        # subset attributable to UDP sockets owned by NaviServer.
        #
        set receiveText [_ns_stats.utilization.displayIntervalCounter $udpReceiveDropsDelta $udpReceiveDropsRate "receive-buffer drop"]
        if {($udpReceiveDropsDelta > 0 || $udpSocketDropsDelta > 0)
            && $udpSocketDropsDelta >= 0
        } {
            append receiveText " ($udpSocketDropsDelta on NaviServer sockets"

            if {$udpSocketsWithDrops > 0} {
                append receiveText "; $udpSocketsWithDrops " \
                    [expr {$udpSocketsWithDrops == 1
                           ? "socket with prior drops"
                           : "sockets with prior drops"}] \
                    ", largest cumulative $udpSocketDropMax"
            }

            append receiveText ")"
        }

        set sendText [_ns_stats.utilization.displayIntervalCounter $udpSendDropsDelta $udpSendDropsRate "send-buffer drop"]
        foreach {rate text} [list \
                                 $udpReceiveDropsRate $receiveText \
                                 $udpSendDropsRate    $sendText] {
            if {$rate > 0.0} {
                lappend udpAlerts [_ns_stats.utilization.colorize warning $text 1]
            } elseif {$rate >= 0.0} {
                lappend udpDetails $text
            }
        }

        set udpSeverity [expr {[llength $udpAlerts] > 0 ? "warning" : "ok"}]
        set udpLabel    [_ns_stats.utilization.colorize $udpSeverity "Linux UDP"]
        set udpDisplay  [join [concat $udpAlerts $udpQueues $udpDetails] {; }]

        #
        # Add precise UDP and interface problems to the global status.
        #
        foreach {delta rate label} [list \
                                        $udpReceiveDropsDelta  $udpReceiveDropsRate  "UDP receive-buffer drop" \
                                        $udpSendDropsDelta     $udpSendDropsRate     "UDP send-buffer drop" \
                                        $interfaceRxDropsDelta $interfaceRxDropsRate "interface RX drop" \
                                        $interfaceTxDropsDelta $interfaceTxDropsRate "interface TX drop" \
                                        $interfaceRxErrorsDelta $interfaceRxErrorsRate "interface RX error" \
                                        $interfaceTxErrorsDelta $interfaceTxErrorsRate "interface TX error"] {

            if {$delta > 0} {
                lappend reasons [_ns_stats.utilization.displayIntervalCounter $delta $rate $label]
                if {$severity eq "ok"} {
                    set severity warning
                }
            }
        }

        #
        # Network-interface counters.
        #
        set interfaceParts {}
        foreach {delta rate label} [list \
                                        $interfaceRxDropsDelta  $interfaceRxDropsRate  "RX drop" \
                                        $interfaceTxDropsDelta  $interfaceTxDropsRate  "TX drop" \
                                        $interfaceRxErrorsDelta $interfaceRxErrorsRate "RX error" \
                                        $interfaceTxErrorsDelta $interfaceTxErrorsRate "TX error"] {
            if {$delta >= 0} {
                set display [_ns_stats.utilization.displayIntervalCounter $delta $rate $label]
                if {$delta > 0} {
                    set display [_ns_stats.utilization.colorize warning $display 1]
                }
                lappend interfaceParts $display
            }
        }

        set interfaceSeverity [expr {
                                     $interfaceRxDropsDelta > 0
                                     || $interfaceTxDropsDelta > 0
                                     || $interfaceRxErrorsDelta > 0
                                     || $interfaceTxErrorsDelta > 0
                                     ? "warning"
                                     : "ok"
                                 }]
        set linuxTitle \
            "Linux kernel statistics visible to the NaviServer process; inside a container, these describe the container's network stack"
        set interfaceTitle \
            "Aggregate counters for non-loopback Linux interfaces visible to the NaviServer process"

        lappend linuxRows \
            [list "<span title='$linuxTitle'>$tcpLabel</span>" $tcpDisplay] \
            [list "<span title='$linuxTitle'>$udpLabel</span>" $udpDisplay] \
            [list "<span title='$interfaceTitle'>Linux Interfaces</span>" [_ns_stats.utilization.colorize $interfaceSeverity [join $interfaceParts {; }]]]
    }
    return $linuxRows
}


proc _ns_stats.utilization.globalSummary {sample threadCpu} {
    set current  [dict get $sample current]
    set previous [dict get $sample previous]
    set elapsed  [dict get $sample elapsed]

    #
    # Current pool/thread gauges.
    #
    set activeRequests       0
    set poolWaiting          0
    set connThreadsCurrent   0
    set connThreadsIdle      0
    set connThreadsStopping  0
    set connThreadsMax       0

    dict for {server serverData} [dict get $current servers] {
        dict for {pool poolData} [dict get $serverData pools] {
            incr activeRequests      [dict get $poolData active]
            incr poolWaiting         [_ns_stats.dictGetDef $poolData waiting 0]
            set threads              [_ns_stats.dictGetDef $poolData threads {}]
            incr connThreadsCurrent  [_ns_stats.dictGetDef $threads current 0]
            incr connThreadsIdle     [_ns_stats.dictGetDef $threads idle 0]
            incr connThreadsStopping [_ns_stats.dictGetDef $threads stopping 0]
            incr connThreadsMax      [_ns_stats.dictGetDef $threads max 0]
        }
    }

    set connThreadsBusy [expr {
        max(0, $connThreadsCurrent
               - $connThreadsIdle
               - $connThreadsStopping)
    }]

    set connThreadUtilization [expr {
        $connThreadsCurrent > 0
        ? 100.0 * $connThreadsBusy / $connThreadsCurrent
        : 0.0
    }]

    #
    # Current driver-local socket gauges.
    #
    set driverWaiting [_ns_stats.utilization.sumDriverCounter $current waiting]
    set driverReading [_ns_stats.utilization.sumDriverCounter $current reading]
    set driverClosing [_ns_stats.utilization.sumDriverCounter $current closing]

    #
    # Interval pool counters.
    #
    set currentRequests  [_ns_stats.utilization.sumPoolCounter $current requests]
    set previousRequests [_ns_stats.utilization.sumPoolCounter $previous requests]

    set currentQueued    [_ns_stats.utilization.sumPoolCounter $current queued]
    set previousQueued   [_ns_stats.utilization.sumPoolCounter $previous queued]

    set currentSpooled   [_ns_stats.utilization.sumPoolCounter $current spools]
    set previousSpooled  [_ns_stats.utilization.sumPoolCounter $previous spools]

    set currentDropped   [_ns_stats.utilization.sumPoolCounter $current dropped]
    set previousDropped  [_ns_stats.utilization.sumPoolCounter $previous dropped]

    set requestRate      [_ns_stats.intervalRate $currentRequests $previousRequests $elapsed]
    set queuedRate       [_ns_stats.intervalRate $currentQueued $previousQueued $elapsed]
    set spooledRate      [_ns_stats.intervalRate $currentSpooled $previousSpooled $elapsed]
    set droppedRate      [_ns_stats.intervalRate $currentDropped $previousDropped $elapsed]
    set droppedDelta     [_ns_stats.intervalDelta $currentDropped $previousDropped]
    set droppedText      [_ns_stats.utilization.displayIntervalCounter $droppedDelta $droppedRate "dropped request"]

    #
    # Interval-average request timing.
    #
    set requestDelta [expr {$currentRequests - $previousRequests}]
    set timingValues {}

    foreach {counter label} {
        queuetime  queue
        filtertime filter
        runtime    run
        tracetime  trace
    } {
        set currentTime  [_ns_stats.utilization.sumPoolCounter $current $counter]
        set previousTime [_ns_stats.utilization.sumPoolCounter $previous $counter]

        if {$requestDelta > 0 && $currentTime >= $previousTime} {
            set average [expr {
                ($currentTime - $previousTime) / double($requestDelta)
            }]
            lappend timingValues "$label [_ns_stats.hr $average]s"
        }
    }

    set snapshot [_ns_stats.dictGetDef $sample coreSnapshot {}]
    if {[_ns_stats.sampled $snapshot]} {
        set requestRate [_ns_stats.utilization.sampleTotal $snapshot rates requests]
        set queuedRate [_ns_stats.utilization.sampleTotal $snapshot rates queued]
        set spooledRate [_ns_stats.utilization.sampleTotal $snapshot rates spools]
        set droppedRate [_ns_stats.utilization.sampleTotal $snapshot rates dropped]
        set droppedDelta [_ns_stats.utilization.sampleTotal $snapshot deltas dropped]
        set droppedText [_ns_stats.utilization.displayIntervalCounter $droppedDelta $droppedRate "dropped request"]
        set requests [_ns_stats.utilization.sampleTotal $snapshot deltas requests]
        set timingValues {}
        foreach {key label} {queuetime queue filtertime filter runtime run tracetime trace} {
            set delta [_ns_stats.utilization.sampleTotal $snapshot deltas $key]
            if {$requests>0 && $delta>=0} {
                lappend timingValues "$label [_ns_stats.hr [expr {$delta/$requests}]]s"
            }
        }
    }

    #
    # CPU percentages. The helper should return dictionaries containing
    # at least "name" and "cpu".
    #
    set driverCpuTotal 0.0
    set driverCpuMax   0.0
    set connCpuTotal   0.0
    set writerCpuTotal 0.0
    set spoolerCpuTotal 0.0

    set measured {}

    dict for {threadKey threadData} $threadCpu {
        set name [_ns_stats.dictGetDef $threadData name ""]
        set cpu  [_ns_stats.dictGetDef $threadData cpu  -1.0]

        if {$cpu < 0.0} {
            continue
        }

        switch -glob -- $name {
            "-driver:*" {
                dict set measured driver true
                set driverCpuTotal [expr {$driverCpuTotal + $cpu}]
                set driverCpuMax   [expr {max($driverCpuMax, $cpu)}]
            }
            "-conn:*" {
                dict set measured conn true
                set connCpuTotal [expr {$connCpuTotal + $cpu}]
            }
            "-writer:*" {
                dict set measured writer true
                set writerCpuTotal [expr {$writerCpuTotal + $cpu}]
            }
            "-spooler:*" {
                dict set measured spooler true
                set spoolerCpuTotal [expr {$spoolerCpuTotal + $cpu}]
            }
        }
    }

    #
    # Determine the most important current warning.
    #
    set severity ok
    set reasons  {}

    set linuxRows [_ns_stats.utilization.linuxRows \
                       $current [_ns_stats.dictGetDef $sample supplementalPrevious $previous] \
                       [_ns_stats.dictGetDef $sample supplementalElapsed $elapsed] severity reasons]

    if {$droppedRate > 0.0} {
        set severity critical
        lappend reasons \
            $droppedText
    }

    if {$driverCpuMax >= 90.0} {
        if {$severity eq "ok"} {
            set severity warning
        }
        lappend reasons \
            "driver thread at [format %.1f $driverCpuMax]%"
    }

    if {$driverWaiting > 0} {
        if {$severity eq "ok"} {
            set severity warning
        }
        lappend reasons "$driverWaiting ready requests awaiting processing"
    }

    if {$poolWaiting > 0} {
        if {$severity eq "ok"} {
            set severity warning
        }
        set poolWaitingDisplay [_ns_stats.utilization.colorize "warning" $poolWaiting]
        lappend reasons "$poolWaiting requests waiting for connection threads"
    } else {
        set poolWaitingDisplay $poolWaiting
    }

    if {$connThreadsCurrent > 0
        && $connThreadsBusy == $connThreadsCurrent
        && $connThreadsCurrent >= $connThreadsMax} {
        if {$severity eq "ok"} {
            set severity warning
        }
        lappend reasons "all configured connection threads busy"
    }
    set connectionThreadSeverity [expr {$poolWaiting > 0 && $connThreadsCurrent >= $connThreadsMax && $connThreadsIdle == 0 ? "warning" : "ok"}]
    set connectionThreadsDisplay [_ns_stats.utilization.colorize $connectionThreadSeverity \
                                      "$connThreadsBusy busy, $connThreadsIdle idle, $connThreadsCurrent current, $connThreadsMax maximum ([format %.1f $connThreadUtilization]% busy)"]

    set driverCpuSeverity [_ns_stats.categorize {{90.0 critical} {75.0 warning} {0.0 ok}} $driverCpuMax]
    #set driverCpuSeverity [expr {$driverCpuMax >= 90.0 ? "critical" : $driverCpuMax >= 75.0 ? "warning" : "ok" }]
    set driverCpuDisplay  [_ns_stats.utilization.colorize $driverCpuSeverity \
                               "[format %.1f $driverCpuTotal]% total, [format %.1f $driverCpuMax]% busiest thread"]

    if {![dict exists $measured driver]} {
        set driverCpuDisplay "unknown"
    }
    set connCpuDisplay [expr {[dict exists $measured conn] ? "[format %.1f $connCpuTotal]%" : "unknown"}]
    set writerCpuDisplay [expr {[dict exists $measured writer] ? "[format %.1f $writerCpuTotal]%" : "unknown"}]
    set spoolerCpuDisplay [expr {[dict exists $measured spooler] ? "[format %.1f $spoolerCpuTotal]%" : "unknown"}]

    set droppedSeverity    [expr {$droppedRate > 0.0 ? "critical" : "ok"}]
    set droppedRateDisplay [_ns_stats.utilization.colorize $droppedSeverity \
                                $droppedText]

    set status [expr {[llength $reasons] == 0 ? "OK" : "[string toupper $severity]: [join $reasons {; }]"}]
    set statusDisplay [_ns_stats.utilization.colorize $severity $status 1]

    #
    # Return the key/value list expected by _ns_stats.process.table.
    #
    set rows [list \
                  [list "Sample Interval"      [expr {$elapsed > 0.0 ? [_ns_stats.fmtSeconds $elapsed] : "\u2014; refresh to obtain interval values"}]] \
                  [list "Request Rate"         [_ns_stats.utilization.displayRate $requestRate]] \
                  [list "Active Requests"      $activeRequests] \
                  [list "Pool Waiting"         $poolWaitingDisplay] \
                  [list "Connection Threads"   $connectionThreadsDisplay] \
                  [list "Driver CPU"           $driverCpuDisplay] \
                  [list "Connection CPU"       $connCpuDisplay] \
                  [list "Writer / Spooler CPU" "$writerCpuDisplay / $spoolerCpuDisplay"] \
                  [list "Driver Socket States"  "$driverReading reading, $driverWaiting ready but unprocessed, $driverClosing closing"] \
                  {*}$linuxRows \
                  [list "Interval Request Handling" "[_ns_stats.utilization.displayRate $queuedRate] queued, [_ns_stats.utilization.displayRate $spooledRate] spooled, $droppedRateDisplay"] \
                  [list "Interval Request Timing"    [expr {[llength $timingValues] > 0 ? [join $timingValues ", "] : "\u2014"}]] \
                  [list "Status"                     $statusDisplay]]
    return $rows
}

proc _ns_stats.utilization.driverCpuInfo {threadCpu driverThread} {
    set driverName      ""
    set driverCpu       -1.0
    set writerCpu       0.0
    set spoolerCpu      0.0
    set writerCount     0
    set spoolerCount    0
    set writerMeasured  0
    set spoolerMeasured 0

    set directDriverName [format {-driver:%s-}     $driverThread]
    set driverSuffix     [format {*:%s-}           $driverThread]
    set writerPattern    [format {-writer:%s:*-}   $driverThread]
    set spoolerPattern   [format {-spooler:%s:*-}  $driverThread]

    dict for {threadKey data} $threadCpu {
        set name   [_ns_stats.dictGetDef $data name ""]
        set parent [_ns_stats.dictGetDef $data parent ""]
        set cpu    [_ns_stats.dictGetDef $data cpu -1.0]

        if {$name eq $directDriverName
            || ([string match "-driver:*" $name]
                && [string match $driverSuffix $name])} {
            set driverName $name
            set driverCpu  $cpu
            continue
        }

        if {[string match $writerPattern $name]} {
            incr writerCount

            if {$cpu >= 0.0} {
                set writerCpu [expr {$writerCpu + $cpu}]
                incr writerMeasured
            }
            continue
        }

        if {[string match $spoolerPattern $name]} {
            incr spoolerCount

            if {$cpu >= 0.0} {
                set spoolerCpu [expr {$spoolerCpu + $cpu}]
                incr spoolerMeasured
            }
        }
    }

    return [dict create \
                driverName       $driverName \
                driverCpu        $driverCpu \
                writerCpu        $writerCpu \
                writerCount      $writerCount \
                writerMeasured   $writerMeasured \
                spoolerCpu       $spoolerCpu \
                spoolerCount     $spoolerCount \
                spoolerMeasured  $spoolerMeasured]
}

proc _ns_stats.utilization.pluralize {count base} {
    return $base[expr {$count>1 ? "s" : ""}]
}

proc _ns_stats.utilization.driverRows {sample threadCpu} {
    set current           [dict get $sample current]
    set previous          [dict get $sample previous]
    set elapsed           [dict get $sample elapsed]
    set rows              {}
    set driverNames       {}
    set cpuValues         {}
    set socketPercentages {}

    dict for {driverThread stats} [dict get $current drivers] {
        set module  [dict get $stats module]
        set name    [_ns_stats.dictGetDef $stats name ""]
        set section ns/module/$module

        set maxQueueSize  [ns_config $section maxqueuesize 1024]
        set writerConfig  [ns_config $section writerthreads 0]
        set spoolerConfig [ns_config $section spoolerthreads 0]

        set waiting [dict get $stats waiting]
        set reading [dict get $stats reading]
        set closing [dict get $stats closing]

        #
        # The sum covers the driver-local lists. It is not the complete
        # drvPtr->queuesize value.
        #
        set localSockets [expr {$waiting + $reading + $closing}]

        #
        # Obtain interval rates when a previous sample for the same
        # driver instance exists.
        #
        set receivedRate  -1.0
        set partialRate   -1.0
        set spooledRate   -1.0
        set errorRate     -1.0
        set errorDelta    -1.0
        set receivedDelta -1.0
        set receivedTotal  0

        if {$elapsed > 0.0
            && [dict exists $previous drivers $driverThread]} {
            set old [dict get $previous drivers $driverThread]

            set receivedRate [_ns_stats.intervalRate \
                                  [dict get $stats received] \
                                  [dict get $old received] \
                                  $elapsed]

            set receivedDelta [_ns_stats.intervalDelta \
                                   [dict get $stats received] \
                                   [dict get $old received] ]
            set receivedTotal [dict get $stats received]

            set partialRate [_ns_stats.intervalRate \
                                 [dict get $stats partial] \
                                 [dict get $old partial] \
                                 $elapsed]

            set spooledRate [_ns_stats.intervalRate \
                                 [dict get $stats spooled] \
                                 [dict get $old spooled] \
                                 $elapsed]

            set errorDelta [_ns_stats.intervalDelta [dict get $stats errors] [dict get $old errors]]
            set errorRate [_ns_stats.intervalRate \
                               [dict get $stats errors] \
                               [dict get $old errors] \
                               $elapsed]
        }

        set cpuInfo [_ns_stats.utilization.driverCpuInfo $threadCpu $driverThread]
        set driverCpu [dict get $cpuInfo driverCpu]

        set measuredCpuSeconds [expr {$elapsed * $driverCpu / 100.0}]
        set estimatedCapacity [expr {$receivedDelta >= 20 && $measuredCpuSeconds >= 0.05
                                     ? $receivedDelta / $measuredCpuSeconds
                                     : -1}]
        set capacityDisplay [expr {$estimatedCapacity > 0
                                   ? [_ns_stats.utilization.displayRate $estimatedCapacity]
                                   : "\u2014"}]

        set writerCount     [_ns_stats.dictGetDef $cpuInfo writerCount 0]
        set writerMeasured  [_ns_stats.dictGetDef $cpuInfo writerMeasured 0]


        set writerDisplay [_ns_stats.utilization.formatWorker \
                               [_ns_stats.dictGetDef $cpuInfo writerCount 0] \
                               [_ns_stats.dictGetDef $cpuInfo writerMeasured 0] \
                               [_ns_stats.dictGetDef $cpuInfo writerCpu 0.0]]

        set spoolerDisplay [_ns_stats.utilization.formatWorker \
                                [_ns_stats.dictGetDef $cpuInfo spoolerCount 0] \
                                [_ns_stats.dictGetDef $cpuInfo spoolerMeasured 0] \
                                [_ns_stats.dictGetDef $cpuInfo spoolerCpu 0.0]]
        set spoolerCount     [_ns_stats.dictGetDef $cpuInfo spoolerCount 0]
        set spoolerMeasured  [_ns_stats.dictGetDef $cpuInfo spoolerMeasured 0]
        if {$spoolerCount == 0} {
            set spoolerDisplay "\u2014"
        } elseif {$spoolerMeasured > 0} {
            set spoolerCpu [_ns_stats.dictGetDef $cpuInfo spoolerCpu 0.0]
            set spoolerDisplay "$spoolerCount [_ns_stats.utilization.pluralize $spoolerCount thread], [format %.1f $spoolerCpu]% CPU"
        } else {
            set spoolerDisplay "$spoolerCount [_ns_stats.utilization.pluralize $spoolerCount thread], \u2014 CPU"
        }

        #
        # Build a concise status and retain the reasons.
        #
        set severity ok
        set reasons  {}

        if {$driverCpu >= 90.0} {
            set severity critical
            lappend reasons "CPU [format %.1f $driverCpu]%"
        } elseif {$driverCpu >= 75.0} {
            set severity warning
            lappend reasons "CPU [format %.1f $driverCpu]%"
        }

        if {$waiting > 0} {
            if {$severity eq "ok"} {
                set severity warning
            }
            lappend reasons "$waiting ready requests awaiting processing"
        }

        #
        # Driver errors can result from malformed or aborted connections,
        # so report them without automatically calling the driver
        # saturated.
        #
        set errorText [_ns_stats.utilization.displayIntervalCounter $errorDelta $errorRate error]
        if {$errorRate > 0.0} {
            lappend reasons \
                $errorText
        }

        if {[llength $reasons] == 0} {
            set status OK
        } else {
            set status "[string toupper $severity]: [join $reasons {; }]"
        }

        if {$receivedTotal > 0} {
            set receivedDisplay [_ns_stats.utilization.displayRate $receivedRate]
            set partialDisplay  [_ns_stats.utilization.displayRate $partialRate]
            set spooledDisplay  [_ns_stats.utilization.displayRate $spooledRate]
        } else {
            set receivedDisplay "\u2014"
            set partialDisplay  "\u2014"
            set spooledDisplay  "\u2014"
        }

        set driverDisplay [_ns_stats.utilization.colorize $severity $driverThread]
        set statusDisplay [_ns_stats.utilization.colorize $severity $status 1]

        set cpuSeverity [expr {$driverCpu >= 90.0 ? "critical" : $driverCpu >= 75.0 ? "warning" : "ok" }]
        set driverCpuDisplay [_ns_stats.utilization.colorize $cpuSeverity \
                                  [expr {$driverCpu < 0.0 ? "\u2014" : "[format %.1f $driverCpu]%" }]]

        set waitingSeverity [expr {$waiting > 0 ? "warning" : "ok"}]
        set waitingDisplay  [_ns_stats.utilization.colorize $waitingSeverity $waiting]

        set errorSeverity  [expr {$errorRate > 0.0 ? "warning" : "ok"}]
        set errorDisplay   [_ns_stats.utilization.colorize $errorSeverity $errorText]

        set socketsPercentage [expr {$localSockets * 100.0 / $maxQueueSize}]
        set socketsSeverity   [expr {$socketsPercentage >= 90.0 ? "critical" : $socketsPercentage >= 75.0 ? "warning" : "ok" }]
        set socketsDisplay    [_ns_stats.utilization.colorize $socketsSeverity \
                                   "$localSockets/$maxQueueSize ([format %.1f $socketsPercentage]%)"]

        lappend driverNames       [dict get $cpuInfo driverName]
        lappend cpuValues         [expr {$driverCpu >= 0.0 ? [format %.1f $driverCpu] : "null"}]
        lappend socketPercentages [expr {$localSockets * 100.0 / $maxQueueSize}]


        lappend rows [list \
                          $driverDisplay \
                          $driverCpuDisplay \
                          $receivedDisplay \
                          $partialDisplay \
                          $spooledDisplay \
                          $errorDisplay \
                          $capacityDisplay \
                          $reading \
                          $waitingDisplay \
                          $closing \
                          $socketsDisplay \
                          $writerDisplay \
                          $spoolerDisplay \
                          $statusDisplay]
    }

    return [dict create \
                rows              $rows \
                names             $driverNames \
                cpuValues         $cpuValues \
                socketPercentages $socketPercentages]
}

proc _ns_stats.utilization.poolRows {sample} {
    set current          [_ns_stats.dictGetDef $sample current {}]
    set previous         [_ns_stats.dictGetDef $sample previous {}]
    set elapsed          [_ns_stats.dictGetDef $sample elapsed 0.0]
    set rows             {}
    set poolNames        {}
    set threadValues     {}
    set connectionValues {}
    set loadValues       {}

    set currentTotalRequests  [_ns_stats.utilization.sumPoolCounter $current requests]
    set previousTotalRequests [_ns_stats.utilization.sumPoolCounter $previous requests]
    set totalRequestRate      [_ns_stats.intervalRate $currentTotalRequests $previousTotalRequests $elapsed]

    set snapshot [_ns_stats.dictGetDef $sample coreSnapshot {}]
    if {[_ns_stats.sampled $snapshot]} {
        set totalRequestRate [_ns_stats.utilization.sampleTotal $snapshot rates requests]
    }
    set currentServers        [_ns_stats.dictGetDef $current servers {}]

    foreach server [lsort [dict keys $currentServers]] {
        set serverData [_ns_stats.dictGetDef $currentServers $server {}]
        set pools      [_ns_stats.dictGetDef $serverData pools {}]

        foreach pool [lsort [dict keys $pools]] {
            set poolData [_ns_stats.dictGetDef $pools $pool {}]
            set stats    [_ns_stats.dictGetDef $poolData stats {}]
            set threads  [_ns_stats.dictGetDef $poolData threads {}]

            set oldPoolData [_ns_stats.dictGetDef $previous servers $server pools $pool {}]
            set oldStats    [_ns_stats.dictGetDef $oldPoolData stats {}]
            set poolLabel   [expr {$pool eq "" ? "default" : $pool}]

            #
            # Current gauges.
            #
            set active         [_ns_stats.dictGetDef $poolData active 0]
            set waiting        [_ns_stats.dictGetDef $poolData waiting 0]
            set threadCurrent  [_ns_stats.dictGetDef $threads current 0]
            set threadIdle     [_ns_stats.dictGetDef $threads idle 0]
            set threadStopping [_ns_stats.dictGetDef $threads stopping 0]
            set threadMax      [_ns_stats.dictGetDef $threads max 0]

            #
            # Pool-specific configuration.
            #
            set configPath     [expr {$pool in {{} default} ? "ns/server/$server" : "ns/server/$server/pool/$pool"}]
            set maxConnections [ns_config $configPath maxconnections 100]

            #
            # Cumulative counters.
            #
            set requests     [_ns_stats.dictGetDef $stats requests 0]
            set oldRequests  [_ns_stats.dictGetDef $oldStats requests 0]
            set requestDelta [expr {$requests - $oldRequests}]
            set requestRate  [_ns_stats.intervalRate $requests $oldRequests $elapsed]

            set queuedRate   [_ns_stats.intervalRate \
                                  [_ns_stats.dictGetDef $stats queued 0] \
                                  [_ns_stats.dictGetDef $oldStats queued 0] \
                                  $elapsed]

            set spooledRate  [_ns_stats.intervalRate \
                                  [_ns_stats.dictGetDef $stats spools 0] \
                                  [_ns_stats.dictGetDef $oldStats spools 0] \
                                  $elapsed]

            set droppedRate  [_ns_stats.intervalRate \
                                  [_ns_stats.dictGetDef $stats dropped 0] \
                                  [_ns_stats.dictGetDef $oldStats dropped 0] \
                                  $elapsed]
            set droppedDelta [_ns_stats.intervalDelta \
                                  [_ns_stats.dictGetDef $stats dropped 0] \
                                  [_ns_stats.dictGetDef $oldStats dropped 0]]
            set droppedText [_ns_stats.utilization.displayIntervalCounter $droppedDelta $droppedRate "dropped request"]

            #
            # Share of the total process-wide request rate.
            #
            if {$requestRate >= 0.0 && $totalRequestRate > 0.0} {
                set globalShare [expr { 100.0 * $requestRate / $totalRequestRate }]
                set globalShareDisplay [format %.1f%% $globalShare]
            } else {
                set globalShareDisplay "\u2014"
            }

            #
            # Compute interval-average timing values.
            #
            set averageQueue   -1.0
            set averageFilter  -1.0
            set averageRun     -1.0
            set averageTrace   -1.0
            set averageService -1.0

            if {$requestDelta > 0} {
                foreach {counter variableName} {
                    queuetime  averageQueue
                    filtertime averageFilter
                    runtime    averageRun
                    tracetime  averageTrace
                } {
                    set currentValue  [_ns_stats.dictGetDef $stats $counter 0.0]
                    set previousValue [_ns_stats.dictGetDef $oldStats $counter 0.0]
                    set delta [expr {$currentValue - $previousValue}]

                    if {$delta >= 0.0} {
                        set $variableName [expr {$delta / double($requestDelta)}]
                    }
                }

                if {$averageFilter >= 0.0
                    && $averageRun >= 0.0
                    && $averageTrace >= 0.0} {
                    set averageService [expr {$averageFilter + $averageRun + $averageTrace}]
                }
            }

            set queueDisplay   [expr {$averageQueue   >= 0.0 ? "[_ns_stats.hr $averageQueue]s"   : "\u2014"}]
            set serviceDisplay [expr {$averageService >= 0.0 ? "[_ns_stats.hr $averageService]s" : "\u2014"}]

            #
            # Estimate the maximum request rate using the configured
            # maximum number of connection threads and the interval
            # average service time.
            #
            set estimatedCapacity -1.0
            set estimatedLoad     -1.0

            if {$threadMax > 0 && $averageService > 0.0} {
                set estimatedCapacity [expr {$threadMax / $averageService}]

                if {$requestRate >= 0.0} {
                    set estimatedLoad [expr {100.0 * $requestRate / $estimatedCapacity}]
                }
            }

            set capacityDisplay [expr {$estimatedCapacity >= 0.0
                                       ? "[_ns_stats.utilization.displayRate $estimatedCapacity]"
                                       : "\u2014"
                                   }]

            #
            # Classify only clear pressure indicators.
            #
            set severity ok
            set reasons  {}

            if {$droppedRate > 0.0} {
                set severity critical
                lappend reasons  $droppedText
            }

            if {$waiting > 0} {
                if {$severity eq "ok"} {
                    set severity warning
                }
                lappend reasons "$waiting waiting"
            }

            if {$threadCurrent > 0
                && $threadIdle == 0
                && $threadCurrent >= $threadMax} {
                if {$severity eq "ok"} {
                    set severity warning
                }
                lappend reasons "all connection threads busy"
            }

            set estimatedLoadSeverity ok
            if {$estimatedLoad >= 90.0} {
                if {$severity eq "ok"} {
                    set severity warning
                    set estimatedLoadSeverity warning
                }
                lappend reasons "estimated load [format %.1f $estimatedLoad]%"
            }

            if {[llength $reasons] == 0} {
                set status OK
            } else {
                set status "[string toupper $severity]: [join $reasons {; }]"
            }

            set serverDisplay [_ns_stats.utilization.colorize $severity $server]
            set poolDisplay   [_ns_stats.utilization.colorize $severity $poolLabel]
            set statusDisplay [_ns_stats.utilization.colorize $severity $status 1]

            set threadBusy [expr {max(0, $threadCurrent - $threadIdle - $threadStopping)}]
            set threadBusyPercentage [expr {$threadCurrent > 0 ? 100.0 * $threadBusy / $threadCurrent : 0.0 }]

            set threadSeverity [expr {$waiting > 0 || $threadBusyPercentage > 90.0 ? "warning" : "ok" }]
            set threadDisplay  [_ns_stats.utilization.colorize $threadSeverity "[format {%d/%d/%d} $threadBusy $threadCurrent $threadMax]&nbsp;→"]
            set busyDisplay    [_ns_stats.utilization.colorize $threadSeverity [format %.1f%% $threadBusyPercentage]]

            set droppedSeverity [expr {$droppedRate > 0.0 ? "critical" : "ok"}]
            set droppedDisplay [_ns_stats.utilization.colorize $droppedSeverity $droppedText]

            set waitingSeverity       [expr {$waiting > 0 ? "warning" : "ok"}]
            set currentConnections    [expr {$waiting + $active}]
            set connectionsPercentage [expr {$currentConnections * 100.0 / $maxConnections}]
            set connectionsSeverity   [expr {$connectionsPercentage >= 90.0 ? "critical" : $connectionsPercentage >= 75.0 ? "warning" : "ok"}]
            if {$connectionsSeverity eq "ok" && $waitingSeverity ne "ok"} {
                set connectionsSeverity $waitingSeverity
            }
            set connectionsDisplay    [_ns_stats.utilization.colorize $connectionsSeverity \
                                           "($active\u00a0+\u00a0$waiting)&nbsp;/$maxConnections&nbsp;→"]
            set connectionsPercentageDisplay [_ns_stats.utilization.colorize $connectionsSeverity [format %.1f $connectionsPercentage]%]

            set loadDisplay [_ns_stats.utilization.colorize $estimatedLoadSeverity \
                                 [expr {$estimatedLoad >= 0.0 ? "[format %.1f $estimatedLoad]%" : "\u2014" }]]

            lappend poolNames        $server/$poolLabel
            lappend threadValues     $threadBusyPercentage
            lappend connectionValues $connectionsPercentage
            lappend loadValues       $estimatedLoad

            lappend rows [list \
                              $serverDisplay \
                              $poolDisplay \
                              [_ns_stats.utilization.displayRate $requestRate] \
                              $globalShareDisplay \
                              $threadDisplay \
                              $busyDisplay \
                              $connectionsDisplay \
                              $connectionsPercentageDisplay \
                              $queueDisplay \
                              $serviceDisplay \
                              $capacityDisplay \
                              $loadDisplay \
                              [_ns_stats.utilization.displayRate $queuedRate] \
                              [_ns_stats.utilization.displayRate $spooledRate] \
                              $droppedDisplay \
                              $statusDisplay]
        }
    }

    return [dict create \
                rows              $rows \
                names             $poolNames \
                threadValues      $threadValues \
                connectionValues $connectionValues \
                loadValues       $loadValues]
}


#
# Render a Highcharts utilization chart.
#
# -categories is a Tcl list of category labels.
#
# -series is a Tcl list of dicts:
#
#   [list \
#       [dict create name CPU     data $cpuValues] \
#       [dict create name Sockets data $socketPercentages]]
#
# Series values must be numbers or the literal "null".
#
proc _ns_stats.utilization.chart {args} {
    ns_parseargs {
        {-id ""}
        {-title ""}
        {-subtitle ""}
        {-categories {}}
        {-series {}}
        {-ytitle "Utilization (%)"}
        {-minimum 0.0}
        {-maximum 100.0}
        {-warning 75.0}
        {-critical 90.0}
        {-suffix "%"}
        {-minheight 320}
        {-baseheight 100}
        {-rowheight 36}
        {-class "utilization-chart"}
    } $args

    if {$id eq ""} {
        error "_ns_stats.utilization.chart: -id must not be empty"
    }
    if {![regexp {^[[:alpha:]][[:alnum:]_-]*$} $id]} {
        error "_ns_stats.utilization.chart: invalid HTML id '$id'"
    }
    if {$title eq ""} {
        error "_ns_stats.utilization.chart: -title must not be empty"
    }
    if {[llength $series] == 0} {
        error "_ns_stats.utilization.chart: -series must not be empty"
    }

    foreach {option value} [list \
                                -minimum  $minimum \
                                -maximum  $maximum \
                                -warning  $warning \
                                -critical $critical] {
        if {![string is double -strict $value]} {
            error "_ns_stats.utilization.chart: $option must be numeric"
        }
    }

    foreach {option value} [list \
                                -minheight  $minheight \
                                -baseheight $baseheight \
                                -rowheight  $rowheight] {
        if {![string is integer -strict $value] || $value < 0} {
            error "_ns_stats.utilization.chart: $option must be a non-negative integer"
        }
    }

    set categoryCount [llength $categories]
    set chartHeight   [expr {max($minheight, $baseheight + $categoryCount * $rowheight)}]

    #
    # Encode the category labels.
    #
    set categoryTriples [lmap category $categories {list 0 string $category}]
    set jsonCategories  [ns_json value -type array [concat {*}$categoryTriples]]

    #
    # Encode every series. The JSON object itself is assembled here,
    # while all dynamic values are encoded by ns_json.
    #
    set jsonSeriesEntries {}

    foreach seriesSpec $series {
        if {![dict exists $seriesSpec name]} {
            error "_ns_stats.utilization.chart: series has no 'name'"
        }
        if {![dict exists $seriesSpec data]} {
            error "_ns_stats.utilization.chart: series has no 'data'"
        }

        set seriesName [dict get $seriesSpec name]
        set seriesData [dict get $seriesSpec data]

        if {[llength $seriesData] != $categoryCount} {
            error "_ns_stats.utilization.chart: series '$seriesName' has \
                [llength $seriesData] values, but there are $categoryCount categories"
        }

        set dataTriples {}
        foreach value $seriesData {
            set type [expr {$value eq "null" ? "null" : "number"}]
            lappend dataTriples  [list 0 $type $value]
        }

        set jsonSeriesName [ns_json value -type string $seriesName]
        set jsonSeriesData [ns_json value -type array [concat {*}$dataTriples]]

        lappend jsonSeriesEntries "\{name: $jsonSeriesName, data: $jsonSeriesData\}"
    }

    set jsonSeries "\[[join $jsonSeriesEntries ,]\]"

    set jsonId          [ns_json value -type string $id]
    set jsonTitle       [ns_json value -type string $title]
    set jsonSubtitle    [ns_json value -type string $subtitle]
    set jsonYTitle      [ns_json value -type string $ytitle]
    set jsonLabelFormat [ns_json value -type string "{point.y:.1f}$suffix"]

    set htmlId    [ns_quotehtml $id]
    set htmlClass [ns_quotehtml $class]

    return [ns_trim -delimiter | [subst -nocommands {
        |<div id="$htmlId" class="$htmlClass"></div>
        |<script>
        |Highcharts.chart($jsonId, {
        |    chart: {
        |        type: 'bar',
        |        height: $chartHeight
        |    },
        |    title: {
        |        text: $jsonTitle
        |    },
        |    subtitle: {
        |        text: $jsonSubtitle
        |    },
        |    xAxis: {
        |        categories: $jsonCategories,
        |        alternateGridColor: 'rgba(0, 0, 0, 0.035)',
        |        gridLineWidth: 1,
        |        gridLineColor: '#d8d8d8',
        |        tickLength: 0
        |    },
        |    yAxis: {
        |        min: $minimum,
        |        max: $maximum,
        |        title: {
        |            text: $jsonYTitle
        |        },
        |        plotBands: [
        |            {
        |                from: $warning,
        |                to: $critical,
        |                color: 'rgba(255, 165, 0, 0.08)'
        |            },
        |            {
        |                from: $critical,
        |                to: $maximum,
        |                color: 'rgba(255, 0, 0, 0.08)'
        |            }
        |        ],
        |        plotLines: [
        |            {
        |                value: $warning,
        |                color: 'orange',
        |                width: 1
        |            },
        |            {
        |                value: $critical,
        |                color: 'red',
        |                width: 1
        |            }
        |        ]
        |    },
        |    plotOptions: {
        |        series: {
        |            grouping: true,
        |            groupPadding: 0.12,
        |            pointPadding: 0.06,
        |            borderWidth: 0,
        |            minPointLength: 3,
        |            dataLabels: {
        |                enabled: true,
        |                allowOverlap: false,
        |                crop: false,
        |                overflow: 'allow',
        |                format: $jsonLabelFormat
        |            }
        |        }
        |    },
        |    series: $jsonSeries
        |});
        |</script>
    }]]
}

#
# Return a display label with a native browser tooltip.
#
proc _ns_stats.tooltip {label tooltip {noquote 0} {class ""}} {
    if {$tooltip ne ""} {
        set spanClass "nsstats-tooltip $class"
        set title [subst {title="[ns_quotehtml $tooltip]"}]
    } else {
        set spanClass "$class"
        set title ""
    }
    set label [expr {$noquote ? $label : [ns_quotehtml $label]}]
    return [subst {<span class="$spanClass" $title">$label</span>}]
}

#
# Provide lists for titles and alignments for ns_stats.results tables
#
proc _ns_stats.columnLists {columnSpecs} {
    set titles {}
    set alignments {}

    foreach {title spec} $columnSpecs {
        set tooltip [string trim [_ns_stats.dictGetDef $spec tooltip ""]]
        set title [_ns_stats.tooltip \
                       $title \
                       $tooltip \
                       [_ns_stats.dictGetDef $spec noquote 0] \
                       [_ns_stats.dictGetDef $spec class ""]]
        lappend titles $title
        lappend alignments [dict get $spec align]
    }

    return [list $titles $alignments]
}

proc _ns_stats.utilization {} {
    set sample        [_ns_stats.utilizationSample]

    set cpuData       [_ns_stats.threadCpuPercentages utilizationThreadCpuSample [dict get $sample coreSnapshot]]
    set threadCpu     [_ns_stats.dictGetDef $cpuData byThread {}]
    set driverInfo    [_ns_stats.utilization.driverRows $sample $threadCpu]
    set driverRows    [dict get $driverInfo rows]

    set poolInfo      [_ns_stats.utilization.poolRows $sample]
    set poolRows      [dict get $poolInfo rows]

    set globalSummary [_ns_stats.utilization.globalSummary $sample $threadCpu]

    set driverColumnSpecs {
        "Driver Thread" {
            align left
        }
        "CPU %" {
            align right
        }
        "Received/s" {
            align right
            tooltip {
                Attempts to submit parsed requests to connection pools
            }
        }
        "Partial/s" {
            align right
            tooltip {
                Receive attempts that left the request incomplete
            }
        }
        "Upload-spooled/s" {
            align right
            tooltip {
                Requests handed to upload spooler threads
            }
        }
        "Errors (interval)" {
            align right
        }
        "Est. capacity" {
            align right
            tooltip {
                Observed completed receives extrapolated to 100% utilization
                of one logical CPU. This is a workload-dependent CPU-capacity
                estimate, not a configured or guaranteed limit. Omitted when
                the sample contains insufficient activity.
            }
        }
        "Reading" {
            align right
            tooltip {
                Sockets with incomplete requests or keep-alive sockets awaiting
                the next request
            }
        }
        "Pending" {
            align right
            tooltip {
                Requests ready for processing but still retained by the driver
            }
        }
        "Closing" {
            align right
            tooltip {
                Sockets retained temporarily for graceful shutdown
            }
        }
        "Sockets <span class='nowrap'>(used/max)</span>" {
            align right
            noquote true
            tooltip {
                Sockets currently retained by this driver thread
                (reading, pending, or closing),
                relative to its configured maxqueuesize.
            }
        }
        "Writers" {
            align right
            tooltip {
                Live threads / combined CPU percentage
            }
        }
        "Spoolers" {
            align right
            tooltip {
                Live threads / combined CPU percentage
            }
        }
        "Status" {
            align left
        }
    }

    set poolColumnSpecs {
        Server {
            align left
        }
        Pool {
            align left
        }
        Req/s {
            align right
        }
        "Global Share" {
            align right
        }
        "Threads <span class='nowrap'>(busy/current/max)</span>" {
            align right
            noquote true
        }
        Busy {
            align left
        }
        "Connections <span class='nowrap'>(active + waiting)/max</span>" {
            align right
            noquote true
            tooltip {
                Running requests plus requests waiting for a connection thread,
                relative to the pool's maxconnections limit.
            }
        }
        Busy {
            align left
        }
        "Avg Queue" {
            align right
        }
        "Avg Service" {
            align right
        }
        "Est. Capacity" {
            align right
            tooltip {
                Estimated maximum request rate, calculated as maximum connection
                threads divided by average service time.
            }
        }
        "Est. Load" {
            align right
            tooltip {
                Observed request rate divided by estimated capacity. This
                interval-based estimate may not reflect short bursts or current
                queueing.
            }
        }
        Queued/s {
            align right
            class nowrap
        }
        "Writer Jobs" {
            align right
        }
        "Dropped (interval)" {
            align right
            class nowrap
        }
        Status {
            align left
        }
    }

    lassign [_ns_stats.columnLists $driverColumnSpecs] \
        driverTitles driverAlign

    lassign [_ns_stats.columnLists $poolColumnSpecs] \
        poolTitles poolAlign


    set ::extraHeadEntries [ns_trim -delimiter | {
        |<style>
        |.utilization-charts {
        |   display: grid;
        |   grid-template-columns: repeat(auto-fit, minmax(520px, 1fr));
        |   gap: 1rem;
        |}
        |.utilization-chart {
        |   min-height: 280px;
        | }
        |.nsstats-tooltip {
        |   text-decoration-line: underline;
        |   text-decoration-style: dashed;
        |   text-decoration-color: currentColor;
        |   text-underline-offset: 3px;
        |   cursor: help;
        |}
        |</style>
        |<script src="https://code.highcharts.com/highcharts.js"></script>
        |<script src="https://code.highcharts.com/modules/exporting.js"></script>
        |<script src="https://code.highcharts.com/modules/export-data.js"></script>
    }]

    set driverChart [_ns_stats.utilization.chart \
                         -id driver-utilization \
                         -title "Network driver utilization" \
                         -subtitle "CPU is relative to one logical CPU; sockets are relative to maxqueuesize" \
                         -categories [dict get $driverInfo names] \
                         -series [list \
                                      [dict create \
                                           name CPU \
                                           data [dict get $driverInfo cpuValues]] \
                                      [dict create \
                                           name Sockets \
                                           data [dict get $driverInfo socketPercentages]]] \
                        ]

    set poolChart [_ns_stats.utilization.chart \
                       -id pool-utilization \
                       -title "Server and connection pool utilization" \
                       -subtitle "Thread busy ratio; active + waiting connections relative to maxconnections; request rate relative to estimated capacity" \
                       -rowheight 48 \
                       -categories [dict get $poolInfo names] \
                       -series [list \
                                    [dict create \
                                         name Thread \
                                         data [dict get $poolInfo threadValues]] \
                                    [dict create \
                                         name Connections \
                                         data [dict get $poolInfo connectionValues]] \
                                    [dict create \
                                         name "Est. load" \
                                         data [dict get $poolInfo loadValues]]] \
                      ]

    append html \
        [_ns_stats.header "Utilization and Bottlenecks"] \
        [_ns_stats.utilization.sourcePanel $sample] \
        [_ns_stats.results global-summary 0 {Metric Value} "?@page=utilization" $globalSummary 0 {left left}] \
        "\n<p></p>" \
        "\n<div class='utilization-charts'>$driverChart $poolChart</div>" \
        "<h2>Network Drivers</h2>" \
        [_ns_stats.results drivers 0 $driverTitles "?@page=utilization" $driverRows 0 $driverAlign] \
        "<h2 id='nsstats-pools'>Servers and Connection Pools</h2>" \
        [_ns_stats.results utilization-pools 0 $poolTitles "?@page=utilization" $poolRows 0 $poolAlign] \
        [_ns_stats.utilization.historyPanel] \
        [_ns_stats.footer]
    return $html
}


proc _ns_stats.locks.mutex {} {
    set col         [ns_queryget col 1]
    set reverseSort [ns_queryget reversesort 1]

    set numericSort 1
    set colTitles   [list Name ID Locks Busy Contention "Total Lock" "Avg Lock" "Total Wait" \
                         "Max Wait" "Locks/Req" "Pot.Locks/sec" "Pot.Reqs/sec" "Read" "Write" "Write %"]
    set rows        ""

    if {$col == 1} {
        set numericSort 0
    }

    set results ""
    set sumWait 0
    set sumLockTime 0
    set sumLocks 0
    set totalRequests [_ns_stats.totalRequests]

    set non_per_req_locks {interp jobThreadPool ns:sched tcljob:jobs}
    lappend non_per_req_locks {*}[ns_config ns/module/nsstats bglocks ""]
    foreach s [ns_info servers] {
        lappend non_per_req_locks tcljob:ns_eval_q:$s
    }
    set non_per_req_locks [lsort $non_per_req_locks]

    foreach l [ns_info locks] {
        lassign $l name owner id nlock nbusy totalWait maxWait totalLock read write
        set sumWait     [expr {$sumWait + $totalWait}]
        if {$name ni $non_per_req_locks} {
            set sumLockTime [expr {$sumLockTime + $totalLock}]
        }
        set sumLocks    [expr {$sumLocks + $nlock}]
        set avgLock     [expr {$totalLock ne "" && $nlock > 0 ? $totalLock * 1.0 / $nlock : 0}]
        if {$nlock > 2 && $name ni $non_per_req_locks} {
            set maxLocksPerSec [expr {1.0/$avgLock}]
            set locksPerReq    [expr {$nlock*1.0/$totalRequests}]
            set maxReqsPerSec  [expr {$maxLocksPerSec/$locksPerReq}]
        } else {
            set maxLocksPerSec [expr {1.0/0}]
            set locksPerReq    -1
            set maxReqsPerSec  [expr {1.0/0}]
        }

        if {$nbusy == 0} {
            set contention 0.0
        } else {
            set contention [format %5.4f [expr {double($nbusy*100.0/$nlock)}]]
        }
        set writePercent   [expr {$write ne "" && $write+$read > 0 ? ($write*100.0/($write+$read)) : ""}]

        lappend results [list $name $id $nlock $nbusy $contention \
                             $totalLock $avgLock $totalWait $maxWait \
                             $locksPerReq $maxLocksPerSec $maxReqsPerSec $read $write $writePercent]
    }

    foreach result [_ns_stats.sortResults $results [expr {$col - 1}] $numericSort $reverseSort] {
        lassign $result name id nlock nbusy contention totalLock avgLock totalWait maxWait \
            locksPerReq maxLocksPerSec maxReqsPerSec read write writePercent
        set contention     [format %.4f $contention]
        set totalLock      [format %.4f $totalLock]
        set avgLock        [format %.8f $avgLock]
        set relWait        [expr {$sumWait > 0 ? $totalWait/$sumWait : 0}]
        set locksPerReq    [format %.2f $locksPerReq]
        set maxLocksPerSec [_ns_stats.hr $maxLocksPerSec]
        set maxReqsPerSec  [_ns_stats.hr $maxReqsPerSec]

        set writePercent   [expr {$writePercent ne "" ? "[format %.2f $writePercent]%" : ""}]
        set read           [expr {$read ne "" ? [_ns_stats.hr $read] : $read}]
        set write          [expr {$write ne "" ? [_ns_stats.hr $write] : $write}]

        set color black
        set ccolor [expr {$contention < 2   ? $color : $contention < 5   ? "orange" : "red"}]
        set tcolor [expr {$relWait    < 0.1 ? $color : $totalWait  < 0.5 ? "orange" : "red"}]
        set wcolor [expr {$maxWait    < 0.01 ? $color : $maxWait    < 0.1   ? "orange" : "red"}]
        set ncolor [expr {"orange" in [list $ccolor $tcolor $wcolor] ? "orange" : $color}]
        set ncolor [expr {"red "   in [list $ccolor $tcolor $wcolor] ? "red" : $ncolor}]

        lappend rows [list \
                          "<font color=$ncolor>$name</font>" \
                          "<font color=$color>$id</font>" \
                          "<font color=$color>[_ns_stats.hr $nlock]</font>" \
                          "<font color=$color>[_ns_stats.hr $nbusy]</font>" \
                          "<font color=$ccolor>$contention%</font>" \
                          "<font color=$color>[_ns_stats.hr $totalLock]s</font>" \
                          "<font color=$color>[_ns_stats.hr $avgLock]s</font>" \
                          "<font color=$tcolor>[_ns_stats.hr $totalWait]s</font>" \
                          "<font color=$wcolor>[_ns_stats.hr $maxWait]s</font>" \
                          "<font color=$color>$locksPerReq</font>" \
                          "<font color=$color>$maxLocksPerSec</font>" \
                          "<font color=$color>$maxReqsPerSec</font>" \
                          "<font color=$color>$read</font>" \
                          "<font color=$color>$write</font>" \
                          "<font color=$color>$writePercent</font>" \
                         ]
    }

    set avgLock          [expr {$sumLockTime/$sumLocks}]
    set locksPerReq      [expr {$sumLocks/$totalRequests}]
    set lockTimePerReq   [expr {$sumLockTime/$totalRequests}]
    set maxLocksPerSec   [expr {1.0/$avgLock}]

    set p_locksPerReq    [_ns_stats.hr $locksPerReq]
    set p_avgLock        [_ns_stats.hr $avgLock]
    set p_maxLocksPerSec [_ns_stats.hr $maxLocksPerSec]
    set p_lockTimePerReq [_ns_stats.hr $lockTimePerReq]
    set p_maxPages       [_ns_stats.hr [expr {1.0/$lockTimePerReq}]]
    set p_sumLocks       [_ns_stats.hr $sumLocks]
    set p_totalRequests  [_ns_stats.hr $totalRequests]

    set line "Total locks: $p_sumLocks, total requests $p_totalRequests,\
        locks per request $p_locksPerReq, avg lock time $p_avgLock,\
        lock time request req $p_lockTimePerReq, max requests per sec $p_maxPages <br>(except: [join $non_per_req_locks {, }])"
    append html \
        [_ns_stats.header "Locks"] \
        "<p class='summary'>$line</p>" \
        [_ns_stats.results locks $col $colTitles ?@page=locks.mutex $rows $reverseSort {
            left right right right right right right right right right right right right right right
        }] \
        [_ns_stats.footer]

    return $html
}

proc _ns_stats.locks.nsv {} {
    set col         [ns_queryget col 2]
    set reverseSort [ns_queryget reversesort 1]
    set all         [ns_queryget all 0]

    set numericSort 1
    set colTitles   [list Array Locks Bucket "Bucket Locks" Busy Contention "Total Wait" "Max Wait"]
    set rows        ""

    if {$col == 1} {
        set numericSort 0
    }

    # get the lock statistics for nsvs
    foreach l [ns_info locks] {
        set name      [lindex $l 0]
        if {![regexp {^nsv:(\d+):} $name _ bucket]} continue
        #set id        [lindex $l 2]
        set nlock     [lindex $l 3]
        set nbusy     [lindex $l 4]
        set totalWait [lindex $l 5]
        set maxWait   [lindex $l 6]
        #set sumWait   [expr {$sumWait + $totalWait}]

        if {$nbusy == 0} {
            set contention 0.0
        } else {
            set contention [format %5.4f [expr {double($nbusy*100.0/$nlock)}]]
        }

        set mutexStats($bucket) [list $nlock $nbusy $contention $totalWait $maxWait]
    }

    set rows ""
    set bucketNr 0
    if {[info commands nsv_bucket] ne ""} {
        foreach b [nsv_bucket] {
            foreach e $b {
                lappend rows [lappend e $bucketNr {*}$mutexStats($bucketNr)]
            }
            incr bucketNr
        }
    }
    set rows [_ns_stats.sortResults $rows [expr {$col - 1}] $numericSort $reverseSort]
    set max 200
    if {[llength $rows]>$max && !$all} {
        set rows [lrange $rows 0 $max]
        set truncated 1
    }

    set table {}
    foreach row $rows {
        lset row 1 [_ns_stats.hr [lindex $row 1]]
        lset row 3 [_ns_stats.hr [lindex $row 3]]
        lset row 4 [_ns_stats.hr [lindex $row 4]]
        lset row 5 [format %.4f [lindex $row 5]]%
        lset row 6 [_ns_stats.hr [lindex $row 6]]s
        lset row 7 [_ns_stats.hr [lindex $row 7]]s
        lappend table $row
    }

    append html \
        [_ns_stats.header "Nsv Locks"] \
        [_ns_stats.results nsv-locks $col $colTitles ?@page=locks.nsv \
             $table \
             $reverseSort \
             {left right right right right right right right}]

    if {[info exists truncated]} {
        append html "<a href='?@page=locks.nsv&col=$col&reversesort=$reverseSort&all=1'>...</a><br>"
    }
    append html [_ns_stats.footer]

    return $html
}

proc _ns_stats.mem.nsvsize {} {
    set col         [ns_queryget col 3]
    set reverseSort [ns_queryget reversesort 1]
    set all         [ns_queryget all 0]

    # Scope is optional: 4.99 uses the unchanged server-local interface.
    set hasScope [expr {![catch {nsv_array scope _ns_stats}]}]
    set numericSort 1
    set colTitles   [list Array Elements Bytes "Agv. Content-Size"]
    if {$hasScope} {
        lappend colTitles Scope
    }
    set rows        ""

    if {$col == 1 || ($hasScope && $col == 5)} {
        set numericSort 0
    }

    set nrArrays 0; set totalElements 0; set totalBytes 0
    set rows ""
    # get the array size statistics for nsvs array
    foreach array [nsv_names] {
        incr nrArrays
        set contentBytes 0
        set sizeBytes 0
        set size    [nsv_array size $array]
        foreach {key value} [nsv_array get $array] {
            set valueLength [string length $value]
            incr contentBytes $valueLength
            incr sizeBytes [expr {$valueLength + [string length $key] + 40}] ;# Tcl_HashEntry
        }
        set row [list $array $size $sizeBytes [expr {$size > 0 ? $contentBytes*1.0/$size : 0}]]
        if {$hasScope} {
            set scope unknown
            catch {set scope [nsv_array scope $array]}
            lappend row [ns_quotehtml [expr {$scope eq "process" ? "Global" : ($scope eq "server" ? "Server: [ns_info server]" : "Unknown")}]]
        }
        lappend rows $row
        incr totalElements $size
        incr totalBytes $sizeBytes
    }
    incr totalBytes [expr {$nrArrays * 120}] ;# add approximate size of a single nsv array structure

    set rows [_ns_stats.sortResults $rows [expr {$col - 1}] $numericSort $reverseSort]
    set table {}
    foreach row $rows {
        lset row 1 [_ns_stats.hr [lindex $row 1]]
        lset row 2 [_ns_stats.hr [lindex $row 2]]B
        lset row 3 [format %.2f [lindex $row 3]]
        lappend table $row
    }

    set scopeInfo "Shared variables for server [ns_quotehtml [ns_info server]]."
    set align {left right right right}
    if {$hasScope} {
        set scopeInfo "Global and current-server shared variables; the Scope column identifies their ownership."
        lappend align left
    }
    append html \
        [_ns_stats.header "Nsv Size"] \
        "<p>$scopeInfo</p>" \
        "<p>Nsv arrays: $nrArrays, elements: [_ns_stats.hr $totalElements], total bytes: [_ns_stats.hr $totalBytes]B</p>" \
        [_ns_stats.results nsv-size $col $colTitles ?@page=mem.nsvsize \
             $table \
             $reverseSort \
             $align]

    append html [_ns_stats.footer]
    return $html
}

proc _ns_stats.log.prepare_content {type content} {
    set content [ns_quotehtml $content]
    switch $type {
        access { regsub -all { ([-][^\]\n\" ]+[-]) } $content \
                     { <a href='nsstats.tcl?@page=log.logfile\&filter=\1'>\1</a> } \
                     content }
        system { regsub -all {\[([-][^\]\n\" ]+[-])\]} $content \
                     [string map [list @X@ [ns_queryget system_log [file tail [ns_info log]]]] \
                          {[<a href='nsstats.tcl?@page=log.logfile\&filter=\1\&system_log=@X@'>\1</a>]}] \
                     content }
    }
    return $content
}

proc _ns_stats.log.logfile {} {
    set content ""
    set colorcodemap [list \
                          [binary decode hex 1b5b303b33326d] "" \
                          [binary decode hex 1b5b303b33396d] "" \
                          [binary decode hex 1b5b306d] "" \
                          [binary decode hex 1b5b313b33316d] "" \
                          [binary decode hex 1b5b313b33396d] "" \
                         ]
    set filter [ns_queryget filter ""]
    set system_log_tail [ns_queryget system_log [file tail [ns_info log]]]
    set system_log [file dirname [ns_info log]]/$system_log_tail
    set system_suffix [string range $system_log [string length [ns_info log]] end]

    if {$filter ne ""} {
        set access_content ""
        foreach s [ns_info servers] {
            try {
                set section ns/server/$s/module/nslog
                set path [ns_config $section file]
                if {$path eq ""} {
                    # check the default
                    set defaultSet [ns_configsection -filter defaults $section]
                    if {$defaultSet eq ""} {
                        # module not configured
                        continue
                    }
                    set path [ns_set get $defaultSet file]
                }
                if {[file pathtype $path] eq "relative"} {
                    set path [file normalize [ns_config ns/parameters logdir]/$path]
                }
                set lines [exec fgrep -- $filter $path]
                if {$system_suffix ne "" && [file exists $path$system_suffix]} {
                    append path $system_suffix
                }
                set lines [exec fgrep -- $filter $path]
                append access_content $lines \n
            } on error {errorMsg} {
                # just return no content lines when fgrep fails
            }
        }
        try {
            set system_content [string map $colorcodemap [exec fgrep -A100 -- $filter $system_log]]
        } on error {errorMsg} {
            set system_content ""
        }
        try {
            set currentLine ""
            set lines {}
            #
            # Join continuation lines
            #
            foreach l [split $system_content \n] {
                if {[string range $l 0 0] eq ":"} {
                    append currentLine \n$l
                } else {
                    lappend lines $currentLine
                    set currentLine [expr {$l eq "--" ? "" : $l}]
                }
            }
            lappend lines $currentLine
            #
            # Search in joined lines
            #
            set system_content [join [lmap l $lines {
                if {![string match *$filter* $l]} continue
                set l
            }] \n]
        } on error {errorMsg} {
            set system_content "error log filter caught: '$errorMsg'"
        }
        set content ""
        if {$access_content ne ""} {
            append content [subst {
                <h4>Access log:</h4>
                <font size=2><pre>[_ns_stats.log.prepare_content access $access_content]</pre></font>
            }]
        }
        if {$system_content ne ""} {
            append content [subst {
                <h4>System log:</h4>
                <font size=2><pre>[_ns_stats.log.prepare_content system $system_content]</pre></font>
            }]
        }
    } else {
        set log_to_stderr [expr {"-f" in [ns_info argv]}]
        if {!$log_to_stderr && ![file exists $system_log]} {
            #
            # Older version of NaviServer do not provide a working
            # "ns_info argv"
            #
            set log_to_stderr 1
        }
        if {$log_to_stderr} {
            set content [ns_trim -delimiter | [subst {
                | <p>The configured log file <i>$system_log</i> does not exist.
                | <p>Was maybe the server is running in foreground mode (i.e., started with the '-f' flag)?
            }]]
        } else {
            try {
                set f [open $system_log]
                seek $f 0 end
                set n [expr {[tell $f] - 40000}]
                if {$n < 0} {
                    set n 40000
                }
                seek $f $n
                # read the first partial line
                gets $f
                set system_content [string map $colorcodemap [read $f]]
            } on error {errorMsg} {
                # probably, output to console
                ns_log notice nsstats: $errorMsg
                set system_content ""
            } finally {
                if {[info exists f]} {
                    close $f
                }
            }
            set content "<font size=2><pre>[_ns_stats.log.prepare_content system $system_content]</pre></font>"
        }
    }

    try {
        set errorLogFiles [lsort -decreasing [glob [ns_info log].*]]
    } on error {errorMsg} {
        ns_log notice nsstats: $errorMsg
        set errorLogFiles {}
    }

    set tails [lmap file $errorLogFiles {
        if {[file size $file] < 10} continue
        file tail $file
    }]
    set options [join [lmap tail [list [file tail [ns_info log]] {*}$tails] {
        set selected [expr {"[file dirname $system_log]/$tail" eq $system_log ? " selected" : ""}]
        set _ "<option value='$tail'$selected>$tail</option>"
    }] \n]

    append html \
        [_ns_stats.header Log] \
        [ns_trim -subst -delimiter | {
            |<form id='logform' method='post' action='./nsstats.tcl'>Filter:
            |  <input type='hidden' name='@page' value='log.logfile'>
            |  <input name='filter' value='$filter' size='40'>
            |  <select name='system_log'>$options</select>
            |</form>
            |<script>
            |  const form = document.getElementById('logform');
            |  form.elements.system_log.addEventListener('change', function () {form.submit();});
            |</script>
        }] \
        $content \
        [_ns_stats.footer]

    return $html
}


set ::tips(module~nslog\$,checkforproxy) "Log peer address provided by X-Forwarded-For. (boolean)"
set ::tips(ns~db~pool~,checkinterval) "Check in this interval if handles are not stale. (time interval)"
set ::tips(ns~db~pool~,maxidle) "Close handles which are idle for at least this interval. (time interval)"
set ::tips(ns~db~pool~,maxopen) "Close handles which open longer than this interval. (time interval)"
set ::tips(ns~parameters\$,asynclogwriter) "Write logfiles (error.log and access.log) asynchronously via writer threads (boolean)"
set ::tips(ns~parameters\$,jobsperthread) "Default number of ns_jobs per thread (similar to connsperthread) (integer)"
set ::tips(ns~parameters\$,jobtimeout) "Default timeout for ns_job (time interval)"
set ::tips(ns~parameters\$,logexpanded) "Double-spaced error.log (boolean)"
set ::tips(ns~parameters\$,logmaxbackup) "The number of old error.log files to keep around if log rolling is enabled.(integer)"
set ::tips(ns~parameters\$,logroll) "If true, the log file will be rolled when the server receives a SIGHUP signal (boolean)"
set ::tips(ns~parameters\$,logusec) "If true, error.log entries will have timestamps with microsecond resolution (boolean)"
set ::tips(ns~parameters\$,schedlogminduration) "Write warning, when a scheduled proc takes more than this time interval (time interval)"
set ::tips(ns~parameters\$,schedsperthread) "Default number of scheduled procs per thread (similar to connsperthread) (integer)"
set ::tips(ns~server~\[^~\]+\$,compressenable) "Compress dynamic content per default. (boolean)"
set ::tips(ns~server~\[^~\]+\$,compresslevel) "Compression level, when compress is enabled. (integer 1-9)"
set ::tips(ns~server~\[^~\]+\$,compressminsize) "Compress dynamic content above this size. (integer)"
set ::tips(ns~server~\[^~\]+\$,connsperthread) "Number of requests per connection thread before it terminates. (integer)"
set ::tips(ns~server~\[^~\]+\$,hackcontenttype) "Force charset into content-type header for dynamic responses. (boolean)"
set ::tips(ns~server~\[^~\]+\$,highwatermark) "When request queue is full above this percentage, create potentially connection threads in parallel. (integer)"
set ::tips(ns~server~\[^~\]+\$,lowwatermark) "When request queue is full above this percentage, create an additional connection threads. (integer)"
set ::tips(ns~server~\[^~\]+\$,noticedetail) "Notice server details (version number) in HTML return notices. (boolean)"
set ::tips(~fastpath\$,directoryadp) "Name of directory ADP"
set ::tips(~fastpath\$,directoryproc) "Name of directory proc"
set ::tips(~module~,deferaccept) "TCP Performance option; use TCP_FASTOPEN or TCP_DEFER_ACCEPT or SO_ACCEPTFILTER. (boolean, false)"
set ::tips(~module~,keepwait) "Timeout for keep-alive. (time interval)"
set ::tips(~module~,closewait) "Timeout for close on socket to drain potential garbage if no keep alive is performed. (time interval)"
set ::tips(~module~,nodelay) "TCP Performance option; use TCP_NODELAY (OS-default on Linux). (boolean)"
set ::tips(~module~,writersize) "Use writer threads for replies above this size. (memory units)"
set ::tips(~module~,writerstreaming) "Use writer threads for streaming HTML output (e.g. ns_write ...). (boolean)"
set ::tips(~module~,writerthreads) "Number of writer threads. (integer)"
set ::tips(~tcl\$,errorlogheaders) "Connection headers to be logged in case of error (list)"


proc _ns_stats.skipConfigSection {sectionName} {
    if {[namespace which ::ns_configdoc::sectionSpec] eq ""} {
        return 0
    }

    set spec [::ns_configdoc::sectionSpec $sectionName]
    if {$spec eq ""} {
        return 0
    }
    #
    # Sections with "providesParamDoc" are helper/default sections whose
    # values are intended to be copied into real configuration sections
    # via ns_section -from.  In nsstats, the copied values are already
    # materialized in the target sections, so showing the helper section
    # would usually be redundant.
    #
    return [dict exists $spec :providesParamDoc]
}


proc _ns_stats.config.loadDocs {coreFile moduleRoots} {
    # Load the core reference first, then repository-owned installed dictionaries.
    # Missing optional documentation must not prevent displaying configuration.
    namespace eval ::ns_configdoc {}
    set ::ns_configdoc::data {}
    set loaded {}
    if {[file readable $coreFile]} {
        source $coreFile
        lappend loaded [file normalize $coreFile]
    }
    foreach root [lsort -unique $moduleRoots] {
        if {![file isdirectory $root]} {continue}
        foreach path [lsort [glob -nocomplain -directory $root */doc/tcl/config-parameters.tcl]] {
            set path [file normalize $path]
            if {$path in $loaded} {continue}
            set before $::ns_configdoc::data
            if {[catch {source $path} message]} {
                set ::ns_configdoc::data $before
                ns_log warning "nsstats: could not load parameter documentation $path: $message"
                continue
            }
            lappend loaded $path
        }
    }
    return $loaded
}

proc _ns_stats.config.params {} {
    set paramDocFile [file join [ns_info home] modules tcl config-parameters.tcl]
    _ns_stats.config.loadDocs $paramDocFile [list \
        [ns_library shared] [ns_library private] \
        [file join [ns_info home] tcl] [file join [ns_info home] modules tcl]]

    set out [list]
    foreach section [lsort [ns_configsections]] {
        # We want to have e.g. "aaa/pools" before "aaa/pool/foo",
        # therefore we map "/" to "" to put it in the collating sequence
        # after plain chars
        set sectionName [ns_set name $section]
        if {[_ns_stats.skipConfigSection $sectionName]} {
            continue
        }

        set tableName [string map {/ ~} $sectionName]

        try {
            set defaults [ns_configsection -filter defaults $sectionName]
            set defaulted [ns_configsection -filter defaulted $sectionName]
            set unread [ns_configsection -filter unread $sectionName]
        } on error {errorMsg} {
            set defaults {}
            set defaulted {}
            set unread {}
        }

        set keys {}
        for { set i 0 } { $i < [ns_set size $section] } { incr i } {
            set key [string tolower [ns_set key $section $i]]
            if {[ns_set isnull $section $i]} {
                # these are most likely parameters, which have just been queried for existence
                ns_log notice "DEBUG: ignore NULL value (section $sectionName key $key)"
                continue
            }
            set value [ns_set value $section $i]
            if {$defaults ne ""} {
                set default [ns_set iget $defaults $key]
                set isUnread [expr {[ns_set ifind $unread $key] == -1 ? "false" : "true"}]
                set isDefaulted [expr {[ns_set ifind $defaulted $key] > -1 ? "true" : "false"}]
            } else {
                set isDefaulted 0
                set isUnread 0
                set default ""
            }
            dict lappend keys $key [list value $value \
                                        default $default \
                                        defaulted $isDefaulted \
                                        unread $isUnread \
                                       ]
        }

        set line ""
        foreach section_key [lsort [dict keys $keys]] {
            set valueDicts [dict get $keys $section_key]

            #
            # Collect runtime defaults for this parameter first. Usually there is only
            # one, but repeated parameters may produce more.
            #
            set defaults {}
            foreach valueDict $valueDicts {
                set default [dict get $valueDict default]
                if {$default ne ""} {
                    lappend defaults $default
                }
            }
            set defaults [lsort -unique $defaults]
            set defaultForTooltip [join $defaults {, }]

            #
            # The parameter tooltip is still shown only when we have documentation.
            #
            set spec ""
            if {[namespace which ::ns_configdoc::get] ne ""} {
                set spec [::ns_configdoc::get $sectionName $section_key]
            }
            if {[namespace which ::ns_configdoc::tooltip] ne ""} {
                set tip [::ns_configdoc::tooltip $sectionName $section_key $defaultForTooltip]
            } else {
                set tip ""
            }

            set titleClasses {coltitle}

            if {$tip ne ""} {
                lappend titleClasses tip
            }

            if {$spec ne "" && [dict exists $spec deprecated]} {
                lappend titleClasses deprecated
            }
            set tipclass [expr {$tip ne "" ? "tip" : ""}]

            set values {}
            set classes {colvalue}
            set tooltip_text ""

            foreach valueDict $valueDicts {
                set value       [dict get $valueDict value]
                set default     [dict get $valueDict default]
                set isDefaulted [dict get $valueDict defaulted]
                set isUnread    [dict get $valueDict unread]

                if {$isDefaulted} {
                    lappend classes defaulted tooltip
                    set tooltip_text {<span class="tooltiptext">Value is default</span>}

                } elseif {$isUnread} {
                    lappend classes unread tooltip
                    set tooltip_text {<span class="tooltiptext">Value was not read during startup</span>}

                } elseif {$default ne "" && $default eq $value} {
                    lappend classes notneeded tooltip
                    set tooltip_text {<span class="tooltiptext">Value is set to default (not needed)</span>}
                }

                lappend values $value
            }

            lappend line "<tr><td title='[ns_quotehtml $tip]' class='[join [lsort -unique $titleClasses] { }]'>$section_key:</td>\n\
        <td class='[lsort -unique $classes]'>[join $values <br>]$tooltip_text</td></tr>"
        }
        set table($tableName) [join $line \n]
    }

    set order {
        ns~parameters ns~encodings ns~mimetypes ns~fastpath ns~threads .br
        ns~modules ns~module~.* .br
        ns~servers ns~server~.* .br
        ns~db~drivers ns~db~driver~* .br
        ns~db~pools ns~db~pool~* .br
    }

    set toc ""
    set sectionhtml ""
    foreach e $order {
        foreach section [lsort [array names table -regexp $e]] {
            set name [string map {~ /} $section]
            lappend toc "<a href='#ref-$name'>$name</a>"
            #set anchor "<a name='ref-$name'>$name</a>"
            append sectionhtml [ns_trim -delimiter | [subst {
                | <section id="ref-$name">
                |  <h2>$name</h2>
                |  <table class="data-table">
                |  <tr><th class="coltitle">Parameter</th><th class="coltitle">Value</th></tr>
                |   $table($section)
                |  </table>
                | </section>
            }]]
            unset table($section)
        }
    }
    if {[array size table] > 0} {
        # append sectionhtml "\n<tr><td colspan='2' class='colsection'><h2>Extra Parameters</h2></td></tr>\n\n"
        foreach section [lsort [array names table]] {
            set name [string map {~ /} $section]
            lappend toc "<a href='#ref-$name'>$name</a>"
            append sectionhtml [ns_trim -delimiter | [subst {
                | <section id="ref-$name">
                |  <h2>$name</h2>
                |  <table class="data-table">
                |  <tr><th class="coltitle">Parameter</th><th class="coltitle">Value</th></tr>
                |   $table($section)
                |  </table>
                | </section>
            }]]
        }
    }
    set ::sidebar [ns_trim -delimiter | [subst {
        |<div class="sidebar">
        |  <ul>
        |   <li>[join $toc </li>\n<li>]</li>\n
        |  </ul>
        | </div>
    }]]

    append html \
        [_ns_stats.header "Configuration Parameters"] \
        "<p class='summary'>The following values are defined in the configuration database:</p>" \
        "<div class='config values'>$sectionhtml</div>" \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.config.file {} {
    set config ""
    set configFile [ns_info config]
    if {$configFile ne ""} {
        catch {
            set f [open $configFile]
            set config [read $f]
            close $f
        }
    }
    append html \
        [_ns_stats.header Log] \
        "<font size=2><pre>[ns_quotehtml $config]</pre></font>" \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.mem.tcl {} {
    #
    # The following works just on Linux. The output is optional.
    #
    set meminfo [_ns_stats.memsizes [ns_info pid] 1]
    set html    [_ns_stats.header Memory]
    try {
        ns_info meminfo {*}[expr {[ns_queryget release 0] ? "-release" : ""}]
    } on ok {result} {
        #ns_log notice "meminfo result <$result>"
        if {[dict exists $result stats] && [dict get $result stats] ne ""} {
            append html [ns_trim -delimiter | [subst {
                |<h3>Memory Statistics from TCMalloc (Google Performance Tools)</h3>
                |<p>
                |<strong>Version:</strong> [dict get $result version]<br>
                |<strong>Loaded library:</strong> [dict get $result preload]<br>
                |<strong>Documentation:</strong>
                |<a href="https://github.com/google/tcmalloc/blob/master/docs/stats.md">Understanding Malloc Stats</a></br>
                |<strong>Memory reported from OS:</strong> $meminfo<br>
                |<pre>[dict get $result stats]</pre>
            }]] [_ns_stats.footer]
            return $html
        }
    } on error {errorMsg} {
        # ignore
    }

    set talloc 0
    set trequest 0
    set tused 0
    set tlocks 0
    set twaits 0
    set tfree 0
    set tops 0
    set ov 0
    set op 0
    set av 0

    if {[info commands ::dict] ne ""} {
        set trans [dict create]
        foreach thread [ns_info threads] {
            dict set trans thread0x[lindex $thread 2] [lindex $thread 0]
        }
    }
    append html \
        "\n<p><strong>Memory reported from OS:</strong> $meminfo</p>" \
        "\n<h4>Memory reported from the Tcl memory allocator:</h4>" \
        "<table border='0' cellpadding='0' cellspacing='0'>\n<tr><td valign=middle>\n"

    foreach p [lsort [ns_info pools]] {
        append html "\
        <b>[lindex $p 0]:</b>
        <b>[_ns_stats.dictGetDef $trans [lindex $p 0] {}]</b>
        <br><br>
        <table border=0 cellpadding=0 cellspacing=1 bgcolor=#cccccc width='100%'>
        <tr>
            <td valign=middle align=center>
            <table border=0 cellpadding=4 cellspacing=1 width='100%'>
            <tr>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Block Size</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Frees</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Gets</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Puts</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Bytes Req</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Bytes Used</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Overhead</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Locks</font></td>
                <td valign=middle bgcolor=#999999><font color=#ffffff>Lock Waits</font></td>
             </tr>"

        foreach b [lrange $p 1 end] {
            set bs [lindex $b 0]
            set nf [lindex $b 1]
            set ng [lindex $b 2]
            set np [lindex $b 3]
            set nr [lindex $b 4]
            set nu [expr {$ng - $np}]
            set na [expr {$nu * $bs}]

            incr tops [expr {$ng + $np}]
            incr tlocks [lindex $b 5]
            incr twaits [lindex $b 6]
            incr tfree [expr {$bs * $nf}]
            incr talloc $na
            incr trequest $nr
            incr tused $nu

            if {$nr != 0} {
                set ov [expr {$na - $nr}]
                set op [format %4.2f%% [expr {double($ov) * 100 / $nr}]]
            } else {
                set ov "N/A"
                set op "N/A"
            }

            append html "<tr>"

            foreach e [linsert [lreplace $b 4 4] 4 $nr $na $op] {
                append html "<td bgcolor=#ffffff>$e</td>"
            }

            append html "</tr>"
        }

        append html "\
                </table>
                </td>
        </tr>
        </table>
        <br>"
    }

    if { $trequest > 0 } {
        set ov [expr {$talloc - $trequest}]
        set op [format %4.2f [expr {double($ov) * 100 / $trequest}]]
    }
    if { $tops > 0 } {
        set av [format %4.2f [expr {double(100) - (double($tlocks) * 100) / $tops}]]
    }
    if { $tlocks > 0 } {
        set wr [format %4.2f [expr {double($twaits) / $tlocks}]]
    } else {
        set wr N/A
    }

    append html "\
        </td>
    </tr>
    <tr>
        <td valign=middle>
        <b>Totals:</b><br><br>
        <table>
            <tr><td>Bytes Requested:</td><td>$trequest</td></tr>
            <tr><td>Bytes Free:</td><td>$tfree</td></tr>
            <tr><td>Bytes Allocated:</td><td>$talloc</td></tr>
            <tr><td>Bytes Wasted:</td><td>$ov</td></tr>
            <tr><td>Byte Overhead:</td><td>${op}%</td></tr>
            <tr><td>Locks:</td><td>$tlocks</td></tr>
            <tr><td>Lock Waits:</td><td>$twaits</td></tr>
            <tr><td>Lock Wait Ratio:</td><td>${wr}%</td></tr>
            <tr><td>Gets/Puts:</td><td>${tops}</td></tr>
            <tr><td>Lock Avoidance:</td><td>${av}%</td></tr>
        </table>
        </td>
    </tr>
    </table>"

    append html [_ns_stats.footer]

    return $html
}

proc _ns_stats.process.table {values} {
    set html [subst {
        <table class="data-table w3-table w3-hoverable">
        <tr>
        <th valign="middle">Key</th>
        <th valign="middle">Value</th>
        </tr>
    }]
    foreach {key value} $values {
        append html [subst {
            <tr>
            <td class='coltitle'>$key</td>
            <td class='colvalue'>$value</td>
            </tr>}]
    }

    append html "</table>"
    return $html
}

proc _ns_stats.process.dbversion.format {type version} {
    if {![string is entier -strict $version] || $version <= 0} {
        return unknown
    }
    switch -- [string tolower $type] {
        sqlite {
            return [format %d.%d.%d [expr {$version / 1000000}] \
                        [expr {$version / 1000 % 1000}] [expr {$version % 1000}]]
        }
        postgresql - postgres {
            if {$version >= 100000} {
                return [format %d.%d [expr {$version / 10000}] [expr {$version % 10000}]]
            }
        }
    }
    # Other drivers and older PostgreSQL versions may use different encodings.
    return $version
}

proc _ns_stats.process.dbversion {pool} {
    set result "Versions: unavailable"
    # Pass a self-contained reader to worker interpreters, where this page's
    # helper procedures are not necessarily defined.
    set reader {{pool} {
        set handle ""
        try {
            # Zero means unlimited waiting in ns_db.
            set handle [ns_db gethandle -timeout 1ms -- $pool]
            if {$handle eq ""} {
                error "no free database handle within 1ms"
            }
            return [ns_db info $handle]
        } on error {message} {
            return [dict create _nsstats_error $message]
        } finally {
            if {$handle ne ""} {
                catch {ns_db releasehandle $handle}
            }
        }
    }}
    try {
        if {![catch {ns_db currenthandles} current] && [dict exists $current $pool]} {
            # nsdb limits pool acquisition per thread. Use another thread's
            # own connection; querying a request-owned handle could overwrite
            # its pending result (notably with nsdbpg's version query).
            set thread [ns_thread create [list apply $reader $pool]]
            set info [ns_thread wait $thread]
        } else {
            set info [apply $reader $pool]
        }
        if {[dict exists $info _nsstats_error]} {
            set result "Versions: unavailable ([ns_quotehtml [dict get $info _nsstats_error]])"
        } elseif {[dict exists $info clientversion] && [dict exists $info serverversion]} {
            set type [dict get $info type]
            set client [_ns_stats.process.dbversion.format $type [dict get $info clientversion]]
            set server [_ns_stats.process.dbversion.format $type [dict get $info serverversion]]
            set result "[ns_quotehtml $type]: client [ns_quotehtml $client], database [ns_quotehtml $server]"
        } else {
            set result "Versions: unavailable (driver does not expose version information)"
        }
    } on error {message} {
        # Thread creation and unsupported interfaces must not break the page.
        set result "Versions: unavailable ([ns_quotehtml $message])"
    }
    return $result
}

proc _ns_stats.process.modules {server} {
    if {[catch {ns_server -server $server modules} modules]} {
        # Older NaviServer releases only provide the registered module names.
        if {[catch {ns_ictl getmodules -server $server} names]} {
            return {}
        }
        return [list "Loaded Modules" [ns_quotehtml [lsort $names]]]
    }
    set poolDrivers {}
    if {![catch {_ns_stats.process.dbpoolnames $server} pools]} {
        foreach pool $pools {
            set driver [ns_config ns/db/pool/$pool driver ""]
            if {$driver ne ""} {lappend poolDrivers $driver}
        }
    }
    set columns {
        {} Module name Name type Type version Version tag Tag scope Scope
        file File
    }
    set html {<div class="w3-responsive"><table class="data-table modules w3-table w3-hoverable"><thead><tr>}
    foreach {key title} $columns {
        append html "<th>[ns_quotehtml $title]</th>"
    }
    append html {</tr></thead><tbody>}
    foreach module [lsort [dict keys $modules]] {
        set info [dict get $modules $module]
        if {[dict exists $info type] && [dict get $info type] eq "db-driver"} {
            if {![dict exists $info driver] || [dict get $info driver] ni $poolDrivers} {
                continue
            }
        }
        append html <tr>
        foreach {key title} $columns {
            set value ""
            if {$key eq ""} {
                set value $module
            } elseif {[dict exists $info $key]} {
                set value [dict get $info $key]
            }
            set cell [ns_quotehtml $value]
            if {$key eq "tag" && [dict exists $info name]} {
                # Metadata has no repository URL; only link known modules.
                set name [dict get $info name]
                set repository ""
                switch -- $name {
                    quic - nssock - nsssl - nscp - nsdb - nslog - nsproxy - nscgi - nsperm {
                        set repository naviserver
                    }
                    nsdbpg - nsdbsqlite - nsdns - nssmtpd {
                        set repository $name
                    }
                }
                set hash ""
                if {[regexp -- {-[0-9]+-g([0-9a-f]+)(?:[+]|-dirty)?$} $value . hash]
                    || [regexp {^([0-9a-f]{7,40})(?:[+]|-dirty)?$} $value . hash]} {
                    if {$repository ne ""} {
                        set cell "<a href='https://github.com/naviserver-project/$repository/commit/$hash'>$cell</a>"
                    }
                }
            }
            append html "<td>$cell</td>"
        }
        append html </tr>
    }
    append html {</tbody></table></div>}
    return [list "Loaded Modules" $html]
}

proc _ns_stats.process.dbpoolnames {server} {
    if {$server eq ""} {set server [ns_info server]}
    if {$server eq [ns_info server]} {
        set pools [ns_db pools]
    } else {
        # ns_db pools has no cross-server interface. Match dbinit's rules:
        # first configured value, wildcard or comma-separated known pools.
        set configured [ns_config ns/server/$server/db pools ""]
        set known [dict keys [ns_db stats]]
        set pools {}
        if {$configured eq "*"} {
            set pools $known
        } else {
            foreach pool [split $configured ,] {
                if {$pool in $known} {lappend pools $pool}
            }
        }
    }
    return [lsort -unique $pools]
}

proc _ns_stats.process.dbaccess {{server ""}} {
    if {$server eq ""} {set server [ns_info server]}
    if {[catch {_ns_stats.process.dbpoolnames $server} pools]} {return unavailable}
    if {[llength $pools] == 0} {return "{}"}
    return [join [lmap pool $pools {ns_quotehtml $pool}] {, }]
}

# Report local SQLite files without opening a database connection. The driver
# publishes the resolved datasource in the configuration; do not guess paths
# for older drivers or interpret SQLite URI and in-memory datasources as files.
proc _ns_stats.process.dbfilesize {pool} {
    set section ns/db/pool/$pool
    set driver [ns_config $section driver ""]
    set library [ns_config ns/db/drivers $driver ""]
    if {[file rootname [file tail $library]] ne "nsdbsqlite"} {
        return ""
    }
    set path [ns_config $section datasource ""]
    if {$path eq ":memory:"} {
        return "Database size: in-memory"
    }
    if {$path eq "" || [string match "file:*" $path] || [file pathtype $path] ne "absolute"} {
        return "Database file size: unavailable"
    }
    if {[catch {file size $path} bytes] || ![file isfile $path]} {
        return "Database file size: unavailable"
    }
    set result "Database file: [_ns_stats.hr $bytes]B ($bytes bytes)"
    foreach {suffix label} {-wal WAL -shm {shared memory}} {
        set auxiliary $path$suffix
        if {[file isfile $auxiliary] && ![catch {file size $auxiliary} bytes]} {
            append result ", $label: [_ns_stats.hr $bytes]B ($bytes bytes)"
        }
    }
    return $result
}

proc _ns_stats.process.dbpools {} {
    set lines ""
    if {![catch {set poolStats [ns_db stats]}]} {
        foreach {pool stats} $poolStats {
            set gethandles [dict get $stats gethandles]
            if {$gethandles > 0} {
                set avgWaitTime [expr {[dict get $stats waittime] / $gethandles}]
                lappend stats avgwaittime $avgWaitTime
            }
            set statements [dict get $stats statements]
            if {$statements > 0} {
                set avgSQLTime [expr {[dict get $stats sqltime] / $statements}]
                lappend stats avgsqltime $avgSQLTime
            }
            set stats [_ns_stats.pretty {statements gethandles {avgwaittime s} {avgsqltime s}} $stats %.1f]
            set versions [_ns_stats.process.dbversion $pool]
            set size [_ns_stats.process.dbfilesize $pool]
            if {$size ne ""} {
                append versions "<br>$size"
            }
            lappend lines "<tr><td class='subtitle'>[ns_quotehtml $pool]:</td><td width='100%'>$versions<br>$stats</td></tr>"
        }
    }
    return $lines
}
proc _ns_stats.process.callbacks {} {
    set lines ""
    foreach {entry} [ns_info callbacks] {
        lassign $entry type call
        set args [lrange $entry 2 end]
        lappend lines "<tr><td class='subtitle'>$type:</td><td>$call</td><td width='100%'>$args</td>"
    }
    return $lines
}

proc _ns_stats.redirect {url} {
    ns_log notice "RETURN REDIRECT <$url>"
    ns_returnredirect $url
    ns_log notice "RETURN REDIRECT <$url> DONE"
    if {[info commands ad_script_abort] ne ""} {
        #
        # Avoid automatic triggering of ADP interpretation when
        # running under OpenACS.
        #
        ad_script_abort
    }
}


proc _ns_stats.log.levels {} {
    set toggle [ns_queryget toggle ""]
    if {$toggle ne ""} {
        set old [ns_logctl severity $toggle]
        ns_logctl severity $toggle [expr {! $old}]
        _ns_stats.redirect [ns_conn url]?@page=[ns_queryget @page]
        return
    }
    set values {}
    set dict {1 on 0 off}
    foreach s [lsort [ns_logctl severities]] {
        set label [dict get $dict [ns_logctl severity $s]]
        lappend values $s "<a href='[ns_conn url]?@page=[ns_queryget @page]&toggle=$s'>$label</a>"
    }
    append html \
        [_ns_stats.header "Log Severity States"] \
        "<p>The following table shows the log severities along with their activation states:<p>\n" \
        [_ns_stats.process.table $values] \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.process.format_duration {duration nowms startTime} {
    return [_ns_stats.hr $duration]s
}

proc _ns_stats.process.running_scheds {} {
    set running [lmap j [ns_info scheduled] {
        if {![_ns_stats.isThreadRunning [lindex $j 1]]} continue; set j
    }]

    set results {}
    set now     [clock seconds]
    set nowms   [clock milliseconds]
    if {[llength $running] > 0} {
        ns_log notice "running $running"
    }

    foreach s $running {
        set id          [lindex $s 0]
        set flags       [lindex $s 1]
        set startTime   [lindex $s 5]
        set proc        [lindex $s 7]
        set arg         [lrange $s 8 end]
        set startFmt    [clock format [expr {int($startTime)}] -format {%H:%M:%S}]
        set duration    [expr {$now - $startTime}]
        set durationFmt [_ns_stats.process.format_duration $duration $nowms $startTime]
        lappend results "$id: start $startFmt - $proc $arg - duration $durationFmt"
    }
    return $results
}

proc _ns_stats.process.running_jobs {} {
    set results {}

    foreach ql [ns_job queuelist] {
        set numrunning [dict get $ql numrunning]
        if {$numrunning > 0} {
            set now   [clock seconds]
            set nowms [clock milliseconds]
            set queue [dict get $ql name]
            foreach jobinfo [ns_job joblist $queue] {
                set state [dict get $jobinfo state]
                if {$state eq "running"} {
                    set startTime   [dict get $jobinfo starttime]
                    set id          [dict get $jobinfo id]
                    set script      [dict get $jobinfo script]
                    set startFmt    [clock format [expr {int($startTime)}] -format {%H:%M:%S}]
                    set duration    [expr {$now - $startTime}]
                    set durationFmt [_ns_stats.process.format_duration $duration $nowms $startTime]
                    lappend results "$queue $id: start $startFmt - $script - duration $durationFmt"
                }
            }
        }
    }
    return $results
}

proc _ns_stats.memsizes {pid {pretty 0}} {
  #
  # return a dict of memory sizes of pid in number of 1K blocks
  #
  lassign {0 0 0} uss rss vsize
  if {[file readable /proc/$pid/statm]} {
    #
    # result in pages, typically 4K
    #
    set F [open /proc/$pid/statm]; set c [read $F]; close $F
    lassign $c vsize rss shared
    #set uss   [format %.2f [expr {($rss-$shared) * 4}]]
    set rss   [format %.2f [expr {$rss           * 4}]]
    set vsize [format %.2f [expr {$vsize         * 4}]]
  }
  if {$rss == 0} {
    set sizes [exec -ignorestderr /bin/ps -o vsz,rss $pid]
    set vsize [lindex $sizes end-1]
    set rss   [lindex $sizes end]
  }
  if {$pretty} {
      set rss [_ns_stats.hr [expr {$rss*1024}]]B
      set vsize [_ns_stats.hr [expr {$vsize*1024}]]B
  }
  return [list rss $rss vsize $vsize]
}

proc _ns_stats.lsof {pid} {
    try {
        foreach cmd {/bin/lsof /usr/bin/lsof /usr/sbin/lsof} {
            if {[file executable $cmd]} break
        }
        set result [split [exec -ignorestderr -- $cmd -n -P +p [pid] 2>/dev/null] \n]
    } on error {errorMsg} {
        set result {}
    }
    return $result
}

proc _ns_stats.process {} {
    set runtimeSnapshot [_ns_stats.runtimeSnapshot]
    if {[info commands ns_driver] ne ""} {
        #
        # Get certificates to report expire dates (assumes that the
        # command "openssl" is on the search path)
        #
        set certInfo {}
        set certificateLabel ""
        set driverInfo {}

        foreach entry [ns_driver info] {
            dict unset entry extraheaders
            lappend driverInfo [_ns_stats.pretty {recvbufsize sendbufsize} $entry %.2f]

            set module [dict get $entry module]
            if {[dict get $entry type] eq "nsssl"} {
                #
                # Use ns_certclt when available. This cmd includes as
                # well the certificates of mass virtual hosting. No
                # external programs are necessary.
                #
                if {[info commands ns_certctl] ne ""} {
                    lappend certInfo [join [lsort -unique [ns_certctl list]] <br>]
                    set certificateLabel "Loaded Certificates"
                } else {
                    set server [dict get $entry server]
                    if {$server ne ""} {
                        set certfile [ns_config ns/server/$server/module/$module certificate]
                    } else {
                        set certfile [ns_config ns/module/$module certificate]
                    }
                    if {![info exists processed($certfile)]} {
                        set notAfter [exec openssl x509 -enddate -noout -in $certfile]
                        regexp {notAfter=(.*)$} $notAfter . date
                        set days [expr {([clock scan $date] - [clock seconds])/(60*60*24.0)}]
                        lappend certInfo "Certificate $certfile will expire in [format %.1f $days] days"
                        set processed($certfile) 1
                    }
                    set certificateLabel "Configured Certificates"
                }
            }
        }
        lappend driverInfo {}
        #
        # Combine driver stats with certificate infos
        #
        foreach tuple [ns_driver stats] {
            lappend driverInfo [_ns_stats.pretty {received spooled partial} $tuple %.0f]
        }
        set driverInfo [list "Driver Info" [join $driverInfo <br>]]

    } else {
        set driverInfo ""
    }
    set certInfo [expr {$certificateLabel ne ""
                        ? [list $certificateLabel [join $certInfo <br>\n]]
                        : ""}]

    set tag [ns_info tag]
    if {[regexp {[-][0-9]+[-]g([0-9a-f]+)[+]?} $tag . hash]} {
        set tag "<a href='https://github.com/naviserver-project/naviserver/commit/$hash'>$tag</a>"
    } elseif {[regexp {([0-9a-f]+)[ +]} $tag . hash]} {
        set tag "<a href='https://bitbucket.org/naviserver/naviserver/commits/?search=$hash'>$tag</a>"
    }
    if {[regexp {([0-9a-f]+)[ +]} $tag . hash]} {
        set tag "<a href='https://bitbucket.org/naviserver/naviserver/commits/?search=$hash'>$tag</a>"
    }
    set version_info "$::tcl_platform(machine), $::tcl_platform(os) $::tcl_platform(osVersion)"
    try {
        set connect_info [ns_conn details]
        if {$connect_info ne ""} {
            append version_info ", connected via [ns_conn details]"
        }
        append version_info " from client [ns_conn peeraddr]"
    } on error {errorMsg} {
        ns_log notice "This version of NaviServer doesn't support ns_conn details: $errorMsg"
    }

    set proxyItems ""
    if {[info commands ns_proxy] ne ""} {
        #
        # Use catch for the time being to handle forward
        # compatibility (when no ns_proxy stats are available)
        #
        set pool ""
        if {[catch {
            foreach pool [lsort [ns_proxy pools]] {
                #
                # Get configure values and statistics
                #
                set configValues [ns_proxy configure $pool]
                set rawstats [ns_proxy stats $pool]
                set requests [dict get $rawstats requests]
                if {$requests > 0} {
                    set avgruntime [expr {[dict get $rawstats runtime] / $requests}]
                    lappend rawstats avgruntime $avgruntime
                }
                set resultstats [_ns_stats.pretty {requests {runtime s} {avgruntime s}} $rawstats %.2f]
                set active [join [lmap l [ns_proxy active $pool] {ns_quotehtml $l}] <br>]
                try {
                    set pidinfos {}
                    foreach pid [ns_proxy pids $pool] {
                        append pidinfos "$pid [list [_ns_stats.memsizes $pid 1]] "
                    }
                    set pidsrow "<tr><td class='subtitle'>Pids:</td><td class='colvalue'>$pidinfos</td></tr>"
                } on error {errorMsg} {
                    set pidsrow ""
                }
                try {
                    set workerinfos {}
                    set nrworkers [llength [ns_proxy workers $pool]]
                    set workerrow "<tr><td class='subtitle'>Workers:</td><td class='colvalue'><a href='?@page=proxy-workers&pool=$pool''>$nrworkers workers</a></td></tr>"
                } on error {errorMsg} {
                    set workerrow ""
                }
                set item ""
                append item \
                    "<tr><td class='subtitle'>Params:</td><td class='colvalue'>$configValues</td></tr>" \
                    "<tr><td class='subtitle'>Stats:</td><td class='colvalue'>$resultstats</td></tr>" \
                    $pidsrow \
                    $workerrow \
                    "<tr><td class='subtitle'>Active:</td><td class='colvalue'>$active</td></tr>"
                lappend proxyItems "nsproxy '$pool'" "<table>$item</table>"
            }

        } errorMsg]} {
            lappend proxyItems "nsproxy '$pool'" "<table>$errorMsg</table>"
        }
    }

    try {
        ns_http taskthreads
    } on ok {taskthreadinfo} {
    } on error {errorMsg} {
        set taskthreadinfo ""
    }

    try {
        ns_info buildinfo
    } on ok {buildinfo} {
    } on error {errorMsg} {
        set buildinfo ""
    }

    set processInfo [_ns_stats.memsizes [ns_info pid] 1]
    set t [clock milliseconds]; set F [open "|cat" w]; puts $F "timing-pipe-open+puts"; close $F
    dict set processInfo fork-time [expr {[clock milliseconds] - $t}]ms
    set values [list \
                    Version              "[ns_info patchlevel] (tag $tag) $buildinfo" \
                    "Build Date"          [ns_info builddate] \
                    Host                 "[ns_info hostname] ([ns_info address], Tcl $::tcl_patchLevel, $version_info)" \
                    "Boot Time"           [clock format [ns_info boottime] -format %c] \
                    Uptime                [_ns_stats.fmtSeconds [ns_info uptime]] \
                    Process              "[ns_info pid] [ns_info nsd] [list $processInfo]" \
                    "Open Files"          "<a href='?@page=list-lsof'>[llength [_ns_stats.lsof [ns_info pid]]]</a>" \
                    Home                  [ns_info home] \
                    Configuration         [ns_info config] \
                    "System Log"          [ns_info log] \
                    "Log Statistics"      [_ns_stats.pretty {Notice Warning Debug(sql)} [ns_logctl stats] %.0f] \
                    Servers               [join [lmap s [ns_info servers] {string cat "<a href='#$s'>$s</a>: [ns_config ns/servers $s]"}] <br>] \
                    {*}${driverInfo} \
                    {*}${certInfo} \
                    DB-Pools             "<table>[join [_ns_stats.process.dbpools]]</table>" \
                    Callbacks            "<table>[join [_ns_stats.process.callbacks]]</table>" \
                    {*}$proxyItems \
                    "Task Threads"        [join $taskthreadinfo <br>] \
                    "Socket Callbacks"    [join [ns_info sockcallbacks] <br>] \
                    "<a href='[_ns_stats.navigation.url background.sched]'>Running Scheduled Procs (repeated)</a>" [join [_ns_stats.process.running_scheds] <br>] \
                    "<a href='[_ns_stats.navigation.url background.jobs]'>Running Jobs</a>" [join [_ns_stats.process.running_jobs] <br>] \
                   ]

    set html [_ns_stats.header Process]
    append html [_ns_stats.utilization.sourcePanel [dict create coreSnapshot $runtimeSnapshot] process]
    append html [_ns_stats.process.table $values]

    foreach s [ns_info servers] {
        set requests ""; set addresses ""; set writerThreads ""; set spoolerThreads ""
        foreach driver [ns_driver names] {
            set section [ns_driversection -driver $driver -server $s]
            if {$section eq ""} continue
            set addr [ns_config_get_all ns/module/$driver/servers $s]
            if {$addr ne ""} {
                lappend addresses "$driver: $addr"
                lappend writerThreads $driver: [ns_config $section writerthreads 0]
                lappend spoolerThreads $driver: [ns_config $section spoolerthreads 0]
            } else {
                set port [ns_config $section port]
                if {$port ne ""} {
                    lappend addresses "$driver: [ns_config $section address]:$port"
                    lappend writerThreads $driver: [ns_config $section writerthreads 0]
                    lappend spoolerThreads $driver: [ns_config $section spoolerthreads 0]
                }
            }
        }
        set serverdir ""
        catch {set serverdir [ns_server -server $s serverdir]}

        #
        # Collect summative information
        #
        set total_server_requests 0
        foreach pool [lsort [ns_server -server $s pools]] {
            if {$runtimeSnapshot ne ""} {
                set poolName [expr {$pool eq "" ? "default" : $pool}]
                set rawstats [dict get $runtimeSnapshot servers $s pools $poolName counters]
            } else {
                set rawstats [ns_server -server $s -pool $pool stats]
            }
            dict set pool_info $s $pool rawstats $rawstats
            incr total_server_requests [dict get $rawstats requests]
        }

        #
        # Per connection pool information
        #
        set poolItems ""
        foreach pool [lsort [ns_server -server $s pools]] {
            #
            # Provide a nicer name for the pool.
            #
            set poolLabel "default"
            if {$pool ne {}} {
                set poolLabel $pool
            }

            #
            # Pool and server specific pool path. The empty pool name
            # has to be treated differently.
            #
            set config_path [expr {$pool eq "" ? "ns/server/$s" : "ns/server/$s/pool/$pool"}]

            #
            # Collect statistics
            #
            #ns_log notice "try to get [list dict get $pool_info $s $pool rawstats]"
            set rawstats [dict get $pool_info $s $pool rawstats]
            if {$runtimeSnapshot ne ""} {
                set poolName [expr {$pool eq "" ? "default" : $pool}]
                set gauges [dict get $runtimeSnapshot servers $s pools $poolName gauges]
                set threads [dict get $gauges threads]
                set waiting [dict get $gauges waitingRequests]
            } else {
                set threads [ns_server -server $s -pool $pool threads]
                set waiting [ns_server -server $s -pool $pool waiting]
            }
            set rawthreads [list {*}$threads \
                                waiting $waiting \
                                started [dict get $rawstats connthreads] \
                                maxconnections [ns_config $config_path maxconnections] \
                               ]
            if {$total_server_requests > 0} {
                set poolPercentage <br>[format %.2f%% [expr {100.0*[dict get $rawstats requests]/$total_server_requests}]]
            } else {
                set poolPercentage ""
            }

            set rawreqs [ns_server -server $s -pool $pool all]
            set reqs {}
            foreach req $rawreqs {
                set ts [expr {round([lindex $req end-1])}]
                if {$ts >= 60} {
                    lappend req [clock format [expr {[clock seconds] - $ts}] -format {%y/%m/%d %H:%M:%S}]
                } else {
                    lappend req .
                }
                lappend reqs [ns_quotehtml $req]
            }
            set reqs [join $reqs <br>]
            array set stats $rawstats
            set item \
                "<tr><td class='subtitle'>Connection Threads:</td><td class='colvalue' width='100%'>$rawthreads</td></tr>\n"
            if {$stats(requests) > 0} {
                incr stats(dropped) 0
                #
                # Take total time (except queue time) to calculate the
                # total number of requests that this pool can handle
                # based on collected data (when configured max threads
                # are running).
                #
                set avgTotalTime [expr {($stats(filtertime) + $stats(runtime) + $stats(tracetime)) / $stats(requests)}]
                if {$avgTotalTime > 0} {
                    set maxReqs [expr {[dict get $rawthreads max]/$avgTotalTime}]
                    append item "<tr><td class='subtitle'>Request Handling:</td>" \
                        "<td class='colvalue'>" \
                        "requests " [_ns_stats.hr $stats(requests) %.1f], \
                        " queued " [_ns_stats.hr $stats(queued) %1.f] \
                        " ([format %.2f [expr {$stats(queued)*100.0/$stats(requests)}]]%)," \
                        " spooled " [_ns_stats.hr $stats(spools) %1.f] \
                        " ([format %.2f [expr {$stats(spools)*100.0/$stats(requests)}]]%)," \
                        " dropped " [_ns_stats.hr $stats(dropped) %1.f] \
                        " possible-max-reqs " [_ns_stats.hr $maxReqs %1.1f]rps \
                        "</td></tr>\n"
                    append item "<tr><td class='subtitle'>Request Timing:</td>" \
                        "<td class='colvalue'>avg queue time [_ns_stats.hr [expr {$stats(queuetime)*1.0/$stats(requests)}]]s," \
                        " avg filter time [_ns_stats.hr [expr {$stats(filtertime)*1.0/$stats(requests)}]]s," \
                        " avg run time [_ns_stats.hr [expr {$stats(runtime)*1.0/$stats(requests)}]]s" \
                        " avg trace time [_ns_stats.hr [expr {$stats(tracetime)*1.0/$stats(requests)}]]s" \
                        "</td></tr>\n"
                }
            }
            append item \
                "<tr><td class='subtitle'>Active Requests:</td><td class='colvalue'>$reqs</td></tr>\n"
            set nrMapped [llength [ns_server -pool $pool map]]
            if {$nrMapped > 0} {
                append item \
                    "<tr><td class='subtitle'>Mapped:</td>" \
                    "<td class='colvalue'><a href='?@page=mapped&pool=$pool&server=$s'>$nrMapped</a></td></tr>\n"
            }
            lappend poolItems "Pool '$poolLabel' $poolPercentage" "<table>$item</table>"
        }

        set requestHandlers [ns_trim -delimiter | [subst {
            |Request Handlers:&nbsp;
            |<a href='?@page=requestprocs&server=$s'>[llength [ns_server -server $s requestprocs]]</a>,
            |URL to file mappings:
            |<a href='?@page=url2file&server=$s'>
            |   [llength [ns_server -server $s url2file]]
            |</a>}]]

        try {
            set serverlogdirEntry [list "Log Directory" [ns_server -server $s logdir]]
        } on error {errorMsg} {
            set serverlogdirEntry {}
        }

        set modulesEntry [_ns_stats.process.modules $s]

        set values [list \
                        "Address"            [join [lsort -unique $addresses] <br>] \
                        "Server Directory"   $serverdir \
                        {*}$serverlogdirEntry \
                        "Page Directory"     [ns_server -server $s pagedir] \
                        "Tcl Library"        [ns_server -server $s tcllib] \
                        "Access Log"         [ns_config ns/server/$s/module/nslog file] \
                        {*}$modulesEntry \
                        "Available DB-Pools"  [_ns_stats.process.dbaccess $s] \
                        "Writer Threads"     $writerThreads \
                        "Spooler Threads"    $spoolerThreads \
                        "Handlers"           $requestHandlers \
                        "Connection Pools"   [ns_server -server $s pools] \
                        {*}$poolItems \
                        "Active Writer Jobs" [join [lmap l [ns_writer list -server $s] {ns_quotehtml $l}] <br>] \
                        "Active Connchan Jobs" [join [lmap l [ns_connchan list -server $s] {ns_quotehtml $l}] <br>] \
                       ]

        append html \
            "<h2 id='$s'>Server '$s'</h2>" \n \
            [_ns_stats.process.table $values]
    }

    append html [_ns_stats.footer]

    return $html
}

proc _ns_stats.mapped.table {entries ctxIdx col numericSort reverseSort op} {
    set rows [_ns_stats.sortResults $entries [expr {$col - 1}] $numericSort $reverseSort]
    set htmlRows [lmap row $rows {
        lassign $row method url filter inherit
        set inheritArg [expr {$inherit eq "noinherit" ? "-noinherit" : ""}]
        set list [lmap cell $row { ns_quotehtml $cell }]
        set cmd [list $op {*}$inheritArg [list $method $url[expr {$filter ne "*" ? $filter : ""}]]]
        if {$ctxIdx ne "" && [lindex $row $ctxIdx] ne ""} {
            set cmd [list [lindex $cmd 0] [linsert [lindex $cmd 1] end [lindex $row $ctxIdx]]]
            #ns_log notice "CMD $cmd"
        }
        set href [ns_conn url]?[ns_conn query]&cmd=[ns_urlencode $cmd]
        lappend list "<a class='button' title='Delete this entry' href='[ns_quotehtml $href]'>$op</a>"
    }]
    return $htmlRows
}
proc _ns_stats.mapped.table-nomethod {entries ctxIdx col numericSort reverseSort op} {
    set rows [_ns_stats.sortResults $entries [expr {$col - 1}] $numericSort $reverseSort]
    set htmlRows [lmap row $rows {
        lassign $row url filter inherit
        set inheritArg [expr {$inherit eq "noinherit" ? "-noinherit" : ""}]
        set list [lmap cell $row { ns_quotehtml $cell }]
        set cmd [list $op {*}$inheritArg [list $url[expr {$filter ne "*" ? $filter : ""}]]]
        if {$ctxIdx ne "" && [lindex $row $ctxIdx] ne ""} {
            set cmd [list [lindex $cmd 0] [linsert [lindex $cmd 1] end [lindex $row $ctxIdx]]]
            #ns_log notice "CMD $cmd"
        }
        set href [ns_conn url]?[ns_conn query]&cmd=[ns_urlencode $cmd]
        lappend list "<a class='button' title='Delete this entry' href='[ns_quotehtml $href]'>$op</a>"
    }]
    return $htmlRows
}



proc _ns_stats.mapped {} {
    set col         [ns_queryget col 0]
    set reverseSort [ns_queryget reversesort 1]
    set pool        [ns_queryget pool [ns_conn pool]]
    set server      [ns_queryget server [ns_conn server]]
    set queryContext @page=[ns_queryget @page]&server=$server&pool=$pool

    set cmd         [ns_queryget cmd ""]
    if {[lindex $cmd 0] eq "unmap"} {
        #ns_log notice "CMD <ns_server -server $server -pool $pool {*}$cmd>"
        ns_server -server $server -pool $pool {*}$cmd
        _ns_stats.redirect [ns_conn url]?$queryContext&col=$col&reverseSort=$reverseSort
        return
    }

    set colTitles [list Method URL Filter Inheritance Context unmap]
    set mappings [lmap entry [ns_server -server $server -pool $pool map] {
        #ns_log notice "len entry [llength $entry]  llen colTitles [llength $colTitles]"
        if {[llength $entry] == 4} {
            lappend entry ""
        }
        set entry
    }]


    set htmlRows [_ns_stats.mapped.table \
                      $mappings \
                      4 $col 0 $reverseSort unmap]

    set poolName $pool
    if {$poolName eq ""} {set poolName default}
    set serverName $server
    if {$serverName eq ""} {set serverName default}

    append html \
        [_ns_stats.header [list Process "?@page=process"] Mapped] \
        "<h4>Server $serverName: Connection Pool mapping for pool <em>$poolName</em></h4>" \
        [_ns_stats.results process $col $colTitles ?$queryContext $htmlRows $reverseSort] \
        "<p>Back to <a href='?@page=process#[ns_urlencode $server]'>process</a></p>" \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.checkboxFilter {name boxes hidden} {
    set checkboxes [lmap box $boxes {
        lassign $box value label checked
        ns_trim -delimiter | [subst {
            | <input class="w3-check" name="$name" type="checkbox" value="$value" $checked>
            | <label >$label</label>
        }]
    }]
    set hiddenfields [lmap {key value} $hidden {
        subst { <input type="hidden" name="$key" value="$value">}
    }]
    return [ns_trim -delimiter | [subst {
        |<div class="$name">
        | Registered Methods:
        | <form class="w3-container" action="[ns_conn url]">
        |[join $checkboxes \n]
        |[join $hiddenfields \n]
        | <button type="submit" class="">Filter</button>
        | </form>
        |</div>}]]
}

proc _ns_stats.requestprocs {} {
    set col          [ns_queryget col 0]
    set reverseSort  [ns_queryget reversesort 1]
    set server       [ns_queryget server [ns_conn server]]
    set methodFilter [ns_querygetall methodfilter GET]
    set cmd          [ns_queryget cmd ""]
    set filterVars   [lmap selectedFilter $methodFilter {string cat methodfilter=$selectedFilter}]
    set queryContext @page=[ns_queryget @page]&server=$server&[join $filterVars &]

    if {[lindex $cmd 0] eq "unregister"} {
        #ns_log notice "CMD ns_unregister_op -server $server {*}[lindex $cmd 1]"
        ns_unregister_op -server $server {*}[lindex $cmd 1]
        _ns_stats.redirect [ns_conn url]?$queryContext&reverseSort=$reverseSort&col=$col
        return
    }

    set registeredHandlers [ns_server -server $server requestprocs]
    set registeredMethods [lsort -unique [lmap entry $registeredHandlers {lindex $entry 0}]]
    set filteredHandlers [lmap entry $registeredHandlers {
        if {[lindex $entry 0] ni $methodFilter} continue
        set entry
    }]
    set filterCheckboxes [lmap m $registeredMethods {
        list $m $m [expr {$m in $methodFilter ? "checked" : ""}]
    }]

    set numericSort 0
    set colTitles   [list Method URL Filter Inheritance Proc Arg unregister]

    set htmlRows [_ns_stats.mapped.table \
                      [lmap entry $filteredHandlers {
                          set reminder [lassign $entry method url filter inherit proc]
                          list $method $url $filter $inherit $proc $reminder
                      }] \
                      "" $col 0 $reverseSort unregister]

    set serverName $server
    if {$serverName eq ""} {set serverName default}

    set hidden {@page requestprocs}
    foreach var {server col reverseSort} {
        lappend hidden $var [set $var]
    }

    append html \
        [_ns_stats.header [list Process "?@page=process"] "Request Handlers"] \
        "<h4>Registered Request Handlers of Server <em>$serverName</em></h4>" \
        [_ns_stats.checkboxFilter methodfilter $filterCheckboxes $hidden] \
        [_ns_stats.results requestprocs $col $colTitles ?$queryContext $htmlRows $reverseSort] \
        "<p>Back to <a href='?@page=process#[ns_urlencode $server]'>process</a></p>" \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.url2file {} {
    set col          [ns_queryget col 0]
    set reverseSort  [ns_queryget reversesort 1]
    set server       [ns_queryget server [ns_conn server]]
    set cmd          [ns_queryget cmd ""]
    set queryContext @page=[ns_queryget @page]&server=$server

    if {[lindex $cmd 0] eq "unregister"} {
        #ns_log notice "CMD ns_unregister_url2file -server $server {*}[lindex $cmd 1]"
        ns_unregister_url2file -server $server {*}[lindex $cmd 1]
        _ns_stats.redirect [ns_conn url]?$queryContext&reverseSort=$reverseSort&col=$col
        return
    }

    set registeredHandlers [ns_server -server $server url2file]
    set registeredMethods [lsort -unique [lmap entry $registeredHandlers {lindex $entry 0}]]

    set numericSort 0
    set colTitles   [list URL Filter Inheritance Proc Arg unregister]

    set htmlRows [_ns_stats.mapped.table-nomethod \
                      [lmap entry $registeredHandlers {
                          set reminder [lassign $entry method url filter inherit proc]
                          list $url $filter $inherit $proc $reminder
                      }] \
                      "" $col 0 $reverseSort unregister]

    set serverName $server
    if {$serverName eq ""} {set serverName default}

    append html \
        [_ns_stats.header [list Process "?@page=process"] "Request-to-File Mappings"] \
        "<h4>Registered Url2File Mapping of Server <em>$serverName</em></h4>" \
        [_ns_stats.results requestprocs $col $colTitles ?$queryContext $htmlRows $reverseSort] \
        "<p>Back to <a href='?@page=process#[ns_urlencode $server]'>process</a></p>" \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.list-lsof-filter-lines {list match max} {
    set filtered [lmap line $list {if {![string match $match $line]} continue;set line}]
    if {[llength $filtered] > $max} {
        set filtered [lrange $filtered 0 $max-1]
    }
    return $filtered
}

proc _ns_stats.list-lsof {} {
    set all [ns_queryget all 0]
    set max [ns_queryget max 1000]
    set of [_ns_stats.lsof [ns_info pid]]
    if {$all} {
        set displayed [expr {[llength $of] > $max ? [lrange $of 0 $max-1] : $of}]
        set body [ns_trim -delimiter | [subst {
            |<strong>Number of Open Files:</strong> [llength $of] (max $max)
            |<p>(<a href='?@page=list-lsof&all=0'>filtered</a>)<p>
            |<pre>[join $displayed \n]</pre>
        }]]
    } else {
        set IPv4 [_ns_stats.list-lsof-filter-lines $of *IPv4* $max]
        set IPv6 [_ns_stats.list-lsof-filter-lines $of *IPv6* $max]
        set body [ns_trim -delimiter | [subst {
            |<strong>Number of Open Files:</strong> [llength $of]
            | (<a href='?@page=list-lsof&all=1'>all</a>)
            |<p>
        }]]
        try {
            ns_http keepalives
        } on ok {keepalives} {
            append body \
                "<strong>ns_http keep-alive slots:</strong>\n" \
                "<blockquote><pre>[join $keepalives \n]</pre></blockquote>\n"
        }

        if {[llength $IPv4] > 0} {
            append body \
                "<strong>IPv4 Sockets (current [llength $IPv4], max displayed $max):</strong>\n" \
                "<blockquote><pre>[join $IPv4 \n]</pre></blockquote>\n"
        }
        if {[llength $IPv6] > 0} {
            append body \
                "<strong>IPv6 Sockets (current [llength $IPv6], max displayed $max):</strong>\n" \
                "<blockquote><pre>[join $IPv6 \n]</pre></blockquote>\n"
        }
    }
    append html \
        [_ns_stats.header [list Process "?@page=process"] "Open Files"] \
        $body \
        "<p>Back to <a href='?@page=process'>process</a> page</p>" \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.proxy-workers {} {
    set col          [ns_queryget col 4]
    set reverseSort  [ns_queryget reversesort 1]
    set pool         [ns_queryget pool]
    set cmd          [ns_queryget cmd ""]
    set queryContext @page=[ns_queryget @page]&pool=$pool
    set workers      [ns_proxy workers $pool]
    set numericSort  1
    set colTitles    [list ID pid created runs state]
    if {$col == 0 || $col == 3} {
        set numericSort 1
    }
    set align [lrepeat [llength $colTitles] right]
    lset align 0 left
    lset align 4 left

    set results [lmap e $workers {
        list [dict get $e id] [dict get $e pid] [dict get $e created] [dict get $e runs] [dict get $e state]
    }]
    set rows [_ns_stats.sortResults $results [expr {$col - 1}] $numericSort $reverseSort]

    append html \
        [_ns_stats.header [list Process "?@page=process"] "nsproxy Workers"] \
        "<h4>[llength $results] nsproxy workers for pool <em>$pool</em></h4>" \
        [_ns_stats.results requestprocs $col $colTitles ?$queryContext $rows $reverseSort $align] \
        "<p>Back to <a href='?@page=process'>process</a> page</p>" \
        [_ns_stats.footer]
    return $html
}


proc _ns_stats.background.sched {} {
    set col             [ns_queryget col 1]
    set reverseSort     [ns_queryget reversesort 1]

    set numericSort     1
    set scheduledProcs  ""

    foreach s [ns_info scheduled] {
        set id          [lindex $s 0]
        set flags       [lindex $s 1]
        set next        [lindex $s 3]
        set lastqueue   [lindex $s 4]
        set laststart   [lindex $s 5]
        set lastend     [lindex $s 6]
        set proc        [lindex $s 7]
        set arg         [lrange $s 8 end]

        if {[catch {
            set duration [expr {$lastend - $laststart}]
        }]} {
            set duration 0
        }

        set state "pending"

        if {[_ns_stats.isThreadSuspended $flags]} {
            set state suspended
        }

        if {[_ns_stats.isThreadRunning $flags]} {
            set state running
        }

        lappend scheduledProcs [list $id $state $proc $arg $flags $lastqueue $laststart $lastend $duration $next]
    }

    set rows ""

    foreach s [_ns_stats.sortResults $scheduledProcs [expr {$col - 1}] $numericSort $reverseSort] {
        set id          [lindex $s 0]
        set state       [lindex $s 1]
        set flags       [join [_ns_stats.getSchedFlagTypes [lindex $s 4]] "<br>"]
        set next        [_ns_stats.fmtTime [lindex $s 9]]
        set lastqueue   [_ns_stats.fmtTime [lindex $s 5]]
        set laststart   [_ns_stats.fmtTime [lindex $s 6]]
        set lastend     [_ns_stats.fmtTime [lindex $s 7]]
        set proc        [lindex $s 2]
        set arg         [lindex $s 3]
        set duration    [_ns_stats.hr [lindex $s 8]]s

        lappend rows [list $id $state $proc $arg $flags $lastqueue $laststart $lastend $duration $next]
    }

    set colTitles [list ID Status Callback Data Flags "Last Queue" "Last Start" "Last End" Duration "Next Run"]
    set align [lrepeat [llength $colTitles] left]
    lset align end-1 right

    append html \
        [_ns_stats.header "Scheduled Procedures"] \
        [_ns_stats.results sched $col $colTitles ?@page=background.sched $rows $reverseSort $align] \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.log.chart.parse-httpclient {line} {
    set fields [split $line]
    set reused 0
    lassign $fields ts tz id status method url elapsed sent received cause
    set ts0 [string range $ts 1 end]
    #
    # Provide robustness when invalid URLs (containing unescaped
    # spaces) were used.
    #
    if {[llength $fields] > 10} {
        lassign [lrange $fields end-4 end] elapsed sent received reused cause
        set url [lrange $fields 5 end-5]
    }

    set host none
    try {
        # remove curly braces and quotes
        regexp {https?://([^/]+)/?} [lindex $url 0 0] . host
    } on error {errorMsg} {
        # remove curly braces
        regexp {https?://([^/]+)/?} [lindex $url 0] . host
    }

    return [list \
                ts0 $ts0 \
                id $id \
                status $status \
                method $method \
                host $host \
                url $url \
                elapsed $elapsed \
                sent $sent \
                received $received \
                reused $reused \
                cause $cause \
                errorLine [expr {$cause ne "ok" ? $line : ""}] \
               ]
}

proc _ns_stats.log.chart.parse-module/nssmtpd {line} {
    set fields [split $line]
    lassign $fields ts tz id status statuscode url elapsed sent sender rcpt
    set ts0 [string range $ts 1 end]
    #[25/Sep/2023:00:02:48 +0200] -sched:...- 250 SUCCESS [smtp.wu.ac.at]:25 0.009911 13313 sender RCPT: USER@HOST
    set host $url

    return [list \
                ts0 $ts0 \
                id $id \
                status $status \
                method "" \
                host $host \
                url $url \
                elapsed $elapsed \
                sent $sent \
                received 0 \
                reused 0 \
                cause "" \
                errorLine [expr {$statuscode ne "SUCCESS" ? $line : ""}] \
               ]
}

proc _ns_stats.log.chart {path section param title} {
    set logfiles [_ns_stats.log.logfiles $section $param]
    ns_log notice "nsstats: process $section $param log $path -> $logfiles"
    set t0 [clock milliseconds]

    set filesize [expr {[file exists $path] ? [file size $path] : 0}]
    if {$filesize < 10} {
        if {[llength $logfiles] > 0} {
            set path [lindex $logfiles 0]
            set logfiles [concat $path {*}[lreverse [lrange $logfiles 1 end]]]
        } else {
            return "<p>No $section $param log entries found in [ns_quotehtml $path]</p>"
        }
    }

    set F [open $path]; set logcontent [read $F]; close $F
    set count 0
    set hostInfos {}
    set errorLines {}

    foreach line [split $logcontent \n] {
        #if {$count>10} break
        if {[string length $line] < 15} {
            break
        }
        incr count
        set data [_ns_stats.log.chart.parse-$section $line]
        try {
            dict with data {
                #
                # Convert time to UTC format for JavaScript: 13/Nov/2022:00:19:49 +0100
                #
                # The timestgamp "ts" in JavaScript (result of Data.parse())
                # is the time since January 1, 1970 in milliseconds
                #
                set ts [clock scan $ts0 -gmt 1 -format {%d/%b/%Y:%H:%M:%S}]

                dict lappend responsetime $host $ts $elapsed
                dict incr requestcount0 [list $host $ts]
                if {[dict exists $hostInfos $host]} {
                    set hostInfo [dict get $hostInfos $host]
                } else {
                    set hostInfo {}
                }
                dict incr hostInfo sent $sent
                dict incr hostInfo received $received
                dict incr hostInfo count
                dict incr hostInfo reused $reused
                dict incr hostInfo $status
                if {[dict exists $hostInfo elapsed]} {
                    dict set hostInfo elapsed [expr {[dict get $hostInfo elapsed] + $elapsed}]
                } else {
                    dict set hostInfo elapsed $elapsed
                }
                dict set hostInfos $host $hostInfo
                dict set statusCodes $status 1
                if {$errorLine ne ""} {
                    lappend errorLines $errorLine
                }
            }
        } on error {errorMsg} {
            ns_log warning _ns_stats.log.chart: cannot parse <$line>: $errorMsg
            continue
        }
    }
    set t1 [clock milliseconds]
    set responsetimeSeries {}
    foreach key [lsort [dict keys $responsetime]] {
        set values [join [lmap {ts value} [dict get $responsetime $key] {
            subst -nocommands {[${ts}000, $value]}
        }] ",\n"]
        lappend responsetimeSeries [subst -nocommands {
            {
                name: '$key',
                data:[$values]
            }
        }]
    }
    set requestcount {}
    foreach key [lsort [dict keys $requestcount0]] {
        lassign $key host ts
        dict lappend requestcount $host $ts [dict get $requestcount0 $key]
    }
    set requestcountSeries {}
    foreach key [dict keys $requestcount] {
        set values [join [lmap {ts value} [dict get $requestcount $key] {
            subst -nocommands {[${ts}000, $value]}
        }] ",\n"]
        lappend requestcountSeries [subst -nocommands {
            {
                name: '$key',
                data:[$values]
            }
        }]
    }

    set responsetimeSeries [join $responsetimeSeries ,]
    set requestcountSeries [join $requestcountSeries ,]
    set JS [subst -nocommands {
        Highcharts.chart('responsetime', {
            chart: {
                type: 'lollipop'
            },
            title: {
                text: '$title - Response Time Overview'
            },
            xAxis: {
                type: 'datetime',
            },
            yAxis: {
                title: {text: 'Seconds'}
            },
            series: [$responsetimeSeries]
        });
        Highcharts.chart('requestcount', {
            chart: {
                type: 'lollipop'
            },
            title: {
                text: '$title - Requests per Second'
            },
            subtitle: {
                text: "Total number of requests: $count"
            },
            xAxis: {
                type: 'datetime',
            },
            yAxis: {
                title: {text: 'Count'}
            },
            series: [$requestcountSeries]
        });
    }]
    set codes [lsort [dict keys $statusCodes]]
    foreach host [dict keys $hostInfos] {
        foreach code $codes {
            if {![dict exists $hostInfos $host $code]} {
                dict set hostInfos $host $code 0
            }
        }
    }
    set data [subst {
        <table class="table table-striped fs-3 bg-white"><tr>
        <th class="fs-6">Host</th>
        <th class="fs-6 text-end">Requests</th>
        <th class="fs-6 text-end">Avg Time</th>
        <th class="fs-6 text-end">Sent</th>
        [expr {$section eq "httpclient" ? {
            <th class="fs-6 text-end">Received</th>
            <th class="fs-6 text-end">Reused</th>} : ""}]
        [join [lmap code $codes {set _ "<th class='fs-6 text-end'>$code</th>"}]]
        </tr>
    }]
    foreach host [lsort [dict keys $hostInfos]] {
        set avg [expr {[dict get $hostInfos $host elapsed]/[dict get $hostInfos $host count]}]
        append data [subst {<tr>
            <td class="fs-6">$host</td>
            <td class="fs-6 text-end">[dict get $hostInfos $host count]</td>
            <td class="fs-6 text-end">[_ns_stats.hr $avg]s</td>
            <td class="fs-6 text-end">[_ns_stats.hr [dict get $hostInfos $host sent]]B</td>
            [expr {$section eq "httpclient"
                   ? [subst {<td class="fs-6 text-end">[_ns_stats.hr [dict get $hostInfos $host received]]B</td>
                       <td class="fs-6 text-end">[dict get $hostInfos $host reused]</td>
                   }] : ""}]
            [join [lmap code $codes {set _ "<td class='fs-6 text-end'>[dict get $hostInfos $host $code]</td>"}]]
            </tr>
        }]
    }
    set fileform [_ns_stats.log.fileform $logfiles $path [ns_queryget @page ""]]
    set t2 [clock milliseconds]
    ns_log notice "nsstats: parse data [expr {$t1-$t0}]ms, graph and table built [expr {$t2-$t1}]ms"

    if {[llength $errorLines] > 0} {
        set errorLines [ns_trim -delimiter | [subst {
            |<h4>Errors:</h4>
            |<hr><pre>[join $errorLines \n]</pre><hr>
        }]]
    }
    return [subst {
        <div id='responsetime'></div>
        <div id='requestcount'></div>
        <script>$JS</script>
        <div class="container">
        <h4>Summative Statistics</h4>
        $data
        </table>
        $errorLines
        <h4>Show other logfile</h4>
        $fileform
        <p>
        </div>
    }]
}

proc _ns_stats.log.logfiles {section param} {
    return [lsort [concat {*}[lmap s [ns_info servers] {
        set logfile [ns_config ns/server/$s/$section $param]
        if {$logfile eq "" || ![file exists $logfile]} {
            continue
        }
        lmap file [glob $logfile*] {
            # An empty active log must remain selectable after rotation.
            if {![file isfile $file] || ![file readable $file]} continue
            set file
        }
    }]]]
}

proc _ns_stats.log.httpclient {} {
    return [_ns_stats.log.mkchart httpclient logfile "HTTP Client Log"]
}
proc _ns_stats.log.smtpsent {} {
    return [_ns_stats.log.mkchart module/nssmtpd logfile "SMTP Sent Log"]
}
proc _ns_stats.log.smtpevents {} {
    return [_ns_stats.log.mkchart module/nssmtpd eventlogfile "SMTP Events" \
                _ns_stats.log.smtpevents.chart]
}

proc _ns_stats.log.chart.parse-smtpevents {line} {
    set fields [split $line " "]
    lassign $fields date zone thread code event peer session transaction server sender recipient action reason targets
    if {[llength $fields] < 14 || [regexp {[\r\n]} $line]
        || ![regexp {^(-|[1-5][0-9]{2})$} $code]
        || ![regexp {^[a-z0-9_-]+$} $event]
        || ![string is integer -strict $transaction]} {
        error {invalid event record}
    }
    set timestamp [expr {1000 * [clock scan [string range "$date $zone" 1 end-1] \
                                   -format {%d/%b/%Y:%H:%M:%S %z}]}]
    foreach name {server sender recipient action reason targets code} {
        if {[set $name] eq "-"} {set $name ""}
    }
    set metadata {}
    foreach field [lrange $fields 14 end] {
        if {[regexp {^([a-z0-9-]+)=(.*)$} $field -> key value]
            && ($key in {last-command message-bytes relay-accepted relay-reply recipients findings policy-rule
                         link-status link-limit link-host-mismatch link-embedded-redirect link-destination-hosts link-destination-limit dkim-obsolete-algorithm spf-result spf-peer spf-helo spf-errorcode dkim-signatures dkim-status dkim-limit}
                || [regexp {^dkim-[1-8]-(domain|selector|key|verification|algorithm|algorithm-status)$} $key])} {
            # Decode the writer's byte escapes without evaluating log content.
            set decoded ""
            while {[regexp -indices {\\x[0-9a-fA-F]{2}} $value match]} {
                lassign $match first last
                append decoded [string range $value 0 $first-1] \
                    [format %c [scan [string range $value $first+2 $last] %x]]
                set value [string range $value $last+1 end]
            }
            dict set metadata $key $decoded$value
        }
    }
    return [dict create timestamp $timestamp thread $thread server $server \
        session $session transaction $transaction peer [string range $peer 1 end-1] \
        sender $sender event $event recipient $recipient action $action reason $reason \
        code $code targets [expr {$targets eq "" ? {} : [split $targets ,]}] metadata $metadata]
}

proc _ns_stats.log.smtpevents.read {path filter} {
    set rows {}
    set counts {}
    set buckets {}
    set total 0
    set invalid 0
    set filter [string tolower $filter]
    set channel [open $path r]
    fconfigure $channel -encoding utf-8
    try {
        while {[gets $channel line] >= 0} {
            if {$line eq ""} {continue}
            try {
                set record [_ns_stats.log.chart.parse-smtpevents $line]
            } on error {message options} {
                incr invalid
                continue
            }
            if {[dict get $record event] in {transaction authentication}} {
                # Fold transaction-wide details into retained rows before
                # filtering: they have no recipient but must join alias searches.
                set joined {}
                foreach row $rows {
                    if {[dict get $row server] eq [dict get $record server]
                        && [dict get $row session] eq [dict get $record session]
                        && [dict get $row transaction] eq [dict get $record transaction]} {
                        set field [expr {[dict get $record event] eq "transaction" ? "outcome" : "authentication"}]
                        dict set row $field $record
                    }
                    lappend joined $row
                }
                set rows $joined
                continue
            }
            set searchable {}
            foreach key {server session transaction peer sender event recipient action reason targets} {
                lappend searchable [dict get $record $key]
            }
            if {$filter ne "" && [string first $filter [string tolower [join $searchable " "]]] < 0} {continue}
            incr total
            set event [dict get $record event]
            set action [dict get $record action]
            set reason [dict get $record reason]
            dict incr counts [list $event $action $reason]
            set minute [expr {[dict get $record timestamp] / 60000 * 60000}]
            # Separate denominators: policies and alias events are not RCPT attempts.
            if {$event eq "recipient" && $action in {accept defer reject}} {
                dict incr buckets [list recipient $action $minute]
            }
            # Consolidated recipient events and historical greylist records.
            if {$event eq "recipient" && [string match greylist-* $reason]} {
                set reason [string range $reason 9 end]
                if {$reason ni {new early retry known expired capacity}} {set reason other}
                dict incr buckets [list greylist $reason $minute]
            } elseif {$event eq "greylist"} {
                if {$reason ni {new early retry known expired capacity}} {set reason other}
                dict incr buckets [list greylist $reason $minute]
            }
            lappend rows $record
            if {[llength $rows] > 200} {set rows [lrange $rows end-199 end]}
        }
    } finally {close $channel}
    return [dict create rows $rows counts $counts buckets $buckets total $total invalid $invalid]
}

proc _ns_stats.log.smtpevents.series {buckets event categories} {
    set series {}
    foreach category $categories {
        set points {}
        dict for {key count} $buckets {
            lassign $key kind label minute
            if {$kind eq $event && $label eq $category} {
                lappend points [list $minute $count]
            }
        }
        set data {}
        foreach point [lsort -integer -index 0 $points] {
            lassign $point minute count
            lappend data "\[$minute,$count\]"
        }
        # Categories are fixed literals; only integers enter the JavaScript data.
        lappend series "{name:'$category',data:\[[join $data ,]\]}"
    }
    return [join $series ,]
}

proc _ns_stats.log.smtpevents.chart {path section param title} {
    set files [_ns_stats.log.logfiles $section $param]
    set filter [ns_queryget filter ""]
    set report [_ns_stats.log.smtpevents.read $path $filter]
    set html [_ns_stats.log.fileform $files $path log.smtpevents [dict create filter $filter]]
    append html {<p>Recipient counts describe SMTP RCPT attempts, not delivered messages.
        Greylisting deferrals are not spam classifications. Filter matches peer, sender,
        original recipient, targets, session, transaction, event, action, or reason.</p>}
    set recipientSeries [_ns_stats.log.smtpevents.series [dict get $report buckets] recipient {accept defer reject}]
    set greySeries [_ns_stats.log.smtpevents.series [dict get $report buckets] greylist {new early retry known expired capacity other}]
    append html "<div id=\"smtp-recipient-events\"></div><div id=\"smtp-greylist-events\"></div><script>\
        Highcharts.chart('smtp-recipient-events', {chart:{type:'column'}, title:{text:'Recipient decisions per minute'},\
        xAxis:{type:'datetime'}, yAxis:{title:{text:'RCPT attempts'},allowDecimals:false}, series:\[$recipientSeries\]});\
        Highcharts.chart('smtp-greylist-events', {chart:{type:'column'}, title:{text:'Greylisting events per minute'},\
        xAxis:{type:'datetime'}, yAxis:{title:{text:'Events'},allowDecimals:false}, series:\[$greySeries\]});</script>"
    append html {<h4>Event totals</h4><table class="table"><tr><th>Event</th><th>Action</th><th>Reason</th><th>Count</th></tr>}
    dict for {key count} [dict get $report counts] {
        append html <tr>
        foreach value [list {*}$key $count] {append html "<td>[ns_quotehtml $value]</td>"}
        append html </tr>
    }
    append html "</table><p>[dict get $report total] matching events; showing the last 200 at most. \
        [dict get $report invalid] malformed or unsupported records skipped.</p>"
    set rows [lreverse [dict get $report rows]]
    set servers [lsort -unique [lmap row $rows {dict get $row server}]]
    if {[llength $servers] == 1} {
        append html "<p>Server: [ns_quotehtml [lindex $servers 0]]</p>"
    }
    append html {<div class="table-responsive"><table class="table table-sm text-nowrap"><thead><tr><th>Time</th><th>Peer</th><th>Sender</th><th>Recipient</th><th>Event</th><th>Action</th><th>Reason</th><th>Code</th><th>Details</th></tr></thead><tbody>}
    set previousDate ""
    foreach row $rows {
        set seconds [expr {[dict get $row timestamp] / 1000}]
        set date [clock format $seconds -format {%Y-%m-%d %z}]
        set timestamp [clock format $seconds -format {%Y-%m-%d %H:%M:%S %z}]
        if {$date ne $previousDate} {
            append html "<tr class=\"table-light\"><th colspan=\"9\" scope=\"rowgroup\">[ns_quotehtml $date]</th></tr>"
            set previousDate $date
        }
        append html "<tr><td title=\"[ns_quotehtml $timestamp]\">[clock format $seconds -format {%H:%M:%S}]</td>"
        foreach key {peer sender recipient event action reason code} {
            set value [ns_quotehtml [dict get $row $key]]
            if {$key in {peer sender recipient reason}} {
                # Keep the full value in the DOM for copying, and in the
                # disclosure below for keyboard/touch access without hovering.
                append html "<td><span class=\"d-inline-block text-truncate align-middle\" style=\"max-width: 24ch\" title=\"$value\">$value</span>"
                if {$key eq "recipient" && [dict get $row event] eq "alias"
                    && [dict get $row action] eq "expand"} {
                    foreach target [dict get $row targets] {
                        append html "<div class=\"text-wrap\" style=\"width: 24ch; overflow-wrap: anywhere\">&#8594; [ns_quotehtml $target]</div>"
                    }
                }
                append html </td>
            } else {
                append html "<td>$value</td>"
            }
        }
        append html {<td><details><summary>Details</summary><dl class="mb-0 text-wrap" style="width: 24rem; max-width: 60vw; overflow-wrap: anywhere">}
        append html "<dt>Time</dt><dd>[ns_quotehtml $timestamp]</dd>"
        foreach {key label} {server Server session Session transaction Transaction peer Peer sender Sender recipient Recipient reason Reason targets Targets} {
            set value [dict get $row $key]
            if {$key eq "targets"} {set value [join $value {, }]}
            append html "<dt>$label</dt><dd>[ns_quotehtml $value]</dd>"
        }
        if {[dict exists $row metadata recipients] && ![catch {llength [dict get $row metadata recipients]}]} {
            append html "<dt>Expanded recipients</dt><dd>[ns_quotehtml [join [dict get $row metadata recipients] {, }]]</dd>"
        }
        if {[dict exists $row metadata findings]} {
            set findings [dict get $row metadata findings]
            if {![catch {dict size $findings}] && [dict size $findings] > 0} {
                append html {<dt>Policy findings</dt><dd>Observations used or collected by the policy chain.</dd>}
                dict for {key value} $findings {
                    append html "<dt>[ns_quotehtml $key]</dt><dd>[ns_quotehtml $value]</dd>"
                }
            }
        }
        if {[dict exists $row authentication]} {
            append html {<dt>Authentication and link diagnostics</dt><dd>Informational; DKIM signatures are not cryptographically verified.</dd>}
            dict for {key value} [dict get $row authentication metadata] {
                append html "<dt>[ns_quotehtml $key]</dt><dd>[ns_quotehtml $value]</dd>"
            }
        }
        if {[dict exists $row outcome]} {
            set outcome [dict get $row outcome]
            append html "<dt>Transaction outcome</dt><dd>[ns_quotehtml [dict get $outcome reason]]</dd>"
            append html "<dt>Ended</dt><dd>[ns_quotehtml [clock format [expr {[dict get $outcome timestamp] / 1000}] -format {%Y-%m-%d %H:%M:%S %z}]]</dd>"
            foreach {key label} {last-command {Last SMTP command} message-bytes {Message bytes (wire DATA)} relay-accepted {Relay accepted} relay-reply {Relay reply}} {
                if {[dict exists $outcome metadata $key]} {
                    append html "<dt>$label</dt><dd>[ns_quotehtml [dict get $outcome metadata $key]]</dd>"
                }
            }
        } else {
            append html {<dt>Transaction outcome</dt><dd>Not recorded in this log</dd>}
        }
        append html </dl></details></td></tr>
    }
    append html </tbody></table></div>
    return $html
}

# Shared selector for request logs and event logs. Full paths distinguish logs
# from different servers; mkchart also accepts legacy basename query values.
proc _ns_stats.log.fileform {files selected page {filters {}}} {
    set options {}
    foreach path $files {
        set attribute [expr {$path eq $selected ? "selected" : ""}]
        append options "<option value=\"[ns_quotehtml $path]\" $attribute>[ns_quotehtml $path]</option>"
    }
    set html "<form action=\"nsstats.tcl\" class=\"row g-1\">\
        <input type=\"hidden\" name=\"@page\" value=\"[ns_quotehtml $page]\">\
        <div class=\"col\"><label>Log <select class=\"form-select\" name=\"logfile\">$options</select></label></div>"
    dict for {name value} $filters {
        append html "<div class=\"col\"><label>[ns_quotehtml [string totitle $name]] \
            <input class=\"form-control\" name=\"[ns_quotehtml $name]\" value=\"[ns_quotehtml $value]\"></label></div>"
    }
    append html {<div class="col"><button type="submit" class="btn btn-outline-secondary">Show</button></div></form>}
    return $html
}

proc _ns_stats.log.mkchart {section param title {renderer _ns_stats.log.chart}} {
    set ::extraHeadEntries {
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN" crossorigin="anonymous">
        <script src="https://code.highcharts.com/highcharts.js"></script>
        <script src="https://code.highcharts.com/modules/exporting.js"></script>
        <script src="https://code.highcharts.com/modules/export-data.js"></script>
        <script src="https://code.highcharts.com/highcharts-more.js"></script>
        <script src="https://code.highcharts.com/modules/dumbbell.js"></script>
        <script src="https://code.highcharts.com/modules/lollipop.js"></script>
    }

    set configured_logfile [ns_config ns/server/[ns_info server]/$section $param ""]
    if {$configured_logfile eq ""} {
        set HTML "<p>No $section $param logfiles configured</p>"
    } else {
        set files [_ns_stats.log.logfiles $section $param]
        set selected_logfile [ns_queryget logfile ""]
        if {$selected_logfile eq ""} {
            set logfile $configured_logfile
            if {$logfile ni $files} {set logfile [lindex $files 0]}
        } else {
            set logfile $selected_logfile
            if {[file tail $selected_logfile] eq $selected_logfile} {
                set logfile [file join [file dirname $configured_logfile] $selected_logfile]
            }
        }
        # Restrict all renderers to configured log files and discovered rotations.
        if {$logfile eq "" || $logfile ni $files} {
            set HTML {<p>No matching log file available.</p>}
        } else {
            try {
                set HTML [{*}$renderer $logfile $section $param $title]
            } on error {message options} {
                set HTML "<p>Cannot read log: [ns_quotehtml $message]</p>"
            }
        }
    }
    append html \
        [_ns_stats.header $title] \
        $HTML \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.threadCpuPercentages {sampleKey {snapshot {}}} {
    if {$snapshot eq ""} {
        set snapshot [_ns_stats.runtimeSnapshot]
    }
    set pid         [pid]
    set rawThreads  [ns_info threads]
    set cpuSource   none
    set cpuTimes    {}
    set collected   {}
    set current     [dict create threads {} collectorMode [expr {[_ns_stats.sampled $snapshot] ? "sample" : ($snapshot eq "" ? "legacy" : "snapshot")}]]
    set cpuAvailable 0

    #
    # Older NaviServer versions do not include the OS TID.
    #
    if {[llength $rawThreads] == 0
        || [llength [lindex $rawThreads 0]] <= 7} {
        return [dict create \
                    available 0 \
                    elapsed   0.0 \
                    rows      $rawThreads \
                    byThread  {}]
    }

    if {$snapshot ne ""} {
        if {[_ns_stats.dictGetDef $snapshot availability cpu false]} {
            set cpuSource core
        }
    } else {
        try {
            set cpuTimes [ns_info threadcputimes]
            set cpuSource api
        } on error {errorMsg} {
            if {[file isdirectory /proc/$pid/task]} {
                set cpuSource proc
                set HZ 100
            }
        }
    }

    if {$cpuSource eq "none"} {
        return [dict create \
                    available 0 \
                    elapsed   0.0 \
                    rows      $rawThreads \
                    byThread  {}]
    }
    set cpuAvailable 1

    #
    # Collect the current cumulative CPU counters.
    #
    foreach t $rawThreads {
        set name       [lindex $t 0]
        set parent     [lindex $t 1]
        set createTime [lindex $t 4]
        set tid        [lindex $t 7]
        set state      0
        set utime      0.0
        set stime      0.0
        set valid      0

        if {$cpuSource eq "core"} {
            set identity [list $tid $createTime]
            if {[dict exists $snapshot cpu $identity]} {
                set times [dict get $snapshot cpu $identity]
                set utime [expr {[dict get $times user] / 1000000.0}]
                set stime [expr {[dict get $times system] / 1000000.0}]
                set state [_ns_stats.dictGetDef $times state 0]
                set valid 1
            }
        } elseif {$cpuSource eq "api"} {
            if {[dict exists $cpuTimes $tid]} {
                set times [dict get $cpuTimes $tid]

                set utime [expr {
                    [dict get $times user] / 1000000.0
                }]
                set stime [expr {
                    [dict get $times system] / 1000000.0
                }]

                if {[dict exists $times state]} {
                    set state [dict get $times state]
                }
                set valid 1
            }

        } elseif {$cpuSource eq "proc"} {
            set filename /proc/$pid/task/$tid/stat

            if {[file readable $filename]} {
                set f [open $filename]
                set s [read $f]
                close $f

                #
                # This retains the current parser. A separate improvement
                # could parse the parenthesized comm field more defensively.
                #
                lassign $s statTid comm state ppid pgrp session ttyNr tpgid \
                    flags minflt cminflt majflt cmajflt userJiffies systemJiffies \
                    cutime cstime priority nice numthreads itrealval \
                    starttime vsize rss rsslim startcode endcode \
                    startstack kstkesp kstkeip signal blocked sigignore \
                    sigcatch wchan nswap cnswap extSignal processor

                set state "$state [format %.2d $processor]"
                set utime [expr {$userJiffies   / double($HZ)}]
                set stime [expr {$systemJiffies / double($HZ)}]
                set valid 1
            }
        }

        #
        # Combining the OS TID with the NaviServer thread creation time
        # protects the delta calculation against OS TID reuse.
        #
        set threadKey [list $tid $createTime]

        if {$valid} {
            dict set current threads $threadKey \
                [dict create utime $utime stime $stime]
        }

        lappend collected [dict create \
                               raw        $t \
                               key        $threadKey \
                               name       $name \
                               parent     $parent \
                               tid        $tid \
                               state      $state \
                               utime      $utime \
                               stime      $stime \
                               valid      $valid]
    }

    set sampledAt [expr {$snapshot eq "" ? [clock microseconds] : [dict get $snapshot timestamp]}]
    dict set current sampled_at $sampledAt

    set sampled [_ns_stats.sampled $snapshot]
    set previous {}
    if {$sampled} {
        nsv_set _ns_stats $sampleKey [dict create collectorMode sample]
    } else {
        set previous [nsv_set -reset _ns_stats $sampleKey $current]
        if {[_ns_stats.dictGetDef $previous collectorMode legacy] ne [dict get $current collectorMode]} {
            set previous {}
        }
    }

    set elapsed 0.0
    if {$previous ne ""
        && [dict exists $previous sampled_at]} {
        set elapsed [expr {
            ($sampledAt - [dict get $previous sampled_at])
            / 1000000.0
        }]
    }

    if {$sampled} {
        set elapsed [dict get $snapshot sampling elapsedSeconds]
    }

    #
    # Compute CPU percentages and build both result representations.
    #
    set rows     {}
    set byThread {}

    foreach entry $collected {
        set t          [dict get $entry raw]
        set threadKey  [dict get $entry key]
        set name       [dict get $entry name]
        set parent     [dict get $entry parent]
        set tid        [dict get $entry tid]
        set state      [dict get $entry state]
        set utime      [dict get $entry utime]
        set stime      [dict get $entry stime]
        set valid      [dict get $entry valid]
        set cpu        -1.0

        if {$sampled} {
            set measured [_ns_stats.dictGetDef $snapshot cpuPercent threads $threadKey percent {}]
            if {$measured ne ""} {set cpu $measured}
        } elseif {$valid
            && $elapsed > 0.0
            && [dict exists $previous threads $threadKey]} {
            set old [dict get $previous threads $threadKey]
            set du  [expr {$utime - [dict get $old utime]}]
            set ds  [expr {$stime - [dict get $old stime]}]

            if {$du >= 0.0 && $ds >= 0.0} {
                set cpu [expr {
                    100.0 * ($du + $ds) / $elapsed
                }]
            }
        }

        dict set byThread $threadKey \
            [dict create \
                 name       $name \
                 parent     $parent \
                 tid        $tid \
                 createTime [lindex $t 4] \
                 state      $state \
                 utime      $utime \
                 stime      $stime \
                 cpu        $cpu]

        #
        # Construct the exact layout consumed by _ns_stats.threads:
        #
        #   name parent id flags create
        #   tid state utime stime cpu
        #   proc arg
        #
        lappend rows [list \
                          [lindex $t 0] \
                          [lindex $t 1] \
                          [lindex $t 2] \
                          [lindex $t 3] \
                          [lindex $t 4] \
                          $tid \
                          $state \
                          $utime \
                          $stime \
                          $cpu \
                          [lindex $t 5] \
                          [lindex $t 6]]
    }

    return [dict create \
                available $cpuAvailable \
                elapsed   $elapsed \
                rows      $rows \
                byThread  $byThread]
}

proc _ns_stats.threads {} {
    set col         [ns_queryget col 1]
    set reverseSort [ns_queryget reversesort 1]

    set cpuData    [_ns_stats.threadCpuPercentages threadCpuSample]
    set osInfo     [dict get $cpuData available]
    set threadInfo [dict get $cpuData rows]

    if {$osInfo} {
        set colNumSort {. 0 0 1 1 1 0 1 1 1 0}
        set colTitles {
            Thread Parent ID Flags "Create Time"
            TID State utime stime "CPU %" Args
        }
        set align {
            left left right left left
            right right right right right left
        }
    } else {
        set colNumSort {. 0 0 1 1 1 0}
        set colTitles {Thread Parent ID Flags "Create Time" Args}
        set align     {left left right left left left}
    }

    #
    # The available columns depend on whether per-thread CPU information
    # could be obtained. A bookmarked or manually supplied column number
    # might therefore refer to a column not present in the current layout.
    #
    if {![string is integer -strict $col]
        || $col < 1
        || $col > [llength $colTitles]} {
        set col 1
    }

    set rows {}

    foreach t [_ns_stats.sortResults \
                   $threadInfo \
                   [expr {$col - 1}] \
                   [lindex $colNumSort $col] \
                   $reverseSort] {
        set thread [lindex $t 0]
        set parent [lindex $t 1]
        set id     [lindex $t 2]
        set flags  [_ns_stats.getThreadType [lindex $t 3]]
        set create [_ns_stats.fmtTime [lindex $t 4]]

        if {$osInfo} {
            set tid   [lindex $t 5]
            set state [lindex $t 6]
            set utime [_ns_stats.hr [lindex $t 7]]s
            set stime [_ns_stats.hr [lindex $t 8]]s
            set cpu   [lindex $t 9]
            set proc  [lindex $t 10]
            set arg   [lindex $t 11]

            set cpuDisplay [expr {
                $cpu < 0.0 ? "\u2014" : [format %.1f $cpu]
            }]

            if {$proc eq "p:0x0"} {
                set proc NULL
            }
            if {$arg eq "a:0x0"} {
                set arg NULL
            }

            lappend rows [list \
                              $thread $parent $id $flags $create \
                              $tid $state $utime $stime \
                              $cpuDisplay $arg]
        } else {
            set proc [lindex $t 5]
            set arg  [lindex $t 6]

            if {$proc eq "p:0x0"} {
                set proc NULL
            }
            if {$arg eq "a:0x0"} {
                set arg NULL
            }

            lappend rows \
                [list $thread $parent $id $flags $create $arg]
        }
    }

    set requestRates [_ns_stats.requestRates total]
    set totalRateDisplay [expr {
        [dict exists $requestRates total]
        ? "[format %.1f [dict get $requestRates total]] requests per second"
        : "n/a"
    }]

    append html \
        [_ns_stats.header Threads] \
        "Current Total Request rate: $totalRateDisplay" \
        [_ns_stats.results threads $col $colTitles \
             ?@page=threads $rows $reverseSort $align] \
        [_ns_stats.footer]

    return $html
}

proc _ns_stats.background.jobs {} {
    set queue       [ns_queryget queue]
    set col         [ns_queryget col 1]
    set reverseSort [ns_queryget reversesort 1]

    set numericSort 1
    set rows        [list]

    if { $queue eq "" } {

        if {$col == 0 || $col == 1 || $col == 4} {
            set numericSort 0
        }

        set colTitles [list "Queue name" Desc maxThreads numRunning Req]

        foreach ql [ns_job queuelist] {
            array set qa $ql
            set name "<a href='?@page=background.jobs&queue=$qa(name)'>$qa(name)</a>"
            lappend results [list $name $qa(desc) $qa(maxthreads) $qa(numrunning) $qa(req)]
        }

        set rows [_ns_stats.sortResults $results [expr {$col - 1}] $numericSort $reverseSort]

    } else {

        if {$col == 0 || $col == 1 || $col == 2 || $col == 3 || $col == 4} {
            set numericSort 0
        }

        set colTitles   [list ID State Script Code Type Started Stopped Time]
        set results     [list]

        foreach jl [ns_job joblist $queue] {
            array set ja $jl
            set ja(starttime) [_ns_stats.fmtTime $ja(starttime)]
            set ja(endtime) [_ns_stats.fmtTime $ja(endtime)]
            set ja(time) "[expr [lindex [split $ja(time) .] 0]/1000] sec"
            lappend results [list $ja(id) $ja(state) $ja(script) $ja(code) $ja(type) $ja(starttime) $ja(endtime) $ja(time)]
        }

        set rows [_ns_stats.sortResults $results [expr {$col - 1}] $numericSort $reverseSort]
    }

    append html \
        [_ns_stats.header Jobs] \
        [_ns_stats.results jobs $col $colTitles ?@page=background.jobs&queue=$queue $rows $reverseSort] \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.results {
                        name
                        {selectedColNum ""}
                        {colTitles ""}
                        {colUrl ""}
                        {rows ""}
                        {reverseSort ""}
                        {colAlignment ""}
                    } {
    set numCols [llength $colTitles]

    for {set colNum 1} {$colNum <= $numCols} {incr colNum} {
        set colClass($colNum) [expr {$colNum == $selectedColNum ? "selected" : "unselected"}]
    }

    set html [ns_trim -delimiter | [subst {
        |<table class="$name data-table w3-table w3-hoverable">
        |<tr class="sortable">
    }]]

    set i 1

    foreach title $colTitles {
        set url $colUrl

        #ns_log notice DEBUG TITLE col $i title $title
        if {$i == $selectedColNum} {
            if {$reverseSort} {
                append url "&reversesort=0"
            } else {
                append url "&reversesort=1"
            }
        } else {
            append url "&reversesort=$reverseSort"
        }

        set colAlign "left"
        set cssAlign ""

        if {[llength $colAlignment]} {
            set align [lindex $colAlignment $i-1]

            if {[string length $align]} {
                set colAlign $align
                if {$align eq "right"} {
                    set cssAlign right
                }
            }
        }

        append html \
            "<th valign='middle' align='$colAlign' class='coltitle $colClass($i) $cssAlign'>" \
            "<a href='$url&col=$i$::rawparam'>$title</a></th>"

        incr i
    }

    append html "</tr>"

    foreach row $rows {
        set i 1
        append html "<tr class='data'>"
        #ns_log notice DEBUG BODY row $row

        foreach column $row title $colTitles {
            set colAlign "left"
            set cssAlign ""
            #ns_log notice DEBUG BODY col $i

            if {[llength $colAlignment]} {
                set align [lindex $colAlignment $i-1]

                if {[string length $align]} {
                    set colAlign $align
                    if {$align eq "right"} {
                        set cssAlign right
                    }
                }
            }
            append html "<td class='x $colClass($i) $cssAlign' valign='top' align='$colAlign'>$column</td>"
            incr i
        }

        append html "</tr>"
    }

    append html "\
        </table>"

    return $html
}

proc _ns_stats.getValue {key} {
    if {![nsv_exists _ns_stats $key]} {
        return ""
    }

    return [nsv_get _ns_stats $key]
}

proc _ns_stats.getThreadType {flag} {
    return [_ns_stats.getValue thread_$flag]
}

proc _ns_stats.getSchedFlag {type} {
    return [_ns_stats.getValue sched_$type]
}

proc _ns_stats.isThreadSuspended {flags} {
    return [expr {$flags & [_ns_stats.getSchedFlag paused]}]
}

proc _ns_stats.isThreadRunning {flags} {
    return [expr {$flags & [_ns_stats.getSchedFlag running]}]
}

proc _ns_stats.getSchedFlagTypes {flags} {
    if {$flags & [_ns_stats.getSchedFlag once]} {
        set types "once"
    } else {
        set types "repeating"
    }

    if {$flags & [_ns_stats.getSchedFlag daily]} {
        lappend types "daily"
    }

    if {$flags & [_ns_stats.getSchedFlag weekly]} {
        lappend types "weekly"
    }

    if {$flags & [_ns_stats.getSchedFlag thread]} {
        lappend types "thread"
    }

    return $types
}

proc _ns_stats.fmtSeconds {seconds} {
    if {$seconds == 0} {
        return 0s
    }
    set ms [expr {($seconds - int($seconds))*1000}]
    set seconds [expr {int($seconds)}]
    if {$seconds < 1} {
        return [format %.2f $ms]ms
    }
    if {$seconds < 60} {
        set subseconds [expr {$ms > 0 ? " [format %.2f $ms]ms" : ""}]
        return ${seconds}s$subseconds
    }

    if {$seconds < 3600} {
        set mins [expr {$seconds/60}]
        set secs [expr {$seconds - ($mins * 60)}]

        return "${mins}m ${secs}s"
    }

    set hours [expr {$seconds/3600}]
    set mins  [expr {($seconds - ($hours * 3600))/60}]
    set secs  [expr {$seconds - (($hours * 3600) + ($mins * 60))}]

    if {$hours > 24} {
        set days  [expr {$hours / 24}]
        set hours [expr {$hours % 24}]
        return "${days}d ${hours}h ${mins}m ${secs}s"
    } else {
        return "${hours}h ${mins}m ${secs}s"
    }
}

proc _ns_stats.fmtTime {time} {
    if {$time < 0} {
        return "never"
    }
    return [clock format [expr {int($time)}] -format "%H:%M:%S %d-%m-%Y"]
}

proc _ns_stats.sortResults {results field numeric {reverse 0}} {
    set ::_sortListTmp(field)     $field
    set ::_sortListTmp(numeric)   $numeric
    set ::_sortListTmp(reverse)   $reverse

    return [lsort -command _ns_stats.cmpField $results]
}

proc _ns_stats.cmpField {v1 v2} {
    set v1 [lindex $v1 $::_sortListTmp(field)]
    set v2 [lindex $v2 $::_sortListTmp(field)]

    if {$::_sortListTmp(numeric)} {
        if {$::_sortListTmp(reverse)} {
            set cmp [_ns_stats.cmpNumeric $v2 $v1]
        } else {
            set cmp [_ns_stats.cmpNumeric $v1 $v2]
        }
    } else {
        if {$::_sortListTmp(reverse)} {
            set cmp [string compare $v2 $v1]
        } else {
            set cmp [string compare $v1 $v2]
        }
    }

    return $cmp
}

proc _ns_stats.cmpNumeric {n1 n2} {
    if {$n1 < $n2} {
        return -1
    } elseif {$n1 > $n2} {
        return 1
    }

    return 0
}

proc _ns_stats.pretty {keys kvlist {format %.2f}} {
    set stats {}
    set nkeys {}
    foreach k $keys {
        lassign $k key s
        set suffix($key) $s
        lappend nkeys $key
    }
    foreach {k v} $kvlist {
        if {$k in $nkeys} {
            set v [_ns_stats.hr $v $format]$suffix($k)
        }
        lappend stats $k $v
    }
    return $stats
}

#     set driverCpuSeverity [expr {$driverCpuMax >= 90.0 ? "critical" : $driverCpuMax >= 75.0 ? "warning" : "ok" }]
# set driverCpuSeverity [_ns_stats.categorize {{90.0 critical} {75.0 warning} {0.0 ok}} $v]
proc _ns_stats.categorize {limits value} {
    set category none
    foreach pair $limits {
        lassign $pair threshold category
        if {$value >= $threshold} {
            return $category
        }
    }
    return $categoy
}

proc _ns_stats.hr {n {format %.2f}} {
    #
    # Use global setting ::raw for returning raw values
    #
    if {[info exists ::raw] && $::raw} {
        return $n
    }

    #
    # Return the number in human readable form -gn
    #
    #puts format=[format %e $n]
    set r $n
    set units {15 P 12 T 9 G 6 M 3 K 0 "" -3 m -6 µ -9 n}
    if {[regexp {^([0-9.]+)e(.[0-9]+)$} [format %e $n] _ val exp]} {
        set exp [string trimleft $exp +]
        set exp [string trimleft $exp 0]
        if {$exp eq ""} {set exp 0}
        foreach {e u} $units {
            #puts "$exp >= $e"
            if {$exp >= $e} {
                #puts "[format %e $n] $val*10 ** ($exp-$e)"
                set v [format $format [expr {$val*10**($exp-$e)}]]
                if {[string first . $v] > -1} {
                    set v [string trimright [string trimright $v 0] .]
                }
                set r $v$u
                set found 1
                #ns_log notice "NSSTATS result <$n> -> <$r>"
                break
                #puts stderr BREAK
            }
        }
        if {![info exists found]} {
            # ns_log notice "NSSTATS FALL BACK on <$n>"
            # fall back to nano
            set e -9
            if {[regexp {^-0([0-9]+)$} $exp . e1]} {
                set exp -$e1
            }
            #puts "[format %e $n] $val*10 ** ($exp-$e) // exp <$exp>"
            set v [format $format [expr {$val * 10 ** ($exp - $e)}]]
            if {[string first . $v] > -1} {
                set v [string trimright [string trimright $v 0] .]
            }
            set r $v$u
        }
    } else {
        #ns_log notice "NSSTATS FALL BACK NO NUMBER <$n>"
    }
    return $r
}

# Main processing logic
set page [ns_queryget @page]

#ns_log notice severity $severity user $user password $password enabled $enabled debug $debug page $page

#
# raw number display
#
set ::raw [ns_queryget raw 0]
set ::rawparam ""
if {$::raw eq "1"} {
    set ::rawparam "&raw=1"
}

if { [info commands _ns_stats.$page] eq "" } {
    set page process
}

# OpenACS can source this script in a procedure, making page local. Publish the
# validated selection for navigation helpers and ADP templates in either setup.
set ::page $page

proc _ns_stats.public_ip {ip} {
    try {
        # For NaviServer 5
        ns_ip public $ip
    } on error {errorMsg} {
        # backwards compatibility
        expr {$ip ni {"127.0.0.1" "::1"}}
    }
}
ns_log $severity "nsstats: enabled $enabled configured user '$user' authuser '[ns_conn authuser]'"

if {$enabled == 0} {
    #
    # When the module is disabled, no access is granted.
    #
    set allowed 0

} elseif {[info commands ::ad_try] ne "" && ("admin" in [ns_conn urlv] || "acs-admin" in  [ns_conn urlv])} {
    #
    # In OpenACS installations, allow access, when we have a site
    # "admin" or a sitewide "acs-admin" link, which are always access
    # checked.
    #
    ns_log $severity "nsstats: OpenACS admin"

    set allowed 1

} elseif {$user ne "" && [info commands ns_perm] ne "" && $user in [lmap {u . .} [ns_perm listusers] {set u}]} {
    #
    # We have the "nsperm" module enabled, and the configured user is
    # in the loaded user table.
    #
    ns_log $severity "nsstats: use nsperm, call 'ns_conn authuser'"
    if {[ns_conn authuser] ne $user} {
        ns_log $severity "ns_conn authuser -> [ns_conn authuser]"
        set allowed 0
        #
        # Add permissions for GET and POST request
        #
        ns_perm allowuser GET  [ns_conn url] $user
        ns_perm allowuser POST [ns_conn url] $user
        #ns_log $severity permissions  \n[join [ns_perm listperms] \n]
    } else {
        # Authentication was already checked by NaviServer via nsperm
        set allowed 1
    }

} elseif {$user ne "" && [ns_conn authuser] eq $user && [ns_conn authpassword] eq $password} {
    #
    # Allow access, when a user is configured, and it is the
    # authenticated user and the password is correct.
    #
    ns_log $severity "check password for user '$user' configured in the file"

    set allowed 1

} elseif {![_ns_stats.public_ip [ns_conn peeraddr -source direct]]} {
    #
    # Allow access for non-public IP addresses. This is for
    # installation tests on local machines. These addresses are not
    # routed over the public Internet.
    #
    ns_log $severity "nsstats: non-public IP"

    set allowed 1
} else {
    set allowed 0
}
ns_log $severity "nsstats: access for user '$user' granted: $allowed"


# Check user access if configured
if { !$allowed } {
    set html [_ns_stats.index]
    ns_returnunauthorized
    if {[info exists ::ad_conn(file)]} {
        ad_script_abort
    }
    #return
} else {
    # Produce page
    ns_set iupdate [ns_conn outputheaders] "expires" "now"
    set html [_ns_stats.$page]
    if {$html ne ""} {
        if {[info exists ::ad_conn(file)]} {
            set path $::ad_conn(file)
        } else {
            set path [ns_url2file [ns_conn url]]
        }
        set fn [file join {*}[lrange [file split $path] 0 end-1]]/$::templateFile-[ns_info version].adp
        if {![file exists $fn]} {
            set fn [file join {*}[lrange [file split $path] 0 end-1]]/$::templateFile.adp
        }
        #ns_log notice "final script <$fn> path <$path>"
        if {[file exists $fn]} {
            ns_return 200 text/html [ns_adp_parse -file $fn]
        } else {
            ns_return 200 text/html [ns_adp_parse -string $::fallbackTemplate]
        }
        if {[info exists ::ad_conn(file)]} {
            ad_script_abort
        }
    } else {
        # We assume, that when _ns_stats returns empty, the page
        # returned/redicted itself.
    }
}
#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
