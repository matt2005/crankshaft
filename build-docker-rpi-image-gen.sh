#!/bin/bash -eu

# Crankshaft Docker Build Script using official Raspberry Pi rpi-image-gen
# This script builds Crankshaft images using the official rpi-image-gen

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DOCKER="docker"
CONTAINER_NAME="crankshaft-rpi-image-gen"

# Check Docker availability
if ! ${DOCKER} ps >/dev/null 2>&1; then
	DOCKER="sudo docker"
fi
if ! ${DOCKER} ps >/dev/null; then
	echo "error connecting to docker:"
	${DOCKER} ps
	exit 1
fi

# Configuration
CONFIG_FILE=""
if [ -f "${DIR}/config" ]; then
	CONFIG_FILE="${DIR}/config"
fi

# Parse command line options
while getopts "c:a:r:n:hv" flag
do
	case "${flag}" in
		c)
			CONFIG_FILE="${OPTARG}"
			;;
		a)
			TARGET_ARCH="${OPTARG}"
			;;
		r)
			DEBIAN_RELEASE="${OPTARG}"
			;;
		n)
			IMG_NAME="${OPTARG}"
			;;
		v)
			VERBOSE=1
			;;
		h)
			echo "Usage: $0 [options]"
			echo "Options:"
			echo "  -c FILE      Configuration file"
			echo "  -a ARCH      Target architecture (arm64, armhf)"
			echo "  -r RELEASE   Debian release (bookworm, bullseye)"
			echo "  -n NAME      Image name"
			echo "  -v           Verbose output"
			echo "  -h           Show help"
			echo ""
			echo "Examples:"
			echo "  $0 -c config -a arm64 -r bookworm"
			echo "  $0 -n my-crankshaft -a armhf"
			exit 0
			;;
		*)
			echo "Unknown option: -${flag}"
			echo "Use -h for help"
			exit 1
			;;
	esac
done

# Set defaults
TARGET_ARCH="${TARGET_ARCH:-arm64}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-bookworm}"

# Git information
GIT_HASH="${GIT_HASH:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
GIT_BRANCH="${GIT_BRANCH:-$(git branch --show-current 2>/dev/null || echo 'main')}"

echo "Building Crankshaft with official rpi-image-gen"
echo "=============================================="
echo "Architecture: ${TARGET_ARCH}"
echo "Debian Release: ${DEBIAN_RELEASE}"
echo "Git Hash: ${GIT_HASH}"
echo "Git Branch: ${GIT_BRANCH}"
echo ""

# Check if config file exists
if [ -n "${CONFIG_FILE}" ]; then
	if [ ! -f "${CONFIG_FILE}" ]; then
		echo "ERROR: Configuration file ${CONFIG_FILE} not found!"
		exit 1
	fi
fi

# Build the Docker image
echo "Building Docker image..."
if ! ${DOCKER} build -t crankshaft-rpi-image-gen "${DIR}"; then
	echo "ERROR: Failed to build Docker image"
	exit 1
fi

# Check if container already exists
CONTAINER_EXISTS=$(${DOCKER} ps -aq -f name="${CONTAINER_NAME}" || true)

if [ -n "${CONTAINER_EXISTS}" ]; then
	echo "Removing existing container ${CONTAINER_NAME}..."
	${DOCKER} rm -f "${CONTAINER_NAME}" || true
fi

# Prepare volume mounts
VOLUME_MOUNTS=""
if [ -n "${CONFIG_FILE}" ]; then
	VOLUME_MOUNTS="${VOLUME_MOUNTS} --volume ${CONFIG_FILE}:/workspace/config:ro"
fi

# Create work and deploy directories if they don't exist
mkdir -p "${DIR}/work" "${DIR}/deploy"

