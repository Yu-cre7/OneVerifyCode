APP_NAME := 一码
BUNDLE_ID := com.oneverifycode.app
VERSION := 0.5.3
BUILD := build
DIST := dist
APP := $(BUILD)/stage/$(APP_NAME).app

SRC := $(wildcard src/*.m)
CFLAGS := -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -Isrc
LDFLAGS := -framework Cocoa -framework ApplicationServices -framework QuartzCore -framework ServiceManagement -lsqlite3
ARCH_FLAGS := -arch x86_64 -arch arm64

.PHONY: all app icons test l10n-check run pkg dmg zip clean

all: app

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/OneVerifyCode: $(SRC) | $(BUILD)
	clang $(CFLAGS) $(ARCH_FLAGS) $(SRC) -o $@ $(LDFLAGS)

tools/icongen: tools/icongen.m src/OVCIconFactory.m src/OVCTheme.m src/OVCLocalization.m | $(BUILD)
	clang $(CFLAGS) -arch x86_64 tools/icongen.m src/OVCIconFactory.m src/OVCTheme.m src/OVCLocalization.m -o $@ $(LDFLAGS)

$(BUILD)/AppIcon.icns: tools/icongen
	mkdir -p $(BUILD)/AppIcon.iconset
	tools/icongen $(BUILD)/AppIcon.iconset
	iconutil -c icns $(BUILD)/AppIcon.iconset -o $@

icons: $(BUILD)/AppIcon.icns

$(APP): $(BUILD)/OneVerifyCode assets/Info.plist assets/en.lproj/Localizable.strings assets/GitHubMark.png $(BUILD)/AppIcon.icns
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp $(BUILD)/OneVerifyCode "$(APP)/Contents/MacOS/OneVerifyCode"
	cp assets/Info.plist "$(APP)/Contents/Info.plist"
	printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	cp $(BUILD)/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp -R assets/en.lproj "$(APP)/Contents/Resources/"
	cp assets/GitHubMark.png "$(APP)/Contents/Resources/GitHubMark.png"
	codesign --force --sign - --identifier $(BUNDLE_ID) "$(APP)"
	@echo "built $(APP)"

app: $(APP)

$(BUILD)/test_extractor: tests/test_extractor.m src/OVCCodeExtractor.m src/OVCTextDecoder.m | $(BUILD)
	clang $(CFLAGS) tests/test_extractor.m src/OVCCodeExtractor.m src/OVCTextDecoder.m -o $@ -framework Foundation

$(BUILD)/test_history: tests/test_history.m src/OVCHistoryStore.m | $(BUILD)
	clang $(CFLAGS) tests/test_history.m src/OVCHistoryStore.m -o $@ -framework Foundation

test: $(BUILD)/test_extractor $(BUILD)/test_history l10n-check
	$(BUILD)/test_extractor
	$(BUILD)/test_history

l10n-check:
	python3 tools/check_l10n.py

run: app
	open "$(APP)"

pkg: app
	python3 -c "import shutil; shutil.rmtree('$(BUILD)/pkgroot', True)"
	mkdir -p $(BUILD)/pkgroot/Applications $(DIST)
	ditto "$(APP)" "$(BUILD)/pkgroot/Applications/$(APP_NAME).app"
	pkgbuild --root $(BUILD)/pkgroot --component-plist assets/component.plist --identifier com.oneverifycode.pkg --version $(VERSION) --install-location / --ownership recommended $(BUILD)/OneVerifyCode-component.pkg
	productbuild --distribution assets/distribution.xml --package-path $(BUILD) "$(DIST)/OneVerifyCode-$(VERSION).pkg"
	@echo "pkg: $(DIST)/OneVerifyCode-$(VERSION).pkg"

dmg: app
	python3 -c "import shutil; shutil.rmtree('$(BUILD)/dmgroot', True)"
	mkdir -p $(BUILD)/dmgroot $(DIST)
	ditto "$(APP)" "$(BUILD)/dmgroot/$(APP_NAME).app"
	cp assets/dmg-install.txt "$(BUILD)/dmgroot/安装说明.txt"
	ln -s /Applications "$(BUILD)/dmgroot/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(BUILD)/dmgroot" -ov -format UDZO "$(DIST)/OneVerifyCode-$(VERSION).dmg"
	@echo "dmg: $(DIST)/OneVerifyCode-$(VERSION).dmg"

zip: app
	mkdir -p $(DIST)
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(DIST)/OneVerifyCode-$(VERSION)-beta.zip"

clean:
	python3 -c "import shutil; shutil.rmtree('$(BUILD)', True)"
