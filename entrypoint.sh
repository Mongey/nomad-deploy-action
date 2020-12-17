#!/bin/sh

set -euxo pipefail

readonly PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"

_changeSecurityGroupRule() {
    aws \
        --region "${AWS_REGION:-us-east-2}" \
        ec2 "$1-security-group-ingress" \
        --group-id "$AWS_SECURITY_GROUP" \
        --protocol tcp \
        --cidr "$PUBLIC_IP/32" \
        --port "${NOMAD_PORT:-4646}"
}

if [ -n "${AWS_SECURITY_GROUP:-}" ]; then
    _changeSecurityGroupRule authorize
    trap "_changeSecurityGroupRule revoke" INT TERM EXIT
fi

USE_LEVANT="${USE_LEVANT:-false}"
if [ "$USE_LEVANT" = "true" ]; then
  LEVANT_PROMOTE_TIME="${LEVANT_PROMOTE_TIME:-45}"
  LEVANT_VERSION="${LEVANT_VERSION:-0.2.8}"
  curl -L https://github.com/hashicorp/levant/releases/download/"$LEVANT_VERSION"/linux-amd64-levant -o levant && \
    chmod +x ./levant
  ./levant deploy -address="$NOMAD_ADDR" $LEVANT_OPTS "$NOMAD_JOB"
else
  curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && sudo apt-get install nomad
  nomad $NOMAD_ARGS
fi
