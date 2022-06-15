#!/bin/bash
set -x

shopt -s expand_aliases
alias netex="ip netns exec"

function set_veth_netns {
    ip link set $1 netns $2
    netex $2 ip addr add $3 dev $1
}

./setup_topology.sh

ip  link add wg0 type wireguard
set_veth_netns wg0 h2 10.0.0.1/24
netex h2 wg setconf wg0 server/wg0.conf
netex h2 ip link set wg0 up
sleep 1

ip  link add wg1 type wireguard
set_veth_netns wg1 h1 10.0.0.2/32
netex h1 wg setconf wg1 vpn1/wg1.conf
sleep 1
netex h1 ip link set wg1 up



ip  link add wg2 type wireguard
set_veth_netns wg2 h1 10.0.0.3/32
netex h1 wg setconf wg2 vpn2/wg2.conf
netex h1 ip link set wg2 up
sleep 1


ip -n h1 rule add pref 10 fwmark 21 table isp1
ip -n h1 route add default via 11.0.0.1 dev h1_s_a table isp1

ip -n h1 rule add pref 10 fwmark 22 table isp2
ip -n h1 route add default via 11.0.0.1 dev h1_s_b table isp2


ip -n h2 mptcp endpoint flush
ip -n h2 mptcp limits set subflow 2 add_addr_accepted 2

ip -n h1 mptcp endpoint flush
ip -n h1 mptcp limits set subflow 2 add_addr_accepted 2
ip -n h1 mptcp endpoint add 10.0.0.3 dev wg2 id 1 subflow

ip -n h1 rule add pref 10 from 10.0.0.2 table vpn1
ip -n h1 route add default dev wg1 table vpn1

ip -n h1 rule add pref 10 from 10.0.0.3 table vpn2
ip -n h1 route add default  dev wg2 table vpn2

# Trick mptcp to send packets from 10.0.0.11 & use 10.0.0.12 when subflow is necessary
ip -n h1 route del 10.0.0.1
ip -n h1 route del 10.0.0.1
ip -n h1 r add 10.0.0.1 dev wg1 proto kernel scope link src 10.0.0.2

echo "Ensure that the below entries are present in /etc/iproute2/rt_tables 
101 isp1
102 isp2
11 vpn1
12 vpn2"
