.PHONY: all app cli install-app install-cli uninstall-cli clean

ARCH := $(shell uname -m)
CORE_SRCS := Sources/Core/AudioDeviceManager.swift \
             Sources/Core/RemoteHIDMonitor.swift \
             Sources/Core/MicRouterEngine.swift

all: app cli

app:
	@chmod +x scripts/build-app.sh
	@./scripts/build-app.sh

cli:
	@mkdir -p build
	@echo "==> Compiling mic-router CLI..."
	@swiftc -O -target $(ARCH)-apple-macos13.0 $(CORE_SRCS) Sources/CLI/main.swift -o build/mic-router
	@codesign --force --sign - --identifier com.microuter.cli build/mic-router
	@echo "==> Built: build/mic-router"

install-app: app
	@echo "==> Installing MicRouter.app to /Applications..."
	@rm -rf /Applications/MicRouter.app
	@cp -R build/MicRouter.app /Applications/MicRouter.app
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/MicRouter.app 2>/dev/null || true
	@echo "==> Installed: /Applications/MicRouter.app"

install-cli: cli
	@chmod +x scripts/install-launchagent.sh
	@./scripts/install-launchagent.sh

uninstall-cli:
	@chmod +x scripts/install-launchagent.sh
	@./scripts/install-launchagent.sh --uninstall

clean:
	@rm -rf build
