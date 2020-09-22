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

sed "s/\[\[\.version\]\]/$DOCKER_TAG/" "$GITHUB_WORKSPACE/$NOMAD_JOB" | nomad job run -