#!/usr/bin/env bash

VIP=10.0.0.100
K3S_VERSION=v1.31.5+k3s1

k3sup join --ip 10.0.0.25 \
	--user ubuntu \
	--sudo \
	--server-ip $VIP \
	--k3s-version $K3S_VERSION

k3sup join --ip 10.0.0.26 \
	--user ubuntu \
	--server-ip $VIP \
	--k3s-version $K3S_VERSION

k3sup join --ip 10.0.0.27 \
	--user ubuntu \
	--server-ip $VIP \
	--k3s-version $K3S_VERSION
