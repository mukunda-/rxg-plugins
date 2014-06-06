
#include <sourcemod>
#include <sdktools>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Spawn Monoculus",
	author = "WhiteThunder",
	description = "Spawnable Monoculus",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define MIN_DISTANCE 100.0
#define MAX_DISTANCE 750.0
#define VERTICAL_OFFSET 50.0

#define TEAM_BOSS 5
#define MAX_MONOCULUS_COUNT 5
#define SUMMON_SOUND_COOLDOWN 10.0

#define MONOCULUS_BOSS_WAIT_TIMER 60.0
#define MONOCULUS_SPECTRAL_WAIT_TIMER 20.0
#define MONOCULUS_BOSS_EXPIRE_TIMER 150.0

new bool:g_sound_playing = false;
new g_monoculus_count;

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative( "MONO_SpawnMonoculus", Native_SpawnMonoculus );
	RegAdminCmd( "sm_spawnmonoculus", Command_SpawnMonoculus, ADMFLAG_RCON );
	RegPluginLibrary("monoculus");
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheMonoculus();
}

//-------------------------------------------------------------------------------------------------
public Native_SpawnMonoculus( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new team = GetNativeCell(2);
	return SpawnMonoculus( client, team );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_SpawnMonoculus( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	new team = 0;
	
	if( args > 0 ) {
		new String:team_arg[12];
		GetCmdArg( 1, team_arg, sizeof team_arg );
		team = StringToInt(team_arg);
	}
	
	SpawnMonoculus( client, team );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
bool:SpawnMonoculus( client, team ) {
	
	if( g_monoculus_count >= MAX_MONOCULUS_COUNT ) {
		PrintToChat( client, "\x07FFD800There are too many Monoculi. Please try again later." );
		RXGSTORE_ShowUseItemMenu(client);
		return false;
	}
	
	decl Float:start[3], Float:angle[3], Float:end[3], Float:feet[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetClientAbsOrigin( client, feet );
	
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );
	
	if( TR_DidHit() ) {
		decl Float:norm[3], Float:norm_angles[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		TR_GetEndPosition( end );

		new Float:distance = GetVectorDistance( feet, end, true );

		if( distance < MIN_DISTANCE * MIN_DISTANCE ) {
			PrintToChat( client, "\x07808080Cannot summon that close." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if( distance > MAX_DISTANCE * MAX_DISTANCE ) {
			PrintToChat( client, "\x07808080Cannot summon that far away." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07808080Cannot summon there." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	}
	
	end[2] += VERTICAL_OFFSET;
	
	new ent = CreateEntityByName("eyeball_boss");
	SetEntProp( ent, Prop_Data, "m_iTeamNum", team );
	
	if( team == TEAM_BOSS ) {
		DispatchKeyValue( ent, "targetname", "RXG_MONOCULUS" );
	}
	
	DispatchSpawn( ent );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
	
	decl String:team_color[7];
	new client_team = GetClientTeam(client);
	
	if( client_team == 2 ){
		team_color = "ff3d3d";
	} else if( client_team == 3 ){
		team_color = "84d8f4";
	}
	
	decl String:name[32];
	GetClientName( client, name, sizeof name );
	
	if( team == TEAM_BOSS ) {
		PrintToChatAll( "\x07%s%s \x07FFD800has summoned a \x07874FADMONOCULUS!", team_color, name );
		CreateTimer( MONOCULUS_BOSS_WAIT_TIMER, Timer_LowerMonoculusCount );
		CreateTimer( MONOCULUS_BOSS_EXPIRE_TIMER, Timer_KillExpiredBossMonoculus, EntIndexToEntRef(ent) );
	} else {
		PrintToChatAll( "\x07%s%s \x07FFD800has summoned a \x07%sSpectral Monoculus!", team_color, name, team_color );
		CreateTimer( MONOCULUS_SPECTRAL_WAIT_TIMER, Timer_LowerMonoculusCount );
		
		if( !g_sound_playing ) {
			EmitSoundToAll( "ui/halloween_boss_summoned_fx.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
			g_sound_playing = true;
			CreateTimer( SUMMON_SOUND_COOLDOWN, Timer_EnableSounds );
		}
	}
	
	g_monoculus_count++;
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_EnableSounds( Handle:timer ) {
	g_sound_playing = false;
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_LowerMonoculusCount( Handle:timer ) {
	g_monoculus_count--;
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_KillExpiredBossMonoculus( Handle:timer, any:boss ) {
	if( IsValidEntity( boss ) ) { // sometimes they don't go away when they should
		AcceptEntityInput( boss, "Kill" );
	}
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
PrecacheMonoculus() {

	PrecacheModel( "models/props_halloween/halloween_demoeye.mdl", true );
	PrecacheModel( "models/props_halloween/eyeball_projectile.mdl", true );

	PrecacheSound( "vo/halloween_eyeball/eyeball_biglaugh01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_boss_pain01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_laugh03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_mad03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball_teleport01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball01.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball02.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball03.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball04.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball05.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball06.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball07.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball08.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball09.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball10.wav", true );
	PrecacheSound( "vo/halloween_eyeball/eyeball11.wav", true );

	PrecacheSound( "ui/halloween_boss_summon_rumble.wav", true);
	PrecacheSound( "ui/halloween_boss_chosen_it.wav", true );
	PrecacheSound( "ui/halloween_boss_defeated_fx.wav", true );
	PrecacheSound( "ui/halloween_boss_defeated.wav", true );
	PrecacheSound( "ui/halloween_boss_player_becomes_it.wav", true );
	PrecacheSound( "ui/halloween_boss_summoned_fx.wav", true );
	PrecacheSound( "ui/halloween_boss_summoned.wav", true );
	PrecacheSound( "ui/halloween_boss_tagged_other_it.wav", true );
	PrecacheSound( "ui/halloween_boss_escape.wav", true );
	PrecacheSound( "ui/halloween_boss_escape_sixty.wav", true );
	PrecacheSound( "ui/halloween_boss_escape_ten.wav", true );
	PrecacheSound( "ui/halloween_boss_tagged_other_it.wav", true );
}
