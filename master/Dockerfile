FROM bigdata25-worker:latest

USER root

RUN apt-get update && \
    apt-get install -y default-mysql-client netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# --- Tez UI (statyczne pliki HTML/JS/CSS) ---
ARG TEZ_UI_VERSION=0.10.5
ARG TEZ_UI_WAR_URL=https://repo1.maven.org/maven2/org/apache/tez/tez-ui/${TEZ_UI_VERSION}/tez-ui-${TEZ_UI_VERSION}.war

USER hadoop

# Pobierz i rozpakuj tez-ui.war
RUN curl -fsSL ${TEZ_UI_WAR_URL} -o /opt/tez/tez-ui.war && \
    mkdir -p /opt/tez/tez-ui && \
    cd /opt/tez/tez-ui && \
    jar xf /opt/tez/tez-ui.war && \
    rm /opt/tez/tez-ui.war 

# --- Jupyter + biblioteki w venv ---
RUN /opt/venv/bin/pip install --no-cache-dir \
    jupyterlab \
    ipykernel \
    findspark \
    matplotlib \
    seaborn \
    sqlalchemy

WORKDIR /home/hadoop

ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
