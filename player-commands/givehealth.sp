

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

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Give Health",
	author = "mukunda",
	description = "Press E to give donate blood",
	version = "1.0.1",
	url = "http://www.reflex-gamers.com"
};

#define SOUND "items/smallmedkit1.wav"

//-------------------------------------------------------------------------------------------------
public bool:IsValidClient(client) {
	if(client <= 0) return false;
	if(client > MaxClients) return false;
	return IsClientInGame(client);
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "givehealth", GiveHealth );

}

public OnMapStart() {
	PrecacheSound( SOUND );
}

public OnClientPutInServer( client ) {
	// enable +use on clients
	//SetEntProp( client, Prop_Data, "m_spawnflags", GetEntProp(client, Prop_Data, "m_spawnflags") | 256 );
	// ^ why was this here lol? (maybe required for trace to hit clients?)
}

GiveHealthClients( client, target, amount ) {
	// both are players, proceed
	new ch = GetClientHealth(client);
	if( ch <= 1 ) {
		PrintCenterText( client, "You don't have enough health lol" );
		return;
	}
	
	/* if player wants to give more than his health, clamp it */
	if( amount >= ch ) {
		amount = ch - 1;
	}

	new th = GetClientHealth(target);
	if( th >= 100 ) {
		PrintCenterText( client, "That guy doesn't need health." );
	} else {
		/* if target cant fit that much health, clamp */
		if( (th+amount) > 100 ) {
			amount = (100-th);
		}
		SetEntityHealth( client, ch - amount );
		SetEntityHealth( target, th + amount );
		PrintCenterText( client, "You gave away %d health!", amount );
		decl String:name[32];
		GetClientName( client, name, 32 );
		PrintCenterText( target, "%N gave you some health!", client );
		EmitSoundToAll( SOUND, target, _, SNDLEVEL_NORMAL-10, _, _, 150 );
	}

}

//-------------------------------------------------------------------------------------------------
public Action:GiveHealth( client, args ) {

	new Float:reach = 100.0;
	new Float:trace_start[3];
	new Float:trace_end[3];
	new Float:trace_angles[3];
	new Float:trace_normal[3];

	new amount = 10;
	if( args >= 1 ) {
		decl String:arg[32];
		GetCmdArg( 1, arg, sizeof(arg) );
		amount = StringToInt(arg);
		if( amount == 0 ) {
			ReplyToCommand( client, "Invalid amount arg!" );
			return Plugin_Handled;
		}
	}

	GetClientEyePosition( client, trace_start );
	GetClientEyeAngles( client, trace_angles );
	GetAngleVectors( trace_angles, trace_normal, NULL_VECTOR, NULL_VECTOR );
	NormalizeVector( trace_normal, trace_normal );
	for( new i = 0; i < 3; i++ )
		trace_end[i] = trace_start[i] + trace_normal[i] * reach;

	TR_TraceRayFilter( trace_start, trace_end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_Clients, client );
	if( TR_DidHit() ) {
		new ent = TR_GetEntityIndex();
		if( IsValidClient(ent) ) {
			if( GetClientTeam(ent) == GetClientTeam(client) ) {
				GiveHealthClients( client, ent, amount );
				return Plugin_Handled;
			}
		}
	}

	PrintCenterText( client, "Couldn't find player!" );
	return Plugin_Handled;
}

public bool:TraceFilter_Clients( entity, contentsMask, any:data ) {
	if( IsValidClient( entity ) && entity != data ) {
		return true;
	}
	return false;
}
