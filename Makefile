#!/usr/bin/make

SHELL = /bin/sh

CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

dev:
	docker run --rm -v ${PWD}:/blog -w /blog -p 1313:1313 klakegg/hugo:ext-ubuntu-onbuild server

new-post:
	docker run --rm -v ${PWD}:/blog -w /blog -u ${CURRENT_UID}:${CURRENT_GID} klakegg/hugo:ext-ubuntu-onbuild new posts/post.md
