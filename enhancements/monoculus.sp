
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <rxgstore>
#include <tf2_stocks>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Spawn Monoculus",
	author = "WhiteThunder",
	description = "Spawnable Monoculus",
	version = "1.5.1",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
Handle sm_monoculus_max_summon_distance;
Handle sm_monoculus_min_distance_player_spawn;
Handle sm_monoculus_max_spectrals_per_team;
Handle sm_monoculus_boss_base_health;
Handle sm_monoculus_boss_health_per_player_above_threshold;
Handle sm_monoculus_boss_health_player_threshold;
Handle sm_monoculus_boss_max_duration;
Handle sm_monoculus_spectral_summon_cooldown;
Handle sm_monoculus_boss_team_summon_cooldown;
Handle sm_monoculus_boss_enemy_summon_cooldown;

float c_max_summon_distance;
float c_min_distance_player_spawn;
int c_max_spectrals_per_team;
int c_boss_base_health;
int c_boss_health_per_player_above_threshold;
int c_boss_health_player_threshold;
float c_boss_max_duration;
float c_spectral_summon_cooldown;
float c_boss_team_summon_cooldown;
float c_boss_enemy_summon_cooldown;

#define TEAM_BOSS 5
#define VERTICAL_OFFSET 50.0
#define BOSS_COLLISION_DELAY 1.0
#define SPECTRAL_FIXED_DURATION 20.0 //This value does not affect the duration
#define SUMMON_SOUND_COOLDOWN 10.0

float g_client_last_spectral_summon[MAXPLAYERS+1];
float g_red_boss_last_summon;
float g_blu_boss_last_summon;
float g_last_summon;
int g_red_spectral_count;
int g_blu_spectral_count;

int g_client_userid[MAXPLAYERS+1];

int g_spawn_count;
float g_player_spawns[100][3];

