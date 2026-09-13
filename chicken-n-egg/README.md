# Chicken and Egg

There's no such things as true automation. I need to deal with the chicken and egg problem for before this becomes a snake eating it's tail problem.

## K3S

Order of install so I don't forgot what to do

- `bash +x ./k3s/first-server-node.sh`
- `helm upgrade --install kube-vip kube-vip/kube-vip -n kube-system -f ../gitops/kube-vip/values.yaml`
- `bash +x ./k3s/remaining-server-nodes.sh` 
- `bash +x ./k3s/remaining-agent-nodes.sh`

## TODOs
- TODO: wrapper the order in a Makefile
- TODO: clean up scripts
