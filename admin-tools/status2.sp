
#include <sourcemod>
#include <regex>

public Plugin:myinfo =
{
	name = "status2",
	author = "mukunda",
	description = "the greater good",
	version = "1.0.3",
	url = "www.mukunda.com"
};
  
 
public OnPluginStart() { 
	RegConsoleCmd( "status2", Command_status2 ); 
}
 
//------------------------------------------------------------------------------------------------- 
public Action:Command_status2( client, args ) {
	PrintToConsole( client, "STATUS2:" );
	
	PrintToConsole( client, "# idx|usrid|     time | steamid             | name" );
	
	new list[MAXPLAYERS];
	new count;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		new userid = GetClientUserId(i);
		list[count++] = i | userid << 8;
	}
	
	SortIntegers( list, count );
	
	//for( new i = 1; i <= MaxClients; i++ ) {
	for( new j = 0; j < count; j++ ) {
		new i = list[j] & 255;
		new userid = list[j] >> 8;
	//	if( !IsClientInGame(i) ) continue;
	//	new userid = GetClientUserId(i);
		if( IsFakeClient(i) ) {
			
			PrintToServer( "# %2d | %d \"%N\" IS A BOT", i, userid, i );
			continue;
		}
		decl String:auth[64];
		new time = RoundToNearest(GetClientTime( i ));
		decl String:timestring[64];
		
		GetClientAuthString( i, auth, sizeof auth );
		if( time >= 60*60 ) {
			FormatEx( timestring, sizeof timestring, "%2d:%02d:%02d", time/(60*60), (time/60)%60, time%60 );
		} else {
			FormatEx( timestring, sizeof timestring, "   %02d:%02d", (time/60)%60, time%60 );
		}
		
		PrintToConsole( client, "# %2d |%4d | %5s | %19s | \"%N\"", i, userid,timestring ,auth,i   );
	}
	
	return Plugin_Handled;
}