 
// mother fucking laser sights
  
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <cstrike_weapons>
#include <rxgcolorparser>

#define USE_DONATIONS 
#if defined USE_DONATIONS
#include <donations>
#endif


// CHANGES:
// 2.0.0
//   vip menu
//   new method
// 1.0.2
//   lasersight saves state with weapon changes
//

public Plugin:myinfo =
{
	name = "Laser Sights",
	author = "mukunda",
	description = "mother fucking LASER SIGHTS!!!!",
	version = "2.0.0",
	url = "www.mukunda.com"
};
   
#define SPECMODE_FIRSTPERSON 4

#define TOGGLE_SOUND "items/flashlight1.wav"

#define LASERMODEL "materials/rxg/rxglaser.vmt"
#define LASERMODEL_BLACK "materials/rxg/rxglaser_black.vmt"

//-------------------------------------------------------------------------------------------------
new weapon_laser_on[2048] = {-1,...}; // entref pointing to self, if match, laser is desired on that weapon
new String:laser_parent[2048];

//-------------------------------------------------------------------------------------------------
new bool:lasersight_active[MAXPLAYERS+1];	// currently "on" for a client
//new lasersight_beams[MAXPLAYERS+1];			// beam entity for laser
//new lasersight_targets[MAXPLAYERS+1];		// info_target entities ( need to be saved? they are children  )
new laser_beams[MAXPLAYERS+1] = {-1,...};	// entref for laser beams
new fps_beam[MAXPLAYERS+1] = {-1,...};		// entref for first-person beams

new prefs_loaded[MAXPLAYERS+1] ;	// userid of preferences that are cached
new Handle:mycookie;
new pref_color[MAXPLAYERS+1][4];	// rgbx x=1 means ignore color and use black laser
new pref_ev[MAXPLAYERS+1];
new pref_fatness[MAXPLAYERS+1];  	// 0-4, THIN NORMAL FAT FATTER FATTEST

// laser widths from fatness pref
new const Float:fatmap[5] = { 1.4, 1.75, 2.1, 2.5, 3.0 };
new const String:fatnames[5][] = {"Thin","Normal","Fat","Fatter","Ultra FAT"};
#define FP_WIDTH_SCALE 0.35

#if defined USE_DONATIONS
new Handle:mymenu;

#endif
  
//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	mycookie = RegClientCookie( "lasersight_prefs", "Lasersight Preferences", CookieAccess_Protected );
	
	HookEvent("player_spawn", OnPlayerSpawn );
	HookEvent("player_death", OnPlayerDeath );
	HookPlayers();
	
	RegConsoleCmd( "laser", Command_laser, 
		"laser <color> <fatness> <alpha> - turn on your lasersight and set it's color, color can be RGB (0-9) RRGGBB (hexcode) or a color name" );
		
//	RegConsoleCmd( "beamtest",  beamtest );
//	RegConsoleCmd( "beamtest1",  beamtest1 );
		
#if defined USE_DONATIONS
	VIP_Register( "Laser Sight", OnVIPMenu );
	
	mymenu = CreateMenu( MyMenuHandler, MenuAction_Select|MenuAction_DisplayItem|MenuAction_DrawItem );
	SetMenuPagination( mymenu, MENU_NO_PAGINATION );
	SetMenuTitle( mymenu, "Laser Sight" );
	AddMenuItem( mymenu, "TG", "Toggle (bind 'laser' for easy access)" );
	AddMenuItem( mymenu, "SZ", "SIZE" );
	AddMenuItem( mymenu, "EV", "ENEMIES" );
	AddMenuItem( mymenu, "MODE", "MODE" );
	AddMenuItem( mymenu, "R", "RED" );
	AddMenuItem( mymenu, "G", "GREEN" );
	AddMenuItem( mymenu, "B", "BLUE" );
	AddMenuItem( mymenu, "H",  "Hold Shift/Space to decrease/slow" );
	SetMenuExitButton(mymenu,true);
	
#endif
}

#if defined USE_DONATIONS
public OnLibraryAdded( const String:name[]) {
	if( StrEqual(name, "donations") ) VIP_Register( "Laser Sight", OnVIPMenu );
}

public OnPluginEnd() {
	VIP_Unregister();
}
#endif

