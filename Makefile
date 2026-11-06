IMAGE_TAG ?= latest

requirements:
	ansible-galaxy install -r requirements.yml

setup:
	cd ansible && ansible-playbook playbook.yml --tags setup

deploy:
	cd ansible && ansible-playbook playbook.yml --tags deploy -e "deploy_image_tag=$(IMAGE_TAG)"

monitoring_setup:
	cd ansible && ansible-playbook playbook.yml --tags monitoring_setup

install-lint:
	pipx install ansible-lint

lint:
	cd ansible && ansible-lint playbook.yml

test:
	cd ansible && ansible all -m ping
	nc -vz aleks-devops.ru 80
	nc -vz aleks-devops.ru 443

smoke:
	@curl -f -s -o /dev/null https://aleks-devops.ru/actuator/health && echo "Приложение доступно!" || (echo "Приложение недоступно!" && exit 1)
	@curl -f -s -o /dev/null http://153.51.117.166:3000/api/health && echo "Grafana доступна!" || (echo "Grafana недоступна!" && exit 1)
	@curl -f -s -o /dev/null http://153.51.117.166:9090/-/ready && echo "Prometheus доступен!" || (echo "Prometheus недоступен!" && exit 1)
