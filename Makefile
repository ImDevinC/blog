dev:
	docker run -v ${PWD}:/blog -w /blog -p 1313:1313 klakegg/hugo:ext-ubuntu-onbuild server

new-post:
	docker run -v ${PWD}:/blog -w /blog klakegg/hugo:ext-ubuntu-onbuild new posts/post.md