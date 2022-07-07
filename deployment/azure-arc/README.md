# Deploying Apps to Azure Arc-enabled Kubernetes clusters

[Azure Arc-enabled Kubernetes](https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/overview) allows you to attach and configure Kubernetes clusters running anywhere. You can connect your clusters running on other public cloud providers (such as GCP or AWS) or clusters running on your on-premises data center (such as VMware vSphere or Azure Stack HCI) to Azure Arc.

When you connect a Kubernetes cluster to Azure Arc, it will:

- Be represented in Azure Resource Manager by a unique ID
- Be placed in an Azure subscription and resource group
- Receive tags just like any other Azure resource

Azure Arc-enabled Kubernetes supports industry-standard SSL to secure data in transit. For the connected clusters, cluster extensions, and custom locations, data at rest is stored encrypted in an Azure Cosmos DB database to ensure confidentiality.



## Using GitOps with Flux v2 with Azure Arc-enabled Kubernetes clusters

Managing infrastructure at scale has always been a challenge, specially when resources are spread geographically with different and unique environment constraints. [Azure Arc](https://docs.microsoft.com/en-us/azure/azure-arc/overview) helps with the visibility and governance of servers, databases and Kubernetes clusters. They appear in the Azure portal, collect metrics through Azure Monitor and are governed by Azure Policies, as if they were just another Azure resource.

Traditionally, CI/CD practices for containerized apps and microservices utilize a push philosophy: whenever there is a change in one of your applications, a new Docker image is built and pushed to a container registry, and the new image version is then pushed to Kubernetes either via manifests or charts like Helm. This model becomes too rigid when one is supposed to deploy the same application at scale, and that is what the GitOps paradigm aims to solve: GitOps treats each software or infrastructure component as one of more files in a version control system (Git, Bucket), with an automated process to syncrhonize state between the version control and the runtime environment. This is a radical change because it allows IT teams to use infrastructure-as-code (IaC) with the same version control processes that developers have used for decades, adding consistency and standardization to infrastructure management at scale. Since Kubernetes provide the concept of immutability and resource definition in a declarative way, it is much easier to put measures to prevent configuration drifts compared to traditional VM-based deployments. Tools like [Flux](https://fluxcd.io/docs/) and [Argo CD](https://argo-cd.readthedocs.io/en/stable/) run on this principle, establishing a single source of truth (a version control system) for all application and infrastructure deployments. Besides, they provide a pull method (as opposed to pushing a manifest or charts to a cluster), making it much easier to target multiple clusters regardless of their locations, just by connecting them to the version control system and pushing the resources declaration to it.

This repo will help you understand how you can deploy applications at scale using Azure Arc-enabled Kubernetes and Flux v2. The following steps define what is done by the deployment wizard:

1. It creates one or many Ubuntu Azure Virtual Machines in the same network address space

2. Installs the lightweight version of [Rancher K3s](https://k3s.io/) on each VM

3. Installs the Azure Arc-enabled Kubernetes agent on each cluster

4. Installs the following Microsoft Kubernetes extensions on each cluster: `Flux`, `Policy Insights`, `Azure Defender for Kubernetes`, `Azure Monitor for Containers`

5. Enables GitOps on each clusters

6. Creates a Flux configuration to manage NGINX Ingress controller as part of the clusters' infrastructure config

7. Creates a Flux configuration to manage a .NET Core Web App as part of the clusters' application config



> **NOTE**: This repository is a more compact version of the [Azure Arc Jumpstart](https://azurearcjumpstart.io/azure_jumpstart_arcbox/) project, which provides sandbox environments for IT Pros and Developer audiences. If you are looking for a broader approach to learning Azure Arc for Kubernetes, definitely check out the amazing work they have done and come back here when you want to focus more on the GitOps side of the story.



> **NOTE:** This repository does not bring into consideration how to manage on-prem Kubernetes clusters or which one to use. Azure Arc works with any Cloud Native Computing Foundation (CNCF) certified Kubernetes clusters.



### Architecture

the image below illustrates the resources that are deployed and how they are configured:

![Azure Arc-enabled Kubernetes architecture](../../docs/arc-k8s-architecture.png)



### Flux Configurations

Probably the most important part of GitOps, is having a clear structure and separation of what will be deployed to the clusters and how they have dependencies on each other. The image below shows the repository's folder structure that is relevant to Flux and what each component represents.



![Flux Configurations Hierarchy](../../docs/flux-extensions-hierarchy.png)



#### Kustomize

[Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) is a tool for customizing Kubernetes configurations by:

- Generating resources from other sources

- Setting cross-cutting fields for resources

- Composing and customizing collections of resources



You will notice that almost every folder contains a `kustomization.yaml` file in it, these files define which resources will be considered as part of the Kubernetes configuration and if any patching is required to apply a more specific configuration. Below is the content of `infrastructure/sources/kustomization.yaml`, notice that despite having other YAML files in the same, folder, only two are provided as resources. When Flux applies this configuration, only `ingress-nginx.yaml` and `webapp.yaml` will be considered.



```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cluster-config
resources:
  - ingress-nginx.yaml
  - webapp.yaml
```



##### Infrastructure

The `infrastructure` folder contains the definition of resources that are considered part of the "Kubernetes infrastructure" or cluster configuration, including the `sources`, `NGINX ingress resources` and each of the cluster's override parameters. Let's go over them one at a time:



##### sources

The `sources` folder contains the [HelmRepository](https://fluxcd.io/docs/components/source/helmrepositories/) objects that specify the location of a [Helm Chart](https://helm.sh/). Those charts can be located at an OCI Helm repository (like [like Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-image-formats#oci-images)) or an HTTP/HTTPS repository like Git (follow this great [article](https://medium.com/@mattiaperi/create-a-public-helm-chart-repository-with-github-pages-49b180dbb417) to create a public Helm chart repository with GitHub Pages and follow the [helm-package.yaml](../../.github/workflows/helm-package.yaml) workflow to learn how to package and index your Helm charts).



> **NOTE:** For secret repositories, your `HelmRepository` you must provide a [Secret reference](https://fluxcd.io/docs/components/source/helmrepositories/#secret-reference).



##### ingress-nginx

This folder contains the full chart for [NGINX Ingress Controller](https://github.com/kubernetes/ingress-nginx), a definition of the `Namespace` object where the controller will be created, and a definition of the `HelmRelease` to use. A [HelmRelease](https://fluxcd.io/docs/components/helm/helmreleases/) object defines a resource that will be reconciliated via Helm actions such as install, upgrade, test, uninstall and rollback. The `.spec` object requires the same parameters as the `helm install/upgrade` command: the target namespace to install the release, the repo location (in this case, referencing a `HelmRepository` object), and override values for the release if needed.



##### k3s-uniqueId-clusterIndex

> **NOTE:** These folders are not present in the `main` branch of the repo. They will be created during the deployment process that will be explained later in this document.



Since the ingress controller requires an IP address to listen to (provided in the `controller.service.externalIPs[]` parameter), every cluster in this sandbox deployment will require their own `HelmRelease` definition providing their private IP Address.

>  **IMPORTANT:** This is a very common scenario where certain configurations require unique parameters. The way the GitOps paradigm solves it is by separating the application code and release configurations in different repositories, and pushing the infrastructure and application releases to the release configuration repository as part of their CI/CD pipelines triggered by changes in the application code. This also creates security boundaries by not letting developer and IT teams tamper with the final state of the releases; they must commit their changes via their version control system which will be submitted for review via pull requests, and the CI process of CI/CD will have the necessary permissions to commit changes to the release configuration repository. For simplicity's sake, in this project "isolates" the release configuration for the ingress controller through a folder hierarchy by creating a folder for each k3s cluster and customizing its`values.yaml` file with the VM's private IP address.



##### apps/webapp

Finally, the `apps` folder contains the definitions of every app that will be deployed in the cluster. Once again, the `apps` folder contains a `kustomization.yaml` file that specifies which folders (or apps) will be deployed, regardless of what else exists in this folder.

Whe `webapp` folder provides a similar structure to `ingress-nginx` by specifying the `Namespace` to install the app in, and its `HelmRelease` object. In this case, the app to be deployed is a .NET Core Web App which code is in another location in this repo, but applying the same isolation principle explained above, the code and the release information for the app are two separate and independent concepts.



Now that you have a high level understanding of the key concepts and the structure of the repo, let's move on to deploying your Azure Arc environment.

## Prerequisites

- You can use a [Bash Azure Cloud Shell](https://shell.azure.com/bash),

- or you can run it locally on a Linux environment. In this case you need:
  
  - [Azure CLI]([How to install the Azure CLI | Microsoft Docs](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) v2.33.0 or later
  
  - The Json processor **jq**. Use your typical distribution package manager to install it (i.e., `sudo apt install jq` for Ubuntu and Debian)



## Getting Started

1. 
2. Once you are in your Azure Cloud Shell or your local Linux environment (see the prerequisites section above for more information), clone the repository:

```bash
git clone https://github.com/marvin-garcia/aks-playground.git
```

2. Run the AKS deployment script and follow the wizard instructions:

```bash
cd aks-playground
./deployment/aks/deploy.sh
```

3. Once the deployment script has completed, it will print the endpoint to test each application that has been deployed in the cluster. It will look like the output below:

```textile
http://aks-apps-123456.eastus.cloudapp.azure.com/carapi/cars
http://aks-apps-123456.eastus.cloudapp.azure.com/userapi/users/1
http://aks-apps-123456.eastus.cloudapp.azure.com/consoleapi/consoles/1
```
