FROM debian:12

ARG USERNAME=hadoop
ARG GROUPNAME=hadoop
ARG UID=1000
ARG GID=1000

# Ustawienie lokalizacji (ważne np. dla Python, Hadoop, Spark)
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Zainstaluj potrzebne pakiety: curl, wget, unzip, nano, sudo, procps, gpg
RUN apt-get update && \
    apt-get install -y curl wget unzip nano net-tools sudo procps gnupg2 gettext-base && \
    # Dodaj klucz i repo Adoptium 
    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bullseye main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-17-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Python (np. dla Hadoop Streaming) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev && \
    rm -rf /var/lib/apt/lists/*

# Symboliczny link, bo niektóre narzędzia wywołują "python", a nie "python3"
RUN ln -s /usr/bin/python3 /usr/bin/python || true

# --- Konfiguracja użytkownika Hadoop ---
RUN groupadd -g $GID $GROUPNAME && \
    useradd -m -s /bin/bash -u $UID -g $GID $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Tworzymy wirtualne środowisko, bo Debian 12 blokuje instalację pakietów pip globalnie (EXTERNALLY-MANAGED)
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir \
        pandas \
        pyarrow && \
    chown -R $USERNAME:$GROUPNAME /opt/venv

# Dodajemy venv do PATH, by domyślny python i pip wskazywały na środowisko wirtualne
ENV PATH="/opt/venv/bin:$PATH"

# Ustawiamy użytkownika hadoop (wszystko powyżej robione jako root)
USER $USERNAME
WORKDIR /home/hadoop

ENV JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64

# --- Hadoop --- 
ARG HADOOP_VERSION=3.4.2
ARG HADOOP_BASE_URL=https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}
ENV HADOOP_HOME=/opt/hadoop

USER root
RUN mkdir -p $HADOOP_HOME && \
    chown $USERNAME:$GROUPNAME $HADOOP_HOME && \
    curl -fsSL ${HADOOP_BASE_URL}/hadoop-${HADOOP_VERSION}.tar.gz -o /tmp/hadoop.tar.gz || \
    curl -fsSL ${HADOOP_BASE_URL}/hadoop-${HADOOP_VERSION}.tar -o /tmp/hadoop.tar && \
    if [ -f /tmp/hadoop.tar.gz ]; then \
        tar -xf /tmp/hadoop.tar.gz -C $HADOOP_HOME --strip-components=1; \
        rm /tmp/hadoop.tar.gz; \
    else \
        tar -xf /tmp/hadoop.tar -C $HADOOP_HOME --strip-components=1; \
        rm /tmp/hadoop.tar; \
    fi && \
    chown -R $USERNAME:$GROUPNAME $HADOOP_HOME

USER $USERNAME

ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

# --- Hive 4.1.0 ---
ARG HIVE_VERSION=4.1.0
ARG HIVE_URL=https://downloads.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz
ENV HIVE_HOME=/opt/hive

USER root
RUN mkdir -p $HIVE_HOME && \
    chown $USERNAME:$GROUPNAME $HIVE_HOME && \
    curl -fsSL $HIVE_URL -o /tmp/hive.tar.gz && \
    tar -xf /tmp/hive.tar.gz -C $HIVE_HOME --strip-components=1 && \
    rm /tmp/hive.tar.gz && \
    curl -L -o $HIVE_HOME/lib/mysql-connector-j-8.4.0.jar https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar && \
    chown -R $USERNAME:$GROUPNAME $HIVE_HOME && \
    chmod 644 $HIVE_HOME/lib/mysql-connector-j-8.4.0.jar

USER $USERNAME

ENV PATH=$HIVE_HOME/bin:$PATH
ENV HIVE_CONF_DIR=/etc/hive/conf
# ENV HADOOP_CLASSPATH="$HADOOP_CLASSPATH:$HIVE_HOME/lib/*"

# --- Tez 0.10.5 ---
ARG TEZ_VERSION=0.10.5
ARG TEZ_URL=https://downloads.apache.org/tez/${TEZ_VERSION}/apache-tez-${TEZ_VERSION}-bin.tar.gz
ENV TEZ_HOME=/opt/tez

USER root
RUN mkdir -p $TEZ_HOME && \
    chown $USERNAME:$GROUPNAME $TEZ_HOME && \
    curl -fsSL $TEZ_URL -o /tmp/tez.tar.gz && \
    tar -xf /tmp/tez.tar.gz -C $TEZ_HOME --strip-components=1 && \
    rm /tmp/tez.tar.gz && \
    chown -R $USERNAME:$GROUPNAME $TEZ_HOME

USER $USERNAME

ENV PATH=$TEZ_HOME/bin:$PATH
# ENV HADOOP_CLASSPATH="$TEZ_HOME/*"

# --- Spark ---
ARG SPARK_VERSION=4.0.1
ARG SPARK_URL=https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz
ENV SPARK_HOME=/opt/spark

USER root
RUN mkdir -p $SPARK_HOME && \
    chown $USERNAME:$GROUPNAME $SPARK_HOME && \
    curl -fsSL $SPARK_URL -o /tmp/spark.tgz && \
    tar -xf /tmp/spark.tgz -C $SPARK_HOME --strip-components=1 && \
    rm /tmp/spark.tgz && \
    curl -fsSL https://repo1.maven.org/maven2/org/apache/spark/spark-network-yarn_2.13/${SPARK_VERSION}/spark-network-yarn_2.13-${SPARK_VERSION}.jar \
         -o $SPARK_HOME/jars/spark-network-yarn_2.13-${SPARK_VERSION}.jar && \
    chown -R $USERNAME:$GROUPNAME $SPARK_HOME

USER $USERNAME

ENV PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH
ENV SPARK_CONF_DIR=/etc/spark/conf
ENV PYSPARK_PYTHON=/opt/venv/bin/python
ENV PYTHONHASHSEED=1
ENV SPARK_CLASSPATH="$SPARK_HOME/jars/*"

# --- Konfiguracja przez wolumen ---
ENV HADOOP_CONF_DIR=/etc/hadoop/conf

# ENTRYPOINT jest montowany z wolumenu
ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
