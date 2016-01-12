# Docker swarm on Digital Ocean


## Architecture overview
```bash
infra             swarm-master       swarm-node-1        swarm-node-2
+--------------+  +---------------+  +----------------+  +----------------+
| consul       |  | registrator   |  | registartor    |  | registartor    |   service discovery
+-------------------------------------------------------------------------------------------------
| minilogbox   |  |               |  |                |  |                |
| kibanabox    |  | logspout      |  | logspout       |  | logspout       |   logs aggregation
+------------------------------------------------------------------------------------------------- 
|              |  | grafana       |  |                |  |                |
|              |  | prometheus    |  |                |  |                |
|              |  | cadvisor      |  | cadvisor       |  | cadvisor       |   monitoring
+------------------------------------------------------------------------------------------------- 


```

## Requierements
* docker-machine https://docs.docker.com/machine/
* GNU make
* a Digital Ocean account 


## Used components
The following components will be installed
* consul (progrium/consul)
* cadvisor (google/cadvisor)
* registrator (sourcestream/registrator) modified version to support the docker 1.9 network overlay
* logspout (progrium/logspout)
* kibanabox (sirile/kibanabox)
* sirile (sirile/minilogbox)
* prometheus (sourcestream/prometheus-sd) modified version of prometheus to use service discovery with DNS through consul
* grafana (grafana/grafana)

## Usage
```bash
export digitalocean_token=[YOUR DIGITAL OCEAN TOKEN]
make all
```

After the script is done you will get a list with all admin urls:
```bash
consul      http://10.131.156.22:8500/
kibana      http://10.131.156.22:5601/
prometheus  http://10.131.180.190:9090/
grafana     http://10.131.180.190:3000/
to map those ports to your localhost run
make ssh-tunnels
```
However this are IPs from the private network of Digital Ocean and can not be accessed from outside. I use a reverse proxy with password protection, but you can also use a ssh tunnel for testing. You can automatically create a ssh tunnel to the UIs above using

```bash
make ssh-tunnels
```

This command will map all the ports on your localhost and print an output:

```bash
consul      http://localhost:8500/
kibana      http://localhost:5601/
prometheus  http://localhost:9090/
grafana     http://localhost:3000/
```
Now you can access the UIs in a secure way.
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

## Make sure all the services are running correctly
```bash
docker ps

CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS                                                     NAMES
6f6e2817f3b9        google/cadvisor:latest       "/usr/bin/cadvisor"      About an hour ago   Up About an hour    8080/tcp                                                  dev-swarm-master/cadvisor-dev-swarm-master
86d232d76994        google/cadvisor:latest       "/usr/bin/cadvisor"      About an hour ago   Up About an hour    8080/tcp                                                  dev-swarm-node-2/cadvisor-dev-swarm-node-2
8806ba459470        google/cadvisor:latest       "/usr/bin/cadvisor"      About an hour ago   Up About an hour    8080/tcp                                                  dev-swarm-node-1/cadvisor-dev-swarm-node-1
aa55eb734e81        grafana/grafana              "/usr/sbin/grafana-se"   About an hour ago   Up About an hour    10.135.180.190:3000->3000/tcp, 127.0.0.1:3000->3000/tcp   dev-swarm-master/grafana
e9cf7a4901c8        sourcestream/prometheus-sd   "/bin/prometheus -con"   About an hour ago   Up About an hour    127.0.0.1:9090->9090/tcp, 10.135.180.190:9090->9090/tcp   dev-swarm-master/prometheus
0cf24ced7533        progrium/logspout            "/bin/logspout syslog"   About an hour ago   Up About an hour    8000/tcp                                                  dev-swarm-master/logspout-dev-swarm-master
c10c54fa77d9        progrium/logspout            "/bin/logspout syslog"   About an hour ago   Up About an hour    8000/tcp                                                  dev-swarm-node-2/logspout-dev-swarm-node-2
afb99afe86c0        progrium/logspout            "/bin/logspout syslog"   About an hour ago   Up About an hour    8000/tcp                                                  dev-swarm-node-1/logspout-dev-swarm-node-1
2a0df7e903db        sourcestream/registrator     "/bin/registrator -in"   About an hour ago   Up About an hour                                                              dev-swarm-master/registrator-dev-swarm-master
8418bf9985f7        sourcestream/registrator     "/bin/registrator -in"   About an hour ago   Up About an hour                                                              dev-swarm-node-2/registrator-dev-swarm-node-2
6989ead0d4b2        sourcestream/registrator     "/bin/registrator -in"   About an hour ago   Up About an hour                                                              dev-swarm-node-1/registrator-dev-swarm-node-1

```

## TODO
* remove the infra node and move the consul, kibanabox and minilogbox inside of the swarm
