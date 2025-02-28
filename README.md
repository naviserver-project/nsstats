# Statistics Module for NaviServer 4.99.27

**Release:** 1.13  
**Authors:**  
- Vlad Seryakov (<vlad@crystalballinc.com>)  
- Gustaf Neumann (<neumann@wu-wien.ac.at>)

## Overview

**Nsstats** is a pure Tcl module designed for NaviServer that provides detailed insights into the performance and activity of your server installation. It reports various statistics to help you monitor and optimize your setup, including:

- Cache usage
- Configuration parameters
- Mutex lock statistics
- NSV usage and lock details
- Runtime statistics from virtual servers and pools
- Scheduled procedures
- Thread information
- Driver usage
- Web-accessible data:
  - Configuration file
  - Recent entries from the error log

## Changes Since Version 1.0

- Updated reporting of actual configuration parameters
- Added per-server and per-pool process statistics
- Introduced queueing and spooling statistics
- Included queuing time and filter time runtime per pool
- Expanded cache statistics (e.g., saved times)
- Enabled direct access to the configuration file
- Reported maximum wait time, total wait time, total lock time, and average lock time
- Mapped NSV locks from variable names to buckets and locks
- Enhanced thread statistics with user time, system time, processor number, and state (Linux only)
- Added comprehensive log statistics
- Implemented pages for displaying/toggling log levels
- Added a page to show URLs mapped to connection thread pools
- Provided additional driver information (threads and stats)
- Formatted values in a human-readable manner
- Displayed running writers, connection channel jobs, and nsproxy jobs
- Included database pool statistics
- Reported NSV size statistics
- Added cache reuse charts
- Introduced quick log file analysis (e.g., searching error.log and access.log for request IDs)
- Included HTTP client log statistics

## Installation Instructions

1. **Enable the Module:**  
   Set the `enabled` parameter to `1` to activate the module.

2. **Place the File:**  
   Copy the module file to a directory within your NaviServer page directory (typically `/usr/local/ns/pages`).

3. **Access the Module:**  
   Open your web browser and navigate to the module's URL.

**Security Notice:**

This module provides access to potentially sensitive information. Do not deploy it on public websites unless you have proper access controls in place. For OpenACS installations, it is advisable to place the file (e.g., `nsstats.tcl`) in a secure directory such as `acs-subsite/www/admin/`, ensuring that it is accessible only to authorized subsites.

**Access Control Criteria:**

Access to the page is granted if the module is enabled and at least one of the following conditions is met:

- The page is installed within an OpenACS installation under `/acs-admin/` or another `/admin/` directory.
- The `nsperm` module is installed, a non-empty user is configured, and that user is authenticated.
- A non-empty user is configured and successfully authenticated using the password specified in the configuration file.
- The access request originates from a non-public routable IP address.


## Configuration

The nsstats module is configurable via the NaviServer configuration file. Below is an example configuration block:

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
  Enables or disables the nsstats module for the NaviServer instance.

- **user** (string, default: `""`) and **password** (string, default: `""`)  
  Specify the credentials for accessing the nsstats module. If non-empty values are provided, the browser will prompt for authentication.

- **bglocks** (list, default: `""`)  
  Defines mutex locks that are primarily used for background processes. For instance, the `oacs:sched_procs` lock in OpenACS is typically excluded from page request-related statistics, as its role is different.

If these settings are not included in the NaviServer configuration file, you can alternatively configure nsstats by modifying the values at the top of the script file.

Access control for the default user can be managed through the nsperm module or, in the case of OpenACS, via URL path permissions.

## Authors

- **Vlad Seryakov** (<vlad@crystalballinc.com>)
- **Gustaf Neumann** (<neumann@wu-wien.ac.at>)
