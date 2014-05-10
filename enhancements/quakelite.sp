



#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma semicolon 1

//------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "quakelite",
	author = "mukunda",
	description = "gay sounds",
	version = "1.0.0",
	url = "http://www.reflex-gamers.com"
};

//#define KILL_SOUND "*quakelite/boink.mp3"

#define SPLURSH_SOUND "*quakelite/splursh.mp3"

new kill_counters[MAXPLAYERS+1];

new bool:broadcast_active;
//new Handle:broadcast_timer;
new broadcast_sound;

#define BROADCAST_CAST_TIME 1.0

enum {
	ASOUND_NULL,
	ASOUND_DOMINATING,
	ASOUND_RAMPAGE,
	ASOUND_MEGAKILL,
	ASOUND_UNSTOPPABLE,
	ASOUND_ULTRAKILL,
	ASOUND_GODLIKE,
	ASOUND_HUMILIATION
};

new String:sound_paths[][] = {
	"",
	"*quakelite/dominating.mp3",
	"*quakelite/rampage.mp3",
	"*quakelite/megakill.mp3",
	"*quakelite/unstoppable.mp3",
	"*quakelite/ultrakill.mp3",
	"*quakelite/godlike.mp3",
	"*quakelite/humiliation.mp3"
};

new String:downloads[][] = {
	"sound/quakelite/dominating.mp3",
	"sound/quakelite/rampage.mp3",
	"sound/quakelite/megakill.mp3",
	"sound/quakelite/unstoppable.mp3",
	"sound/quakelite/ultrakill.mp3",
	"sound/quakelite/godlike.mp3",
	"sound/quakelite/humiliation.mp3",
//	"sound/quakelite/boink.mp3"
	"sound/quakelite/splursh.mp3"
};

new asound_importance[] = {
	0, //NULL
	1, //DOMINATING
	2, //RAMPAGE
	3, //MEGAKILL
	4, //UNSTOPPABLE
	5, //ULTRAKILL
	6, //GODLIKE
	3, //HUMILIATION

};

//------------------------------------------------------------------------------------------------------------
public bool:IsValidClient(client) {
	if(client <= 0)
		return false;
	if(client > MaxClients)
		return false;

	return IsClientInGame(client);
}

new Handle:cookie_disabled = INVALID_HANDLE;

public OnPluginStart() {
	cookie_disabled = RegClientCookie( "quakesounds2_disabled", "Disable Quake Sounds", CookieAccess_Protected );
	SetCookiePrefabMenu( cookie_disabled, CookieMenu_YesNo_Int, "Disable Quake Sounds" );
	
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "player_death", Event_PlayerDeath );
}

public OnMapStart() {
	for( new i = 0; i < sizeof(downloads); i++ ) {
		AddFileToDownloadsTable(downloads[i]);
	}
	AddToStringTable( FindStringTable( "soundprecache" ), SPLURSH_SOUND );
}

//------------------------------------------------------------------------------------------------------------
PlayKillSound( client ) {
//	ClientCommand( client, "playgamesound %s", KILL_SOUND );
}

//------------------------------------------------------------------------------------------------------------
public Action:BroadcastAnnouncer( Handle:timer ) {
	broadcast_active = false;
	if( broadcast_sound == 0 ) return Plugin_Handled;
	decl String:command[128];
	Format( command, sizeof(command), "playgamesound %s", sound_paths[broadcast_sound] );

	decl String:buffer[4];

	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			if( AreClientCookiesCached( i ) ) {
				if( GetClientCookie( i, cookie_disabled, buffer, sizeof(buffer) ) ) {
					if( buffer[0] == '1' ) { continue; }
				}
			}
				
			ClientCommand( i, command );
		}
	}
	return Plugin_Handled;
}

//------------------------------------------------------------------------------------------------------------
PlayAnnouncer( sound ) {
 
	if( !broadcast_active ) {
		CreateTimer( BROADCAST_CAST_TIME, BroadcastAnnouncer, 0, TIMER_FLAG_NO_MAPCHANGE );
		broadcast_sound = sound;
		broadcast_active = true;
	} else {
		if( asound_importance[sound] <= asound_importance[broadcast_sound] ) return;
		broadcast_sound = sound;
	}
}

//------------------------------------------------------------------------------------------------------------
AddKill( client, const String:weapon[], headshot, victim ) {
	kill_counters[client]++;
	
	PlayKillSound(client);

	new kc = kill_counters[client];

	if( kc >= 4 ) {
		if( kc == 4 ) {
			PlayAnnouncer( ASOUND_DOMINATING );
		} else if( kc == 5 ) {
			PlayAnnouncer( ASOUND_RAMPAGE );			
		} else if( kc == 6 ) {
			PlayAnnouncer( ASOUND_MEGAKILL );
		} else if( kc == 7 ) {
			PlayAnnouncer( ASOUND_UNSTOPPABLE );
		} else if( kc == 8 ) {
			PlayAnnouncer( ASOUND_ULTRAKILL );
		} else if( kc >= 9 ) {
			PlayAnnouncer( ASOUND_GODLIKE );
		}
	}
	if( StrEqual( weapon, "knife" ) || StrEqual( weapon, "taser" ) ) {
		PlayAnnouncer( ASOUND_HUMILIATION );
	}
	
	if( StrEqual( weapon, "deagle" ) ) {
		if( headshot ) {
			EmitSoundToAll( SPLURSH_SOUND, victim );
		}
	}
}

//------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		kill_counters[i] = 0;
	}
}

//------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new attacker = GetClientOfUserId(GetEventInt( event, "attacker" ));
	new victim = GetClientOfUserId(GetEventInt( event, "userid" ));
	if( attacker == 0 || victim == 0 ) return;
	if( attacker == victim ) return;
//bypass	if( GetClientTeam(attacker) == GetClientTeam(victim) ) return; // teamkill

	decl String:weapon[64];
	weapon[0] = 0;
	new bool:headshot = GetEventBool( event, "headshot" );
	GetEventString( event, "weapon", weapon, sizeof(weapon) );
	AddKill( attacker, weapon, headshot, victim );

}
