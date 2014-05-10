
#include <sourcemod>
#include <sdktools>

#include <sdkhooks>
 
#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "propper",
	author = "mukunda",
	description = "add props to the map",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------------------------------------
 
new Handle:sm_propper_config;

new Handle:kv_config = INVALID_HANDLE; 

new String:mapname[64];

new bool:system_enabled;

new bool:round_start_hooked = false;

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	sm_propper_config = CreateConVar( "sm_propper_config", "propper.txt", "Filename of propper config, relative to /configs/", FCVAR_PLUGIN );
	
	RegServerCmd( "sm_propper_reload", Command_reload, "Reload propper config" );
/*debugcode
	{
		new ent = FindEntityByClassname( 323, "prop_door_rotating" );
		decl String:test[64];
		GetEntPropString( ent, Prop_Data, "m_ModelName", test, sizeof(test) );
		PrintToServer( "Penis %d %s", ent, test );
	}	*/
}

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
	kv_config = CreateKeyValues( "Propper" );
	
	// search file for map
	decl String:filepath[256], String:file[64];
		
	GetConVarString( sm_propper_config, file, sizeof(file) );
	BuildPath( Path_SM, filepath, sizeof(filepath), "configs/%s", file );
	
	if( FileExists(filepath) ) {
		if( !FileToKeyValues( kv_config, filepath ) ) {
			SetFailState( "Couldn't Load Config" );
		}
	} else {
		SetFailState( "Datafile Not Found: %s", filepath );
		return;
	}
	
	KvGotoFirstSubKey(kv_config);
	do {
		
		decl String:name[64];
		KvGetSectionName( kv_config, name, sizeof(name) );
		
		if( StrEqual( name, mapname ) ) {
			
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
	PrintToServer( "Reloaded propper config!" );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	
	LoadPropList();
	
	
}

//----------------------------------------------------------------------------------------------------------------------
SetupProps() {
	
	 
	if( !KvJumpToKey( kv_config, "props" ) ) return false;
	 
	
	decl String:model[128];
	decl String:position[128];
	decl String:type[64];
	decl String:bbox[64];
	decl String:spawnflags[32];
	new propperflags;
	new movetype;
	
	if( !KvGotoFirstSubKey( kv_config ) ) {
		KvGoBack( kv_config );
		return false;
	} 
	
	do {
		
		KvGetString( kv_config, "model", model, sizeof(model) );
		KvGetString( kv_config, "position", position, sizeof(position) );
		KvGetString( kv_config, "type", type, sizeof(type) );
		KvGetString( kv_config, "bbox", bbox, sizeof(bbox) );
		 
		movetype = KvGetNum( kv_config, "move", -1 );
		propperflags = KvGetNum( kv_config, "propperflags", 0 );
		KvGetString( kv_config, "spawnflags", spawnflags, sizeof(spawnflags) );
		
		if( type[0] == 0 ) {
			LogError( "Type not specified" );
			break; // error
		}
		 
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
		
		//decl String:classname[64];
		//Format( classname, sizeof(classname), "prop_%s", type );
		
		new ent = CreateEntityByName( type );
		if( ent == -1 ) {
			LogError( "Couldn't create entity" );
			break; // error
		}
		
		decl String:targetname[64];
		KvGetSectionName( kv_config, targetname, sizeof(targetname) );
		Format( targetname, sizeof(targetname), "propper_%s", targetname );
		  
		if( spawnflags[0] != 0 )
			DispatchKeyValue( ent, "spawnflags", spawnflags );
			
		DispatchKeyValue( ent, "targetname", targetname );
		DispatchKeyValue( ent, "physdamagescale", "0.0" );
		
		if( model[0] != 0 )
			DispatchKeyValue( ent, "model", model );
		
		if( movetype != -1 )
			SetEntityMoveType( ent, MoveType:movetype );
		
		
		if( KvJumpToKey( kv_config, "keyvalues" ) ) {
			if( KvGotoFirstSubKey( kv_config, false ) ) {
				
				do {
					decl String:name[128];
					decl String:value[128];
					KvGetSectionName( kv_config, name, sizeof(name) );
					KvGetString( kv_config, NULL_STRING, value, sizeof(value), "" );
					DispatchKeyValue( ent, name, value );
					
				} while( KvGotoNextKey(kv_config,false) );
				KvGoBack(kv_config);
			}
			KvGoBack(kv_config);
		}
		
		
		
		DispatchSpawn( ent );
		new Float:vel[3];
		TeleportEntity( ent, pos, ang, vel );
		
		if( use_bbox ) {
			SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test
			 
			new Float:vec[3];
			vec[0] = f_bbox[0]; vec[1] = f_bbox[1]; vec[2] = f_bbox[2];
			SetEntPropVector( ent, Prop_Send, "m_vecMins", vec );
			vec[0] = f_bbox[3]; vec[1] = f_bbox[4]; vec[2] = f_bbox[5];
			SetEntPropVector( ent, Prop_Send, "m_vecMaxs", vec );
			
			  
		}
		
		if( KvJumpToKey( kv_config, "inputstring" ) ) {
			if( KvGotoFirstSubKey( kv_config, false ) ) {
				
				do {
					decl String:name[128];
					decl String:value[128];
					KvGetSectionName( kv_config, name, sizeof(name) );
					KvGetString( kv_config, NULL_STRING, value, sizeof(value), "" );
					SetVariantString(value);
					AcceptEntityInput( ent, name );
					
				} while( KvGotoNextKey(kv_config,false) );
				KvGoBack(kv_config);
			}
			KvGoBack(kv_config);
		}
		
		if( propperflags & 1 ) {
			// door hack
			SDKHook( ent, SDKHook_UsePost, DoorHack );
			//HookSingleEntityOutput( ent, "OnPlayerUse", DoorHack, false );
			//PrintToChatAll( "daaaa" );
		}
		
	} while( KvGotoNextKey( kv_config ) );
	
	KvGoBack( kv_config ); // exit props data
	KvGoBack( kv_config ); // exit props
	
	return true;
}

//----------------------------------------------------------------------------------------------------------------------
// hack to make doors closeable when set next to props
public Action:DoorHack(entity, activator, caller, UseType:type, Float:value) {

	AcceptEntityInput( entity, "Toggle" );

	return Plugin_Handled;
}
 
//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	
	if( !system_enabled ) {
		SetFailState( "(Assert) round_start should not be hooked while system is disabled." );
		return;
	}
	 
	 
	SetupProps(); 
	
	
}



