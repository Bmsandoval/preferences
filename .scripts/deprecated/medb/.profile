# source any bash scripts here
#export PATH="/home/sandman/.scripts/setup:${PATH}"
alias bashmedb="vim ~/.scripts/medb/.profile"

alias kubePodsByName="kubectl get pods --all-namespaces -o=jsonpath='{range .items[*]}{\"\n\"}{.metadata.name}{end}' |sort"
kubeFuzzyFindPod () {
	result=$(kubePodsByName | fzf)
	echo "${result}"
}

alias kubeCtxtByName="kubectl config get-contexts -o name"
kubeFuzzyFindCtxt () {
	result=$(kubeCtxtByName | fzf)
	echo "${result}"
}

alias kubeReleaseByName="helm ls -q"
kubeFuzzyFindRelease () {
	result=$(kubeReleaseByName | fzf)
	echo "${result}"
}

alias kubeCurrentContext="kubectl config current-context"

alias mdc="medic"
medic () {
   # if no command given force help page
   local OPTION
	if [[ "$1" != "" ]]; then
       OPTION=$1
   else
       OPTION="help"
   fi
	# handle input options
   case "${OPTION}" in
       'help')
echo "Usage: $ ${FUNCNAME} [option]

Options:
- help: show this menu
- start: Run minikube.sh
- stop: stop minikube
- port: forward ports for pod
- ssh: ssh into pod
- logs: show logs for pod
- kill: kills specified pod so it can rebuilt
- purge: purges helm release
- context: change context
- release: releasing current context
- desc: describe specified pod
- events: gets events for a specified pod
- status: get status of all pods [kubectl get pods -w]
- delete: delete a pod
"
       ;;
       "start")
			. ~/projects/k8s-cluster-management/scripts/minikube.sh
       ;;
       'stop')
			minikube stop
       ;;
		'purge')
			release=$(kubeFuzzyFindRelease)
			helm delete --purge "${release}"
			echo "helm delete --purge ${release}"
		;;
		'port')
			pod=$(kubeFuzzyFindPod)
			kubectl port-forward "${pod}" "${2}"
			echo "kubectl port-forward ${pod} ${2}"
		;;
		'ssh')
			pod=$(kubeFuzzyFindPod)
			kubectl exec "${pod}" -it /bin/sh
			echo "kubectl exec ${pod} -it /bin/sh"
		;;
		'logs')
			pod=$(kubeFuzzyFindPod)
			kubectl logs "${pod}" -f
			echo "kubectl logs ${pod} -f"
		;;
		'kill')
			pod=$(kubeFuzzyFindPod)
			kubectl exec -it "${pod}" -- killall main
			echo "kubectl exec -it ${pod} -- killall main"
		;;
		'context')
			context=$(kubeFuzzyFindCtxt)
			kubectl config use-context "${context}"
			echo "kubectl config use-context ${context}"
		;;
		'release')
		    if [[ "${2}" != "" ]]; then
               context=$(kubeCurrentContext)
               if [[ "${context}" == "minikube" ]]; then
                   cmdOptions=""
               elif [[ "${context}" == *"staging"* ]]; then
                   cmdOptions="-e staging"
               fi
               boatswain release "${2}" ${cmdOptions} --assume-yes
               echo "boatswain release "${2}" ${cmdOptions} --assume-yes"
           else
               echo -e "no release specified. please try...\n$ ${FUNCNAME} release odin"
           fi
		;;
		'desc')
			pod=$(kubeFuzzyFindPod)
			kubectl describe pod "${pod}"
			echo "kubectl describe pod ${pod}"
		;;
		'events')
			pod=$(kubeFuzzyFindPod)
			kubectl get events | grep "${pod}"
			echo "kubectl get events | grep "${pod}""
		;;
		'status')
			pod=$(kubeFuzzyFindPod)
			if [[ "${pod}" == "" ]]; then
               kubectl get pods -w
			else
               kubectl get pods -w | grep "${pod}"
           fi
		;;
		'delete')
			pod=$(kubeFuzzyFindPod)
			kubectl delete pod "${pod}"
			echo "kubectl get events | grep ${pod}"
		;;
       *)
           echo -e "ERROR: invalid option. Try..\n$ ${FUNCNAME} help"
       ;;
   esac
}

