#!/bin/sh

log() {
  echo "[l2tp-vpn-client @$(date +'%F %T')] $1"
}

whereAmI() {
  local var=$(curl -s ipconfig.io/json)
  local ip=$(echo $var|grep -Po '"ip":.*?[^\\]",'|grep -zoP '"ip":\s*\K[^\s,]*(?=\s*,)'|tr '\0' '\n'|tr -d "\"")
  local country=$(echo $var|grep -Po '"country":.*?[^\\]",'|grep -zoP '"country":\s*\K[^\s,]*(?=\s*,)'|tr '\0' '\n'|tr -d "\"")
  local city=$(echo $var|grep -Po '"city":.*?[^\\]",'|grep -zoP '"city":\s*\K[^\s,]*(?=\s*,)'|tr '\0' '\n'|tr -d "\"")
  log "Current IP address is $ip. Location is $country, $city."
}

setTable() {
  log "Updating routing table"
  log "Your routing table was:"
  ip route
  echo ""
  ip addr
  echo ""
  
  # Setup routing table
  local localIp=$(ip addr|grep "eth0"| grep "inet"|awk -F ' ' '{print $2}')
  echo "LocalIP = $localIp"
  local localNet=$(ipcalc -n $localIp|awk -F '=' '{print $2}')
  local mask=$(echo $localIp| awk -F '/' '{print $2}')
  local network=$(echo $localNet"/"$mask)
  local device=$(ip route show to default | grep -Eo "dev\s*[[:alnum:]]+" | sed 's/dev\s//g')
  local gw=$(ip route |awk '/default/ {print $3}')
  local myip=$(ip addr show dev eth0|grep "inet"|awk '{print $2}'|awk -F '/' '{print $1}')

  echo "ip route add $VPN_SERVER_IPV4 via $gw dev $device proto static metric 100"
  ip route add $VPN_SERVER_IPV4 via $gw dev $device proto static metric 100
  
  echo "ip route add "$network" via $gw dev $device proto static metric 70"
  ip route add "$network" via $gw dev $device proto static metric 70
  
  # Set a route back to local network
  if [ -n "$LAN" ]; then
    echo "ip route add $LAN via $gw dev $device proto static metric 70"
    ip route add $LAN via $gw dev $device proto static metric 70
  fi
  
  echo "ip route add default dev ppp0 proto static scope link metric 50"
  ip route add default dev ppp0 proto static scope link metric 50
  
  echo "ip route del default via $gw"
  ip route del default via $gw
  
  echo "ip route del $network dev $device"
  ip route del $network dev $device
  
  sleep 1
  
  log "Routing table updated"
  log "Your routing table is now:"
  ip route
  echo ""
  
  whereAmI
  log "Ready"
}

setupVPN() {
  log "Editing configuration files"
  
  # template out all the config files using env vars
  sed -i 's/right=.*/right='$VPN_SERVER_IPV4'/' /etc/ipsec.conf
  echo ': PSK "'$VPN_PSK'"' > /etc/ipsec.secrets
  sed -i 's/lns = .*/lns = '$VPN_SERVER_IPV4'/' /etc/xl2tpd/xl2tpd.conf
  sed -i 's/name .*/name '$VPN_USERNAME'/' /etc/ppp/options.l2tpd.client
  sed -i 's/password .*/password '$VPN_PASSWORD'/' /etc/ppp/options.l2tpd.client
  
  whereAmI
  
  log "Waiting..."
  sleep 3
  
  log "Launching ipsec"
  ipsec up L2TP-PSK
  sleep 3
  ipsec status L2TP-PSK
  
  log "Waiting..."
  sleep 2
  
  log "Launching service"
  (sleep 5 && log "Connecting to ppp daemon" && echo "c myVPN" > /var/run/xl2tpd/l2tp-control) &
  
  (sleep 10 && setTable) &
  
  log "Launching ppp daemon"
  exec /usr/sbin/xl2tpd -p /var/run/xl2tpd.pid -c /etc/xl2tpd/xl2tpd.conf -C /var/run/xl2tpd/l2tp-control -D
  sleep 10
}

echo "------------------------------------- ------------------------------------- -------------------------------------"

setupVPN

setTable

# Useful to debug
tail -f /dev/null

# We never see this
log "Oops, something went wrong."
