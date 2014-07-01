#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

//#include <cstrike_weapons>

#include <donations>
#include <rxgcolorparser>
 
// 2.1.0
//   un-dumb
// 2.0.1
//   glow sustains across sessions

public Plugin:myinfo = {
	name = "VIP Glow",
	author = "mukunda",
	description = "VIP Glow",
	version = "2.1.0",
	url = "www.reflex-gamers.com"
};

// ent refs for sprites
new glow_sprites[MAXPLAYERS+1] = {-1,...};
new glow_sprites2[MAXPLAYERS+1] = {-1,...};
new glow_color[MAXPLAYERS+1][3];
new glow_fp[MAXPLAYERS+1]; // first person flag
new bool:glow_on[MAXPLAYERS+1]; // bool
new cookie_loaded[MAXPLAYERS+1]; // userid
new glow_team[2048];

new Handle:cookieprefs;

new String:material[128];
//#define MATERIAL "materials/sprites/glow.vmt"

#define GLOW_SIZE "63.0"
#define GLOW_SIZE2 "63.0" 

#define GAME_CSGO 0
#define GAME_TF2 1
new GAME;

new Handle:glow_menu;

enum {
	GM_CONCMD,
	GM_TOGGLE,
	GM_FPDISP,
	GM_RED,
	GM_GREEN,
	GM_BLUE,
	GM_HINT
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	cookieprefs = RegClientCookie( "VIPGlowData", "VIP Glow Saved Data", CookieAccess_Protected );
	
	decl String:game[64];
	GetGameFolderName( game, sizeof game );
	if( StrEqual( game, "csgo", false ) ) {
		material = "materials/sprites/glow.vmt";
		GAME = GAME_CSGO;
	} else if( StrEqual( game, "tf", false ) ) {
		material = "materials/sprites/glow02.vmt";
		GAME = GAME_TF2;
	}

	HookEvent( "player_death", OnPlayerDeath );
	HookEvent( "player_spawn", OnPlayerSpawn );

	RegConsoleCmd( "+glow", Command_GlowOn );
	RegConsoleCmd( "-glow", Command_GlowOff );
	RegConsoleCmd( "glow", Command_Glow );
	
	VIP_Register( "Glow", OnVIPMenu ); 
	
	glow_menu = CreateMenu( GlowMenuHandler, MenuAction_Select|MenuAction_DisplayItem );
	SetMenuPagination( glow_menu, MENU_NO_PAGINATION );
	SetMenuTitle( glow_menu, "Glow" );
	AddMenuItem( glow_menu, "CONCMD", "Console Commands" );
	AddMenuItem( glow_menu, "TOGGLE", "Turn On" );
	AddMenuItem( glow_menu, "FPDISP", "First Person Display" );
	AddMenuItem( glow_menu, "RED", "Red" );
	AddMenuItem( glow_menu, "GREEN", "Green" );
	AddMenuItem( glow_menu, "BLUE", "Blue" );
	if( GAME == GAME_CSGO ) {
		AddMenuItem( glow_menu, "COLORHINT", "Hold Shift/Space to decrease/slow", ITEMDRAW_DISABLED );
	} else if( GAME == GAME_TF2 ) {
		AddMenuItem( glow_menu, "COLORHINT", "Hold Ctrl/Space to decrease/slow", ITEMDRAW_DISABLED );
	}
	SetMenuExitButton( glow_menu, true );
}

public OnLibraryAdded( const String:name[] ) {
	if( StrEqual(name,"donations") ) 
		VIP_Register( "Glow", OnVIPMenu ); 
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	VIP_Unregister();
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( material );
}

//-------------------------------------------------------------------------------------------------
public Action:OnSetTransmit( entity, client ) {
	if( !IsPlayerAlive(client) ) return Plugin_Continue;
	if( GetClientTeam(client) == glow_team[entity] ) return Plugin_Continue;
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnClientCookiesCached( client ) {
	LoadClientPrefs( client );
}

//-------------------------------------------------------------------------------------------------
CreateSprite( client, color[3] ) { 
	new ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	
	SetEntityModel( ent, material );
	SetEntityRenderColor( ent, color[0], color[1], color[2] );
	
	glow_team[ent] = GetClientTeam(client);
	if( GAME == GAME_CSGO ) {
		// csgo: show glow to team
		SDKHook( ent, SDKHook_SetTransmit, OnSetTransmit );
		SetEdictFlags( ent, GetEdictFlags(ent) & ~FL_EDICT_ALWAYS );
	} else {
		// tf2: always show glow
		SetEdictFlags( ent, FL_EDICT_ALWAYS );
	}

	SetEntityRenderMode( ent, RENDER_WORLDGLOW );  
	DispatchKeyValue( ent, "GlowProxySize", GLOW_SIZE );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "10.0" ); 
	DispatchKeyValue( ent, "scale", GLOW_SIZE ); 
	
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 ); 
	DispatchSpawn( ent ); 
	
	AcceptEntityInput( ent, "ShowSprite" );
	
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", client );
 
	new Float:pos[3] = {0.0, 0.0, 48.0};
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	return ent;
}

