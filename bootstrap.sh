#!/bin/bash

#while :; do
#	_hostname="$(hostname -f)"
#	if [[ $_hostname == *.* && $_hostname != *.internal ]]; then
#		break
#	fi
#	systemctl restart systemd-networkd
#	echo "Waiting for FQDN..."
#	sleep 10
#done

apt-get update
# Install JRE
# https://adoptopenjdk.net/installation.html?variant=openjdk15&jvmVariant=openj9#linux-pkg
# THIS ASSUMES DEBIAN 10 "buster" and openJ9 version of JRE 15
apt-get install -y --no-install-recommends wget apt-transport-https gnupg2
wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb buster main" | sudo tee /etc/apt/sources.list.d/adoptopenjdk.list
apt-get update
apt install -y --no-install-recommends adoptopenjdk-15-openj9-jre

#curl -sSfL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
#echo "deb http://packages.cloud.google.com/apt gcsfuse-bionic main" \
#	>/etc/apt/sources.list.d/gcsfuse.list
apt install -y --no-install-recommends \
    apt-transport-https gnupg2 \
    collectd collectd-utils liboping0 jq dnsutils \
		bpfcc-tools iotop \
		nginx libnginx-mod-http-fancyindex \
		coreutils tree \
		build-essential autoconf automake libtool \
		python3 python3-venv python3-dev \
		unzip graphviz subversion

wget https://storage.googleapis.com/public.bucket.rchain-dev.tk/rnode_0.10.0-145-gab6de27_all.deb -O ~/rnode.deb
dpkg -i ~/rnode.deb

#apt install -y --no-install-recommends --no-upgrade docker-ce
#apt install -y --no-install-recommends gcsfuse

#pushd scripts >/dev/null
#python3 -mvenv venv
#source ./venv/bin/activate
# pyjq setup fails with errors similar to https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=917006
# explicitly installing wheel fixes the error
#pip3 install wheel
# upgrade setuptools for pyrchain to work
#pip3 install -U setuptools>=40.1
#pip3 install -U -r requirements.txt
#popd >/dev/null

mkdir ~/.rnode | true
mkdir ~/.rnode/genesis | true

tar -xvzf /root/rnode.tar.gz -C ~/.rnode/ --strip-components=1

# install -C -m644 nginx/* -t /etc/nginx/
# systemctl reload nginx

######################################################################
# create bonds.txt file

cp /root/bonds.txt ~/.rnode/genesis/bonds.txt
cp /root/wallets.txt ~/.rnode/genesis/wallets.txt

cat > ~/.rnode/kamon.conf << EOF
# Kamon configuration, for syntax please look to Kamon reporters documentation
# https://kamon.io/docs/latest/reporters/
kamon {
  trace = {
    sampler = always
    join-remote-parents-with-same-span-id = true
  }

  # Config for streaming metrics
  influxdb {
    # InfluxDB server hostname and UDP port
    hostname = "127.0.0.1"
    port = 8089

    # Max packet size for UDP metrics data sent to InfluxDB
    max-packet-size = 1024 bytes

    # For histograms, which percentiles to count.
    percentiles = [50.0, 70.0, 90.0, 95.0, 99.0, 99.9]

    # Allow including environment information as tags on all reported metrics.
    additional-tags {
      # Define whether specific environment settings will be included as tags in all exposed metrics. When enabled,
      # the service, host and instance tags will be added using the values from Kamon.environment().
      service = yes
      host = yes
      instance = yes

      # Specifies which Kamon environment tags should be ignored. All unmatched tags will be always added to al metrics.
      blacklisted-tags = []
    }
  }

  # Server for spans collection (you can use Zipkin or Jaeger or any other Zipkin compatible tracing systems).
  zipkin {
    # Hostname and port where the Zipkin Server is running.
    host = "jaeger-dev.c.developer-222401.internal"
    port = 9411

    # Decides whether to use HTTP or HTTPS when connecting to Zipkin.
    protocol = "http"
  }

  prometheus {
    enabled = false
  }

  sigar {
    enabled = false
  }
}
EOF

######################################################################
# BEGIN docker run

JMX_PORT=9999
launcher_args=(
  -XX:MaxDirectMemorySize=200m
  -XX:InitialRAMPercentage=30
  -XX:MaxRAMPercentage=75
	-XX:+HeapDumpOnOutOfMemoryError
	-XX:HeapDumpPath=$DIAG_DIR/heapdump_OOM.hprof
	-XX:+ExitOnOutOfMemoryError
	-XX:ErrorFile=$DIAG_DIR/hs_err.log
	-XX:MaxJavaStackTraceDepth=100000
	-Dlogback.configurationFile=~/.rnode/logback.xml
  -Dcom.sun.management.jmxremote.port=$JMX_PORT
  -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT
  -Dcom.sun.management.jmxremote.local.only=false
  -Dcom.sun.management.jmxremote.authenticate=false
  -Dcom.sun.management.jmxremote.ssl=false
  -Djava.rmi.server.hostname=localhost
)

run_args=(
	-c ~/.rnode/rnode.conf
)

#nohup rnode ${launcher_args[@]} run ${run_args[@]} &>/dev/null &
tmux new-session -d -s rnode rnode ${launcher_args[@]} run ${run_args[@]}
