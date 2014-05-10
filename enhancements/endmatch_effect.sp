 
#include <sourcemod>
#include <sdktools> 

#pragma semicolon 1
 
public Plugin:myinfo = {
    name        = "endmatch effect",
    author      = "eeeeeeeeee",
    description = "maximum potency",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};
 
new UserMsg:g_FadeUserMsgId;
new bool:effect_active;


#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)
#define HIDEHUD_RADAR				( 1<<12 )	// Hide the radar

   
public OnMapStart() { 
	PrecacheSound( "*rxg/winsound.mp3", true );
	AddFileToDownloadsTable( "sound/rxg/winsound.mp3" );
}

public OnMapEnd() {
	effect_active = false;
}

public OnPluginStart() {
	g_FadeUserMsgId = GetUserMessageId("Fade"); 
	
	HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy );
	HookEvent( "cs_intermission", OnMatchEnd, EventHookMode_PostNoCopy );
}
   
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !effect_active ) return;
	effect_active = false;

	// reset hidehud
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		SetEntProp( i, Prop_Send, "m_iHideHUD", 0 );
		
	}
}

public OnMatchEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	effect_active = true;
	EmitSoundToAll( "*rxg/winsound.mp3" );
	
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		clients[count] = i;
		count++; 
		
		if( !IsPlayerAlive(i) ) continue;
		
		SetEntProp( i, Prop_Send, "m_iHideHUD", ~(HIDEHUD_CHAT|HIDEHUD_ALL|HIDEHUD_MISCSTATUS) );
		SetEntityMoveType( i, MOVETYPE_FLY );

		new Float:pos[3], Float:vel[3];
		GetClientAbsOrigin(i, pos);
		pos[2] += 2.0;
		vel[0] = GetRandomFloat(-10.0, 10.0);
		vel[1] = GetRandomFloat(-10.0, 10.0);
		vel[2] = GetRandomFloat(30.0, 80.0);

		TeleportEntity(i, pos, NULL_VECTOR, vel);
	}
	
	new duration2 = 1500;
	new holdtime = 50;

	new flags = 0x10|1;
	//new color[4] = { 255,60,10, 192};
	new color[4] = { 255,255,255, 255};
	new Handle:message = StartMessageEx( g_FadeUserMsgId, clients, count );
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
 


