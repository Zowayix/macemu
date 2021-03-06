/*
 *  $Id$
 *
 *  main_macosx.mm -	Startup code for MacOS X
 *						Based (in a small way) on the default main.m,
						and on Basilisk's main_unix.cpp
 *
 *  Basilisk II (C) 1997-2008 Christian Bauer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <AppKit/AppKit.h>
#undef check

#define PTHREADS	// Why is this here?
#include "sysdeps.h"

#ifdef HAVE_PTHREADS
# include <pthread.h>
#endif

#if DIRECT_ADDRESSING
# include <sys/mman.h>
#endif

#include <string>
using std::string;

#include "sys.h"
#include "rom_patches.h"
#include "xpram.h"
#include "video.h"
#include "prefs.h"
#include "prefs_editor.h"
#include "macos_util_macosx.h"
#include "user_strings.h"
#include "version.h"
#include "main.h"
#include "sigsegv.h"

#if USE_JIT
extern void flush_icache_range(uint8 *start, uint32 size); // from compemu_support.cpp
#endif

#ifdef ENABLE_MON
# include "mon.h"
#endif

#define DEBUG 0
#include "debug.h"

#include "main_macosx.h"		// To bridge between main() and misc. classes

static char *bundle = NULL;		// If in an OS X application bundle, its path

// CPU and FPU type, addressing mode
int CPUType;
bool CPUIs68060;
int FPUType;
bool TwentyFourBitAddressing;

// Global variables

#ifdef HAVE_PTHREADS

static pthread_mutex_t intflag_lock = PTHREAD_MUTEX_INITIALIZER;	// Mutex to protect InterruptFlags
#define LOCK_INTFLAGS pthread_mutex_lock(&intflag_lock)
#define UNLOCK_INTFLAGS pthread_mutex_unlock(&intflag_lock)

#else

#define LOCK_INTFLAGS
#define UNLOCK_INTFLAGS

#endif

#ifdef ENABLE_MON
static struct sigaction sigint_sa;	// sigaction for SIGINT handler
static void sigint_handler(...);
#endif

/*
 *  SIGSEGV handler
 */

static sigsegv_return_t sigsegv_handler(sigsegv_info_t *sip)
{
	const uintptr fault_address = (uintptr)sigsegv_get_fault_address(sip);
#if ENABLE_VOSF
	// Handle screen fault
	extern bool Screen_fault_handler(sigsegv_info_t *sip);
	if (Screen_fault_handler(sip))
		return SIGSEGV_RETURN_SUCCESS;
#endif

#ifdef HAVE_SIGSEGV_SKIP_INSTRUCTION
	// Ignore writes to ROM
	if (((uintptr)fault_address - (uintptr)ROMBaseHost) < ROMSize)
		return SIGSEGV_RETURN_SKIP_INSTRUCTION;

	// Ignore all other faults, if requested
	if (PrefsFindBool("ignoresegv"))
		return SIGSEGV_RETURN_SKIP_INSTRUCTION;
#endif

	return SIGSEGV_RETURN_FAILURE;
}

/*
 *  Dump state when everything went wrong after a SEGV
 */

static void sigsegv_dump_state(sigsegv_info_t *sip)
{
	const sigsegv_address_t fault_address = sigsegv_get_fault_address(sip);
	const sigsegv_address_t fault_instruction = sigsegv_get_fault_instruction_address(sip);
	fprintf(stderr, "Caught SIGSEGV at address %p", fault_address);
	if (fault_instruction != SIGSEGV_INVALID_ADDRESS)
		fprintf(stderr, " [IP=%p]", fault_instruction);
	fprintf(stderr, "\n");
	uaecptr nextpc;
	extern void m68k_dumpstate(uaecptr *nextpc);
	m68k_dumpstate(&nextpc);
#if USE_JIT && JIT_DEBUG
	extern void compiler_dumpstate(void);
	compiler_dumpstate();
#endif
	VideoQuitFullScreen();
#ifdef ENABLE_MON
	const char *arg[4] = {"mon", "-m", "-r", NULL};
	mon(3, arg);
#endif
	QuitEmulator();
}


/*
 * Screen fault handler
 */

bool Screen_fault_handler(sigsegv_info_t *sip)
{
	return true;
}


/*
 *  Main program
 */

static void usage(const char *prg_name)
{
	printf(
		"Usage: %s [OPTION...]\n"
		"\nUnix options:\n"
		"  --config FILE\n    read/write configuration from/to FILE\n"
		"  --break ADDRESS\n    set ROM breakpoint\n"
		"  --rominfo\n    dump ROM information\n", prg_name
	);
	LoadPrefs(NULL); // read the prefs file so PrefsPrintUsage() will print the correct default values
	PrefsPrintUsage();
	exit(0);
}

