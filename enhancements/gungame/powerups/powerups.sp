
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <powerups>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Powerups",
    author      = "mukunda",
    description = "Provides powerups API",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

#define MAXSPAWNS 64
#define MAXPICKUPS 10
#define MIN_DIST_FROM_PLAYERS 5.0 //debug 250.0

#define MONEY_MODEL "models/props/cs_assault/money.mdl"


//#define TESTMODEL  "models/chicken/chicken.mdl"


enum {
	
	PC_INFO=1,
	PC_MODEL,
	PC_START,
	PC_STOP,
	PC_UPDATE,
	PC_FADING,
	PC_END,
	PC_ONGIVEDAMAGE,
	PC_ONTAKEDAMAGE,
	
	PC_PICKUPSPAWNED,
	PC_PICKUPUPDATE,
	PC_PICKUPTAKEN,
	PC_PICKUPEND,
	
	PC_TOTAL
};
/*
enum {
	POWERUP_EFFECT,
	POWERUP_CUSTOM
};*/

new Handle:use_forward;

//-------------------------------------------------------------------------------------------------
new Float:spawn_positions[MAXSPAWNS][3];
new spawn_count;
new bool:used_spawns[MAXSPAWNS];

new Handle:gg_powerups_interval;
new Handle:gg_powerups_count;
new Handle:gg_powerups_pickuptime;
new Float:c_powerups_interval;
new c_powerups_count;
new Float:c_powerups_pickuptime;

//-------------------------------------------------------------------------------------------------
new pickup_locations[MAXPICKUPS];
new pickup_type[MAXPICKUPS];
new pickup_active[MAXPICKUPS];
new pickup_ents[MAXPICKUPS];
new pickup_state[MAXPICKUPS];
new Handle:pickup_userdata[MAXPICKUPS];
new pickup_trigger_parents[2048];
new Float:pickup_time[MAXPICKUPS];
new Float:next_pickup_spawn_time;

new UserMsg:g_FadeUserMsgId;

//-------------------------------------------------------------------------------------------------
new client_powerup_active[MAXPLAYERS+1]; // 0 = not active, 1..x = powerup type active
new Handle:client_powerup_plugin[MAXPLAYERS+1];
new client_powerup_state[MAXPLAYERS+1]; // CPS*
new Float:client_powerup_time[MAXPLAYERS+1]; // start of updates or start of fade, depending on state
new Float:client_powerup_fade[MAXPLAYERS+1]; // duration of powerup fade
enum {
	CPS_ACTIVE,
	CPS_FADING
};
new Handle:client_powerup_data[MAXPLAYERS+1] = {INVALID_HANDLE,...}; // userdata used by plugin
new client_last_buttons[MAXPLAYERS+1];
new client_status_box_serial[MAXPLAYERS+1];
//-------------------------------------------------------------------------------------------------

new Float:player_location_cache[MAXPLAYERS+1][3];
new bool:player_ingame_cache[MAXPLAYERS+1] ;
//-------------------------------------------------------------------------------------------------
new Handle:plugin_list; // list of powerup plugins, and their functions
new Handle:plugin_names;

//-------------------------------------------------------------------------------------------------
new mat_halosprite;
new mat_fatlaser;
new mat_glowsprite;

POWERUP_CALL(type,index){
	
	Call_StartFunction( GetArrayCell( plugin_list, type-1 ), GetArrayCell( plugin_list, type-1, index ) );
}

bool:POWERUP_FUNCTION_EXISTS( type, index ) {
	return (view_as<Function>GetArrayCell( plugin_list, type-1, index )) != INVALID_FUNCTION;
}

CachePluginFunctions( i, Handle:plugin ) {
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_Info" ), PC_INFO );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_Model" ), PC_MODEL );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_Start" ), PC_START );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_Stop" ), PC_STOP );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_Update" ), PC_UPDATE );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_Fading" ), PC_FADING );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_End" ), PC_END );
	
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_OnGiveDamage" ), PC_ONGIVEDAMAGE );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_OnTakeDamage" ), PC_ONTAKEDAMAGE );
	
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_PickupSpawned" ), PC_PICKUPSPAWNED );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_PickupUpdate" ), PC_PICKUPUPDATE );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_PickupTaken" ), PC_PICKUPTAKEN );
	SetArrayCell( plugin_list, i, view_as<int>GetFunctionByName( plugin, "PC_PickupEnd" ), PC_PICKUPEND );
	
}

//-------------------------------------------------------------------------------------------------
public Native_Register( Handle:plugin, numParams ) {
	decl String:name[64];
	
	
	GetNativeString( 1, name, sizeof(name) );
	
	
	for( new i = 0; i < GetArraySize( plugin_list ); i++ ) {
		decl String:str[64];
		GetArrayString( plugin_names, i, str, sizeof str );
		if( StrEqual( str, name ) ) {
			SetArrayCell( plugin_list, i, plugin );
			CachePluginFunctions( i, plugin );
			
			return i+1;
		}
	}
	
	PushArrayString( plugin_names, name );
	PushArrayCell( plugin_list, plugin );
	CachePluginFunctions( GetArraySize(plugin_list)-1, plugin );	
	return GetArraySize(plugin_list)-1+1;
}

#define FFADE_IN			0x0001		// Just here so we don't pass 0 into the function
#define FFADE_OUT			0x0002		// Fade out (not in)
#define FFADE_MODULATE		0x0004		// Modulate (don't blend)
#define FFADE_STAYOUT		0x0008		// ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE			0x0010		// Purges all other fades, replacing them with this one

