
#include <sourcemod>
#include <sourceirc>
 
#pragma semicolon 1

public Plugin:myinfo = {
	name = "relay actions",
	author = "mukunda",
	description = "relays logged actions to irc",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new Handle:basechat;

public OnPluginStart() {
	
}

FindBasechat() {
	new Handle:iter=GetPluginIterator();
	new Handle:p;
	while( MorePlugins(iter) && (p = ReadPlugin(iter)) ) {
		decl String:buffer[64];
		GetPluginFilename( p, buffer, sizeof buffer );
		
		if( StrEqual(buffer,"basechat_rxg.smx") ) {
			PrintToChatAll( "found basechat" );
			basechat = p;
			CloseHandle(iter);
			return;
		}
		
	}
	basechat=  INVALID_HANDLE;
	CloseHandle(iter);
}
public OnAllPluginsLoaded() {
	FindBasechat();
	
	
	
}

public Action:OnLogAction(Handle:source, 
                           Identity:ident,
                           client,
                           target,
                           const String:message[]) {
	
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