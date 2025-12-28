#!/usr/bin/env bash
set -euo pipefail

# fast-cleanup.sh - small helper to remove stuck Helm jobs/releases and namespace finalizers
# Usage: fast-cleanup.sh [-n NAMESPACE] [-j JOB_NAME] [-r RELEASE_NAME] [--patch-finalizers]

NAMESPACE="mobileapp"
JOB_NAME="tigera-operator-uninstall"
RELEASE_NAME=""
PATCH_FINALIZERS=false
FORCE=false

print_usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -n NAMESPACE        Namespace to operate on (default: mobileapp)
  -j JOB_NAME         Kubernetes Job name to delete (default: tigera-operator-uninstall)
  -r RELEASE_NAME     Helm release name to uninstall (preferred over deleting job)
  --patch-finalizers  Remove namespace finalizers if namespace is stuck in Terminating
  -f                  Force deletion of resources (adds --grace-period=0 --force where applicable)
  -h                  Show this help

Examples:
  # Delete the known pre-delete hook job in the mobileapp namespace
  $0

  # Uninstall a Helm release and remove namespace finalizers
  $0 -n myns -r tigera -j tigera-operator-uninstall --patch-finalizers
EOF
}

# parse args
while [[ ${#} -gt 0 ]]; do
  case "$1" in
    -n)
      NAMESPACE="$2"; shift 2;;
    -j)
      JOB_NAME="$2"; shift 2;;
    -r)
      RELEASE_NAME="$2"; shift 2;;
    --patch-finalizers)
      PATCH_FINALIZERS=true; shift 1;;
    -f)
      FORCE=true; shift 1;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "Unknown arg: $1"; print_usage; exit 2;;
  esac
done

echo "Running fast-cleanup for namespace='$NAMESPACE' job='$JOB_NAME' release='$RELEASE_NAME' patch_finalizers=$PATCH_FINALIZERS force=$FORCE"

# If a helm release is specified, try to uninstall it first
if [[ -n "$RELEASE_NAME" ]]; then
  echo "Attempting helm uninstall $RELEASE_NAME -n $NAMESPACE"
  if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
  else
    echo "Helm release $RELEASE_NAME not found in namespace $NAMESPACE"
  fi
fi

# Delete the job if present
if kubectl get job "$JOB_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Deleting job $JOB_NAME in namespace $NAMESPACE"
  if [[ "$FORCE" = true ]]; then
    kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --grace-period=0 --force || true
  else
    kubectl delete job "$JOB_NAME" -n "$NAMESPACE" || true
  fi
else
  echo "Job $JOB_NAME not found in namespace $NAMESPACE"
fi

# Delete pods owned by the job (if any)
if kubectl get pods -n "$NAMESPACE" -l job-name="$JOB_NAME" >/dev/null 2>&1; then
  echo "Deleting pods with label job-name=$JOB_NAME in $NAMESPACE"
  if [[ "$FORCE" = true ]]; then
    kubectl delete pods -n "$NAMESPACE" -l job-name="$JOB_NAME" --grace-period=0 --force || true
  else
    kubectl delete pods -n "$NAMESPACE" -l job-name="$JOB_NAME" || true
  fi
fi

# If requested, remove finalizers from namespace to unstuck Terminating
if [[ "$PATCH_FINALIZERS" = true ]]; then
  state=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  echo "Namespace $NAMESPACE status: $state"
  if [[ "$state" = "Terminating" ]]; then
    echo "Patching namespace $NAMESPACE to remove finalizers"
    kubectl patch namespace "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge || true
  else
    echo "Namespace not Terminating; skipping finalizers patch"
  fi
fi

echo "Fast cleanup complete. Consider re-running 'terraform destroy' or retrying the operation that failed."
