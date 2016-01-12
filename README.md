# Docker swarm on digitalocean

## Used components
The following components are included
* consul (progrium/consul)
* cadvisor (google/cadvisor)
* registrator (sourcestream/registrator) modified version to support the docker 1.9 network overlay
* logspout (progrium/logspout)
* kibanabox (sirile/kibanabox)
* sirile (sirile/minilogbox)
* prometheus (sourcestream/prometheus-sd) modified version of prometheus to use service discovery with DNS thru consul
* grafana (grafana/grafana)

## Usage
```bash
export digitalocean_token=[YOUR DIGITAL OCIAN TOKEN]
make all
```

## Connect to the swarm master
```bash
eval $(docker-machine env --swarm dev-swarm-master)
docker info
```
the output should look like
```bash
Containers: 11
Images: 10
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 3
 dev-swarm-master: 46.102.118.254:2376
  └ Status: Healthy
  └ Containers: 5
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.026 GiB
  └ Labels: com.docker.network.driver.overlay.bind_interface=eth1, environment=dev, executiondriver=native-0.2, kernelversion=3.16.0-4-amd64, node_name=dev-swarm-master, operatingsystem=Debian GNU/Linux 8 (jessie), provider=digitalocean, storagedriver=aufs
 dev-swarm-node-1: 46.102.255.101:2376
  └ Status: Healthy
  └ Containers: 3
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.026 GiB
  └ Labels: com.docker.network.driver.overlay.bind_interface=eth1, environment=dev, executiondriver=native-0.2, kernelversion=3.16.0-4-amd64, node_name=dev-swarm-node-1, operatingsystem=Debian GNU/Linux 8 (jessie), provider=digitalocean, storagedriver=aufs
 dev-swarm-node-2: 46.102.119.136:2376
  └ Status: Healthy
  └ Containers: 3
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.026 GiB
  └ Labels: com.docker.network.driver.overlay.bind_interface=eth1, environment=dev, executiondriver=native-0.2, kernelversion=3.16.0-4-amd64, node_name=dev-swarm-node-2, operatingsystem=Debian GNU/Linux 8 (jessie), provider=digitalocean, storagedriver=aufs
CPUs: 3
Total Memory: 3.078 GiB
Name: dev-swarm-master
```
