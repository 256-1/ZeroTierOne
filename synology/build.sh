#!/bin/bash

ZTO_VER=$(jq -r '.version' config.json)
PKG_REV=$(jq -r '.rev' config.json)
echo $ZTO_VER-$PKG_REV
ZTO_DESC=$(jq -r '.desc' config.json)
echo $ZTO_DESC
ZTO_EMAIL=$(jq -r '.email' config.json)
echo $ZTO_EMAIL
read -p "Confirm details [y/n] ? " -n 1 -r; echo; if [[ ! $REPLY =~ ^[Yy]$ ]]; then echo "Exiting."; exit; fi

build_environment()
{
  git clone https://github.com/SynoCommunity/spksrc.git
  sudo docker build --load -t zt-spksrc -f Dockerfile.spksrc .
}

generate_package_sources()
{
  # Clean up any intermediate files
  make -C spksrc clean
  rm -rf spksrc/distrib/*
  rm -rf spksrc/packages/*
  rm -rf spksrc/distrib/*source.tar.gz*

  # Generate the SPK

  # Copy package scripts to spksrc so they're accessible to container
  rm -rf spksrc/ztpkg-dsm6
  cp -rf ztpkg-dsm6 spksrc/ztpkg-dsm6

  TAB="$(printf '\t')"

  cd ..

  # Generate ZTO source tarball used by spksrc
  git ls-files -z | xargs -0 tar -czvf source.tar.gz
  mkdir -p synology/spksrc/distrib
  cp source.tar.gz synology/spksrc/distrib/source.tar.gz

  #
  # Set up (cross) directory contents
  #
  rm -rf spksrc/cross/*
  mkdir -p spksrc/cross/zerotier

cat > synology/spksrc/cross/zerotier/digests <<- EOM
source.tar.gz SHA1 $(sha1sum source.tar.gz | awk '{print $1}')
source.tar.gz SHA256 $(sha256sum source.tar.gz | awk '{print $1}')
source.tar.gz MD5 $(md5sum source.tar.gz | awk '{print $1}')
EOM

  cd -


  STAGING_DIR='$(STAGING_DIR)'
  RUN='$(RUN)'

cat > spksrc/cross/zerotier/Makefile <<- EOM
PKG_NAME = ZeroTierOne
PKG_VERS = $ZTO_VER
PKG_EXT = tar.gz
PKG_DIST_NAME = source.tar.gz
PKG_DIR =
PKG_DIST_SITE = http://localhost:8000
DEPENDS =
GNU_CONFIGURE = 1
CONFIGURE_ARGS = HAVE_CXX=yes

INSTALL_TARGET = zerotier_custom_install
CONFIGURE_TARGET = zerotier_custom_configure

ENV += ZT_SYNOLOGY=1

include ../../mk/spksrc.cross-cc.mk

.PHONY: zerotier_custom_install
zerotier_custom_install:
${TAB}$RUN mkdir -p $STAGING_DIR/bin
${TAB}$RUN cp zerotier-one $STAGING_DIR/bin/zerotier-one
EOM

cat > spksrc/cross/zerotier/PLIST <<- EOM
bin:bin/zerotier-one
EOM

  #
  # Set up (spk) directory contents
  #
  rm -rf spksrc/spk/*
  mkdir -p spksrc/spk/zerotier

  STAGING_DIR='$(STAGING_DIR)'
  WORK_DIR='$(WORK_DIR)'
  PRODUCT_DIR='$(PRODUCT_DIR)'

cat > spksrc/spk/zerotier/Makefile <<- EOM
SPK_NAME = zerotier
SPK_VERS = $ZTO_VER
SPK_REV = $PKG_REV
SPK_ICON = /spksrc/ztpkg-dsm6/PACKAGE_ICON_256.png
DEPENDS = cross/zerotier
MAINTAINER = ZeroTier, Inc.
DESCRIPTION = $ZTO_DESC
LICENSE  = BUSL-1.1
CHANGELOG =
HOMEPAGE = https://my.zerotier.com
REPORT_URL = https://github.com/zerotier/ZeroTierOne/issues
DISPLAY_NAME = ZeroTier
PRODUCT_DIR = $WORK_DIR

STARTABLE = yes
REQUIRED_DSM = 6.2.4

ENV += ZT_SYNOLOGY=1

SERVICE_SETUP = ../../ztpkg-dsm6/service-setup.sh
SSS_SCRIPT = ../../ztpkg-dsm6/start-stop-status.sh

PRE_STRIP_TARGET = zerotier_install

include ../../mk/spksrc.spk.mk

.PHONY: zerotier_install
zerotier_install:
${TAB}install -m 755 -d $STAGING_DIR/bin
${TAB}install -m 755 $PRODUCT_DIR/zerotier-one $STAGING_DIR/bin/zerotier-one
EOM

cat > spksrc/spk/zerotier/PLIST <<- EOM
bin:bin/zerotier-one
EOM
}

build()
{
  build_environment
  generate_package_sources
  sudo docker run -it -v $(pwd)/spksrc:/spksrc zt-spksrc /bin/bash
}

"$@"
