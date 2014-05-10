
#include <sourcemod>
#include <sdktools>

#pragma semicolon 1


//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "kdrscore",
	author = "mukunda",
	description = "Change score to K/D * 100",
	version = "1.0.0",
	url = "http://www.reflex-gamers.com"
};

#define MVP_OFFSET_FROM_WEAPON_PURCHASES 256
//#define CASHSPENT_OFFSET_FROM_SCORE 20
#define SCORE_OFFSET_FROM_MVP 20

public OnPluginStart() {
	HookEvent("player_death", Event_PlayerDeath);
	
}

UpdatePlayerScore(client) {
	new frags = GetEntProp( client, Prop_Data, "m_iFrags" );
	new deaths = GetEntProp( client, Prop_Data, "m_iDeaths" );
	if( deaths < 1 ) deaths = 1;
	new score = frags * 100 / deaths;
	if( frags < 20 ) score = score / 2;
	if( frags < 10 ) score = score / 2;
	new mvp_offset = FindSendPropInfo( "CCSPlayer", "m_iWeaponPurchasesThisRound" ) + MVP_OFFSET_FROM_WEAPON_PURCHASES;
	SetEntData( client, mvp_offset + SCORE_OFFSET_FROM_MVP, score );
}

public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new attacker = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	//new assister = GetClientOfUserId( GetEventInt( event, "assister" ) );
	if( victim ) UpdatePlayerScore(victim);
	if( attacker ) UpdatePlayerScore(attacker);
	//if( assister ) UpdatePlayerScore(assister);
}
