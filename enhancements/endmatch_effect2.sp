#include <sourcemod>
#include <sdktools> 

#pragma semicolon 1
 
public Plugin:myinfo = {
    name        = "endmatch effect 2",
    author      = "eeeeeeeeee",
    description = "minimum potency",
    version     = "1.0.1",
    url         = "www.mukunda.com"
};
 

new bool:effect_active;
  
public OnMapStart() { 
	PrecacheSound( "buttons/light_power_on_switch_01.wav", true );
}

public OnMapEnd() {
	effect_active = false;
}

public OnPluginStart() { 
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	HookEvent( "cs_intermission", OnMatchEnd, EventHookMode_PostNoCopy );
}
   
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !effect_active ) return;
	effect_active = false; 
}

public OnMatchEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	effect_active = true;
	EmitSoundToAll( "buttons/light_power_on_switch_01.wav" );
	
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		clients[count] = i;
		count++;  
	}
	
	new duration2 = 1500;
	new holdtime = 50;

	new flags = 0x10|1; 
	new color[4] = { 255,255,255, 255};
	new Handle:message = StartMessageEx( GetUserMessageId("Fade"), clients, count );
	PbSetInt(message, "duration", duration2);
	PbSetInt(message, "hold_time", holdtime);
	PbSetInt(message, "flags", flags);
	PbSetColor(message, "clr", color);
	EndMessage();
	 
	CreateTimer( 4.0, UnfreezePlayers, _, TIMER_FLAG_NO_MAPCHANGE  ); 
}

//----------------------------------------------------------------------
public Action:UnfreezePlayers( Handle:tmr ) {
	for (new i=1; i <= MaxClients; i++) {
		if ( !IsClientInGame(i) || !IsPlayerAlive(i)) continue;
		SetEntityFlags( i, GetEntityFlags(i) & ~FL_FROZEN );
	}
	return Plugin_Handled;
}
 


