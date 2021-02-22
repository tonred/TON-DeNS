ARTIFACTS_PATH = build-artifacts

help:
	@echo "build - compile all contracts"
	@echo "clean - clear build artifacts except ABI's"
	@echo "deploy-contracts - deploy DeNS contracts"
	@echo "deploy-debot - deploy DeBot contract"
	@echo "deploy - deploy all contracts"
	@echo "tests - test contracts"


deploy-all: deploy-contracts deploy-debot
	@echo "deploy-all"

deploy-contracts:
	@echo "deploy-contracts:"

deploy-debot:
	@echo "deploy-debot"

build: build-dns-root build-dns-cert build-dns-debot build-dns-auction build-dns-test
	@echo "build"

build-dns-root:
	@echo "build-dns-root"

build-dns-cert:
	@echo "build-dns-cert"

build-dns-debot:
	@echo "build-dns-debot"

build-dns-auction:
	@echo "build-dns-auction"

build-dns-test:
	@echo "build-dns-test"

tests:
	@echo "tests"

clean:
	@rm -f $(ARTIFACTS_PATH)/*.tvc $(ARTIFACTS_PATH)/*.js $(ARTIFACTS_PATH)/*.sh $(ARTIFACTS_PATH)/*.result