/*
public Action:beamtest1( client, args ) {
	
	decl String:tarname[32];
	new Float:end[3] = {0.0,0.0,32.0};
	Format( tarname, sizeof tarname, "test2%d", test1++ );
	strcopy(poop,sizeof poop,tarname);
	new tar = CreateEntityByName("env_sprite"); 
	SetEntityModel( tar, MODEL2 );
	DispatchKeyValue( tar, "renderamt", "255" );
	DispatchKeyValue( tar, "rendercolor", "255 255 255" );
	DispatchKeyValue( tar,"targetname", tarname );
	DispatchSpawn( tar );
	AcceptEntityInput(tar,"ShowSprite");
	ActivateEntity(tar);
	TeleportEntity( tar, end, NULL_VECTOR, NULL_VECTOR );
	
	return Plugin_Handled;
}*/
/*
public Action:beamtest( client, args ) {

	decl String:arg[64];
	GetCmdArg(1,arg,sizeof arg);
	new target = FindTarget(client,arg);
	if(target==-1)return Plugin_Handled;
	LoadPrefs(target);
	TurnOnLaser(target);
	return Plugin_Handled;
	
	
	#define MODEL2 "sprites/laserbeam.vmt"
	PrecacheModel(MODEL2);
	decl Float:pos[3];
	decl Float:dir[3];
	GetClientEyePosition( client, pos );
	GetClientEyeAngles(client, dir );
	GetAngleVectors( dir, dir, NULL_VECTOR, NULL_VECTOR );
	decl Float:start[3];
	decl Float:end[3];
	for( new i = 0; i < 3; i++ ) {
		start[i] = pos[i] + dir[i] * 100.0;
		end[i] = pos[i] + dir[i] * 200.0;
	} 
	
	new tar = CreateEntityByName("env_sprite"); 
	SetEntityModel( tar, MODEL2 );
	DispatchKeyValue( tar, "renderamt", "255" );
	DispatchKeyValue( tar, "rendercolor", "255 255 255" ); 
	DispatchSpawn( tar );
	AcceptEntityInput(tar,"ShowSprite");
	ActivateEntity(tar);
	TeleportEntity( tar, end, NULL_VECTOR, NULL_VECTOR );
	
	new beam = CreateEntityByName( "env_beam" );
	SetEntityModel( beam, MODEL2 );
	DispatchKeyValue( beam, "renderamt", "100" );
	DispatchKeyValue( beam, "rendermode", "0" );
	DispatchKeyValue( beam, "rendercolor", "255 255 255" );  
	DispatchKeyValue( beam, "life", "0" ); 
	TeleportEntity( beam, start, NULL_VECTOR, NULL_VECTOR ); 
	
	DispatchSpawn(beam);
	SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(beam) );
	SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(tar), 1 );
	SetEntProp( beam, Prop_Send, "m_nNumBeamEnts", 2);
	SetEntProp( beam, Prop_Send, "m_nBeamType", 2);
	
	SetEntPropFloat( beam, Prop_Data, "m_fWidth", 10.0 );
	SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", 1.0 );
	AcceptEntityInput(beam,"TurnOn");
	return Plugin_Handled;
} 
*/
//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() { 
	PrecacheModel( LASERMODEL );
	PrecacheModel( LASERMODEL_BLACK );
	PrecacheSound( TOGGLE_SOUND );
	AddFileToDownloadsTable( "materials/rxg/rxglaser.vmt" );
	AddFileToDownloadsTable( "materials/rxg/rxglaser_black.vmt" );
	AddFileToDownloadsTable( "materials/rxg/rxglaser.vtf" );
} 

//-------------------------------------------------------------------------------------------------
LoadPrefs( client ) {
	new userid = GetClientUserId( client );
	if( userid == prefs_loaded[client] ) return; // prefs already loaded
	
	if( IsFakeClient(client) ) {
		prefs_loaded[client] = userid; // mark as "loaded"
		pref_color[client][0] = 0;
		pref_color[client][1] = 0;
		pref_color[client][2] = 255;
		pref_color[client][3] = 0;
		pref_fatness[client] = 2; 
		pref_ev[client] = 1;
		return;
	}
	
	if( AreClientCookiesCached(client) ) {
		prefs_loaded[client] = userid; // mark as "loaded"
		
		decl String:data[128];
		GetClientCookie( client, mycookie, data, sizeof data );
	
		if( data[0] == 0 ) {
			// initialize with default settings
			pref_color[client][0] = 255;
			pref_color[client][1] = 0;
			pref_color[client][2] = 0;
			pref_color[client][3] = 0;
			pref_fatness[client] = 1; 
			pref_ev[client] = 1;
		} else {
			pref_color[client][0] = parse_hexbyte( data[4] );
			pref_color[client][1] = parse_hexbyte( data[6] );
			pref_color[client][2] = parse_hexbyte( data[8] );
			pref_color[client][3] = parse_hexbyte( data[10] );
			pref_fatness[client] = data[0]-'0';
			pref_ev[client] = data[1]-'0';
		}
	}
}

