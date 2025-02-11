#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is mostly the same as the 80-post-start.sh hook in the
#  pingdirectory product image, but configures sync failover rather than
#  configuring replication.
#
test "${VERBOSE}" = "true" && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=../../../../pingdatacommon/opt/staging/hooks/pingdata.lib.sh
. "${HOOKS_DIR}/pingdata.lib.sh"

# Check availability and set variables necessary for enabling failover
# If this method returns a non-zero exit code, then we shouldn't try
# to enable failover
if ! prepareToJoinTopology; then
    echo "Failover will not be configured."
    exit 0
fi

#
#- * Enabling PingDataSync failover
#
printf "
#############################################
# Enabling PingDataSync Failover
#
# Current Master Topology Instance: ${MASTER_TOPOLOGY_INSTANCE}
#
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Topology Master Server" "POD Server" "${MASTER_TOPOLOGY_HOSTNAME}:${MASTER_TOPOLOGY_LDAPS_PORT}" "${POD_HOSTNAME}:${POD_LDAPS_PORT:?}"

# manage-topology add-server does not currently support an admin password file - see DS-43027
# Read the value from file using get_value if necessary, or default to PING_IDENTITY_PASSWORD.
ADMIN_USER_PASSWORD="$(get_value ADMIN_USER_PASSWORD true)"
if test -z "${ADMIN_USER_PASSWORD}"; then
    ADMIN_USER_PASSWORD="${PING_IDENTITY_PASSWORD}"
fi

manage-topology add-server \
    --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
    --trustAll \
    --hostname "${MASTER_TOPOLOGY_HOSTNAME}" \
    --port "${MASTER_TOPOLOGY_LDAPS_PORT}" \
    --useSSL \
    --bindDN "${ROOT_USER_DN}" \
    --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --remoteServerHostname "${POD_HOSTNAME}" \
    --remoteServerPort "${POD_LDAPS_PORT}" \
    --remoteServerConnectionSecurity useSSL \
    --remoteServerBindDN "${ROOT_USER_DN}" \
    --remoteServerBindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
    --adminUID "${ADMIN_USER_NAME}" \
    --adminPassword "${ADMIN_USER_PASSWORD}" \
    --ignoreWarnings

_addServerResult=$?
echo "Failover configuration for POD Server result=${_addServerResult}"

if test ${_addServerResult} -ne 0; then
    echo "Failed to configure sync failover."
fi

exit ${_addServerResult}
