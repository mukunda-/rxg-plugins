#pragma semicolon 1

#include <sourcemod>
#include <sdktools> 
#include <cstrike>
 
//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "singing hosties",
	author = "REFLEX-GAMERS",
	description = "sing motherfucker sing",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define MAX_HOSTIES 4

new hosties[MAX_HOSTIES];
new nhosties;

new hostage_track[MAX_HOSTIES];
new song = 0;

new bool:hooked = false;

new Handle:singing_hosties = INVALID_HANDLE;

new String:songs[][] = {
	"edcdeeedddeggedcdeeeeddedc"	// mary had a little lamb
};

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	singing_hosties = CreateConVar( "singing_hosties", "0", "make them sing", FCVAR_PLUGIN );
	HookEvent( "round_start", Event_RoundStart );

	HookConVarChange( singing_hosties, CVarChanged_singing_hosties );
}

//----------------------------------------------------------------------------------------------------------------------
public CVarChanged_singing_hosties( Handle:cvar, const String:oldval[], const String:newval[] ) {
	SetSoundHook( GetConVarInt( singing_hosties ) != 0 );
}

//----------------------------------------------------------------------------------------------------------------------
SetSoundHook(bool:yes) {
	if( hooked != yes ) {
		if( yes ) {
			AddNormalSoundHook( SoundHook );
		} else {
			RemoveNormalSoundHook( SoundHook );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
FindHosties() {
	nhosties = 0;
	for( new i = 0; i < MAX_HOSTIES; i++ ) {
		hostage_track[i] = 0;
	}

	new ent = -1;
	while( ent = FindEntityByClassname( ent, "hostage_entity" ) ) {
		hosties[nhosties] = ent;
		nhosties++;
		if( nhosties == 4 ) {
			break;
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	FindHosties();
}

//----------------------------------------------------------------------------------------------------------------------
public Action:SoundHook( clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) {
	new bool:is_hostage = false;
	for( new i = 0; i < nhosties; i++ ) {
		if( entity == hosties[i] ) {
			is_hostage = true;
			break;
		}
	}
	if( !is_hostage ) return Plugin_Continue;
	
	// verify sample == hostage scream --and tune accordingly
	
	
	
	return Plugin_Changed;
}
