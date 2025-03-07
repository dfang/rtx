#!/usr/bin/env bash
set -euxo pipefail

git config --global user.name rtx-vm
git config --global user.email 123107610+rtx-vm@users.noreply.github.com

RTX_VERSION=$(cd rtx && ./scripts/get-version.sh)
RELEASE_DIR=releases
export RTX_VERSION RELEASE_DIR
rm -rf "${RELEASE_DIR:?}/$RTX_VERSION"
mkdir -p "$RELEASE_DIR/$RTX_VERSION"

#cp artifacts/tarball-x86_64-pc-windows-gnu/*.zip "$RELEASE_DIR/$RTX_VERSION"
#cp artifacts/tarball-x86_64-pc-windows-gnu/*.zip "$RELEASE_DIR/rtx-latest-windows.zip"

targets=(
	x86_64-unknown-linux-gnu
	aarch64-unknown-linux-gnu
	x86_64-apple-darwin
	aarch64-apple-darwin
)
for target in "${targets[@]}"; do
	cp "artifacts/tarball-$target/"*.tar.gz "$RELEASE_DIR/$RTX_VERSION"
	cp "artifacts/tarball-$target/"*.tar.xz "$RELEASE_DIR/$RTX_VERSION"
done

# these are already packaged into the deb/rpm
rm -rf "$RELEASE_DIR/$RTX_VERSION/rtx-brew-"*.gz
rm -rf "$RELEASE_DIR/$RTX_VERSION/rtx-deb-"*
rm -rf "$RELEASE_DIR/$RTX_VERSION/rtx-rpm-"*

platforms=(
	linux-x64
	linux-arm64
	macos-x64
	macos-arm64
)
for platform in "${platforms[@]}"; do
	cp "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform.tar.gz" "$RELEASE_DIR/rtx-latest-$platform.tar.gz"
	cp "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform.tar.xz" "$RELEASE_DIR/rtx-latest-$platform.tar.xz"
	tar -xvzf "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform.tar.gz"
	cp -v rtx/bin/rtx "$RELEASE_DIR/rtx-latest-$platform"
	cp -v rtx/bin/rtx "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform"
done

pushd "$RELEASE_DIR"
echo "$RTX_VERSION" | tr -d 'v' >VERSION
cp rtx-latest-linux-x64 rtx-latest-linux-amd64
cp rtx-latest-macos-x64 rtx-latest-macos-amd64
sha256sum ./rtx-latest-* >SHASUMS256.txt
sha512sum ./rtx-latest-* >SHASUMS512.txt
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS256.txt >SHASUMS256.asc
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS512.txt >SHASUMS512.asc
popd

pushd "$RELEASE_DIR/$RTX_VERSION"
sha256sum ./* >SHASUMS256.txt
sha512sum ./* >SHASUMS512.txt
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS256.txt >SHASUMS256.asc
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS512.txt >SHASUMS512.asc
popd

./rtx/scripts/render-install.sh >"$RELEASE_DIR"/install.sh
gpg -u 408B88DB29DDE9E0 --output "$RELEASE_DIR"/install.sh.sig --sign "$RELEASE_DIR"/install.sh

NPM_PREFIX=@jdxcode/rtx ./rtx/scripts/release-npm.sh
NPM_PREFIX=rtx-cli ./rtx/scripts/release-npm.sh
./rtx/scripts/publish-s3.sh

./rtx/scripts/render-homebrew.sh >homebrew-tap/rtx.rb
pushd homebrew-tap
git add . && git commit -m "rtx ${RTX_VERSION#v}"
popd

# we don't want to include these in the github release, only S3
rm -rf "$RELEASE_DIR/$RTX_VERSION/rtx-brew"*
