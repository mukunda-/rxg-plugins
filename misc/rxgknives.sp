
#include <sourcemod>
#include <sdktools>
#include <cstrike_weapons>

public Plugin:myinfo =
{
	name = "rxg knives server",
	author = "mukunda",
	description = "rxg knives server",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new bool:player_hastaser[MAXPLAYERS+1];
new Float:player_tasetime[MAXPLAYERS+1];

new Float:player_alive_time[MAXPLAYERS+1];

new player_use[MAXPLAYERS+1];

new Handle:rxg_tasers;
new Handle:rxg_tasers_cooldown;
new Handle:rxg_respawn;
new Handle:rxg_respawn_time;
new Handle:rxg_dominoes_ftem;
new c_tasers;
new Float:c_tasers_cooldown;
new c_respawn;
new Float:c_respawn_time;
new String:c_dominoes_ftem[64];

new domino_id;

new const String:downloads[][] = {
	"models/rxg/domino.dx90.vtx",
	"models/rxg/domino.mdl",
	"models/rxg/domino.phy",
	"models/rxg/domino.vvd",
	"materials/rxg/domino.vtf",
	"materials/rxg/domino.vmt"
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldValue[], const String:newValue[]) {
	if( convar == rxg_tasers ) {
		c_tasers = GetConVarInt( rxg_tasers );
	} else if( convar == rxg_tasers_cooldown ) {
		c_tasers_cooldown = GetConVarFloat( rxg_tasers_cooldown );
	} else if( convar == rxg_respawn ) {
		c_respawn = GetConVarInt( rxg_respawn );
	} else if( convar == rxg_respawn_time ) {
		c_respawn_time = GetConVarFloat( rxg_respawn_time );
	} else if( convar == rxg_dominoes_ftem ) {
		GetConVarString( rxg_dominoes_ftem, c_dominoes_ftem, sizeof c_dominoes_ftem );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	rxg_tasers = CreateConVar( "rxg_tasers", "1", "give tasers", FCVAR_PLUGIN );
	rxg_tasers_cooldown = CreateConVar( "rxg_tasers_cooldown", "3.0", "tser cooldown before regiving", FCVAR_PLUGIN );
	rxg_respawn = CreateConVar( "rxg_respawn", "1", "can players respawn", FCVAR_PLUGIN );
	rxg_respawn_time = CreateConVar( "rxg_respawn_time", "30.0", "respawn after x seconds", FCVAR_PLUGIN );
	rxg_dominoes_ftem = CreateConVar( "rxg_dominoes_ftem", "100.0", "force required to wake dominoes (lower = more cpu load)", FCVAR_PLUGIN );
	HookConVarChange( rxg_tasers, OnConVarChanged );
	HookConVarChange( rxg_tasers_cooldown, OnConVarChanged );
	HookConVarChange( rxg_respawn, OnConVarChanged );
	HookConVarChange( rxg_respawn_time, OnConVarChanged );
	HookConVarChange( rxg_dominoes_ftem, OnConVarChanged );
	c_tasers = GetConVarInt( rxg_tasers );
	c_tasers_cooldown = GetConVarFloat( rxg_tasers_cooldown );
	c_respawn = GetConVarInt( rxg_respawn );
	c_respawn_time = GetConVarFloat( rxg_respawn_time );
	GetConVarString( rxg_dominoes_ftem, c_dominoes_ftem, sizeof c_dominoes_ftem );
	
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent( "player_death", Event_PlayerDeath );
	
	
	RegConsoleCmd( "domino", Command_domino );
}

public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event,"userid") );
	if( !client ) return;
	player_tasetime[client] = GetGameTime();
}

public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event,"userid") );
	if( !client ) return;
	
//	if( c_respawn ) {
//		PrintHintText( client, "Respawning in %d seconds...", RoundToNearest(c_respawn_time) );
//	}
	player_alive_time[client] = GetGameTime();
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	CreateTimer( 1.0, OnUpdate, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
	
	for( new i = 0; i < sizeof downloads; i++ ) {
		AddFileToDownloadsTable( downloads[i] );
	}
	
	PrecacheModel( "models/rxg/domino.mdl" );
	
	domino_id = 1;
}

//-------------------------------------------------------------------------------------------------
WeaponID:WeaponIDfromEntity( ent ) {
	if( ent == -1 ) return WEAPON_NONE;
	decl String:classname[64];
	GetEntityClassname( ent, classname, sizeof(classname) );
	ReplaceString( classname, sizeof(classname), "weapon_", "" );
	return GetWeaponID( classname );
}	

//----------------------------------------------------------------------------------------------------------------------
PlayerHasTaser( client ) {
	new ent = -1;
	for( new i = 0; i < 64; i++ ) {
		ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		if( ent != -1 ) {
			new WeaponID:id = WeaponIDfromEntity(ent);
			if( id == WEAPON_TASER ) {
				return ent;
			}
		}
	}
	return 0;
}

