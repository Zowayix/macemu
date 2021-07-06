mkdir -p build

pushd BasiliskII/src/Unix
NO_CONFIGURE=1 ./autogen.sh
#might want --with-libvhd or --with-vdeplug? Just need to make sure that doesn't break anything
#JIT requires addressing=direct, do I care about that… no
./configure --enable-standalone-gui --with-bincue # --enable-addressing=banks --disable-jit
make -j`nproc`
cp BasiliskII BasiliskIIGUI ../../../build
popd

pushd SheepShaver/src/Unix
NO_CONFIGURE=1 ./autogen.sh
#--with-bincue broke last time I tried it, should do that again
./configure --enable-standalone-gui --enable-addressing=direct
make -j`nproc`
cp SheepShaver SheepShaverGUI ../../../build

popd
