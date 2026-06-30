#!/bin/bash

set -euo pipefail

monitor_names=()
while IFS= read -r monitor_name; do
  if [ -n "$monitor_name" ]; then
    monitor_names+=("$monitor_name")
  fi
done < <(aerospace list-monitors --format '%{monitor-name}')

monitor_count=${#monitor_names[@]}
if [ "$monitor_count" -lt 2 ]; then
  exit 0
fi

focused_monitor=$(aerospace list-monitors --focused --format '%{monitor-name}' | head -n 1)
if [ -z "$focused_monitor" ]; then
  exit 0
fi

visible_workspaces=()
for ((i = 0; i < monitor_count; i++)); do
  workspace=$(aerospace list-workspaces --monitor "$((i + 1))" --visible --format '%{workspace}' | head -n 1)
  if [ -z "$workspace" ]; then
    exit 0
  fi
  visible_workspaces+=("$workspace")
done

# Rotate whole workspace positions clockwise across the monitor ring.
for ((i = monitor_count - 1; i > 0; i--)); do
  source_workspace="${visible_workspaces[$((i - 1))]}"
  displaced_workspace="${visible_workspaces[$i]}"
  target_monitor="${monitor_names[$i]}"
  source_monitor="${monitor_names[$((i - 1))]}"

  aerospace move-workspace-to-monitor --workspace "$source_workspace" "$target_monitor"
  aerospace focus-monitor "$source_monitor"
  aerospace summon-workspace "$displaced_workspace"
done

aerospace focus-monitor "$focused_monitor"