//-------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max) {
	CreateNative( "MONO_SpawnMonoculus", Native_SpawnMonoculus );
	RegPluginLibrary("monoculus");
}

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_max_summon_distance = GetConVarFloat( sm_monoculus_max_summon_distance );
	c_min_distance_player_spawn = GetConVarFloat( sm_monoculus_min_distance_player_spawn );
	c_max_spectrals_per_team = GetConVarInt( sm_monoculus_max_spectrals_per_team );
	c_boss_base_health = GetConVarInt( sm_monoculus_boss_base_health );
	c_boss_health_per_player_above_threshold = GetConVarInt( sm_monoculus_boss_health_per_player_above_threshold );
	c_boss_health_player_threshold = GetConVarInt( sm_monoculus_boss_health_player_threshold );
	c_boss_max_duration = GetConVarFloat( sm_monoculus_boss_max_duration );
	c_spectral_summon_cooldown = GetConVarFloat( sm_monoculus_spectral_summon_cooldown );
	c_boss_team_summon_cooldown = GetConVarFloat( sm_monoculus_boss_team_summon_cooldown );
	c_boss_enemy_summon_cooldown = GetConVarFloat( sm_monoculus_boss_enemy_summon_cooldown );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval ) {
	RecacheConvars();
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	sm_monoculus_max_summon_distance = CreateConVar( "sm_monoculus_max_summon_distance", "750", "The maximum distance you may summon a Monoculus away from yourself. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_monoculus_min_distance_player_spawn = CreateConVar( "sm_monoculus_min_distance_player_spawn", "500", "The minimum distance from spawn points Monoculi can be spawned", FCVAR_PLUGIN, true, 0.0 );
	sm_monoculus_max_spectrals_per_team = CreateConVar( "sm_monoculus_max_spectrals_per_team", "2", "The maximum number of Spectral Monoculi allowed per team. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_monoculus_boss_base_health = CreateConVar( "sm_monoculus_boss_base_health", "2000", "The base health the Boss MONOCULUS should have before considering player count.", FCVAR_PLUGIN, true, 1.0, true, 50000.0 );
	sm_monoculus_boss_health_per_player_above_threshold = CreateConVar( "sm_monoculus_boss_health_per_player_above_threshold", "100", "The additional health the Boss MONOCULUS should get per player above the threshold set by sm_monoculus_boss_health_player_threshold.", FCVAR_PLUGIN, true, 0.0, true, 5000.0 );
	sm_monoculus_boss_health_player_threshold = CreateConVar( "sm_monoculus_boss_health_player_threshold", "10", "The number of players required to start adding additional health to the Boss MONOCULUS.", FCVAR_PLUGIN, true, 0.0 );
	sm_monoculus_boss_max_duration = CreateConVar( "sm_monoculus_boss_max_duration", "125", "The maximum duration in seconds that the Boss MONOCULUS should remain in the realm after being summoned.", FCVAR_PLUGIN, true, 30.0, true, 300.0 );
	sm_monoculus_spectral_summon_cooldown = CreateConVar( "sm_monoculus_spectral_summon_cooldown", "60", "The number of seconds you must wait between summoning Spectral Monoculi.", FCVAR_PLUGIN, true, 0.0 );
	sm_monoculus_boss_team_summon_cooldown = CreateConVar( "sm_monoculus_boss_team_summon_cooldown", "180", "The number of seconds your team must wait after summoning the Boss MONOCULUS before summoning him again.", FCVAR_PLUGIN, true, 0.0 );
	sm_monoculus_boss_enemy_summon_cooldown = CreateConVar( "sm_monoculus_boss_enemy_summon_cooldown", "90", "The number of seconds the enemy team must wait to summon the Boss MONOCULUS after your team has summoned him. For best results, set to the value of sm_monoculus_boss_max_duration to prevent more than one at a time.", FCVAR_PLUGIN, true, 0.0 );

	HookConVarChange( sm_monoculus_max_summon_distance, OnConVarChanged );
	HookConVarChange( sm_monoculus_min_distance_player_spawn, OnConVarChanged );
	HookConVarChange( sm_monoculus_max_spectrals_per_team, OnConVarChanged );
	HookConVarChange( sm_monoculus_boss_base_health, OnConVarChanged );
	HookConVarChange( sm_monoculus_boss_health_per_player_above_threshold, OnConVarChanged );
	HookConVarChange( sm_monoculus_boss_health_player_threshold, OnConVarChanged );
	HookConVarChange( sm_monoculus_boss_max_duration, OnConVarChanged );
	HookConVarChange( sm_monoculus_spectral_summon_cooldown, OnConVarChanged );
	HookConVarChange( sm_monoculus_boss_team_summon_cooldown, OnConVarChanged );
	HookConVarChange( sm_monoculus_boss_enemy_summon_cooldown, OnConVarChanged );
	
	RecacheConvars();
	
	RegAdminCmd( "sm_spawnmonoculus", Command_SpawnMonoculus, ADMFLAG_RCON );
	
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheMonoculus();
	findSpawnPoints();
	
	for( int i = 1; i <= MaxClients; i++ ) {
		g_client_last_spectral_summon[i] = -c_spectral_summon_cooldown;
	}
	
	g_red_spectral_count = 0;
	g_blu_spectral_count = 0;
	g_red_boss_last_summon = -c_boss_team_summon_cooldown;
	g_blu_boss_last_summon = -c_boss_team_summon_cooldown;
	g_last_summon = -SUMMON_SOUND_COOLDOWN;
}
//-------------------------------------------------------------------------------------------------
findSpawnPoints() {
	int ent = -1;
	g_spawn_count = 0;
	while( (ent = FindEntityByClassname(ent, "info_player_teamspawn")) != -1){
		GetEntPropVector( ent, Prop_Send, "m_vecOrigin", g_player_spawns[g_spawn_count]);
		g_spawn_count++;
	}
}

//-------------------------------------------------------------------------------------------------
bool NearSpawn( float end[3]){
	float target[3];
	target[0] = end[0];
	target[1] = end[1];
	for( int i = 0; i < g_spawn_count; i++ ) {
		target[2] = end[2] + (end[2] - g_player_spawns[i][2])*2;
		float distance = GetVectorDistance(g_player_spawns[i],target,true);
		if(distance < c_min_distance_player_spawn*c_min_distance_player_spawn){
			return true;
		}
		// if(FloatAbs(g_player_spawns[i][0] - target[0]) < c_min_distance_player_spawn){
			// if(FloatAbs(g_player_spawns[i][1] - target[1]) < c_min_distance_player_spawn){
				// if(FloatAbs(g_player_spawns[i][2] - target[2]) < 75){
					// return true;
				// }
			// }
		// }
	}
	return false;
}
bool SpawnMonoculus( client, TFTeam team ) {

	float time = GetGameTime();
	TFTeam client_team = TFTeam:GetClientTeam(client);

	char team_color[7];
	
	if( client_team == TFTeam_Red ){
		team_color = "ff3d3d";
	} else if ( client_team == TFTeam_Blue ){
		team_color = "84d8f4";
	} else {
		team_color = "874fad";
	}
	
	
	if( team == TFTeam:TEAM_BOSS ) {
		
		float team_next_summon; //Time your team can next summon as a result of your team's recent summon
		float enemy_next_summon; //Time your team can next summon as a result of a recent enemy summon
		
		if( client_team == TFTeam_Red ) {
			team_next_summon = g_red_boss_last_summon + c_boss_team_summon_cooldown;
			enemy_next_summon = g_blu_boss_last_summon + c_boss_enemy_summon_cooldown;
		} else {
			team_next_summon = g_blu_boss_last_summon + c_boss_team_summon_cooldown;
			enemy_next_summon = g_red_boss_last_summon + c_boss_enemy_summon_cooldown;
		}
		
		float next_summon = (team_next_summon > enemy_next_summon) ? team_next_summon : enemy_next_summon;
		
		if( time < team_next_summon && team_next_summon >= enemy_next_summon ) {
			
			PrintToChat( client, "\x07FFD800Your team recently summoned a \x07874FADMONOCULUS! \x07FFD800Please try again in \x073EFF3E%d \x07FFD800seconds.", RoundToCeil(next_summon - time) );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
			
		} else if ( time < enemy_next_summon ) {
			
			PrintToChat( client, "\x07FFD800The other team recently summoned a \x07874FADMONOCULUS! \x07FFD800Please try again in \x073EFF3E%d \x07FFD800seconds.", RoundToCeil(next_summon - time) );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	
	} else {
	
		int userid = GetClientUserId(client);
		
		if( g_client_userid[client] != userid ) {
			//Client index changed hands
			g_client_userid[client] = userid;
			g_client_last_spectral_summon[client] = -c_spectral_summon_cooldown;
		}
		
		if( time < g_client_last_spectral_summon[client] + c_spectral_summon_cooldown ) {
		
			float timeleft = g_client_last_spectral_summon[client] + c_spectral_summon_cooldown - time;
			
			PrintToChat( client, "\x07FFD800Please wait \x073EFF3E%d \x07FFD800seconds before summoning another \x07%sSpectral Monoculus.", RoundToCeil(timeleft), team_color );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
			
		} else if( c_max_spectrals_per_team != 0 && (
					team == TFTeam_Red && g_red_spectral_count >= c_max_spectrals_per_team ||
					team == TFTeam_Blue && g_blu_spectral_count >= c_max_spectrals_per_team ) ) {
			
			PrintToChat( client, "\x07FFD800Your team is only allowed to have \x073EFF3E%d \x07%sSpectral Monoculi \x07FFD800at once. Please try again later.", c_max_spectrals_per_team, team_color );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
			
		}
	}
	
	if( !IsPlayerAlive(client) ){
		PrintToChat( client, "\x07FFD800Cannot summon when dead." );
		return false;
	}
	if( TF2_IsPlayerInCondition(client, TFCond_Cloaked ) ){
		PrintToChat( client, "\x07FFD800Cannot summon when cloaked." );
		return false;
	}
	if( TF2_IsPlayerInCondition(client, TFCond_Disguised ) ){
		PrintToChat( client, "\x07FFD800Cannot summon when disguised." );
		return false;
	}
	
	float start[3];
	float angle[3];
	float end[3];
	float feet[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetClientAbsOrigin( client, feet );
	
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );
	
	if( TR_DidHit() ) {
		float norm[3];
		float norm_angles[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		TR_GetEndPosition( end );

		float distance = GetVectorDistance( feet, end, true );

		if( c_max_summon_distance != 0 && distance > c_max_summon_distance * c_max_summon_distance ) {
			PrintToChat( client, "\x07FFD800Cannot summon that far away." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot summon there." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if( NearSpawn(end) ){
			PrintToChat( client, "\x07FFD800Cannot summon near player spawns." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	}
	
	if( team != TFTeam:TEAM_BOSS ) {
		end[2] += VERTICAL_OFFSET;
	}
	
	int ent = CreateEntityByName("eyeball_boss");
	SetEntProp( ent, Prop_Data, "m_iTeamNum", team );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	
	DispatchSpawn( ent );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
	
	if( team == TFTeam:TEAM_BOSS ) {
		
		CreateTimer( BOSS_COLLISION_DELAY, Timer_ActivateBossCollision, ent );
	
		int player_count = GetClientCount();
		int boss_hp = c_boss_base_health;
		if( player_count > c_boss_health_player_threshold ) {
			boss_hp += (player_count - 10) * c_boss_health_per_player_above_threshold;
		}
		
		SetEntProp( ent, Prop_Data, "m_iMaxHealth", boss_hp );
		SetEntProp( ent, Prop_Data, "m_iHealth", boss_hp );
	}
	
	char name[32];
	GetClientName( client, name, sizeof name );
	
	if( team == TFTeam:TEAM_BOSS ) {
	
		PrintToChatAll( "\x07%s%s \x07FFD800has summoned a \x07874FADMONOCULUS!", team_color, name );
		CreateTimer( c_boss_max_duration, Timer_KillExpiredBossMonoculus, EntIndexToEntRef(ent) );
		
		if( client_team == TFTeam_Red ) {
			g_red_boss_last_summon = time;
		} else {
			g_blu_boss_last_summon = time;
		}
		
		g_last_summon = time;
		
	} else {
	
		PrintToChatAll( "\x07%s%s \x07FFD800has summoned a \x07%sSpectral Monoculus!", team_color, name, team_color );
		CreateTimer( SPECTRAL_FIXED_DURATION, Timer_LowerMonoculusCount, team );
		
		if( client_team == TFTeam_Red ) {
			g_red_spectral_count++;
		} else {
			g_blu_spectral_count++;
		}
		
		if( time >= g_last_summon + SUMMON_SOUND_COOLDOWN ) {
			EmitSoundToAll( "ui/halloween_boss_summoned_fx.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_HOME );
			g_last_summon = time;
		}
		
		g_client_last_spectral_summon[client] = time;
	}
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action Timer_LowerMonoculusCount( Handle timer, any team ) {
	if( team == TFTeam_Red ) {
		g_red_spectral_count--;
	} else if( team == TFTeam_Blue ) {
		g_blu_spectral_count--;
	} else {
		//Spawned via admin command for different team index
		//Do nothing
	}
}

//-------------------------------------------------------------------------------------------------
public Action Timer_KillExpiredBossMonoculus( Handle timer, any boss ) {
	if( IsValidEntity(boss) ) {
		// sometimes they don't go away when they should or we want to kill them early
		AcceptEntityInput( boss, "Kill" );
		PrintToChatAll( "\x07874FADMONOCULUS! \x01has left the realm!" );
	}
}

//-------------------------------------------------------------------------------------------------
public Action Timer_ActivateBossCollision( Handle timer, any boss ) {
	if( IsValidEntity(boss) ) {
		SetEntProp( boss, Prop_Send, "m_CollisionGroup", 0 );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Native_SpawnMonoculus( Handle plugin, numParams ) {
	int client = GetNativeCell(1);
	TFTeam team = GetNativeCell(2);
	return SpawnMonoculus( client, team );
}

//-------------------------------------------------------------------------------------------------
public Action Command_SpawnMonoculus( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	int team;
	
	if( args > 0 ) {
		char team_arg[12];
		GetCmdArg( 1, team_arg, sizeof team_arg );
		team = StringToInt(team_arg);
	} else {
		team = GetClientTeam(client);
	}
	
	SpawnMonoculus( client, TFTeam:team );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public bool TraceFilter_All( entity, contentsMask ) {
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