int main(int argc, char **argv){
	const char *vmdir = NULL;
	char str[256];

	// Initialize variables
	srand(time(NULL));
	tzset();

	// Print some info
	printf(GetString(STR_ABOUT_TEXT1), VERSION_MAJOR, VERSION_MINOR);
	printf(" %s\n", GetString(STR_ABOUT_TEXT2));

	// Parse command line arguments
	for (int i=1; i<argc; i++) {
		if (strcmp(argv[i], "--help") == 0) {
			usage(argv[0]);
		} else if (strncmp(argv[i], "-psn_", 5) == 0) {// OS X process identifier
			argv[i++] = NULL;
		} else if (strcmp(argv[i], "--break") == 0) {
			argv[i++] = NULL;
			if (i < argc) {
				ROMBreakpoint = strtol(argv[i], NULL, 0);
				argv[i] = NULL;
			}
		} else if (strcmp(argv[i], "--config") == 0) {
			argv[i++] = NULL;
			if (i < argc) {
				extern string UserPrefsPath; // from prefs_unix.cpp
				UserPrefsPath = argv[i];
				argv[i] = NULL;
			}
		} else if (strcmp(argv[i], "--rominfo") == 0) {
			argv[i] = NULL;
			PrintROMInfo = true;
		}
	}

	// Remove processed arguments
	for (int i=1; i<argc; i++) {
		int k;
		for (k=i; k<argc; k++)
			if (argv[k] != NULL)
				break;
		if (k > i) {
			k -= i;
			for (int j=i+k; j<argc; j++)
				argv[j-k] = argv[j];
			argc -= k;
		}
	}

	// Read preferences
	PrefsInit(vmdir, argc, argv);

	// Any command line arguments left?
	for (int i=1; i<argc; i++) {
		if (argv[i][0] == '-') {
			fprintf(stderr, "Unrecognized option '%s'\n", argv[i]);
			usage(argv[0]);
		}
	}

	// Init system routines
	SysInit();

	// Set the current directory somewhere useful.
	// Handy for storing the ROM file
	bundle = strstr(argv[0], "BasiliskII.app/Contents/MacOS/BasiliskII");
	if (bundle)
	{
		while (*bundle != '/')
			++bundle;

		*bundle = 0;  // Throw away Contents/... on end of argv[0]
		bundle = argv[0];

		chdir(bundle);
	}

	// Open display, attach to window server,
	// load pre-instantiated classes from MainMenu.nib, start run loop
	int i = NSApplicationMain(argc, (const char **)argv);
	// We currently never get past here, because QuitEmulator() does an exit()

	// Exit system routines
	SysExit();

	// Exit preferences
	PrefsExit();

	return i;
}

#define QuitEmulator()	{ QuitEmuNoExit() ; return NO; }

bool InitEmulator (void)
{
	const char *vmdir = NULL;
	char str[256];


	// Install the handler for SIGSEGV
	if (!sigsegv_install_handler(sigsegv_handler)) {
		sprintf(str, GetString(STR_SIG_INSTALL_ERR), "SIGSEGV", strerror(errno));
		ErrorAlert(str);
		QuitEmulator();
	}

	// Register dump state function when we got mad after a segfault
	sigsegv_set_dump_state(sigsegv_dump_state);

	// Initialize everything
	if (!InitAll(vmdir))
		QuitEmulator();
	D(bug("Initialization complete\n"));

#ifdef ENABLE_MON
	// Setup SIGINT handler to enter mon
	sigemptyset(&sigint_sa.sa_mask);
	sigint_sa.sa_handler = (void (*)(int))sigint_handler;
	sigint_sa.sa_flags = 0;
	sigaction(SIGINT, &sigint_sa, NULL);
#endif

	return YES;
}

#undef QuitEmulator()


/*
 *  Quit emulator
 */

void QuitEmuNoExit(){
	D(bug("QuitEmulator\n"));

	// Exit 680x0 emulation
	Exit680x0();

	// Deinitialize everything
	ExitAll();

	// Exit system routines
	SysExit();

	// Exit preferences
	PrefsExit();
}

void QuitEmulator(void){
	QuitEmuNoExit();

	// Stop run loop?
	[NSApp terminate: nil];

	exit(0);
}


/*
 *  Code was patched, flush caches if neccessary (i.e. when using a real 680x0
 *  or a dynamically recompiling emulator)
 */

void FlushCodeCache(void *start, uint32 size)
{
#if USE_JIT
	if (UseJIT)
		flush_icache_range((uint8 *)start, size);
#endif
}


/*
 *  SIGINT handler, enters mon
 */

#ifdef ENABLE_MON
static void sigint_handler(...)
{
	uaecptr nextpc;
	extern void m68k_dumpstate(uaecptr *nextpc);
	m68k_dumpstate(&nextpc);
	VideoQuitFullScreen();
	const char *arg[4] = {"mon", "-m", "-r", NULL};
	mon(3, arg);
	QuitEmulator();
}
#endif


#ifdef HAVE_PTHREADS
/*
 *  Pthread configuration
 */

