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
