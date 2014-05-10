#include <sourcemod>
#include <sdktools>


//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "killheal",
	author = "reflex-gamers",
	description = "heal on kill",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_death", Event_PlayerDeath );
}

//----------------------------------------------------------------------------------------------------------------------
HealPlayer( client, amount ) {
	new hp = GetClientHealth(client) + amount;
	if( hp > 100 ) hp = 100;
	SetEntityHealth( client, hp );
} 

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 || victim == 0 ) return;
	
	if( GetClientTeam(client) == GetClientTeam(victim) ) return;
	
	decl String:weapon[64];
	GetEventString( event, "weapon", weapon, sizeof weapon );
	
	if( strncmp( weapon, "knife", 5 ) == 0 ) {
		HealPlayer( client, 50 );
		PrintToChat( client, "\x01 \x04+50HP \x01for knifing someone." );
		return;
	}
	
	if( strncmp( weapon, "taser" , 5) == 0 ) {
		HealPlayer( client, 20 );
		PrintToChat( client, "\x01 \x04+20HP \x01for tasing someone." );
		return;
	}
	
	if( GetEventBool( event, "headshot" ) ) {
		HealPlayer( client, 10 );
		PrintToChat( client, "\x01 \x04+10HP \x01for headshotting an enemy." );
		return;
	} else {
		HealPlayer( client, 5 );
		PrintToChat( client, "\x01 \x04+5HP \x01for killing an enemy." );
		return;
	}
}