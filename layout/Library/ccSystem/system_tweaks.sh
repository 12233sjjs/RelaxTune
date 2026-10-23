#!/bin/sh
# Manual root-only application of the supplied values; never run at installation.
umask 077
state_dir=/var/root/Library/Preferences/ccSystem
state_file="$state_dir/kernel-state"

if [ "$(id -u)" != 0 ]; then
    echo "Run from a root jailbreak terminal." >&2
    exit 1
fi
sysctl_bin=$(command -v sysctl) || exit 1
case "${1:-}" in apply|restore) ;; *) echo "Usage: sh system_tweaks.sh apply|restore" >&2; exit 2 ;; esac
mkdir -p "$state_dir" || exit 1
lock_dir="$state_dir/kernel-lock"
mkdir "$lock_dir" 2>/dev/null || { echo "Another operation is active." >&2; exit 1; }
trap 'rmdir "$lock_dir" 2>/dev/null || :' 0
trap 'exit 130' INT
trap 'exit 143' TERM

valid_key() {
    case "$1" in
        kern.wq_max_threads|kern.maxvnodes|kern.memorystatus_sysprocs_idle_delay_time|\
        kern.memorystatus_apps_idle_delay_time|kern.memorystatus_kill_on_sustained_pressure_delay_ms|\
        kern.vm_max_delayed_work_limit) return 0 ;;
        *) return 1 ;;
    esac
}

restore_values() {
    [ -f "$state_file" ] || { echo "No saved changes."; return 0; }
    while read -r key previous applied extra; do
        valid_key "$key" || { echo "Invalid backup key." >&2; return 1; }
        case "$previous:$applied" in *[!0-9:]*|:*|*:) echo "Invalid backup value." >&2; return 1 ;; esac
        [ -z "$extra" ] || return 1
    done < "$state_file"
    pending="$state_file.pending"
    : > "$pending" || return 1
    while read -r key previous applied; do
        current=$("$sysctl_bin" -n "$key" 2>/dev/null) || current=
        if [ "$current" = "$previous" ]; then
            continue
        elif [ -z "$current" ]; then
            printf '%s %s %s\n' "$key" "$previous" "$applied" >> "$pending"
        elif [ "$current" != "$applied" ]; then
            echo "Preserved external change: $key"
        elif "$sysctl_bin" "$key=$previous" >/dev/null 2>&1 &&
             [ "$("$sysctl_bin" -n "$key" 2>/dev/null)" = "$previous" ]; then
            echo "Restored: $key=$previous"
        else
            printf '%s %s %s\n' "$key" "$previous" "$applied" >> "$pending"
        fi
    done < "$state_file"
    if [ -s "$pending" ]; then
        mv "$pending" "$state_file" || return 1
        echo "Some values could not be restored; backup retained." >&2
        return 1
    fi
    rm -f "$pending" "$state_file"
}

if [ "$1" = restore ]; then
    restore_values
    exit $?
fi
if [ -s "$state_file" ]; then
    echo "Changes already saved. Restore before applying again."
    exit 0
fi

echo "Experimental kernel values, not CPU frequency or FPS controls."
echo "The sustained-pressure delay requests 86400000 ms (24 hours) if supported."
: > "$state_file" || exit 1
changed=0
while read -r key desired; do
    previous=$("$sysctl_bin" -n "$key" 2>/dev/null) || {
        echo "Skipped unsupported/inaccessible key: $key"
        continue
    }
    case "$previous" in ''|*[!0-9]*) echo "Skipped non-integer key: $key"; continue ;; esac
    [ "$previous" = "$desired" ] && continue
    printf '%s %s %s\n' "$key" "$previous" "$desired" >> "$state_file" || {
        restore_values
        exit 1
    }
    if "$sysctl_bin" "$key=$desired" >/dev/null 2>&1 &&
       [ "$("$sysctl_bin" -n "$key" 2>/dev/null)" = "$desired" ]; then
        changed=$((changed + 1))
        echo "Applied: $key=$desired"
    else
        echo "Write failed; restoring changes: $key" >&2
        restore_values
        exit 1
    fi
done <<'VALUES'
kern.wq_max_threads 2048
kern.maxvnodes 20000
kern.memorystatus_sysprocs_idle_delay_time 1
kern.memorystatus_apps_idle_delay_time 1
kern.memorystatus_kill_on_sustained_pressure_delay_ms 86400000
kern.vm_max_delayed_work_limit 64
VALUES
[ "$changed" -gt 0 ] || rm -f "$state_file"
"$sysctl_bin" vm.swapusage 2>/dev/null || :
echo "Changed keys: $changed"
