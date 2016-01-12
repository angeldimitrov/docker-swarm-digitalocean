digitalocean_image=debian-8-x64

driver_ops = --driver=digitalocean \
		--digitalocean-region=fra1 \
		--digitalocean-image=$(digitalocean_image) \
		--digitalocean-access-token=$(digitalocean_token) \
		--digitalocean-size=1gb \
		--digitalocean-private-networking=true

environment=dev
infra_node_name=$(environment)-infra
swarm_master_name=$(environment)-swarm-master
swarm_node_name=$(environment)-swarm-node
monitoring_overlay_network_name=service-monitoring
logging_overlay_network_name=service-logging

init-vars:
	$(eval infra_node_ip_private := $(shell docker-machine ssh $(infra_node_name) ip addr list eth1 |grep "inet " |cut -d' ' -f6|cut -d/ -f1))
	@echo infra_node_ip_private: $(infra_node_ip_private)
	$(eval infra_docker_config := $(shell docker-machine config $(infra_node_name)))
	@echo infra_docker_config: $(infra_docker_config)

init-swarm-master-vars:
	$(eval swarm_master_config := $(shell docker-machine config --swarm $(swarm_master_name)))
	$(eval smarm_master_ip_private := $(shell docker-machine ssh $(swarm_master_name) ip addr list eth1 |grep "inet " |cut -d' ' -f6|cut -d/ -f1))
	@echo smarm_master_ip_private: $(smarm_master_ip_private)

init-nodes-vars:
	$(eval smarm_nodes := $(shell docker-machine ls -q | grep $(swarm_node_name)))

create-infra:
	@printf "\e[33m*** \e create $(infra_node_name)... \e[33m***\e[0m\n"
	docker-machine create \
		$(driver_ops) \
		$(infra_node_name)

destroy-infra:
	docker-machine rm $(infra_node_name)

install-consul: init-vars
	@printf "\e[33m*** \e install service discovery - consul on $(infra_node_name)... \e[33m***\e[0m\n"
	docker $(infra_docker_config) run -d \
		-p 8500:8500 \
		-p $(infra_node_ip_private):53:53 \
		-p $(infra_node_ip_private):53:53/udp \
		-p $(infra_node_ip_private):8301:8301 \
		-p $(infra_node_ip_private):8301:8301/udp \
		-p $(infra_node_ip_private):8302:8302 \
		-p $(infra_node_ip_private):8302:8302/udp \
		-p $(infra_node_ip_private):8400:8400 \
		-h consul \
		--name consul \
		--restart always \
		progrium/consul -server -bootstrap -ui-dir /ui

create-master: init-vars install-consul
	@printf "\e[33m*** \e create swarm-master $(swarm_master_name)... \e[33m***\e[0m\n"
	docker-machine create \
		$(driver_ops) \
		--swarm \
		--swarm-master \
		--engine-label="environment=$(environment)" \
		--engine-label="com.docker.network.driver.overlay.bind_interface=eth1" \
		--engine-label="node_name=$(swarm_master_name)" \
		--swarm-discovery="consul://$(infra_node_ip_private):8500" \
		--engine-opt="cluster-store=consul://$(infra_node_ip_private):8500" \
		--engine-opt="cluster-advertise=eth1:2376" \
		$(swarm_master_name)

destroy-master:
	docker-machine rm $(swarm_master_name)

create-nodes: init-vars install-consul
	@for number in 1 2 ; do \
		printf "\e[33m*** \e create smarm node $(swarm_node_name)-$$number... \e[33m***\e[0m\n"; \
		docker-machine create \
			$(driver_ops) \
			--swarm \
			--engine-label="node_name=$(swarm_node_name)-$$number" \
			--engine-label="environment=$(environment)" \
			--engine-label="com.docker.network.driver.overlay.bind_interface=eth1" \
			--swarm-discovery="consul://$(infra_node_ip_private):8500" \
			--engine-opt="cluster-store=consul://$(infra_node_ip_private):8500" \
			--engine-opt="cluster-advertise=eth1:2376" \
			$(swarm_node_name)-$$number; \
	done

destroy-nodes:
	@for node_name in $(smarm_nodes); do \
		printf "### destorying $(node_name)..." \
		docker-machine rm $$(docker-machine config $$node_name); \
	done

create-overlay-network-logging: init-swarm-master-vars
	@printf "\e[33m*** \e create $(logging_overlay_network_name) overlay network \e[33m***\e[0m\n"
	docker $(swarm_master_config) network create -d overlay $(logging_overlay_network_name)