void Set_pthread_attr(pthread_attr_t *attr, int priority)
{
	pthread_attr_init(attr);
#if defined(_POSIX_THREAD_PRIORITY_SCHEDULING)
	// Some of these only work for superuser
	if (geteuid() == 0) {
		pthread_attr_setinheritsched(attr, PTHREAD_EXPLICIT_SCHED);
		pthread_attr_setschedpolicy(attr, SCHED_FIFO);
		struct sched_param fifo_param;
		fifo_param.sched_priority = ((sched_get_priority_min(SCHED_FIFO)
									 + sched_get_priority_max(SCHED_FIFO))
									 / 2 + priority);
		pthread_attr_setschedparam(attr, &fifo_param);
	}
	if (pthread_attr_setscope(attr, PTHREAD_SCOPE_SYSTEM) != 0) {
#ifdef PTHREAD_SCOPE_BOUND_NP
	    // If system scope is not available (eg. we're not running
	    // with CAP_SCHED_MGT capability on an SGI box), try bound
	    // scope.  It exposes pthread scheduling to the kernel,
	    // without setting realtime priority.
	    pthread_attr_setscope(attr, PTHREAD_SCOPE_BOUND_NP);
#endif
	}
#endif
}
#endif // HAVE_PTHREADS


/*
 *  Mutexes
 */

#ifdef HAVE_PTHREADS

struct B2_mutex {
	B2_mutex() {
		pthread_mutexattr_t attr;
		pthread_mutexattr_init(&attr);
		// Initialize the mutex for priority inheritance --
		// required for accurate timing.
#ifdef HAVE_PTHREAD_MUTEXATTR_SETPROTOCOL
		pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT);
#endif
#if defined(HAVE_PTHREAD_MUTEXATTR_SETTYPE) && defined(PTHREAD_MUTEX_NORMAL)
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
#endif
#ifdef HAVE_PTHREAD_MUTEXATTR_SETPSHARED
		pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_PRIVATE);
#endif
		pthread_mutex_init(&m, &attr);
		pthread_mutexattr_destroy(&attr);
	}
	~B2_mutex() {
		pthread_mutex_trylock(&m);	// Make sure it's locked before
		pthread_mutex_unlock(&m);	// unlocking it.
		pthread_mutex_destroy(&m);
	}
	pthread_mutex_t m;
};

B2_mutex *B2_create_mutex(void)
{
	return new B2_mutex;
}

void B2_lock_mutex(B2_mutex *mutex)
{
	pthread_mutex_lock(&mutex->m);
}

void B2_unlock_mutex(B2_mutex *mutex)
{
	pthread_mutex_unlock(&mutex->m);
}

void B2_delete_mutex(B2_mutex *mutex)
{
	delete mutex;
}

#else

struct B2_mutex {
	int dummy;
};

B2_mutex *B2_create_mutex(void)
{
	return new B2_mutex;
}

void B2_lock_mutex(B2_mutex *mutex)
{
}

void B2_unlock_mutex(B2_mutex *mutex)
{
}

void B2_delete_mutex(B2_mutex *mutex)
{
	delete mutex;
}

#endif


/*
 *  Interrupt flags (must be handled atomically!)
 */

uint32 InterruptFlags = 0;

void SetInterruptFlag(uint32 flag)
{
	LOCK_INTFLAGS;
	InterruptFlags |= flag;
	UNLOCK_INTFLAGS;
}

void ClearInterruptFlag(uint32 flag)
{
	LOCK_INTFLAGS;
	InterruptFlags &= ~flag;
	UNLOCK_INTFLAGS;
}


/*
 *  Display error alert
 */

void ErrorAlert(const char *text)
{
	NSString *title  = [NSString stringWithCString:
						GetString(STR_ERROR_ALERT_TITLE) ];
	NSString *error  = [NSString stringWithCString: text];
	NSString *button = [NSString stringWithCString: GetString(STR_QUIT_BUTTON) ];

	NSLog(error);
	if ( PrefsFindBool("nogui") )
		return;
	VideoQuitFullScreen();
	NSRunCriticalAlertPanel(title, error, button, nil, nil);
}


/*
 *  Display warning alert
 */

void WarningAlert(const char *text)
{
	NSString *title   = [NSString stringWithCString:
							GetString(STR_WARNING_ALERT_TITLE) ];
	NSString *warning = [NSString stringWithCString: text];
	NSString *button  = [NSString stringWithCString: GetString(STR_OK_BUTTON) ];

	NSLog(warning);
	if ( PrefsFindBool("nogui") )
		return;
	VideoQuitFullScreen();
	NSRunAlertPanel(title, warning, button, nil, nil);
}


/*
 *  Display choice alert
 */

bool ChoiceAlert(const char *text, const char *pos, const char *neg)
{
	NSString *title   = [NSString stringWithCString:
							GetString(STR_WARNING_ALERT_TITLE) ];
	NSString *warning = [NSString stringWithCString: text];
	NSString *yes	  = [NSString stringWithCString: pos];
	NSString *no	  = [NSString stringWithCString: neg];

	return NSRunInformationalAlertPanel(title, warning, yes, no, nil);
}
