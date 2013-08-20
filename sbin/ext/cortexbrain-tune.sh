#!/sbin/busybox sh

# Credits:
# Zacharias.maladroit
# Voku1987
# Collin_ph@xda
# Dorimanx@xda
# Gokhanmoral@xda
# Johnbeetee
# halaszk

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# read setting from profile

# Get values from profile. since we dont have the recovery source code i cant change the .halaszk dir, so just leave it there for history.
PROFILE=`cat /data/.halaszk/.active.profile`;
. /data/.halaszk/$PROFILE.profile;

FILE_NAME=$0;
PIDOFCORTEX=$$;
IWCONFIG="/sbin/iwconfig";
INTERFACE=wlan0;
AWAKE_LAPTOP_MODE="0";
SLEEP_LAPTOP_MODE="0";
BB="/sbin/busybox";
PROP="/system/bin/setprop";
sqlite="/sbin/sqlite3";
wifi_idle_wait=10000;
# set initial vm.dirty vales
#echo "2000" > /proc/sys/vm/dirty_writeback_centisecs;
#echo "1000" > /proc/sys/vm/dirty_expire_centisecs;
# init functions.
sleeprun=1;
wifi_helper_awake=1;
TELE_DATA=`dumpsys telephony.registry`;
mobile_helper_awake=1;
echo 1 > /tmp/wifi_helper;
echo 1 > /tmp/mobile_helper;
chmod 777 -R /tmp/
# check if dumpsys exist in ROM
if [ -e /system/bin/dumpsys ]; then
	DUMPSYS=1;
else
	DUMPSYS=0;
fi;

# replace kernel version info for repacked kernels
cat /proc/version | grep infra && (kmemhelper -t string -n linux_proc_banner -o 15 `cat /res/version`);

# ==============================================================
# I/O-TWEAKS 
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == on ]; then

		ZRM=`ls -d /sys/block/zram*`;
		for z in $ZRM; do
	
			if [ -e $z/queue/rotational ]; then
				echo "0" > $z/queue/rotational;
			fi;

#			if [ -e $z/queue/iostats ]; then
#				echo "0" > $z/queue/iostats;
#			fi;

			if [ -e $z/queue/rq_affinity ]; then
				echo "1" > $z/queue/rq_affinity;
			fi;

                        if [ -e $z/queue/read_ahead_kb ]; then
                                echo "256" > $z/queue/read_ahead_kb;
                        fi;


		done;

		MMC=`ls -d /sys/block/mmc*`;
for i in $MMC; do
			if [ -e $i/queue/scheduler ]; then
				echo $scheduler > $i/queue/scheduler;
			fi;

			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

