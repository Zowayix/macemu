Fork aimed at adding usability features for gaming, maybe I will succeed at that, maybe I will abandon it like many other projects

Current status:
- Allow changing the emulated screen resolution without messing with the host (very handy for games that want you to switch resolutions), even resolutions bigger than your screen
- SDL joystick:
	- Assumes you even want to do that
	- Assumes joystick index 0
	- Assumes the following mapping, which is handy for running most games (most have configurable controls anyway, but with a layout that would be sensible for keyboard as well) with an Xbox 360 controller or anything that acts like one:
```
		0 (A) -> space
		1 (B) -> left ctrl
		2 (X) -> left alt
		3 (Y) -> left command
		4 (LB) -> left shift
		5 (RB) -> /
		6 (Select/back/whatever it's called these days) -> esc
		7 (Start) -> return
		Hat 0 (dpad) (also buttons 13 to 16, as the DualShock 3 does that instead of a hat) -> arrow keys
```

Stuff to do:
- Options for joystick stuff
	- `joystick_enable`, don't try and init SDL with `SDL_INIT_JOYSTICK`  
	- `joystick_index` - it could be cool or useful to have multiple joysticks, though (shared screen 2-player games which both use the keyboard exist on classic Mac) but then we might have to refactor the code to open multiple joysticks I guess  
	- Suppose until I learn C more to know more about what I'm actually doing, could just have a `joystick_player2_index`  
	- `joystick_mapping_file` - Override the mappings for joystick button/hat to Mac keycode, or leave it blank and use what we currently have as default  
- Handle `SDL_JOYSTICKADDED` event, open a joystick if event.jdevice.which is an index we want and joystick is currently null
- Handle `SDL_JOYSTICKREMOVED` event, close joystick if it is not currently null if event.jdevice.which == the instance ID (we need to get this upon opening)
- Control arrow keys with a joystick axis
- Control mouse with a joystick axis
	- Hmm if mouse is grabbed (which it is in fullscreen) then mouse movement is relative, so that may require keeping track of stuff
- Option to use SDL gamepad instead of a joystick
- Make sure we can change which monitor it should fullscreen to

Stuff that I'm not sure is even possible:
- On screen keyboard?

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