public Native_ColorOverlay( Handle:plugin, numParams ) {
	new client = GetNativeCell( 1 );
	new color[4];
	GetNativeArray( 2, color, 4 );
	new bool:modulate = GetNativeCell( 3 );
	new bool:clear=GetNativeCell(4);
	
	// Screen Fade Effect
	new clients[2];
	clients[0] = client;
	new duration2 = 512;
	new holdtime = 512;

	new flags = FFADE_STAYOUT|(clear?FFADE_PURGE:0)| (modulate?FFADE_MODULATE:0);
	
	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration2);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	} else {
		BfWriteShort( message, duration2 );
		BfWriteShort( message, holdtime );
		BfWriteShort( message, flags );
		for( new i = 0; i < 4; i++ )
			BfWriteByte( message, color[i] );
	}
	EndMessage();
	
}

public Native_ColorFlash( Handle:plugin, numParams ) {
	new client = GetNativeCell( 1 );
	new color[4];
	GetNativeArray( 2, color, 4 );
	new holdtime = RoundToNearest( Float:GetNativeCell(3) * 512.0);
	new duration = RoundToNearest( Float:GetNativeCell(4) * 512.0);
	new bool:modulate = GetNativeCell( 5 );
	new bool:clear=GetNativeCell(6);
	
	// Screen Fade Effect
	new clients[2];
	clients[0] = client;

	new flags = FFADE_IN|(clear?FFADE_PURGE:0)| (modulate?FFADE_MODULATE:0);
	
	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration );
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	} else {
		BfWriteShort( message, duration );
		BfWriteShort( message, holdtime );
		BfWriteShort( message, flags );
		for( new i = 0; i < 4; i++ )
			BfWriteByte( message, color[i] );
	}
	EndMessage();
	
}


public Native_GetClientData( Handle:plugin, numParams ) {
	new client = GetNativeCell( 1 );
	return _:client_powerup_data[client];
}

//public Native_SetClientData( Handle:plugin, numParams ) {
//	new client = GetNativeCell( 1 );
//	SetPowerupUserdata( client, GetNativeCell(2) );
//}

public Native_IsPowerupActive( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	return ( client_powerup_active[client] && 
			  client_powerup_state[client] == CPS_ACTIVE &&
			  client_powerup_plugin[client] == plugin );
	
	
}

public Native_HookUse(Handle:plugin, numParams)
{
	AddToForward( use_forward, plugin, Function:GetNativeCell(1));
}

ShowStatusBox(  client, const String:color[], const String:name[], const String:duration[], Float:percent, serial ) {
	if( serial == client_status_box_serial[client] ) return;
	client_status_box_serial[client] = serial;
	
	decl String:bar[128];
	new String:block[] = "█";
	new write = 0;
	new barlen = Lerpcl( 0, 40,percent );
	for( ; barlen >= 2; barlen-=2 ) {
		bar[write++] = block[0];
		bar[write++] = block[1];
		bar[write++] = block[2];
	}
	bar[write++]= 0 ;
	if( barlen > 0 ) {
		StrCat( bar, sizeof bar, "▌" );
	}
	PrintHintText( client, "<font color=\"#%s\" size=\"32\">%s: </font><font size=\"32\">%s\n</font><font color=\"#%s\" size=\"24\">%s</font>", color,name,duration,color,bar);
}

ShowStatusBoxSeconds(  client, const String:color[], const String:name[], Float:seconds, Float:percent, serial ) {
	decl String:duration[64];
	FormatEx( duration, sizeof duration, "%.1fs", seconds );
	if( serial == -1 ) serial = RoundToFloor(seconds*10.0);
	ShowStatusBox( client, color, name, duration, percent, serial );
}

public Native_ShowStatusBoxSeconds( Handle:plugin, numParams ) {
	decl String:color[64];
	decl String:name[64];
	GetNativeString( 2, color, sizeof color );
	GetNativeString( 3, name, sizeof name );
	ShowStatusBoxSeconds( GetNativeCell(1), color, name, Float:GetNativeCell(4), Float:GetNativeCell( 5 ), GetNativeCell( 6 ) );
}

public Native_ShowStatusBox( Handle:plugin, numParams ) {
	decl String:color[64];
	decl String:name[64];
	decl String:duration[64];
	
	GetNativeString( 2, color, sizeof color );
	GetNativeString( 3, name, sizeof name );
	GetNativeString( 4, duration, sizeof duration );
	
	ShowStatusBox( GetNativeCell(1), color, name, duration, Float:GetNativeCell( 5 ), GetNativeCell( 6 ) );
}

public Native_ShowStatusBoxExpired( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	decl String:color[64];
	decl String:name[64];
	GetNativeString( 2, color, sizeof color );
	GetNativeString( 3, name, sizeof name );
	
	PrintHintText( client, "<font color=\"#%s\" size=\"32\">%s: </font><font size=\"32\">EXPIRED</font>", color,name  );
}

public APLRes:AskPluginLoad2( Handle:myself, bool:late, String:error[], err_max ) {
	CreateNative( "PWR_Register", Native_Register );
	CreateNative( "PWR_ColorOverlay", Native_ColorOverlay );
	CreateNative( "PWR_ColorFlash", Native_ColorFlash );
	CreateNative( "PWR_GetClientData", Native_GetClientData );
//	CreateNative( "PWR_SetClientData", Native_SetClientData );
	CreateNative( "PWR_IsPowerupActive", Native_IsPowerupActive );
	
	CreateNative("PWR_HookUse", Native_HookUse);
	
	CreateNative( "PWR_ShowStatusBox", Native_ShowStatusBox );
	CreateNative( "PWR_ShowStatusBoxSeconds", Native_ShowStatusBoxSeconds );
	CreateNative( "PWR_ShowStatusBoxExpired", Native_ShowStatusBoxExpired );
	
	RegPluginLibrary( "powerups" );
}



