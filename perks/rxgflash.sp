

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <flashmod>

#include <rxgcolorparser>
#include <donations>

#undef REQUIRE_PLUGIN
#include <autoslay>

#pragma semicolon 1

// 2.0.0
//	 vip menu
// 1.1.0 8:24 AM 11/26/2013
//   admin force command

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxgflash",
	author = "mukunda",
	description = "flashbang effects",
	version = "2.0.0",
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
new UserMsg:g_FadeUserMsgId;

#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)
#define HIDEHUD_RADAR				( 1<<12 )	// Hide the radar

new bool:hidehud_active[MAXPLAYERS+1];
new cookie_loaded[MAXPLAYERS+1];
new flash_color[MAXPLAYERS+1][3];
new bool:flash_enable[MAXPLAYERS+1];

new Handle:g_cookie; 

new Float:round_start_time;

new Handle:rxgflash_punish_time;
new Float:c_rxgflash_punish_time;

new Handle:flash_menu;

enum { 
	GM_ENABLED,
	GM_RED,
	GM_GREEN,
	GM_BLUE,
	GM_HINT,
	GM_PREVIEW
};
 
//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	if( convar == rxgflash_punish_time ) { 
		c_rxgflash_punish_time = GetConVarFloat( rxgflash_punish_time );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");

	g_cookie = RegClientCookie("FlashColorSettings", "Flash Color Settings", CookieAccess_Protected );
	rxgflash_punish_time = CreateConVar( "rxgflash_punish_time", "12.0", "automatic flash punishing time" );
	HookConVarChange( rxgflash_punish_time, OnConVarChanged );
	c_rxgflash_punish_time = GetConVarFloat( rxgflash_punish_time );
	
	g_FadeUserMsgId = GetUserMessageId("Fade");
 
	HookEvent( "player_death", OnPlayerDeath );
	HookEvent( "round_start", OnRoundStart );
	RegConsoleCmd( "sm_flashcolor", Command_Flashcolor );
	RegConsoleCmd( "sm_forceflashcolor", Command_Forceflashcolor );
	
	flash_menu = CreateMenu( FlashMenuHandler, MenuAction_Select|MenuAction_DisplayItem );
	SetMenuPagination( flash_menu, MENU_NO_PAGINATION );
	SetMenuTitle( flash_menu, "Flash Color" );
	AddMenuItem( flash_menu, "ENABLED", "Enabled" );
	AddMenuItem( flash_menu, "RED", "Red" );
	AddMenuItem( flash_menu, "GREEN", "Green" );
	AddMenuItem( flash_menu, "BLUE", "Blue" );
	AddMenuItem( flash_menu, "COLORHINT", "Hold Shift/Space to decrease/slow", ITEMDRAW_DISABLED );
	AddMenuItem( flash_menu, "PREVIEW", "Preview" );
	SetMenuExitButton( flash_menu, true );
	
	VIP_Register( "Flash Color", OnVIPMenu );
}

public OnLibraryAdded( const String:name[] ) {
	if( StrEqual(name,"donations") ) 
		VIP_Register( "Flash Color", OnVIPMenu );
}
public OnPluginEnd() {
	VIP_Unregister();
}


//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:naefwefaw[], bool:dontbroadcast ) {
	round_start_time = GetGameTime();
}

//-------------------------------------------------------------------------------------------------
LoadPrefs( client ) {
	new userid = GetClientUserId( client );
	
	// cookie_loaded contains the userid of the last load operation, if its equal
	// that means the cookie was already loaded for this unique person
	if( userid == cookie_loaded[client] ) return;
	
	if( AreClientCookiesCached(client) ) {
		cookie_loaded[client] = userid; // mark as "loaded"
		decl String:data[32];
		GetClientCookie( client, g_cookie, data, sizeof data );
		// if the cookie doesn't have a value set a default color
		if( data[0] == 0 ) {
			flash_color[client][0] = 255;
			flash_color[client][1] = 255;
			flash_color[client][2] = 255;
			flash_enable[client] = false; 
		} else {
			flash_enable[client] = (data[0] == '1');
			ParseColor( data[1], flash_color[client] );
		}
	}
}

