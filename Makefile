IMAGE_TAG ?= latest

requirements:
	ansible-galaxy install -r requirements.yml

setup:
	ansible-playbook playbook.yml --tags setup

deploy:
	ansible-playbook playbook.yml --tags deploy -e "deploy_image_tag=$(IMAGE_TAG)"