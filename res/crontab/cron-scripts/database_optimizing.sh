#!/sbin/busybox sh

(
	PROFILE=`cat /data/.halaszk/.active.profile`;
	. /data/.halaszk/$PROFILE.profile;

	if [ "$cron_db_optimizing" == "on" ]; then

	        if [ ! -e /system/xbin/sqlite3 ]; then
                mount -o remount,rw /;
                mount -o remount,rw /system;
                        cp /res/misc/sql/sqlite3 /system/xbin/sqlite3;
			cp /res/misc/sql/libsqlite.so /system/xbin/libsqlite.so;
                        chmod 755 /system/xbin/sqlite3;
			chmod 755 /system/lib/libsqlite.so;
                fi;


		for i in `find /data -iname "*.db"`; do 
			/system/xbin/sqlite3 $i 'VACUUM;';
			/system/xbin/sqlite3 $i 'REINDEX;';
		done;

		for i in `find /sdcard -iname "*.db"`; do
			/system/xbin/sqlite3 $i 'VACUUM;';
			/system/xbin/sqlite3 $i 'REINDEX;';
		done;

		date > /data/crontab/cron-db-optimizing;
		echo "Done! DB Optimized" >> /data/crontab/cron-db-optimizing;
	fi;
)&

