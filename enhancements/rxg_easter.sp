
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <tf2_stocks>
#include <rxgcommon>
#include <dbrelay>
#include <rxgstore>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Reflex Easter Egg Hunt",
	author = "Roker",
	description = "Pickup dem eggs",
	version = "1.3.0",
	url = "www.reflex-gamers.com"
};

char files[][] = {
	"materials/models/props_easteregg/c_easteregg.vtf",
	"materials/models/props_easteregg/c_easteregg.vmt",
	"materials/models/props_easteregg/c_easteregg_gold.vmt",
	"models/player/saxton_hale/w_easteregg{version}.mdl",
	"models/player/saxton_hale/w_easteregg{version}.dx90.vtx",
	"models/player/saxton_hale/w_easteregg{version}.vvd",
	"models/player/saxton_hale/w_easteregg{version}.phy",
	"sound/rxg/items/egg_sound.mp3"
};
char egg_model[64] = "models/player/saxton_hale/w_easteregg{version}.mdl";
char egg_sound[64] = "rxg/items/egg_sound.mp3";

char item_color[24];
char initial_space[24];

Handle sm_easter_egg_scale;
Handle sm_easter_egg_chance;
Handle sm_easter_eggs_per_round;

float c_easter_egg_scale;
float c_easter_egg_chance;
int c_easter_eggs_per_round;

Handle kv;
int spawn_count;

int GAME;

#define GAME_CSGO	0
#define GAME_TF2	1

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_easter_egg_scale = GetConVarFloat( sm_easter_egg_scale );
	c_easter_egg_chance = GetConVarFloat( sm_easter_egg_chance );
	c_easter_eggs_per_round = GetConVarInt( sm_easter_eggs_per_round );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval ) {
	RecacheConvars();
}

//-----------------------------------------------------------------------------
public OnPluginStart() {
	char gamedir[64];
	GetGameFolderName( gamedir, sizeof gamedir );
	
	if( StrEqual( gamedir, "csgo" ) ) {  
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	if( GAME == GAME_CSGO ) {
		ReplaceString( egg_model, sizeof egg_model, "{version}", "_csgo3" );
		Format( egg_sound, sizeof egg_sound, "*%s", egg_sound );
	} else {
		ReplaceString( egg_model, sizeof egg_model, "{version}", "" );
	}
	
	item_color = GAME == GAME_TF2 ? "\x07874fad" : "\x03";
	initial_space = GAME == GAME_CSGO ? "\x01 " : "\x01";
	
	HookEvent("player_death", Event_Player_Death, EventHookMode_Pre);
	
	sm_easter_egg_scale = CreateConVar( "sm_easter_egg_scale", "1", "Scale of easter egg model.", FCVAR_PLUGIN, true, 0.1 );
	sm_easter_egg_chance = CreateConVar( "sm_easter_egg_chance", "0.2", "Chance for an easter egg to drop.", FCVAR_PLUGIN, true, 0.05 );
	sm_easter_eggs_per_round = CreateConVar( "sm_easter_eggs_per_round", "5", "Number of eggs to randomly spawn each round.", FCVAR_PLUGIN, true, 1.0 );
	
	HookConVarChange( sm_easter_egg_scale, OnConVarChanged );
	HookConVarChange( sm_easter_egg_chance, OnConVarChanged );
	HookConVarChange( sm_easter_eggs_per_round, OnConVarChanged );
	RecacheConvars();
	
	RegServerCmd( "sm_easter_reload_config", Command_ReloadConfig );
	RegAdminCmd( "sm_spawnegg", Command_SpawnEgg, ADMFLAG_SLAY );
	RegAdminCmd( "sm_geteggpos", Command_GetEgggPosition, ADMFLAG_SLAY );
	
	if( GAME == GAME_CSGO ) {
		HookEvent( "player_use", OnPlayerUse );
		HookEvent( "round_start", Event_RoundStart );
	}
	
	LoadConfigFile();
}

//-----------------------------------------------------------------------------
public LoadConfigFile() {
	
	if( kv != INVALID_HANDLE ) {
		CloseHandle( kv );
	}
	
	char filepath[128];
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/easter_egg_spawns.txt" );
	
	kv = CreateKeyValues( "EggSpawns" );
	
	if( !FileExists( filepath ) ) {
		CloseHandle( kv );
		kv = INVALID_HANDLE;
		return;
	}
	
	if( !FileToKeyValues( kv, filepath ) ) {
		CloseHandle( kv );
		kv = INVALID_HANDLE;
		return;
	}
	
	KvRewind( kv );
	KvGotoFirstSubKey( kv );
	
	spawn_count = 0;
	
	do {
		spawn_count++;
	} while( KvGotoNextKey( kv ) );
}

//-----------------------------------------------------------------------------
public Action Command_ReloadConfig( args ) {
	LoadConfigFile();
}

//-----------------------------------------------------------------------------
public Event_RoundStart( Handle event, const char[] name, bool dontBroadcast ) {
	if( kv == INVALID_HANDLE ) {
		return;
	}
	
	for( int i = 0; i < c_easter_eggs_per_round; i++ ) {
		SpawnRandomEgg();
	}
	
	PrintToChatAll( "\x01 \x04%i easter eggs have spawned this round. Go find them!", c_easter_eggs_per_round );
}

//-----------------------------------------------------------------------------
public GetRandomSpawn( float pos[3], float ang[3] ) {
	int spawn_index = GetRandomInt(1, spawn_count);
	char spawn_string[8];
	IntToString( spawn_index, spawn_string, sizeof spawn_string );
	
	KvRewind( kv );
	KvJumpToKey( kv, spawn_string );
	KvGetVector( kv, "pos", pos );
	KvGetVector( kv, "ang", ang );
}

//-----------------------------------------------------------------------------
public SpawnRandomEgg() {
	float pos[3];
	float ang[3];
	GetRandomSpawn( pos, ang );
	SpawnEgg( pos, ang );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( egg_model );
	PrecacheSound( egg_sound );
	
	for( new i = 0; i < sizeof files; i++ ) {
		decl String:file[64];
		strcopy( file, sizeof file, files[i] );
		
		if( GAME == GAME_CSGO ) {
			ReplaceString( file, sizeof file, "{version}", "_csgo3" );
		} else {
			ReplaceString( file, sizeof file, "{version}", "" );
		}
		
		AddFileToDownloadsTable( file );
	}
	
	if( GAME == GAME_TF2 ) {
		AddFileToDownloadsTable( "models/player/saxton_hale/w_easteregg.dx80.vtx" );
		AddFileToDownloadsTable( "models/player/saxton_hale/w_easteregg.sw.vtx" );
	}
}

//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	int killer = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	if( killer != client && GetClientCount() > 6 ) {
		if( GetRandomFloat(0.0, 1.0) < c_easter_egg_chance ) {
			DropEgg(client);
		}
	}
}

