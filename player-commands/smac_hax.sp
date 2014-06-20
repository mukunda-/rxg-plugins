


/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac> 

#pragma semicolon 1

/* Plugin Info */
public Plugin:myinfo =
{
	name = "smac_hax",
	author = "mukunda",
	description = "!hax",
	version = "1.0.0",
	url = "www.mukunda.com"
};

 
new client_flagged[MAXPLAYERS+1];
new client_userid[MAXPLAYERS+1];

new Float:last_cmd_use_time;
#define COOLDOWN 60.0

enum {
	FLAG_AIMBOT,
	FLAG_AUTOTRIGGER,
	FLAG_CVAR,
	FLAG_USERCMD,
	FLAG_SPINHACK,
	FLAG_EYEANGLE,
	FLAG_COUNT
};

new String:g_reasons[][] = {
	"Aimbot",
	"Auto-trigger",
	"Convar tampering",
	"Usercmd tampering",
	"Spinhack",
	"Eye-angle tampering"
};

new Handle:g_HaxBanForward;

public OnPluginStart() {
	g_HaxBanForward = CreateGlobalForward("OnHaxBan", ET_Ignore, Param_Cell, Param_Cell );
	
	RegConsoleCmd( "hax", Command_hax );
}

FlagClient( client, flag ) {
	new userid = GetClientUserId(client);
	if( client_userid[client] != userid ) {
		client_userid[client]= userid;
		client_flagged[client] = 0;
	}
	client_flagged[client] |= 1<<flag;
}

public Action:SMAC_OnCheatDetected(client, const String:module[], DetectionType:type, Handle:info ) {
	if( type == Detection_Aimbot ) {
		FlagClient( client, FLAG_AIMBOT );
	} else if( type == Detection_AutoTrigger ) {
		FlagClient( client, FLAG_AUTOTRIGGER );
	} else if( type >= Detection_CvarNotEqual &&
		type <= Detection_CvarNotBound ) {
		
		FlagClient( client, FLAG_CVAR );
	} else if( type >= Detection_UserCmdReuse &&
		type < Detection_UserCmdTamperingButtons ) {
		
		FlagClient( client, FLAG_USERCMD );
	} else if( type == Detection_Spinhack ) {
		FlagClient( client, FLAG_SPINHACK );
	} else if( type == Detection_Eyeangles ) {
		FlagClient( client, FLAG_EYEANGLE  );
	}
}

public Action:Command_hax( client, args ) {
	if( GetGameTime() - last_cmd_use_time < COOLDOWN ) {
		ReplyToCommand( client, "Please wait before banning more hackers." );
		return Plugin_Handled;
	}
	last_cmd_use_time = GetGameTime();
	new bool:found = false;
	for( new target = 1; target <= MaxClients; target++ ) {
		if( !IsClientInGame(target) ) continue;
		
		if( client_flagged[target] && client_userid[target] == GetClientUserId(target) ) {
		
			decl String:reason[256];
			reason[0] = 0;
			new counter = 0;
			for( new f = 0; f < FLAG_COUNT; f++ ) {
				if( client_flagged[target] & (1<<f) ) {
					if( counter != 0 ) {
						StrCat( reason, sizeof reason, ", " );
					}
					StrCat( reason, sizeof reason, g_reasons[f] );
					counter++;
					if( counter >= 4 ) {
						strcopy( reason, sizeof reason, "Multi-hack" );
						break;
					}
				}
			}
			
			Call_StartForward(g_HaxBanForward);
			Call_PushCell( client );
			Call_PushCell( target );

			Call_Finish();
			
			PrintToChatAll( "\x01 >> \x02Banning hacker: %N for \"%s\"", target, reason );
			SMAC_Ban( target, reason );
			found = true;

		}
	}
	
	if( !found ) {
		PrintToChatAll( "\x01 >> \x08No hackers detected." );
	}
	
	return Plugin_Handled;
	
}

