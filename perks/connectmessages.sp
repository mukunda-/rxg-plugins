
//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <donations>

//  2.0.0
//   vip menu rework
//  1.0.3:
//   removed custom name shit

//1.0.2 - ignore bots

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Connect Messages",
	author = "mukunda",
	description = "Displays a message when VIPs connect",
	version = "2.0.0",
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
#define GAME_CSGO 1
#define GAME_TF2 2

new Game = 0;
new Handle:cookie_data = INVALID_HANDLE;
// cookie format: <enabled><showname><color><reserved><message>
new Handle:mymenu;
new Handle:setmsg_menu;

new bool:client_setting_message[MAXPLAYERS+1];
  
//-------------------------------------------------------------------------------------------------
public Donations_OnClientCached( client, bool:onjoin ) {
	if( !onjoin ) return;
	
	client_setting_message[client] = false;
	if( Donations_GetClientLevel(client) != 0 ) { 
		// print welcome message
		PrintConnectMessage( client );
	}
}
 
//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");
	cookie_data = RegClientCookie( "connectmessage_data", "Connect Message", CookieAccess_Private );
	
	decl String:gameName[30];
	GetGameFolderName(gameName, sizeof(gameName));
	
	if( StrEqual(gameName,"csgo",false) ) {
		Game = GAME_CSGO;
	}
	else if( StrEqual(gameName, "tf", false) ) {
		Game = GAME_TF2;
	}
  
	RegAdminCmd( "sm_admincm", Command_admincm, ADMFLAG_SLAY );
 
	VIP_Register( "Connect Message", OnVIPMenu );
	
	mymenu = CreateMenu( MyMenuHandler, MenuAction_Select|MenuAction_DisplayItem );
	SetMenuPagination( mymenu, MENU_NO_PAGINATION );
	SetMenuTitle( mymenu, "Connect Message" );
	AddMenuItem( mymenu, "EN", "Enabled" );
	AddMenuItem( mymenu, "SN", "Show Name" );
	AddMenuItem( mymenu, "SM", "Set Message" );
	AddMenuItem( mymenu, "PR", "Preview" );
	SetMenuExitButton( mymenu, true );
	
	setmsg_menu = CreateMenu( SetMsgHandler );
	SetMenuTitle( setmsg_menu, "Type your connect message in chat to set it." );
	AddMenuItem( setmsg_menu, "1", "Cancel" );
	SetMenuExitButton( setmsg_menu, false );
	
	RegConsoleCmd( "say", Command_say );
	RegConsoleCmd( "say_team", Command_say );
}

public OnLibraryAdded( const String:name[] ) {
	if( StrEqual(name,"donations") ) 
		VIP_Register( "Connect Message", OnVIPMenu );
}
public OnPluginEnd() {
	VIP_Unregister();
}


//-------------------------------------------------------------------------------------------------
GetMessageCookie( client, String:cookie[], maxlen ) {
	GetClientCookie( client, cookie_data, cookie, maxlen );
	
	// initialize if not
	if( cookie[0] == 0 ) {
		cookie[0] = '0'; // enabled: no
		cookie[1] = '1'; // showname: yes
		cookie[2] = '0'; // color: #0
		cookie[3] = '0'; // reserved
		cookie[4] = 0; ///  empty message
	}
}

//-------------------------------------------------------------------------------------------------
GetClientMessageString( client, String:msg[], maxlen, bool:force=false ) {
	decl String:cookie[128];
	GetMessageCookie( client, cookie, sizeof cookie );
	if( !force ) {
		if( cookie[0] == '0' ) return false;
		if( cookie[4] == 0 ) return false;
	}
	if( cookie[1] == '1' ) {
		if( Game == GAME_CSGO ) {
			FormatEx( msg, maxlen, "\x01 \x0C[%N] \x01- \"%s\"", client, cookie[4] );
		} else if( Game == GAME_TF2 ) {
			FormatEx( msg, maxlen, "\x070088df[%N]\x01 - \"%s\"", client, cookie[4] );
		}
	} else {
		if( Game == GAME_CSGO ) {
			FormatEx( msg, maxlen, "\x01 \x0C\"%s\"",   cookie[4] );
		} else if( Game == GAME_TF2 ) {
			FormatEx( msg, maxlen, "\x070088df\"%s\"",   cookie[4] );
		}
	}
	
	return true;
} 
/*
//-------------------------------------------------------------------------------------------------
SetClientMessageString( client, const String:message[] ) {
	// delete special chars from message
 
	decl String:cookie[128];
	ReadMessageCookie( client,  cookie, sizeof cookie );
	strcopy( cookie[4], sizeof cookie-4, message );
	for( new i = 4; text[i]; i++ ) {
		
		if( text[i] < 32 || text[i] > 126 ) text[i] = ' ';
	}
	SetClientCookie( client, cookie_data, cookie );
}*/

