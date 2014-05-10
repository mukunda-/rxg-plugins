#include <sourcemod>
#include <sdktools>

// 12:49 AM 10/3/2013 - 1.0.2
//   plugin door fix

public Plugin:myinfo = {
	name = "fastdoors",
	author = "mukunda",
	description = "door tickrate fix",
	version = "1.0.2",
	url = "www.reflex-gamers.com"
};

public OnPluginStart() {
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );

}

public OnMapStart() {
	Event_RoundStart( INVALID_HANDLE, "", false );
}

public Action:FixDoors(Handle:timer) {
	new Float:tickrate = 1.0 / GetTickInterval();
	new ent = -1;
	while( (ent=FindEntityByClassname( ent, "prop_door_rotating" )) != -1 ) {
		new Float:speed = GetEntPropFloat( ent, Prop_Data, "m_flSpeed" );
		speed = speed * tickrate / 64.0;
		SetEntPropFloat( ent, Prop_Data, "m_flSpeed", speed );
	}
	return Plugin_Handled;
}

public Event_RoundStart( Handle:event, const String:name[], bool:db ) {
	
	// do it a second later to catch doors added by plugins
	CreateTimer( 1.0, FixDoors, _, TIMER_FLAG_NO_MAPCHANGE );
	
}
