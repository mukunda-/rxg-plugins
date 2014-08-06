
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Spawn Monoculus",
	author = "WhiteThunder",
	description = "Spawnable Monoculus",
	version = "1.3.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define MIN_DISTANCE 100.0
#define MAX_DISTANCE 750.0
#define VERTICAL_OFFSET 50.0

#define TEAM_BOSS 5
#define BOSS_BASE_HEALTH 4000
#define BOSS_HEALTH_PER_PLAYER_ABOVE_THRESHOLD 200
#define BOSS_HEALTH_PLAYER_THRESHOLD 10
#define BOSS_COLLISION_DELAY 1.0

#define MAX_SPECTRALS_PER_TEAM 2
#define SPECTRAL_FIXED_DURATION 20.0 //This value does not affect the duration

#define BOSS_EXPIRE_TIMER 125.0
#define SPECTRAL_SUMMON_COOLDOWN 60.0
#define BOSS_TEAM_SUMMON_COOLDOWN 300.0
#define BOSS_ENEMY_SUMMON_COOLDOWN 125.0 //Prevents enemy team from spawning this long after your team
#define SUMMON_SOUND_COOLDOWN 10.0

new Float:g_client_last_spectral_summon[MAXPLAYERS+1];
new Float:g_red_boss_last_summon;
new Float:g_blu_boss_last_summon;
new Float:g_last_summon;
new g_red_spectral_count;
new g_blu_spectral_count;

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative( "MONO_SpawnMonoculus", Native_SpawnMonoculus );
	RegAdminCmd( "sm_spawnmonoculus", Command_SpawnMonoculus, ADMFLAG_RCON );
	RegPluginLibrary("monoculus");
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheMonoculus();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_last_spectral_summon[i] = -SPECTRAL_SUMMON_COOLDOWN;
	}
	
	g_red_spectral_count = 0;
	g_blu_spectral_count = 0;
	g_red_boss_last_summon = -BOSS_TEAM_SUMMON_COOLDOWN;
	g_blu_boss_last_summon = -BOSS_TEAM_SUMMON_COOLDOWN;
	g_last_summon = -SUMMON_SOUND_COOLDOWN;
}

