#!/bin/bash
#
# Server Status Script
# Version 0.1.3 m
# Updated: July 26th 2011 m

CPUTIME="$(ps -eo pcpu | awk 'NR>1' | awk '{tot=tot+$1} END {print tot}')"
CPUCORES="$(cat /proc/cpuinfo | grep -c processor)"

upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
secs=$((${upSeconds}%60))
mins=$((${upSeconds}/60%60))
hours=$((${upSeconds}/3600%24))
days=$((${upSeconds}/86400))
UP=$(printf "%d days, %02dh:%02dm:%02ds" "$days" "$hours" "$mins" "$secs")

# use single device to detect temp
storage=/dev/sda
TERM="xterm-256color"

black() { echo "$(tput setaf 0)$*$(tput setaf 9)"; }
red() { echo "$(tput setaf 1)$*$(tput setaf 9)"; }
green() { echo "$(tput setaf 2)$*$(tput setaf 9)"; }
yellow() { echo "$(tput setaf 3)$*$(tput setaf 9)"; }
blue() { echo "$(tput setaf 4)$*$(tput setaf 9)"; }
magenta() { echo "$(tput setaf 5)$*$(tput setaf 9)"; }
cyan() { echo "$(tput setaf 6)$*$(tput setaf 9)"; }
white() { echo "$(tput setaf 7)$*$(tput setaf 9)"; }

root_usage=$(df -h / | awk '/\// {print $(NF-1)}' | sed 's/%//g')
home_usage_gb=$(df -h /home | awk '/\// {print $(NF-3)}')
home_total=$(df -h /home | awk '/\// {print $(NF-4)}')
root_usage_gb=$(df -h / | awk '/\// {print $(NF-3)}')
root_total=$(df -h / | awk '/\// {print $(NF-4)}')
# 52C
cpu_temp=$(cat /sys/devices/platform/coretemp.0/hwmon/hwmon1/temp4_input | awk '{printf("%d",$1/1000)}')
# 26%/4135 MB of 16041MB
memory_usage=$(free | awk '/Mem/ {printf("%.0f",(($2-($4+$6+$7))/$2) * 100)}')
memory_total=$(free -m |  awk '/Mem/ {print $(2)}')
memory_usage_gb=$(free -t -m | grep "buffers/cache" | awk '{print $3" MB";}')
docker_active=$(systemctl is-active docker)
docker_containers=$(docker ps -q $1 | wc -l)
wipe_waiting=$(docker ps -a -q -f status=exited | wc -l)
users=$(users)
RPM_GET_VER=$(rpm -qa --queryformat "%{VERSION}\n" docker)
get_host_name=$(hostname)
get_ip_host=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
get_os_name=$(cat /etc/redhat-release)
get_os_loadavg=$(cat /proc/loadavg)
get_hdd_temp=$(hddtemp -u C -nq $storage)
get_plat_data=$(uname -orpi)
get_proc_ps=$(ps -Afl | wc -l)
get_swap=$(free -m | tail -n 1 | awk {'print $3'})
get_fail2ban=$(fail2ban-client status sshd | grep -i "Total banned" | awk '{printf $4}')
repoclosure_timer=$(cat /home/omv/repoclosure/index.html | grep date | cut -d' ' -f12-16)
cert_timer=$(openssl x509 -noout -in /home/omv/docker-nginx/abf.openmandriva.org-chain.pem -text | grep -i 'not after' | cut -d ':' -f2-5)
get_average_cpu=$(echo "$CPUTIME" / "$CPUCORES" | bc)
blue_colour="\e\\033[38;5;33m"
light_blue_colour="\e\\033[38;5;39m"
red_colour="\e\\033[38;5;196m"
green_colour="\e\\033[38;5;42m"
yellow_colour="\e\\033[38;5;227m"
close_colour="$(tput sgr0)"

# networking
interface="eth0"

R1=`cat /sys/class/net/${interface}/statistics/rx_bytes`
T1=`cat /sys/class/net/${interface}/statistics/tx_bytes`
# sleep one second to collect statistics
sleep 1
R2=`cat /sys/class/net/${interface}/statistics/rx_bytes`
T2=`cat /sys/class/net/${interface}/statistics/tx_bytes`
TBPS=`expr $T2 - $T1`
RBPS=`expr $R2 - $R1`
TKBPS=`expr $TBPS / 1024`
RKBPS=`expr $RBPS / 1024`