//new Handle:debug_test;
//-------------------------------------------------------------------------------------------------
public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if( convar == gg_powerups_interval ) {
		c_powerups_interval = GetConVarFloat( gg_powerups_interval );
		next_pickup_spawn_time = GetGameTime() + c_powerups_interval;
	} else if( convar == gg_powerups_count ) {
		c_powerups_count = GetConVarInt( gg_powerups_count );
	} else if( convar == gg_powerups_pickuptime ) {
		c_powerups_pickuptime = GetConVarFloat( gg_powerups_pickuptime );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	use_forward = CreateForward( ET_Ignore, Param_Cell );
	g_FadeUserMsgId = GetUserMessageId("Fade");
	SetupPE();
	plugin_list = CreateArray( PC_TOTAL );
	plugin_names = CreateArray( 16 );
	
//	debug_test = CreateConVar( "debug_test", "0" );
	
	gg_powerups_interval = CreateConVar( "gg_powerups_interval", "60.0", "Rate at which powerups spawn in seconds, 0=disabled", FCVAR_PLUGIN );
	gg_powerups_count = CreateConVar( "gg_powerups_count", "2", "How many powerups spawn at a time (0=disabled)", FCVAR_PLUGIN );
	gg_powerups_pickuptime = CreateConVar( "gg_powerups_pickuptime", "30.0", "How long pickups last", FCVAR_PLUGIN );
	HookConVarChange( gg_powerups_interval, OnConVarChanged );
	HookConVarChange( gg_powerups_count, OnConVarChanged );
	HookConVarChange( gg_powerups_pickuptime, OnConVarChanged );
	c_powerups_interval = GetConVarFloat( gg_powerups_interval );
	c_powerups_count = GetConVarInt( gg_powerups_count );
	c_powerups_pickuptime = GetConVarFloat( gg_powerups_pickuptime );
	
	RegAdminCmd( "gg_powerups_editor", Command_PowerupEditor, ADMFLAG_RCON );
	
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		HookClient(i);
	}
}

//-------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	client_powerup_active[client] = false;
}


//-------------------------------------------------------------------------------------------------
GetConfigFilePath( String:path[], maxlen ) {
	decl String:map[64];
	GetCurrentMap( map, sizeof map );
	FormatEx( path, maxlen, "cfg/gungame/powerups/%s.txt", map );
}

//-------------------------------------------------------------------------------------------------
CreateConfigDir() {
	new DPERMS = ((FPERM_O_READ|FPERM_O_EXEC)|(FPERM_G_EXEC|FPERM_G_READ)|(FPERM_U_EXEC|FPERM_U_WRITE|FPERM_U_READ));

	if( !DirExists( "cfg/gungame" ) ) {
		CreateDirectory( "cfg/gungame", DPERMS );
	}
	if( !DirExists( "cfg/gungame/powerups" ) ) {
		CreateDirectory( "cfg/gungame/powerups", DPERMS );
	}
}

//-------------------------------------------------------------------------------------------------
LoadConfig() {
	spawn_count = 0;
	decl String:configfile[256];
	GetConfigFilePath( configfile, sizeof configfile );
	if( !FileExists( configfile ) ) {
		return;
	}
	
	new Handle:kv = CreateKeyValues( "PowerupConfig" );
	if( !FileToKeyValues( kv, configfile ) ) {
		LogError( "Error loading powerup config: %s", configfile );
		CloseHandle(kv);
		return;
	}
	
	if( !KvJumpToKey( kv, "Spawns" ) ) {
		// no spawn points in config
		CloseHandle(kv);
		return;
	}
	if( !KvGotoFirstSubKey( kv,false ) ) {
		CloseHandle(kv);
		return;
	}
	
	do {
		new Float:pos[3];
		new Float:def[3] = {9000.0,9000.0,9000.0};
		KvGetVector( kv, NULL_STRING, pos, def );
		if( pos[0] == def[0] && pos[1] == def[1] && pos[2] == def[2] ) {
			continue; // bad value?
		}
		if( spawn_count == MAXSPAWNS ) {
			LogError( "File has too many spawn points (max %d) - %s", MAXSPAWNS, configfile );
			break;
		}
		for( new i = 0; i < 3; i++ ) 
			spawn_positions[spawn_count][i] = pos[i];
		spawn_count++;
		
	} while( KvGotoNextKey(kv,false) );
	
	CloseHandle(kv);
	return;
}

//-------------------------------------------------------------------------------------------------
bool:SaveConfig() {
	CreateConfigDir();
	new Handle:kv = CreateKeyValues( "PowerupConfig" );
	KvJumpToKey( kv, "Spawns",  true );
	for( new i = 0; i < spawn_count; i++ ) {
		decl String:indexstring[32];
		FormatEx( indexstring, sizeof indexstring, "%d", i+1 );
		KvSetVector( kv, indexstring, spawn_positions[i] );
	}
	KvRewind(kv);
	decl String:configfile[256];
	GetConfigFilePath( configfile, sizeof configfile );
	new bool:result=KeyValuesToFile( kv, configfile );
	CloseHandle( kv );
	return result;
}


//-------------------------------------------------------------------------------------------------
// POWERUP EDITOR
//-------------------------------------------------------------------------------------------------

new bool:admins_currently_editing[MAXPLAYERS+1];
new Float:pe_admin_activity_time[MAXPLAYERS+1];
new Handle:pe_update_timer = INVALID_HANDLE;
new Handle:pe_menu = INVALID_HANDLE;

