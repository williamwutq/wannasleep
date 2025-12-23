BUILD_DIR = -p builds --prefix-exe-dir .
DATE = $(shell date +%Y-%m-%d)
VERSION = 0.1.2
# Change this to include nightly on command line

version:
	@echo $(VERSION)-nightly-$(DATE)

build:
	@zig build -Doptimize=ReleaseSafe
	@zig build -Doptimize=ReleaseSafe $(BUILD_DIR)

debug:
	@zig build -Doptimize=Debug

release:
	@echo "Ensure to update src/root.zig build_version_detail before running this target."
	@zig build -Doptimize=ReleaseFast $(BUILD_DIR) -Dtarget=aarch64-linux -Dname=aarch64-linux-${VERSION}-release
	@zig build -Doptimize=ReleaseFast $(BUILD_DIR) -Dtarget=x86_64-linux -Dname=x86_64-linux-${VERSION}-release
	@zig build -Doptimize=ReleaseFast $(BUILD_DIR) -Dtarget=aarch64-macos -Dname=aarch64-macos-${VERSION}-release
	@zig build -Doptimize=ReleaseFast $(BUILD_DIR) -Dtarget=x86_64-macos -Dname=x86_64-macos-${VERSION}-release

nightly:
	@echo "Ensure to update src/root.zig build_version_detail before running this target."
	@zig build -Doptimize=Debug $(BUILD_DIR) -Dtarget=aarch64-linux -Dname=aarch64-linux-${VERSION}-nightly-$(DATE)-debug
	@zig build -Doptimize=Debug $(BUILD_DIR) -Dtarget=x86_64-linux -Dname=x86_64-linux-${VERSION}-nightly-$(DATE)-debug
	@zig build -Doptimize=Debug $(BUILD_DIR) -Dtarget=aarch64-macos -Dname=aarch64-macos-${VERSION}-nightly-$(DATE)-debug
	@zig build -Doptimize=Debug $(BUILD_DIR) -Dtarget=x86_64-macos -Dname=x86_64-macos-${VERSION}-nightly-$(DATE)-debug