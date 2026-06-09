FROM apache/fluss-quickstart-flink:1.20-0.9.1-incubating

# This quickstart base does not ship the Paimon connector, the Paimon S3
# filesystem, or the Hadoop classes Paimon needs, so all three are added here.
# Versions are pinned as build args and every download is checksum verified, so
# the build is reproducible and fails on a corrupt, truncated, or replaced jar.
ARG PAIMON_VERSION=1.2.0
ARG PAIMON_FLINK_MINOR=1.20
ARG HADOOP_UBER_VERSION=2.8.3-10.0
ARG MAVEN_BASE=https://repo1.maven.org/maven2

# Expected SHA-512 checksums for the downloaded jars. Maven Central does not
# publish .sha512 for these artifacts, so the values are computed from the
# released jars, whose .sha1 checksums were cross-checked against Maven Central.
ARG PAIMON_FLINK_SHA512=469ca157e33d40405fffa29f3ff841b634ddc0a8a48a0652b338f46515a7e409c8cc73709494a7e3daceba54997a7ec4d8901cf76b7f76dc95253fbbf2e30345
ARG PAIMON_S3_SHA512=37349d311411f46a71be8d337db08e549613707f8350dd396b0809fddbbe6e1648a5bf0b8560ebf364287de9ca3eeb73eb05ee5d82583a7982c2708aaa643e8a
ARG HADOOP_UBER_SHA512=c04d217fb53123054c58c5c492cc8d87e75aa72b798e3b4858757cb4d389ccd9866c224662a012e1e9b012c05e481372e2bbc97cd45746f924814733d864591f

# Download the jars and verify them. curl -f makes an HTTP error page fail the
# build instead of being saved as a jar, and --retry rides out network blips.
RUN set -eux; \
    cd /opt/flink/lib; \
    curl -fL --retry 3 --retry-delay 2 -o paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/paimon/paimon-flink-${PAIMON_FLINK_MINOR}/${PAIMON_VERSION}/paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar; \
    curl -fL --retry 3 --retry-delay 2 -o paimon-s3-${PAIMON_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/paimon/paimon-s3/${PAIMON_VERSION}/paimon-s3-${PAIMON_VERSION}.jar; \
    curl -fL --retry 3 --retry-delay 2 -o flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/flink/flink-shaded-hadoop-2-uber/${HADOOP_UBER_VERSION}/flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar; \
    printf '%s  %s\n' \
      "${PAIMON_FLINK_SHA512}" "paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar" \
      "${PAIMON_S3_SHA512}" "paimon-s3-${PAIMON_VERSION}.jar" \
      "${HADOOP_UBER_SHA512}" "flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar" \
      > jars.sha512; \
    sha512sum -c jars.sha512; \
    rm jars.sha512; \
    chown flink:flink paimon-*.jar flink-shaded-hadoop-*.jar

# Ensure Prometheus plugin is properly set up (dir may already have correct ownership)
RUN if [ -d /opt/flink/plugins/metrics-prometheus ]; then \
      chown -R flink:flink /opt/flink/plugins/metrics-prometheus/; \
    fi
