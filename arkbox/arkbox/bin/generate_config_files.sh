#!/bin/sh

#  Matthias Strubel    (c) 2013-2014
#    licenced with GPL-3
#	adapted by sleepdeficit (simon@sleepdev.sh) 2017
#
# Generate severall configuration files out of arkbox.conf
#     conf/hosts_generated
#     conf/dnsmasq_generated.conf
#     conf/radvd_generated.conf
#     conf/lighttpd/env
#     conf/hosts_mesh
#
# There are files for default configuration or adding custom stuff:
#     conf/hosts
#     conf/dnsmasq_default.conf
#
#  it is using the following VARS out of arkbox.conf:
#    NET               = The network of your box  i.e. 192.168.1
#    IP_SHORT          = The ip of the arkbox  i.e. 1    results 192.168.1.1
#    START_LEASE       =   Range of dhcp leases  start  10
#    END_LEASE         =                         end    250
#    LEASE_DURATION    =    lease time           30min
#    HOSTNAME          =  arkbox.lan   - o'rly?  Maybe generate some additional stuff here
#  -
#    GLOBAL_CHAT       = Enable Broadcasts
#    GLOBAL_DEST       = Broadcast IP destinations
#    PYTHONPATH        = Path of arkbox python libs
#    GEN_CHATFILE      = generated html chatfile
#    ARKBOX         = ArkBox Folder
#    CHATFILE          = data store for Shoutbox-content
#
#    NODE_CONFIG       = Config file for Mesh-Node parameters
#  -
#  ipv6.conf (loaded within arkbox.conf)
#    IPV6_ENABLE	= enables IPv6 config
#    IPV6_ADVERT	= which service for advertising IPv6 Prefix
#    IPV6_MASK		= Netmask
#    IPV6_PREFIX	= Which prefix should be announced.
#  -
#  node.conf
#    NODE_CONFIG_ACTIVE = if yes, configure special ipv6-node-hostname
#    NODE_IPV6_IP	= Device specific IP
#    NODE_NAME & NODE_GEN = Settings for setting up Hostname
#
#  Matthias Strubel    -- 08.06.2012
#    licenced with GPL-3

CONFIG_PATH="conf"
DNSMASQ_CONFIG=""
HOSTS_CONFIG=""
DEFAULT_HOSTS=""
LEASE_FILE=""
RADVD_CONFIG=""
LIGHTTPD_ENV_CONFIG=""
AVAHI_SRC=""
AVAHI_CONFIG=""

set_pathnames() {
  CONFIG_PATH=$1/conf
  DNSMASQ_CONFIG=$CONFIG_PATH/dnsmasq_generated.conf
  HOSTS_CONFIG=$CONFIG_PATH/hosts_generated
  HOSTS_MESH=$CONFIG_PATH/hosts_mesh
  DEFAULT_HOSTS=$CONFIG_PATH/hosts
  DEFAULT_DNSMASQ=$CONFIG_PATH/dnsmasq_default.conf
  RADVD_CONFIG=$CONFIG_PATH/radvd_generated.conf
  LEASE_FILE=$LEASE_FILE_LOCATION
  LIGHTTPD_ENV_CONFIG=$CONFIG_PATH/lighttpd/env
  AVAHI_CONFIG=$CONFIG_PATH/avahi/avahi-daemon.conf
  AVAHI_SRC=$CONFIG_PATH/avahi/avahi-daemon.conf.schema

}

generate_hosts() {
   set_hostname=$1
   set_ipv4=$2
   set_ipv6=$3
   echo "Generating hosts file .... "
   cat  $DEFAULT_HOSTS                 >  $HOSTS_CONFIG
   echo "$set_ipv4     $set_hostname " >> $HOSTS_CONFIG
   echo "$set_ipv6     $set_hostname " >> $HOSTS_CONFIG

}

