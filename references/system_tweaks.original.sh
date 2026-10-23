#!/bin/bash
set -e

# 检查Dopamine环境
if [ ! -d "/var/jb" ]; then
    echo "错误：未检测到Dopamine越狱环境"
    exit 1
fi

echo "[Dopamine] 应用内核参数调整..."

# 线程参数
echo "当前线程数量"
/var/jb/usr/sbin/sysctl kern.wq_max_threads=2048

# 虚拟内存参数
echo "设置虚拟节点最大值"
/var/jb/usr/sbin/sysctl kern.maxvnodes=20000
echo "当前虚拟内存状态"
/var/jb/usr/sbin/sysctl vm.swapusage

# 后台管理参数
echo "调整后台保留策略"
/var/jb/usr/sbin/sysctl kern.memorystatus_sysprocs_idle_delay_time=1
/var/jb/usr/sbin/sysctl kern.memorystatus_apps_idle_delay_time=1
/var/jb/usr/sbin/sysctl kern.memorystatus_kill_on_sustained_pressure_delay_ms=86400000

# 延迟工作限制
echo "调整后台队列限制"
/var/jb/usr/sbin/sysctl kern.vm_max_delayed_work_limit=64
