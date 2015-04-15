#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name        = "flashmod",
	author      = "mukunda",
	description = "Flashbang messages and forwards",
	version     = "1.3.0",
	url         = "www.mukunda.com"
};

//-----------------------------------------------------------------------------
// the flash source for OnPlayerBlind
int   g_flasher = 0;

int   g_teamflashes;
float g_teamflash_total;
int   g_enemyflashes;
float g_enemyflash_total;

// forwards
Handle g_forward;
Handle g_stats_forward;
Handle g_teamflash_forward;

// thresholds for a flash to be considered offensive
#define DURATION_LIMIT 2.0
#define ALPHA_LIMIT    255.0

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	
	g_forward = CreateGlobalForward( "Flashmod_OnPlayerFlashed", 
			ET_Event, Param_Cell, Param_Cell, 
			Param_FloatByRef, Param_FloatByRef );
			
	g_teamflash_forward = CreateGlobalForward( "Flashmod_OnPlayerTeamflash", 
			ET_Ignore, Param_Cell, Param_Cell  );
			
	g_stats_forward = CreateGlobalForward( "Flashmod_FlashbangStats", 
			ET_Ignore, Param_Cell, Param_Cell, 
			Param_Cell, Param_Float, Param_Float );
			
	HookEvent( "player_blind",       Event_PlayerBlind );
	HookEvent( "flashbang_detonate", Event_FlashbangDetonate );
}

//-----------------------------------------------------------------------------
public void Event_PlayerBlind( Handle event, const char[] name, bool db ) {
	
	// the client that was blinded
	int victim = GetClientOfUserId( GetEventInt( event, "userid" ));
	
	bool  alive = IsPlayerAlive( victim );
	
	float alpha, duration;
	
	alpha    = GetEntPropFloat( victim, Prop_Send, "m_flFlashMaxAlpha" );
	duration = GetEntPropFloat( victim, Prop_Send, "m_flFlashDuration" );
	 
	Action result;
	
	// pass to plugins
	Call_StartForward( g_forward );
	
	Call_PushCell    ( g_flasher );
	Call_PushCell    ( victim    );
	Call_PushFloatRef( alpha     );
	Call_PushFloatRef( duration  );
	
	Call_Finish( result );

	if( result != Plugin_Continue ) {
		// flash result was modified by a plugin.
		SetEntPropFloat( victim, Prop_Send, "m_flFlashMaxAlpha", alpha );
		SetEntPropFloat( victim, Prop_Send, "m_flFlashDuration", duration );
	}
	 
	if( alpha >= ALPHA_LIMIT && duration >= DURATION_LIMIT ) {
		
		char flash_duration[8];
		Format( flash_duration, sizeof flash_duration, "%.2f", duration );

		if( g_flasher == victim ) {
			
			// flashed themselves, ignore.
			
		} else if( GetClientTeam(g_flasher) == GetClientTeam(victim) && alive ) {
			
			char flashed_name[32], flasher_name[32];
			
			GetClientName( victim, flashed_name, sizeof flashed_name );
			GetClientName( g_flasher, flasher_name, sizeof flasher_name );

			PrintToChat( victim, "\x01 \x02You were flashed by %s for %s seconds!", 
				flasher_name, flash_duration );
				
			PrintToChat( g_flasher, "\x01 \x02You flashed %s for %s seconds!", 
				flashed_name, flash_duration );
				
			g_teamflashes++;
			g_teamflash_total += duration;
			
		} else if( alive )  {
			// no message
			
			g_enemyflashes++;
			g_enemyflash_total += duration;
		}
	}
 
}

//-----------------------------------------------------------------------------
public void Event_FlashbangDetonate( Handle event, 
									 const char[] name, bool db ) {
	
	// The number of flashed players, and the player that threw the flashbang
	int   client = GetClientOfUserId( GetEventInt( event, "userid" ));
	
	if( g_flasher == 0 ) {
		
		CreateTimer( 0.1, ProcessFlashResultsDelayed );
		
	} else {
		
		// we are processing a new flashbang now, finish up the last one
		
		// ...unless of course one person 
		// threw two flashbangs at the same time??
		ProcessFlashResults();
		g_flasher = 0;
	}
	
	// set flasher and reset stats.
	g_flasher          = client; 
	g_teamflashes      = 0;
	g_teamflash_total  = 0.0;
	g_enemyflashes     = 0;
	g_enemyflash_total = 0.0; 
}

//-----------------------------------------------------------------------------
public Action ProcessFlashResultsDelayed( Handle timer ) {
	ProcessFlashResults();
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
void ProcessFlashResults() {
	
	// pass data to forwards
	
	if( g_teamflashes != 0 ) {
		Call_StartForward( g_teamflash_forward );
		
		Call_PushCell( g_flasher    );
		Call_PushCell( g_teamflashes );
		
 		Call_Finish();
	}
	
	if( g_teamflashes != 0 || g_enemyflashes != 0 ) {

		Call_StartForward( g_stats_forward );
		
		Call_PushCell ( g_flasher          );
		Call_PushCell ( g_enemyflashes     );
		Call_PushCell ( g_teamflashes      );
		Call_PushFloat( g_enemyflash_total );
		Call_PushFloat( g_teamflash_total  );
		
 		Call_Finish();
	}
	
	// reset flasher for next event
	g_flasher = 0;
}
