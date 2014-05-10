
/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

#include <sourcemod>
#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "night mode",
	author = "REFLEX-GAMERS",
	description = "Nighttime Special Mode",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

// set this plugin's lifetime to "global" !

//----------------------------------------------------------------------------------------------------------------------
new Handle:nm_time_start; // what time range to check for server death and switch gamemodes
new Handle:nm_time_end; // format for each is HH:MM
//new Handle:nm_hostname_normal; //
new Handle:nm_hostname; // 
new Handle:nm_clients_threshold;

new c_time_start;
new c_time_end;
new c_clients_threshold;

new current_mode;
new transitioning;

new bool:game_active;

enum {
	MODE_REGULAR,
	MODE_NIGHT,
	
	MODE_DEFAULT = MODE_REGULAR
};

//----------------------------------------------------------------------------------------------------------------------
ParseTime( String:time[] ) {
	time[2] = 0;
	return StringToInt( time ) * 60 + StringToInt( time[3] );
}

//----------------------------------------------------------------------------------------------------------------------
CacheTimes() {
	decl String:timestring[64];
	GetConVarString( nm_time_start, timestring, sizeof timestring );
	timestring[5] = 0;
	c_time_start = ParseTime( timestring );
	
	GetConVarString( nm_time_end, timestring, sizeof timestring );
	timestring[5] = 0;
	c_time_end = ParseTime( timestring );
}

//----------------------------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( cvar == nm_time_start || cvar == nm_time_end ) {
		CacheTimes();
	} else if( cvar == nm_clients_threshold ) {
		c_clients_threshold = GetConVarInt( nm_clients_threshold );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	current_mode = MODE_DEFAULT;
	
	nm_time_start = CreateConVar( "nm_time_start", "03:00", "HH:MM, time of potential nightmode start", FCVAR_PLUGIN );
	nm_time_end = CreateConVar( "nm_time_end", "07:00", "HH:MM, time of nightmode end", FCVAR_PLUGIN );
	//nm_hostname_normal = CreateConVar( "nm_hostname_normal", "<test>", "normal hostname of server, copied from hostname", FCVAR_PLUGIN );
	nm_hostname = CreateConVar( "nm_hostname", "<night mode>", "nightmode hostname of server", FCVAR_PLUGIN );
	nm_clients_threshold = CreateConVar( "nm_clients_threshold", "14", "wait until clients are under this amount before starting nightmode", FCVAR_PLUGIN );
	
	HookConVarChange( nm_time_start, OnConVarChanged );
	HookConVarChange( nm_time_end, OnConVarChanged );
	HookConVarChange( nm_clients_threshold, OnConVarChanged );
	
	CacheTimes();
	c_clients_threshold = GetConVarInt( nm_clients_threshold );
	
	CreateTimer( 120.0, OnTimeUpdate, _, TIMER_REPEAT );
//	CreateTimer( 6.0, OnTimeUpdate, _, TIMER_REPEAT ); // DEBUG
	
	HookEvent( "cs_intermission", Event_Intermission, EventHookMode_PostNoCopy  );
	HookEvent( "cs_match_end_restart", Event_Newmatch, EventHookMode_PostNoCopy  );
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnConfigsExecuted() {
	
	CreateTimer( 3.0, TimerChangeHostname );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:TimerChangeHostname( Handle:timer ) {
	
	//GetConVarString( FindConVar( "hostname" ), buffer, sizeof buffer );
	//SetConVarString( nm_hostname_normal, buffer );
	
	if( current_mode == MODE_NIGHT ) {
		decl String:buffer[256];
		GetConVarString( nm_hostname, buffer, sizeof buffer );
		ServerCommand( "hostname \"%s\"", buffer );
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
TimeUpdate() {
	if( !game_active ) return;
	if( transitioning ) return;
	
	decl String:timestring[64];
	FormatTime( timestring, sizeof timestring, "%H:%M" );
	
	new minutes = ParseTime( timestring );
	
	if( current_mode == MODE_REGULAR ) {
		
		if( minutes < c_time_start || minutes > c_time_end ) return; // daytime
		
		new active_clients = GetTeamClientCount(2)+GetTeamClientCount(3);
		if( active_clients < c_clients_threshold ) {
			
			StartNightMode();
		}
	} else if( current_mode == MODE_NIGHT ) {
		if( minutes >= c_time_start && minutes <= c_time_end ) return; // nighttime
		StartDayMode();
		
	}
}

//----------------------------------------------------------------------------------------------------------------------
StartNightMode() {
	SetConVarInt( FindConVar( "mp_timelimit" ), 1 ); // end match
	SetConVarInt( FindConVar( "mp_match_end_restart" ), 0 ); // 
	SetConVarInt( FindConVar( "mp_match_end_changelevel" ), 1 ); //
	transitioning = 1;
	
	CreateTimer( 300.0, TimerForceEnd, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
	
	current_mode = MODE_NIGHT;
}

//----------------------------------------------------------------------------------------------------------------------
StartDayMode() {
	SetConVarInt( FindConVar( "mp_match_end_restart" ), 0 ); // 
	SetConVarInt( FindConVar( "mp_match_end_changelevel" ), 1 ); //
	transitioning = 1;
	
	CreateTimer( 6000.0, TimerForceEnd, _, TIMER_FLAG_NO_MAPCHANGE );
	
	current_mode = MODE_REGULAR;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:TimerForceEnd( Handle:timer ) {
	new active_clients = GetTeamClientCount(2)+GetTeamClientCount(3);
	if( active_clients > 8 ) { //magic numborrrrrrrrr
		return Plugin_Continue;
	}
	decl String:map[64];
	GetCurrentMap( map, sizeof map );
	ForceChangeLevel( map, "Switching Game Mode" );
	return Plugin_Stop;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnTimeUpdate( Handle:timer ) {
	TimeUpdate();
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	game_active = true;
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapEnd() {
	game_active = false;
	
	if( transitioning ) {	
		if( current_mode == MODE_NIGHT ) {
			SetConVarInt( FindConVar( "game_type" ), 1 ); // gungame
			SetConVarInt( FindConVar( "game_mode" ), 2 ); // deathmatch
		} else {
			SetConVarInt( FindConVar( "game_type" ), 0 ); // gungame
			SetConVarInt( FindConVar( "game_mode" ), 0 ); // deathmatch
		}
	}
	
	transitioning = 0;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_Intermission( Handle:event, const String:name[], bool:db ) {
	game_active = false;
	if( transitioning ) {
		if( current_mode == MODE_NIGHT ) {
			PrintToChatAll( "\x01 >> \x0ESwitching to night mode..." );
		} else if( current_mode == MODE_REGULAR ) {
			PrintToChatAll( "\x01 >> \x0ESwitching to day mode..." );
		}
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
public Event_Newmatch( Handle:event, const String:name[], bool:db ) {
	game_active = true;
}
//----------------------------------------------------------------------------------------------------------------------
