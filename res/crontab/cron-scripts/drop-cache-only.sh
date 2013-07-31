#!/sbin/busybox sh

(
	PROFILE=`cat /data/.halaszk/.active.profile`;
	. /data/.halaszk/$PROFILE.profile;

	if [ "$cron_drop_cache" == "on" ]; then

		MEM_ALL=`free | grep Mem | awk '{ print $2 }'`;
		MEM_USED=`free | grep Mem | awk '{ print $3 }'`;
		MEM_USED_CALC=$(($MEM_USED*100/$MEM_ALL));

		# do clean cache only if cache uses 50% of free memory.
		if [ "$MEM_USED_CALC" \> 50 ]; then

			sysctl -w vm.drop_caches=3
			sync;
			sysctl -w vm.drop_caches=1
			sync;
			date > /data/crontab/cron-clear-ram-cache;
			echo "Cache above 50%! Cleaned RAM Cache" >> /data/crontab/cron-clear-ram-cache;
		fi;
	fi;
)&


