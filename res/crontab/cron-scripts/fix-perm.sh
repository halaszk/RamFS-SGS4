#!/sbin/busybox sh

(
	PROFILE=`cat /data/.halaszk/.active.profile`;
	. /data/.halaszk/$PROFILE.profile;

	if [ "$cron_fix_permissions" == "on" ]; then

		/sbin/fix_permissions -l -r -v > /dev/null 2>&1;
		date +%H:%M-%D-%Z > /data/crontab/cron-fix_permissions;
		echo "Done! Fixed Apps Permissions" >> /data/crontab/cron-fix_permissions;
	fi;
)&


