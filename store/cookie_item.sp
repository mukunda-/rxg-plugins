 
#include <sourcemod>
#include <sdktools> 
#include <rxgstore> 

#undef REQUIRE_PLUGIN
#include <tf2use>

#pragma semicolon 1

// 1.1.0
//   increased to 35 hp
// 1.0.2
//   bugfix
// 1.0.1
//   set targetname

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "cookie item",
	author = "mukunda",
	description = "delicious",
	version = "1.1.0",
	url = "www.mukunda.com"
};


#define ITEM_NAME "cookie"
#define ITEM_FULLNAME "cookie"
#define ITEMID 4

new cookie_ents[2048] = {-1,...};

new String:files[][] = {
	"materials/rxg/items/cookie.vtf",
	"materials/rxg/items/cookie.vmt",
	"models/rxg/items/cookie{version}.mdl",
	"models/rxg/items/cookie{version}.dx90.vtx",
	"models/rxg/items/cookie{version}.vvd",
	"models/rxg/items/cookie{version}.phy",
	"sound/rxg/items/cookie.mp3"
};

new String:cookie_model[64] = "models/rxg/items/cookie{version}.mdl";
new String:cookie_sound[64] = "rxg/items/cookie.mp3";
//#define COOKIE_MODEL "models/rxg/items/cookie.mdl"
//#define COOKIE_SOUND "*rxg/items/cookie.mp3"

new Float:cookie_last_use[MAXPLAYERS];
#define COOLDOWN 2.0

#define COOKIE_HP 35
#define COOKIE_HP_TF2 85
#define TF2_COOKIE_SCALE 1.5

new GAME;

#define GAME_CSGO	0
#define GAME_TF2	1

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	
	decl String:gamedir[64];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual(gamedir, "csgo") ) {  
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	if( GAME == GAME_CSGO ) {
		ReplaceString( cookie_model, sizeof cookie_model, "{version}", "" );
		Format( cookie_sound, sizeof cookie_sound, "*%s", cookie_sound );
		HookEvent( "player_use", OnPlayerUse );
	} else {
		
		ReplaceString( cookie_model, sizeof cookie_model, "{version}", "_tf2" );
	}
	
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	RegAdminCmd( "sm_spawncookie", Command_spawncookie, ADMFLAG_RCON ); 
}

//-------------------------------------------------------------------------------------------------
public OnAllPluginsLoaded() {
	if( GAME == GAME_TF2 ) {
		if( !LibraryExists( "tf2use" ) ) {
			SetFailState( "Required Library \"tf2use\" missing!" );
			return;
		}
	}
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( cookie_model );
	PrecacheSound( cookie_sound );
	
	for( new i = 0; i < sizeof files; i++ ) {
		decl String:file[64];
		strcopy( file, sizeof file, files[i] );
		if( GAME == GAME_CSGO ) {
			ReplaceString( file, sizeof file, "{version}", "" );
		} else {
			ReplaceString( file, sizeof file, "{version}", "_tf2" );
		}
		AddFileToDownloadsTable( file );
	}
	
	if( GAME == GAME_TF2 ) {
		AddFileToDownloadsTable( "models/rxg/items/cookie_tf2.dx80.vtx" );
		AddFileToDownloadsTable( "models/rxg/items/cookie_tf2.sw.vtx" );
	}
}

