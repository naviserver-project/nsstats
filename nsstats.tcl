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

set ::navLinks [subst {
    background        "Background"
    background.jobs   "Jobs"
    background.sched  "Scheduled Procedures"
    config            "Configuration"
    config.file       "Configuration File"
    config.params     "Configuration Parameters"
    locks             "Locks"
    locks.mutex       "Mutex and RW-Locks"
    locks.nsv         "Nsv Locks"
    log               "Logging"
    log.logfile       "System Log"
    log.httpclient    "HTTP Client Log"
    log.smtpsent      "SMTP Sent Log"
    log.levels        "Log Severities"
    mem               "Memory"
    mem.adp           "ADP"
    mem.tcl           "Allocated Memory"
    mem.cache         "Cache (ns_cache)"
    mem.nsvsize       "Shared Variables (nsv)"
    [expr {[info commands ns_json] ne "" ?  {utilization Utilization} : ""}]
    process           "Process"
    threads           "Threads"
}]

# The following entries have no counter parts in the navLinks
# (we could add some of these to sub menus).
#
#    list-lsof         "Open Files"
#    mapped            "Connection Pool Mappings"
#    proxy-workers     "nsproxy Workers"
#    url2file          "Url2File Mappings"


set ::titles {
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
    mapped            "Connection Pool Mappings"
    mem.adp           "ADP"
    mem.cache         "Cache Statistics (ns_cache)"
    mem.nsvsize       "Shared Variable Statistics (nsv)"
    mem.tcl           "Allocated Memory"
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
</head>

<body>
  <table class='navbar table table-responsive w-100 d-block d-md-table'>
    <tr>
      <td valign='middle'><b><%= $::nav %></b></td>
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
    set linkLines ""
    set level 0
    foreach {name label} $::navLinks {
        if {[string match *.* $name]} {
            if {$level == 0} {
                lappend linkLines "<ul>"
                incr level
            }
        } else {
            if {$level > 0} {
                lappend linkLines </ul>
                incr level -1
            }
        }
        if {[info procs _ns_stats.$name] ne ""} {
            lappend linkLines  "<li> <a href='?@page=$name$::rawparam'>$label</a></li>"
        } else {
            lappend linkLines  "<li> <strong>$label</strong></li>"
        }
    }

    append html \
        [_ns_stats.header] \
        <ul> \n \
        [join $linkLines \n] \n \
        </ul> \n \
        [_ns_stats.footer]

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
            array set t {commit 0 rollback 0}
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
                                 [expr {$t(hits) > 0 ? $t(saved)*1.0/$t(hits) : 0}] \
                                 [expr {$totalRequests > 0 ? $t(saved)/$totalRequests : 0}] \
                                ]
            set totalSaved [expr {$totalSaved + $t(saved)}]
        }

        set colTitles   {
            Cache Max Current Utilization Entries "Avg Size" Flushes Hits Hits/Req Reuse Misses
            "Hit Rate" Expired Pruned Commit Rollback "Saved/Hit" "Saved/Req"
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
            lset row 16 [_ns_stats.hr [lindex $row 16]]s
            lset row 17 [_ns_stats.hr [lindex $row 17]]s
            lappend table $row
        }

        append html \
            [_ns_stats.header Cache] \
            "<p class='summary'>ns_cache operations saved since the start of the server [_ns_stats.fmtSeconds $totalSaved] on [_ns_stats.hr $totalRequests] requests " \
            "([_ns_stats.hr [expr {$totalSaved/$totalRequests}]]s per request on average)</p>" \n \
            [_ns_stats.results cache $col $colTitles ?@page=mem.cache $table $reverseSort {
                left right right right right right right right right right right right right right right right right right
            }] \
            [_ns_stats.footer]
    }
    return $html
}

