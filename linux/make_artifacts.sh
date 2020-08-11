set -e

MACHINE=$(uname -m)
case "$MACHINE" in
  x86_64) ARCHITECTURE=amd64;;
  i686)   ARCHITECTURE=i386;;
  i386)   ARCHITECTURE=i386;;
esac

ARTIFACTS="${ARTIFACTS:-/artifacts}"

# build binaries

cabal --version
ghc --version

cabal v2-update
cabal v2-clean
cabal v2-configure --enable-tests -f-export-dynamic -fstatic -fembed_data_files -fbibutils --enable-executable-static --ghc-options '-optc-Os -optl=-pthread -split-sections' . pandoc-citeproc
cabal v2-build . pandoc-citeproc
cabal v2-test -j1 . pandoc-citeproc
for f in $(find dist-newstyle -name 'pandoc*' -type f -perm /400); do cp $f /artifacts/; done

# make deb

VERSION=`$ARTIFACTS/pandoc --version | awk '{print $2; exit;}'`
REVISION=${REVISION:-1}
DEBVER=$VERSION-$REVISION
BASE=pandoc-$DEBVER-$ARCHITECTURE
DIST=`pwd`/$BASE
DEST=$DIST/usr
COPYRIGHT=$DEST/share/doc/pandoc/copyright

mkdir -p $DEST/bin
mkdir -p $DEST/share/man/man1
mkdir -p $DEST/share/doc/pandoc

mkdir -p $DEST/share/doc/pandoc-citeproc
find $DIST -type d | xargs chmod 755
cp $ARTIFACTS/pandoc $DEST/bin/
cp $ARTIFACTS/pandoc-citeproc $DEST/bin/
strip $DEST/bin/pandoc
strip $DEST/bin/pandoc-citeproc
cp /mnt/man/pandoc.1 $DEST/share/man/man1/pandoc.1
$ARTIFACTS/pandoc-citeproc --man > $DEST/share/man/man1/pandoc-citeproc.1
gzip -9 $DEST/share/man/man1/pandoc.1
gzip -9 $DEST/share/man/man1/pandoc-citeproc.1

cp /mnt/COPYRIGHT $COPYRIGHT
echo "" >> $COPYRIGHT
echo "pandoc-citeproc" >> $COPYRIGHT
$ARTIFACTS/pandoc-citeproc --license >> $COPYRIGHT

INSTALLED_SIZE=$(du -k -s $DEST | awk '{print $1}')
mkdir $DIST/DEBIAN
perl -pe "s/VERSION/$DEBVER/" linux/control.in | \
  perl -pe "s/ARCHITECTURE/$ARCHITECTURE/" | \
  perl -pe "s/INSTALLED_SIZE/$INSTALLED_SIZE/" \
  > $DIST/DEBIAN/control

fakeroot dpkg-deb -Zgzip -z4 --build $DIST
rm -rf $DIST
cp $BASE.deb $ARTIFACTS/

# Make tarball

TARGET=pandoc-$VERSION
cd $ARTIFACTS
rm -rf $TARGET
mkdir $TARGET
mkdir $TARGET/bin $TARGET/share $TARGET/share/man $TARGET/share/man/man1
./pandoc-citeproc --man > $TARGET/share/man/man1/pandoc-citeproc.1
cp /mnt/man/pandoc.1 $TARGET/share/man/man1
mv pandoc pandoc-citeproc $TARGET/bin
strip $TARGET/bin/pandoc
strip $TARGET/bin/pandoc-citeproc
gzip -9 $TARGET/share/man/man1/pandoc.1
gzip -9 $TARGET/share/man/man1/pandoc-citeproc.1

tar cvzf $TARGET-linux-amd64.tar.gz $TARGET
rm -r $TARGET