#define PE_UPDATE_INTERVAL 0.5
#define PE_PLACEMENT_Z_OFFSET 5.0
#define PE_TIMEOUT 120.0
#define PE_TIMEOUTI 120

PE_ErasePickups() {
	for( new i = 0; i < MAXPICKUPS; i++ ) {
		DeletePickup(i);
	}
}

//-------------------------------------------------------------------------------------------------
PE_ShowMenu( client ) {
	DisplayMenu( pe_menu, client, PE_TIMEOUTI );
	admins_currently_editing[client] = true;
	StartPeTimer();
	pe_admin_activity_time[client] = GetGameTime();
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	
	return false;
}
/*
//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_Clients( entity, contentsMask ) {
	return true;
	return ( entity >= 1 && entity <= MaxClients );
}*/

//-------------------------------------------------------------------------------------------------
bool:GetClientPointedLocation( client, Float:vec[3], bool:flatonly ) {
	new Float:start[3];
	new Float:angle[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );

	new bool:valid_location;
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		new Float:norm[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		new Float:norm_angles[3];
		GetVectorAngles( norm, norm_angles );

		if( FloatAbs( norm_angles[0] - (270) ) < 30 ) {

			valid_location = true;
		}
			
		TR_GetEndPosition( vec );
	} else {
		return false;
	}
	
	if( flatonly && !valid_location ) {
		
		return false;
	}
	return true;
}

//-------------------------------------------------------------------------------------------------
PE_AddSpawn( client ) {

	PE_ErasePickups();
	
	if( spawn_count == MAXSPAWNS ) {
		PrintToChat( client, "\x01 \x04[PE]\x01 Cannot add spawn; limit reached (%d).", MAXSPAWNS );
		return;
	}
	
	decl Float:vec[3];
	if( !GetClientPointedLocation( client, vec, true ) ) {
		PrintToChat( client, "\x01 \x04[PE]\x01 Invalid location." );
		return;
	}
	
	vec[2] += PE_PLACEMENT_Z_OFFSET;
	
	for( new i = 0; i < 3; i++ ) 
		spawn_positions[spawn_count][i] = vec[i];
	
	spawn_count++;
	PrintToChat( client, "\x01 \x04[PE]\x01 Added spawn at {%.1f, %.1f, %.1f}", vec[0], vec[1], vec[2] ); 
	
	
	new clients[MAXPLAYERS+1];
	new count = PE_BuildClientList(clients);
	new color[4] = {15 ,128,25,255};
	TE_SetupBeamRingPoint( vec, 200.0, 20.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 3.0, 0.0, color, 10, 0);
	TE_Send( clients, count );
}

//-------------------------------------------------------------------------------------------------
PE_FindNearestSpawn( const Float:point[3], Float:max ) {
	new best_find = -1;
	new Float:distance = max*max;
	
	for( new i = 0; i < spawn_count; i++ ) {
		new Float:d = GetVectorDistance( point, spawn_positions[i], true );
		if( d < distance ) {
			best_find = i;
			distance = d;
		}
	}
	return best_find;
}

//-------------------------------------------------------------------------------------------------
PE_RemoveSpawn( client ) {

	PE_ErasePickups();
	
	decl Float:point[3];
	if( !GetClientPointedLocation( client, point, false ) ) {
		PrintToChat( client, "\x01 \x04[PE]\x01 Invalid location." );
		return;
	}
	
	new best_find = PE_FindNearestSpawn( point, 100.0 );
	
	if( best_find == -1 ) {
		PrintToChat( client, "\x01 \x04[PE]\x01 No spawn at location." );
		return;
	}
	
	for( new i = 0; i < 3; i++ ) point[i] = spawn_positions[best_find][i];
	 
	PrintToChat( client, "\x01 \x04[PE]\x01 Removed spawn at {%.1f, %.1f, %.1f}", point[0], point[1], point[2] );
	
	for( new i = best_find; i < spawn_count-1; i++ ) {
		for( new j = 0; j < 3; j++ ) {
			spawn_positions[i][j] = spawn_positions[i+1][j];
		}
	}
	spawn_count--;
	
	new clients[MAXPLAYERS+1];
	new count = PE_BuildClientList(clients);
	new color[4] = {128 ,5,25,255};
	TE_SetupBeamRingPoint( point, 200.0, 20.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 3.0, 0.0, color, 10, 0);
	TE_Send( clients, count );
	TE_SetupBeamRingPoint( point, 300.0, 20.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 3.0, 0.0, color, 10, 0);
	TE_Send( clients, count, 0.25 );
}

//-------------------------------------------------------------------------------------------------
PE_TeleportToNext( client ) {
	decl Float:point[3];
	GetClientAbsOrigin( client, point );
	
	if( spawn_count == 0 ) {
		PrintToChat( client, "\x01 \x04[PE]\x01 No spawns exist." );
		return;
	}
	
	new best_find = PE_FindNearestSpawn( point, 100000.0 );
	if( best_find == -1 ) {
		best_find = 0;
	} else {
		best_find = (best_find + 1) % spawn_count;
	}
	
	new Float:zero[3];
	
	new Float:pos[3];
	for( new i = 0; i < 3; i++ )
		pos[i] = spawn_positions[best_find][i];
	pos[2] += 25.0;
	TeleportEntity( client, pos, NULL_VECTOR, zero );
	PrintToChat( client, "\x01 \x04[PE]\x01 Teleported to spawn at {%.1f, %.1f, %.1f}", 
		spawn_positions[best_find][0], 
		spawn_positions[best_find][1],
		spawn_positions[best_find][2]);
		
}