//-------------------------------------------------------------------------------------------------
SavePrefs( client ) {
	if( prefs_loaded[client] != GetClientUserId(client) ) return;
	if( IsFakeClient(client) ) return;
	
	decl String:data[16];
	FormatEx( data, sizeof data, "%c%c%c%c%02X%02X%02X%02X",
		'0' + pref_fatness[client],
		'0' + pref_ev[client],
		'0','0',
		pref_color[client][0],
		pref_color[client][1],
		pref_color[client][2],
		pref_color[client][3] );
	SetClientCookie( client, mycookie, data  );
}

//-------------------------------------------------------------------------------------------------
public Action:OnBeamSetTransmit( entity, client ) {
	// transmit for 3rd person beam
	// sends to everyone except owner and people spectating the owner in first person

	//decl String:name[8];
	new owner = laser_parent[entity];
	if( !IsClientInGame(client) ) return Plugin_Handled;
	if( !IsPlayerAlive(client) ) {
		new specmode = GetEntProp( client, Prop_Send, "m_iObserverMode" );
		if( specmode == SPECMODE_FIRSTPERSON ) {
			new target = GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" );
			if( target == owner ) return Plugin_Handled;
		}
	} else {
		if( (!pref_ev[client]) && GetClientTeam(owner) != GetClientTeam(client) ) {
			return Plugin_Handled;
		}
	}

	//new owner = StringToInt( name);
	// OPTIMIZE THIS SHT
	if( owner == client ) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
   /*
//-------------------------------------------------------------------------------------------------
LaserSights_SetColor( client, color[4] ) {
	new beam = lasersight_beams[client];
	new beam2 = lasersight_beams_fps[client];
	if( beam <= 0 || beam2 <= 0 ) return;

	decl String:scolor[32];
	Format( scolor, sizeof(scolor), "%d %d %d", color[0], color[1], color[2] );
	DispatchKeyValue( beam, "rendercolor", scolor );
	DispatchKeyValue( beam2, "rendercolor", scolor );
	Format( scolor, sizeof(scolor), "%d", color[3] );
	DispatchKeyValue( beam, "renderamt", scolor );
	DispatchKeyValue( beam2, "renderamt", scolor );
}

//-------------------------------------------------------------------------------------------------
LaserSights_SetWidth( client, Float:width ) {
	new beam = lasersight_beams[client];
	new beam2 = lasersight_beams_fps[client];
	if( beam <= 0 || beam2 <= 0 ) return;

	SetVariantFloat( width );
	AcceptEntityInput( beam, "Width" );
	SetEntPropFloat( beam, Prop_Data, "m_fWidth", width ); // wtf lol
	SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", width); 
	
	SetVariantFloat( width );
	//AcceptEntityInput( beam2, "Width" );
	SetEntPropFloat( beam2, Prop_Data, "m_fWidth", width /3.0); // wtf lol
	SetEntPropFloat( beam2, Prop_Data, "m_fEndWidth", width/3.0); 
}*/

//-------------------------------------------------------------------------------------------------
CreateLaserHooks(client, &start, &end ){

	// we need to create a dummy entity to put in the player's hand
	// if the beam is directly attached without this "glue" then it 
	// doesn't show up
	new ent = CreateEntityByName("env_sprite"); 
	SetEntityRenderColor( ent, 0,0,0,0 ); 
	DispatchSpawn(ent);
	AcceptEntityInput( ent, "Activate" );
	AcceptEntityInput( ent, "HideSprite" );
	
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent",  client );
	SetVariantString("weapon_bone");
	AcceptEntityInput( ent, "SetParentAttachment" );
	
	start = ent;
	
	// the info target is the ending entity
	// parented to the beam in the upper function
	ent = CreateEntityByName( "info_target" ); 
	DispatchSpawn(ent); 
	end = ent;
}

//-------------------------------------------------------------------------------------------------
CreateFPSBeam( client ) {
	new beam = CreateEntityByName( "env_beam" );
	
	SetEntityModel( beam, LASERMODEL );
	DispatchKeyValue( beam, "life", "0" );
	
	//SetEntPropEnt( beam, Prop_Data, "m_hEffectEntity", client );
	//SDKHook( beam, SDKHook_SetTransmit, OnBeamSetTransmit_WeaponReady );
	
	new vm = GetEntPropEnt( client, Prop_Send, "m_hViewModel" );
	SetVariantString( "!activator" );
	AcceptEntityInput( beam, "SetParent", vm );
	
	new Float:pos[3] = {0.0,-2.0,-2.0};
	new Float:end[3] = {2500.0,0.0,0.0};
	
	TeleportEntity( beam, pos, NULL_VECTOR, NULL_VECTOR );
	SetEntPropVector( beam, Prop_Data, "m_vecEndPos", end );
	
	fps_beam[client] = EntIndexToEntRef( beam );
}

//-------------------------------------------------------------------------------------------------
SetBeamParams( beam, color[4], fatness, Float:scale=1.0 ) {
	if( color[3] == 0 ) {
		SetEntityRenderColor( beam, color[0], color[1], color[2], 255 );
		SetEntityModel( beam, LASERMODEL );
	} else {
		SetEntityRenderColor( beam, 0,0,0,255 );
		SetEntityModel( beam, LASERMODEL_BLACK );
	} 
	SetEntPropFloat( beam, Prop_Data, "m_fWidth", fatmap[fatness]*scale );
	SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", fatmap[fatness]*scale ); 
}
/*
//-------------------------------------------------------------------------------------------------
UpdateBeamParams( client ) {
	if( !lasersight_active[client] ) return;
	SetBeamParams( fps_beam[client], pref_color[client], pref_fatness[client], FP_WIDTH_SCALE );
	SetBeamParams( laser_beams[client], pref_color[client], pref_fatness[client] );
}*/

//-------------------------------------------------------------------------------------------------
SetFPSBeam( client, color[4], fatness ) {
	if( !IsValidEntity( fps_beam[client] ) ) {
		CreateFPSBeam( client );
	}
	AcceptEntityInput( fps_beam[client], "TurnOn" );
	SetBeamParams( fps_beam[client], color, fatness, FP_WIDTH_SCALE );
}

//-------------------------------------------------------------------------------------------------
SetFPSBeamOff( client ) {
	if( IsValidEntity( fps_beam[client] ) ) {
		AcceptEntityInput( fps_beam[client], "TurnOff" );
	}
}

//-------------------------------------------------------------------------------------------------
CreateLaserBeam( client ) {
	new beam = CreateEntityByName( "env_beam" );
	laser_beams[client] = EntIndexToEntRef(beam);
	SetEntityModel( beam, LASERMODEL ); 
	DispatchKeyValue( beam, "life", "0" );
	DispatchKeyValue( beam, "ClipStyle", "2" );

	new start,end;
	CreateLaserHooks( client, start, end );
	//new target = CreateLaserSightTarget( client );
	
	laser_parent[beam] = client;
	SDKHook( beam, SDKHook_SetTransmit, OnBeamSetTransmit );
	
	SetVariantString("!activator");
	AcceptEntityInput( beam, "SetParent", start); 
	
	SetVariantString("!activator");
	AcceptEntityInput( end, "SetParent", beam ); 
	
	new Float:beampos[3] = {-0.6,-2.0,5.0}; 
	//new Float:beamang[3] = {90.0,90.0,90.0}; // (only god knows)
	new Float:beamang[3] = {0.0,0.0,0.0}; // (only god knows)
	new Float:targetpos[3] = {0.0,0.0,5000.0};
	
	TeleportEntity( beam, beampos, beamang, NULL_VECTOR );
	TeleportEntity( end, targetpos, NULL_VECTOR, NULL_VECTOR );  
	
	//TeleportEntity( beam, start, NULL_VECTOR, NULL_VECTOR ); 
	
	DispatchSpawn(beam);
	SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(beam) );
	SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(end), 1 );
	SetEntProp( beam, Prop_Send, "m_nNumBeamEnts", 2);
	SetEntProp( beam, Prop_Send, "m_nBeamType", 2); 
	
	//AcceptEntityInput(beam,"TurnOn");
}

