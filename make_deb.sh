#!/bin/bash

set -euxo pipefail

printf '#!/bin/bash\n\nprintf "%s\\n"' $(scripts/version | sed -e 's:-dirty::') >/tmp/jq/scripts/version
export VERSION=$(/tmp/jq/scripts/version | sed -e 's:\([0-9.]\)\(-[0-9]*\).*:\1+dfsg\2bn:')

cd /tmp/jq
sed -i -e '/^m4_define/s:git describe[^]]*:scripts/version:' configure.ac

cd /tmp
tar -cf jq_1.5+dfsg.orig.tar jq && bzip2 --fast jq_1.5+dfsg.orig.tar &
curl -fLRsSO http://archive.ubuntu.com/ubuntu/pool/universe/j/jq/jq_1.5+dfsg-1.debian.tar.xz
wait
tar -xaf jq*debian.tar* -C jq/

cd /tmp/jq
rm debian/patches/patch-version-into-build.patch && sed -i -e '/version-into-build/d' debian/patches/series
sed -i \
  -e "1i $(head -n 1 debian/changelog | sed -e 's:\(([^)]*)\):('$VERSION'):')\n\n  * See https://github.com/wmark/jq\n\n -- W. Mark Kubacki <wmark@hurrikane.de>  $(date --utc --rfc-2822)\n" \
  debian/changelog
sed -i \
  -e 's:libonig-dev:libonig-dev, libseccomp-dev:' \
  -e '/^Uploaders/d' \
  -e '/^Maintainer:/c\Maintainer: W-Mark Kubacki <wmark@hurrikane.de>' \
  debian/control

apt-get -y --no-install-recommends install $(dpkg-checkbuilddeps -a amd64 2>&1 | cut -f 4 -d ':' | sed -e 's:\(([^)]*)\)::g')
while read F; do patch -p1 --dry-run -i debian/patches/$F; done < <(cat debian/patches/series)
while read F; do patch -p1 -i debian/patches/$F; done < <(cat debian/patches/series)
env DEB_BUILD_OPTIONS="nocheck" dpkg-buildpackage -rfakeroot -b -d -j$(nproc) || true
# env DEB_BUILD_OPTIONS="nocheck parallel=$(proc)" debuild -uc -us
