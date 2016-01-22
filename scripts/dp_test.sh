#!/bin/bash -x

function mac_flood() {
    #
    # Flood a given Neutron network with UDP packets to sequential MAC addresses
    #
    local netid=$1

    set -e

    sudo modprobe pktgen

    local probeout=$(mktemp)
    neutron-debug --config-file /etc/neutron/dhcp_agent.ini probe-create $netid 2>&1 | tee $probeout
    # 2016-01-22 21:10:53.496 7221 INFO neutron.debug.commands.CreateProbe [-] Probe created : 6bc8bf9e-6c3e-48cd-a78b-55483693d7ca
    local probe_id=$(awk 'BEGIN { FS=" : "} /Probe created/ {  print $2 }' $probeout)
    rm $probeout

    local portout=$(mktemp)
    neutron port-show $probe_id | tee $portout
    local port_mac=$(awk '/mac_address/ {print $4}' $portout)
    read subnet_id port_ip <<<$(awk 'BEGIN {FS="\""} /fixed_ips/ {print $4, $8}' $portout)
    rm $portout

    # TODO
    subnet_first_ip=192.0.2.1
    subnet_last_ip=192.0.2.254

    local probens=qprobe-$probe_id
    local iface=tap$(echo $probe_id | cut -b -11)

    echo "add_device $iface@0" | sudo ip netns exec $probens tee /proc/net/pktgen/kpktgend_0
    echo "count 16777216" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "src_mac $port_mac" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "dst_mac fa:16:3e:00:00:00" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "dst_mac_count 16777216" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "src_min $port_ip" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "src_max $port_ip" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "dst_min $subnet_first_ip" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "dst_max $subnet_last_ip" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "udp_src_min 1024" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "udp_src_max 65535" | sudo ip netns exec $probens tee /proc/net/pktgen/$iface@0
    echo "start" | sudo ip netns exec $probens tee /proc/net/pktgen/pgctrl
    sudo ip netns exec $probens cat /proc/net/pktgen/$iface@0
    neutron-debug --config-file /etc/neutron/dhcp_agent.ini probe-delete $probe_id
}

mac_flood $1
