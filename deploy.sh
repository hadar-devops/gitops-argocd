#!/bin/bash
set -e

echo "🔌 Connecting to EKS cluster..."
aws eks --region eu-central-1 update-kubeconfig --name hadar

echo "📦 Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=hadar \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId=vpc-0c9b1642c44ecf3ef \
  --set image.tag="v2.7.1"

echo "⏳ Waiting for AWS Load Balancer Controller webhook to become ready..."
until kubectl get endpoints aws-load-balancer-webhook-service -n kube-system -o jsonpath='{.subsets}' | grep -q "addresses"; do
  echo "🔄 Waiting for webhook service endpoint..."
  sleep 5
done

echo "📁 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for argocd-server deployment to be created..."
while ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; do
  echo "🔄 Waiting for argocd-server..."
  sleep 5
done

sleep 10

echo "⚙️ Configuring ArgoCD for HTTP only (insecure mode)..."
CMD=$(kubectl get deploy argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
ARGS=$(kubectl get deploy argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)

if [[ "$CMD" != '["argocd-server"]' || "$ARGS" != '["--insecure"]' ]]; then
  echo "🔧 Patching command and args..."
  kubectl patch deployment argocd-server -n argocd \
    --type='json' \
    -p='[
      {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["argocd-server"]},
      {"op":"replace","path":"/spec/template/spec/containers/0/args","value":["--insecure"]}
    ]' || {
      echo "⚠️ Fallback to 'add' operation..."
      kubectl patch deployment argocd-server -n argocd \
        --type='json' \
        -p='[
          {"op":"add","path":"/spec/template/spec/containers/0/command","value":["argocd-server"]},
          {"op":"add","path":"/spec/template/spec/containers/0/args","value":["--insecure"]}
        ]'
    }
else
  echo "✅ ArgoCD already patched with correct command/args."
fi

echo "🧼 Removing port 443 from argocd-server Service if needed..."
PORTS=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)

if echo "$PORTS" | grep -q 443; then
  echo "🧹 Removing port 443..."
  kubectl -n argocd patch service argocd-server \
    --type=json \
    -p='[{"op":"remove","path":"/spec/ports/1"}]'
else
  echo "✅ Port 443 already removed or does not exist."
fi

echo "🔁 Restarting argocd-server..."
kubectl rollout restart deployment argocd-server -n argocd

echo "⏳ Waiting for rollout to finish..."
kubectl rollout status deployment argocd-server -n argocd

echo "🌐 Creating Ingress for ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: z-argocd-ingress
  namespace: argocd
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/priority: "20"
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/success-codes: "200,307"
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF

echo "✅ Done! ArgoCD should be accessible via the ALB at the root path (/)."
