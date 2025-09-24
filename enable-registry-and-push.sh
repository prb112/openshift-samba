#!/bin/bash
# Script to enable the OpenShift image-registry and push a Samba image to it
# This script requires the 'oc' binary to be installed and the user to be logged in to OpenShift

set -e  # Exit immediately if a command exits with a non-zero status

# Define variables
PROJECT_NAME="samba-test"
IMAGE_NAME="samba"
IMAGE_TAG="latest"

echo "=== Checking OpenShift login status ==="
oc whoami || { echo "Error: Not logged into OpenShift. Please run 'oc login' first."; exit 1; }

echo "=== Creating project $PROJECT_NAME if it doesn't exist ==="
oc get project $PROJECT_NAME &>/dev/null || oc new-project $PROJECT_NAME

echo "=== Checking if the image-registry is enabled ==="
if ! oc get svc image-registry -n openshift-image-registry &>/dev/null; then
  echo "Image registry service not found. Enabling the image-registry..."
  
  # Enable the default registry
  oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"managementState":"Managed"}}' --type=merge
  
  # If storage is needed (for persistent registry)
  oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"storage":{"emptyDir":{}}}}' --type=merge
  
  # Wait for the registry to become available
  echo "Waiting for the image-registry to become available..."
  for i in {1..30}; do
    if oc get svc image-registry -n openshift-image-registry &>/dev/null; then
      echo "Image registry is now available."
      break
    fi
    echo "Waiting for image-registry to be created... ($i/30)"
    sleep 10
  done
  
  if ! oc get svc image-registry -n openshift-image-registry &>/dev/null; then
    echo "Error: Image registry service did not become available in time."
    exit 1
  fi
fi

# Get the registry route
echo "=== Setting up registry route ==="
if ! oc get route default-route -n openshift-image-registry &>/dev/null; then
  echo "Creating default route for the image-registry..."
  oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
  
  # Wait for the route to be created
  for i in {1..15}; do
    if oc get route default-route -n openshift-image-registry &>/dev/null; then
      break
    fi
    echo "Waiting for default-route to be created... ($i/15)"
    sleep 4
  done
fi

# Get the registry hostname
REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -z "$REGISTRY_HOST" ]; then
  echo "Using internal registry service..."
  REGISTRY_HOST="image-registry.openshift-image-registry.svc:5000"
fi

echo "Registry host: $REGISTRY_HOST"

# Build the image (using the appropriate Dockerfile)
echo "=== Building the Samba container image ==="
# Detect architecture and use appropriate Dockerfile
ARCH=$(uname -m)
DOCKERFILE="Dockerfile"

if [ "$ARCH" == "ppc64le" ]; then
  DOCKERFILE="Dockerfile.ppc64le"
elif [ "$ARCH" == "aarch64" ]; then
  DOCKERFILE="Dockerfile.aarch64"
elif [ "$ARCH" == "armv7l" ]; then
  DOCKERFILE="Dockerfile.armhf"
fi

echo "Using $DOCKERFILE for architecture $ARCH"
podman build -t $IMAGE_NAME:$IMAGE_TAG -f $DOCKERFILE .

# Get authentication token for the registry
echo "=== Getting authentication token for the registry ==="
TOKEN=$(oc whoami -t)

# Log in to the registry
echo "=== Logging in to the OpenShift registry ==="
podman login -u $(oc whoami) -p $TOKEN $REGISTRY_HOST --tls-verify=false

# Tag the image for the OpenShift registry
REGISTRY_IMAGE="$REGISTRY_HOST/$PROJECT_NAME/$IMAGE_NAME:$IMAGE_TAG"
echo "=== Tagging image as $REGISTRY_IMAGE ==="
podman tag $IMAGE_NAME:$IMAGE_TAG $REGISTRY_IMAGE

# Push the image to the registry
echo "=== Pushing image to OpenShift registry ==="
podman push --tls-verify=false $REGISTRY_IMAGE

# Verify the image exists in the registry
echo "=== Verifying image in registry ==="
oc get imagestream $IMAGE_NAME -n $PROJECT_NAME || {
  echo "ImageStream not found. Creating it..."
  oc import-image $IMAGE_NAME:$IMAGE_TAG --from=$REGISTRY_IMAGE --confirm -n $PROJECT_NAME
}

echo "=== Image successfully pushed to OpenShift registry ==="
echo "You can now use this image in your deployments with: $REGISTRY_IMAGE"
