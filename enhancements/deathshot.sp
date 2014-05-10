//
//
//

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <cstrike_weapons>
 
public Plugin:myinfo =
{
	name = "Death Shot",
	author = "mukunda",
	description = "Shows a trace of the bullet that killed you",
	version = "1.0.0",
	url = "www.mukunda.com"
};

#define BEAM_TIME 20.0

new beam_colors[4+4+4] = {128,64,0,255,  128,0,0,255,  0,118,128,255 };
					      //normal       headshot      taser

#define MATERIAL		"materials/deathshot/deathshot.vmt"//deathshot/deathshot.vmt"
#define MATERIALFILE1	"materials/deathshot/deathshot.vmt"
#define MATERIALFILE2	"materials/deathshot/deathshot.vtf"

new g_sprite;

new Float:client_last_bullet[MAXPLAYERS+1][3];
new Float:client_last_bulletfrom[MAXPLAYERS+1][3];

new Handle:sm_deathshot_enabled;

new Handle:cookie_disabled = INVALID_HANDLE;

public OnPluginStart() {
	cookie_disabled = RegClientCookie( "deathshot_disabled", "Disable Deathshot Beams", CookieAccess_Protected );
	SetCookiePrefabMenu( cookie_disabled, CookieMenu_YesNo_Int, "Disable Deathshot Beams" );

	sm_deathshot_enabled = CreateConVar( "sm_deathshot_enabled", "1", "Enable Deathshot Beams", FCVAR_PLUGIN );
 
	
	HookEvent( "player_death", PlayerDeath );
	HookEvent( "bullet_impact", BulletImpact );
}

public OnMapStart() {
	g_sprite = PrecacheModel(MATERIAL);
	AddFileToDownloadsTable(MATERIALFILE1);
	AddFileToDownloadsTable(MATERIALFILE2);
}

bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

public BulletImpact( Handle:event, const String:name[], bool:dontBroadcast ) {
	new attacker = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( attacker > 0 && attacker <= MaxClients ) {
		client_last_bullet[attacker][0] = GetEventFloat( event, "x" );
		client_last_bullet[attacker][1] = GetEventFloat( event, "y" );
		client_last_bullet[attacker][2] = GetEventFloat( event, "z" );
		GetClientEyePosition( attacker, client_last_bulletfrom[attacker] );
		/* TEST
		g_sprite = PrecacheModel(MATERIAL);
		new color[4];
		color[0] = 128;
		color[1] = 0;
		color[2] = 0;
		color[3] = 255;
		TE_SetupBeamPoints(client_last_bullet[attacker]  , client_last_bulletfrom[attacker], g_sprite, 0, 0,0, BEAM_TIME, 0.2, 0.2, 2, 0.0, color, 4);
		//TE_SendToClient(client_victim);
		TE_SendToAll(); // debug purpose*/
	}
}

public PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( GetConVarBool(sm_deathshot_enabled) == false ) return;
	new userid = GetEventInt( event, "userid" );
	new client_victim = GetClientOfUserId(userid);
	new attacker = GetEventInt( event, "attacker" );
	new client_att = GetClientOfUserId(attacker);

	if( IsValidClient(client_att) && IsValidClient(client_victim) ) {
		if( AreClientCookiesCached(client_victim) ) {
			decl String:buffer[4];

			if( GetClientCookie( client_victim, cookie_disabled, buffer, sizeof(buffer) ) ) {
				if( buffer[0] == '1' ) {
					return;
				}
			}
		}

		decl String:weap[24];
		GetEventString( event, "weapon", weap, sizeof(weap) );
		new WeaponType:wtype = GetWeaponType(weap);
		
		new colorbase = 0;
		new Float:amp = 0.0;
		if( (wtype >= WeaponTypePistol && wtype <= WeaponTypeSniper) || wtype == WeaponTypeMachineGun ) {

			if( GetEventBool( event,"headshot" ) ) {
				colorbase = 4;
			}

		} else if( wtype == WeaponTypeTaser ) {
			colorbase = 8;
			//amp = 5.0;
		} else {
			return; // not a hitscan weapon
		}

		

		decl color[4];
		
		for( new i = 0; i < 4; i++ )
			color[i] = beam_colors[i+colorbase];

		
		TE_SetupBeamPoints(client_last_bullet[client_att]  , client_last_bulletfrom[client_att], g_sprite, 0, 0,0, BEAM_TIME, 0.4, 0.4, 2, amp, color, 4);
		//TE_SetupBeamPoints( client_last_bulletfrom[client_att] , client_last_bullet[client_att], g_sprite, 0, 0, 5, BEAM_TIME, 0.3, 0.1, 2, 0.0, color, 0);
		/*
		new toclients[MAXPLAYERS+1];
		new tcwrite = 0;
		for( new i = 1; i <= MaxClients; i++ ) {
			if( IsValidClient(i) ) {
			
				new bool:skip = false;
				
				if( !IsPlayerAlive(i) || client_victim == i && !skip ) {
					toclients[tcwrite] = i;
					tcwrite++;
				
				}
			}
		}*/
		//TE_Send( toclients, tcwrite );
		TE_SendToClient(client_victim);
		//TE_WriteNum( "m_nFlags", FBEAM_SINENOISE);
		//TE_SendToAll(); // debug purpose
	}
}
