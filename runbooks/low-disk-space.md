# Runbook: Disk free below 15% (Warning)

1. Acknowledge the alert and check how fast the disk is filling (Latest data > graph).
2. Windows: run `Get-PSDrive C` and find large folders (logs, temp, old updates).
   Linux: `df -h`, then `du -sh /var/log/* | sort -h | tail`.
3. Safe clean-up only: rotate or compress old logs, empty temp, clear old update files.
4. Do not delete application data or databases. If space is still low, escalate to L2
   with the size of the top folders.
5. Confirm the alert clears and record the action in the shift handover.
