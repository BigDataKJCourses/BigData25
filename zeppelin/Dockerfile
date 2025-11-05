FROM bigdata25-worker:latest

ARG USERNAME=hadoop
ARG GROUPNAME=hadoop

ARG ZEPPELIN_VERSION=0.12.0
ARG ZEPPELIN_URL=https://dlcdn.apache.org/zeppelin/zeppelin-${ZEPPELIN_VERSION}/zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz
ENV ZEPPELIN_HOME=/opt/zeppelin

USER root
# Instalujemy curl i tar, jeśli nie ma ich w obrazie worker
RUN apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

# Instalacja Zeppelina
RUN mkdir -p $ZEPPELIN_HOME && \
    chown $USERNAME:$GROUPNAME $ZEPPELIN_HOME && \
    curl -fsSL $ZEPPELIN_URL -o /tmp/zeppelin.tgz && \
    tar -xf /tmp/zeppelin.tgz -C $ZEPPELIN_HOME --strip-components=1 && \
    rm /tmp/zeppelin.tgz && \
    chown -R $USERNAME:$GROUPNAME $ZEPPELIN_HOME

# Tworzenie katalogu na notebooki
RUN mkdir -p /home/hadoop/notebook && chown $USERNAME:$GROUPNAME /home/hadoop/notebook

# ----------------------------------------------------
# ETAP 4: Modyfikacja Konfiguracji Interpretera Spark
# ----------------------------------------------------
# Plik: /opt/zeppelin/interpreter/spark/interpreter-setting.json
RUN jq '.[0].properties."spark.master".defaultValue = "yarn" | \
       .[0].properties."spark.submit.deployMode".defaultValue = "client" | \
       .[0].properties."spark.app.name".defaultValue = "BigData25 Zeppelin" | \
       .[0].properties."zeppelin.spark.enableSupportedVersionCheck".defaultValue = false' \
       ${ZEPPELIN_HOME}/interpreter/spark/interpreter-setting.json > /tmp/spark-setting.json && \
    mv /tmp/spark-setting.json ${ZEPPELIN_HOME}/interpreter/spark/interpreter-setting.json

# ----------------------------------------------------
# ETAP 5: Modyfikacja Konfiguracji Interpretera JDBC
# ----------------------------------------------------
# Plik: /opt/zeppelin/interpreter/jdbc/interpreter-setting.json
RUN jq '.[0].properties."default.url".defaultValue = "jdbc:mysql://metastore:3306/" | \
       .[0].properties."default.user".defaultValue = "root" | \
       .[0].properties."default.password".defaultValue = "jupyter" | \
       .[0].properties."default.driver".defaultValue = "com.mysql.cj.jdbc.Driver" | \
       .[0].dependencies += [{"group": "com.mysql", "artifact": "mysql-connector-j", "version": "8.4.0"}]' \
       ${ZEPPELIN_HOME}/interpreter/jdbc/interpreter-setting.json > /tmp/jdbc-setting.json && \
    mv /tmp/jdbc-setting.json ${ZEPPELIN_HOME}/interpreter/jdbc/interpreter-setting.json

USER $USERNAME
WORKDIR /home/hadoop

ENV ZEPPELIN_HOME=$ZEPPELIN_HOME
ENV PATH=$ZEPPELIN_HOME/bin:$PATH 

# Uruchomienie Zeppelina
CMD ["/opt/zeppelin/bin/zeppelin.sh"]