//-------------------------------------------------------------------------------------------------
public Action:Command_admincm( client, args ) {
	if (args < 5 ) {
		ReplyToCommand( client, "sm_admincm [user] [enabled] [showname] [color] [message]" );
		return Plugin_Handled;
	}

	decl String:targetstring[64];
	GetCmdArg( 1, targetstring, sizeof(targetstring) );
	new target = FindTarget( client, targetstring, true );
	if( target == -1 ) return Plugin_Handled;

	decl String:arg[128];
	GetCmdArg( 2, arg, sizeof(arg) );
	new enabled = StringToInt(arg) ? '1' : '0';
	GetCmdArg( 3, arg, sizeof(arg) );
	new showname = StringToInt(arg) ? '1' : '0';
	GetCmdArg( 4, arg, sizeof(arg) );
	new color = StringToInt(arg) + '0' ;
	GetCmdArg( 5, arg, sizeof arg );
	
	Format( arg, sizeof arg, "%c%c%c%c%s", enabled, showname, color, '0', arg );
	
	SetClientCookie( target, cookie_data, arg );
	
	ReplyToCommand( client, "Connect message set. Preview:" );
	PrintConnectMessage( target, false, client );

	return Plugin_Handled;
}
/*
//-------------------------------------------------------------------------------------------------
public Action:Command_cm( client, args ) {
	
	if( !AreClientCookiesCached(client) ) {
		ReplyToCommand( client, "Your client data is still being loaded. Please try again in a moment." );
		return Plugin_Handled;
	}

	decl String:name[64];


	if( args < 2 ) {
		if( args == 1 ) {
			GetCmdArg( 1, name, sizeof(name) );
			if( name[0] == 0 ) {
				ReplyToCommand( client, "Connect message reset." );
				SetClientCookie( client, cookie_message, "" );
				return Plugin_Handled;
			}
		}
		ReplyToCommand( client, "sm_cm - set your connect message quote. (Donators only!)" );
		ReplyToCommand( client, "Usage: sm_cm \"NAME\" \"QUOTE\"" );
		ReplyToCommand( client, "The quote should be relevant to you, if not by you. Max 75 chars." );
		ReplyToCommand( client, "Example: sm_cm \"Storm7117\" \"Pray is probably a serial killer\"" );
		ReplyToCommand( client, "Use sm_cm \"\" to reset." );

		decl String:preview[128];
		GetClientMessageString( client, preview, sizeof(preview ) );
		if( preview[0] != 0 ) {
			ReplyToCommand( client, "Current message: %s", preview );
		} else {
			ReplyToCommand( client, "You currently have no message set!" );
		}
		return Plugin_Handled;
	}
	
	decl String:text[128];

	GetCmdArg( 1, name, sizeof(name) );
	GetCmdArg( 2, text, sizeof(text) );
	
	SetClientMessageString( client, name, sizeof(name), text, sizeof(text) );
	
	ReplyToCommand( client, "Connect message set! Printing a preview in chat..." );
	PrintConnectMessage( client, false, client );

	return Plugin_Handled;
}*/

//-------------------------------------------------------------------------------------------------
PrintConnectMessage( client, bool:all=true, single=0, bool:force=false ) {
	decl String:preview[128];
	if( GetClientMessageString( client, preview, sizeof(preview ), force ) ) {
	
		if( all ) {
			PrintToChatAll( preview );
		} else {
			PrintToChat( single, preview );
		}
	}
}
 
 
//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04VIPs can have the server announce a message when they join." );
	} else if( action == VIP_ACTION_USE ) {
		if( !AreClientCookiesCached( client ) ) return;
		DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
	}
}

//-------------------------------------------------------------------------------------------------
public MyMenuHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_DisplayItem ) {
		new client = param1;
		decl String:info[32];
		GetMenuItem( menu, param2, info, sizeof info );
		if( StrEqual(info,"EN") ) {
			decl String:cookie[8];
			GetMessageCookie( client, cookie, sizeof cookie );
			if( cookie[0] == '1' ) {
				RedrawMenuItem( "Enabled: Yes" );
			} else {
				RedrawMenuItem( "Enabled: No" );
			}
		} else if( StrEqual( info, "SN" ) ) {
			decl String:cookie[8];
			GetMessageCookie( client, cookie, sizeof cookie );
			if( cookie[1] == '1' ) {
				RedrawMenuItem( "Show Name: Yes" );
			} else {
				RedrawMenuItem( "Show Name: No" );
			}
		}
	} else if( action == MenuAction_Select ) {
		new client = param1;
		decl String:info[32];
		GetMenuItem( menu, param2, info, sizeof info );
		if( StrEqual( info, "EN" ) ) {
			decl String:cookie[128];
			GetMessageCookie( client, cookie, sizeof cookie );
			cookie[0] = cookie[0] == '1'?'0':'1';
			SetClientCookie( client, cookie_data, cookie );
			DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
		} else if( StrEqual( info, "SN" ) ) {
			decl String:cookie[128];
			GetMessageCookie( client, cookie, sizeof cookie );
			cookie[1] = cookie[1] == '1'?'0':'1';
			SetClientCookie( client, cookie_data, cookie );
			DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
		} else if( StrEqual( info, "SM" ) ) {
			
			PrintToChat( client, "Type your new connect message; this will not show up in chat." );
			client_setting_message[param1] = true;
			DisplayMenu( setmsg_menu, client, MENU_TIME_FOREVER );
		} else if( StrEqual( info, "PR" ) ) {
			
			PrintToChat( client, "Connect Message Preview:" );
			PrintConnectMessage( client, false, client, true );
			DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
		}
	}
}

//-------------------------------------------------------------------------------------------------
public SetMsgHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	if( action == MenuAction_Select || action == MenuAction_Cancel ) {
		client_setting_message[param1] = false;
		DisplayMenu( mymenu, param1, MENU_TIME_FOREVER );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_say( client, args ) {
	if( client_setting_message[client] ) {
		client_setting_message[client] = false;
		decl String:cookie[128];
		GetMessageCookie( client, cookie, sizeof cookie );
		decl String:msg[128];
		GetCmdArgString( msg, sizeof msg );
		StripQuotes(msg);
		strcopy( cookie[4], sizeof cookie-4, msg );
		if( msg[0] == 0 ) {
			cookie[0] = '0';
			PrintToChat( client, "Connect message removed." );
		} else {
			cookie[0] = '1';
			PrintToChat( client, "Connect message saved." );
		}
		SetClientCookie( client, cookie_data, cookie );
		DisplayMenu( mymenu, client, MENU_TIME_FOREVER );
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