//-------------------------------------------------------------------------------------------------
SavePrefs( client ) {
	new userid = GetClientUserId( client );
	if( userid != cookie_loaded[client] ) return; // dont overwrite prefs with uninitialized ones
	decl String:data[16];
	// RRGGBB hexcode
	FormatEx( data, sizeof data, "%s%02X%02X%02X", flash_enable[client]?"1":"0", flash_color[client][0], flash_color[client][1], flash_color[client][2] );
	
	SetClientCookie( client, g_cookie, data );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_Flashcolor( client, args ) {
	if( Donations_GetClientLevel(client) == 0 ) {
		ReplyToCommand( client, "Flashcolor is only available to VIPs." );
		return Plugin_Handled;
	}
	if( args == 0 ) {
		ReplyToCommand( client, "Usage: /flashcolor <color> - Change the color of your flashbang effect. Use '/flashcolor off' to disable." );
		return Plugin_Handled;
	}
	
	decl String:arg[32];
	GetCmdArg(1,arg,sizeof(arg));
	
	if( StrEqual( arg, "off", false ) ) {
		flash_enable[client] = false;
		SavePrefs( client );
		PrintToChat( client, "Flash color disabled." );
		return Plugin_Handled;
	}

	if( !ParseColor( arg, flash_color[client] ) ) {
		PrintToChat( client, "Invalid Color." );
		return Plugin_Handled;
	}
	flash_enable[client] = true;
	SavePrefs( client );
	ReplyToCommand( client, "Flash color changed to\"%s\"!", arg ); 
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_Forceflashcolor( client, args ) {
	if( args < 2 ) {
		ReplyToCommand( client, "Usage: sm_forceflashcolor <player> <color>" );
		return Plugin_Handled;
	}
	
	decl String:arg[64];
	GetCmdArg(1,arg,sizeof(arg));
	
	new target = FindTarget( client, arg, true );
	if( target == -1 ) return Plugin_Handled;
	GetCmdArg( 2,arg,sizeof(arg));
	if( !ParseColor( arg, flash_color[target] ) ) {
		PrintToChat( client, "Invalid Color." );
		return Plugin_Handled;
	}
	flash_enable[target] = true;
	SavePrefs( target );

	ReplyToCommand( client, "Changed flashcolor of \"%N\" to \"%s\".", target, arg );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
//public OnClientPutInServer( client ) {
//	hidehud_active[client] = false;
//}
// this doesnt need to be initialized, because the error from it not being wont be noticeable

//-------------------------------------------------------------------------------------------------
public Action:HudTimer( Handle:Timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	if( client <= 0 ) return Plugin_Handled;
	SetEntProp( client, Prop_Send, "m_iHideHUD" , 0);//
	hidehud_active[client] = false;

	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public HideHud( client, Float:time ) {

	SetEntProp( client, Prop_Send, "m_iHideHUD" ,
		HIDEHUD_HEALTH|HIDEHUD_RADAR|HIDEHUD_MISCSTATUS|HIDEHUD_BONUS_PROGRESS|HIDEHUD_CHAT|HIDEHUD_CROSSHAIR );
	hidehud_active[client] = true;
	CreateTimer( time, HudTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE );
} 
 
//-------------------------------------------------------------------------------------------------
public Flashmod_OnPlayerTeamflash( flasher, count ) {
	if( count >= 2 && (GetGameTime() - round_start_time) < c_rxgflash_punish_time ) {
		if( LibraryExists( "autoslay" ) ) {
			Autoslay_ExplodePlayer(flasher);
		} else {
			ForcePlayerSuicide(flasher);
		}
		PrintToChatAll( "\x01 \x02Slayed %N for teamflashing.", flasher );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Flashmod_OnPlayerFlashed( flasher, flashee, &Float:alpha, &Float:duration ) {
	new bool:flash_coloring = true;
	new color[4] = { 0,0,0, 255};
	
	if( Donations_GetClientLevel( flasher ) == 0 ) {
		flash_coloring=false;
	} else {
		LoadPrefs(flasher);
		flash_coloring = flash_enable[flasher]; 
		for( new i = 0; i < 3; i++ ) {
			color[i] = flash_color[flasher][i];
		}
	}

	// reduce team-flash for donators, dont reduce self flash
	new bool:flash_reduce = (flasher != flashee) && (GetClientTeam(flasher) == GetClientTeam(flashee)) && (Donations_GetClientLevel(flashee) > 0);
	
	if( flash_coloring ) {
		new clients[2];
		clients[0] = flashee; 
		
		new duration2 = duration < 2.5 ? RoundToZero(duration*512) :1024;
		new Float:holdtime_f = (duration-2.8);//*512.0;
		if( holdtime_f < 0.0 ) holdtime_f = 0.0;
 
		if( flash_reduce ) {	//
			holdtime_f = holdtime_f * 0.75; 
		}
		new holdtime = RoundToZero(holdtime_f*512.0);	
	
		new flags = ( 0x01| 0x10);
		if( duration < 2.5 ) {
			color[3] = RoundToZero(duration * (255.0/2.5));
		}
		//color[3] = RoundToZero(alpha);
		new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);
		if (GetUserMessageType() == UM_Protobuf) {
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
	
	
		if( holdtime_f > 0.0 ) {
			HideHud( flashee, holdtime_f );
		}
		
		//	alpha = 128.0;
		if( duration > 2.5 )
			duration = 2.5;
			
		if( flash_reduce ) {	//
			duration = duration * 0.75;
		}
	} else {
		if( flash_reduce ) {
			duration = duration * 0.75;
		}
	}
		
	return Plugin_Changed;
}
 
//-------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	if( !client ) return;

	if( hidehud_active[client] ) {
		hidehud_active[client] = false;
		SetEntProp( client, Prop_Send, "m_iHideHUD" , 0);
	 
		new clients[2];
		clients[0] = client;
		new duration2 = 512;
		new holdtime = 0;

		new flags = 0x10|0x04|0x01;
		new color[4] = { 255,0,0, 255};
		new Handle:message = StartMessageOne( "Fade", client );
		if( GetUserMessageType() == UM_Protobuf ) {
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
}

//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04The flash color feature allows you to use a different color to blind people with." );
	} else if( action == VIP_ACTION_USE ) {
		LoadPrefs(client);
		DisplayMenu( flash_menu, client, MENU_TIME_FOREVER );
	}
}

//-------------------------------------------------------------------------------------------------
public FlashMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_DisplayItem ) {
		new client = param1;
		decl String:text[64];
		if( param2 == GM_ENABLED ) {
			
			FormatEx( text,sizeof text, "Enabled: %s", flash_enable[client]?"On":"Off" );
			RedrawMenuItem( text );
		} else if( param2 == GM_RED ) {
			FormatEx( text, sizeof text, "Red: %d%%", (flash_color[client][0] * 100+128) / 255);
			RedrawMenuItem( text );
		} else if( param2 == GM_GREEN ) {
			FormatEx( text, sizeof text, "Green: %d%%", (flash_color[client][1] * 100+128) / 255);
			RedrawMenuItem( text );
		} else if( param2 == GM_BLUE ) {
			FormatEx( text, sizeof text, "Blue: %d%%", (flash_color[client][2] * 100+128) / 255);
			RedrawMenuItem( text );
		}
	} else if( action == MenuAction_Select ) {
		new client = param1;
		if( param2 == GM_ENABLED ) {
			flash_enable[client] = !flash_enable[client];
			SavePrefs( client );
			DisplayMenu( flash_menu, client, MENU_TIME_FOREVER );
		} else if( param2 == GM_RED || param2 == GM_BLUE || param2 == GM_GREEN ) {
			new index;
			if( param2 == GM_RED ) index = 0;
			else if( param2 == GM_GREEN ) index = 1;
			else if( param2 == GM_BLUE ) index = 2;
			new buttons = GetClientButtons(client);
			new step = (buttons & IN_JUMP) ? 2 : 25;
			if(buttons & IN_SPEED) step = -step;
			if( step > 0 && flash_color[client][index] == 255 ) {
				flash_color[client][index] = 0;
			} else if( step < 0 && flash_color[client][index] == 0 ) {
				flash_color[client][index] = 255;
			} else {
				flash_color[client][index] = Saturate( flash_color[client][index] + step, 0, 255 );
			}
			 
			SavePrefs(client);
			DisplayMenu( flash_menu, client, MENU_TIME_FOREVER );
		} else if( param2 == GM_PREVIEW ) {
			new flags = 0x01;
			new color[4] = { 0,0,0, 255};
			for( new i = 0; i < 3; i++ ) color[i] = flash_color[client][i];
			new Handle:message = StartMessageOne( "Fade", client );
			if( GetUserMessageType() == UM_Protobuf ) {
				PbSetInt(message, "duration", 512);
				PbSetInt(message, "hold_time", 64);
				PbSetInt(message, "flags", flags);
				PbSetColor(message, "clr", color);
			} else {
				
				BfWriteShort( message, 512 );
				BfWriteShort( message, 64 );
				BfWriteShort( message, flags );
				for( new i = 0; i < 4; i++ )
					BfWriteByte( message, color[i] );
			}
			EndMessage();
			DisplayMenu( flash_menu, client, MENU_TIME_FOREVER );
		}
	}
}
