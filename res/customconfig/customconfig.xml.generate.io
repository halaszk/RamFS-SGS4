#!/sbin/busybox sh

cat << ENDCONFIG
  <settingsTab name="I/O">
    <settingsPane description="Set the active I/O elevator algorithm. The scheduler decides how to handle I/O requests and how to handle them. FIOPS is the everyday recommended default scheduler."  
                  name="I/O schedulers">

      <spinner name="Current internal storage scheduler"
               action="iosched internal /sys/block/mmcblk0/queue/scheduler">
`
for IOSCHED in \`cat /sys/block/mmcblk0/queue/scheduler | sed -e 's/\]//;s/\[//'\`; do
  echo '<spinnerItem name="'$IOSCHED'" value="'$IOSCHED'"/>"'
done
`
      </spinner>
      <spinner name="Current SD card scheduler"
               action="iosched sd /sys/block/mmcblk1/queue/scheduler">
`
for IOSCHED in \`cat /sys/block/mmcblk0/queue/scheduler | sed -e 's/\]//;s/\[//'\`; do
  echo '<spinnerItem name="'$IOSCHED'" value="'$IOSCHED'"/>"'
done
`
      </spinner>
    </settingsPane>

    <settingsPane name="I/O read-ahead" 
                  description="The readahead value is the requested block size the host controller reads into memory on any given I/O read request. Increasing the read-ahead on cards with high latency and lower IOPS will increase the raw thoroughput.">

      <seekBar  description="The read-ahead value on the internal phone memory." 
                name="Internal storage read-ahead" 
                action="generictagforce internal /sys/block/mmcblk0/queue/read_ahead_kb"
                unit="kB" min="128" reversed="false" step="128" max="2048"/>

      <seekBar  description="The read-ahead value on the external SD card." 
                name="SD card read-ahead" 
                action="generictagforce sd /sys/block/mmcblk1/queue/read_ahead_kb"
                unit="kB" min="128" reversed="false" step="128" max="2048"/>

    </settingsPane>
  </settingsTab>
ENDCONFIG