generate_dnsmasq() {
   net=$1
   lease_start=$3
   lease_end=$4
   lease_time=$5
   ip_pb=$2
   dnsmasq_interface=$6
   echo "Generating dnsmasq.conf ....."
   cat $DEFAULT_DNSMASQ                > $DNSMASQ_CONFIG

   #Add interface line if filled
   [ -n $dnsmasq_interface ] &&   echo "interface=$dnsmasq_interface" >> $DNSMASQ_CONFIG

   lease_line="$net.$lease_start,$net.$lease_end,$lease_time"
   echo  "dhcp-range=$lease_line"      >> $DNSMASQ_CONFIG
   #redirect every dns
   dns_redirect="/#/$net.$ip_pb"
   echo "address=$dns_redirect"        >> $DNSMASQ_CONFIG
   echo "dhcp-leasefile=$LEASE_FILE"   >> $DNSMASQ_CONFIG

   echo "addn-hosts=$HOSTS_CONFIG"     >>$DNSMASQ_CONFIG

   #Mesh hosts
   echo "addn-hosts=$HOSTS_MESH" 	>> $DNSMASQ_CONFIG

   if [ "$IPV6_ENABLE" = "yes" ] && [ "$IPV6_ADVERT" = "dnsmasq" ] ; then
     echo "Do additional v6 stuff in dnsmasq.conf"
     echo "#----- V6 Stuff"                     >> $DNSMASQ_CONFIG
     echo "dchp-range=$ipv6_call::, ra-stateless" >> $DNSMASQ_CONFIG
   fi

}

generate_radvd(){
  prefix=$1
  mask=$2
  interface=$3

  echo "Generating config for radvd.."
  echo "#---- generated file ---"               > $RADVD_CONFIG
  echo "
    interface $interface {
       AdvSendAdvert on;
       MinRtrAdvInterval 3;
       MaxRtrAdvInterval 10;
       prefix $prefix::/$mask {
           AdvOnLink on;
	   AdvAutonomous on;
	   AdvRouterAddr on;
       };
    };
       "                                        >>  $RADVD_CONFIG
}

#------------ lighttpd env config - Start ---------------------

generate_lighttpd_env() {
        local GLOBAL_DEST="$2"
	local PYTHONPATH=$3
	local ARKBOX=$5
  	local DISK_GEN_HTMLFILE=$9

    echo "Generating Environment-config for lighttpd ....."

    LIGHTTPD_ENV_BR_LINE=""

	LIGHTTPD_ENV="setenv.add-environment = (
	   \"PYTHONPATH\"             => \"$PYTHONPATH:$ARKBOX/python_lib\",
     	   \"DISK_GEN_HTMLFILE\"      => \"$DISK_GEN_HTMLFILE\" ,
	   $LIGHTTPD_ENV_BR_LINE

        )"

    echo $LIGHTTPD_ENV > $LIGHTTPD_ENV_CONFIG
}

#------------ lighttpd env config - End   ---------------------


if [ -z  $1 ] ; then
  echo "Usage is
      generate_config_files.sh /opt/arkbox/conf/arkbox.conf
   "
   exit 255
fi

if [ !  -f $1 ] ; then
  echo "Config-File $1 not found..."
  exit 255
fi

. $1

. $NODE_CONFIG
. $ARKBOX_FOLDER/lib/node_name_generation.sh

IPV6="#"

set_pathnames  $ARKBOX_FOLDER

ipv6_call=''
if [ "$IPV6_ENABLE" = "yes" ] ; then
   ipv6_call=$IPV6_PREFIX
   IPV6=$IPV6_IP
   [[ "$IPV6_ADVERT" = "radvd" ]] && generate_radvd $IPV6_PREFIX  $IPV6_MASK $DNSMASQ_INTERFACE
fi
generate_hosts $HOST  $IP  $IPV6
generate_dnsmasq  $NET $IP_SHORT  $START_LEASE  $END_LEASE $LEASE_DURATION $DNSMASQ_INTERFACE
generate_lighttpd_env "$GLOBAL_DEST" $ARKBOX_PYTHONPATH $ARKBOX_FOLDER $GEN_DISKFILE

COMPLETE_HOST=$HOST

if [ "$NODE_CONFIG_ACTIVE" = "yes" ] ; then
     echo -n "Appending local node-name hosts entry "
     if generate_node_name "$HOST" "$NODE_NAME" "$NODE_GEN" ; then
	echo $NODE_GEN_OUTPUT
	echo "$NODE_IPV6_IP   $NODE_GEN_OUTPUT  " >> $HOSTS_CONFIG
	COMPLETE_HOST=$NODE_GEN_OUTPUT
     else
	 echo "Error: No valid node-name-config found, skipping"
     fi
fi

#We want a long hostname and not only the hostname itself...
### ArkBox Scripts generates its own config in  /opt/arkbox/conf/avahi
###   but, the daemon works per default only on /etc/avahi
### If you want to enable avahi, then you have to link /etc/avahi to /opt/arkbox/conf/avahi
### On OpenWRT this should happen, if avahi is available before installing the arkbox
###  automtically.
AVAHI_HOST=$( echo $COMPLETE_HOST | sed 's|\.|_|g' )
sed "s|#####MASKED_HOSTNAME#####|$AVAHI_HOST|" $AVAHI_SRC > $AVAHI_CONFIG
