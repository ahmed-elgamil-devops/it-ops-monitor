# Runbook: Host unreachable (High)

1. Acknowledge the alert in Zabbix and note the time.
2. Check if it is one host or many (many = network or switch problem).
3. From the Zabbix host: `ping <IP>`, then `traceroute <IP>` (or `tracert` on Windows).
4. Hyper-V Manager: is the VM running? Check its virtual switch and network adapter.
5. If the VM is off or frozen, start or restart it, then confirm the agent reports again.
6. If the cause is not clear in 15 minutes, escalate to L2 with the results of steps 2 to 5.
7. Close the problem with a short note and add it to the shift handover.
