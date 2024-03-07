#!/usr/bin/env bash

NAMESPACE="test"
KAFKA_VERSION="3.5.0"
STRIMZI_VERSION="0.36.0"

if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  echo "Source this script, not execute it"; exit 1
fi

for x in kubectl yq; do
  if ! command -v "$x" &>/dev/null; then
    echo "Missing required utility: $x"; return 1
  fi
done

kubectl-kafka() { kubectl run kubectl-kafka-"$(date +%s)" -itq --rm --restart="Never" \
  --image="quay.io/strimzi/kafka:latest-kafka-$KAFKA_VERSION" -- sh -c "/opt/kafka/$*"; }

kubectl delete ns "$NAMESPACE" target --wait &>/dev/null
kubectl wait --for=delete ns/"$NAMESPACE" --timeout=120s &>/dev/null
kubectl create ns "$NAMESPACE"
kubectl config set-context --current --namespace="$NAMESPACE" &>/dev/null
curl -sL "https://github.com/strimzi/strimzi-kafka-operator/releases/download/$STRIMZI_VERSION/strimzi-cluster-operator-$STRIMZI_VERSION.yaml" \
  | sed -E "s/namespace: .*/namespace: $NAMESPACE/g" | kubectl create -f - --dry-run=client -o yaml | kubectl replace --force -f - &>/dev/null
echo "Done"