//-------------------------------------------------------------------------------------------------
GivePlayerTaser( client ) {
	GivePlayerItem( client, "weapon_taser" );
}

//-------------------------------------------------------------------------------------------------
UpdateTaser( client ) {
	if( !c_tasers ) return;

	if( !IsPlayerAlive(client) ) return;
	new Float:time = GetGameTime();
	if( player_hastaser[client] ) {
		// wait until player loses taser and record time
		if( !PlayerHasTaser(client) ) {
			player_hastaser[client] = false;
			player_tasetime[client] = time;
		}
	} else {
		// give player taser after some time
		if( PlayerHasTaser(client) ) {
			// player picked up a taser
			player_hastaser[client] = true;
		} else {
			if( (time - player_tasetime[client]) >= c_tasers_cooldown ) {
				GivePlayerTaser(client);
				player_hastaser[client] = true;
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
UpdateRespawn( client ) {
	if( !c_respawn ) return;
	
	if( GetClientTeam(client) < 2 ) return;
	if( !IsPlayerAlive(client) ) {
		new Float:seconds = c_respawn_time - (GetGameTime() - player_alive_time[client]);
		if( seconds <= 0.0 ) {

			if( player_use[client] ) {
				player_alive_time[client] = GetGameTime();
				CS_RespawnPlayer(client);
			} else {
				PrintHintText( client, "Press E to respawn." );
			}
		} else if( seconds < c_respawn_time - 3.0 ) {
			PrintHintText( client, "Respawn in %d seconds...", RoundToNearest(seconds) );
		} else {
		}
	} else {
		player_alive_time[client] = GetGameTime();
	}
}

Respawn_OnUse( client ) {
	if( !c_respawn ) return;
	if( GetClientTeam(client) < 2 ) return;
	if( !IsPlayerAlive(client) ) {
		new Float:seconds = c_respawn_time - (GetGameTime() - player_alive_time[client]);
		if( seconds <= 0.0 ) {
			player_alive_time[client] = GetGameTime();
			CS_RespawnPlayer(client);
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Action:OnUpdate( Handle:timer ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		UpdateTaser(i);
		UpdateRespawn(i);

		player_use[i] = false;
	}
}

//-------------------------------------------------------------------------------------------------
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if( buttons & IN_USE ) {
		player_use[client] = 1;
		Respawn_OnUse(client);
		
	}
}


public bool:TraceFilter_All( entity, contentsMask ) {
	if(entity > MaxClients) return true;
	return false;
}

public KillEnt(const String:output[], caller, activator, Float:delay) { 
	
	AcceptEntityInput(caller,"Kill");
}
// LIFECYCLE OF A DOMINO:

// placed by user ->
//   impact wakes up domino
//   after 5 seconds, disables motion						} procedures in place to prevent dominoes from infinitely nudging each other
//   after 3 seconds, respawns itself with motion disabled	}
//   after 3 seconds, enables motion

//----------------------------------------------------------------------------------------------------------------------
public Action:EnableDomino( Handle:timer, any:data ) {
	ResetPack(data);
	decl String:idstring[64];
	ReadPackString(data,idstring,sizeof idstring);
	new ent = ReadPackCell(data);
	if( !IsValidEntity( ent ) ) return Plugin_Handled;
	
	decl String:name[64];
	GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
	if( !StrEqual(idstring,name) ) return Plugin_Handled; // entity was changed
	
	decl Float:pos[3], Float:ang[3];
	
	GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", pos );
	GetEntPropVector( ent, Prop_Send, "m_angRotation", ang );
	//PrintToChatAll( "Debug: %f, %f, %f", pos[0], ang[0], ang[1] );
	
	AcceptEntityInput( ent, "Kill" );
	
	SpawnDomino( pos, ang,true );
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:DisableDomino( Handle:timer, any:data ) {
	
	
	ResetPack(data);
	decl String:idstring[64];
	ReadPackString(data,idstring,sizeof idstring);
	new ent = ReadPackCell(data);
	if( !IsValidEntity( ent ) ) return Plugin_Handled;
	
	decl String:name[64];
	GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
	
	if( !StrEqual(idstring,name) ) return Plugin_Handled; // entity was changed
	//PrintToChatAll( "Debug: DisableDomino: %d", ent );
	
	AcceptEntityInput( ent, "DisableMotion" ); // prevent dominoes from shitting ona  server
	AcceptEntityInput( ent, "Sleep" ); // prevent dominoes from shitting on a server
	
	new Handle:data2;
	CreateDataTimer( 3.0, EnableDomino, data2 );
	 
	WritePackString( data2, idstring ); // id
	WritePackCell( data2, ent ); // ent
	
	return Plugin_Handled;
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnDominoAwakened(const String:output[], caller, activator, Float:delay) { 
	
	new Handle:data;
	CreateDataTimer( 5.0, DisableDomino, data );
	
	//PrintToChatAll( "Debug: OnDominoAwakened: %d", caller );
	decl String:name[64];
	GetEntPropString( caller, Prop_Data, "m_iName", name, sizeof name );
	WritePackString( data, name ); // id
	WritePackCell( data, caller ); // ent
}

//----------------------------------------------------------------------------------------------------------------------
public Action:WakeDomino( Handle:timer, any:data ) {
	ResetPack(data);
	decl String:idstring[64];
	ReadPackString(data,idstring,sizeof idstring);
	new ent = ReadPackCell(data);
	if( !IsValidEntity( ent ) ) return Plugin_Handled;
	decl String:name[64];
	GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof name );
	if( !StrEqual(idstring,name) ) return Plugin_Handled; // entity was changed
	//PrintToChatAll( "Debug: WakeDomino: %d", ent );
	 
	AcceptEntityInput(ent, "EnableMotion");
	AcceptEntityInput(ent, "Sleep");
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
SpawnDomino( const Float:position[3], const Float:ang[3], bool:waitmotion=false ) {
	
	// waitmotion = delay enable motion to prevent immediate touching with other dominoes recovering from their disabled state
	//
	
	decl String:name[64];
	Format( name, sizeof(name), "domino%d", domino_id++ );
	new ent = CreateEntityByName( "prop_physics_override" );
	SetEntityModel( ent, "models/rxg/domino.mdl" );
	
	if( waitmotion ) {
		DispatchKeyValue(ent, "spawnflags", "265" ); // sleep+disablemotion+onuse
	} else {
		DispatchKeyValue(ent, "spawnflags", "257" ); // sleep+onuse
	}
	DispatchKeyValue(ent, "targetname", name ); 
	DispatchKeyValue(ent, "physdamagescale", "100.0" );  
	AcceptEntityInput(ent,"DisableMotion");
	 
	new Float:zero[3];
	TeleportEntity( ent, position, ang,NULL_VECTOR );
		
	DispatchSpawn(ent);
	HookSingleEntityOutput( ent, "OnPlayerUse", KillEnt, true );
	HookSingleEntityOutput( ent, "OnAwakened", OnDominoAwakened, false );
	
	if( waitmotion ) {
		new Handle:data;
		CreateDataTimer( 3.0, WakeDomino, data );
		 
		WritePackString( data, name ); // id
		WritePackCell( data, ent ); // ent
	}
	 
	return ent;
}

//----------------------------------------------------------------------------------------------------------------------
PlaceDomino( client, bool:flat ) {
	
	decl Float:trace_start[3], Float:trace_angle[3], Float:trace_end[3], Float:trace_normal[3];
	GetClientEyePosition( client, trace_start );
	GetClientEyeAngles( client, trace_angle );
	GetAngleVectors( trace_angle, trace_end, NULL_VECTOR, NULL_VECTOR );
	NormalizeVector( trace_end, trace_end ); // end = normal

	// offset start by near point
	for( new i = 0; i < 3; i++ )
		trace_start[i] += trace_end[i] * 1.0;
	
	for( new i = 0; i < 3; i++ )
		trace_end[i] = trace_start[i] + trace_end[i] * 160.0;
	
	TR_TraceRayFilter( trace_start, trace_end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0 );
	
	if( TR_DidHit( INVALID_HANDLE ) ) {

		TR_GetEndPosition( trace_end, INVALID_HANDLE );
		TR_GetPlaneNormal(INVALID_HANDLE, trace_normal); 
		  
		new Float:norm_angles[3]; 
		GetVectorAngles( trace_normal, norm_angles );
		if( FloatAbs( norm_angles[0] - (270) ) < 30 ) {

			
		} else {
			PrintCenterText( client, "Invalid Surface Angle" );
			return;
		}
		
		
		new Float:ang[3];
		GetClientEyeAngles( client, ang );
		ang[0] = 0.0;
		ang[2] = 0.0;
		
		trace_end[2] += 0.125;
		if( flat ) {
			ang[0] = 90.0;
			trace_end[2] += (1.37*3.0)
		} else {
			
		}
		
		SpawnDomino( trace_end, ang );
		
	} else {
		PrintCenterText( client, "Invalid Location." );
		return;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_domino( client, args ) {
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	
	new bool:flat = false;
	if( args >= 1 ) {
		decl String:arg[64];
		GetCmdArg(1,arg,sizeof arg);
		if( StrEqual(arg, "flat") ) {
			flat = true;
		}
	}
	PlaceDomino(client,flat);
	return Plugin_Handled;
}
