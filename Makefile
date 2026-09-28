# Phone builds that run without a debugger, so they keep working unplugged.
# F5 sessions start every isolate paused and hang once the phone is unplugged
# (see docs/DEBUG-VSCODE.md).
#
#   make install-prod               build and install Prod on the only phone
#   make install-prod DEVICE=<id>   choose a phone listed by `adb devices`

PUROFLUTTER := puro flutter
PROD_CONFIG := config/prod.local.json
PROD_APK := build/app/outputs/flutter-apk/app-prod-release.apk
PROD_PACKAGE := fr.gpix.gpix
ADB := adb $(if $(DEVICE),-s $(DEVICE))

.PHONY: help build-prod install-prod check-prod-config

help:
	@echo make install-prod [DEVICE=id]  Build Prod in release mode and install it, keeping app data
	@echo make build-prod                Build the Prod release APK only

check-prod-config:
ifeq ($(wildcard $(PROD_CONFIG)),)
	$(error Missing $(PROD_CONFIG): copy config/prod.example.json and set API_URL)
endif

build-prod: check-prod-config
	$(PUROFLUTTER) build apk --release --flavor prod --dart-define-from-file=$(PROD_CONFIG)

# -r replaces the installed app and keeps its data. The release build is signed
# with this computer's debug key, like F5 builds; a phone holding a build signed
# by another key refuses the update instead of losing its data.
install-prod: build-prod
	$(ADB) install -r $(PROD_APK)
	$(ADB) shell am start -n $(PROD_PACKAGE)/.MainActivity