# Check for sufficient disk space (minimum 8GB)
AVAILABLE_SPACE=$(df "${DIR}" | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
if [ "${AVAILABLE_GB}" -lt 8 ]; then
	echo "WARNING: Low disk space (${AVAILABLE_GB}GB available, recommend 10GB+)"
	read -p "Continue anyway? (y/N): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi

# Run the build
echo "Starting containerized build..."

# Ensure binfmt_misc is available on host
echo "Setting up binfmt_misc support..."

# Check if binfmt_misc module is loaded
echo "Checking binfmt_misc kernel module..."
if ! lsmod | grep -q binfmt_misc 2>/dev/null; then
	echo "binfmt_misc module not loaded, attempting to load it..."
	sudo modprobe binfmt_misc 2>/dev/null || {
		echo "WARNING: Could not load binfmt_misc module"
		echo "This might be due to:"
		echo "  - Running in a container without module loading privileges"
		echo "  - Kernel without binfmt_misc support"
		echo "  - Security restrictions"
		echo "Will attempt to continue with Docker's built-in emulation support"
	}
else
	echo "binfmt_misc module already loaded"
fi

# First check if /proc/sys/fs exists (some containers might not have it)
if [ ! -d "/proc/sys/fs" ]; then
	echo "WARNING: /proc/sys/fs not available in this environment"
	echo "This might be a restricted container environment"
	echo "Cross-compilation support may be limited"
elif [ ! -d "/proc/sys/fs/binfmt_misc" ]; then
	echo "binfmt_misc filesystem not mounted, attempting to mount..."
	# Create the mount point if it doesn't exist
	sudo mkdir -p /proc/sys/fs/binfmt_misc 2>/dev/null || true
	sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || {
		echo "WARNING: Could not mount binfmt_misc filesystem"
		echo "This might be due to:"
		echo "  - Insufficient privileges"
		echo "  - Container restrictions"
		echo "  - Missing kernel support"
		echo "Will rely on Docker's privileged mode for cross-compilation"
	}
else
	echo "binfmt_misc filesystem already available"
fi

# Register QEMU binfmt handlers if not already done
echo "Registering QEMU binfmt handlers..."
if command -v docker >/dev/null 2>&1; then
	# Try the standard multiarch approach
	${DOCKER} run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || {
		echo "Standard QEMU registration failed, trying alternative approaches..."
		
		# Alternative 1: Try without --reset flag
		${DOCKER} run --rm --privileged multiarch/qemu-user-static -p yes 2>/dev/null || {
			echo "Alternative QEMU registration also failed"
			
			# Alternative 2: Try using docker buildx
			echo "Setting up Docker buildx for multi-arch support..."
			${DOCKER} buildx create --use --name multiarch --driver docker-container 2>/dev/null || true
			${DOCKER} buildx inspect --bootstrap 2>/dev/null || {
				echo "Docker buildx setup also failed"
				echo "Will rely on privileged container mode for emulation"
			}
		}
	}
	
	echo "QEMU setup completed (with potential fallbacks)"
else
	echo "Docker not available, skipping QEMU handler registration"
fi

# Note: We don't mount /proc/sys/fs/binfmt_misc in the container because:
# 1. Docker doesn't allow mounting inside /proc for security reasons
# 2. The privileged container inherits the host's QEMU emulation capabilities
# 3. The binfmt handlers registered above will be available to the container

# Verify binfmt registration
echo "Verifying binfmt registration..."
if [ -d "/proc/sys/fs/binfmt_misc" ]; then
	echo "Available binfmt interpreters:"
	ls -la /proc/sys/fs/binfmt_misc/ 2>/dev/null | head -10 || echo "Could not list binfmt interpreters"
	
	# Check for specific architecture support
	if [ "${TARGET_ARCH}" = "arm64" ] && [ -f "/proc/sys/fs/binfmt_misc/qemu-aarch64" ]; then
		echo "✓ ARM64 (aarch64) support detected"
	elif [ "${TARGET_ARCH}" = "armhf" ] && [ -f "/proc/sys/fs/binfmt_misc/qemu-arm" ]; then
		echo "✓ ARMHF (arm) support detected"
	else
		echo "⚠ Architecture-specific binfmt handler not found for ${TARGET_ARCH}"
		echo "This may cause cross-compilation to fail"
		echo "The build will attempt to continue using native tools where possible"
	fi
else
	echo "⚠ binfmt_misc not available"
	echo "Cross-compilation will be limited to native tools only"
fi

if [ "${VERBOSE:-0}" = "1" ]; then
	echo "Running with verbose output..."
	DOCKER_ARGS="--rm --privileged"
else
	DOCKER_ARGS="--rm --privileged"
fi

# Add additional debugging
echo "Docker command that will be executed:"
echo "${DOCKER} run ${DOCKER_ARGS} \\"
echo "  --name \"${CONTAINER_NAME}\" \\"
echo "  ${VOLUME_MOUNTS} \\"
echo "  --volume \"${DIR}/work\":/workspace/work \\"
echo "  --volume \"${DIR}/deploy\":/workspace/deploy \\"
echo "  -e \"TARGET_ARCH=${TARGET_ARCH}\" \\"
echo "  -e \"DEBIAN_RELEASE=${DEBIAN_RELEASE}\" \\"
echo "  -e \"IMG_NAME=${IMG_NAME:-crankshaft-ng}\" \\"
echo "  -e \"GIT_HASH=${GIT_HASH}\" \\"
echo "  -e \"GIT_BRANCH=${GIT_BRANCH}\" \\"
echo "  -e \"VERBOSE=${VERBOSE:-0}\" \\"
echo "  crankshaft-rpi-image-gen \\"
echo "  /workspace/build-rpi-image-gen.sh"
echo ""
echo "NOTE: binfmt_misc support is provided by the host system and QEMU registration above"
echo "The container inherits cross-compilation capabilities through privileged mode"
echo ""

if ! ${DOCKER} run ${DOCKER_ARGS} \
	--name "${CONTAINER_NAME}" \
	${VOLUME_MOUNTS} \
	--volume "${DIR}/work":/workspace/work \
	--volume "${DIR}/deploy":/workspace/deploy \
	-e "TARGET_ARCH=${TARGET_ARCH}" \
	-e "DEBIAN_RELEASE=${DEBIAN_RELEASE}" \
	-e "IMG_NAME=${IMG_NAME:-crankshaft-ng}" \
	-e "GIT_HASH=${GIT_HASH}" \
	-e "GIT_BRANCH=${GIT_BRANCH}" \
	-e "VERBOSE=${VERBOSE:-0}" \
	crankshaft-rpi-image-gen \
	/workspace/build-rpi-image-gen.sh; then
	
	echo "ERROR: Container execution failed"
	echo "Checking container logs..."
	${DOCKER} logs "${CONTAINER_NAME}" 2>/dev/null || echo "No container logs available"
	exit 1
fi

echo ""
echo "Build completed!"
echo "Images and artifacts are available in: ${DIR}/deploy"
ls -la "${DIR}/deploy/" 2>/dev/null || echo "Deploy directory not yet created"
