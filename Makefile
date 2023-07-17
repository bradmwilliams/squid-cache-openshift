export CONTAINER_ENGINE ?= podman

all: image
.PHONY: all

image:
	$(CONTAINER_ENGINE) build -t squid -f Dockerfile .
.PHONY: image

