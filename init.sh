#!/usr/bin/env bash
# Source this file to configure the environment.

INIT_NAMESPACE="test"
INIT_KAFKA_VERSION="3.5.0"
INIT_STRIMZI_VERSION="0.36.0"

for x in kubectl yq; do
  if ! command -v "$x" &>/dev/null; then
    echo "Missing required utility: $x" && return 1
  fi
done

kubectl-kafka() { kubectl run kubectl-kafka-"$(date +%s)" -itq --rm --restart="Never" \
  --image="quay.io/strimzi/kafka:latest-kafka-$INIT_KAFKA_VERSION" -- sh -c "$*; exit 0"; }

kubectl delete ns "$INIT_NAMESPACE" target --wait &>/dev/null
kubectl wait --for=delete ns/"$INIT_NAMESPACE" --timeout=120s &>/dev/null
kubectl -n "$INIT_OPERATOR_NS" delete pv -l "app=retain-patch" &>/dev/null
kubectl create ns "$INIT_NAMESPACE"
kubectl config set-context --current --namespace="$INIT_NAMESPACE" &>/dev/null
curl -sL "https://github.com/strimzi/strimzi-kafka-operator/releases/download/$INIT_STRIMZI_VERSION/strimzi-cluster-operator-$INIT_STRIMZI_VERSION.yaml" \
  | sed -E "s/namespace: .*/namespace: $INIT_NAMESPACE/g" | kubectl create -f - --dry-run=client -o yaml | kubectl replace --force -f - &>/dev/null
echo "Done"
