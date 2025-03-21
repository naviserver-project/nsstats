<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%=$::title%></title>
  <link rel="icon" type="image/svg+xml" href="favicon.svg">
  <style>
    /* Global */
    html {
      scroll-behavior: smooth;
    }
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background-color: #f9f9f9;
    }
    /* Header */
    header.custom-header {
      display: flex;
      align-items: center;
      background-color: #004080;
      color: #fff;
      padding: 20px;
    }
    header.custom-header h1 {
      margin: 0;
      font-size: 24px;
      display: inline-block;
    }
    header.custom-header .header-right {
      margin-left: auto;
      text-align: right;
    }
    header.custom-header .header-right p {
      margin: 0;
      line-height: 1.2;
      font-size: 12px;
    }
    header.custom-header h1 a {
       color: #fff;
       font-size: 1em;
       text-decoration: none;
    }
    header span.tagline { font-size: 16px; font-weight: 400; margin-left: 16px; }

    /* Breadcrumbs */
    .breadcrumbs {
      padding: 8px 16px;
      background-color: #f1f1f1;
      font-size: 0.9em;
      color: #666;
      clear: both;
    }
    .breadcrumbs a {
      color: #004080;
      text-decoration: none;
    }
    .breadcrumbs a:hover {
      text-decoration: underline;
    }

    /* Menubar using Flexbox */
    .menu-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background-color: #004080 !important;
      padding: 0 10px;
    }
    .menu-left {
      display: flex;
      align-items: center;
    }
    .menu-bar a,
    .menu-bar .dropdown-btn {
      color: #fff;
      text-decoration: none;
      padding: 14px 10px;
      font-size: 1em;
      background-color: inherit;
      border: none;
      cursor: pointer;
    }
    .menu-bar a:hover,
    .menu-bar a.active,
    .menu-left .dropdown:hover .dropdown-btn {
      background-color: #0056b3;
    }
   /* Menubar adjustments for small devices */
    @media (max-width: 905px) {
      .menu-bar a,
      .menu-bar .dropdown-btn,
      .raw-toggle {
        padding: 6px 6px; /* reduced padding */
        font-size: 12px;    /* smaller text */
      }
      .dropdown .dropdown-content {
        min-width: 200px;   /* slightly smaller dropdowns */
      }
    }
     @media (max-width: 480px) {
      .menu-bar {
        padding: 0 10px;
      }
    }

    /* Dropdowns */
    .dropdown {
      position: relative;
      margin-right: 10px;
    }
    @media (max-width: 480px) {
      .dropdown {
        margin-right: 2px;
      }
    }
    .dropdown .dropdown-btn {
      /* Already styled above */
    }
    .dropdown .dropdown-content {
      display: none;
      position: absolute;
      top: 100%;
      left: 0;
      background-color: #fff;
      min-width: 250px;
      box-shadow: 0 8px 1em rgba(0,0,0,0.2);
      z-index: 1;
    }
    .dropdown .dropdown-content a {
      display: block;
      text-align: left;
      padding: 12px 16px;
      color: #004080;
      text-decoration: none;
      white-space: normal;
    }
    .dropdown .dropdown-content a:hover {
      background-color: #ddd;
    }
    .dropdown:hover .dropdown-content {
      display: block;
    }
    .dropdown-marker {
      margin-left: 3px; /* Increase separation from label */
      font-size: 0.7em; /* Make the marker smaller */
      opacity: 0.8;
    }

    /* Raw Toggle */
    .raw-toggle {
      padding: 12px 20px;
      color: #fff;
    }
    .raw-label {
      font-weight: normal;
    }
    .raw-value {
      color: #ffc107;
      font-weight: bold;
    }
    /* Main Layout */
    .main-container {
      display: flex;
      align-items: flex-start;
      padding: 20px;
    }
    /* Sidebar */
    .sidebar {
      width: 250px;
      background-color: #eeeeee;
      padding: 15px;
      box-sizing: border-box;
      position: sticky;
      top: 0;
      height: calc(100vh - 100px);
      overflow-y: auto;
      border-right: 1px solid #ccc;
      margin-right: 20px;
    }
    .sidebar ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    .sidebar li {
      margin-bottom: 10px;
    }
    .sidebar a {
      text-decoration: none;
      color: #004080;
      font-weight: bold;
      font-size: 13px;
    }
    @media (max-width: 905px) {
      .sidebar {
        width: 150px;
        padding: 10px;
        top: 0;
        height: calc(100vh - 100px);
        overflow-y: auto;
        border-right: 1px solid #ccc;
        margin-right: 10px;
      }
      .sidebar a {
        font-size: 11px;
      }
      .sidebar li {
        margin-bottom: 6px;
      }
    }
    /* Content */
    .content {
      flex: 1;
    }
    .content h2 {
      color: #004080;
      border-bottom: 2px solid #ccc;
      padding-bottom: 5px;
      margin-top: 10px;
      text-align: left;
    }
    /* Table Styling */
    .data-table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid gray;
      margin-top: 20px;
      table-layout: fixed;
    }
    .data-table th:first-child,
    .data-table td:first-child {
      width: 250px;
    }

    @media (max-width: 905px) {
      .data-table th:first-child,
      .data-table td:first-child {
        width: 150px; /* Reduced width on small screens */
      }
    }
    .data-table th,
    .data-table td {
      border: 1px solid #ccc;
      padding: 8px;
      text-align: left;
      font-size: 0.9rem;
    }
    .data-table th {
      background-color: #999;
      color: #fff;
    }
    .data-table th a {
      color: inherit;
    }
    .data-table .coltitle {
      /*background-color: #eaeaea;*/
      font-weight: bold;
    }
    .data-table .colvalue {
      overflow-wrap: break-word;
    }
    /* Tooltip Styling */
    .tooltip {
      position: relative;
    }
    .tooltip .tooltiptext {
      visibility: hidden;
      /*width: 250px;*/
      background-color: #999;
      color: #fff;
      text-align: center;
      padding: 5px 10px;
      margin-left: 15px;
      margin-top: -5px;
      border-radius: 6px;
      position: absolute;
      z-index: 1;
      opacity: 0;
      transition: opacity 0.3s;
     }
    .tooltip.unread .tooltiptext           {background-color: #900;}
    .tooltip.unread .tooltiptext::after    {border-color: transparent #900 transparent transparent;}
    .tooltip.defaulted .tooltiptext        {background-color: #aaa;}
    .tooltip.defaulted .tooltiptext::after {border-color: transparent #aaa transparent transparent;}
    .tooltip.notneeded .tooltiptext        {background-color: orange;}
    .tooltip.notneeded .tooltiptext::after {border-color: transparent orange transparent transparent;}

    .tooltip:hover .tooltiptext {
      visibility: visible;
      opacity: 1;
    }
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
    /* Tip Marker Styling */
    .tip {
      cursor: help;
      color: #777;
      position: relative;
    }
    .tip::after {
      content: " ⓘ";
      font-size: 0.9em;
      color: #777;
      margin-left: 4px;
    }
    /* Footer */
    footer {
      background-color: #f1f1f1;
      padding: 10px;
      text-align: center;
    }

    tr.sortable td.selected   { background: #666666; color: #ffffff; }
    tr.sortable td.unselected { background: #999999; color: #ffffff; }
    tr.data td.selected       { background: #ececec; }
    tr.data td.unselected     { background: #ffffff; }


/* For nested table in process page */
table.data-table td td.subtitle {text-align: right; white-space: nowrap; font-style: italic; background-color: #e6e6e6;}
table.data-table td table td {font-size:smaller !important; padding: 2px !important; border-width: 0px !important;}

/* Styling for defaulted/unread/notneed parameters */
td.defaulted {color: #aaa;}
td.unread {color: red;}
td.notneeded {color: orange;}
table.config {font-size: 0.9rem;}


  </style>
  <%= $::extraHeadEntries %>
</head>

<body>
<%
    set linkLines {}
    set level 0
    foreach {name label} $::navLinks {
        if {$name eq "process"} continue
        set dropdown [expr {[info procs _ns_stats.$name] eq ""}]
        set postincr 0
        
        if {$dropdown} {
            set item [subst [ns_trim -delimiter | {
                |<div class="dropdown">
                | <button class="dropdown-btn">$label<span class="dropdown-marker">▼</span></button>
                | <div class="dropdown-content">}]]
            set postincr 1
        } else {
            set item "<a href='?@page=$name$::rawparam'>$label</a>"
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
%>
              
<!-- Header -->
<header class="custom-header">
  <h1><a href="<%=[ns_conn url]%>">NaviServer<span class="tagline">Monitoring and Statistics</span></a></h1>
  <div class="header-right">
    <p><strong><%=[ns_info hostname]%></strong></p>
    <p><%=[_ns_stats.fmtTime [ns_time]]%></p>
  </div>
  <div style="clear: both;"></div>
</header>

<!-- Menubar -->
<div class="menu-bar">
  <div class="menu-left">
  <%=[join $linkLines \n]%>
  </div>
  <div class="raw-toggle">
    <span class="raw-label">Raw:</span> <span class="raw-value"><%=$::rawLabel%></span>
  </div>
</div>

<!-- Breadcrumbs -->
<div class="breadcrumbs">
  <a href="/">Home</a> &gt; <a href="<%=[ns_conn url]%>">nsstats</a>  &gt; <%=[dict get $::navLinks $::page]%>
  <!-- <%= $::nav %> -->
</div>

<!-- Main Container -->
<div class="main-container">
  <!-- Sidebar -->
  <%=[expr {[info exists ::sidebar] ? $::sidebar : ""}]%>
  <!-- Main Content -->
    <div class="content"> 
    <h2><%=[dict get $::titles $::page]%></h2>
<%= $html %>
    </div>
</div>

<footer>
<%= $::footer %>
</footer>

</body>
</html>

