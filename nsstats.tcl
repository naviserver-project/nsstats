#
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.mozilla.org/.
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
#
# The Original Code is AOLserver Code and related documentation
# distributed by AOL.
#
# The Initial Developer of the Original Code is America Online,
# Inc. Portions created by AOL are Copyright (C) 1999 America Online,
# Inc. All Rights Reserved.
#
# Alternatively, the contents of this file may be used under the terms
# of the GNU General Public License (the "GPL"), in which case the
# provisions of GPL are applicable instead of those above.  If you wish
# to allow use of your version of this file only under the terms of the
# GPL and not to allow others to use your version of this file under the
# License, indicate your decision by deleting the provisions above and
# replace them with the notice and other provisions required by the GPL.
# If you do not delete the provisions above, a recipient may use your
# version of this file under either the License or the GPL.
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
set user     [ns_config ns/module/nsstats user ""]
set password [ns_config ns/module/nsstats password ""]
set enabled  [ns_config ns/module/nsstats enabled 1]

set ::templateFile nsstats.adp


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

set ::navLinks {
    background        "Background"
    background.jobs   "Jobs"
    background.sched  "Scheduled Procedures"
    config            "Configuration"
    config.file       "Config File"
    config.params     "Config Parameters"
    locks             "Locks"
    locks.mutex       "Mutex and RW-Locks"
    locks.nsv         "Nsv Locks"
    log               "Logging"
    log.httpclient    "HTTP Client Log"
    log.smtpsent      "SMTP Sent Log"
    log.levels        "Log Levels"
    log.logfile       "Log File"
    mem               "Memory"
    mem.adp           "ADP"
    mem.cache         "Cache"
    mem.nsvsize       "Shared Variables"
    mem.tcl           "Tcl Memory"
    process           "Process"
    threads           "Threads"
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
    set ::footer "</body></html>"
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
            "<h4>ns_cache operations saved since the start of the server [_ns_stats.fmtSeconds $totalSaved] on [_ns_stats.hr $totalRequests] requests " \
            "([_ns_stats.hr [expr {$totalSaved/$totalRequests}]]s per request on average)</h4>" \n \
            [_ns_stats.results cache $col $colTitles ?@page=mem.cache $table $reverseSort {
                left right right right right right right right right right right right right right right right right right
            }] \
            [_ns_stats.footer]
    }
    return $html
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
        "<h4>$line</h4>" \
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
        [_ns_stats.results nsv-size $col $colTitles ?@page=nsv.size \
             $table \
             $reverseSort \
             {left right right right}]

    append html [_ns_stats.footer]
    return $html
}

