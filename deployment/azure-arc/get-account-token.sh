CLUSTER_NAME='k3s-95eada54-1'
RESOURCE_GROUP='arc-k8s-0713220958-95eada54'

kubectl create serviceaccount azureportal-user
kubectl create clusterrolebinding azureportal-user-binding --clusterrole cluster-admin --serviceaccount default:azureportal-user
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: azureportal-user-secret
  annotations:
    kubernetes.io/service-account.name: azureportal-user
type: kubernetes.io/service-account-token
EOF

TOKEN=$(kubectl get secret azureportal-user-secret -o jsonpath='{$.data.token}' | base64 -d | sed $'s/$/\\\n/g')
echo -e "$TOKEN\n\n"

az connectedk8s proxy -g $RESOURCE_GROUP -n $CLUSTER_NAME --token $TOKEN
