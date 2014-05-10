
#if defined _TIMEFUNCS
  #endinput
#endif
#define _TIMEFUNCS

// returns unix timestamp
// susceptible to y2038k
//
native MakeTime( hour=-1, minute=-1, second=-1, month=-1, day=-1, year=-1 );

/**
 * Do not edit below this line!
 */
public Extension:__ext_timefuncs = 
{
	name = "TimeFuncs",
	file = "timefuncs.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};
