#!/bin/bash -e

# Crankshaft Stage 2 Pre-run Script
# This script sets up the environment for Crankshaft installation

# Source the main config and layer config
if [ -f "${BASE_DIR}/config" ]; then
    source "${BASE_DIR}/config"
fi

if [ -f "${LAYER_DIR}/layer.conf" ]; then
    source "${LAYER_DIR}/layer.conf"
fi

# Set stage-specific variables
STAGE_DIR="${LAYER_DIR}/stage2-crankshaft"
STAGE_WORK_DIR="${WORK_DIR}/stage2-crankshaft"

# Create work directory
mkdir -p "${STAGE_WORK_DIR}"

# Log the stage start
echo "Starting Crankshaft Stage 2 (${LAYER_VERSION})"
echo "Target architecture: ${TARGET_ARCH}"
echo "Debian release: ${DEBIAN_RELEASE}"
echo "Build type: ${CRANKSHAFT_BUILD_TYPE}"

# Export variables for use in stage scripts
export CRANKSHAFT_VERSION
export CRANKSHAFT_BUILD_TYPE
export TARGET_ARCH
export DEBIAN_RELEASE
export LAYER_DIR
export STAGE_DIR

# Set up logging
export CRANKSHAFT_LOG="${STAGE_WORK_DIR}/crankshaft.log"
echo "Crankshaft build started at $(date)" > "${CRANKSHAFT_LOG}"
