FROM apache/fluss-quickstart-flink:1.20-0.9.1-incubating

# This quickstart base does not ship the Paimon connector, the Paimon S3
# filesystem, the Hadoop classes Paimon needs, or the Fluss Paimon lake-storage
# plugin used by the tiering service, so they are added here. Versions are
# pinned as build args and every download is checksum verified, so the build is
# reproducible and fails on a corrupt, truncated, or replaced jar.
ARG PAIMON_VERSION=1.3.1
ARG PAIMON_FLINK_MINOR=1.20
ARG HADOOP_UBER_VERSION=2.8.3-10.0
ARG FLUSS_VERSION=0.9.1-incubating
ARG MAVEN_BASE=https://repo1.maven.org/maven2

# Expected SHA-512 checksums for the downloaded jars. Maven Central does not
# publish .sha512 for these artifacts, so the values are computed from the
# released jars, whose .sha1 checksums were cross-checked against Maven Central.
ARG PAIMON_FLINK_SHA512=98930b30685e08d11ab53ab61c0bff0de14574d42ab1bf1a5ccace92ba2437e04b41ddc56275e418fea6e70daac47d3cce36ebc828c487855f262569a696b43c
ARG PAIMON_S3_SHA512=79aee3320fc0abe98a4187d948868219ad9d1530e0e46ed11b2c1e57c7b1272c3bbc9a9a7152b417d1a7f471af3d2565c0ecca4a8cbea298519236548f9c4e00
ARG HADOOP_UBER_SHA512=c04d217fb53123054c58c5c492cc8d87e75aa72b798e3b4858757cb4d389ccd9866c224662a012e1e9b012c05e481372e2bbc97cd45746f924814733d864591f
ARG FLUSS_LAKE_PAIMON_SHA512=554b4ab570f4f6543fad0fa53d732b9a0036f975c9190991651d7ee700d6d318ca31cbb73afa46e5e04b2417f2f683174dc6c740c0f2d3eae9fa28d99e036f02

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
    curl -fL --retry 3 --retry-delay 2 -o fluss-lake-paimon-${FLUSS_VERSION}.jar \
      ${MAVEN_BASE}/org/apache/fluss/fluss-lake-paimon/${FLUSS_VERSION}/fluss-lake-paimon-${FLUSS_VERSION}.jar; \
    printf '%s  %s\n' \
      "${PAIMON_FLINK_SHA512}" "paimon-flink-${PAIMON_FLINK_MINOR}-${PAIMON_VERSION}.jar" \
      "${PAIMON_S3_SHA512}" "paimon-s3-${PAIMON_VERSION}.jar" \
      "${HADOOP_UBER_SHA512}" "flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar" \
      "${FLUSS_LAKE_PAIMON_SHA512}" "fluss-lake-paimon-${FLUSS_VERSION}.jar" \
      > jars.sha512; \
    sha512sum -c jars.sha512; \
    rm jars.sha512; \
    chown flink:flink paimon-*.jar flink-shaded-hadoop-*.jar fluss-lake-paimon-*.jar

# Enable Flink's bundled S3 filesystem plugin so Paimon can resolve the s3://
# warehouse when reading tiered tables through the Fluss $lake path. The jar
# ships with the base image under /opt/flink/opt.
RUN set -eux; \
    mkdir -p /opt/flink/plugins/s3-fs-hadoop; \
    cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/

# Ensure Prometheus plugin is properly set up (dir may already have correct ownership)
RUN if [ -d /opt/flink/plugins/metrics-prometheus ]; then \
      chown -R flink:flink /opt/flink/plugins/metrics-prometheus/; \
    fi