proc _ns_stats.requestRates {sampleKey} {
    set total        0
    set serverCounts {}

    foreach server [ns_info servers] {
        set requests 0

        foreach pool [ns_server -server $server pools] {
            incr requests \
                [dict get [ns_server -server $server -pool $pool stats] requests]
        }

        dict set serverCounts $server $requests
        incr total $requests
    }

    set linuxNetwork [_ns_stats.linuxNetworkSnapshot]
    set now          [clock microseconds]

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
    set totalRequests 0
    foreach s [ns_info servers] {
        foreach pool [ns_server -server $s pools] {
            incr totalRequests [dict get [ns_server -server $s -pool $pool stats] requests]
        }
    }
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

    foreach stats [ns_driver stats] {
        dict set drivers [dict get $stats thread] $stats
    }

    foreach kind {driver writer spooler} {
        if {![catch {ns_driver queues $kind} entries]} {
            foreach entry $entries {
                dict set queues $kind [dict get $entry thread] $entry
            }
        }
    }

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

    set linuxNetwork [_ns_stats.linuxNetworkSnapshot]
    set now          [clock microseconds]

    set sample [dict create \
                    timestamp    $now \
                    drivers      $drivers \
                    queues       $queues \
                    servers      $servers \
                    linuxNetwork $linuxNetwork]
    set previous \
        [nsv_set -reset _ns_stats utilizationSample $sample]

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

    return [dict create \
                current  $sample \
                previous $previous \
                elapsed  $elapsed]
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

    set noun [_ns_stats.utilization.pluralize $delta $label]

    if {$delta == 0} {
        return "0 $noun"
    }

    if {$rate >= 0.0} {
        return "$delta $noun in interval ([_ns_stats.utilization.displayRate $rate])"
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
        set receiveText "[_ns_stats.utilization.displayRate $udpReceiveDropsRate] receive-buffer drops"
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

        set sendText "[_ns_stats.utilization.displayRate $udpSendDropsRate] send-buffer drops"
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

    #
    # CPU percentages. The helper should return dictionaries containing
    # at least "name" and "cpu".
    #
    set driverCpuTotal 0.0
    set driverCpuMax   0.0
    set connCpuTotal   0.0
    set writerCpuTotal 0.0
    set spoolerCpuTotal 0.0

    dict for {threadKey threadData} $threadCpu {
        set name [_ns_stats.dictGetDef $threadData name ""]
        set cpu  [_ns_stats.dictGetDef $threadData cpu  -1.0]

        if {$cpu < 0.0} {
            continue
        }

        switch -glob -- $name {
            "-driver:*" {
                set driverCpuTotal [expr {$driverCpuTotal + $cpu}]
                set driverCpuMax   [expr {max($driverCpuMax, $cpu)}]
            }
            "-conn:*" {
                set connCpuTotal [expr {$connCpuTotal + $cpu}]
            }
            "-writer:*" {
                set writerCpuTotal [expr {$writerCpuTotal + $cpu}]
            }
            "-spooler:*" {
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
                       $current $previous $elapsed severity reasons]

    if {$droppedRate > 0.0} {
        set severity critical
        lappend reasons \
            "[_ns_stats.utilization.displayRate $droppedRate] dropped"
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

    set droppedSeverity    [expr {$droppedRate > 0.0 ? "critical" : "ok"}]
    set droppedRateDisplay [_ns_stats.utilization.colorize $droppedSeverity \
                                "[_ns_stats.utilization.displayRate $droppedRate] dropped"]

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
                  [list "Connection CPU"       "[format %.1f $connCpuTotal]%"] \
                  [list "Writer / Spooler CPU" "[format %.1f $writerCpuTotal]% / [format %.1f $spoolerCpuTotal]%"] \
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
        if {$errorRate > 0.0} {
            lappend reasons \
                "[_ns_stats.utilization.displayRate $errorRate] errors"
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
        set errorDisplay   [_ns_stats.utilization.colorize $errorSeverity [_ns_stats.utilization.displayRate $errorRate]]

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
            set configPath     [expr {$pool eq "" ? "ns/server/$server" : "ns/server/$server/pool/$pool"}]
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
                lappend reasons  "[_ns_stats.utilization.displayRate $droppedRate] dropped"
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
            set droppedDisplay [_ns_stats.utilization.colorize $droppedSeverity [_ns_stats.utilization.displayRate $droppedRate]]

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

    set cpuData       [_ns_stats.threadCpuPercentages utilizationThreadCpuSample]
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
        "Errors/s" {
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
        Dropped/s {
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
        [_ns_stats.results global-summary 0 {Metric Value} "?@page=utilization" $globalSummary 0 {left left}] \
        "\n<p></p>" \
        "\n<div class='utilization-charts'>$driverChart $poolChart</div>" \
        "<h2>Network Drivers</h2>" \
        [_ns_stats.results drivers 0 $driverTitles "?@page=utilization" $driverRows 0 $driverAlign] \
        "<h2>Servers and Connection Pools</h2>" \
        [_ns_stats.results utilization-pools 0 $poolTitles "?@page=utilization" $poolRows 0 $poolAlign] \
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

    set numericSort 1
    set colTitles   [list Array Elements Bytes "Agv. Content-Size"]
    set rows        ""

    if {$col == 1} {
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
        lappend rows [list $array $size $sizeBytes [expr {$size > 0 ? $contentBytes*1.0/$size : 0}]]
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

    append html \
        [_ns_stats.header "Nsv Size"] \
        "<p>Nsv arrays: $nrArrays, elements: [_ns_stats.hr $totalElements], total bytes: [_ns_stats.hr $totalBytes]B</p>" \
        [_ns_stats.results nsv-size $col $colTitles ?@page=mem.nsvsize \
             $table \
             $reverseSort \
             {left right right right}]

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
        try {
            set log_to_stderr [expr {"-f" in [ns_info argv]}]
        } on error {errorMsg} {
            set log_to_stderr [expr {![file exists $system_log]}]
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
            } finally {
                if {[info exists f]} {
                    close $f
                }
            }
            set content "<font size=2><pre>[_ns_stats.log.prepare_content system $system_content]</pre></font>"
        }
    }

    set tails [lmap file [lsort -decreasing [glob [ns_info log].*]] {
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


proc _ns_stats.config.params {} {
    set paramDocFile [file join [ns_info home] modules tcl config-parameters.tcl]
    ns_log notice paramDocFile [file readable $paramDocFile] $paramDocFile
    if {[file readable $paramDocFile]} {
        source $paramDocFile
    } else {
        set ::configParamDoc {}
    }

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
            lappend lines "<tr><td class='subtitle'>$pool:</td><td width='100%'>$stats</td>"
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
            lappend driverInfo $entry
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
                    Host                 "[ns_info hostname] ([ns_info address], Tcl $::tcl_patchLevel, $version_info)" \
                    "Boot Time"           [clock format [ns_info boottime] -format %c] \
                    Uptime                [_ns_stats.fmtSeconds [ns_info uptime]] \
                    Process              "[ns_info pid] [ns_info nsd] [list $processInfo]" \
                    "Open Files"          "<a href='?@page=list-lsof'>[llength [_ns_stats.lsof [ns_info pid]]]</a>" \
                    Home                  [ns_info home] \
                    Configuration         [ns_info config] \
                    "System Log"          [ns_info log] \
                    "Log Statistics"      [_ns_stats.pretty {Notice Warning Debug(sql)} [ns_logctl stats] %.0f] \
                    Version              "[ns_info patchlevel] (tag $tag) $buildinfo" \
                    "Build Date"          [ns_info builddate] \
                    Servers               [join [lmap s [ns_info servers] {string cat "<a href='#$s'>$s</a>: [ns_config ns/servers $s]"}] <br>] \
                    {*}${driverInfo} \
                    {*}${certInfo} \
                    DB-Pools             "<table>[join [_ns_stats.process.dbpools]]</table>" \
                    Callbacks            "<table>[join [_ns_stats.process.callbacks]]</table>" \
                    {*}$proxyItems \
                    "Task Threads"        [join $taskthreadinfo <br>] \
                    "Socket Callbacks"    [join [ns_info sockcallbacks] <br>] \
                    "Running Scheduled Procs (repeated)" [join [_ns_stats.process.running_scheds] <br>] \
                    "Running Jobs"        [join [_ns_stats.process.running_jobs] <br>] \
                   ]

    set html [_ns_stats.header Process]
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
            set rawstats [ns_server -server $s -pool $pool stats]
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
            set rawthreads [list {*}[ns_server -server $s -pool $pool threads] \
                                waiting [ns_server -server $s -pool $pool waiting] \
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

        try {
            set modulesEntry [list "Loaded Modules" [lsort [ns_ictl getmodules -server $s]]]
        } on error {errorMsg} {
            set modulesEntry {}
        }

        set values [list \
                        "Address"            [join [lsort -unique $addresses] <br>] \
                        "Server Directory"   $serverdir \
                        {*}$serverlogdirEntry \
                        "Page Directory"     [ns_server -server $s pagedir] \
                        "Tcl Library"        [ns_server -server $s tcllib] \
                        "Access Log"         [ns_config ns/server/$s/module/nslog file] \
                        {*}$modulesEntry \
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
        "<p>Back to <a href='?@page=process'>process</a> page</p>" \
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
        "<p>Back to <a href='?@page=process'>process</a> page</p>" \
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
        "<p>Back to <a href='?@page=process'>process</a> page</p>" \
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
    set options [join [lmap logfile $logfiles {
        set selected [expr {$logfile eq $path ? "selected" : ""}]
        set tail [file tail $logfile]
        set _ "<option value='$tail' $selected>$tail</option>"
    }] \n]
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
        <form action="nsstats.tcl" class="row g-1">
        <div class="col"><select class="form-select" name="logfile">$options</select></div>
        <div class="col"><button type="submit" class="btn btn-outline-secondary">Show</button></div>
        <input type="hidden" name="@page" value="[ns_queryget @page]">
        </form>
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
            if {[file size $file] < 10} continue
            #ns_log notice "file size <$file> [file size $file]"
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

proc _ns_stats.log.mkchart {section param title} {
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
        set selected_logfile [ns_queryget logfile ""]
        if {$selected_logfile eq ""} {
            set logfile $configured_logfile
        } else {
            set logfile [file join {*}[lreplace [file split $configured_logfile] end end $selected_logfile]]
        }
        set HTML [_ns_stats.log.chart $logfile $section $param $title]
    }
    append html \
        [_ns_stats.header $title] \
        $HTML \
        [_ns_stats.footer]
    return $html
}

proc _ns_stats.threadCpuPercentages {sampleKey} {
    set pid         [pid]
    set rawThreads  [ns_info threads]
    set cpuSource   none
    set cpuTimes    {}
    set collected   {}
    set current     [dict create threads {}]
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

    try {
        set cpuTimes [ns_info threadcputimes]
        set cpuSource api
    } on error {errorMsg} {
        if {[file isdirectory /proc/$pid/task]} {
            set cpuSource proc
            set HZ 100
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

        if {$cpuSource eq "api"} {
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

    set sampledAt [clock microseconds]
    dict set current sampled_at $sampledAt

    set previous [nsv_set -reset _ns_stats $sampleKey $current]

    set elapsed 0.0
    if {$previous ne ""
        && [dict exists $previous sampled_at]} {
        set elapsed [expr {
            ($sampledAt - [dict get $previous sampled_at])
            / 1000000.0
        }]
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

        if {$valid
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

        set colTitles [list Name Desc maxThreads numRunning Req]

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
