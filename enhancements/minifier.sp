
#include <sourcemod>
#include <sdktools>

//#include <sdkhooks>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "minifier",
	author = "mukunda",
	description = "minifies maps when low on players",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
new Handle:sm_minifier_players;
new Handle:sm_minifier_config;

new Handle:kv_config = INVALID_HANDLE; 

new String:mapname[64];

new bool:system_enabled;

new bool:round_start_hooked = false;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	sm_minifier_players = CreateConVar( "sm_minifier_players", "12", "Threshold of players that disables minifier.", FCVAR_PLUGIN );
	sm_minifier_config = CreateConVar( "sm_minifier_config", "minifier.txt", "Filename of minifier config, relative to /configs/", FCVAR_PLUGIN );
	
	RegServerCmd( "sm_minifier_reload", Command_reload, "Reload minifier config" );
	
//	HookAllClients();
}
/*
//----------------------------------------------------------------------------------------------------------------------
public OnWeaponDrop( client, weapon ) {
	decl String:name[64];
	GetEntityClassname( weapon, name, sizeof(name) );
	if (StrEqual( name, "weapon_c4" ) ) {
		PrintToServer("minifier found weapon c4 being dropped");
		//FlagBomb(weapon);
		CreateTimer( 0.01, FlagBombTimer, _, TIMER_FLAG_NO_MAPCHANGE );
	}
}

//----------------------------------------------------------------------------------------------------------------------
HookClient(client) {
	SDKHook( client, SDKHook_WeaponDropPost, OnWeaponDrop );
}

//----------------------------------------------------------------------------------------------------------------------
HookAllClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			HookClient(i);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer(client) {
	HookClient(client);
}
*/
//----------------------------------------------------------------------------------------------------------------------
PrecacheProps() {

	if( !KvJumpToKey( kv_config, "props" ) ) return false;
	
	new found;
	
	if( !KvGotoFirstSubKey( kv_config ) ) return false; // no items!
	
	do {
		decl String:model[128];
		
		KvGetString( kv_config, "model", model, sizeof(model) );
		if( model[0] != 0 ) {
			
			PrecacheModel( model );
			found++;
		}
	} while( KvGotoNextKey( kv_config ) );
	KvGoBack( kv_config ); // exit prop data
	KvGoBack( kv_config ); // exit props
	
	return found != 0;
}

//----------------------------------------------------------------------------------------------------------------------
bool:PrepareMapData() {
	
	new players = KvGetNum( kv_config, "player_threshold", -1 );
	if( players != -1 ) {
		SetConVarInt( sm_minifier_players, players );
	}
	
	if( PrecacheProps() ) { // returns true if one or more props are found
		system_enabled = true;
		return true;
	} else {
		LogMessage( "Notice: no prop data found for %s", mapname );
		return false;
	}
	
}

