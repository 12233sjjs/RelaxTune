# Supplied kernel script review

Input: `system_tweaks(1).sh`, preserved as `system_tweaks.original.sh`.
Status: not installed or executed by either Debian package.

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

No kernel writes from the input are enabled. The implemented alternative is to
suspend low-power mode while the supported game is foreground, and restore the
user's prior manual state afterward. CPU/GPU clocks and thermal protections are
unchanged.

Primary source checks:

- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_memorystatus_notify.c
- https://github.com/apple-oss-distributions/xnu/blob/main/bsd/pthread/pthread_workqueue.c
- https://github.com/theos/headers/blob/master/LowPowerMode/_PMLowPowerMode.h