//-------------------------------------------------------------------------------------------------
TurnOnLaser( client, bool:silent=false, manual=true ) {
	
	if( !IsPlayerAlive(client) ) return;
	if( manual ) {
		
		decl String:weap[64];
		GetClientWeapon( client, weap, sizeof(weap) );

		ReplaceString( weap, sizeof(weap), "weapon_", "" );
		new WeaponType:wtype = GetWeaponType( weap );
		if( !(wtype == WeaponTypePistol ||
			wtype == WeaponTypeSMG ||
			wtype == WeaponTypeShotgun ||
			wtype == WeaponTypeRifle ||
			wtype == WeaponTypeSniper ||
			wtype == WeaponTypeMachineGun) ) {

			return;
		}	
		if( !silent ) {
			EmitSoundToAll( TOGGLE_SOUND, client );
		}

		new weapent = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
		SetLaserSightOn( weapent );
	}
	
	if( !IsValidEntity(laser_beams[client]) ) {
		CreateLaserBeam( client );
	}
	
	AcceptEntityInput( laser_beams[client], "TurnOn" );
	SetBeamParams( laser_beams[client], pref_color[client], pref_fatness[client] );
	SetFPSBeam( client, pref_color[client], pref_fatness[client] );
	
	lasersight_active[client] = true; 
}

