include .env

ifndef VERBOSE
.SILENT:
endif

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
	$(call compile_all,$(DNS_ROOT_CONTRACT))

build-dns-cert:
	@echo "build-dns-cert"
	$(call compile_all,$(DNS_NIC_CONTRACT))

build-dns-debot:
	@echo "build-dns-debot"

build-dns-auction:
	@echo "build-dns-auction"
	$(call compile_all,$(DNS_AUCTION_CONTRACT))


build-dns-test:
	@echo "build-dns-test"

tests:
	@echo "tests"

setup:
	@echo "setup"
	cp .env.dist .env

clean: clean-tmp
	rm -f $(ARTIFACTS_PATH)/*.tvc \
		  $(ARTIFACTS_PATH)/*.js \
		  $(ARTIFACTS_PATH)/*.base64

clean-tmp:
	rm -f $(ARTIFACTS_PATH)/*.sh \
		  $(ARTIFACTS_PATH)/*.result \
		  $(ARTIFACTS_PATH)/*.code


define compile_all
	$(call compile_sol,$(CONTRACTS_PATH),$(1))
	$(call compile_tvm,$(1))
	$(call compile_client_code,$(ARTIFACTS_PATH)/$(1).sol)
	$(call tvc_to_base64,$(ARTIFACTS_PATH)/$(1))
endef

define compile_sol
	$(SOLC_BIN) $(1)/$(2).sol
	mv $(1)/$(2).code $(ARTIFACTS_PATH)
	mv $(1)/$(2).abi.json $(ARTIFACTS_PATH)
endef

define compile_tvm
	$(TVM_LINKER_BIN) compile $(ARTIFACTS_PATH)/$(1).code \
							   --lib $(STDLIB_PATH) \
							   --abi-json $(ARTIFACTS_PATH)/$(1).abi.json \
							   -o $(ARTIFACTS_PATH)/$(1).tvc
endef

define compile_client_code
	node $(CLIENT_JS_COMPILER) $(1)
endef

define tvc_to_base64
	base64 $(1).tvc > $(1).base64
endef