//-----------------------------------------------------------------------------
public Action Command_GetEgggPosition( client, args ) {

	float start[3];
	float angle[3];
	float end[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_Egg );

	if( TR_DidHit() ) {
		float norm[3];
		float norm_angles[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		
		int ent = TR_GetEntityIndex();
		
		TR_GetEndPosition( end );
		
		char entname[64];
		GetEntPropString( ent, Prop_Data, "m_iName", entname, sizeof(entname) );
		
		if ( !StrEqual( entname, "RXG_EGG" ) ) {
			PrintToChat( client, "no egg found" );
			return Plugin_Handled;
		}
		
		float egg_position[3];
		float egg_angle[3];
		GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", egg_position );
		GetEntPropVector( ent, Prop_Data, "m_angAbsRotation", egg_angle );
		
		PrintToChat( client, "\"pos\" \"%f %f %f\"", egg_position[0], egg_position[1], egg_position[2] );
		PrintToConsole( client, "\"pos\" \"%f %f %f\"", egg_position[0], egg_position[1], egg_position[2] );
		PrintToChat( client, "\"ang\" \"%f %f %f\"", egg_angle[0], egg_angle[1], egg_angle[2] );
		PrintToConsole( client, "\"ang\" \"%f %f %f\"", egg_angle[0], egg_angle[1], egg_angle[2] );
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public bool TraceFilter_Egg( int entity, int contentsMask ) {
	char entname[64];
	GetEntPropString( entity, Prop_Data, "m_iName", entname, sizeof(entname) );
	return ( StrEqual( entname, "RXG_EGG" ) );
}

//-----------------------------------------------------------------------------
public Action Command_SpawnEgg( client, args ) {

	if( !RXGSTORE_IsConnected() ) {
		ReplyToCommand( client, "Store is not connected yet." );
		return Plugin_Handled;
	}
	
	DropEgg( client );
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public DropEgg( int client ) {

	float pos[3];
	GetClientEyePosition( client, pos );
	SpawnEgg( pos, NULL_VECTOR );
}

//-----------------------------------------------------------------------------
public SpawnEgg( float pos[3], float ang[3] ) {
	
	int ent = CreateEntityByName( "prop_physics_override" );
	DispatchKeyValue( ent, "targetname", "RXG_EGG" );
	SetEntityModel( ent, egg_model );
	
	if( c_easter_egg_scale != 1.0 ) {
		SetEntPropFloat( ent, Prop_Data, "m_flModelScale", c_easter_egg_scale );
	}
	
	DispatchKeyValue( ent, "spawnflags", "256" );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	DispatchSpawn( ent );
	
	TeleportEntity( ent, pos, ang, NULL_VECTOR );
	
	if( GAME == GAME_TF2 ) {
		AddTrigger( ent );
	}
}

//-----------------------------------------------------------------------------
AddTrigger( int parent ) {
	
	int ent = CreateEntityByName( "trigger_once" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", parent );
	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "StartDisabled", "1" );
	
	DispatchSpawn(ent);
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", parent );
	AcceptEntityInput( ent, "Disable" );
	
	SetEntityModel( ent, egg_model );
	
	float minbounds[3] = {-33.0, -33.0, -33.0};
	float maxbounds[3] = {33.0, 33.0, 33.0};
	SetEntPropVector( ent, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", maxbounds);


	SetEntProp( ent, Prop_Send, "m_usSolidFlags", 4|8 |0x400 ); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test

	int enteffects = GetEntProp( ent, Prop_Send, "m_fEffects" );
	enteffects |= 32;
	SetEntProp( ent, Prop_Send, "m_fEffects", enteffects );

	float pos[3];
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	SDKHook( ent, SDKHook_Touch, EggTouched_TF2 );
	return ent;
}

//-----------------------------------------------------------------------------
public Action EggTouched_TF2( int entity, int client ) {
	RedeemEgg( client, entity );
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public OnPlayerUse( Handle event, const char[] name, bool dontBroadcast ) {  
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client <= 0 ) return;
	int ent = GetEventInt( event, "entity" );
	char entname[64];
	GetEntPropString( ent, Prop_Data, "m_iName", entname, sizeof(entname) );
	if( !StrEqual( entname, "RXG_EGG" ) ) return;
	RedeemEgg( client, ent );
}

//-------------------------------------------------------------------------------------------------
public bool RedeemEgg( int client, int entity ) { 

	if( !IsValidClient(client) || IsFakeClient(client) ) return false;
	if( !givePrize(client) ) return false;
	eggDB(client);
	
	EmitSoundToAll( egg_sound, client );
	
	if( GAME == GAME_TF2 ) {
		// get trigger parent
		entity = GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" );
	}
	
	AcceptEntityInput( entity, "Kill" );
	return true;
}

//-----------------------------------------------------------------------------
bool givePrize( client ) {

	int random = GetRandomInt(0, 5000);
	int itemID = -1;
	char itemName[64];
	bool bigItem = false;
	int cashDropped = 0;
	char clientName[64];
	
	GetClientName( client, clientName, sizeof clientName );
	
	if( GAME == GAME_CSGO ) {
		if( random <= 1 && RXGSTORE_IsItemRegistered(5) ) {
			//nuke
			itemName = "Nuke";
			itemID = 5;
		} else if( random <= 250 && RXGSTORE_IsItemRegistered(13) ) {
			//negev
			itemName = "AWP";
			itemID = 13;
		} else if( random <= 500 && RXGSTORE_IsItemRegistered(3) ) {
			//negev
			itemName = "Negev";
			itemID = 3;
		} else if( random <= 1000 && RXGSTORE_IsItemRegistered(2) ) {
			//radio
			itemName = "Disposable Radio";
			itemID = 2;
		} else if( random <= 2500 && RXGSTORE_IsItemRegistered(4) ) {
			//cookie
			itemName = "Cookie";
			itemID = 4;
		} else if( random <= 3500 && RXGSTORE_IsItemRegistered(7) ) {
			//chicken
			itemName = "Chicken";
			itemID = 7;
		} else {
			
			cashDropped = GetRandomInt(50, 150);
			
			if(!RXGSTORE_AddCash( client,  cashDropped)){
				LogError("Tried to give %s %i cash. Failed.", clientName, cashDropped);
				return false;
			}
			
			PrintToChat( client, "You found \x04$%i \x01in an easter egg!", cashDropped );
		}
	}
	
	if( GAME == GAME_TF2 ) {
		if( random <= 50 && RXGSTORE_IsItemRegistered(12) ) {
			//time warp
			itemName = "Time Warp";
			itemID = 12;
		} else if( random <= 175 && RXGSTORE_IsItemRegistered(8) ) {
			//boss monoculus
			itemName = "Boss Monoculus";
			itemID = 8;
		} else if( random <= 425 && RXGSTORE_IsItemRegistered(10) ) {
			//roman candle
			itemName = "Roman Candle";
			itemID = 10;
		} else if( random <= 675 && RXGSTORE_IsItemRegistered(11) ) {
			//fire cracker
			itemName = "Fire Cracker";
			itemID = 11;
		} else if( random <= 1175 && RXGSTORE_IsItemRegistered(9) ) {
			//spectral monoculus
			itemName = "Spectral Monoculus";
			itemID = 9;
		} else if( random <= 1675 && RXGSTORE_IsItemRegistered(4) ) {
			//cookie
			itemName = "Cookie";
			itemID = 4;
		}else if( random <= 2500 && RXGSTORE_IsItemRegistered(14) ) {
			//skeleton
			itemName = "Skeleton";
			itemID = 14;
		}else if( random <= 3875 && RXGSTORE_IsItemRegistered(6) ) {
			//pumpkin
			itemName = "Pumpkin Bomb";
			itemID = 6;
		}else {
			cashDropped = GetRandomInt(100, 200);
			if( !RXGSTORE_AddCash( client,  cashDropped) ) {
				LogError("Tried to give %s %i cash. Failed.", clientName, cashDropped);
				return false;
			}
			
			PrintToChat( client, "%sYou found \x04$%i \x01in an easter egg!", initial_space, cashDropped );
		}
	}
	
	if( itemID != -1 ) {
	
		if( !RXGSTORE_GiveItem( client, itemID ) ) {
			LogError("Tried to give %s item '%s' with ID %i. Failed.", clientName, itemName, itemID);
			return false;
		}
		
		bigItem = ( random <= 50 );
		
		if( bigItem ) {
			PrintCenterTextAll( "%s%s has just found a %s in an Easter Egg!!!", initial_space, clientName, itemName );
		} else {
			PrintCenterText( client, "You found a %s store item!", itemName );
		}
		
		PrintToChat( client, "%sYou found a %s%s \x01in an Easter Egg. Type \x04!useitem \x01to use it.", initial_space, item_color, itemName );
	}
	
	itemDropDB(client,itemID,cashDropped);
	return true;
}

//-----------------------------------------------------------------------------
itemDropDB( client, itemID, cashDropped ) {

	if( DBRELAY_IsConnected() ) {
	
	    int account = GetSteamAccountID(client);
	    if( account == 0 ){ return; }
	    
	    int val = 1;
	    char query[1024];
	    
	    if( itemID == -1 ){
	    	val = cashDropped;
	    }
	    
	    FormatEx( query, sizeof query, "INSERT INTO sourcebans_easter.drops( account, item, count ) VALUES ( %i, %i, %i ) ON DUPLICATE KEY UPDATE count = count + %i", account, itemID, val , val );
	    
	    DBRELAY_TQuery( IgnoredSQLResult, query );
	 }
}

//-----------------------------------------------------------------------------
eggDB( client ) {

	if( DBRELAY_IsConnected() ) {
		int account = GetSteamAccountID(client);
		if( account == 0 ){ return; }
		
		char query[1024];
		FormatEx( query, sizeof query, "INSERT INTO sourcebans_easter.players( account, egg_count ) VALUES ( %i, %i ) ON DUPLICATE KEY UPDATE egg_count = egg_count + 1", account, 1 );
		DBRELAY_TQuery( IgnoredSQLResult, query );
	}
}

//-----------------------------------------------------------------------------
public IgnoredSQLResult( Handle owner, Handle hndl, const char [] error, any data ) {
    if( !hndl ) {
        LogError( "SQL Error --- %s", error );
        return;
    }
}