#			if [ -e $i/queue/iostats ]; then
#				echo "0" > $i/queue/iostats;
#			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo "$internal_read_ahead_kb" >  $i/queue/read_ahead_kb; # default: 128
			fi;

			     	if [ -e $i/queue/nr_requests ]; then
                                        echo "3072" > $i/queue/nr_requests; # default: 128
                                fi;


			if [ "$scheduler" == "sio" ] || [ "$scheduler" == "zen" ]; then
				if [ -e $i/queue/nr_requests ]; then
					echo "64" > $i/queue/nr_requests; # default: 128
				fi;
			fi;

			if [ -e $i/queue/iosched/back_seek_penalty ]; then
				echo "1" > $i/queue/iosched/back_seek_penalty; # default: 2
			fi;

			if [ -e $i/queue/iosched/slice_idle ]; then
				echo "2" > $i/queue/iosched/slice_idle; # default: 8
			fi;

			if [ -e $i/queue/iosched/fifo_batch ]; then
				echo "1" > $i/queue/iosched/fifo_batch;
			fi;
		done;

		if [ -e /sys/devices/virtual/bdi/default/read_ahead_kb ]; then
			echo "$internal_read_ahead_kb" > /sys/devices/virtual/bdi/default/read_ahead_kb;
		fi;

		local SDCARDREADAHEAD=`ls -d /sys/devices/virtual/bdi/179*`;
		for i in $SDCARDREADAHEAD; do
			echo "$internal_read_ahead_kb" > $i/read_ahead_kb;
		done;

		for i in /sys/block/*/queue/add_random; do 
		echo "0" > $i;
		done;
		echo "0" > /proc/sys/kernel/randomize_va_space;


		echo "45" > /proc/sys/fs/lease-break-time;
		echo "0" > /proc/sys/fs/leases-enable;

		log -p i -t $FILE_NAME "*** IO_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
IO_TWEAKS;

KERNEL_TWEAKS()
{
	local state="$1";

	if [ "$cortexbrain_kernel_tweaks" == on ]; then
		if [ "${state}" == "awake" ]; then
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "120" > /proc/sys/kernel/panic;
			if [ "$cortexbrain_memory" == on ]; then
				echo "32 64" > /proc/sys/vm/lowmem_reserve_ratio;
			fi;
		elif [ "${state}" == "sleep" ]; then
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "1" > /proc/sys/vm/panic_on_oom;
			echo "0" > /proc/sys/kernel/panic;
			if [ "$cortexbrain_memory" == on ]; then
				echo "32 32" > /proc/sys/vm/lowmem_reserve_ratio;
			fi;
		else
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "120" > /proc/sys/kernel/panic;
		fi;
	
		log -p i -t $FILE_NAME "*** KERNEL_TWEAKS ***: ${state} ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
KERNEL_TWEAKS;
# ==============================================================
# SYSTEM-TWEAKS
# ==============================================================
SYSTEM_TWEAKS()
{
	if [ "$cortexbrain_system" == on ]; then
	# enable Hardware Rendering
	$PROP video.accelerate.hw 1;
	$PROP debug.performance.tuning 1;
	$PROP debug.sf.hw 1;
	$PROP persist.sys.use_dithering 1;
#	$PROP persist.sys.ui.hw true; # ->reported as problem maker in some roms.

	# render UI with GPU
	$PROP hwui.render_dirty_regions false;
	$PROP windowsmgr.max_events_per_sec 240;
	$PROP profiler.force_disable_err_rpt 1;
	$PROP profiler.force_disable_ulog 1;

	# more Tweaks
	$PROP dalvik.vm.execution-mode int:jit;
	$PROP persist.adb.notify 0;
	$PROP pm.sleep_mode 1;



		log -p i -t $FILE_NAME "*** SYSTEM_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
SYSTEM_TWEAKS;

# ==============================================================
# BATTERY-TWEAKS
# ==============================================================
BATTERY_TWEAKS()
{
	if [ "$cortexbrain_battery" == on ]; then
	  $BB mount -t debugfs none /sys/kernel/debug;
	  $BB umount /sys/kernel/debug;
	  # vm tweaks
	  echo "$dirty_background_ratio" > /proc/sys/vm/dirty_background_ratio; # default: 10
          echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio; # default: 20

# LCD Power-Reduce
		if [ -e /sys/class/lcd/panel/power_reduce ]; then
			if [ "$power_reduce" == on ]; then
				echo "1" > /sys/class/lcd/panel/power_reduce;
			else
				echo "0" > /sys/class/lcd/panel/power_reduce;
			fi;
		fi;

		# USB power support
		local POWER_LEVEL=`ls /sys/bus/usb/devices/*/power/level`;
		for i in $POWER_LEVEL; do
			chmod 777 $i;
			echo "auto" > $i;
		done;

		local POWER_AUTOSUSPEND=`ls /sys/bus/usb/devices/*/power/autosuspend`;
		for i in $POWER_AUTOSUSPEND; do
			chmod 777 $i;
			echo "1" > $i;
		done;

		# BUS power support
		buslist="spi i2c sdio";
		for bus in $buslist; do
			local POWER_CONTROL=`ls /sys/bus/$bus/devices/*/power/control`;
			for i in $POWER_CONTROL; do
				chmod 777 $i;
				echo "auto" > $i;
			done;
		done;

		log -p i -t $FILE_NAME "*** BATTERY_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
if [ "$cortexbrain_background_process" == 0 ]; then
	BATTERY_TWEAKS;
fi;

# ==============================================================
# CPU-TWEAKS
# ==============================================================

CPU_GOV_TWEAKS()
{
	local state="$1";
	if [ "$cortexbrain_cpu" == on ]; then
	SYSTEM_GOVERNOR=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;
        
		# power_performance
	if [ "${state}" == "performance" ]; then

	echo "20000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "40" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "100" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "800000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;

		# sleep-settings
	elif [ "${state}" == "sleep" ]; then

	echo "$freq_for_responsiveness_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;
    echo "$freq_for_fast_down_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_fast_down;
    echo "$sampling_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "$sampling_down_factor_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
	echo "$up_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "$down_differential_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
	echo "$up_threshold_at_min_freq_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "$up_threshold_at_fast_down_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_fast_down;
	echo "$freq_step_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "$up_threshold_diff_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_diff;
	echo "$freq_step_dec_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step_dec;
	echo "$cpu_up_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "$cpu_down_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "$up_nr_cpus_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_nr_cpus;
	echo "$hotplug_freq_1_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_1_1;
	echo "$hotplug_freq_2_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_0;
	echo "$hotplug_freq_2_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_1;
	echo "$hotplug_freq_3_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_0;
	echo "$hotplug_freq_3_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_1;
	echo "$hotplug_freq_4_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_4_0;
	echo "$hotplug_rq_1_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_1_1;
	echo "$hotplug_rq_2_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_0;
	echo "$hotplug_rq_2_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_1;
	echo "$hotplug_rq_3_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_0;
	echo "$hotplug_rq_3_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_1;
	echo "$hotplug_rq_4_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_4_0;
	echo "$flexrate_enable_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_enable;
	echo "$flexrate_max_freq_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_max_freq;
	echo "$flexrate_forcerate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_forcerate;
	echo "$cpu_online_bias_count_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_count;
	echo "$cpu_online_bias_up_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_up_threshold;
	echo "$cpu_online_bias_down_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_down_threshold;
	echo "$intelli_plug_active" > /sys/module/intelli_plug/parameters/intelli_plug_active;
	echo "$eco_mode_active" > /sys/module/intelli_plug/parameters/eco_mode_active;
	echo "$suspend_max_cpu" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/suspend_max_cpu;
	
		# awake-settings
	elif [ "${state}" == "awake" ]; then
	echo "$freq_for_responsiveness" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;
    echo "$freq_for_fast_down" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_fast_down;
    echo "$sampling_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "$sampling_down_factor" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
	echo "$up_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "$down_differential" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
	echo "$up_threshold_at_min_freq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "$up_threshold_at_fast_down" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_fast_down;
	echo "$freq_step" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "$up_threshold_diff" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_diff;
	echo "$freq_step_dec" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step_dec;
	echo "$cpu_up_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "$cpu_down_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "$up_nr_cpus" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_nr_cpus;
	echo "$hotplug_freq_1_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_1_1;
	echo "$hotplug_freq_2_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_0;
	echo "$hotplug_freq_2_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_1;
	echo "$hotplug_freq_3_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_0;
	echo "$hotplug_freq_3_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_1;
	echo "$hotplug_freq_4_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_4_0;
	echo "$hotplug_rq_1_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_1_1;
	echo "$hotplug_rq_2_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_0;
	echo "$hotplug_rq_2_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_1;
	echo "$hotplug_rq_3_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_0;
	echo "$hotplug_rq_3_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_1;
	echo "$hotplug_rq_4_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_4_0;
	echo "$flexrate_max_freq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_max_freq;
	echo "$flexrate_forcerate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_forcerate;
	echo "$boost" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/boost;
	echo "$cpu_online_bias_count" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_count;
	echo "$cpu_online_bias_up_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_up_threshold;
	echo "$cpu_online_bias_down_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_down_threshold;
	echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/max_cpu_lock;
	echo "$lcdfreq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/lcdfreq_enable;
	echo "$intelli_plug_active" > /sys/module/intelli_plug/parameters/intelli_plug_active;
	echo "$eco_mode_active" > /sys/module/intelli_plug/parameters/eco_mode_active;
	
	fi;

		log -p i -t $FILE_NAME "*** CPU_GOV_TWEAKS: ${state} ***: enabled";
	fi;
}
#if [ "$cortexbrain_background_process" == 0 ]; then
#	CPU_GOV_TWEAKS "awake";
#fi;
# this needed for cpu tweaks apply from STweaks in real time.
#apply_cpu=$2;
#if [ "${apply_cpu}" == "update" ]; then
#CPU_GOV_TWEAKS "awake";
#fi;

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == on ]; then
		echo "$dirty_background_ratio" > /proc/sys/vm/dirty_background_ratio; # default: 10
		echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio; # default: 20
	#	echo "4" > /proc/sys/vm/min_free_order_shift; # default: 4
	#	echo "0" > /proc/sys/vm/overcommit_memory; # default: 0
	#	echo "50" > /proc/sys/vm/overcommit_ratio; # default: 50
	#	echo "3" > /proc/sys/vm/page-cluster; # default: 3
	#	echo "8192" > /proc/sys/vm/min_free_kbytes;
	#	echo "16384" > /proc/sys/vm/mmap_min_addr; 

		log -p i -t $FILE_NAME "*** MEMORY_TWEAKS ***: enabled";
		return 0;
	else
		return 1;		
	fi;
}
MEMORY_TWEAKS;
# ==============================================================
# TCP-TWEAKS
# ==============================================================
TCP_TWEAKS()
{
	if [ "$cortexbrain_tcp" == on ]; then
		echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
		echo "1" > /proc/sys/net/ipv4/tcp_rfc1337;
		echo "1" > /proc/sys/net/ipv4/tcp_workaround_signed_windows;
		echo "1" > /proc/sys/net/ipv4/tcp_low_latency;
		echo "1" > /proc/sys/net/ipv4/tcp_mtu_probing;
		echo "2" > /proc/sys/net/ipv4/tcp_frto_response;
		echo "1" > /proc/sys/net/ipv4/tcp_no_metrics_save;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
		echo "30" > /proc/sys/net/ipv4/tcp_fin_timeout;
		echo "0" > /proc/sys/net/ipv4/tcp_ecn;
		echo "5" > /proc/sys/net/ipv4/tcp_keepalive_probes;
		echo "40" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
		echo "2500" > /proc/sys/net/core/netdev_max_backlog;
		echo "1" > /proc/sys/net/ipv4/route/flush;

		log -p i -t $FILE_NAME "*** TCP_TWEAKS ***: enabled";
	fi;

	if [ "$cortexbrain_tcp_ram" == on ]; then
		echo "4194304" > /proc/sys/net/core/wmem_max;
		echo "4194304" > /proc/sys/net/core/rmem_max;
		echo "20480" > /proc/sys/net/core/optmem_max;
		echo "4096 87380 4194304" > /proc/sys/net/ipv4/tcp_wmem;
		echo "4096 87380 4194304" > /proc/sys/net/ipv4/tcp_rmem;

		log -p i -t $FILE_NAME "*** TCP_RAM_TWEAKS ***: enabled";
	fi;
}
TCP_TWEAKS;

# ==============================================================
# FIREWALL-TWEAKS
# ==============================================================
FIREWALL_TWEAKS()
{
	if [ "$cortexbrain_firewall" == on ]; then
		# ping/icmp protection
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts;
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all;
		echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses;

		log -p i -t $FILE_NAME "*** FIREWALL_TWEAKS ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
FIREWALL_TWEAKS;

# ==============================================================
# SCREEN-FUNCTIONS
# ==============================================================

LOGGER()
{
	local state="$1";

	if [ "${state}" == "awake" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == debug ]; then
		echo "1" > /sys/kernel/logger_mode/logger_mode;
		fi;
	elif [ "${state}" == "sleep" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == disabled ]; then
		echo "0" > /sys/kernel/logger_mode/logger_mode;
		fi;
	fi;
	log -p i -t $FILE_NAME "*** LOGGER ***: ${state}";
}

WIFI_PM()
{
	local state="$1";
	if [ "${state}" == "sleep" ]; then
		if [ "$wifi_pwr" == on ]; then
			if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
				echo "1" > /sys/module/dhd/parameters/wifi_pm;
			fi;
		fi;

	elif [ "${state}" == "awake" ]; then
		if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
			echo "0" > /sys/module/dhd/parameters/wifi_pm;
		fi;
	fi;

	log -p i -t $FILE_NAME "*** WIFI_PM ***: ${state}";
}

WIFI_TIMEOUT_TWEAKS()
{
RETURN_VALUE=$($sqlite /data/data/com.android.providers.settings/databases/settings.db "select value from secure where name='wifi_idle_ms'");
echo "Current wifi_idle_ms value: $RETURN_VALUE";
if [ $RETURN_VALUE='' ] 
then
   echo "Creating row with wifi_idle_ms value: $wifi_idle_wait";
   $sqlite /data/data/com.android.providers.settings/databases/settings.db "insert into secure (name, value) values ('wifi_idle_ms', $wifi_idle_wait )"
    log -p i -t $FILE_NAME "*** Creating row with wifi_idle_ms value: $wifi_idle_wait ***";
else
   echo "Updating wifi_idle_ms value from $RETURN_VALUE to $wifi_idle_wait";
   $sqlite /data/data/com.android.providers.settings/databases/settings.db "update secure set value=$wifi_idle_wait where name='wifi_idle_ms'"
   log -p i -t $FILE_NAME "*** Updating wifi_idle_ms value from $RETURN_VALUE to $wifi_idle_wait ***";
fi;
}
if [ "$cortexbrain_wifi" == on ]; then
WIFI_TIMEOUT_TWEAKS;
fi;
# please don't kill "cortexbrain"
DONT_KILL_CORTEX()
{
	PIDOFCORTEX=`pgrep -f "/sbin/ext/cortexbrain-tune.sh"`;
	for i in $PIDOFCORTEX; do
		echo "-950" > /proc/${i}/oom_score_adj;
	done;

	log -p i -t $FILE_NAME "*** DONT_KILL_CORTEX ***";
}

MOUNT_SD_CARD()
{
if [ "$auto_mount_sd" == on ]; then
		$PROP persist.sys.usb.config mass_storage,adb;
	if [ -e /dev/block/vold/179:9 ]; then
		echo "/dev/block/vold/179:9" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
	fi;
	log -p i -t $FILE_NAME "*** MOUNT_SD_CARD ***";
fi;
}
MOUNT_SD_CARD;
# set wakeup booster delay to prevent mp3 music shattering when screen turned ON
WAKEUP_DELAY()
{
if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.halaszk/booting ]; then
log -p i -t $FILE_NAME "*** WAKEUP_DELAY ${wakeup_delay}sec ***";
sleep $wakeup_delay
fi;
}

WAKEUP_DELAY_SLEEP()
{
if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.halaszk/booting ]; then
log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP ${wakeup_delay}sec ***";
sleep $wakeup_delay;
else
log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP 3sec ***";
sleep 3;
fi;
}

# check if ROM booting now, then don't wait - creation and deletion of /data/.halaszk/booting @> /sbin/ext/post-init.sh
WAKEUP_BOOST_DELAY()
{
if [ ! -e /data/.halaszk/booting ] && [ "$wakeup_boost" != 0 ]; then
log -p i -t $FILE_NAME "*** WAKEUP_BOOST_DELAY ${wakeup_boost}sec ***";
sleep $wakeup_boost;
fi;
}

# boost CPU power for fast and no lag wakeup
MEGA_BOOST_CPU_TWEAKS()
{
if [ "$cortexbrain_cpu_boost" == on ]; then

echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
CPU_GOV_TWEAKS "performance";

	# bus freq to 400MHZ in low load
echo "30" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
echo "30" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
echo "30" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;

echo "1600000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
echo "1600000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
log -p i -t $FILE_NAME "*** MEGA_BOOST_CPU_TWEAKS ***";
fi;
}
# set swappiness in case that no root installed, and zram used or disk swap used
SWAPPINESS()
{
	SWAP_CHECK=`free | grep Swap | awk '{ print $2 }'`;
	if [ "$zram" == 4 ] || [ "$SWAP_CHECK" == 0 ]; then
		echo "0" > /proc/sys/vm/swappiness;
	else
		echo "$swappiness" > /proc/sys/vm/swappiness;
	fi;
log -p i -t $FILE_NAME "*** SWAPPINESS: $swappiness ***";
}
SWAPPINESS;

TUNE_IPV6()
{
	CISCO_VPN=`find /data/data/com.cisco.anyconnec* | wc -l`;
	if [ "$cortexbrain_ipv6" == on ] || [ "$CISCO_VPN" != 0 ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		$BB sysctl -w net.ipv6.conf.all.disable_ipv6=0;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: enabled";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		$BB sysctl -w net.ipv6.conf.all.disable_ipv6=1;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: disabled";
	fi;
}

KERNEL_SCHED()
{
	local state="$1";

	# this is the correct order to input this settings, every value will be x2 after set
	if [ "${state}" == "awake" ]; then
		$BB sysctl -w kernel.sched_min_granularity_ns=1 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_latency_ns=600000 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_wakeup_granularity_ns=400000 > /dev/null 2>&1;
	elif [ "${state}" == "sleep" ]; then
		$BB sysctl -w kernel.sched_min_granularity_ns=1 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_latency_ns=600000 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_wakeup_granularity_ns=400000 > /dev/null 2>&1;
	fi;

	log -p i -t $FILE_NAME "*** KERNEL_SCHED ***: ${state}";
}

LOWMMKILLER()
{
        local state="$1";
        if [ "${state}" == "awake" ]; then
                /res/uci.sh oom_config $oom_config;
        elif [ "${state}" == "sleep" ]; then
                /res/uci.sh oom_config_sleep $oom_config_sleep;
        fi;

        log -p i -t $FILE_NAME "*** LOWMMKILLER ***: ${state}";
}

# if crond used, then give it root perent - if started by STweaks, then it will be killed in time
CROND_SAFETY()
{
	if [ "$crontab" == on ]; then
		$BB pkill -f "crond";
		$BB /res/crontab_service/service.sh;
		log -p i -t $FILE_NAME "*** CROND_SAFETY ***";
	fi;
}

DISABLE_NMI()
{
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "0" > /proc/sys/kernel/nmi_watchdog;
		log -p i -t $FILE_NAME "*** NMI ***: disable";
	fi;
}

ENABLE_NMI()
{
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "1" > /proc/sys/kernel/nmi_watchdog;
		log -p i -t $FILE_NAME "*** NMI ***: enabled";
	fi;
}

NET()
{
	local state="$1";

	if [ "${state}" == "awake" ]; then
		echo "3" > /proc/sys/net/ipv4/tcp_keepalive_probes; # default: 3
		echo "1200" > /proc/sys/net/ipv4/tcp_keepalive_time; # default: 7200s
		echo "10" > /proc/sys/net/ipv4/tcp_keepalive_intvl; # default: 75s
		echo "10" > /proc/sys/net/ipv4/tcp_retries2; # default: 15
	elif [ "${state}" == "sleep" ]; then
		echo "2" > /proc/sys/net/ipv4/tcp_keepalive_probes;
		echo "300" > /proc/sys/net/ipv4/tcp_keepalive_time;
		echo "5" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
		echo "5" > /proc/sys/net/ipv4/tcp_retries2;
	fi;

	log -p i -t $FILE_NAME "*** NET ***: ${state}";	
}

VFS_CACHE_PRESSURE()
{
	local state="$1";
	local sys_vfs_cache="/proc/sys/vm/vfs_cache_pressure";

	if [ -e $sys_vfs_cache ]; then
	if [ "${state}" == "awake" ]; then
		echo "100" > $sys_vfs_cache;
	elif [ "${state}" == "sleep" ]; then
		echo "50" > $sys_vfs_cache;
	fi;

	log -p i -t $FILE_NAME "*** VFS_CACHE_PRESSURE: ${state} ***";
			return 0;
	fi;

	return 1;
}

IO_SCHEDULER()
{
	local state="$1";
	local sys_mmc0_scheduler="/sys/block/mmcblk0/queue/scheduler";
	local sys_mmc1_scheduler="/sys/block/mmcblk1/queue/scheduler";

	if [ "${state}" == "awake" ]; then
		echo "$internal_iosched" > $sys_mmc0_scheduler;
		echo "$sd_iosched" > $sys_mmc1_scheduler;
	elif [ "${state}" == "sleep" ]; then
		echo "noop" > $sys_mmc0_scheduler;
		echo "noop" > $sys_mmc1_scheduler;
	fi;

	log -p i -t $FILE_NAME "*** IO_SCHEDULER: ${state} - INTERNAL: $internal_iosched EXTERNAL: $sd_iosched ***: done";	
		# set I/O Tweaks again ...
		IO_TWEAKS;
}

# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	LOGGER "awake";

	KERNEL_TWEAKS "awake"; 

	IO_TWEAKS;

#	KERNEL_SCHED "awake";

	WAKEUP_DELAY;
	
	MEGA_BOOST_CPU_TWEAKS;

	#restore normal max freq after call or sleep ending
#	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

	WAKEUP_BOOST_DELAY;
	
#	echo "$AWAKE_LAPTOP_MODE" > /proc/sys/vm/laptop_mode;
	
	if [ "$cortexbrain_wifi" == on ]; then
	$IWCONFIG $INTERFACE frag 2345;
	$IWCONFIG $INTERFACE rts 2346;
	$IWCONFIG $INTERFACE txpower $cortexbrain_wifi_tx;
	fi;
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	fi;
	
	WIFI_PM "awake";

	TUNE_IPV6;
	
	NET "awake";
	
	IO_SCHEDULER "awake";
	
	VFS_CACHE_PRESSURE "awake";

	if [ "$cortexbrain_cpu_boost" == on ]; then
	# set CPU speed
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	if [ "$cortexbrain_cpu_boost" == on ]; then
	# bus freq back to normal
	echo "$dmc_max_threshold" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
	echo "$max_cpu_threshold" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
	echo "$up_cpu_threshold" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;
	fi;
	
	ENABLE_NMI;

	DONT_KILL_CORTEX;
	
	SWAPPINESS;

	if [ "$cortexbrain_lmkiller" == on ]; then
	LOWMMKILLER "awake";
	fi;
	
#	CPU_GOV_TWEAKS "awake";
	log -p i -t $FILE_NAME "*** AWAKE: Normal-Mode ***";
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	WAKEUP_DELAY_SLEEP;

	# we only read the config when screen goes off ...
	PROFILE=`cat /data/.halaszk/.active.profile`;
	. /data/.halaszk/$PROFILE.profile;

	if [ "$DUMPSYS" == 1 ]; then
		# check the call state, not on call = 0, on call = 2
		CALL_STATE=`dumpsys telephony.registry | awk '/mCallState/ {print $1}'`;
		if [ "$CALL_STATE" == "mCallState=0" ]; then
			CALL_STATE=0;
		else
			CALL_STATE=2;
		fi;
	else
		CALL_STATE=0;
	fi;

	if [ "$CALL_STATE" == 0 ]; then

	if [ "$cortexbrain_cpu_boost" == on ]; then
		# set CPU-Governor
#	echo "$deep_sleep" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
#	echo "$standby_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
		# reduce deepsleep CPU speed, SUSPEND mode
	echo "$scaling_min_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	# set CPU-Tweak
#	CPU_GOV_TWEAKS "sleep";

	if [ "$cortexbrain_cpu_boost" == on ]; then
	# bus freq to min 100Mhz
	echo "80" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
	echo "80" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
	echo "80" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;
	fi;
	if [ "$cortexbrain_wifi" == on ]; then
	$IWCONFIG $INTERFACE frag 2345;
	$IWCONFIG $INTERFACE rts 2346;
	$IWCONFIG $INTERFACE txpower $cortexbrain_wifi_tx;
	fi;
	
#	echo "$SLEEP_LAPTOP_MODE" > /proc/sys/vm/laptop_mode;

#	KERNEL_SCHED "sleep";

	TUNE_IPV6;

	BATTERY_TWEAKS;

	CROND_SAFETY;
	
	SWAPPINESS;

	WIFI_PM "sleep";

	IO_SCHEDULER "sleep";

	VFS_CACHE_PRESSURE "sleep";

	DISABLE_NMI;

	if [ "$cortexbrain_lmkiller" == on ]; then
	LOWMMKILLER "sleep";
	fi;
		
	NET "sleep";

	KERNEL_TWEAKS "sleep";

	log -p i -t $FILE_NAME "*** SLEEP mode ***";

	LOGGER "sleep";

	else

	# reduce CPU speed in call mode (no overheating under call)
#	echo "1000000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
		
	log -p i -t $FILE_NAME "*** On Call! SLEEP aborted, Reduced CPU speed to 1000MHz! ***";

	fi;

}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;
already_awake=0;
already_sleep=0;
if [ "$cortexbrain_background_process" == 1 ]; then
	(while [ 1 ]; do
sleep 5;
	SCREEN_OFF=$(cat /sys/class/lcd/panel/device/backlight/panel/brightness);

		# AWAKE State. all system ON.
		if [ "$SCREEN_OFF" != 0 ] && [ "$already_awake" == 0 ]; then
		AWAKE_MODE;
		already_awake=1;
		already_sleep=0;
		sleep 2;

		# SLEEP state. All system to power save.
                elif [ "$SCREEN_OFF" == 0 ] && [ "$already_sleep" == 0 ]; then
                SLEEP_MODE;
                already_awake=0;
                already_sleep=1;
		sleep 2;
		fi;

	done &);
	else
	if [ "$cortexbrain_background_process" == 0 ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;

