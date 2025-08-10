#!/usr/bin/env bash
set -e

NAMEDIR=${NAMEDIR:-/hadoop/dfs/name}
SPARK_LOGS_HDFS_PATH=${SPARK_LOGS_HDFS_PATH:-/spark-logs}

function shutdown {
  echo "[MASTER] Zatrzymuję usługi..."

  echo "[MASTER] Stopuję JupyterLab..."
  pkill -f "jupyter lab" || true

  echo "[MASTER] Stopuję Spark History Server..."
  $SPARK_HOME/sbin/stop-history-server.sh || true

  echo "[MASTER] Stopuję Tez UI..."
  pkill -f "python3 -m http.server" || true

  echo "[MASTER] Stopuję HiveServer2..."
  pkill -f "hiveserver2" || true

  echo "[MASTER] Stopuję Hive Metastore..."
  pkill -f "hive --service metastore" || true

  echo "[MASTER] Stopuję MapReduce History Server..."
  mapred --daemon stop historyserver || true

  echo "[MASTER] Stopuję ResourceManager..."
  yarn --daemon stop resourcemanager || true

  echo "[MASTER] Stopuję Timeline Server..."
  yarn --daemon stop timelineserver || true

  echo "[MASTER] Stopuję NameNode..."
  hdfs --daemon stop namenode || true

  echo "[MASTER] Wszystkie usługi zatrzymane. Kończę pracę."
  exit 0
}

trap shutdown SIGTERM SIGINT

echo "[MASTER] Naprawiam uprawnienia dla katalogu NameNode: $NAMEDIR"
sudo chown -R hadoop:hadoop "$NAMEDIR"
sudo chmod -R 700 "$NAMEDIR"

echo "[MASTER] Ustawiam uprawnienia dla katalogu domowego"
sudo chown -R hadoop:hadoop /home/hadoop

# Adjust configuration files
CONFIG_DIR_RW="/tmp/hadoop-conf"

# Copy configs to writable directory
cp -r /etc/hadoop/conf "$CONFIG_DIR_RW"

# Perform envsubst or sed on the copy
envsubst < "$CONFIG_DIR_RW/hdfs-site.xml" > "$CONFIG_DIR_RW/hdfs-site.xml.tmp" && mv "$CONFIG_DIR_RW/hdfs-site.xml.tmp" "$CONFIG_DIR_RW/hdfs-site.xml"
envsubst < "$CONFIG_DIR_RW/yarn-site.xml" > "$CONFIG_DIR_RW/yarn-site.xml.tmp" && mv "$CONFIG_DIR_RW/yarn-site.xml.tmp" "$CONFIG_DIR_RW/yarn-site.xml"

# Tell Hadoop to use the modified config directory
export HADOOP_CONF_DIR="$CONFIG_DIR_RW"

echo "[MASTER] Sprawdzam katalog NameNode: $NAMEDIR"
NAMENODE_FORMATTED_FLAG="$NAMEDIR/.namenode_formatted"
if [ -z "$(ls -A "$NAMEDIR" 2>/dev/null)" ] && [ ! -f "$NAMENODE_FORMATTED_FLAG" ]; then
  echo "[MASTER] Formatowanie NameNode (katalog $NAMEDIR)..."
  hdfs namenode -format -force -nonInteractive
  touch "$NAMENODE_FORMATTED_FLAG"
fi

echo "[MASTER] Startuję Hadoop NameNode..."
hdfs --daemon start namenode

function wait_for_namenode_ready {
  NAMENODE_HOST="master"
  NAMENODE_PORT=8020

  echo "[MASTER] Czekam na dostępność NameNode na $NAMENODE_HOST:$NAMENODE_PORT..."
  while ! nc -z "$NAMENODE_HOST" "$NAMENODE_PORT"; do
    echo "NameNode niedostępny ($NAMENODE_HOST:$NAMENODE_PORT), czekam..."
    sleep 3
  done

  echo "[MASTER] Sprawdzam SafeMode NameNode..."
  while hdfs dfsadmin -safemode get 2>/dev/null | grep -q "ON"; do
    echo "NameNode jest w SafeMode, czekam..."
    sleep 5
  done
  echo "[MASTER] NameNode wyszedł z SafeMode i jest gotowy."
}

wait_for_namenode_ready

echo "[MASTER] Startuję ResourceManager..."
yarn --daemon start resourcemanager

echo "[MASTER] Startuję Timeline Server..."
yarn --daemon start timelineserver

echo "[MASTER] Tworzę katalogi historii MR..."
hdfs dfs -mkdir -p /mr-history/done || true
hdfs dfs -mkdir -p /mr-history/tmp || true
hdfs dfs -chown -R hadoop:hadoop /mr-history

echo "[MASTER] Startuję MapReduce JobHistory Server..."
mapred --daemon start historyserver

MYSQL_USER="hive"
MYSQL_PASSWORD="hive"

echo "[MASTER] Czekam na start MySQL (metastore:3306)..."
until mysql -h metastore -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; do
  sleep 2
done
echo "[MASTER] MySQL gotowy."

# Inicjalizacja Hive Metastore i katalogów HDFS
HIVE_INITIALIZED_FLAG="$NAMEDIR/.hive_initialized"
if [ ! -f "$HIVE_INITIALIZED_FLAG" ]; then
  echo "[MASTER] Inicjalizuję Hive Metastore i katalogi HDFS..."
  hdfs dfs -mkdir -p /user/hive/warehouse
  schematool -dbType mysql -initSchema
  touch "$HIVE_INITIALIZED_FLAG"
fi

echo "[MASTER] Startuję Hive Metastore i HiveServer2..."
hive --service metastore > /tmp/hive-metastore.log 2>&1 &
hiveserver2 > /tmp/hiveserver2.log 2>&1 &

echo "[MASTER] Tworzę katalog /tmp w HDFS"
hdfs dfs -mkdir -p /tmp || true

echo "[MASTER] Startuję Tez UI (static) na porcie 9999..."
python3 -m http.server 9999 --directory /opt/tez/tez-ui > /tmp/tez-ui.log 2>&1 &

echo "[MASTER] Tworzę katalog dla Spark logs: $SPARK_LOGS_HDFS_PATH"
hdfs dfs -mkdir -p "$SPARK_LOGS_HDFS_PATH"

echo "[MASTER] Startuję Spark History Server"
$SPARK_HOME/sbin/start-history-server.sh

# --- START JUPYTER LAB ---
echo "[MASTER] Czyszczenie starych sesji Jupyter..."
rm -rf /home/hadoop/.local/share/jupyter/runtime/* 2>/dev/null || true
rm -rf /home/hadoop/.ipython/profile_default/security/* 2>/dev/null || true

echo "[MASTER] Startuję JupyterLab..."
jupyter lab --notebook-dir=/home/hadoop/notebooks --ip=0.0.0.0 --port=8888 --no-browser --allow-root --IdentityProvider.token='' > /tmp/jupyter.log 2>&1 &

echo "[MASTER] Wszystkie usługi uruchomione."

# Utrzymaj kontener aktywny – pokazuj logi wszystkich serwisów
tail -n +1 -F \
  /tmp/hive-metastore.log \
  /tmp/hiveserver2.log \
  /tmp/jupyter.log \
  /tmp/tez-ui.log \
  $HADOOP_HOME/logs/*.log \
  $HADOOP_HOME/logs/mapred-*.log &

wait