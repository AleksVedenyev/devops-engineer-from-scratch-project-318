IMAGE_TAG ?= latest

requirements:
	ansible-galaxy install -r requirements.yml

setup:
	ansible-playbook playbook.yml --tags setup

deploy:
	ansible-playbook playbook.yml --tags deploy -e "deploy_image_tag=$(IMAGE_TAG)"

monitoring_setup:
	ansible-playbook playbook.yml --tags monitoring_setup

install-lint:
	pipx install ansible-lint

lint:
	ansible-lint

test:
	ansible all -m ping

smoke:
	@curl -f -s -o /dev/null http://aleks-devops.ru && echo "Приложение доступно!" || echo "Приложение недоступно!"
	@curl -f -s -o /dev/null http://153.51.117.166:3000 && echo "Grafana доступна!" || echo "Grafana недоступна!"
	@curl -f -s -o /dev/null http://153.51.117.166:9090 && echo "Prometheus доступен!" || echo "Prometheus недоступен!"
