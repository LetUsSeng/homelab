VENV := ansible-venv
BIN := $(VENV)/bin

.PHONY: venv ping check apply

venv:
	python3 -m venv $(VENV)
	$(BIN)/pip install -r requirements.txt

ping:
	$(BIN)/ansible proxmox -m ping

check:
	$(BIN)/ansible-playbook proxmox.yaml --check --diff

apply:
	$(BIN)/ansible-playbook proxmox.yaml --diff

apply-with-auth:
	infisical run --env=prod --path="/tailscale/auth" -- $(BIN)/ansible-playbook proxmox.yaml --diff