install-logging: init-nodes-vars init-swarm-master-vars create-overlay-network-logging
	@printf "\e[33m*** \e installing logstash and elasticsearch @ $(infra_node_name)... \e[33m***\e[0m\n"
	docker $(infra_docker_config) run -d \
		--name logbox \
		-h logbox \
		-p $(infra_node_ip_private):5000:5000/udp \
		-p $(infra_node_ip_private):9200:9200 \
		--restart=always \
		sirile/minilogbox
	@printf "\e[33m*** \e installing kibana @ $(infra_node_name)... \e[33m***\e[0m\n"
	docker $(infra_docker_config) run -d \
		-p $(infra_node_ip_private):5601:5601 \
		-h kibanabox \
		--name kibanabox \
		--restart=always \
		sirile/kibanabox http://$(infra_node_ip_private):9200
	@for node_name in $(smarm_nodes) $(swarm_master_name); do \
		printf "\e[33m*** \e installing logspout @ $$node_name ... \e[33m***\e[0m\n"; \
		docker $(swarm_master_config) run -d \
			--name logspout-$$node_name \
			--restart=always \
			-h logspout \
			--net=$(logging_overlay_network_name) \
			-e constraint:node_name==$$node_name \
			-v /var/run/docker.sock:/tmp/docker.sock \
			progrium/logspout syslog://$(infra_node_ip_private):5000; \
	done

create-overlay-network-monitoring: init-swarm-master-vars
	@printf "\e[33m*** \e create  $(monitoring_overlay_network_name) overlay network \e[33m***\e[0m\n"
	docker $(swarm_master_config) network create -d overlay $(monitoring_overlay_network_name)

install-monitoring: init-nodes-vars init-swarm-master-vars create-overlay-network-monitoring install-prometheus install-grafana
	@for node_name in $(smarm_nodes) $(swarm_master_name); do \
		printf "\e[33m*** \e  installing cadvisor @ $$node_name ... \e[33m***\e[0m\n"; \
		docker $(swarm_master_config) run -d \
			--name cadvisor-$$node_name \
			--restart=always \
			--volume=/:/rootfs:ro \
			--volume=/var/run:/var/run:rw \
			--volume=/sys:/sys:ro \
			--volume=/var/lib/docker/:/var/lib/docker:ro \
			--detach=true \
			-e SERVICE_NAME=monitoring \
			--net=$(monitoring_overlay_network_name) \
			-e constraint:node_name==$$node_name \
			google/cadvisor:latest; \
	done

install-registrator: init-vars init-nodes-vars init-swarm-master-vars
	@for node_name in $(smarm_nodes) $(swarm_master_name); do \
		printf "\e[33m*** \e installing registrator @ $$node_name ... \e[33m***\e[0m\n"; \
		docker $(swarm_master_config) run -d \
			-v /var/run/docker.sock:/tmp/docker.sock \
			--restart=always \
			--name registrator-$$node_name \
			--net=host \
			-e constraint:node_name==$$node_name \
			sourcestream/registrator -internal consul://$(infra_node_ip_private):8500; \
	done

install-prometheus: init-vars init-swarm-master-vars
	@printf "\e[33m*** \e installing prometheus @ $(swarm_master_name) ... \e[33m***\e[0m\n"; \
	docker $(swarm_master_config) run -d \
		-p $(smarm_master_ip_private):9090:9090 \
		--name prometheus \
		--restart=always \
		--net=$(monitoring_overlay_network_name) \
		-e SERVICE_NAME=prometheus \
		--dns $(infra_node_ip_private) \
		-e constraint:node_name==$(swarm_master_name) \
		sourcestream/prometheus-sd

remove-prometheus: init-vars init-swarm-master-vars
	docker rm -f prometheus
	docker rmi sourcestream/prometheus-sd

all: create-infra create-master create-nodes install-registrator install-logging install-monitoring
	docker-machine ls | grep $(environment)

display-admin-urls:
	@printf "\e[33m"
	@printf "consul      http://$infra_node_ip_private:8500/ \n"
	@printf "kibana      http://$infra_node_ip_private:5601/ \n"
	@printf "prometheus  http://$smarm_master_ip_private:9090/"
	@printf "grafana     http://$smarm_master_ip_private:3000/"
	@printf " \e[0m\n"

destroy-all: init-nodes-vars
	docker-machine rm $(smarm_nodes) $(infra_node_name) $(swarm_master_name)

install-grafana: init-swarm-master-vars
	docker $(swarm_master_config) run -d \
		-p $(smarm_master_ip_private):3000:3000 \
		--net=$(monitoring_overlay_network_name) \
		--name grafana \
		-e SERVICE_NAME=grafana \
		-e constraint:node_name==$(swarm_master_name) \
		grafana/grafana
