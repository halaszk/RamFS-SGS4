#!/sbin/busybox sh

BB="/sbin/busybox";

PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;
for i in $PIDOFINIT; do
echo "-600" > /proc/$i/oom_score_adj;
done;PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;

$BB mount -o remount,rw /system
$BB mount -t rootfs -o remount,rw rootfs

if [ ! -f /system/xbin/su ]; then
$BB mv  /res/su /system/xbin/su
fi

$BB chown 0.0 /system/xbin/su
$BB chmod 06755 /system/xbin/su
symlink /system/xbin/su /system/bin/su

if [ ! -f /system/app/Superuser.apk ]; then
$BB mv /res/Superuser.apk /system/app/Superuser.apk
fi

$BB chown 0.0 /system/app/Superuser.apk
$BB chmod 0644 /system/app/Superuser.apk

if [ ! -f /system/xbin/busybox ]; then
$BB ln -s /sbin/busybox /system/xbin/busybox
$BB ln -s /sbin/busybox /system/xbin/pkill
fi

if [ ! -f /system/bin/busybox ]; then
$BB ln -s /sbin/busybox /system/bin/busybox
$BB ln -s /sbin/busybox /system/bin/pkill
fi

if [ ! -f /system/app/STweaks.apk ]; then
 $BB cat /res/STweaks.apk > /system/app/STweaks.apk
 $BB chown 0.0 /system/app/STweaks.apk
 $BB chmod 644 /system/app/STweaks.apk
fi


$BB rm /data/.halaszk/customconfig.xml
$BB rm /data/.halaszk/action.cache

# reset config-backup-restore
if [ -f /data/.halaszk/restore_running ]; then
$BB rm -f /data/.halaszk/restore_running;
fi;

# for dev testing
PROFILES=`$BB ls -A1 /data/.halaszk/*.profile`;
for p in $PROFILES; do
$BB cp $p $p.test;
done;

. /res/customconfig/customconfig-helper

read_defaults;
read_config;

/system/bin/setprop pm.sleep_mode 1
/system/bin/setprop ro.ril.disable.power.collapse 0
/system/bin/setprop wifi.supplicant_scan_interval 60

sync

######################################
# Loading Modules
######################################
$BB chmod -R 755 /lib;

(
	sleep 40;
	# order of modules load is important.
	$BB insmod /lib/modules/scsi_wait_scan.ko;
)&

# for ntfs automounting
#insmod /lib/modules/fuse.ko;
mount -o remount,rw /
mkdir -p /mnt/ntfs
chmod 777 /mnt/ntfs
mount -o mode=0777,gid=1000 -t tmpfs tmpfs /mnt/ntfs
mount -o remount,ro /


echo "20" > /proc/sys/vm/dirty_background_ratio
echo "80" > /proc/sys/vm/dirty_ratio
echo "100" > /proc/sys/vm/swappiness
echo "120" > /proc/sys/vm/vfs_cache_pressure

# Cortex parent should be ROOT/INIT and not STweaks
nohup /sbin/ext/cortexbrain-tune.sh; 

# Stop uci.sh from running all the PUSH Buttons in stweaks on boot.
$BB mount -o remount,rw rootfs;
$BB chown root:system /res/customconfig/actions/ -R;
$BB chmod 6755 /res/customconfig/actions/*;
$BB chmod 6755 /res/customconfig/actions/push-actions/*;
$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;

# set root access script.
$BB chmod 6755 /sbin/ext/cortexbrain-tune.sh;
sync
# apply STweaks settings
echo "booting" > /data/.halaszk/booting;
pkill -f "com.gokhanmoral.stweaks.app";
# apply STweaks defaults
export CONFIG_BOOTING=1
/res/uci.sh apply
export CONFIG_BOOTING=

echo "1" > /tmp/uci_done;

# restore all the PUSH Button Actions back to there location
$BB mount -o remount,rw rootfs;
$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
pkill -f "com.gokhanmoral.stweaks.app";
$BB rm -f /data/.halaszk/booting;

$BB mount -o remount,rw /system;
$BB mount -o remount,rw /;

if [ $cortexbrain_lmkiller == on ]; then
# correct oom tuning, if changed by apps/rom
$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
$BB sh /res/uci.sh oom_config_screen_off $oom_config_screen_off;
fi;
##### init scripts #####

$BB sh /sbin/ext/run-init-scripts.sh;
