
#include <sourcemod>
#include <sdktools>
#include <sourceirc>

#pragma semicolon 1;
#pragma newdecls required;

public Plugin myinfo = {
	name = "SourceIRC -> Rounds",
	author = "WhiteThunder",
	description = "Relays round events",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	HookEvent( "cs_match_end_restart", Event_MatchRestart,
			   EventHookMode_PostNoCopy );
	HookEvent( "round_end", Event_RoundEnd, EventHookMode_PostNoCopy );
}

//-----------------------------------------------------------------------------
public void Event_MatchRestart( Handle event, const char[] name,
								bool dontBroadcast ) {
	
	IRC_MsgFlaggedChannels( "relay", "\x031,15Match Restarted" );
}

//-----------------------------------------------------------------------------
public void Event_RoundEnd( Handle event, const char[] name,
							bool dontBroadcast ) {
	
	int wins_t = GetTeamScore(2);
	int wins_ct = GetTeamScore(3);
	
	if( wins_t == 0 && wins_ct == 0 ) {
		return;
	}
	
	IRC_MsgFlaggedChannels( "relay", "\x031,15Round Ended - CT: %d | T: %d", 
							wins_ct, wins_t );
}