mdadm_status_func(){
RAID_MD="/dev/md[0-9]"
# no new line

        for device in $RAID_MD;do
                active_devices=$(mdadm --detail $device |  grep 'Active Devices :' | awk '{printf "%s:", $4}')
                failed_devices=$(mdadm --detail $device |  grep 'Failed Devices :' | awk '{printf "%s:", $4}')
                echo -e -n "$green_colour$device active: [$active_devices]$close_colour" "[$red_colour"failed: $failed_devices"$close_colour"]
        done
}

echo -e "
$blue_colour"System Status:"$close_colour
$blue_colour"Updated at"$close_colour: $green_colour`date`$close_colour

$blue_colour"- Server Name"$close_colour               = `echo -e "$green_colour$get_host_name$close_colour"`
$blue_colour"- Public IP"$close_colour                 = `echo -e "$green_colour$get_ip_host$close_colour"`
$blue_colour"- OS Version"$close_colour                = `echo -e "$green_colour$get_os_name$close_colour"`
$blue_colour"- Load Averages"$close_colour             = `echo -e "$green_colour$get_os_loadavg$close_colour"`
$blue_colour"- Usage of /"$close_colour             = `echo -e "$green_colour$root_usage%$close_colour"`/`echo -e "$green_colour$root_usage_gb$close_colour"` "of" `echo -e "$red_colour$root_total$close_colour"`
$blue_colour"- Usage of /home"$close_colour         = `echo -e "$green_colour$home_usage_gb$close_colour"`/`echo -e "$red_colour$home_total$close_colour"` 
$blue_colour"- RAID status"$close_colour               = `mdadm_status_func`
$blue_colour"- System Uptime"$close_colour             = `echo -e "$green_colour$UP$close_colour"`
$blue_colour"- Logged users"$close_colour              = `echo -e "$light_blue_colour$users$close_colour"`
$blue_colour"- Platform Data"$close_colour             = `echo -e "$green_colour$get_plat_data$close_colour"`
$blue_colour"- Fail2ban Status"$close_colour           = `echo -e "$red_colour[$get_fail2ban] ip banned$close_colour"`
$blue_colour"- Repoclosure report"$close_colour        = `echo -e "$green_colour[$repoclosure_timer]$close_colour"`
$blue_colour"- SSL expiration date"$close_colour       = `echo -e "$red_colour[$cert_timer]$close_colour"`
$blue_colour"- Docker"$close_colour                 = `echo -e "$green_colour[$RPM_GET_VER]$close_colour"` `echo -e $green_colour[$docker_active] running:$close_colour "$green_colour[$docker_containers]" wipe waiting:$close_colour ["$red_colour$wipe_waiting$close_colour"]`
$blue_colour"- CPU temp"$close_colour               = `echo -e "$yellow_colour$cpu_temp C$close_colour"`
$blue_colour"- HDD temp"$close_colour               = `echo -e "$yellow_colour$get_hdd_temp C$close_colour"`
$blue_colour"- CPU average usage"$close_colour         = `echo -e "$green_colour$get_average_cpu%$close_colour"`
$blue_colour"- Memory Usage"$close_colour              = `echo -e "$green_colour$memory_usage%$close_colour"`/` echo -e "$green_colour$memory_usage_gb$close_colour"` "of" `echo -e "$red_colour$memory_total MB$close_colour"`
$blue_colour"- Swap in use"$close_colour               = `echo -e "$green_colour$get_swap MB$close_colour"`
$blue_colour"- Processes"$close_colour              = `echo -e "$green_colour$get_proc_ps$close_colour"`
$blue_colour"- Networking"$close_colour             = `echo -e "$green_colour$interface: upload(tx) $TKBPS kb/s download(rx) $RKBPS kb/s$close_colour"`

$red_colour"Message:"$close_colour `echo -e "$red_colour"if you want to update this server, ask fedya on freenode:openmandriva-cooker"$close_colour"`
" > /etc/motd
