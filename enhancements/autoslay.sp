
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

// 1.1.1
//  dont slay cts when bomb doenst get defused (could allow griefing)
// 1.1.0
//   defuse map support
//

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "autoslay",
	author = "REFLEX-GAMERS",
	description = "auto slay vaginas",
	version = "1.1.3",
	url = "www.reflex-gamers.com"
};

new kill_counters[MAXPLAYERS+1];

new g_bloodstain;
new g_physbeam;

new slaylist[MAXPLAYERS+1];
new slaycount;
new slaytimer;

new round=0;

#define SOUND7 "player/headshot1.wav"
#define SOUND8 "player/headshot2.wav"

public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {
	CreateNative( "Autoslay_ExplodePlayer", Native_ExplodePlayer );
	RegPluginLibrary( "autoslay" );
}


//-------------------------------------------------------------------------------------------------
public Native_ExplodePlayer( Handle:plugin, numParams ) {
	ExplodePlayer( GetNativeCell(1) );

}
//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "player_death", Event_PlayerDeath );
	HookEvent( "round_end", Event_RoundEnd );
//	RegConsoleCmd( "autoslay_test", Command_test );
}

public OnMapStart() {
	PrecacheModel( "models/gibs/hgibs.mdl" );
	PrecacheSound( SOUND7 );
	PrecacheSound( SOUND8 );
	PrecacheSound( "*rxg/autoslay4.mp3" );
	AddFileToDownloadsTable( "sound/rxg/autoslay4.mp3" );
	g_bloodstain = PrecacheDecal( "decals/bloodstain_002" );// "materials/sprites/bloodspray.vmt" );
	g_physbeam = PrecacheModel( "materials/sprites/physbeam.vmt" );
	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_test( client, args ) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof(arg) );
	new target = FindTarget(client,arg);
	if(target==-1)return Plugin_Handled;
	ExplodePlayer(target);
	return Plugin_Handled;
}

//------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		kill_counters[i] = 0;
	}
	round++;
	
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	new CSRoundEndReason:reason = CSRoundEndReason:GetEventInt( event, "reason" );
	if( reason == CSRoundEnd_HostagesRescued ) {
		SlaySurvivors( CS_TEAM_T, "\x01 \x02Slaying terrorists for letting the hostage escape." );
	} else if( reason == CSRoundEnd_HostagesNotRescued ) {
		SlaySurvivors( CS_TEAM_CT, "\x01 \x02Slaying counter-terrorists for not rescuing the hostage." );
	} else if( reason == CSRoundEnd_TargetSaved ) {
		SlaySurvivors( CS_TEAM_T, "\x01 \x02Slaying terrorists for not planting the bomb." );
	}
//      else if( reason == CSRoundEnd_TargetBombed ) {
//		SlaySurvivors( CS_TEAM_CT, "\x01 \x02Slaying counter-terrorists for not defusing the bomb." );
//	}
//	else if( reason == CSRoundEnd_BombDefused ) {
		// should this happen ?
//		SlaySurvivors( CS_TEAM_T, "\x01 \x02Slaying terrorists for not protecting the bomb." );
//	}
}

