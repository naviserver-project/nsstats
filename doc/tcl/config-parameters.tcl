# Module-owned configuration documentation; generated fragments use this source.
namespace eval ::ns_configdoc {}
dict set ::ns_configdoc::data modules nsstats {
            :title {nsstats}
            :scope global
            :desc {
                The nsstats module provides status and diagnostic pages for a running
                NaviServer instance. It is configured as a global Tcl module and can
                display runtime information such as server statistics, locks, threads,
                loaded modules, and the current configuration database.

                This module provides access to potentially sensitive
                information. Do not deploy it on public-facing
                websites unless you implement appropriate access
                controls. For OpenACS installations, it is recommended
                to place the module main script nsstats.tcl in a
                secure directory such as acs-subsite/www/admin/,
                ensuring that only authorized users can access it.
            }
            :see {
                {uri https://github.com/naviserver-project/nsstats nsstats}
            }

            :example {
                ns_section ns/module/nsstats {
                    ns_param enabled  true
                    ns_param user     nsadmin
                    ns_param password ""
                    ns_param bglocks  {oacs:sched_procs}
                }
            }

            enabled {
                type boolean
                default {true}
                desc {Enable or disable the nsstats module}
            }

            user {
                type string
                default {nsadmin}
                desc {User name required for accessing nsstats pages}
            }

            password {
                type password
                default {}
                desc {Password required for accessing nsstats pages; when empty, access control depends on the surrounding configuration}
            }

            bglocks {
                type list
                default {}
                desc {List of lock names treated as non-per-request background locks in nsstats lock reporting}
            }
        }
