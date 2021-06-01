#!/bin/bash

set -e

ORANGE='\033[0;33m'
NC='\033[0m'
OPENSSL=${OPENSSL:-openssl}

# Generate CA certificate and key
#
# These commands do not work with LibreSSL which is shipped with MacOS. Please use openssl
#
if $OPENSSL version | grep -q LibreSSL; then
  echo -e "${ORANGE}Please do not use LibreSSL. Set OPENSSL variable to actual OpenSSL binary.${NC}"
  exit 1
fi

$OPENSSL genrsa -out rabbitmq-ca-key.pem 2048
$OPENSSL req -x509 -new -nodes -key rabbitmq-ca-key.pem -subj "/CN=mtls-inter-node" -days 3650 -reqexts v3_req -extensions v3_ca -out rabbitmq-ca.pem

echo -e "${ORANGE}Deploying Cert-manager & RabbitMQ cluster operator...${NC}"
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/download/v1.7.0/cluster-operator.yml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml
kubectl wait -n rabbitmq-system deployment/rabbitmq-cluster-operator --for=condition=Available --timeout=10m
kubectl wait -n cert-manager deployment/cert-manager --for=condition=Available --timeout=10m
kubectl wait -n cert-manager deployment/cert-manager-webhook --for=condition=Available --timeout=10m
kubectl wait -n cert-manager deployment/cert-manager-cainjector --for=condition=Available --timeout=10m

echo -e "${ORANGE}Creating TLS certificates${NC}"
kubectl create secret tls rabbitmq-ca -n default --cert=rabbitmq-ca.pem --key=rabbitmq-ca-key.pem
kubectl apply -f rabbitmq-ca.yaml
kubectl apply -f rabbitmq-certificate.yaml

echo -e "${ORANGE}Creating Erlang Distribution configmap${NC}"
kubectl create configmap mtls-inter-node-tls-config --from-file=inter_node_tls1_3.config --from-file=inter_node_tls1_2.config

echo -e "${ORANGE}Creating RabbitMQ clusters${NC}"
kubectl apply -f rabbitmq_1_2.yaml
kubectl apply -f rabbitmq_1_3.yaml
kubectl wait -f rabbitmq_1_2.yaml --for=condition=AllReplicasReady --timeout=10m
kubectl wait -f rabbitmq_1_3.yaml --for=condition=AllReplicasReady --timeout=10m

echo ""
echo -e "${ORANGE} Attempting to connect to clustering port on TLS v1.2 cluster${NC}"
kubectl exec -it mtls1-2-inter-node-server-0 -- bash -c 'openssl s_client -connect ${HOSTNAME}${K8S_HOSTNAME_SUFFIX}:25672 -state -cert /etc/rabbitmq/certs/tls.crt -key /etc/rabbitmq/certs/tls.key -CAfile /etc/rabbitmq/certs/ca.crt -tls1_2 2>&1'
echo ""
echo -e "${ORANGE}Attempting to connect to clustering port on TLS v1.3 cluster${NC}"
kubectl exec -it mtls1-3-inter-node-server-0 -- bash -c 'openssl s_client -connect ${HOSTNAME}${K8S_HOSTNAME_SUFFIX}:25672 -state -cert /etc/rabbitmq/certs/tls.crt -key /etc/rabbitmq/certs/tls.key -CAfile /etc/rabbitmq/certs/ca.crt -tls1_3 2>&1'
