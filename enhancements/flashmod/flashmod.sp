#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
	name = "flashmod",
	author = "mukunda",
	description = "Flashbang messages and forwards",
	version = "1.1.1",
	url = "www.mukunda.com"
};
 
new bool:player_flashed[MAXPLAYERS+1];
//new Float:player_flash_alpha[MAXPLAYERS+1];
//new Float:player_flash_duration[MAXPLAYERS+1];

new Handle:flashmod_forward;
new Handle:flashmod_stats_forward;
new Handle:flashmod_teamflash_forward;
 


#define DURATION_LIMIT 2.0
#define ALPHA_LIMIT 255.0

public OnPluginStart()
{
	flashmod_forward = CreateGlobalForward("Flashmod_OnPlayerFlashed", ET_Event, Param_Cell, Param_Cell, Param_FloatByRef, Param_FloatByRef );
	flashmod_teamflash_forward = CreateGlobalForward("Flashmod_OnPlayerTeamflash", ET_Ignore, Param_Cell, Param_Cell  );
	flashmod_stats_forward = CreateGlobalForward( "Flashmod_FlashbangStats", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float );
	HookEvent( "player_blind", Event_PlayerBlind );
	HookEvent( "flashbang_detonate", Event_FlashbangDetonate );
}

/* Called when a player is blinded by a flashbang */
public Event_PlayerBlind(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* The client that was blinded */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// flag player
	player_flashed[client] = true;
}

/* Called when a flashbang has detonated (after the players have already been blinded) */
public Event_FlashbangDetonate(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* The number of flashed players, and the player that threw the flashbang */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new teamflash = 0;
	new Float:teamflash_total = 0.0;
	new enemyflash = 0;
	new Float:enemyflash_total = 0.0;
	/* Loop through all flashed players to check if they are on the same team */
	for (new i = 1; i <= MaxClients; i++)
	{
		/* Flash player found */
		if (player_flashed[i] == true)
		{
			new bool:alive = IsPlayerAlive(i);
			new Float:alpha, Float:duration;
			alpha = GetEntPropFloat( i, Prop_Send, "m_flFlashMaxAlpha" );
			duration = GetEntPropFloat( i, Prop_Send, "m_flFlashDuration" );
			if (GetClientTeam(i) == GetClientTeam(client) && alive)  {
				teamflash++;
				teamflash_total += duration;
			} else if( alive ) {
				enemyflash++;
				enemyflash_total += duration;
			}
			
			new Action:result;
			//call forward
			Call_StartForward(flashmod_forward);
			Call_PushCell( client );
			Call_PushCell( i );
 			Call_PushFloatRef( alpha );
			Call_PushFloatRef( duration );
 			Call_Finish(_:result);
		
			if( result != Plugin_Continue ) {
				SetEntPropFloat( i, Prop_Send, "m_flFlashMaxAlpha", alpha );
				SetEntPropFloat( i, Prop_Send, "m_flFlashDuration", duration );
			}
			//SetEntPropFloat( i, Prop_Send, "m_flFlashMaxAlpha",255.0 );
			//SetEntPropFloat( i, Prop_Send, "m_flFlashDuration",1.0 );
			
			if( alpha >= ALPHA_LIMIT && duration >= DURATION_LIMIT ) {

				/* Format the flashed time to be 2 decimal places */
				decl String:sFlash[8];
				Format( sFlash, sizeof(sFlash), "%.2f", duration );

			
				/* Did the player flash an alive teammate? */
				if( i == client ) {
				} else if (GetClientTeam(i) == GetClientTeam(client) && alive)
				{
					decl String:flashedName[32], String:flasherName[32];
					GetClientName(i, flashedName, sizeof(flashedName));
					GetClientName(client, flasherName, sizeof(flasherName));

					PrintToChat(i, "\x01 \x02You were flashed by %s for %s seconds!", flasherName, sFlash);
					PrintToChat(client, "\x01 \x02You flashed %s for %s seconds!", flashedName, sFlash);
					teamflash++;
				}
				else if( alive ) 
				{
					// todo: translations for foreign bitches
					//PrintToChat( i, "\x01 \x02 You were flashed by %N (enemy) for %s seconds!", client, sFlash );
					
					enemyflash++;
				}
			}

			// clear flag
			player_flashed[i] = false;
		}
	}
	if( teamflash ) {
		new Action:result;
		Call_StartForward(flashmod_teamflash_forward);
		Call_PushCell( client );
		Call_PushCell( teamflash );
 		Call_Finish(_:result);
	}
	
	if( teamflash||enemyflash ) {
		new Action:result;
		Call_StartForward(flashmod_stats_forward);
		Call_PushCell( client );
		Call_PushCell( enemyflash );
		Call_PushCell( teamflash );
		Call_PushFloat( enemyflash_total );
		Call_PushFloat( teamflash_total );
 		Call_Finish(_:result);
		
	}
}
