#!/bin/bash
set -e

echo "[WORKER] Fixing permissions for HDFS data directory..."

HDFS_DATA_DIR=/opt/hadoop/dfs/data
NM_LOG_DIR=/tmp/hadoop-hadoop/nm-logs
NM_LOCAL_DIR=/tmp/hadoop-hadoop/nm-local-dir

if [ -d "$HDFS_DATA_DIR" ]; then
  sudo chown -R hadoop:hadoop "$HDFS_DATA_DIR"
  sudo chmod -R 750 "$HDFS_DATA_DIR"
else
  echo "[WORKER] Warning: HDFS data directory $HDFS_DATA_DIR does not exist."
fi

echo "[WORKER] Creating NAMENODE log and local directory..."

if [ ! -d "$NM_LOG_DIR" ]; then
  sudo mkdir -p "$NM_LOG_DIR"
  sudo chown -R hadoop:hadoop "$NM_LOG_DIR"
fi

if [ ! -d "$NM_LOCAL_DIR" ]; then
  sudo mkdir -p "$NM_LOCAL_DIR"
  sudo chown -R hadoop:hadoop "$NM_LOCAL_DIR"
fi

# Adjust configuration files
CONFIG_DIR_RW="/tmp/hadoop-conf"

# Copy configs to writable directory
cp -r /etc/hadoop/conf "$CONFIG_DIR_RW"

# Perform envsubst or sed on the copy
envsubst < "$CONFIG_DIR_RW/hdfs-site.xml" > "$CONFIG_DIR_RW/hdfs-site.xml.tmp" && mv "$CONFIG_DIR_RW/hdfs-site.xml.tmp" "$CONFIG_DIR_RW/hdfs-site.xml"
envsubst < "$CONFIG_DIR_RW/yarn-site.xml" > "$CONFIG_DIR_RW/yarn-site.xml.tmp" && mv "$CONFIG_DIR_RW/yarn-site.xml.tmp" "$CONFIG_DIR_RW/yarn-site.xml"

# Tell Hadoop to use the modified config directory
export HADOOP_CONF_DIR="$CONFIG_DIR_RW"

# In entrypoint - only at worker nodes
export HADOOP_CLASSPATH="$HADOOP_CLASSPATH:$SPARK_HOME/jars/*"

echo "[WORKER] Starting Hadoop DataNode and NodeManager..."

if ! pgrep -f 'org.apache.hadoop.hdfs.server.datanode.DataNode' >/dev/null; then
  echo "[WORKER] Starting Hadoop DataNode..."
  $HADOOP_HOME/bin/hdfs --daemon start datanode
else
  echo "[WORKER] DataNode already running."
fi

if ! pgrep -f 'org.apache.hadoop.yarn.server.nodemanager.NodeManager' >/dev/null; then
  echo "[WORKER] Starting Hadoop NodeManager..."
  $HADOOP_HOME/bin/yarn --daemon start nodemanager
else
  echo "[WORKER] NodeManager already running."
fi

# Funkcja do zatrzymania serwisów przy SIGTERM/SIGINT
function shutdown {
  echo "[WORKER] Stopping Hadoop DataNode and NodeManager..."
  $HADOOP_HOME/bin/yarn --daemon stop nodemanager
  sleep 1
  $HADOOP_HOME/bin/hdfs --daemon stop datanode
  sleep 1
  exit 0
}

trap shutdown SIGTERM SIGINT

LOG_DIR=$HADOOP_HOME/logs
mkdir -p "$LOG_DIR"
touch $LOG_DIR/worker.log

# Tail logi żeby kontener nie umarł
tail -n 100 -F $LOG_DIR/*.log || true &

wait