proc _ns_stats.log.prepare_content {type content} {
    set content [ns_quotehtml $content]
    switch $type {
       access { regsub -all { ([-][^\]\n\" ]+[-]) } $content { <a href='nsstats.tcl?@page=log.logfile\&filter=\1'>\1</a> } content}
       system { regsub -all {\[([-][^\]\n\" ]+[-])\]} $content {[<a href='nsstats.tcl?@page=log.logfile\&filter=\1'>\1</a>]} content}
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

    if {$filter ne ""} {
        set access_content ""
        foreach s [ns_info servers] {
            try {
                set lines [exec fgrep -- $filter [ns_config ns/server/$s/module/nslog file]]
                append access_content $lines \n
            } on error {errorMsg} {
                # just return no content lines when fgrep fails
            }
        }
        try {
            set system_content [string map $colorcodemap [exec fgrep -A100 -- $filter [ns_info log]]]
        } on error {errorMsg} {
            set system_content ""
        }
        try {
            set currentLine ""
            set lines {}
            foreach l [split $system_content \n] {
                if {[string range $l 0 0] eq ":"} {
                    append currentLine \n$l
                } else {
                    lappend lines $currentLine
                    set currentLine [expr {$l eq "--" ? "" : $l}]
                }
            }
            lappend lines $currentLine
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
            set f [open [ns_info log]]
            seek $f 0 end
            set n [expr {[tell $f] -10000}]
            if {$n < 0} {
                set n 10000
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

    append html \
        [_ns_stats.header Log] \
        "<form method='post' action='./nsstats.tcl'>Filter: " \
        "<input type='hidden' name='@page' value='log.logfile'>" \
        "<input name='filter' value='$filter' size='40'></form>" \
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


proc _ns_stats.tooltip {section field} {
    foreach n [array names ::tips] {
        lassign [split $n ,] re f
        if {$field eq $f && [regexp $re $section]} {return $::tips($n)}
    }
    return ""
}

proc _ns_stats.config.params {} {
    set out [list]
    foreach section [lsort [ns_configsections]] {
        # We want to have e.g. "aaa/pools" before "aaa/pool/foo",
        # therefore we map "/" to "" to put it in the collating sequence
        # after plain chars
        set sectionName [ns_set name $section]
        set name [string map {/ ~} $sectionName]

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
            set tip [_ns_stats.tooltip $name $section_key]
            set tipclass [expr {$tip ne "" ? "tip" : ""}]
            set valueDicts [dict get $keys $section_key]
            set values ""
            set class "colvalue"
            set tooltip_text ""
            foreach valueDict [dict get $keys $section_key] {
                set value [dict get $valueDict value]
                set default [dict get $valueDict default]
                set flags ""
                if {[dict get $valueDict defaulted]} {
                    lappend class defaulted tooltip
                    set tooltip_text {<span class="tooltiptext">Value is default</span>}
                }
                if {[dict get $valueDict unread]} {
                    lappend class unread tooltip
                    set tooltip_text {<span class="tooltiptext">Value was not read during startup</span>}
                }
                if {$default ne "" && ![dict get $valueDict defaulted]} {
                    append section_key " " "($default)"
                    if {$default eq $value} {
                        lappend class notneeded tooltip
                        set tooltip_text {<span class="tooltiptext">Value is set to default (not needed)</span>}
                    }
                }
                if {$flags ne ""} {
                    append value " " $flags
                }
                lappend values $value
            }
            lappend line "<tr><td title='$tip' class='coltitle $tipclass'>$section_key:</td>\n\
        <td class='$class'>[join $values <br>]$tooltip_text</td></tr>"
        }
        set table($name) [join $line \n]
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
        if {$e eq ".br"} {
            append sectionhtml "<tr><td colspan='2'>&nbsp</td></tr>\n"
        }
        foreach section [lsort [array names table -regexp $e]] {
            set name [string map {~ /} $section]
            lappend toc "<a href='#ref-$name'>$name</a>"
            set anchor "<a name='ref-$name'>$name</a>"
            append sectionhtml "\n<tr><td colspan='2' class='colsection'><h4>$anchor</h4></td></tr>\n$table($section)\n"
            unset table($section)
        }
    }
    if {[array size table] > 0} {
        append sectionhtml "\n<tr><td colspan='2' class='colsection'><h4>Extra Parameters</h4></td></tr>\n\n"
        foreach section [lsort [array names table]] {
            set name [string map {~ /} $section]
            lappend toc "<a href='#ref-$name'>$name</a>"
            set anchor "<a name='ref-$name'>$name</a>"
            append sectionhtml "\n<tr><td colspan='2' class='colsection'><h4>$anchor</h4></td></tr>\n$table($section)\n"
        }
    }
    append html \
        [_ns_stats.header "Config Parameters"] \
        "<h4>The following values are defined in the configuration database:</h4>" \
        "<table><tr><td valign='top' style='background:#eeeeee; white-space:nowrap;'>" \
        "<ul style='list-style-type: none; margin: 0; padding: 0;'><li>[join $toc </li><li>]</li></ul>" \
        </td><td> \
        <table>$sectionhtml</table> \
        </td></tr> \
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

# minimal backwards compatibility for tcl 8.4

if {[info commands ::dict] ne ""} {
    proc dictget? {dict key {def ""}} {
        if {[dict exists $dict $key]} {
            return [dict get $dict $key]
        } else {
            return $def
        }
    }
} else {
    proc dictget? {dict key {def ""}} {
        return $key
    }
}


proc _ns_stats.mem.tcl {} {
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

    set html [_ns_stats.header Memory]

    if {[info commands ::dict] ne ""} {
        set trans [dict create]
        foreach thread [ns_info threads] {
            dict set trans thread0x[lindex $thread 2] [lindex $thread 0]
        }
    }

    append html "\
    <table border='0' cellpadding='0' cellspacing='0'>
    <tr>
        <td valign=middle>"

    foreach p [lsort [ns_info pools]] {
        append html "\
        <b>[lindex $p 0]:</b>
        <b>[dictget? $trans [lindex $p 0]]</b>
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
        <table class="data">
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
    ns_returnredirect $url
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
        [_ns_stats.header "Log Levels"] \
        "<p>The following table shows the current log levels:<p>\n" \
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

proc _ns_stats.memsizes {pid} {
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
    set uss   [format %.2f [expr {($rss-$shared) * 4}]]
    set rss   [format %.2f [expr {$rss           * 4}]]
    set vsize [format %.2f [expr {$vsize         * 4}]]
  }
  if {$rss == 0} {
    set sizes [exec -ignorestderr /bin/ps -o vsize,rss $pid]
    set vsize [lindex $sizes end-1]
    set rss   [lindex $sizes end]
  }
  return [list rss $rss vsize $vsize uss $uss]
}

proc _ns_stats.pretty_meminfo {pid} {
    try {
        set m [_ns_stats.memsizes $pid]
        append pretty_meminfo "(" \
            "vm [_ns_stats.hr [dict get $m vsize]]B " \
            "rss [_ns_stats.hr [dict get $m rss]]B)"
    } on error {errorMsg} {
        set pretty_meminfo ""
    }
    return $pretty_meminfo
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
                    lappend certInfo [join [ns_certctl list] <br>]
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
                        append pidinfos "$pid [_ns_stats.pretty_meminfo $pid] "
                    }
                    set pidsrow "<tr><td class='subtitle'>Pids:</td><td class='colvalue'>$pidinfos</td></tr>"
                } on error {errorMsg} {
                    set pidsrow ""
                }
                set item ""
                append item \
                    "<tr><td class='subtitle'>Params:</td><td class='colvalue'>$configValues</td></tr>" \
                    "<tr><td class='subtitle'>Stats:</td><td class='colvalue'>$resultstats</td></tr>" \
                    $pidsrow \
                    "<tr><td class='subtitle'>Active:</td><td class='colvalue'>$active</td></tr>"
                lappend proxyItems "nsproxy '$pool'" "<table>$item</table>"
            }

        } errorMsg]} {
            lappend proxyItems "nsproxy '$pool'" "<table>$errorMsg</table>"
        }
    }

    set values [list \
                    Host                 "[ns_info hostname] ([ns_info address], Tcl $::tcl_patchLevel, $version_info)" \
                    "Boot Time"           [clock format [ns_info boottime] -format %c] \
                    Uptime                [_ns_stats.fmtSeconds [ns_info uptime]] \
                    Process              "[ns_info pid] [ns_info nsd] [_ns_stats.pretty_meminfo [ns_info pid]]" \
                    Home                  [ns_info home] \
                    Configuration         [ns_info config] \
                    "Error Log"           [ns_info log] \
                    "Log Statistics"      [_ns_stats.pretty {Notice Warning Debug(sql)} [ns_logctl stats] %.0f] \
                    Version              "[ns_info patchlevel] (tag $tag)" \
                    "Build Date"          [ns_info builddate] \
                    Servers               [join [ns_info servers] <br>] \
                    {*}${driverInfo} \
                    {*}${certInfo} \
                    DB-Pools             "<table>[join [_ns_stats.process.dbpools]]</table>" \
                    Callbacks            "<table>[join [_ns_stats.process.callbacks]]</table>" \
                    {*}$proxyItems \
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
            set addr [ns_config ns/module/$driver/servers $s]
            if {$addr ne ""} {
                lappend addresses $addr
                lappend writerThreads $driver: [ns_config $section writerthreads 0]
                lappend spoolerThreads $driver: [ns_config $section spoolerthreads 0]
            } else {
                set port [ns_config $section port]
                if {$port ne ""} {
                    lappend addresses [ns_config $section address]:$port
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
            |URL mappings:
            |<a href='?@page=url2file&server=$s'>
            |   [llength [ns_server -server $s url2file]]
            |</a>}]]

        set values [list \
                        "Address"            [join [lsort -unique $addresses] <br>] \
                        "Server Directory"   $serverdir \
                        "Page Directory"     [ns_server -server $s pagedir] \
                        "Tcl Library"        [ns_server -server $s tcllib] \
                        "Access Log"         [ns_config ns/server/$s/module/nslog file] \
                        "Writer Threads"     $writerThreads \
                        "Spooler Threads"    $spoolerThreads \
                        "Handlers"           $requestHandlers \
                        "Connection Pools"   [ns_server -server $s pools] \
                        {*}$poolItems \
                        "Active Writer Jobs" [join [lmap l [ns_writer list -server $s] {ns_quotehtml $l}] <br>] \
                        "Active Connchan Jobs" [join [lmap l [ns_connchan list -server $s] {ns_quotehtml $l}] <br>] \
                       ]

        append html \
            "<h2>Server $s</h2>" \n \
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
    lassign $fields ts tz id status method url elapsed sent received cause
    set ts0 [string range $ts 1 end]
    #
    # Provide robustness when invalid URLs (containing unescaped
    # spaces) were used.
    #
    if {[llength $fields] > 10} {
        lassign [lrange $fields end-3 end] elapsed sent received cause
        set url [lrange $fields 5 end-4]
    }
    set host none
    regexp {https?://([^/]+)/} $url . host

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
                cause $cause \
               ]
}

proc _ns_stats.log.chart.parse-module/nssmtpd {line} {
    set fields [split $line]
    lassign $fields ts tz id status method url elapsed sent sender rcpt
    set ts0 [string range $ts 1 end]
    #[25/Sep/2023:00:02:48 +0200] -sched:...- 250 SUCCESS [smtp.wu.ac.at]:25 0.009911 13313 sender RCPT: USER@HOST
    set host $url

    return [list \
                ts0 $ts0 \
                id $id \
                status $status \
                method $method \
                host $host \
                url $url \
                elapsed $elapsed \
                sent $sent \
                received 0 \
                cause "" \
               ]
}

proc _ns_stats.log.chart {path section param title} {
    set logfiles [_ns_stats.log.logfiles $section $param]
    ns_log notice "nsstats: process $section $param log $path -> $logfiles"

    if {[file size $path] < 10} {
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

    foreach line [split $logcontent \n] {
        #if {$count>10} break
        if {[string length $line] < 15} {
            break
        }
        incr count
        set data [_ns_stats.log.chart.parse-$section $line]
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
            dict incr hostInfo $status
            if {[dict exists $hostInfo elapsed]} {
                dict set hostInfo elapsed [expr {[dict get $hostInfo elapsed] + $elapsed}]
            } else {
                dict set hostInfo elapsed $elapsed
            }
            dict set hostInfos $host $hostInfo
            dict set statusCodes $status 1
        }
    }
    set responsetimeSeries {}
    foreach key [dict keys $responsetime] {
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
    foreach key [dict keys $requestcount0] {
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
        <th class="fs-6 text-end">Received</th>
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
            <td class="fs-6 text-end">[_ns_stats.hr [dict get $hostInfos $host received]]B</td>
            [join [lmap code $codes {set _ "<td class='fs-6 text-end'>[dict get $hostInfos $host $code]</td>"}]]
            </tr>
        }]
    }
    set options [join [lmap logfile $logfiles {
        set selected [expr {$logfile eq $path ? "selected" : ""}]
        set tail [file tail $logfile]
        set _ "<option value='$tail' $selected>$tail</option>"
    }] \n]

    return [subst {
        <div id='responsetime'></div>
        <div id='requestcount'></div>
        <script>$JS</script>
        <div class="container">
        <h4>Summative Statistics</h4>
        $data
        </table>
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

proc _ns_stats.threads {} {
    set col         [ns_queryget col 1]
    set reverseSort [ns_queryget reversesort 1]

    set pid [pid]
    set threadInfo [ns_info threads]
    if {[file readable /proc/$pid/statm] && [llength [lindex $threadInfo 0]] > 7} {
        set colNumSort  {. 0 0 1 1 1 0 0 1 1 0}
        set colTitles   {Thread Parent ID    Flags "Create Time" TID   State utime stime Args}
        set align       {left   left   right left   left         right right right right left}
        set osInfo      1
        set HZ          100  ;# for more reliable handling, we should implement jiffies_to_timespec or jiffies_to_secs in C
    } else {
        set colNumSort  {. 0 0 1 1 1 0}
        set colTitles   {Thread Parent ID    Flags "Create Time" Args}
        set align       {left   left   right left   left         left}
        set osInfo      0
    }

    if {$osInfo} {
        set ti {}
        foreach t $threadInfo {
            set fn /proc/$pid/task/[lindex $t 7]/stat
            if {[file readable $fn]} {
                set f [open $fn]; set s [read $f]; close $f
            } elseif {[file readable /proc/$pid/task/$pid/stat]} {
                set f [open /proc/$pid/task/$pid/stat]; set s [read $f]; close $f
            } else {
                set s ""
            }
            if {$s ne ""} {
                lassign $s tid comm state ppid pgrp session tty_nr tpgid flags minflt \
                    cminflt majflt cmajflt utime stime cutime cstime priority nice \
                    numthreads itrealval starttime vsize rss rsslim startcode endcode \
                    startstack kstkesp kstkeip signal blocked sigignore sigcatch wchan \
                    nswap cnswap ext_signal processor
                set state "$state [format %.2d $processor]"
            } else {
                lassign {} tid state
                lassign {0 0} utime stime
            }
            lappend ti [linsert $t 5 $tid $state $utime $stime]
        }
        set threadInfo $ti
    }

    set rows ""
    foreach t [_ns_stats.sortResults $threadInfo [expr {$col - 1}] [lindex $colNumSort $col] $reverseSort] {
        set thread  [lindex $t 0]
        set parent  [lindex $t 1]
        set id      [lindex $t 2]
        set flags   [_ns_stats.getThreadType [lindex $t 3]]
        set create  [_ns_stats.fmtTime [lindex $t 4]]
        if {$osInfo} {
            set tid      [lindex $t 5]
            set state    [lindex $t 6]
            set utime    [lindex $t 7]
            set stime    [lindex $t 8]
            set proc     [lindex $t 9]
            set arg      [lindex $t 10]
            if {"p:0x0" eq $proc} { set proc "NULL" }
            if {"a:0x0" eq $arg} { set arg "NULL" }
            set stime    [_ns_stats.hr [expr {$stime*1.0/$HZ}]]s
            set utime    [_ns_stats.hr [expr {$utime*1.0/$HZ}]]s
            lappend rows [list $thread $parent $id $flags $create $tid $state $utime $stime $arg]
        } else {
            set proc     [lindex $t 5]
            set arg      [lindex $t 6]
            if {"p:0x0" eq $proc} { set proc "NULL" }
            if {"a:0x0" eq $arg} { set arg "NULL" }
            lappend rows [list $thread $parent $id $flags $create $arg]
        }
    }

    append html \
        [_ns_stats.header Threads] \
        [_ns_stats.results threads $col $colTitles ?@page=threads $rows $reverseSort $align] \
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
        if {$colNum == $selectedColNum} {
            set colHdrColor($colNum)        "#666666"
            set colHdrFontColor($colNum)    "#ffffff"
            set colColor($colNum)           "#ececec"
        } else {
            set colHdrColor($colNum)        "#999999"
            set colHdrFontColor($colNum)    "#ffffff"
            set colColor($colNum)           "#ffffff"
        }
    }

    set html [ns_trim -delimiter | [subst {
        |<table class="$name">
        |<tr>
    }]]

    set i 1

    foreach title $colTitles {
        set url $colUrl

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

        if {[llength $colAlignment]} {
            set align [lindex $colAlignment $i-1]

            if {[string length $align]} {
                set colAlign $align
            }
        }

        append html \
            "<td valign='middle' align='$colAlign' bgcolor='$colHdrColor($i)'>" \
            "<a href='$url&col=$i$::rawparam'>" \
            "<font color='$colHdrFontColor($i)'>$title</font>" \
            "</a></td>"

        incr i
    }

    append html "</tr>"

    foreach row $rows {
        set i 1
        append html "<tr>"

        foreach column $row title $colTitles {
            set colAlign "left"

            if {[llength $colAlignment]} {
                set align [lindex $colAlignment $i-1]

                if {[string length $align]} {
                    set colAlign $align
                }
            }
            append html "<td class='$title' bgcolor='$colColor($i)' valign=top align=$colAlign>$column</td>"
            incr i
        }

        append html "</tr>"
    }

    append html "\
        </table>"

    return $html
}

proc _ns_stats.msg {type msg} {
    switch $type {
        "error" {
            set color "red"
        }
        "warning" {
            set color "orange"
        }
        "success" {
            set color "green"
        }
        default {
            set color "black"
        }
    }

    return "<font color=$color><b>[string toupper $type]:<br><br>$msg</b></font>"
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

proc _ns_stats.getSchedType {flag} {
    return [_ns_stats.getValue sched_$flag]
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
                break
                puts stderr BREAK
            }
        }
        if {![info exists found]} {
            # fall back to nano
            #puts stderr fallback
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
        #puts "no match"
    }
    return $r
}

# Main processing logic
set page [ns_queryget @page]

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

# Check user access if configured
if { ($enabled == 0 && [ns_conn peeraddr] ni {"127.0.0.1" "::1"}) ||
     ($user ne "" && ([ns_conn authuser] ne $user || [ns_conn authpassword] ne $password)) } {
    ns_returnunauthorized
    return
} else {
    # Produce page
    ns_set update [ns_conn outputheaders] "Expires" "now"
    set html [_ns_stats.$page]
    if {$html ne ""} {
        if {[info exists ::ad_conn(file)]} {
            set path $::ad_conn(file)
        } else {
            set path [ns_url2file [ns_conn url]]
        }
        set fn [file join {*}[lrange [file split $path] 0 end-1]]/$::templateFile
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
