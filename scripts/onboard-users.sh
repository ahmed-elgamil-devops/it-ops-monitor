#!/usr/bin/env bash
# Create Linux accounts for new employees from a CSV file.
# CSV columns: username,full_name,group
# Usage: sudo ./onboard-users.sh new-users.csv
set -euo pipefail

csv="${1:?usage: $0 users.csv}"

tail -n +2 "$csv" | while IFS=, read -r username full_name group; do
  [[ -z "$username" ]] && continue
  if id "$username" &>/dev/null; then
    echo "skip: $username already exists"
    continue
  fi
  getent group "$group" >/dev/null || groupadd "$group"
  useradd --create-home --shell /bin/bash --comment "$full_name" --groups "$group" "$username"
  temp_pass="$(openssl rand -base64 12)"
  echo "$username:$temp_pass" | chpasswd
  chage -d 0 "$username"          # must change password at first login
  echo "created: $username ($full_name) in group $group - temporary password: $temp_pass"
done
