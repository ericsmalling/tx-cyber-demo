#!/bin/bash
set -e


REPO_PROMPT="Enter the image repository name (DockerHub username or other registry) )"
if [[ -z "${REPO}" ]]; then
  read -p "${REPO_PROMPT}:" REPO_INPUT
else
  read -p "${REPO_PROMPT} [${REPO}]:" REPO_INPUT
fi
export REPO=${REPO_INPUT:-$REPO}

# if "build" passed as argument, build images
if [[ $1 == "build" ]]; then
  echo "Building and pushing docker images"

  #if depot is in PATH, use it, otherwise use docker
  if command -v depot >/dev/null 2>&1; then
    export IMAGE_BUILDER="depot build "
    export IMAGE_FLAGS=" --project 5024s98s0j --push"
  elif command -v docker >/dev/null 2>&1; then
    export IMAGE_BUILDER="docker build "
  else
    echo "ERROR: Neither docker nor depot client found, exiting"
    exit 1
  fi

  echo "  ${IMAGE_BUILDER}client found, will use it to build and push images"
  echo

  $IMAGE_BUILDER -t $REPO/thumbnailer:latest --platform=linux/amd64 thumbnailer $IMAGE_FLAGS
  $IMAGE_BUILDER -t $REPO/todolist:latest --platform=linux/amd64  todolist $IMAGE_FLAGS
  $IMAGE_BUILDER -t $REPO/log4shell-server:latest --platform=linux/amd64 todolist/exploits/log4shell-server $IMAGE_FLAGS

  if [[ $IMAGE_BUILDER == *"docker"* ]]; then
    docker push $REPO/thumbnailer:latest
    docker push $REPO/todolist:latest
    docker push $REPO/log4shell-server:latest
  fi
fi

echo "Deploying to kubernetes"
cat manifests/*.yaml | envsubst | kubectl apply -f -

echo "Waiting for deployments to be ready"
kubectl wait --for=condition=available --timeout=600s deployment/todolist -n todolist
kubectl wait --for=condition=available --timeout=600s deployment/thumbnailer -n todolist
ip=""
while [ -z $ip ]; do
  echo "Waiting for external IP"
  ip=$(kubectl get svc todolist -n todolist --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$ip" ] && sleep 10
done
echo "Application appears to up and running, open http://${ip}/todolist in your browser."