//-------------------------------------------------------------------------------------------------
public bool:OnCookieTouch( client, entity ) {
	new hp = GetClientHealth(client);
	new maxhealth;
	if( GAME == GAME_CSGO ) {
		maxhealth = 100;
	} else {
		maxhealth = GetEntProp( client, Prop_Data, "m_iMaxHealth" );
	}
	
	if( hp >= maxhealth ) {
		if( GAME == GAME_CSGO ) {
			PrintToChat( client, "\x01 \x08You aren't hungry." );
		} else {
			PrintToChat( client, "\x07808080You aren't hungry." );
		}
		return false;
	}
	
	if( FloatAbs( GetGameTime() - cookie_last_use[client] ) < COOLDOWN ) {
		if( GAME == GAME_CSGO ) {
			PrintToChat( client, "\x01 \x08Your mouth is full!" );
		} else {
			PrintToChat( client, "\x07808080Your mouth is full!" );
		}
		return false;
	}
	cookie_last_use[client] = GetGameTime();
	
	hp += (maxhealth * ( GAME == GAME_TF2 ? COOKIE_HP_TF2 : COOKIE_HP )) / 100;
	if( GAME == GAME_CSGO ) {
		if( hp > maxhealth ) hp = maxhealth;
	} else {
		//overheal!
	}
	SetEntityHealth( client, hp );
	
	if( GAME == GAME_CSGO ) {
		PrintToChat( client, "\x01 \x04Mmm... delicious!" );
	} else {
		PrintToChat( client, "\x04Mmm... delicious!" );
	}
	if( GAME == GAME_CSGO ) {
		FadeCookie(entity);
	} else {
		AcceptEntityInput( entity, "kill" );
	}
	
	if( GAME == GAME_TF2 ) {
		decl String:team_color[7];
		new team = GetClientTeam(client);
		
		if( team == 2 ){
			team_color = "ff3d3d";
		} else if ( team == 3 ){
			team_color = "84d8f4";
		}
		
		decl String:name[32];
		GetClientName( client, name, sizeof name );
		
		PrintToChatAll( "\x07%s%s \x07FFD800has eaten a \x07b24115Cookie!", team_color, name );
	}
	
	EmitSoundToAll( cookie_sound, client );
	return true;
}

//-------------------------------------------------------------------------------------------------
public OnPlayerUse( Handle:event, const String:name[],bool:dontBroadcast ) {
	
	new ent = GetEventInt( event, "entity" );
	if( IsValidEntity( cookie_ents[ent] ) ) {
		// this is a cookie!
		new client = GetClientOfUserId( GetEventInt(event, "userid") );
		if( !client ) return;
		
		OnCookieTouch( client, ent );
		
	}
}

//-------------------------------------------------------------------------------------------------
FadeCookie( cookie ) {
	new ent = CreateEntityByName( "prop_dynamic" );
	SetEntityModel( ent, cookie_model );
	SetEntityRenderColor( ent, 128,128,128);
	DispatchSpawn( ent );
	decl Float:pos[3];
	decl Float:ang[3];
	GetEntPropVector( cookie, Prop_Data, "m_vecAbsOrigin", pos );
	GetEntPropVector( cookie, Prop_Data, "m_angAbsRotation", ang );
	AcceptEntityInput( cookie, "kill" );
	
	TeleportEntity( ent, pos, ang, NULL_VECTOR );
	AcceptEntityInput( ent, "FadeAndKill" );
}

//-------------------------------------------------------------------------------------------------
SpawnCookie( Float:vec[3], Float:vel[3] ) {
	new ent = CreateEntityByName( "prop_physics_override" );
	DispatchKeyValue( ent, "targetname", "RXG_COOKIE" );
	SetEntityModel( ent, cookie_model );
	
	if( GAME == GAME_TF2 ){
		SetEntPropFloat( ent, Prop_Data, "m_flModelScale", TF2_COOKIE_SCALE );
	}
	
	if( GAME==GAME_CSGO ){
		SetEntityRenderColor( ent, 128,128,128);
	} else {
		SetEntityRenderColor( ent, 255,255,255);
	}
	
	DispatchKeyValue( ent, "spawnflags", "256" );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	DispatchSpawn( ent );
	cookie_ents[ent] = EntIndexToEntRef( ent );
	TeleportEntity( ent, vec, NULL_VECTOR, vel );
	
	if( GAME == GAME_TF2 ) {
		TF2Use_Hook( ent, OnCookieTouch );
	}
}

//-------------------------------------------------------------------------------------------------
ThrowCookie( client ) {
	decl Float:pos[3];
	GetClientEyePosition( client, pos );
	decl Float:vec[3];
	GetClientEyeAngles( client, vec );
	GetAngleVectors( vec, vec, NULL_VECTOR, NULL_VECTOR );
	vec[2] = 0.0;
	NormalizeVector(vec,vec);
	vec[0] *= 200.0;
	vec[1] *= 200.0;
	vec[2] = 140.0;
	pos[2] -= 20.0;
	for( new i = 0; i < 3; i++ ) {	
		vec[i] += GetRandomFloat( -10.0,10.0);
	}
	SpawnCookie( pos, vec );
}

//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	ThrowCookie(client);
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_spawncookie( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	ThrowCookie(client);
	return Plugin_Handled;
}
