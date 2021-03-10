include .env

ifndef VERBOSE
.SILENT:
endif

help:
	@echo "build - Compile all contracts"
	@echo "deploy - deploy all contracts"
	@echo "tests - test contracts"
	@echo "clean - clear build artifacts except ABI's"
	@echo "clean-tmp - clear temp build artifacts except tvc and ABI's"
	@echo "build-root - Compile DeNS root contract"
	@echo "build-cert - Compile DeNS NIC(Name Identity Certificate)"
	@echo "build-debot - Compile DeNS DeBot"
	@echo "build-auction - Compile DeNS Auction"
	@echo "build-participant-storage - Compile DeNS Participant storage"
	@echo "build-test - Compile DeNS Tests contracts"
	@echo "deploy-main - Deploy DeNS contracts needed for work"
	@echo "deploy-root - Deploy Root contract"
	@echo "deploy-debot - Deploy DeBot contract"
	@echo "deploy-tests - deploy Tests contract"

dev: build
	@echo "dev"
	npm run migrate
	make tests

start-debot:
	@echo "start-debot"
	/Users/pavel/Downloads/tonos-cli\ 3  debot fetch `cat migration-log.json | jq -r '.DeBotDeNS.address'`

deploy: deploy-main deploy-tests
	@echo "Deploying all contracts"

deploy-main: deploy-root deploy-debot deploy-tests
	@echo "Deploying contracts needed for work"

deploy-root:
	@echo "Deploying Root contract"
	node migration/1-deploy-DeNSRoot.js

deploy-debot:
	@echo "Deploying DeBot contract"
	node migration/2-deploy-DeNSDebot.js

deploy-tests:
	@echo "Deploying Tests contract"
	node migration/3-deploy-TestContracts.js

build: build-root build-cert build-debot build-auction build-test build-participant-storage
	@echo "Compiling all contracts"

build-root:
	@echo "Compiling DeNS Root"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_ROOT_CONTRACT))

build-cert:
	@echo "Compiling DeNS NIC"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_NIC_CONTRACT))

build-debot:
	@echo "Compiling DeNS DeBot"
	$(call compile_all,$(DEBOT_PATH),$(DNS_DEBOT_CONTRACT))

build-auction:
	@echo "Compiling DeNS Auction"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_AUCTION_CONTRACT))

build-participant-storage:
	@echo "Compiling DeNS Participant storage"
	$(call compile_all,$(CONTRACTS_PATH),$(DNS_PARTICIPANT_STORAGE_CONTRACT))

build-test:
	@echo "Compiling DeNS Tests"
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_DNS_ROOT_CONTRACT))
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_DNS_NIC_CONTRACT))
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_DNS_AUCTION_CONTRACT))
	$(call compile_all,$(TEST_CONTRACTS_PATH),$(TEST_WALLET_CONTRACT))

tests:
	@echo "Running tests"
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
	$(SOLC_BIN) $(1)/$(2).sol --tvm-optimize
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
