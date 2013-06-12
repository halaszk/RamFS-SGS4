#!/sbin/busybox sh
# DATA on script

(
	PROFILE=`cat /data/.halaszk/.active.profile`;
	. /data/.halaszk/$PROFILE.profile;

	if [ "$cron_mobile_data" == "on" ]; then
	svc data enable;
	svc wifi enable;
	date +%H:%M-%D-%Z > /data/crontab/mdata_off;
	echo "Done! Mobile network disabled" >> /data/crontab/mdata_off;
	fi;
)&
