
/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#pragma semicolon 1

//#define BYPASS_DISABLED

// 1.0.1
//  fix for sourcetv

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = 
{
	name = "Radar Overlay",
	author = "mukunda",
	description = "Highlights players which are visible on radar.",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
new bool:g_active;

new Float:g_spotted_time[MAXPLAYERS+1];
new g_sprites[MAXPLAYERS+1]; 
new g_enabled[MAXPLAYERS+1];

new Handle:cookie;
new Handle:menu_prefs;

#define SPOTTED_TIME 0.2

//-------------------------------------------------------------------------------------------------
public OnPluginStart() { 
	
	CreateTimer( 0.1, OnUpdate, _, TIMER_REPEAT );
	
	for( new i = 1; i <= MaxClients; i++ ) {
		g_enabled[i] = false;
	}
	
	cookie = RegClientCookie( "cookie_spottedicon", "SpottedIcon Enabled Switch", CookieAccess_Private );
	SetupPrefMenus();
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {

	PrecacheModel( "materials/rxg/spotted.vmt" );
	AddFileToDownloadsTable( "materials/rxg/spotted.vmt" );
	AddFileToDownloadsTable( "materials/rxg/spotted.vtf" );

	g_active = true;
	for( new i = 1; i <= MaxClients; i++ ) {
		g_spotted_time[i] = -5.0;
		g_sprites[i] = INVALID_ENT_REFERENCE;
	}
}

//-------------------------------------------------------------------------------------------------
public OnMapEnd() {
	g_active = false;
}
 
//-------------------------------------------------------------------------------------------------
public Action:OnSpriteSetTransmit( entity, client ) {

	new owner = GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" );
	if( GetGameTime() - g_spotted_time[owner] > SPOTTED_TIME ) return Plugin_Handled;
	
	if( IsFakeClient(client) ) return Plugin_Continue;

#if !defined BYPASS_DISABLED
	if( !g_enabled[client] ) return Plugin_Handled;
	if( IsPlayerAlive(client) ) return Plugin_Handled;
#endif	
	
	
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
CreateSprite( client ) {
	new ent = EntRefToEntIndex( g_sprites[client] ); 
	if( ent != INVALID_ENT_REFERENCE ) return; // return if already has sprite
 
	// create sprite and hook above player's head
	ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	
	SetEntityModel( ent, "materials/rxg/spotted.vmt" );
	DispatchKeyValue( ent, "rendercolor", "15 90 40" );
	DispatchKeyValue( ent, "rendermode", "9" );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "20.0" ); 
	DispatchKeyValue( ent, "scale", "100.0" );
	DispatchKeyValue( ent, "GlowProxySize", "1000.0" );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", client );
	
	new Float:pos[3];
	pos[0] = 0.0;
	pos[1] = 0.0;
	pos[2] = 36.0;

	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	SetEdictFlags( ent, GetEdictFlags(ent)&(~FL_EDICT_ALWAYS) ); // allow settransmit hooks
	SDKHook( ent, SDKHook_SetTransmit, OnSpriteSetTransmit );

	g_sprites[client] = EntIndexToEntRef(ent);
}

//-------------------------------------------------------------------------------------------------
public Action:OnUpdate( Handle:timer ) {
	if( !g_active ) return;
	
	new Float:time = GetGameTime();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		if( IsPlayerAlive(i) ) {
			if( GetEntProp( i, Prop_Send, "m_bSpotted" ) ) {
				 
				g_spotted_time[i] = time;
				CreateSprite(i);
			}
		} else {

		}
	}
}



// cookie menu
//-------------------------------------------------------------------------------------------------
public PrefsHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	
 
	if( action == MenuAction_DrawItem ) {
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if( StrEqual( info, "enable" ) ) {
			return g_enabled[param1] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
			
		} else if ( StrEqual( info, "disable" ) ) {
			return !g_enabled[param1] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
		} 
		
	} else if( action == MenuAction_Select ) {
		if( !AreClientCookiesCached(param1) ) return 0;
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if( StrEqual( info, "enable" ) ) {
			g_enabled[param1] = true;
			SetClientCookie( param1, cookie, "1" );
			PrintToChat( param1, "\x01 \x04Radar overlay enabled." );
		} else if ( StrEqual( info, "disable" ) ) {
			g_enabled[param1] = false;
			SetClientCookie( param1, cookie, "0" );
			PrintToChat( param1, "\x01 \x04Radar overlay disabled." );
		}
		
		
	}
	return 0;
}

//-------------------------------------------------------------------------------------------------
public OnSettings(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	if( action == CookieMenuAction_DisplayOption ) {

	} else if( action == CookieMenuAction_SelectOption ) {

		DisplayMenu( menu_prefs, client, MENU_TIME_FOREVER );
	}
}

//-------------------------------------------------------------------------------------------------
SetupPrefMenus() {
	menu_prefs = CreateMenu(PrefsHandler,MENU_ACTIONS_DEFAULT|MenuAction_DrawItem);
	SetMenuTitle( menu_prefs, "Radar Overlay Settings" );
	AddMenuItem( menu_prefs, "enable", "Enable" );
	AddMenuItem( menu_prefs, "disable", "Disable" );
	
	SetCookieMenuItem( OnSettings, 0, "Radar Overlay" );
}

//-------------------------------------------------------------------------------------------------
public OnClientCookiesCached(client) {
	decl String:str[32];
	GetClientCookie( client, cookie, str, sizeof str );
	g_enabled[client] = (str[0] == '1');
}
