.PHONY: build compile download inspect install lzc-build lzc-install lzc-install-gpu lzc-pre-publish push sync-clean sync-from-gpu sync-to-gpu test test2 voices

VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/projects/work/lzc-aipod-vibevoice
DOCKER_REGISTRY := registry.lazycat.cloud/x/lzc-aipod-vibevoice
DOCKER_NAME := lzc-aipod-vibevoice
ENV_PROXY := http://wa.lan:7890
ENV_NOPROXY := localhost,wa.lan,lzc-pod-APhKhy.lan,registry.lazycat.cloud

sync-from-gpu:
	rsync -arvzlt --delete --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --delete --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

prepare:
	git submodule update --init --recursive
	uv sync --all-groups
	uv pip compile --no-deps pyproject.toml -o requirements-pypi.txt

download:
	mkdir -p models
	source .venv/bin/activate && \
	HF_ENDPOINT=https://hf-mirror.com \
	hf download --local-dir ./models/WestZhang/VibeVoice-Large-pt WestZhang/VibeVoice-Large-pt

dev: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		export HTTP_PROXY=$(ENV_PROXY) && \
		export HTTPS_PROXY=$(ENV_PROXY) && \
		export ALL_PROXY=$(ENV_PROXY) && \
		export NO_PROXY=$(ENV_NOPROXY) && \
		$(UV) run python indextts/infer.py"

compile: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		export HTTP_PROXY=$(ENV_PROXY) && \
		export HTTPS_PROXY=$(ENV_PROXY) && \
		export ALL_PROXY=$(ENV_PROXY) && \
		export NO_PROXY=$(ENV_NOPROXY) && \
		echo $(UV) run py2so.py -d CosyVoice/webui && \
		echo $(UV) pip compile --no-deps pyproject.toml -o requirements-pypi.txt"
	$(MAKE) sync-from-gpu

build: compile
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
		--progress=plain \
		-f Dockerfile \
		-t $(DOCKER_REGISTRY):$(VERSION) \
		-t $(DOCKER_REGISTRY):latest \
		--network host \
		--build-arg "HTTP_PROXY=$(ENV_PROXY)" \
		--build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
		--build-arg "NO_PROXY=$(ENV_NOPROXY)" \
		."

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all \
		--name $(DOCKER_NAME) \
		--network host \
		-v ./output:/app/output \
		-e HF_HUB_OFFLINE=0 \
		-e HF_ENDPOINT=https://hf-mirror.com \
		-e HTTP_PROXY=$(ENV_PROXY) \
		-e HTTPS_PROXY=$(ENV_PROXY) \
		-e NO_PROXY=$(ENV_NOPROXY) \
		$(DOCKER_REGISTRY):$(VERSION)"

inspect: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION) bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		docker push $(DOCKER_REGISTRY):latest"

lzc-build:
	rm -rf content
	cd ui && pnpm run build
	mkdir -p content
	cp -r ui/dist/* content/
	lzc-cli project build

lzc-install: lzc-build
	lzc-cli app install ./dist/

lzc-install-gpu:
	rsync -arvzlt ./ai/docker-compose.yml $(REMOTE):~/docker-compose.yml.new
	ssh -t $(REMOTE) "mkdir -p /ssd/lzc-ai-agent/services/cloud.lazycat.aipod.vibevoice && \
		cd /ssd/lzc-ai-agent/services/cloud.lazycat.aipod.ttss && \
		sudo mv ~/docker-compose.yml.new docker-compose.yml && \
		sudo docker-compose down && \
		sudo docker-compose up -d && \
		sudo docker-compose logs -f"

lzc-pre-publish: lzc-build
	@echo 'lzc-cli appstore pre-publish --file changelog.md -G 9999 dist/'

voices:
	mkdir -p voices
	uv run mp32wav.py
