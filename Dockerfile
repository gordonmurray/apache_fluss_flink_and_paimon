FROM fluss/quickstart-flink:1.20-0.7.0

# Download Paimon JARs
ARG PAIMON_VERSION=1.2.0
RUN set -eux; \
    curl -L -o /opt/flink/lib/paimon-flink-1.20-${PAIMON_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-1.20/${PAIMON_VERSION}/paimon-flink-1.20-${PAIMON_VERSION}.jar; \
    curl -L -o /opt/flink/lib/paimon-s3-${PAIMON_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/paimon/paimon-s3/${PAIMON_VERSION}/paimon-s3-${PAIMON_VERSION}.jar; \
    curl -L -o /opt/flink/lib/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar

# Set proper ownership
RUN chown flink:flink /opt/flink/lib/paimon-*.jar /opt/flink/lib/flink-shaded-hadoop-*.jar

# Verify JARs were downloaded
RUN ls -la /opt/flink/lib/paimon-* /opt/flink/lib/flink-shaded-hadoop-*

# Ensure Prometheus plugin is properly set up
RUN chown -R flink:flink /opt/flink/plugins/metrics-prometheus/