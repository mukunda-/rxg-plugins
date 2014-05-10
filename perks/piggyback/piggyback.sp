
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <donations>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "piggyback",
	author = "mukunda",
	description = "piggyback",
	version = "1.0.1",
	url = "www.mukunda.com"
};

new bool:timer_active;

new client_piggy[MAXPLAYERS+1]; // 0= client is not piggybacking, !0 = userid of client piggyback target

new Handle:sm_piggyback_enemies;
new c_piggyback_enemies;

new Handle:onuse_forward;

new Handle:cookie_allow;

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {
	CreateNative( "IsClientPiggybacking", Native_IsClientPiggybacking );
	
	RegPluginLibrary( "piggybacking" );
}

//-------------------------------------------------------------------------------------------------
public Native_IsClientPiggybacking( Handle:plugin, numParams ) {
	return client_piggy[GetNativeCell(1)] != 0;
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldValue[], const String:newValue[]) {
	if( convar == sm_piggyback_enemies ) {
		c_piggyback_enemies = GetConVarInt( sm_piggyback_enemies );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "piggyback", Command_piggyback ); 
	cookie_allow = RegClientCookie( "piggyback_allow", "Allow Piggybacking", CookieAccess_Protected );
	SetCookiePrefabMenu( cookie_allow, CookieMenu_YesNo_Int, "Allow Piggybacking"  );

	onuse_forward = CreateGlobalForward( "Piggyback_OnUse", ET_Event, Param_Cell, Param_Cell );
	
	sm_piggyback_enemies = CreateConVar( "sm_piggyback_enemies", "0", "can player's piggyback hostile targets?" );
	HookConVarChange( sm_piggyback_enemies, OnConVarChanged );
	c_piggyback_enemies = GetConVarInt( sm_piggyback_enemies );
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
	VIP_Register( "Piggyback", OnVIPMenu );
}

public OnLibraryAdded( const String:name[] ) {
	if( StrEqual(name,"donations") ) 
		VIP_Register( "Piggyback", OnVIPMenu );
}
public OnPluginEnd() {
	VIP_Unregister();
}
//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	AddFileToDownloadsTable( "sound/piggyback/yoshi.mp3" );
	PrecacheSound( "*piggyback/yoshi.mp3" );
}

//-------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	client_piggy[client] = 0;
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	
	client_piggy[client] = 0;
}

//-------------------------------------------------------------------------------------------------
public bool:IsValidClient(client) {
	if(client <= 0) return false;
	if(client > MaxClients) return false;
	return IsClientInGame(client);
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_Clients( entity, contentsMask, any:data ) {
	if( IsValidClient( entity ) && entity != data ) {
		return true;
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
GetClientLookTarget( client, Float:reach ) {
	decl Float:trace_start[3];
	decl Float:trace_angles[3];
	decl Float:trace_normal[3];
	decl Float:trace_end[3];
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
			return ent; 
		}
	}
	return 0;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_piggyback( client, args ) {
	
	if( !IsPlayerAlive(client) ) return Plugin_Handled;

	
	new Action:result;
	Call_StartForward(onuse_forward);
	Call_PushCell( client );
	Call_Finish(_:result);
	if( result == Plugin_Handled ){
		PrintCenterText( client, "You can't piggyback right now." );
		return Plugin_Handled;
	}

	if( client_piggy[client] ) {
		// unmount
		StopPiggyback( client );
	} else {
		if( Donations_GetClientLevelDirect( client ) == 0 ) {
			PrintCenterText( client, "Piggyback is for donator's only! :)" );
			return Plugin_Handled;
		}
		new target = GetClientLookTarget( client, 40.0 );
		if( !target ) {
			PrintCenterText( client, "Couldn't find player!" );
			return Plugin_Handled;
		}
		if( (!c_piggyback_enemies) && (GetClientTeam(client) != GetClientTeam(target)) ) {
			PrintCenterText( client, "Target is hostile!!" );
			return Plugin_Handled;
		}
		if( !CheckPiggyback(client,target) ) {
			PrintCenterText( client, "Couldn't find player!" );
			return Plugin_Handled;
		}
		decl String:c[4];
		GetClientCookie( client, cookie_allow, c, sizeof c );
		if( c[0] == '0' ) {
			PrintCenterText( client, "That player has piggybacking disabled." );
			return Plugin_Handled;
		}
		StartPiggyback( client, target );
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
bool:CheckPiggyback( client, target ) {
	// returns TRUE if valid piggyback target
	// returns FALSE if target is on top of client
	// (this function to prevent recursive piggybacking)
	
	if( !client_piggy[target] ) return true;
	new targetpiggy = GetClientOfUserId( client_piggy[target] );
	if( !targetpiggy ) return true;
	if( targetpiggy == client ) return false;
	return CheckPiggyback( client, targetpiggy );
}

//-------------------------------------------------------------------------------------------------
StartPiggyback( client, target ) {	
	 
	client_piggy[client] = GetClientUserId( target );
	SetEntityMoveType( client, MOVETYPE_NONE );
	
	EmitSoundToAll( "*piggyback/yoshi.mp3", client );
	
	if (!timer_active ) {
		timer_active = true;
		CreateTimer( 0.05, UpdateTimer, _, TIMER_REPEAT );
	}
}

//-------------------------------------------------------------------------------------------------
StopPiggyback( client ) {
	client_piggy[client] = 0;
	SetEntityMoveType( client, MOVETYPE_WALK );
	
	new Float:vel[3] = {0.0,0.0,200.0};
	TeleportEntity( client, NULL_VECTOR,NULL_VECTOR, vel );
	
}

//-------------------------------------------------------------------------------------------------
bool:UpdatePiggyback( client ) {
	if( !client_piggy[client] ) return false;
	if( !IsPlayerAlive(client) ) {
		StopPiggyback(client);
		return false;
	}
	new target = GetClientOfUserId( client_piggy[client] );
	if( target == 0 ) {
		StopPiggyback(client);
		return false;
	}
	
	if( !IsPlayerAlive(target) ) {
		StopPiggyback(client);
		return false;
	}
	
	decl Float:pos[3];
	GetClientEyePosition( target, pos );
	pos[2] -= 32.0;
	new Float:poop[3];
	
	poop[0] = GetEntPropFloat( target, Prop_Send, "m_vecVelocity[0]" );
	poop[1] = GetEntPropFloat( target, Prop_Send, "m_vecVelocity[1]" );
	poop[2] = GetEntPropFloat( target, Prop_Send, "m_vecVelocity[2]" );
	
	TeleportEntity( client, pos, NULL_VECTOR,poop );
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action:UpdateTimer( Handle:timer ) {
	
	new updates = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( UpdatePiggyback( i ) ) {	
			updates++;
		}
	}
	if( updates ) return Plugin_Continue;
	
	timer_active=false;
	return Plugin_Stop;
}
 
//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04Only VIPs can ride other players." );
	} else if( action == VIP_ACTION_USE ) {
		PrintToChat( client, "\x01 \x04Use !piggyback or bind \"piggyback\" in console to mount people (type \"bind <key> piggyback\")" );
	}
}
