/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

//-------------------------------------------------------------------------------------------------

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define PLAYSOUND

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "nightvision",
	author = "mukunda",
	description = "give players nightvision",
	version = "1.0.0",
	url = "http://www.reflex-gamers.com"
};

#if defined PLAYSOUND

#define SOUND_NVG_ON	"items/nvg_on.wav"
#define SOUND_NVG_OFF	"items/nvg_off.wav"

#define SOUND_COOLDOWN 0.25

new Float:next_sound_time[MAXPLAYERS+1];

#endif

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	HookEvent( "player_spawn", Event_PlayerSpawn );
	
	
#if defined PLAYSOUND
	AddCommandListener( Command_Nightvision, "nightvision" );
#endif
}

#if defined PLAYSOUND
public OnMapStart() {
	PrecacheSound( SOUND_NVG_ON );
	PrecacheSound( SOUND_NVG_OFF );
}

public OnClientPutInServer( client ) {
	next_sound_time[client] = 0.0;
}

#endif

//----------------------------------------------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId(GetEventInt( event, "userid" ));
	if( IsValidClient(client) ) {
		SetEntProp( client, Prop_Send, "m_bHasNightVision", 1 );
	}
}

#if defined PLAYSOUND 

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Nightvision( client, const String:command[], argc ) {
	if( !IsClientInGame(client) ) return Plugin_Continue;
	if( !IsPlayerAlive(client) ) return Plugin_Continue;
	if( GetGameTime() < next_sound_time[client] ) return Plugin_Continue;
	next_sound_time[client] = GetGameTime() + SOUND_COOLDOWN;
	
	if( GetEntProp( client, Prop_Send, "m_bNightVisionOn" ) ) {
		EmitSoundToAll( SOUND_NVG_OFF, client );
	} else {
		EmitSoundToAll( SOUND_NVG_ON, client );
	}
	
	return Plugin_Continue;
}

#endif