//----------------------------------------------------------------------------------------------------------------------
public LoadPropList() {

	system_enabled = false;
	GetCurrentMap( mapname, sizeof(mapname) );
	
	if( kv_config != INVALID_HANDLE ) {
		CloseHandle( kv_config );
		kv_config = INVALID_HANDLE;
	}
	kv_config = CreateKeyValues( "Minifier" );
	
	// search file for map
	decl String:filepath[256], String:file[64];
		
	GetConVarString( sm_minifier_config, file, sizeof(file) );
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/%s", file );
	
	if( FileExists(filepath) ) {
		if( !FileToKeyValues( kv_config, filepath ) ) {
			SetFailState( "Couldn't Load Config" );
		}
	} else {
		SetFailState( "Datafile Not Found: %s", filepath );
		return;
	}
	PrintToServer( "Debug Minifier: Searching for map..." );
	KvGotoFirstSubKey(kv_config);
	do {
		
		decl String:name[64];
		KvGetSectionName( kv_config, name, sizeof(name) );
		PrintToServer( "Debug Minifier:   Found '%s' (searching for '%s')", name, mapname );
		if( StrEqual( name, mapname ) ) {
			PrintToServer( "Debug Minifier: Found map!" );
			// found map
			system_enabled = PrepareMapData();
			break;
		}

	} while( KvGotoNextKey( kv_config ) );
	
	
	if( system_enabled ) {
		if( !round_start_hooked ) HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
		round_start_hooked = true;
	} else {
		if( round_start_hooked ) UnhookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
		round_start_hooked = false;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_reload( args ) {
	
	LoadPropList();
	PrintToServer( "Reloaded minifier config!" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	
	LoadPropList();
	
	
}

//----------------------------------------------------------------------------------------------------------------------
SetupProps() {
	
	PrintToServer( "Debug Minifier: SetupProps()" );
	if( !KvJumpToKey( kv_config, "props" ) ) return false;
	
	PrintToServer( "Debug Minifier:   entered props" );
	
	decl String:model[128];
	decl String:position[128];
	decl String:type[64];
	decl String:bbox[64];
	decl String:spawnflags[32];
	new movetype;
	
	if( !KvGotoFirstSubKey( kv_config ) ) {
		KvGoBack( kv_config );
		return false;
	}
	PrintToServer( "Debug Minifier:   entered prop data" );
	
	do {
		
		KvGetString( kv_config, "model", model, sizeof(model) );
		KvGetString( kv_config, "position", position, sizeof(position) );
		KvGetString( kv_config, "type", type, sizeof(type) );
		KvGetString( kv_config, "bbox", bbox, sizeof(bbox) );
		PrintToServer(" debug AAA %s", bbox );
		movetype = KvGetNum( kv_config, "move", 6 );
		KvGetString( kv_config, "spawnflags", spawnflags, sizeof(spawnflags) );
		
		if( type[0] == 0 ) {
			LogError( "Type not specified" );
			break; // error
		}
		//PrintToServer( "position string = %s", position );
		
		decl Float:pos[3], Float:ang[3];
		decl Float:f_bbox[6];
		new bool:use_bbox;
		
		decl String:arg[32];
		new positer;
		
		if( bbox[0] != 0 ) {
			for( new i = 0; i < 6; i++ ) {
				if( positer == -1 ) {
					SetFailState( "Error parsing bbox in config" );
					return false;
				}
				positer += BreakString( bbox[positer], arg, sizeof(arg) );
				f_bbox[i] = StringToFloat( arg );
			}
			use_bbox = true;
		
			positer = 0;
		}
		
		for( new i = 0; i < 3; i++ ) {
			if( positer == -1 ) {
				SetFailState( "Error parsing position in config" );
				return false;
			}
			positer += BreakString( position[positer], arg, sizeof(arg) );
			pos[i] = StringToFloat( arg );
		}
		
		for( new i = 0; i < 3; i++ ) {
			if( positer == -1 ) {
				SetFailState( "Error parsing position in config" );
				return false;
			}
			positer += BreakString( position[positer], arg, sizeof(arg) );
			ang[i] = StringToFloat( arg );
		}
		
		decl String:classname[64];
		Format( classname, sizeof(classname), "prop_%s", type );
		
		new ent = CreateEntityByName( classname );
		if( ent == -1 ) {
			LogError( "Couldn't create entity" );
			break; // error
		}
		
		decl String:targetname[64];
		KvGetSectionName( kv_config, targetname, sizeof(targetname) );
		Format( targetname, sizeof(targetname), "minifier_%s", targetname );
		
		PrintToServer( "Creating Prop: %s", targetname );
		PrintToServer( "  model=%s", model );
		PrintToServer( "  position = %.2f, %.2f, %.2f", pos[0], pos[1], pos[2] );
		PrintToServer( "  rotation = %.2f, %.2f, %.2f", ang[0], ang[1], ang[2] );
		PrintToServer( "  type = %s", classname );
		
		
		if( spawnflags[0] != 0 )
			DispatchKeyValue( ent, "spawnflags", spawnflags );
		DispatchKeyValue( ent, "targetname", targetname );
		DispatchKeyValue( ent, "physdamagescale", "0.0" );
		DispatchKeyValue( ent, "model", model );
		DispatchSpawn( ent );
		TeleportEntity( ent, pos, ang, NULL_VECTOR );
		SetEntityMoveType( ent, MoveType:movetype );
		
		if( use_bbox ) {
			SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test
			//SetEntProp( ent, Prop_Send, "m_CollisionGroup", 4 ); // something to do with bounding box test
			new Float:vec[3];
			vec[0] = f_bbox[0]; vec[1] = f_bbox[1]; vec[2] = f_bbox[2];
			SetEntPropVector( ent, Prop_Send, "m_vecMins", vec );
			vec[0] = f_bbox[3]; vec[1] = f_bbox[4]; vec[2] = f_bbox[5];
			SetEntPropVector( ent, Prop_Send, "m_vecMaxs", vec );
			
			PrintToServer( "  using bounding box: %.2f %.2f %.2f, %.2f %.2f %.2f", f_bbox[0],f_bbox[1],f_bbox[2],f_bbox[3],f_bbox[4],f_bbox[5] );
			
			
			//SetEntProp( ent, Prop_Send, "m_usSolidFlags", 0x80); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
		}
		
	} while( KvGotoNextKey( kv_config ) );
	
	KvGoBack( kv_config ); // exit props data
	KvGoBack( kv_config ); // exit props
	
	return true;
}
/* FUCK IT.

/// Find the C4 entity and give it a bounding box so people cant lose it 
FlagBomb( ent ) {

	if( ent == -1 ) return;
	
	PrintToServer( "Debug Minifier: flagging bomb %d", ent );
	
	new Float:vec[3] = {-20.0,-20.0,-20.0};
	new Float:vec2[3] = {-20.0,-20.0,-20.0};
	SetEntProp( ent, Prop_Send, "m_nSolidType",2 );
	SetEntPropVector( ent, Prop_Send, "m_vecMins", vec );
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", vec2 );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup",0);
	SetEntProp( ent, Prop_Send, "m_usSolidFlags", 0); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	//SetEntityMoveType( ent, MOVETYPE_NONE );
	
}

public Action:FlagBombTimer( Handle:timer, any:data ) {
	//FlagBomb( data );
	return Plugin_Handled;
}*/

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	if( !system_enabled ) {
		SetFailState( "(Assert) round_start should not be hooked while system is disabled." );
		return;
	}
	
	new players = GetTeamClientCount(2) + GetTeamClientCount(3);
	new threshold = GetConVarInt(sm_minifier_players);
	if( players >= threshold ) {
		return ;
	}
	
	PrintToChatAll( "[SM] Under %d players; certain areas will be blocked.", threshold );
	
	SetupProps();
	//FlagBomb();
	
	
}



