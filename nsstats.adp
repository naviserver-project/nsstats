<!DOCTYPE html lang="en">
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://www.w3schools.com/w3css/4/w3.css">
<title><%= $::title %></title>
<style type='text/css'>
/* tooltip styling. by default the element to be styled is .tooltip  */
.tip {
   cursor: help;
   text-decoration:underline;
   color: #777777;
}
.w3-bar { font-size: 8pt; color: #000000;}
.w3-example .w3-container { font-size: 8pt;}
.w3-example { font-size: 10pt;}
.w3-example a { text-decoration: underline; color: #006fc6}
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

table.data {padding: 0px; border-spacing: 1px}
table.data td.coltitle {width: 110px; text-align: right; background-color: #eaeaea;}
table.data td td.subtitle {text-align: right; white-space: nowrap; font-style: italic; font-size: 7pt; background-color: #f5f5f5;}
table.data th {background-color: #999999; color: #ffffff; font-weight: normal; text-align: left;}
table.data td {background-color: #ffffff; padding: 4px;}
table.data td table {background-color: #ffffff; border-spacing: 0px;}
table.data td table td {padding: 2px;}

.dropdown-toggle::after {
    display: inline-block;
    margin-left: 0.255em;
    vertical-align: 0.255em;
    content: "";
    border-top: 0.3em solid;
    border-right: 0.3em solid transparent;
    border-bottom: 0;
    border-left: 0.3em solid transparent;
}
div.w3-example .w3-container a {
    text-decoration: none;
}
div.w3-bar-item a.current {
    text-decoration: none;
}
table.requestprocs td.Arg {
    white-space: pre;
    font-size: 6pt;
}
div.methodfilter .w3-check {
    width: 12px;
    height: 12px;
    top: 2px;
}
div.methodfilter label {
     margin-right: 6px;
}
</style>
<%= $::extraHeadEntries %>
</head>

<body>
<%
    set w3color black ;#blue-grey
    lappend linkLines "<img class='w3-bar-item' src='https://naviserver.sourceforge.io/ns-icon-16.png'>"
    set level 0
    foreach {name label} $::navLinks {
        set dropdown [expr {[info procs _ns_stats.$name] eq ""}]
        set postincr 0
        
        if {$dropdown} {
            set item [subst [ns_trim -delimiter | {
                |<div class="w3-dropdown-hover">
                | <button class="w3-button dropdown-toggle w3-$w3color">$label</button>
                | <div class="w3-dropdown-content w3-bar-block w3-card-4">}]]
            set postincr 1
        } else {
            set item \
                "<a href='?@page=$name$::rawparam' class='w3-bar-item w3-button w3-mobile'>$label</a>"
        }
        if {$level == 1 && ![string match *.* $name]} {
            #
            # End pulldown before outputting next item.
            #
            lappend linkLines </div></div>       
            incr level -1
        }
        lappend linkLines "[string repeat {  } $level]$item"
        incr level $postincr
    }
    lappend linkLines \
            [subst [ns_trim -delimiter | {
              |<div class='w3-bar-item w3-right'>
              |  Raw: <a class='current w3-text-amber' href='$::rawUrl'>$::rawLabel</a> &middot; 
              | <strong>[_ns_stats.fmtTime [ns_time]]</strong>
              |</div>}]]
%>

<div class="w3-container">
<div class="w3-bar w3-border w3-<%= $w3color %>">
<%= [join $linkLines \n] %>
</div>
<div class="w3-example">
<div class="w3-container w3-light-grey">
  <%= $::nav %>
</div><%= $html %>
</div>
</div>
<%= $::footer %>
