#!/usr/bin/env bash
set -euo pipefail

discover_subnet() {
  if [[ -n "${X400_SCAN_SUBNET:-}" ]]; then
    printf '%s\n' "$X400_SCAN_SUBNET"
    return 0
  fi

  if command -v ip >/dev/null 2>&1; then
    local cidr
    cidr="$(ip -o -4 addr show up scope global | awk 'NR==1 {print $4}')"
    if [[ "$cidr" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+/[0-9]+$ ]]; then
      printf '%s.0/24\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  fi

  printf '192.168.2.0/24\n'
}

resolve_printer_name() {
  local ip="$1"
  local host_name
  local server_info

  host_name="$(curl -fsS --max-time 1 "http://${ip}/all/hostname" 2>/dev/null | tr -d '\r\n' || true)"
  if [[ -n "$host_name" ]]; then
    printf '%s\n' "$host_name"
    return 0
  fi

  server_info="$(curl -fsS --max-time 1 "http://${ip}:7125/server/info" 2>/dev/null || true)"
  if [[ -n "$server_info" ]]; then
    host_name="$(
      python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("result", {}); print(r.get("hostname") or r.get("system_info", {}).get("hostname", ""), end="")' \
      <<<"$server_info" 2>/dev/null || true
    )"
  fi

  if [[ -z "$host_name" ]]; then
    host_name="$ip"
  fi

  printf '%s\n' "$host_name"
}

if ! command -v nmap >/dev/null 2>&1; then
  echo "[thinker-x400] scan hook skipped: nmap is not installed" >&2
  exit 0
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

hosts_file="$work_dir/nmap_hosts.txt"
ips_file="$work_dir/open_ips.txt"
out_file="{{PRINTER_HOME}}/mainsail/all/printers.txt"
subnet="$(discover_subnet)"

if ! nmap -p 7125 "$subnet" -oG "$hosts_file" >/dev/null 2>&1; then
  echo "[thinker-x400] scan hook skipped: nmap scan failed for subnet ${subnet}" >&2
  exit 0
fi

awk '/7125\/open/ { print $2 }' "$hosts_file" >"$ips_file"

mkdir -p "$(dirname "$out_file")"
: >"$out_file"

while IFS= read -r ip; do
  [[ -n "$ip" ]] || continue
  host_name="$(resolve_printer_name "$ip")"
  printf '%s,%s\n' "$host_name" "$ip"
done <"$ips_file" >>"$out_file"
