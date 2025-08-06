export JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64

export LD_LIBRARY_PATH=/opt/hadoop/lib/native:$LD_LIBRARY_PATH

export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=/opt/hadoop/lib/native"