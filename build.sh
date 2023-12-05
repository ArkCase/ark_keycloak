helm uninstall ingress
kubectl delete service/db
kubectl delete service/keycloak
kubectl delete pod/db
kubectl delete pod/keycloak
helm install ingress ingress/
kubectl create -f pod_postgres.yaml
kubectl expose pod/db

# Temporary until we get AWS Repositories in place
docker build -t nathanobert/ark_keycloak:latest .
docker push nathanobert/ark_keycloak:latest

kubectl wait --for=condition=ready pod -l app=db  --timeout=-1s
kubectl create -f pod_ark_keycloak.yaml
kubectl expose pod/keycloak

kubectl wait --for=condition=ready pod -l app=keycloak  --timeout=-1s
kubectl get pods
echo kubectl logs pod/keycloak
echo kubectl exec -it pod/keycloak -- bash