//-------------------------------------------------------------------------------------------------
bool:PE_SaveChanges( client ) {
	PrintToChatAll( "\x01 \x04[PE]\x01 Saving configuration..." );
	if( SaveConfig() ) {
		PrintToChat( client, "\x01 \x04[PE]\x01 Config saved!" );
		return true;
	} else {
		PrintToChat( client, "\x01 \x04[PE]\x07 Failed to write config!" );
		return false;
	}
}

//-------------------------------------------------------------------------------------------------
bool:PE_Reload( client ) {
	PE_ErasePickups();
	PrintToChatAll( "\x01 \x04[PE]\x01 Reloading configuration..." );
	LoadConfig();
	PrintToChat( client, "\x01 \x04[PE]\x01 OK." );
}

//-------------------------------------------------------------------------------------------------
PE_Clear( client ) {
	PE_ErasePickups();
	
	spawn_count = 0;
	
	PrintToChat( client, "\x01 \x04[PE]\x01 All spawns cleared.", client );
}

//-------------------------------------------------------------------------------------------------
public PE_MenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_Select ) {
		new client = param1;
		decl String:info[32];
		new bool:found = GetMenuItem( menu, param2, info, sizeof(info) );
		if( !found ) return;
		if( StrEqual(info, "add") ) {
			PE_AddSpawn( client );
			PE_ShowMenu( client );
		} else if( StrEqual(info, "remove") ) {
			PE_RemoveSpawn( client );
			PE_ShowMenu( client );
		} else if( StrEqual(info, "next") ) {
			PE_TeleportToNext( client );
			PE_ShowMenu( client );
		} else if( StrEqual(info, "save") ) {
			PE_SaveChanges( client );
			PE_ShowMenu( client );
			
		} else if( StrEqual(info, "load") ) {
			PE_Reload( client );
			PE_ShowMenu( client );
			
		} else if( StrEqual(info, "clear") ) {
			PE_Clear( client );
			PE_ShowMenu( client );
		}
	} else if( action == MenuAction_Cancel ) {
		new client = param1;
		admins_currently_editing[client] = false;
		return;
	}
}

//-------------------------------------------------------------------------------------------------
SetupPE() {
	pe_menu = CreateMenu( PE_MenuHandler );
	SetMenuTitle( pe_menu, "Powerups Spawn Editor 1.0" );
	AddMenuItem( pe_menu, "add", "Add at crosshair" );
	AddMenuItem( pe_menu, "remove", "Remove at crosshair" );
	AddMenuItem( pe_menu, "next", "Teleport to next" );
	AddMenuItem( pe_menu, "save", "Save configuration" );
	AddMenuItem( pe_menu, "load", "Reload configuration (undo changes)" );
	AddMenuItem( pe_menu, "clear", "Clear all spawns" );
}

//-------------------------------------------------------------------------------------------------
PE_BuildClientList( clients[] ) {
	new count;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !admins_currently_editing[i] ) continue;
		clients[count] = i;
		count++;
	}
	return count;
}

