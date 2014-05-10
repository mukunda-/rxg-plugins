// simple MOTD

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "motd",
	author = "REFLEX-GAMERS",
	description = "message of the day!",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

new bool:show_motd[MAXPLAYERS+1];

new motd_lines;
new String:motd_text[8][256];

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadMOTDFile();

	HookEvent( "player_spawn", Event_PlayerSpawn );
	
	RegServerCmd( "motd_refresh", Command_motd_refresh );
	RegConsoleCmd( "motd", Command_motd );
}

//----------------------------------------------------------------------------------------------------------------------
LoadMOTDFile() {
	motd_lines = 0;
	decl String:filepath[256];
	BuildPath( Path_SM, filepath, 256, "configs/motd.txt" );
	if( !FileExists(filepath) ) return;

	new Handle:f = OpenFile( filepath, "r" );

	while( !IsEndOfFile(f) ) {
		if( ReadFileLine( f, motd_text[motd_lines], 256 ) ) {
			motd_lines++;
			if( motd_lines == 8 ) break;
		} else {
			motd_text[motd_lines][0] = 0;
			motd_lines++;
			if( motd_lines == 8 ) break;
		}

	}
	
	CloseHandle( f );

	// add colors
	for( new i = 0; i < motd_lines; i++ ) {

		new found = 0;
		found += ReplaceString( motd_text[i], 256, "{C1}", "\x01" );
		found += ReplaceString( motd_text[i], 256, "{C2}", "\x02" );
		found += ReplaceString( motd_text[i], 256, "{C3}", "\x03" );
		found += ReplaceString( motd_text[i], 256, "{C4}", "\x04" );
		found += ReplaceString( motd_text[i], 256, "{C5}", "\x05" );
		found += ReplaceString( motd_text[i], 256, "{C6}", "\x06" );
		found += ReplaceString( motd_text[i], 256, "{C7}", "\x07" );

		if( found > 0 ) {
			// colored line prefix
			Format( motd_text[i], 256, "\x01\x0B%s", motd_text[i] );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	show_motd[client] = true;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	if( client > 0 ) {
		if( show_motd[client] ) {
			PrintMOTD(client);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public PrintMOTD( client ) {
	show_motd[client] = false;
	
	for( new i = 0; i < motd_lines; i++ ) {
		PrintToChat( client, motd_text[i] );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_motd( client ,args ) {
	PrintMOTD( client );
	return Plugin_Handled;
}

public Action:Command_motd_refresh( args ) {
	LoadMOTDFile()
	return Plugin_Handled;
}
