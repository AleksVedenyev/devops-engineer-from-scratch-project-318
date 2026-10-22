[![hexlet-check](https://github.com/AleksVedenyev/devops-engineer-from-scratch-project-315/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/AleksVedenyev/devops-engineer-from-scratch-project-315/actions)

# Доска объявлений (IaC)

Infrastructure-as-Code repository for the bulletin board application.

## Project link

The application repository is available here:

- https://github.com/AleksVedenyev/project-devops-deploy

## Description

This repository contains the infrastructure code used to provision and deploy the application:
- Ansible playbooks
- inventory
- group variables
- role and collection requirements
- deployment commands in `Makefile`

The application itself is containerized in the application fork, while this repository is responsible only for infrastructure and deployment.

## Requirements

- Ansible
- SSH access to the target server
- Vault password file for encrypted variables, if you use `group_vars/all/vault.yml`

## Ansible dependencies

Third-party roles and collections are listed in `requirements.yml`.

Install them with:

```bash
make requirements
```

## Server setup

Prepare the target server for deployment with:

```bash
make setup
```

This runs playbook.yml and installs Docker, Nginx, Certbot, configures the reverse proxy, and applies basic firewall rules.

## Deployment

The application is deployed with Ansible and can be started with:

```bash
make deploy
```

By default this deploys the latest image tag.

To deploy or roll back to a specific version, pass the immutable SHA-based tag published by CI:

```bash
make deploy IMAGE_TAG=<git-commit-sha>
```

## Vault password file

If your group_vars/all/vault.yml contains encrypted values, create a local vault password file in the project root:

```bash
echo "your-vault-password" > vault-password-file
chmod 600 vault-password-file
```

The file is ignored by git and is not committed to the repository.
