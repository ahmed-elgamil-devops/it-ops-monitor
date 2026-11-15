# Runbook: Service stopped (DNS, Spooler, Nginx)

1. Acknowledge the alert and confirm users are affected (DNS and web = high impact).
2. Windows: `Get-Service <name>` then `Start-Service <name>`; check Event Viewer > System
   for the reason it stopped.
   Linux: `systemctl status nginx`, `journalctl -u nginx -n 50`, then `systemctl start nginx`.
3. If it stops again, do not keep restarting: collect the error and escalate to L2.
4. Confirm the service is healthy in Zabbix, close the problem with the root cause,
   and add it to the shift handover.
