<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%=$::title%></title>
  <!--<link rel="icon" type="image/svg+xml" href="favicon.svg"> -->
<style>

:root {
  --color-body-bg: #f9f9f9;               /* body */
  --color-body-text: #000000;             /* body text */
  --color-anchor: #004080;                /* link text color */

  --color-border: #ccc;                   /* sidebar, data-table */
  --color-dropdown-btn-bg: #0056b3;       /* dropdown buttons */
  --color-dropdown-btn-text: #fff;        /* dropdown buttons */
  --color-dropdown-content-anchor-text: var(--color-anchor); /* dropdown --content */
  --color-dropdown-content-bg: #fff;      /* dropdown content */
  --color-dropdown-hover-bg: #ddd;        /* dropdown link hover */
  --color-h2-text: #004080;               /* h2 text */
  --color-header-bg: #004080;             /* header */
  --color-header-strong-text: #fff;       /* "NaviServer" in the main header */
  --color-header-text: #fff;              /* header */
  --color-menubar-bg: #00376f;            /* menubar; was 004080ed; */
  --color-secondary-bg: #f1f1f1;          /* breadcrums, sidebar */
  --color-sidebar-anchor: #004080;        /* sidebar link */
  --color-subtitle-bg: #e6e6e6;           /* table subtitle */
  --color-table-header-bg: #999;          /* data-table header */
  --dropdown-content-border-width: 0px;

  /*--color-anchor-hover: #e0e0e0;
  --accent-color: #0066cc;*/
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-body-bg: #0F1B2B;
    --color-body-text: #E0E0E0;
    --color-anchor: #84b3ff; /*#4D90FE;*/

    --color-border: #444;
    --color-dropdown-btn-bg: #333333;
    --color-dropdown-btn-text: #8CA6C0;
    --color-dropdown-content-anchor-text: var(--color-dropdown-btn-text); /* dropdown content */
    --color-dropdown-content-bg: #1f1f1f;
    --color-dropdown-hover-bg: #2C3E50;
    --color-h2-text: #DCDCDC;
    --color-header-bg: #1B263B;
    --color-header-strong-text: #9CB3C9; /* var(--color-anchor), #B0CFE0; */
    --color-header-text: #fff;
    --color-menubar-bg: var(--color-header-bg);
    --color-secondary-bg: #1B263B;
    --color-sidebar-anchor: #ddd;
    --color-subtitle-bg: #444;
    --color-table-header-bg: #666;
    --dropdown-content-border-width: 2px;

    /* --color-anchor-hover: #2C3E50;
    --accent-color: #4D90FE; */
  }
}

    /* Global */
    html {
      scroll-behavior: smooth;
    }
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background-color: var(--color-body-bg); /*was #f9f9f9;*/
      color: var(--color-body-text);
    }
a {
  color: var(--color-anchor);
  text-decoration: none;
}
/* Header */
    header.custom-header {
      display: flex;
      align-items: center;
      background-color: var(--color-header-bg); /*was #004080;*/
      color: var(--color-header-text); /*was #fff; */
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
       font-size: 1em;
       text-decoration: none;
    }
    header.custom-header h1 a:hover {
      text-decoration: underline;
      color: var(--color-header-strong-text);
    }
    header.custom-header h1 a strong {
       color: var(--color-header-strong-text); /*var(--color-dropdown-btn-text);*/
    }
    header span.tagline { font-size: 16px; font-weight: 400; margin-left: 16px; }

    /* Breadcrumbs */
    .breadcrumbs {
      padding: 8px 16px;
      background-color: var(--color-secondary-bg); /*was #f1f1f1;*/
      font-size: 0.9em;
      color: #666;
      clear: both;
    }
    .breadcrumbs a {
      color: var(--color-anchor); /*was #004080;*/
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
      background-color: var(--color-menubar-bg) !important; /*was #004080;*/
      padding: 0 10px;
    }
    .menu-left {
      display: flex;
      align-items: center;
    }
    .menu-bar a,
    .menu-bar .dropdown-btn {
      color: var(--color-dropdown-btn-text);
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
        background-color: var(--color-dropdown-btn-bg) !important; /*was #0056b3*/
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
      background-color: var(--color-dropdown-content-bg);
      border: var(--dropdown-content-border-width) solid var(--color-dropdown-btn-bg);
      min-width: 250px;
      box-shadow: 0 8px 1em rgba(0,0,0,0.2);
      z-index: 1;
    }
    .dropdown .dropdown-content a {
      display: block;
      text-align: left;
      padding: 12px 16px;
      color: var(--color-dropdown-content-anchor-text); /*was #004080;*/
      text-decoration: none;
      white-space: normal;
    }
    .dropdown .dropdown-content a:hover {
      background-color: var(--color-dropdown-hover-bg) !important; /* was #ddd*/
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
      background-color: var(--color-secondary-bg); /*was #eeeeee;*/
      padding: 15px;
      box-sizing: border-box;
      position: sticky;
      top: 0;
      height: calc(100vh - 100px);
      overflow-y: auto;
      border-right: 1px solid var(--color-border) /*was #ccc*/;
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
      color: var(--color-sidebar-anchor); /*was #004080;*/
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
        border-right: 1px solid var(--color-border);
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
      color: var(--color-h2-text); /*was #004080;*/
      border-bottom: 2px solid var(--color-border) ;
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

   .data-table.sched th,
   .data-table.sched td {
       word-break: break-word;
    }
    .data-table.sched th:first-child,
    .data-table.sched td:first-child {
      width: 2em;
    }
    .data-table.sched th:nth-child(4),
    .data-table.sched td:nth-child(4) {
      width: 450px;
    }
    @media (max-width: 905px) {
      .data-table.sched th,
      .data-table.sched td {
          font-size: smaller;
       }
      .data-table.sched th:nth-child(4),
      .data-table.sched td:nth-child(4) {
        width: 220px; /* Reduced width on small screens */
      }
    }

    .data-table th,
    .data-table td {
      border: 1px solid var(--color-border) ;
      padding: 8px;
      text-align: left;
      font-size: 0.9rem;
    }
    .data-table th {
      background-color:  var(--color-table-header-bg); /*was #999*/
      color: #fff;
    }
    .data-table th a {
      color: inherit;
    }
    .data-table .coltitle {
      /*background-color: #eaeaea;*/
      font-weight: bold;
      vertical-align: top;
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
table.data-table td td.subtitle {
   text-align: right; white-space: nowrap; font-style: italic;
   width:100px;
   background-color:  var(--color-subtitle-bg); /*was #e6e6e6;*/
}
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
  <h1><a href="<%=[ns_conn url]%>"><strong>NaviServer</strong></a><span class="tagline">Monitoring and Statistics</span></h1>
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
  <a href="/">Home</a> &gt; <a href="<%=[ns_conn url]%>">nsstats</a>
  &gt; <%=[expr {[dict exists $::navLinks $page]?[dict get $::navLinks $page]:[dict get $::titles $page]}]%>
  <!-- <%= $::nav %> -->
</div>

<!-- Main Container -->
<div class="main-container">
  <!-- Sidebar -->
  <%=[expr {[info exists ::sidebar] ? $::sidebar : ""}]%>
  <!-- Main Content -->
    <div class="content">
    <h2><%=[dict get $::titles $page]%></h2>
<%= $html %>
    </div>
</div>

<footer>
<%= $::footer %>
</footer>

</body>
</html>