//-------------------------------------------------------------------------------------------------
CreateSpriteFP( client, color[3] ) {

	new ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	
	SetEntityModel( ent, material );
	SetEntityRenderColor( ent, color[0], color[1], color[2] );
	
	SetEntityRenderMode( ent, RENDER_WORLDGLOW ); 
	DispatchKeyValue( ent, "GlowProxySize", "3.0" );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "10.0" ); 
	if( GAME == GAME_CSGO ) {
		DispatchKeyValue( ent, "scale", "10.0" ); 
	} else {
		DispatchKeyValue( ent, "scale", "15.0" ); 
	}
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	
	DispatchSpawn( ent );
	
	AcceptEntityInput( ent, "ShowSprite" );
	
	new viewent = GetEntPropEnt( client, Prop_Send, "m_hViewModel" );
	
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", viewent );
	
	new Float:pos[3] = {12.0, -3.0, -3.0};
	if( GAME == GAME_TF2 ) {
		pos[0] = 12.0;
		pos[1] = 0.0;
		pos[2] = -8.0;
	}
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	return ent;
}

//-------------------------------------------------------------------------------------------------
UpdateGlowColor( client ) {
	if( IsValidEntity(glow_sprites[client]) ) {
		SetEntityRenderColor( 
			glow_sprites[client], 
			glow_color[client][0], 
			glow_color[client][1], 
			glow_color[client][2] );
	}
	if( IsValidEntity(glow_sprites2[client]) ) {
		SetEntityRenderColor( 
			glow_sprites2[client], 
			glow_color[client][0], 
			glow_color[client][1], 
			glow_color[client][2] );
	} 
}

//-------------------------------------------------------------------------------------------------
bool:IsGlowDesired( client ) {
	return glow_on[client];
}

//-------------------------------------------------------------------------------------------------
GlowOn( client ) {
	glow_on[client] = true;
	if( !IsPlayerAlive(client) ) return;
	if( !IsValidEntity(glow_sprites[client]) ) {
		glow_sprites[client] = EntIndexToEntRef(CreateSprite( client, glow_color[client] ));
	}
	if( !IsValidEntity(glow_sprites2[client]) && glow_fp[client] ) {
		glow_sprites2[client] = EntIndexToEntRef(CreateSpriteFP( client, glow_color[client] ));
	} 
}

//-------------------------------------------------------------------------------------------------
GlowOff( client, bool:save=true ) {
	if( IsValidEntity(glow_sprites[client]) ) {
		AcceptEntityInput(glow_sprites[client],"Kill");
		glow_sprites[client] = -1;
	}
	if( IsValidEntity(glow_sprites2[client] ) ) {
		AcceptEntityInput(glow_sprites2[client],"Kill");
		glow_sprites2[client] = -1; 
	}
	if( save ) glow_on[client] = false;	
}

//-------------------------------------------------------------------------------------------------
LoadClientPrefs( client ) {
	new userid = GetClientUserId( client );
	
	// cookie_loaded contains the userid of the last load operation, if its equal
	// that means the cookie was already loaded for this unique person
	if( userid == cookie_loaded[client] ) return;
	
	if( AreClientCookiesCached(client) ) {
		cookie_loaded[client] = userid; // mark as "loaded"
		
		decl String:data[128];
		GetClientCookie( client, cookieprefs, data, sizeof data );
		
		// if the cookie doesn't have a value, set a default color
		if( data[0] == 0 ) {
			glow_color[client][0] = 128;
			glow_color[client][1] = 128;
			glow_color[client][2] = 128;
			glow_fp[client] = true;
			glow_on[client] = false;
		} else {
			glow_fp[client] = (data[0] == '1');
			ParseColor( data[1], glow_color[client] );
			glow_on[client] = (data[7] == '1');
		}
	}
}

//-------------------------------------------------------------------------------------------------
SaveClientPrefs( client ) {
	if( GetClientUserId(client) != cookie_loaded[client] ) return;
	decl String:data[16];
	
	// RRGGBB hexcode
	FormatEx( data, sizeof data, "%s%02X%02X%02X%s", glow_fp[client]?"1":"0", glow_color[client][0], glow_color[client][1], glow_color[client][2], glow_on[client] ? "1":"0" );
	
	SetClientCookie( client, cookieprefs, data );
}

