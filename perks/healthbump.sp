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
#include <clientprefs>
#include <donations>

#pragma semicolon 1

// 2.0.0
//   vip menu

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Healthbump",
	author = "mukunda",
	description = "Increases donator health (pay2win)",
	version = "2.0.0",
	url = "http://www.reflex-gamers.com"
};

new Handle:cookie;
new Handle:mymenu;

#define AMOUNT 102

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	cookie = RegClientCookie( "healthbumpv2", "Healthbump", CookieAccess_Protected );
	HookEvent( "player_spawn", OnPlayerSpawn );
	
	mymenu = CreateMenu( MyMenuHandler, MenuAction_Select|MenuAction_DisplayItem );
	SetMenuPagination( mymenu, MENU_NO_PAGINATION );
	SetMenuTitle( mymenu, "Unfair Advantage Selector" );
	AddMenuItem( mymenu, "HEALTHBUMP", "Health: 100" );
	SetMenuExitButton( mymenu, true ); 
	
	VIP_Register( "Healthbump", OnVIPMenu );
}

public OnLibraryAdded( const String:name[] ) {
	if( StrEqual(name,"donations") ) 
		VIP_Register( "Healthbump", OnVIPMenu );
}

public OnPluginEnd() {
	VIP_Unregister();
}
//-------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if( client == 0 ) return;
	if( GetClientTeam(client) < 2 ) return;
	new hp = 100;
	if( AreClientCookiesCached(client) ) {
		decl String:c[4];
		GetClientCookie( client, cookie, c, sizeof(c) );
		
		if( c[0] == 0 ) hp = 102;
		else if( c[0] == '0' ) return;
		else if( c[0] == '1' ) hp = 101;
		else if( c[0] == '2' ) hp = 102;
	}
	if( Donations_GetClientLevelDirect( client ) ) {
		SetEntityHealth( client, hp );
	}
}

//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04VIPs can choose to raise their health all the way to 102." );
	} else if( action == VIP_ACTION_USE ) {
		if( AreClientCookiesCached(client) ) {
			DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
		}
	}
}

//-------------------------------------------------------------------------------------------------
public MyMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	new client = param1;
	decl String:c[4];
	if( action == MenuAction_DisplayItem ) {
		if( param2 == 0 ) {
			decl String:text[64];
			GetClientCookie( client, cookie, c, sizeof(c) );
			if( c[0] == '0' ) text = "Health: 100 (Like Everyone Else)";
			else if( c[0] == '1' ) text = "Health: 101 (Semi Balanced)";
			else text = "Health: 102 (Maximum Hulking Mode Advantage)";
			RedrawMenuItem( text );
		}
	} else if( action == MenuAction_Select ) {
		if( param2 == 0 ) {
			GetClientCookie( client, cookie, c, sizeof(c) );
			if( c[0] == '0' ) c[0] = '1';
			else if( c[0] == '1' ) c[0] = '2';
			else c[0] = '0';
			SetClientCookie( client, cookie, c );
			DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
		}
	}
}
