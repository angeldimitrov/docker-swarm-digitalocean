# Docker swarm on digitalocean

## Used components
The following components are included
* consul (progrium/consul)
* cadvisor (google/cadvisor)
* registrator (sourcestream/registrator) modified version to support the docker 1.9 network overlay
* logspout (progrium/logspout)
* kibanabox (sirile/kibanabox)
* sirile (sirile/minilogbox)

## Usage
```bash
make all
```
