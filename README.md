# TodoList Goof - One of Snyk's vulnerable demo app repos

Welcome to the Snyk "TodoList Goof" vulnerable demo application repo.
This repository contains a pair of purposefully vulnerable applications used for the purpose of demonstrating Snyk's capabilities in finding and fixing vulnerabilities in your dependencies and container images.

---
## WARNING! | ACHTUNG! | ¡PRECAUCIÓN! | !AVERTISSEMENT!
Many of the applications that are part of this repo are **highly dangerous**
and are purposely built with vulnerabilities! Please, **do not deploy these examples to
clusters that you don't want to have attacked!**

In other words, only deploy these to local/sandboxed clusters for the sole purpose of experimentation.
Examples of places you should **NOT** deploy this to:
* your developer servers
* your QA environment
* your company's cloud account

We take no responsibility for exploitation or damages caused by deploying anything from this
repository (or the associated container images) to your personal or organization's infrastructure (private or public).

## You have been warned!

---

### Contents
Applications included in this repo:
* [thumbnailer](thumbnailer) - Python application deployed in a container who's base image contains a vulnerable version of ImageMagick.
* [todolist](todolist) - Java JEE application with many vulnerable dependencies, including the Log4Shell vulnerability and an implementation of a malicous LDAP server for exploting it.

## Quick setup
Assuming you have cloned this repo to a machine with the following prerequisites, these steps will build and deploy the demonstration images to your Kubernetes cluster.

### Prerequisites
* A Kubernetes cluster running on amd64 (Intel) based nodes
* `kubectl` client installed configured for deploying to your cluster
* An image registry that can be resolved and reached by your Kubernetes cluster nodes (i.e. DockerHub, GAR, ECR, Harbor, etc)
* One of the following container image building tools, pre-configured to deploy to your image registry
  * [Docker](https://docker.com) runtime
  * [Depot.dev](https://depot.dev) client

### Build & Deploy
From the top level of this repo, run `./startup.sh build`
```bash
$ ./startup.sh build
Enter the image repository name (DockerHub username or other registry) ) [ericsmalling]:
Building and pushing docker images
...
Deploying to kubernetes
namespace/darkweb created
deployment.apps/log4shell created
service/ldap created
...
Waiting for deployments to be ready
deployment.apps/todolist condition met
deployment.apps/thumbnailer condition met
Waiting for external IP
Waiting for external IP
Application appears to up and running, open http://1.2.3.4/todolist in your browser.
```

## Teardown
When complete, the `./teardown.sh` script will delete all of the deployed assets in your Kubernetes cluster.
```bash
$ ./teardown.sh 
namespace "darkweb" deleted
namespace "todolist" deleted
```
Don't forget to also de-provision your cluster if you are no longer using it.