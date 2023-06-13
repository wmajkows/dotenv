#!/usr/bin/env bash

set -xeo pipefail

rm -f ~/.kube/config

AKS_NAME=${AKS_NAME:-"aks-$INSTANCE_IDENTIFIER"} 
AKS_RG=${AKS_RG:-"rg-$INSTANCE_IDENTIFIER"}

PE_NAME=${PE_NAME:-"$AKS_NAME-kube-apiserver"}

ADMIN=${ADMIN:-true}

PRIVATE=${PRIVATE:-true}

export KUBECONFIG=${KUBECONFIG:-"$HOME/.kube/config"}

# set +x
# az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant 5d471751-9675-428d-917b-70f44f9630b0
# set -xeuo pipefail

test ! -z "$SUBSCRIPTION_NAME" && az account set --name "$SUBSCRIPTION_NAME"
test ! -z $SUBSCRIPTION_ID && az account set --subscription "$SUBSCRIPTION_ID"

if $ADMIN
then
  az aks get-credentials --name $AKS_NAME --resource-group $AKS_RG --admin -f $KUBECONFIG --overwrite-existing
else 
  az aks get-credentials --name $AKS_NAME --resource-group $AKS_RG -f $KUBECONFIG --overwrite-existing
fi

az account set --name "NHC AZURE CNS SaaS DEV C 1 outside"

if $PRIVATE
then
  export nic_id=$(az network private-endpoint list --query "[?name=='$PE_NAME' && resourceGroup=='vmssagents'].networkInterfaces[].id" -o tsv)
  export nic_name=$(basename $nic_id)
  export pe_ip=$(az network nic ip-config list --resource-group vmssagents --nic-name $nic_name --query "[].privateIpAddress" -o tsv)
  sed -ie '/certificate-authority-data/d' $KUBECONFIG
  yq e -i '.clusters[].cluster.insecure-skip-tls-verify  = true' $KUBECONFIG
  yq e -i ".clusters[].cluster.server = \"https://$pe_ip\"" $KUBECONFIG
fi

kubectl cluster-info

set +x
