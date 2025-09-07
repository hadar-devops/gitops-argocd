# step 1: run the deploy.sh file after the cluster is up 
```bash
#change the vpc id
bash ./tmp_ingress/deploy.sh 
```
# step 2: for password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

username= admin
#ui great for sync and refresh 
```


# step 3: for deploy the app via argocd
```bash
kubectl apply -f weatherapp-app.yaml

```
# step 4: for validation
```bash 
kubectl get ingress -n deployapp
kubectl get pods -n deployapp
```

# step 5: running the pipeline
```bash 
#change the ip of node myvpc-agent to be the private ip of jenkins-agent instance
#run the pipeline 
```
# step 6: install in cluster applicationset-controller and crd's
```bash
kubectl get deployment -n argocd argocd-applicationset-controller

kubectl apply -f application-set.yaml
 #for port fowarding- but you can use the alb instead
kubectl port-forward service/dev-hadar-weatherapp 5000:5000 -n dev-hadar
```

# step 7: platform for creating and deleting environments
```bash
#-do clone from weather app deploy to a folder "platform_env" (there is already a folder weatherapp-deploy there so change it to numbers)
```