//-------------------------------------------------------------------------------------------------
bool:SpawnMonoculus( client, TFTeam:team ) {

	new Float:time = GetGameTime();
	new TFTeam:client_team = TFTeam:GetClientTeam(client);

	decl String:team_color[7];
	
	if( client_team == TFTeam_Red ){
		team_color = "ff3d3d";
	} else {
		team_color = "84d8f4";
	}
	
	if( team == TFTeam:TEAM_BOSS ) {
		
		new Float:team_next_summon; //Time your team can next summon as a result of your team's recent summon
		new Float:enemy_next_summon; //Time your team can next summon as a result of a recent enemy summon
		
		if( client_team == TFTeam_Red ) {
			team_next_summon = g_red_boss_last_summon + BOSS_TEAM_SUMMON_COOLDOWN;
			enemy_next_summon = g_blu_boss_last_summon + BOSS_ENEMY_SUMMON_COOLDOWN;
		} else {
			team_next_summon = g_blu_boss_last_summon + BOSS_TEAM_SUMMON_COOLDOWN;
			enemy_next_summon = g_red_boss_last_summon + BOSS_ENEMY_SUMMON_COOLDOWN;
		}
		
		new Float:next_summon = (team_next_summon > enemy_next_summon) ? team_next_summon : enemy_next_summon;
		
		if( time < team_next_summon && team_next_summon >= enemy_next_summon ) {
			
			PrintToChat( client, "\x07FFD800Your team recently summoned a \x07874FADMONOCULUS! \x07FFD800Please try again in \x073EFF3E%d \x07FFD800seconds.", RoundToCeil(next_summon - time) );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
			
		} else if ( time < enemy_next_summon ) {
			
			PrintToChat( client, "\x07FFD800The other team recently summoned a \x07874FADMONOCULUS! \x07FFD800Please try again in \x073EFF3E%d \x07FFD800seconds.", RoundToCeil(next_summon - time) );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	
	} else if( time < g_client_last_spectral_summon[client] + SPECTRAL_SUMMON_COOLDOWN ) {
		
		new Float:timeleft = g_client_last_spectral_summon[client] + SPECTRAL_SUMMON_COOLDOWN - time;
		
		PrintToChat( client, "\x07FFD800Please wait \x073EFF3E%d \x07FFD800seconds before summoning another \x07%sSpectral Monoculus.", RoundToCeil(timeleft), team_color );
		RXGSTORE_ShowUseItemMenu(client);
		return false;
		
	} else if( team == TFTeam_Red && g_red_spectral_count >= MAX_SPECTRALS_PER_TEAM ||
				team == TFTeam_Blue && g_blu_spectral_count >= MAX_SPECTRALS_PER_TEAM ) {
		
		PrintToChat( client, "\x07FFD800Your team is only allowed to have \x073EFF3E%d \x07%sSpectral Monoculi \x07FFD800at once. Please try again later.", MAX_SPECTRALS_PER_TEAM, team_color );
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

		if( distance > MAX_DISTANCE * MAX_DISTANCE ) {
			PrintToChat( client, "\x07FFD800Cannot summon that far away." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot summon there." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	}
	
	if( team != TFTeam:TEAM_BOSS ) {
		end[2] += VERTICAL_OFFSET;
	}
	
	new ent = CreateEntityByName("eyeball_boss");
	SetEntProp( ent, Prop_Data, "m_iTeamNum", team );
	
	if( team == TFTeam:TEAM_BOSS ) {
		DispatchKeyValue( ent, "targetname", "RXG_MONOCULUS" );
	} else {
		SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	}
	
	DispatchSpawn( ent );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
	
	if( team == TFTeam:TEAM_BOSS ) {
		
		CreateTimer( BOSS_COLLISION_DELAY, Timer_ActivateBossCollision, ent );
	
		new player_count = GetClientCount();
		new boss_hp = BOSS_BASE_HEALTH;
		if( player_count > BOSS_HEALTH_PLAYER_THRESHOLD ) {
			boss_hp += (player_count - 10) * BOSS_HEALTH_PER_PLAYER_ABOVE_THRESHOLD;
		}
		
		SetEntProp( ent, Prop_Data, "m_iMaxHealth", boss_hp );
		SetEntProp( ent, Prop_Data, "m_iHealth", boss_hp );
	}
	
	decl String:name[32];
	GetClientName( client, name, sizeof name );
	
	if( team == TFTeam:TEAM_BOSS ) {
	
		PrintToChatAll( "\x07%s%s \x07FFD800has summoned a \x07874FADMONOCULUS!", team_color, name );
		CreateTimer( BOSS_EXPIRE_TIMER, Timer_KillExpiredBossMonoculus, EntIndexToEntRef(ent) );
		
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
public Action:Timer_LowerMonoculusCount( Handle:timer, any:team ) {
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
public Action:Timer_KillExpiredBossMonoculus( Handle:timer, any:boss ) {
	if( IsValidEntity(boss) ) {
		// sometimes they don't go away when they should or we want to kill them early
		AcceptEntityInput( boss, "Kill" );
		PrintToChatAll( "\x07874FADMONOCULUS! \x01has left the realm!" );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_ActivateBossCollision( Handle:timer, any:boss ) {
	if( IsValidEntity(boss) ) {
		SetEntProp( boss, Prop_Send, "m_CollisionGroup", 0 );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Native_SpawnMonoculus( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new TFTeam:team = GetNativeCell(2);
	return SpawnMonoculus( client, team );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_SpawnMonoculus( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	new team;
	
	if( args > 0 ) {
		new String:team_arg[12];
		GetCmdArg( 1, team_arg, sizeof team_arg );
		team = StringToInt(team_arg);
	} else {
		team = GetClientTeam(client);
	}
	
	SpawnMonoculus( client, TFTeam:team );
	return Plugin_Handled;
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
