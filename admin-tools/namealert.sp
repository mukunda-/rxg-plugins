// name alert

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "name alert",
	author = "REFLEX-GAMERS",
	description = "prints name change events in console",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};


//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_changename", Event_Player_ChangeName );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_Player_ChangeName( Handle:event, const String:name[], bool:dontBroadcast ) {
	decl String:text[512];
	
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return; // something strange happened

	decl String:oldname[64];
	decl String:newname[64];

	GetEventString( event, "oldname", oldname, sizeof(oldname) );
	GetEventString( event, "newname", newname, sizeof(newname) );

	decl String:auth[64];
	GetClientAuthString( client, auth, sizeof(auth) );
	
	Format( text, sizeof(text), "NAMECHANGE: %d | %s | %s -> %s", userid, auth, oldname, newname );
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientConnected(i) ) {
			if( IsClientInGame(i) ) {
				PrintToConsole( i, text );
			}
		}
	}
}
