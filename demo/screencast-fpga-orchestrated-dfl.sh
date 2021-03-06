#!/bin/bash -e

PV='pv -qL'

command()
{
  speed=$2
  [ -z "$speed" ] && speed=10

  echo "> $1" | $PV $speed
  sh -c "$1"
  echo | $PV $speed
}

out()
{
  speed=$2
  [ -z "$speed" ] && speed=10

  echo "$1" | $PV $speed
  echo | $PV $speed
}

cleanup()
{
  clear
  out 'Cleanup demo artifacts' 20
  out 'delete test pod:' 20
  command 'kubectl delete pod test-fpga-region || true' 20
  out 'delete ServiceAccount:' 20
  command 'kubectl delete ServiceAccount intel-fpga-plugin-controller --namespace kube-system || true' 20
  out 'delete ClusterRole:' 20
  command 'kubectl delete ClusterRole node-getter --namespace kube-system || true' 20
  out 'delete ClusterRoleBinding:' 20
  command 'kubectl delete ClusterRoleBinding get-nodes --namespace kube-system || true' 20
  out 'delete node annotation:' 20
  command 'kubectl annotate node --all fpga.intel.com/device-plugin-mode- || true' 20
  out 'delete plugin daemonset:' 20
  command 'kubectl delete daemonset intel-fpga-plugin --namespace kube-system || true' 20
  out 'delete webhook deployment:' 20
  command 'kubectl delete deployment intel-fpga-webhook-deployment || true' 20
}

record()
{
  clear
  out 'Record this screencast'
  command 'asciinema rec -t "Intel FPGA Device Plugin for Kubernetes in orchestrated mode with DFL kernel driver."  Intel-FPGA-Device-Plugin-for-Kubernetes-orchestrated-DFL-Demo.cast -c "sh ./screencast-fpga-orchestrated-dfl.sh play"'
}

screen1()
{
  clear
  out 'This screencast demonstrates deployment of the Intel FPGA Plugin for Kubernetes in orchestrated mode with DFL kernel driver'
  out "Let's get started!"
  out '1. Check if Kubernetes node is in good shape:'
  command 'kubectl get nodes'
  command 'kubectl get pods --all-namespaces'
  out 'Check if CRI-O is running k8s pods:'
  command 'sudo crictl ps'
}

screen2()
{
  clear
  rm -rf $GOPATH/src/github.com/intel/intel-device-plugins-for-kubernetes
  out '2. Clone Intel Device Plugins for Kubernetes repository from github to the $GOPATH/src/github.com/intel directory'
  command "mkdir -p $GOPATH/src/github.com/intel/; cd $GOPATH/src/github.com/intel; git clone https://github.com/intel/intel-device-plugins-for-kubernetes" 15
}

screen3()
{
  clear
  cd $GOPATH/src/github.com/intel/intel-device-plugins-for-kubernetes
  out '3. Deploy admission controller webhook'
  command 'cd scripts ; ./webhook-deploy.sh --mode orchestrated; cd ../'
  sleep 2
  out 'Check if its pod is running:'
  command 'kubectl get pods | grep intel-fpga-webhook'
  out 'Check pod logs:'
  command "kubectl logs $(kubectl get pods | grep intel-fpga-webhook | awk '{print $1}')"
}

screen4()
{
  clear
  cd /srv/demo
  sudo rm -rf /srv/intel.com/fpga/Arria10.dcp1.2 /srv/intel.com/fpga/69528db6eb31577a8c3668f9faa081f6
  out '4. Create bistream storage'
  out 'Create directory for Arria10.dcp1.2 interface id:'
  command 'sudo mkdir -p /srv/intel.com/fpga/69528db6eb31577a8c3668f9faa081f6'
  out 'Create Arria10.dcp1.2 symlink for convenience:'
  command 'cd /srv/intel.com/fpga ; sudo ln -s 69528db6eb31577a8c3668f9faa081f6 Arria10.dcp1.2'
  out 'Add OPAE NLB0 and NLB3 bitstreams:'
  command "sudo cp -v f7*.gbs d8*.gbs /srv/intel.com/fpga/Arria10.dcp1.2/"
  out 'Create convenience symlinks:'
  command "cd /srv/intel.com/fpga/Arria10.dcp1.2 ; sudo ln -s d8*.gbs nlb0.gbs ; sudo ln -s f7*.gbs nlb3.gbs"
  out 'Directory content should look like this:'
  command 'ls -la /srv/intel.com/fpga/ | grep Arria10.dcp1.2'
  command 'ls -la /srv/intel.com/fpga/Arria10.dcp1.2/'
}

