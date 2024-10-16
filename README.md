# Kasm Workspaces Docker STIG Hardening Scripts

## Warning
**This open-source project is not officially supported under a Kasm support license. It is an open-source project provided to the community to assist with hardening systems to meet DoD STIG requirements. Kasm Technologies does not provide any guarantees that these scripts will work as designed on every possible system and different configurations. There is the possibility that running these scripts can break systems and caution should be taken before running these scripts.**

---

## Supported Kasm Workspaces Versions
Ensure that you switch to a branch that matches the version of Kasm Workspaces that you have installed. For example, if you are running Kasm Workspaces 1.12.0, ensure that you change to the release/1.12.0 branch before applying the script, for 1.11.0 change to release/1.11.0.

```bash
git clone https://github.com/kasmtech/workspaces-stigs.git
cd workspaces-stigs
git checkout release/1.12.0
```

## Supported Architectures
These hardening scripts will only work on x86_64/AMD64 based architectures.

## Supported Operating Systems
These hardening scripts have been tested by Kasm Technologies on the following operating systems. It should be noted that we started with a base OS install and then installed Kasm Workspaces. These systems were not pre-configured in any way nor did they already have docker installed. These hardening scripts may not work on the following operating systems if they have unique non-default configurations. A Linux kernel version of 4.11 or newer is required.

* Ubuntu 20.04 LTS base OS
* Ubuntu 20.04 LTS with Advantage subscription, full OS level hardened with FIPS mode enabled 
* CentOS 7 base OS with upgraded kernel >= 4.11

Please open an issue on the project's issue tracker to report your experience with other operating systems. The scripts have been written such that they should work on any Linux distro with the prerquisites sited.

## Prerequisites

Auditd must be installed on the operating system. Auditd is required to meet base operating system STIG requirements and should therefore already be installed. The package 'jq' is also required and should be available in the operating systems package repository for most operating systems.

The apply_kasm_stigs.sh will pull down and install the yq utility automatically on an internet connected host. 
If you are on an air gapped network, please pull down the latest yq from here: https://github.com/mikefarah/yq/releases and put the binary here: /opt/kasm/bin/utilities/yq_x86_64

## Applying the Scripts

Kasm must be running when executing these scripts on the web app servers and agent servers. The apply_kasm_stigs.sh will handle shutting down and restarting kasm service containers when needed.
The order that the scripts are ran is important, run the apply_docker_stigs.sh first, then run the apply_kasm_stigs.sh

```bash
# Kasm Workspaces must already be installed
git clone https://github.com/kasmtech/workspaces-stigs.git
cd workspaces-stigs
# switch to the release branch that matches your installed version of Kasm Workspaces
git checkout release/1.12.0
sudo bash apply_docker_stigs.sh
sudo bash apply_kasm_stigs.sh
```

V-235819 will fail if Kasm was installed using the default listening port of 443. To pass this check, Kasm must be installed with the -L 8443 flag, where 8443 can be any port above 1024.
In a hardened environment, it is assumed that Kasm will be proxied behind a security device, such as an F5 or NGINX, which supports proxying on 443 to end-users.

## Considerations when executing a database backup
Because the database is running as uid 70 gid 70, when you execute the /opt/kasm/bin/utils/db_backup script ensure that the directory passed for the backup file is writable by uid:70 or the backup will fail.

## Considerations when executing a database restore
When running a db_restore against a hardened Kasm 1.12.0 instance there is a modification that is needed for the db_restore script.
Change line 144 of the db_restore script:

    TEMP_DB_BACKUP_PATH=${KASM_INSTALL_BASE}/conf/database/

Change the line to:

    TEMP_DB_BACKUP_PATH=${KASM_INSTALL_BASE}/tmp/kasm_db/

## Verbose output for Checklist Artifacts
When running apply_docker_stigs.sh or apply_kasm_stigs.sh, an optional flag `--verbose` can be set to show the output of the commands specified in the STIG check to validate the system passes the check. In some cases this STIG hardening script will show **PASS** but the command ouput may indicates a failure according to the STIG. The hardening script does not restart docker until the end, so changes made during the script execution may not have been applied yet. Therefore, you may need to run the script twice with the `--verbose` flag to ensure the output matches the PASS status provided by the script. Artifacts will be output in the following format:

    V-235831, PASS, log driver is enabled
    Command: cat /etc/docker/daemon.json | grep -i log-driver
    Output:   "log-driver": "syslog",



    

     