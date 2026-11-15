# NOC Monitoring Lab (Zabbix + Hyper-V)

A small Network Operations Center: Zabbix monitors Windows and Linux servers and a
network device, raises alerts by severity, and every alert has a runbook and a
shift-handover record. The servers run as Hyper-V virtual machines.

## What it covers

| Skill asked for in NOC / IT jobs | Where it is in this lab |
| --- | --- |
| Network and server monitoring | Zabbix server, agents and SNMP |
| Virtualization | Hyper-V VMs, checkpoints, virtual switches |
| Alerting and severity | Triggers for host down, high CPU, low disk, service stopped |
| Incident handling | Runbooks in `runbooks/` |
| Shift handover and reporting | `reports/shift-handover-template.md`, weekly availability report |

## Lab layout

| VM / container | Role | IP (Internal virtual switch) |
| --- | --- | --- |
| `zabbix` (Docker on the host) | Zabbix server, web UI, PostgreSQL | host |
| `DC01` (Hyper-V) | Windows Server 2022, AD DS, DNS, DHCP | 192.168.50.10 |
| `PC01` (Hyper-V) | Windows 10/11 client | DHCP |
| `LNX01` (Hyper-V) | Ubuntu Server with Nginx and SNMP | 192.168.50.20 |

## Steps

### 1. Hyper-V
1. Turn on Hyper-V (Windows Features), create an **Internal** virtual switch `LabNet`.
2. Create the three VMs from evaluation ISOs, connect them to `LabNet`, set the IPs above.
3. Take a **checkpoint** of each VM before changes (and document how you restored one).

### 2. Zabbix
```bash
cd zabbix
docker compose up -d
```
Open http://localhost:8081 and log in with the default Zabbix admin account shown in the
Zabbix documentation, then change the password right away.

### 3. Add hosts
- **DC01 and PC01:** install the Zabbix agent 2 (MSI), point it to the host IP, link the
  template *Windows by Zabbix agent*.
- **LNX01:** `sudo apt install zabbix-agent2 snmpd nginx`, link *Linux by Zabbix agent* and
  *Nginx by HTTP*.
- **Network device:** add LNX01 a second time over **SNMP v2** (community `labro`), link
  *Linux by SNMP*, to practise SNMP the way switches and firewalls are monitored.

### 4. Triggers and alerts
Use the template triggers plus these, and set the severity:

| Alert | Severity |
| --- | --- |
| Host unreachable for 3 minutes | High |
| Disk free below 15% | Warning |
| CPU above 90% for 10 minutes | Average |
| Windows service `Spooler` or `DNS` stopped | High |
| Nginx down | Disaster |

Add an e-mail media type (or a Telegram bot) so alerts are sent out.

### 5. Break things on purpose and handle them
Stop the VM, fill the disk, stop the DNS service, stop Nginx. For each one:
watch the alert fire, follow the runbook in `runbooks/`, record it in the shift handover.

### 6. Dashboard and report
Build a dashboard (problems by severity, host availability, top CPU) and export the
weekly availability report from *Reports > Availability report*.

Put screenshots of each step in `screenshots/`.
