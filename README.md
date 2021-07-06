#### Original readme below I dunno maybe I'll just leave it there in case it's important

#### BasiliskII
```
macOS     x86_64 JIT / arm64 non-JIT
Linux x86 x86_64 JIT
MinGW x86        JIT
```
#### SheepShaver
```
macOS     x86_64 JIT / arm64 non-JIT
Linux x86 x86_64 JIT
MinGW x86        JIT
```
### How To Build
These builds need to be installed SDL2.0.10+ framework/library.
#### BasiliskII
##### macOS
BasiliskII for macOS can be built with Apple Silicon Mac.

preparation:

Download gmp-6.2.1.tar.xz from https://gmplib.org.
```
$ cd ~/Downloads
$ tar xf gmp-6.2.1.tar.xz
$ cd gmp-6.2.1
$ ./configure --disable-shared
$ make
$ make check
$ sudo make install
```
Download mpfr-4.1.0.tar.xz from https://www.mpfr.org.
```
$ cd ~/Downloads
$ tar xf mpfr-4.1.0.tar.xz
$ cd mpfr-4.1.0
$ ./configure --disable-shared
$ make
$ make check
$ sudo make install
```
For Intel Mac, checkout `has_fpu_bug` branch. But it has FPU issue if the binary runs on Apple Silicon Mac.

1. Open BasiliskII/src/MacOSX/BasiliskII.xcodeproj
1. Set Build Configuration to Release
1. Build

or same as Linux (x86_64 only)

##### Linux(x86/x86_64)
```
$ cd macemu/BasiliskII/src/Unix
$ ./autogen.sh
$ make
```
##### MinGW32/MSYS2
```
$ cd macemu/BasiliskII/src/Windows
$ ../Unix/autogen.sh
$ make
```
#### SheepShaver
##### macOS
1. Open SheepShaver/src/MacOSX/SheepShaver_Xcode8.xcodeproj
1. Set Build Configuration to Release
1. Build

or same as Linux (x86_64 only)

##### Linux(x86/x86_64)
```
$ cd macemu/SheepShaver/src/Unix
$ ./autogen.sh
$ make
```
##### MinGW32/MSYS2
```
$ cd macemu/SheepShaver
$ make links
$ cd src/Windows
$ ../Unix/autogen.sh
$ make
```
### Recommended key bindings for gnome
https://github.com/kanjitalk755/macemu/blob/master/SheepShaver/doc/Linux/gnome_keybindings.txt

(from https://github.com/kanjitalk755/macemu/issues/59)