//-------------------------------------------------------------------------------------------------
PE_Draw() {
	new clients[MAXPLAYERS+1];
	new count = PE_BuildClientList(clients);
	
	for( new i = 0; i < spawn_count; i++ ) {
		new color[4] = {0 ,52,101,255};
		decl Float:pos[3];
		pos[0] = spawn_positions[i][0];
		pos[1] = spawn_positions[i][1];
		pos[2] = spawn_positions[i][2] + 5.0;
		color[0] = RoundToNearest(Sine(GetGameTime())*40.0) + 60;
		TE_SetupBeamRingPoint( pos, 1.0, 15.0, mat_fatlaser, mat_halosprite, 0, 15, 0.25, 2.5, 0.0, color, 10, 0);
		
		TE_Send( clients, count, 0.25 );
		
		TE_SetupGlowSprite( pos, mat_glowsprite, 1.0, 1.0, 70);
		TE_Send( clients, count, 0.0 );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:OnPETimer( Handle:timer ) {
	new bool:active;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( admins_currently_editing[i] ) {
			if( GetGameTime() - pe_admin_activity_time[i] >= PE_TIMEOUT ) {
				admins_currently_editing[i] = false;
			} else {
				active = true;
			}
		}
	}
	
	if( !active ) {
		pe_update_timer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	PE_Draw();
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
StartPeTimer() {
	if( pe_update_timer != INVALID_HANDLE ) {
		return;
	}
	pe_update_timer = CreateTimer( PE_UPDATE_INTERVAL, OnPETimer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_PowerupEditor( client, args ) {	
	PE_ShowMenu( client );
	
	return Plugin_Handled;
}


//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	LoadConfig();
	
	PrecacheModel( MONEY_MODEL );
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	mat_halosprite = PrecacheModel("materials/sprites/glow01.vmt");
	mat_glowsprite = PrecacheModel("materials/sprites/ledglow.vmt");
	
//	PrecacheModel( TESTMODEL );
	pe_update_timer = INVALID_HANDLE;
	next_pickup_spawn_time = 60.0; // magic number
}

//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------
public TriggerTouched( const String:output[], caller,activator, Float:delay ) {
	new ent = caller;
	new other = activator;
	if( other < 1 || other > MaxClients ) return;
	new index = pickup_trigger_parents[ent];
	
	pickup_state[index] = PICKUPSTATE_TAKEN;
	pickup_time[index] = GetGameTime();
	ClientPowerup( other, pickup_type[index] );
	 
	if( POWERUP_FUNCTION_EXISTS( pickup_type[index], PC_PICKUPTAKEN ) ) {
		POWERUP_CALL( pickup_type[index], PC_PICKUPTAKEN );
		Call_PushCell( EntRefToEntIndex(pickup_ents[index]) );
		Call_PushCell( pickup_userdata[index] );
		Call_Finish();
	}
	
	AcceptEntityInput( ent, "Kill" );
}

//-------------------------------------------------------------------------------------------------
AddTrigger( parent, index ) {
	
	new ent = CreateEntityByName( "trigger_once" );
	pickup_trigger_parents[ent] = index;
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", parent );
	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "StartDisabled", "1" );
	
	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", parent );
	//ActivateEntity(ent);
	AcceptEntityInput( ent, "Disable" );


	SetEntityModel( ent, MONEY_MODEL );

	new Float:minbounds[3] = {-33.0, -33.0, -33.0};
	new Float:maxbounds[3] = {33.0, 33.0, 33.0};
	SetEntPropVector( ent, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", maxbounds);


	SetEntProp( ent, Prop_Send, "m_usSolidFlags", 4|8 |0x400); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test
///	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2); //COLLISION_GROUP_DEBRIS

	new enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);  

	new Float:pos[3];
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	HookSingleEntityOutput( ent, "OnStartTouch", TriggerTouched );
	return ent;
	
}

Float:ManhattanDistanceFlat( Float:a[3], Float:b[3] ) {
	return FloatAbs(a[0]-b[0])+FloatAbs(a[1]-b[1]) ;
}

DeletePickup( index ) {
	if( !pickup_active[index] ) return;
	pickup_active[index] = false;
	used_spawns[pickup_locations[index]] = false;
	
	new ent = EntRefToEntIndex( pickup_ents[index] );
	if( ent == INVALID_ENT_REFERENCE ) return;	
	
	if( POWERUP_FUNCTION_EXISTS( pickup_type[index], PC_PICKUPEND ) ) {
		POWERUP_CALL( pickup_type[index], PC_PICKUPEND );
		Call_PushCell( ent );
		Call_PushCell( pickup_userdata[index] );
		Call_Finish();
	}
	
	if( IsValidEntity( ent ) ) AcceptEntityInput( ent, "Kill" );
	
}

SpawnPickup( index, location ) {
	if( used_spawns[location] ) return;
	used_spawns[location] = true;
	 
	if( GetArraySize(plugin_list) == 0 ) return;
	new type = GetRandomInt( 0, GetArraySize(plugin_list)-1 )+1;
	 
	pickup_type[index] = type;
	pickup_locations[index] = location;
	pickup_active[index] = true;
	pickup_time[index] = GetGameTime();
	pickup_state[index] = PICKUPSTATE_FADEIN;
	
	//new ent = CreateEntityByName( "env_sprite" );
	new ent = CreateEntityByName( "prop_dynamic" );
	pickup_ents[index] = EntIndexToEntRef( ent );
	
	decl String:model[256];
	POWERUP_CALL( type, PC_MODEL );
	Call_PushStringEx( model, sizeof model, 0, SM_PARAM_COPYBACK );
	Call_PushCell( sizeof model );
	
	new color[4] = {255,255,255,255};
	Call_PushArray( color, sizeof color );
	Call_Finish();
	
//	SetEntityModel( ent, TESTMODEL ) ;//"materials/sprites/ledglow.vmt" );
	SetEntityModel( ent, model );
	SetEntityRenderColor( ent, 255,255,255 );
	 
	DispatchKeyValue( ent, "rendermode", "2" );
	//DispatchKeyValue( ent, "GlowProxySize", "50.0" );
	DispatchKeyValue( ent, "renderamt", "64" ); 
	//DispatchKeyValue( ent, "framerate", "20.0" ); 
	//DispatchKeyValue( ent, "scale", "50.0" );
	//SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );

	//AcceptEntityInput( ent, "ShowSprite" );
	
	
	TeleportEntity( ent, spawn_positions[location], NULL_VECTOR, NULL_VECTOR );
	
	if( pickup_userdata[index] != INVALID_HANDLE ) {
		CloseHandle( pickup_userdata[index] );
		pickup_userdata[index] = INVALID_HANDLE;
	}
	
	if( POWERUP_FUNCTION_EXISTS( type, PC_PICKUPSPAWNED ) ) {
		POWERUP_CALL( type, PC_PICKUPSPAWNED );
		Call_PushCell( ent );
		new Handle:data;
		Call_Finish( data );
		if( data != INVALID_HANDLE ) {
			pickup_userdata[index] = CloneHandle(data);
			CloseHandle(data);
		}
	}
	
}

//-------------------------------------------------------------------------------------------------
bool:TrySpawnPickup() {
	if( spawn_count == 0 ) return false;
	new pickup_index = -1;
	
	for( new i = 0; i < MAXPICKUPS; i++ ) {
		if( !pickup_active[i] ) pickup_index = i;
	}
	if( pickup_index == -1 ) return false;
	
	new Float:mindist = MIN_DIST_FROM_PLAYERS;
	for( new tries =  10; tries; tries-- ) {
		new spawn = GetRandomInt( 0, spawn_count-1 );
		if( used_spawns[spawn] ) continue;
		new bool:tooclose = false;
		for( new i = 1; i <= MaxClients; i++ ) {	
			if( !player_ingame_cache[i] ) continue;
			if( ManhattanDistanceFlat( player_location_cache[i], spawn_positions[spawn] ) < mindist ) {
				tooclose=true;
				break;
			}
		}
		if( !tooclose ) {
			SpawnPickup( pickup_index, spawn );
			return true;
		}
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
SetGlowSpriteAlpha( ent, Float:alpha,r=255,g=255,b=255 ) {
	r = RoundToNearest(float(r) * alpha);
	if( r < 0 ) r = 0;
	if( r > 255 ) r = 255;
	g = RoundToNearest(float(g) * alpha);
	if( g < 0 ) g = 0;
	if( g > 255 ) g = 255;
	b = RoundToNearest(float(b) * alpha);
	if( b < 0 ) b = 0;
	if( b > 255 ) b = 255;
	
	SetEntityRenderColor( ent, r,g,b,255);
}

//-------------------------------------------------------------------------------------------------
UpdatePickup( index, Float:time ) {
	
	#define PICKUP_FADE_TIME 1.5
	
	if( !pickup_active[index] ) return;

	new ent = EntRefToEntIndex( pickup_ents[index] );
	if( ent == INVALID_ENT_REFERENCE ) {
		DeletePickup(index);
		return;
	}
	if( !IsValidEntity( ent ) ) {
		DeletePickup(index);
		return;
	}
	
	if( pickup_state[index] == PICKUPSTATE_FADEIN ) {
	
		
		if( (time - pickup_time[index]) >= PICKUP_FADE_TIME ) {
			SetGlowSpriteAlpha( ent, 1.0 );
			pickup_state[index] = PICKUPSTATE_READY;
			AddTrigger( ent, index );
			pickup_time[index] = time;
			SetEntPropFloat( ent, Prop_Send, "m_flModelScale", 1.0 );
		} else {
			new Float:alpha = ((time - pickup_time[index]) / PICKUP_FADE_TIME) ;
			SetGlowSpriteAlpha( ent, alpha );
			
			
			SetEntPropFloat( ent, Prop_Send, "m_flModelScale", Lerpfcl( 0.1, 1.0, alpha ) );
		}
	} else if( pickup_state[index] == PICKUPSTATE_READY ) {
		if( time - pickup_time[index] >= c_powerups_pickuptime ) {
			pickup_state[index] = PICKUPSTATE_FADEOUT;
			pickup_time[index] = time;
		}
		 
	} else if( pickup_state[index] == PICKUPSTATE_FADEOUT ) {
		if( (time - pickup_time[index]) >= PICKUP_FADE_TIME ) {
			DeletePickup(index);
			return;
			
			
		} else {
			new Float:alpha = 1.0 - ((time - pickup_time[index]) / PICKUP_FADE_TIME) ;
			SetGlowSpriteAlpha( ent, alpha );
			
		}
	} else if( pickup_state[index] == PICKUPSTATE_TAKEN ) {
		
		DeletePickup(index);
		return;
		 
	}
	
	new Float:pos[3];
	for( new i = 0; i < 3; i++ )
		pos[i] = spawn_positions[pickup_locations[index]][i];
	//pos[2] += y_offset;
	pos[2] += Sine(time) * 8.0;
	pos[2] += 16.0;
	
	new Float:ang[3];
	ang[1] = time * 90.0;
	TeleportEntity( ent, pos, ang, NULL_VECTOR );
	
	if( POWERUP_FUNCTION_EXISTS( pickup_type[index], PC_PICKUPUPDATE ) ) {
		POWERUP_CALL( pickup_type[index], PC_PICKUPUPDATE );
		Call_PushCell( ent );
		Call_PushCell( pickup_state[index] );
		Call_PushFloat( pickup_time[index] );
		Call_PushCell( pickup_userdata[index] );
		Call_Finish();
	}
}

new Float:last_tick_time;
//-------------------------------------------------------------------------------------------------
public OnGameFrame() {

	// button handlign at high refresh rate
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) || !IsPlayerAlive(i) ) continue;
		
		new buttons = GetClientButtons(i);
		if( ((client_last_buttons[i] ^ buttons)&buttons) & IN_USE ) {

			Call_StartForward( use_forward );
			Call_PushCell( i );
			Call_Finish();
		}
		client_last_buttons[i] = buttons;
	}
	
	// update at 64hz
	new Float:time = GetGameTime();
	if( FloatAbs(time - last_tick_time) < 0.015625 ) return;
	last_tick_time = time;
	
	if( time >= next_pickup_spawn_time ) {
		// spawn new pickups
		 
		new bool:spawned;
		
		for( new i = 0; i < c_powerups_count; i++ ) {
			if( TrySpawnPickup() ) {
				spawned = true;
			}
		}
		
		if( spawned ) {
			next_pickup_spawn_time = time + c_powerups_interval;
		} else {
			// if no pickups were spawned, try again in a few moments
			next_pickup_spawn_time = time + 1.0;//todo: magic number
		}
		
		
	}
	
	for( new i = 0; i < MAXPICKUPS; i++ ) {
		UpdatePickup( i, time );
	}
	
	for( new c = 1; c <= MaxClients; c++ ) {
		if( !IsClientInGame(c) ) continue;
		if( !client_powerup_active[c] ) continue;
		
		if( !IsPlayerAlive(c) ) {
			POWERUP_CALL( client_powerup_active[c], PC_END );
			Call_PushCell( c );
			Call_PushCell( client_powerup_data[c] );
			Call_Finish();

			client_powerup_active[c] = 0;
			continue;
		}
		
		if( client_powerup_state[c] == CPS_ACTIVE ) {
			
			POWERUP_CALL( client_powerup_active[c], PC_UPDATE );
			Call_PushCell( c );
			Call_PushCell( client_powerup_data[c] );
			new result;
			Call_Finish( result );
			if( result == PC_UPDATE_CONTINUE ) {
				if( time >= client_powerup_time[c] ) {
					client_powerup_state[c] = CPS_FADING;
					client_powerup_time[c] += client_powerup_fade[c];
					
					POWERUP_CALL( client_powerup_active[c], PC_STOP );
					Call_PushCell( c );
					Call_PushCell( client_powerup_data[c] );
					Call_Finish();
				}
				continue;
			} else if( result == PC_UPDATE_FADE ) {
				client_powerup_state[c] = CPS_FADING;
				client_powerup_time[c] = GetGameTime() + client_powerup_fade[c];
				
				POWERUP_CALL( client_powerup_active[c], PC_STOP );
				Call_PushCell( c );
				Call_PushCell( client_powerup_data[c] );
				Call_Finish();
			
				continue;
			} else {
				DeletePowerupUserdata( c );
				client_powerup_active[c] = 0;
				continue;
			}
		} else {
			
			if( time >= client_powerup_time[c] ) {
				POWERUP_CALL( client_powerup_active[c], PC_END );
				Call_PushCell( c );
				Call_PushCell( client_powerup_data[c] );
				Call_Finish();
				
				DeletePowerupUserdata( c );
				client_powerup_active[c] = 0;
			} else {
				POWERUP_CALL( client_powerup_active[c], PC_FADING );
				Call_PushCell( c );
				Call_PushCell( client_powerup_data[c] );
				Call_Finish();
				
			}
		}
		
	}
	
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	// reset pickups
	for( new i = 0; i < MAXPICKUPS; i++ ) {
		pickup_active[i] = false;
		pickup_ents[i] = 0;
	}
	for( new i = 0; i < MAXSPAWNS; i++ ) {
		used_spawns[i] = false;
	}
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		CancelPowerup(i);
	}
}

//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------

DeletePowerupUserdata( client ) {
	if( client_powerup_data[client] != INVALID_HANDLE )
		CloseHandle( client_powerup_data[client] );
	client_powerup_data[client] = INVALID_HANDLE;
}

SetPowerupUserdata( client, Handle:data ) {
	DeletePowerupUserdata( client );
	if( data == INVALID_HANDLE ) return;
	
	client_powerup_data[client] = CloneHandle(data);
	CloseHandle(data);
}

//-------------------------------------------------------------------------------------------------
CancelPowerup( client ) {
	new type = client_powerup_active[client];
	if( !type ) return;
	
	POWERUP_CALL( type, PC_END );
	Call_PushCell( client );
	Call_PushCell( client_powerup_data[client] );
	Call_Finish();
	
	DeletePowerupUserdata( client );
	client_powerup_active[client] = 0;
}

//-------------------------------------------------------------------------------------------------
ClientPowerup(  client, type  ) {
	
	new Float:duration, Float:fade, poweruptype;
	POWERUP_CALL( type, PC_INFO );
	Call_PushFloatRef( duration );
	Call_PushFloatRef( fade );
	Call_PushCellRef( poweruptype );
	Call_Finish();
	
	if( poweruptype == POWERUP_EFFECT ) {
		CancelPowerup(client);
		DeletePowerupUserdata(client);
	} else {
	}
	
	
	new Handle:data = INVALID_HANDLE;
	POWERUP_CALL( type, PC_START );
	Call_PushCell( client );
	Call_Finish(data);
	
	if( poweruptype == POWERUP_EFFECT ) {
		
		
		client_powerup_active[client] = type;
		client_powerup_plugin[client] = GetArrayCell( plugin_list, type-1 );
		client_powerup_time[client] = GetGameTime() + duration;
		client_powerup_fade[client] = fade;
		client_powerup_state[client] = CPS_ACTIVE;
		client_status_box_serial[client] = -1;
		
		SetPowerupUserdata( client, data );
//		client_powerup_data[client] = CloneHandle(data);
//		CloseHandle(data);
	}	
}


//----------------------------------------------------------------------------------------------------------------------
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
		Float:damageForce[3], Float:damagePosition[3]) {
	
	
	
	if(!(victim > 0 && victim <= MaxClients)) {
		return Plugin_Continue;
	}
	if( damage <= 0.0  ) {
		return Plugin_Continue;
	}
	
	new bool:changed;
	
	new type;
	if( attacker > 0 && attacker <= MaxClients ) {
		 
		type = client_powerup_active[attacker];
		if( type && client_powerup_state[attacker] == CPS_ACTIVE ) {
			if( POWERUP_FUNCTION_EXISTS( type, PC_ONGIVEDAMAGE ) ) {
				
				POWERUP_CALL( type, PC_ONGIVEDAMAGE );
				Call_PushCell( attacker );
				Call_PushCell( victim );
				Call_PushFloatRef( damage );
				Call_PushArrayEx( damageForce, 3, SM_PARAM_COPYBACK );
				Call_Finish();
				
				changed =true;
			}
		}
	}
	
	type = client_powerup_active[victim];
	if( type && client_powerup_state[victim] == CPS_ACTIVE  ) {
		if( POWERUP_FUNCTION_EXISTS( type, PC_ONTAKEDAMAGE ) ) {
			POWERUP_CALL( type, PC_ONTAKEDAMAGE );
			Call_PushCell( victim );
			Call_PushCell( attacker );
			Call_PushFloatRef( damage );
			Call_PushCell( damagetype );
			Call_Finish();
			changed =true;
			
		}
	}
	
	if( changed&&damage == 0.0 ) return Plugin_Handled;
	return changed?Plugin_Changed:Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	HookClient( client );
	client_last_buttons[ client ] = 0;
}

//-------------------------------------------------------------------------------------------------
HookClient( client ) {
	SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
}