//-------------------------------------------------------------------------------------------------
TurnOffLaser( client, bool:silent=false, manual=true ) {
	 
	if( manual ) {
		new weapent = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
		if( weapent > 0 ) {
			SetLaserSightOff( weapent );
		}
	}

	if( !silent ) { 
		EmitSoundToAll( TOGGLE_SOUND, client );
	}
	
	if( IsValidEntity(laser_beams[client]) ) {
		AcceptEntityInput( laser_beams[client], "TurnOff" );
	}
	SetFPSBeamOff( client );
	lasersight_active[client] = false;
}

//-------------------------------------------------------------------------------------------------
ToggleLaser(client) {
	if( lasersight_active[client] ) {
		TurnOffLaser( client );
	} else {
		TurnOnLaser( client );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_laser( client, args ) {
	if( client==0 ) return Plugin_Continue;
	
	if( lasersight_active[ client] ) {
		TurnOffLaser(client);
	} else {
	
		LoadPrefs(client);

		#if defined USE_DONATIONS 
		if( !Donations_GetClientLevel(client)  ) {
			ReplyToCommand( client, "The amazing laser sight is available to VIPs only!" );
			return Plugin_Handled;
		} 
		#endif
		
		decl String:arg[64];
		if( args >= 1 ) {
			GetCmdArg(1,arg,sizeof arg);
			decl color[3];
			if( !ParseColor( arg, color ) ) {
				PrintToChat( client, "Invalid color!" );
				return Plugin_Handled;
			}
			pref_color[client][0] = color[0];
			pref_color[client][1] = color[1];
			pref_color[client][2] = color[2];
			pref_color[client][3] = 0;
		}
		if( args >= 2 ) {
			new i = Saturate(GetIntArg(2),0,4);
			pref_fatness[client] = i;
		}
		if( args >= 3 ) {
			new i = Saturate(GetIntArg(3),0,255);
			pref_color[client][3] = i;
		}
		if( args >= 1 ) {
			SavePrefs( client );
		}
		
		TurnOnLaser(client);
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnClientPutInServer(client) {
	SDKHook( client, SDKHook_WeaponCanSwitchToPost, OnClientWeaponCanSwitchToPost );
	SDKHook( client, SDKHook_WeaponDropPost, OnClientWeaponDropPost );
	lasersight_active[client] = false;
}

//-------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if( client == 0 ) return;
	if( GetClientTeam(client) < 2 ) return;
	
	new weapent = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( weapent > 0 ) {
		if( IsLaserSightOn( weapent ) ) {
			TurnOnLaser(client, true, false); 
		}
	}
}

//-------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {

	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if( client == 0 ) return;
	TurnOffLaser( client, true, true ); 
}

//-------------------------------------------------------------------------------------------------
public OnClientWeaponCanSwitchToPost( client, weapon ) {
 
	if( IsLaserSightOn( weapon ) ) {
		TurnOnLaser(client, true, false);
	} else {
		TurnOffLaser(client, true, false);
	}
}

//-------------------------------------------------------------------------------------------------
public OnClientWeaponDropPost( client, weapon ) {
	if( weapon > 0 && weapon < 2048 ) {
		SetLaserSightOff( weapon );
	}
}

//-------------------------------------------------------------------------------------------------
bool:IsLaserSightOn( weapon ) {
	return EntRefToEntIndex(weapon_laser_on[weapon]) == weapon;
}

//-------------------------------------------------------------------------------------------------
SetLaserSightOn( weapon ) {
	weapon_laser_on[weapon] = EntIndexToEntRef(weapon);
}

//-------------------------------------------------------------------------------------------------
SetLaserSightOff( weapon ) {
	weapon_laser_on[weapon] = -1;
}

//----------------------------------------------------------------------------------------------------------------------
HookPlayers() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			SDKHook( i, SDKHook_WeaponCanSwitchToPost, OnClientWeaponCanSwitchToPost );
			SDKHook( i, SDKHook_WeaponDropPost, OnClientWeaponDropPost );
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
#if defined USE_DONATIONS

#define SHOW_MENU DisplayMenu( mymenu, client, MENU_TIME_FOREVER )

//----------------------------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04VIPs can add a laser sight to their weapon." );
	} else if( action == VIP_ACTION_USE ) {
		if( !AreClientCookiesCached(client) ) return;
		LoadPrefs( client );
		SHOW_MENU;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public MyMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_DisplayItem ) {
		new client = param1;
		decl String:info[32];
		decl String:text[64];
		GetMenuItem( menu, param2, info, sizeof info );
		if( StrEqual( info, "SZ" ) ) {
			FormatEx( text, sizeof text, "Size: %s", fatnames[pref_fatness[client]] );
			return RedrawMenuItem( text );
		} else if( StrEqual( info, "MODE" ) ) {
			if( pref_color[client][3] == 0 ) {
				RedrawMenuItem( "Mode: Normal" );
			} else {
				RedrawMenuItem( "Mode: Black" );
			}
		} else if( StrEqual( info, "EV" ) ) {
			FormatEx( text, sizeof text, "Enemies can see: %s", (pref_ev[client]) ? "Yes":"No" );
			return RedrawMenuItem( text );
		} else if( StrEqual( info, "R" ) ) {
			FormatEx( text, sizeof text, "Red: %d%%", (pref_color[client][0] * 100+128) / 255);
			return RedrawMenuItem( text );
		} else if( StrEqual( info, "G" ) ) {
			FormatEx( text, sizeof text, "Green: %d%%", (pref_color[client][1] * 100+128) / 255);
			return RedrawMenuItem( text );
		} else if( StrEqual( info, "B" ) ) {
			FormatEx( text, sizeof text, "Blue: %d%%", (pref_color[client][2] * 100+128) / 255);
			return RedrawMenuItem( text );
		}
	} else if( action == MenuAction_DrawItem ) {
		decl String:info[32]; 
		GetMenuItem( menu, param2, info, sizeof info );
		if( StrEqual( info, "R" ) || StrEqual(info, "G") || StrEqual(info, "B") || StrEqual(info, "H") ) {
			if( pref_color[param1][3] == 0 ) {
				if( StrEqual(info, "H") ) return ITEMDRAW_DISABLED;
				return ITEMDRAW_DEFAULT;
			} else {
				return ITEMDRAW_IGNORE;
			}
		}
		return ITEMDRAW_DEFAULT;
	} else if( action == MenuAction_Select ) {
		new client = param1;
		decl String:info[32];
		GetMenuItem( menu, param2, info, sizeof info );
		if( StrEqual( info, "TG" ) ) {
			ToggleLaser(client);
			SHOW_MENU;
		} else if( StrEqual( info, "SZ" ) ) {
			pref_fatness[client]++;
			if( pref_fatness[client] > 4 ) pref_fatness[client] = 0;
			SavePrefs(client);
			TurnOnLaser( client, true );
			SHOW_MENU;
		} else if( StrEqual( info, "MODE" ) ) {
			pref_color[client][3] = !pref_color[client][3];
			SavePrefs(client);
			TurnOnLaser( client, true );
			SHOW_MENU;
		} else if( StrEqual( info, "EV" ) ) {
			pref_ev[client] = !pref_ev[client];
			SavePrefs(client);
			SHOW_MENU;
		} else if( StrEqual( info, "R" ) || StrEqual(info, "G") || StrEqual(info, "B") ) {
			new index;
			if( info[0] == 'R' ) index =0 ;
			if( info[0] == 'G' ) index = 1;
			if( info[0] == 'B' ) index = 2;
			
			new buttons = GetClientButtons(client);
			new step = (buttons & IN_JUMP) ? 2 : 25;
			if(buttons & IN_SPEED) step = -step;
			if( step > 0 && pref_color[client][index] == 255 ) {
				pref_color[client][index] = 0;
			} else if( step < 0 && pref_color[client][index] == 0 ) {
				pref_color[client][index] = 255;
			} else {
				pref_color[client][index] = Saturate( pref_color[client][index] + step, 0, 255 );
			}
			SavePrefs(client);
			
			TurnOnLaser( client, true );
			SHOW_MENU;
		}
	}
	return 0;
}

#endif
