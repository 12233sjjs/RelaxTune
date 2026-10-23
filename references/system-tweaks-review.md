# Supplied kernel script review

Input: `system_tweaks(1).sh`, preserved as `system_tweaks.original.sh`.
The original is not executed. Both packages install a manual apply/restore
adaptation at `Library/ccSystem/system_tweaks.sh`, with the same six numeric values.
It requires an explicit root-terminal command and is never run by installation,
startup, or game-entry hooks.

The input checks a fixed `/var/jb` prefix and assumes Dopamine. The target uses
Relaxin/RootHide, where that prefix is not a portable environment check.
`set -e` may stop after earlier writes have succeeded, without restoring them.

| Input | Review |
| --- | --- |
| `kern.wq_max_threads=2048` | A workqueue thread limit, not a CPU clock or FPS control. No target-device baseline, writable-key check, or workload evidence was supplied. |
| `kern.maxvnodes=20000` | A filesystem vnode limit, not a virtual-memory size setting. No evidence supports this fixed limit on the target phone. |
| `vm.swapusage` | A read, not an optimization. A missing or inaccessible key can abort this script after preceding writes. |
| `kern.memorystatus_sysprocs_idle_delay_time=1` | Changes system-process idle handling if the key exists and is writable. Target support and consequences were not verified. |
| `kern.memorystatus_apps_idle_delay_time=1` | Changes application idle handling if available. It does not establish a game-performance improvement. |
| `kern.memorystatus_kill_on_sustained_pressure_delay_ms=86400000` | Requests a 24-hour delay. Apple's current XNU source uses a differently nested `kern.memorystatus` sysctl and a 500 ms default. That source does not prove key availability on iOS 16.6.1, and does not justify a 24-hour delay. |
| `kern.vm_max_delayed_work_limit=64` | No target-device support, baseline, or benefit was verified. It is not a display refresh setting. |

No kernel writes are enabled automatically. Manual application skips unreadable
or absent keys, backs up supported integer values, verifies writes and attempts
rollback on failure. It does not remap the original key names to newer XNU names.
Restoration preserves values changed by other tools and retains failed entries.
The game policy separately suspends low-power mode while the supported game is
foreground, and restores the user's prior manual state afterward. CPU/GPU clocks
and system thermal protections are unchanged.

Primary source checks:

- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_memorystatus_notify.c
- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/pthread/pthread_workqueue.c
- https://github.com/theos/headers/blob/master/LowPowerMode/_PMLowPowerMode.h