screen5()
{
  clear
  cd $GOPATH/src/github.com/intel/intel-device-plugins-for-kubernetes
  out '5. Deploy FPGA plugin'
  out 'Create a service account for the plugin'
  command 'kubectl create -f deployments/fpga_plugin/fpga_plugin_service_account.yaml'
  out 'Set region mode for the plugin:'
  command "kubectl annotate node --all 'fpga.intel.com/device-plugin-mode=region'"
  out 'Create plugin daemonset:'
  command 'kubectl create -f deployments/fpga_plugin/fpga_plugin.yaml'
  out 'Check if its pod is runnning:'
  command 'kubectl get pod --namespace kube-system |grep intel-fpga-plugin'
  out 'Check if it runs in 'region' mode:'
  command "kubectl logs $(kubectl  get pods --namespace kube-system |grep intel-fpga-plugin|cut -f1 -d' ') --namespace kube-system"
  out 'Check if resource fpga.intel.com/region-<FPGA interface id> is allocatable:'
  command 'kubectl describe node  |grep -A5 Allocatable'
}

screen6()
{
  clear
  cd $GOPATH/src/github.com/intel/intel-device-plugins-for-kubernetes
  out '6. Run OPAE workload that uses NLB3 bitstream'
  out 'Program devices with a bitstream that is not wanted by the workload:'
  command 'sudo /opt/intel/fpga-sw/fpgatool -b /srv/intel.com/fpga/Arria10.dcp1.2/nlb0.gbs -d /dev/dfl-port.0 pr'
  command 'sudo /opt/intel/fpga-sw/fpgatool -b /srv/intel.com/fpga/Arria10.dcp1.2/nlb0.gbs -d /dev/dfl-port.1 pr'
  out 'Check if devices are programmed with it:'
  command 'cat /sys/class/fpga_region/region0/dfl-port.0/afu_id'
  command 'cat /sys/class/fpga_region/region1/dfl-port.1/afu_id'
  out 'Run workload:'
  command 'kubectl create -f demo/test-fpga-region.yaml'
  sleep 5
  out 'Look at the test output'
  command 'kubectl logs test-fpga-region'
  out 'Check if orchestration reprogrammed one device with required(NLB3) bitstream:'
  command 'cat /sys/class/fpga_region/region0/dfl-port.0/afu_id'
  command 'cat /sys/class/fpga_region/region1/dfl-port.1/afu_id'
}

screen7()
{
  clear
  out 'Summary:' 15
  out "This screencast demonstrated 'Orchestration programmed' use case for FPGA:" 15
  out ' - FPGA device was programmed by the kubernetes machinery' 15
  out ' - desired bitstream resource was specified in the pod spec as fpga.intel.com/arria10.dcp1.2-nlb3' 15
  out ' - the machinery mapped arria10-nlb3 into the pair of region id/AFU id using admission controller webhook' 15
  out ' - programming was done by fpgatool utility installed by the init container into /opt/intel/fpga-sw' 15
  out
  out 'More detailed information about Intel Device Plugins can be found at https://github.com/intel/intel-device-plugins-for-kubernetes' 15
}

if [ "$1" == 'play' ] ; then
  if [ -n "$2" ] ; then
    screen$2
  else
    for n in $(seq 7) ; do screen$n ; sleep 3; done
  fi
elif [ "$1" == 'cleanup' ] ; then
  cleanup
elif [ "$1" == 'record' ] ; then
  record
else
   echo 'Usage: screencast-fpga-orchestrated-dfl.sh [--help|help|-h] | [play [<screen number>]] | [cleanup] | [record]'
fi
