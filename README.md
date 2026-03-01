### FAQ how to use run the nginx and kekinx charts with ArgoCD on a local Kubernetes cluster (e.g. kind, minikube)

```bash
# 1. Create a local Kubernetes cluster (e.g. kind, minikube)
kind create cluster --name argocd-demo

# 2. Install ArgoCD in the cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Install Argo Rollouts in the cluster
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# 4. Port-forward the ArgoCD API server to access the UI (or use Lens)
kubectl port-forward -n argocd svc/argocd-server 8080:443

# 5. Log in to the ArgoCD UI using the default admin password (the name of the argocd-server pod)
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# 6. Create ArgoCD applications for nginx and kekinx in the UI, pointing to the respective Helm charts in this repository

# 7. Sync the applications in ArgoCD to deploy nginx and kekinx to the cluster
```
