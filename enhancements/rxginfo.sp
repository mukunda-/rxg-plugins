#include <sourcemod>
#include <sdktools>

#pragma semicolon 1


public Plugin:myinfo = {
	name = "rxginfo",
	author = "mukunda",
	description = "rxg info things",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//----------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "say", Command_say );
	RegConsoleCmd( "say_team", Command_say );
}

//----------------------------------------------------------------------------------------
public Action:Command_say( client, args ) {
	decl String:text[32];
	GetCmdArgString( text, sizeof(text) );
	StripQuotes(text);
	new start = 0;
	new bool:captured = false;
	if(text[0] == '/' || text[0] == '!' ) start = 1;
	if( StrEqual( text[start],"motd",false) ) {
		PrintToChat( client, "Opening MOTD panel...");
		ShowMOTDPanel( client, "Message of the day", "http://www.mukunda.com/test/test2.html", MOTDPANEL_TYPE_URL ); //http://www.reflex-gamers.com/csblog/csgopopup.html", MOTDPANEL_TYPE_URL );
		captured = true;
	}
	
	if( captured && text[0] == '/' ) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
