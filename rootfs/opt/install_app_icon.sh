#!/bin/sh
#
# Helper script to generate and install favicons.
#
# Favicons are generated by `Real Favicon Generator`. See:
#   https://realfavicongenerator.net
#

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

WORKDIR=/tmp
ICONSDIR=/opt/novnc/images/icons

usage() {
    if [ -n "$*" ]; then
        echo "$*"
        echo
      fi

    echo "usage: $( basename $0 ) URL [DESC]

Generate and install favicons.

Arguments:
  URL   URL pointing to the master picture, in PNG format.  All favicons are
        generated from this picture.

Options:
  DESC  Favicons description in JSON format.  This is used by the generator and
        it describes what to generate and how.
"

    exit 1
}

install_build_dependencies_alpine() {
    apk --no-cache add --virtual build-dependencies curl nodejs jq sed
}

install_build_dependencies_debian() {
    BUILD_PACKAGES="curl ca-certificates jq nodejs"
    apt-get update
    apt-get install -y --no-install-recommends $BUILD_PACKAGES
}

install_build_dependencies() {
    if [ -n "$(which apk)" ]; then
        install_build_dependencies_alpine
    else
        install_build_dependencies_debian
    fi
}

uninstall_build_dependencies_alpine() {
  apk --no-cache del build-dependencies
}

uninstall_build_dependencies_debian() {
    apt-get clean
    apt-get purge -y $BUILD_PACKAGES
    apt-get --purge autoremove -y
    rm -rf /var/lib/apt/lists/* \
           /var/tmp/*
}

uninstall_build_dependencies() {
    if [ -n "$(which apk)" ]; then
        uninstall_build_dependencies_alpine
    else
        uninstall_build_dependencies_debian
    fi
}

cleanup() {
    rm -rf /tmp/*
    rm -rf $HOME/.npm
}

APP_ICON_URL="${1:-UNSET}"
APP_ICON_DESC=${2:-'{"masterPicture":"/opt/novnc/images/icons/master_icon.png","iconsPath":"/images/icons/","design":{"ios":{"pictureAspect":"backgroundAndMargin","backgroundColor":"#ffffff","margin":"14%","assets":{"ios6AndPriorIcons":false,"ios7AndLaterIcons":false,"precomposedIcons":false,"declareOnlyDefaultIcon":true}},"desktopBrowser":{},"windows":{"pictureAspect":"noChange","backgroundColor":"#2d89ef","onConflict":"override","assets":{"windows80Ie10Tile":false,"windows10Ie11EdgeTiles":{"small":false,"medium":true,"big":false,"rectangle":false}}},"androidChrome":{"pictureAspect":"noChange","themeColor":"#ffffff","manifest":{"display":"standalone","orientation":"notSet","onConflict":"override","declared":true},"assets":{"legacyIcon":false,"lowResolutionIcons":false}},"safariPinnedTab":{"pictureAspect":"silhouette","themeColor":"#5bbad5"}},"settings":{"scalingAlgorithm":"Mitchell","errorOnImageTooSmall":false},"versioning":{"paramName":"v","paramValue":"ICON_VERSION"}}'}

[ "$APP_ICON_URL" != "UNSET" ] || usage "Icon URL is missing."

cd $WORKDIR

echo "Installing dependencies..."
install_build_dependencies

# Reset any previously generated icons.
rm -rf $ICONSDIR
mkdir -p $ICONSDIR

# Download the master icon.
curl -sS -L -o "$ICONSDIR/master_icon.png" "$APP_ICON_URL"

# Create the description file.
echo "$APP_ICON_DESC" > faviconDescription.json
sed -i "s/ICON_VERSION/$(date | md5sum | cut -c1-10)/" faviconDescription.json

echo "Installing Real Favicon Generator..."
mkdir cli-real-favicon
cd cli-real-favicon
npm install --production https://github.com/RealFaviconGenerator/cli-real-favicon/archive/master.tar.gz
cd ..

echo "Generating favicons..." && \
./cli-real-favicon/node_modules/cli-real-favicon/real-favicon.js generate faviconDescription.json faviconData.json $ICONSDIR && \

echo "Adjusting HTML page..."
jq -r '.favicon.html_code' faviconData.json > htmlCode
sed -i -ne '/<!-- BEGIN Favicons -->/ {p; r htmlCode' -e ':a; n; /<!-- END Favicons -->/ {p; b}; ba}; p' /opt/novnc/index.vnc

npm uninstall cli-real-favicon

echo "Removing dependencies..."
uninstall_build_dependencies
cleanup
