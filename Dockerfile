###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/ark_keycloak:latest .
#
# How to run: (Helm)
#
# helm repo add arkcase https://arkcase.github.io/ark_helm_charts/
# helm install ark-keycloak arkcase/ark-keycloak
# helm uninstall ark-keycloak
#
# How to run: (Docker)
#
# docker run --name ark_keycloak -p 8443:8443  -d arkcase/keycloak:latest
# docker exec -it ark_keycloak/bin/bash
# docker stop ark_keycloak
# docker rm ark_keycloak
#
# How to run: (Kubernetes)
#
# kubectl create -f pod_ark_keycloak.yaml
# kubectl --namespace default port-forward keycloak 8443:8443 --address='0.0.0.0'
# kubectl exec -it pod/keycloak -- bash
# kubectl delete -f pod_ark_keycloak.yaml
#
###########################################################################################################

ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG ARCH="amd64"
ARG OS="linux"

# https://quay.io/repository/keycloak/keycloak?tab=tags
ARG VER="23.0.1-0"
ARG PKG="keycloak"
ARG SRC="quay.io/keycloak/keycloak:latest"

ARG JMX_VER="0.17.0"
ARG JMX_SRC="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_VER}/jmx_prometheus_javaagent-${JMX_VER}.jar"

ARG BASE_REPO="arkcase/base"
ARG BASE_VER="8"
ARG BASE_IMG="${PUBLIC_REGISTRY}/${BASE_REPO}:${BASE_VER}"

FROM "${SRC}" as builder
FROM "${BASE_IMG}"

ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG APP_UID="1998"
ARG APP_GID="${APP_UID}"
ARG APP_USER="${PKG}"
ARG APP_GROUP="${APP_USER}"
ARG BASE_DIR="/opt/keycloak"
ARG HOME_DIR="${BASE_DIR}/${PKG}"
ARG CONF_DIR="${BASE_DIR}/conf"
ARG IMPORT_DIR="${BASE_DIR}/data/import"

# Enable health and metrics support
ARG KC_HEALTH_ENABLED=true
ARG KC_METRICS_ENABLED=true

# Master Realm Admin
ARG KEYCLOAK_ADMIN=admin
ARG KEYCLOAK_ADMIN_PASSWORD=Armedia@1234567890

ARG SRC
ARG JMX_SRC

#
# Basic Parameters
#

LABEL ORG="Armedia LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Keycloak"
LABEL VERSION="${VER}"

# Environment variables: tarball stuff
ENV JMX_PROMETHEUS_AGENT_JAR="jmx_prometheus_javaagent-${JMX_VER}.jar"
ENV HOME_DIR="${HOME_DIR}"
ENV CONF_DIR="${CONF_DIR}"

# Environment variables: system stuff
ENV APP_UID="${APP_UID}"
ENV APP_GID="${APP_GID}"
ENV APP_USER="${APP_USER}"
ENV APP_GROUP="${APP_GROUP}"

# Environment variables: Java stuff
ENV JAVA_HOME="/usr/lib/jvm/jre-17-openjdk"
ENV USER="${APP_USER}"

# Keycloak
ENV KC_HEALTH_ENABLED="${KC_HEALTH_ENABLED}"
ENV KC_METRICS_ENABLED="${KC_METRICS_ENABLED}"
ENV KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN}"
ENV KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
ENV IMPORT_DIR="${IMPORT_DIR}"

WORKDIR "${BASE_DIR}"

ENV JMX_AGENT_JAR="${HOME_DIR}/jmx-prometheus-agent.jar"
ENV JMX_AGENT_CONF="${CONF_DIR}/jmx-prometheus-agent.yaml"

# Activate the Prometheus JMX exporter
ENV PATH="${HOME_DIR}/bin:${PATH}"

#
# Update local packages and install required packages
#
RUN yum -y install \
        java-17-openjdk-devel \
        libaio \
        sudo \
        xmlstarlet \
    && \
    yum -y clean all && \
    mkdir -p "${HOME_DIR}" "${CONF_DIR}" && \
    curl -L -o "${JMX_AGENT_JAR}" "${JMX_SRC}"

#
# Install the remaining files
#
COPY jmx-prometheus-agent.yaml "${JMX_AGENT_CONF}"

#
# Create the required user/group
#
RUN groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"


COPY --from=builder /opt/keycloak/ /opt/keycloak/

RUN yum upgrade -y && \
    rm -rf /tmp/* && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" 

#
# Launch as the application's user
#
USER "${APP_USER}"
WORKDIR "${HOME_DIR}"

RUN mkdir -p /opt/keycloak/data/import

# Documentation on how to Export and Import realm.
# https://www.keycloak.org/server/importExport

# Example how to import custom realm
#
# Probably this should be moved to helm with realm file on bind mount
COPY realm.json /opt/keycloak/data/import

ENV KC_HEALTH_ENABLED="${KC_HEALTH_ENABLED}"
ENV KC_METRICS_ENABLED="${KC_METRICS_ENABLED}"

# Example how to set admin login / password 
ENV KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN}"
ENV KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
ENV IMPORT_DIR="${IMPORT_DIR}"

EXPOSE 8080

# realm import directory
VOLUME [ "${IMPORT_DIR}" ]

# jmx config directory
VOLUME [ "${CONF_DIR}" ]

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
