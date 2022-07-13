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
echo $TOKEN
