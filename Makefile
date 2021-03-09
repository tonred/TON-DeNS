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

deploy: deploy-contracts deploy-debot
	@echo "deploy-all"
	npm run migrate

deploy-contracts:
	@echo "deploy-contracts:"

deploy-debot:
	@echo "deploy-debot"

build: build-dns-root build-dns-cert build-dns-debot build-dns-auction build-dns-test build-dns-participant-storage
	@echo "build"

build-dns-root:
	@echo "build-dns-root"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_ROOT_CONTRACT))

build-dns-cert:
	@echo "build-dns-cert"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_NIC_CONTRACT))

build-dns-debot:
	@echo "build-dns-debot"
	$(call compile_all,$(DEBOT_PATH),$(DNS_DEBOT_CONTRACT))

build-dns-auction:
	@echo "build-dns-auction"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_AUCTION_CONTRACT))

build-dns-participant-storage:
	@echo "build-dns-participant-storage"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_PARTICIPANT_STORAGE_CONTRACT))


build-dns-test:
	@echo "build-dns-test"
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_DNS_ROOT_CONTRACT))
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_DNS_NIC_CONTRACT))
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_DNS_AUCTION_CONTRACT))
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_WALLET_CONTRACT))


tests:
	@echo "tests"
	npm run test

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
		  $(ARTIFACTS_PATH)/*.code \
		  $(ARTIFACTS_PATH)/Test*.*


define compile_all
	$(call compile_sol,$(1),$(2))
	$(call compile_tvm,$(2))
	$(call compile_client_code,$(ARTIFACTS_PATH)/$(2).sol)
	$(call tvc_to_base64,$(ARTIFACTS_PATH)/$(2))
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