//----------------------------------------------------------------------------------------------------------------------
SlaySurvivors( team, const String:reason[] ) {
	slaytimer = 0;
	slaycount = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		if( GetClientTeam(i) != team ) continue;
		if( kill_counters[i] >= 3 ) continue;
		
		slaylist[slaycount++] = GetClientUserId(i);
	}
	
	if( slaycount > 0 ) {
		if( team == 2 ) {
			PrintToChatAll( reason );// );
		} else if( team == 3 ) {
			PrintToChatAll( reason );// );
		}
		CreateTimer( 1.0, StartSlay ,round);
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:StartSlay( Handle:timer, any:data ) {
	if( data != round ) return Plugin_Handled;
	CreateTimer( 0.2, SlayTimer, round, TIMER_REPEAT );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:SlayTimer( Handle:timer, any:data ) {
	if( data != round ) return Plugin_Stop;
	if( slaytimer >= slaycount )return Plugin_Stop;
	new client = GetClientOfUserId( slaylist[slaytimer++] );
	if( client != 0 ) ExplodePlayer( client );
	if( slaytimer == slaycount ) {
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
BloodSquirt( Float:origin[3], Float:dir[3], Float:length ) {
	
	new Float:end[3];
	for( new i = 0; i < 3; i++ ) {
		end[i] = origin[i] + dir[i] * length;
	}
	TR_TraceRayFilter( origin, end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0 );
	if( TR_DidHit( INVALID_HANDLE ) ) {

		TR_GetEndPosition( end, INVALID_HANDLE );

		TE_Start( "World Decal" );
		TE_WriteVector( "m_vecOrigin", end );
		TE_WriteNum( "m_nIndex", g_bloodstain );
		TE_SendToAll();
		
		
	}
 
}

//----------------------------------------------------------------------------------------------------------------------
SpawnSkull(client) {
	new Float:vec[3];
	new Float:vel[3];
	new Float:ang[3];
	new Float:v = 100.0;
	vel[0] = GetRandomFloat( -v, v );
	vel[1] = GetRandomFloat( -v, v );
	vel[2] = 200.0+GetRandomFloat( 0.0, v );

	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );
	GetClientEyePosition(client,vec);
	
	new ent = CreateEntityByName( "prop_physics_override" );
	
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	DispatchKeyValue(ent, "model", "models/gibs/hgibs.mdl");
	DispatchSpawn(ent);
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2); // set non-collidable
	
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);   
	
	TeleportEntity( ent, vec, ang, vel);
}

//----------------------------------------------------------------------------------------------------------------------
Beam( const Float:pos[3] ) {
	decl Float:a[3], Float:b[3];
	for( new i = 0; i < 3; i++ ) {
		a[i] = b[i] = pos[i];
	}
	a[2] -= 32.0;
	b[2] += 128.0;

	new color[4] = {255,255,255,255};
	TE_SetupBeamPoints( a, b, g_physbeam, 0, 0, 30, 0.5, 8.0, 8.0, 0, 50.0, color, 25 );
	
	TE_SendToAll();
}

//----------------------------------------------------------------------------------------------------------------------
ExplodePlayer( client ) {
	if( !IsClientInGame(client) ) return;
	if( !IsPlayerAlive(client) ) return;
	
	
	new Float:pos[3];
	GetClientAbsOrigin( client, pos );
	
	pos[2] += 32.0;
	
	CreateExplosion( pos );
	
	// klil player
	ForcePlayerSuicide(client);

	new ent = GetEntPropEnt(client,Prop_Send,"m_hRagdoll");
	SetEntPropEnt(client,Prop_Send,"m_hRagdoll",-1);
	AcceptEntityInput(ent,"kill");
	
	for( new i = 0; i <= 20; i++ ) {
		decl Float:dir[3];
		dir[0] = GetRandomFloat( -1.0, 1.0 );
		dir[1] = GetRandomFloat( -1.0, 1.0 );
		dir[2] = GetRandomFloat( -1.0, 1.0 );
		BloodSquirt( pos, dir, 300.0  );


	}
	Beam(pos);
	
	
	EmitSoundToAll( SOUND7, client );
	EmitSoundToAll( SOUND8, client );
	EmitSoundToAll( "*rxg/autoslay4.mp3", client, _, SNDLEVEL_RAIDSIREN );
	SpawnSkull( client );
	
}

//----------------------------------------------------------------------------------------------------------------------
public CreateExplosion( Float:vec[3] ) {
	new ent = CreateEntityByName("env_explosion");	
 
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",0); 
 
	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}

//------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new attacker = GetClientOfUserId(GetEventInt( event, "attacker" ));
	new victim = GetClientOfUserId(GetEventInt( event, "userid" ));
	if( attacker == 0 || victim == 0 ) return;
	if( attacker == victim ) return;
	kill_counters[attacker]++;
}