//-------------------------------------------------------------------------------------------------
bool:GetColorFromCmd( client, args ) {
	if( args < 1 ) return true;
	decl String:arg[64]; 
	GetCmdArg( 1, arg, sizeof arg );
	if( !ParseColor(arg, glow_color[client] ) ) {
		PrintToChat( client, "\x01[Glow] \x07Invalid Color!" );
		return false;
	}
	SaveClientPrefs( client );
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_GlowOn( client, args ) {
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	if( Donations_GetClientLevel(client) == 0 ) {
		ReplyToCommand( client, "Glowing is only available for VIPs." );
		return Plugin_Handled;
	}
	LoadClientPrefs(client);
	
	if( !GetColorFromCmd( client,args ) ) return Plugin_Handled;
	GlowOn( client );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_GlowOff( client, args ) {
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	if( Donations_GetClientLevel(client) == 0 ) {
		ReplyToCommand( client, "Glowing is only available for VIPs." );
		return Plugin_Handled;
	}

	GlowOff( client );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_Glow( client, args ) {
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	if( Donations_GetClientLevel(client) == 0 ) {
		ReplyToCommand( client, "Glowing is only available for VIPs." );
		return Plugin_Handled;
	}
	LoadClientPrefs(client);
	if( !GetColorFromCmd( client, args ) ) return Plugin_Handled;
	
	if( IsValidEntity( glow_sprites[client] ) ) {
		GlowOff( client );
	} else {
		GlowOn( client );
	}
	SaveClientPrefs( client );
	return Plugin_Handled;
}
 
//-------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) ); 
	if( client == 0 ) return;
	GlowOff(client,false); 
}

//-------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	if( GetClientTeam( client ) < 2 ) return;
	if( glow_on[client] ) {
		GlowOn( client );
	}
}

//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04The glow feature places a glow around your person which is only visible to your teammates or dead players." );
	} else if( action == VIP_ACTION_USE ) {
		LoadClientPrefs(client);
		DisplayMenu( glow_menu, client, MENU_TIME_FOREVER );
	}
}

//-------------------------------------------------------------------------------------------------
public GlowMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_DisplayItem ) {
		new client = param1;
		decl String:text[64];
		if( param2 == GM_TOGGLE ) {
			
			FormatEx( text,sizeof text, "%s", (glow_on[client])?"Turn Off":"Turn On" );
			RedrawMenuItem( text );
		} else if( param2 == GM_FPDISP ) {
			FormatEx( text, sizeof text, "First Person Display: %s", glow_fp[client]?"On":"Off" );
			RedrawMenuItem( text );
		} else if( param2 == GM_RED ) {
			FormatEx( text, sizeof text, "Red: %d%%", (glow_color[client][0] * 100+128) / 255);
			RedrawMenuItem( text );
		} else if( param2 == GM_GREEN ) {
			FormatEx( text, sizeof text, "Green: %d%%", (glow_color[client][1] * 100+128) / 255);
			RedrawMenuItem( text );
		} else if( param2 == GM_BLUE ) {
			FormatEx( text, sizeof text, "Blue: %d%%", (glow_color[client][2] * 100+128) / 255);
			RedrawMenuItem( text );
		}
	} else if( action == MenuAction_Select ) {
		new client = param1;
		if( param2 == GM_TOGGLE ) {
			if( (glow_on[client]) ) {
				GlowOff( client );
			} else {
				GlowOn( client );
			}
			SaveClientPrefs( client );
			DisplayMenu( glow_menu, client, MENU_TIME_FOREVER );
		} else if( param2 == GM_CONCMD ) {
			PrintToChat( client, "Bind \"glow\" or \"+glow\" to a key for easy access." );
			PrintToChat( client, 
				"The glow command takes one parameter which changes the color of it, formats are RGB (0-9), RRGGBB (hexcode), or a color name." );
			DisplayMenu( glow_menu, client, MENU_TIME_FOREVER );
		} else if( param2 == GM_FPDISP ) {
			glow_fp[client] = !glow_fp[client];
			if( IsGlowDesired(client) ) {
				GlowOff(client);
				GlowOn(client);
			}
			SaveClientPrefs(client);
			DisplayMenu( glow_menu, client, MENU_TIME_FOREVER );
		} else if( param2 == GM_RED || param2 == GM_BLUE || param2 == GM_GREEN ) {
			new index;
			if( param2 == GM_RED ) index = 0;
			else if( param2 == GM_GREEN ) index = 1;
			else if( param2 == GM_BLUE ) index = 2;
			new buttons = GetClientButtons(client);
			new step = (buttons & IN_JUMP) ? 2 : 25;
			if(buttons & (IN_SPEED|IN_DUCK)) step = -step;
			if( step > 0 && glow_color[client][index] == 255 ) {
				glow_color[client][index] = 0;
			} else if( step < 0 && glow_color[client][index] == 0 ) {
				glow_color[client][index] = 255;
			} else {
				glow_color[client][index] = Saturate( glow_color[client][index] + step, 0, 255 );
			}
			
			GlowOn(client);
			UpdateGlowColor(client);
			SaveClientPrefs(client);
			DisplayMenu( glow_menu, client, MENU_TIME_FOREVER );
		}
	}
}
