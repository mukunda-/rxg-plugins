
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <sourceirc>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "relay actions",
	author = "mukunda",
	description = "relays logged actions to irc",
	version = "1.0.1",
	url = "www.mukunda.com"
};

Handle basechat;

//-----------------------------------------------------------------------------
public void OnAllPluginsLoaded() {
	if( !LibraryExists( "sourceirc" ) ) {
		SetFailState( "Required Library \"sourceirc\" not installed!" );
		return;
	}
	FindBasechat();
}

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
}

//-----------------------------------------------------------------------------
void FindBasechat() {
	Handle iter=GetPluginIterator();
	Handle p;
	while( MorePlugins(iter) && (p = ReadPlugin(iter)) ) {
		char buffer[64];
		GetPluginFilename( p, buffer, sizeof buffer );
		
		if( StrEqual(buffer,"basechat_rxg.smx") ) {
			PrintToChatAll( "found basechat" );
			basechat = p;
			CloseHandle(iter);
			return;
		}
		
	}
	basechat = INVALID_HANDLE;
	CloseHandle(iter);
}

//-----------------------------------------------------------------------------
public Action OnLogAction( Handle source, Identity ident, int client,
						   int target, const char[] message ) {
	
	if( ident != Identity_Plugin ) return Plugin_Continue;
	if( source == basechat ) return Plugin_Continue;
	
	IRC_MsgFlaggedChannels( "relay", "\x031,7%s", message );
	/*PrintToChatAll( "source=%d", source );
	PrintToChatAll( "ident=%d", ident );
	PrintToChatAll( "client=%d", client );
	PrintToChatAll( "target=%d", target );
	PrintToChatAll( "msg=%s", message );*/
	return Plugin_Continue;
}