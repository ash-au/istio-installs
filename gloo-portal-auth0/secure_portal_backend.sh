#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

# PortalGroup define what APIs a group of users can view in the portal, and what usage plans they can manage API keys for
# Here is an example of a PortalGroup that defines a group of users that can view the API (RouteTables) with portal-users: true label and manage API keys for gold usage plan. A user is considered to be a member of this group if they have claims that match all claims in Membership criteria
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: PortalGroup
metadata:
  name: portal-users
  namespace: gloo-mesh-addons
spec:
  name: portal-users
  description: a group for users accessing the customers APIs
  membership:
    - claims:
        - key: group
          value: users
  accessLevel:
    apis:
    - labels:
        portal-users: "true"
    usagePlans:
    - gold
EOF

# Based on the above Portal Group, users with claim (group: users) will have access to APIs with label (portal-users: true)