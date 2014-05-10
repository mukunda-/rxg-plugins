
// votekick
// 

#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#include <idletracker>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "votekick",
	author = "mukunda",
	description = "votekick module",
	version = "1.0.1",
	url = "www.mukunda.com"
};

new g_AdminCount;
new g_IsAdmin[MAXPLAYERS+1];

new Float:vote_menu_time[MAXPLAYERS+1];// when players accessed the votemenu

new Handle:sm_votekick_percentage;
new Handle:sm_votekick_teamweight;
new Handle:sm_votekick_time;
new Handle:sm_votekick_noadmins;
new Handle:sm_votekick_enable;
new Handle:sm_votekick_minplayers;

new c_votekick_percentage;
new c_votekick_teamweight;
new c_votekick_noadmins;
new c_votekick_enable;
new c_votekick_minplayers;

new Float:client_votes[MAXPLAYERS+1][MAXPLAYERS+1]; // source, target

#define VOTE_EXPIRATION 300.0 // 5 MINUTES

#define GAME_CSGO 1
#define GAME_TF2 2

new Game = 0;

//-------------------------------------------------------------------------------------------------
public CvarChanged ( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	if( convar == sm_votekick_percentage ) {
		c_votekick_percentage = GetConVarInt( convar );
	} else if( convar == sm_votekick_noadmins ) {
		c_votekick_noadmins = GetConVarInt( convar );
	} else if( convar == sm_votekick_enable ) {
		c_votekick_enable = GetConVarInt( convar );
	} else if( convar == sm_votekick_minplayers ) {
		c_votekick_minplayers = GetConVarInt( convar );
	} else if( convar == sm_votekick_teamweight ) {
		c_votekick_teamweight = GetConVarInt( convar );
	}
} 

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations( "common.phrases" );	
	
	sm_votekick_percentage = CreateConVar( "sm_votekick_percentage", "75", "Percent of players (counting the target's team only) required to votekick someone.", FCVAR_PLUGIN );
	HookConVarChange( sm_votekick_percentage, CvarChanged );
	sm_votekick_time = CreateConVar( "sm_votekick_time", "5", "Minutes to ban votekicked player; -1 = no ban, 0 = PERMANENT", FCVAR_PLUGIN );
	sm_votekick_noadmins = CreateConVar( "sm_votekick_noadmins", "1", "Can only votekick when no admins are present", FCVAR_PLUGIN );
	HookConVarChange( sm_votekick_noadmins, CvarChanged );
	sm_votekick_enable = CreateConVar( "sm_votekick_enable", "0", "Enable votekicking", FCVAR_PLUGIN );
	HookConVarChange( sm_votekick_enable, CvarChanged );
	sm_votekick_minplayers = CreateConVar( "sm_votekick_minplayers", "5", "Minimum players required to enable vote kicks", FCVAR_PLUGIN );
	HookConVarChange( sm_votekick_minplayers, CvarChanged );
	sm_votekick_teamweight = CreateConVar( "sm_votekick_teamweight", "50", "Power (percentage) of votes from players not on the target's team", FCVAR_PLUGIN );
	HookConVarChange( sm_votekick_teamweight, CvarChanged );

	c_votekick_percentage = GetConVarInt( sm_votekick_percentage );
	c_votekick_noadmins = GetConVarInt( sm_votekick_noadmins );
	c_votekick_enable = GetConVarInt( sm_votekick_enable );
	c_votekick_minplayers = GetConVarInt( sm_votekick_minplayers );
	c_votekick_teamweight = GetConVarInt( sm_votekick_teamweight );

	decl String:gameName[30];
	GetGameFolderName(gameName, sizeof(gameName));
	
	if( StrEqual(gameName,"csgo",false) ) {
		Game = GAME_CSGO;
	} else if( StrEqual(gameName, "tf", false) ) {
		Game = GAME_TF2;
	} else {
		SetFailState( "GAME NOT SUPPPORTED" );
	}
	
	RefreshAdmins();
	
	RegConsoleCmd( "sm_votekick", Command_votekick );
	
	for( new i = 0; i <= MaxClients; i++ ) {
		for( new j = 0; j <= MaxClients; j++ ) {
			client_votes[i][j] = -VOTE_EXPIRATION;
		}
	}
}

//-------------------------------------------------------------------------------------------------
RefreshAdmins() {
	g_AdminCount = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;

		if( GetUserFlagBits(i) & ADMFLAG_KICK ) {
			g_IsAdmin[i] = true;
			g_AdminCount++;
		} else {
			g_IsAdmin[i] = false;
		}
	}
}

//-------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	// reset votes
	for( new i = 0; i <= MaxClients; i++ ) {
		client_votes[client][i] = -VOTE_EXPIRATION;
		client_votes[i][client] = -VOTE_EXPIRATION;
	}
	vote_menu_time[client] = -9000.0;
}

//-------------------------------------------------------------------------------------------------
public OnClientPostAdminCheck( client ) {

	if( GetUserFlagBits(client) & ADMFLAG_KICK ) {
		g_IsAdmin[client] = true;
		g_AdminCount++;
	} else {
		g_IsAdmin[client] = false;
	}
}

//-------------------------------------------------------------------------------------------------
public OnClientDisconnect_Post( client ) {
	if( g_IsAdmin[client] ) {
		g_AdminCount--;
	}
	g_IsAdmin[client] = false;
	
}

//-------------------------------------------------------------------------------------------------
bool:AreAdminsOnline(){
	if( g_AdminCount == 0 ) return false; // no admins connected

	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !g_IsAdmin[i] ) continue;
		if( GetClientIdleTime(i) < 60.0 ) { // 60 seconds hardcoded :)
			
			// an admin has been active in the last 60 seconds
			return true;
		}
	}

	return false; // all online admins are AFK
}

//-------------------------------------------------------------------------------------------------
public MenuHandler_VoteKick(Handle:menu, MenuAction:action, param1, param2) {
	if( action == MenuAction_End ) {
		CloseHandle( menu );
	} else if( action == MenuAction_Cancel ) {
		return;
	} else if( action == MenuAction_Select ) {
		decl String:info[32];
		new userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] Player no longer available." );
			return;
		}
		
		if( GetUserFlagBits(target) & (ADMFLAG_KICK|ADMFLAG_ROOT) ) {
			PrintToChat( param1, "[SM] Cannot target admins." );
			return;
		}
		
		if( !c_votekick_enable ) {
			PrintToChat( param1, "[SM] Votekick is disabled." );
			return;
		}
		
		if( c_votekick_minplayers > 1 && GetClientCount() < c_votekick_minplayers ) {
			PrintToChat( param1, "[SM] Votekick is disabled until there are at least %d players.", c_votekick_minplayers );
			return;
		}
		
		if( c_votekick_noadmins && AreAdminsOnline() ) {
		
			PrintToChat( param1, "[SM] Cannot vote when admins are online." );
			return;
		}

		if( IsFakeClient(target) ) {
			PrintToChat( param1, "[SM] That is a bot." );
			return;
		}
		
		if( target == param1 ) {
			PrintToChat( param1, "[SM] You can't vote against yourself." );
			return;
		}
		
		new Float:time = GetGameTime();
		
		if( (time-client_votes[param1][target]) < VOTE_EXPIRATION ) {
			PrintToChat( param1, "[SM] You have already voted to kick %N", target );
			return;
		}
		
		PrintToChat( param1, "[SM] You have voted to kick %N", target );
		client_votes[param1][target] = time;
		CheckClientKick( target );
	}
}

#define MVP_OFFSET_FROM_WEAPON_PURCHASES 256
//#define CASHSPENT_OFFSET_FROM_SCORE 20
#define SCORE_OFFSET_FROM_MVP 20

//-------------------------------------------------------------------------------------------------
FillVotekickMenu( client, Handle:menu ) {
	new count = 0;
	new entries[64];
	
	new score_offset = FindSendPropInfo( "CCSPlayer", "m_iWeaponPurchasesThisRound" ) + MVP_OFFSET_FROM_WEAPON_PURCHASES + SCORE_OFFSET_FROM_MVP;
	
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( GetUserFlagBits(i) & (ADMFLAG_KICK|ADMFLAG_ROOT) ) continue; // cannot target admins
		if( IsFakeClient(i) ) continue; // cannot target bots
		if( client == i ) continue; // cannot target self	
		new team =GetClientTeam(i);

		
		new score = team >= 2 ? GetEntData( i, score_offset ) : 0;
		score += (team<<16); // sort by team

		entries[count++] = i | (score<<8);

		
	}
	SortIntegers( entries, count, Sort_Descending );
	for( new i = 0; i < count; i++ ) {
		new target = entries[i] & 255;
		decl String:info[32];
		Format( info, sizeof(info), "%d", GetClientUserId( target ) );
		decl String:title[48];
		decl String:teamstring[8];
		new team =GetClientTeam(target);
		if( team == 1 ) teamstring = "(SPEC)";
		else if( team == 2 ) teamstring = "(T)";
		else if( team == 3 ) teamstring = "(CT)";
		else teamstring = "";
		Format( title, sizeof(title), "%s %N", teamstring, target );
		AddMenuItem( menu, info, title );

	}
	
	return count;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_votekick( client, args ) {
	if( GetGameTime() - vote_menu_time[client] <10.0 ) {
		PrintToChat( client, "[SM] Please wait before accessing the votekick menu again." );
		return Plugin_Handled;
	}
	vote_menu_time[client] = GetGameTime();

	new Handle:menu = CreateMenu( MenuHandler_VoteKick );
	
	SetMenuTitle(menu, "Votekick Player:");
	
	if( !FillVotekickMenu( client, menu ) ) {
		PrintToChat( client, "[SM] There is nobody you can vote kick." );
		CloseHandle(menu);
		return Plugin_Handled;
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
CheckClientKick( target ) {
	new players;
	new votes_team;
	new votes_nonteam;
	new Float:time = GetGameTime();

	new target_team = GetClientTeam(target);

	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		
		players++;
		
		if( target == i ) continue;
		if( (time - client_votes[i][target]) < VOTE_EXPIRATION ) {
			if( GetClientTeam(i) == target_team ) {
				votes_team++;
			} else {
				votes_nonteam++;
			}
		}
	}

	new votes = votes_team + votes_nonteam;
	
	if( (time-client_votes[0][target]) < VOTE_EXPIRATION ) {
		votes_nonteam++; // console has voted...somehow :)
	}
	players = players * c_votekick_percentage / 2;

	if( (votes_team*100 + votes_nonteam*c_votekick_teamweight) >= players && votes >= 3 ) {
		// votekick success bitches
		new bantime = GetConVarInt( sm_votekick_time );
		if( bantime == -1 ) {
			LogMessage( "\"%L\" was votekicked (no ban)",target );
			KickClient( target, "You have been votekicked" );
		} else {
			LogMessage( "\"%L\" was votekicked (%d minute ban)",target, bantime );
			BanClient( target, bantime, BANFLAG_AUTO, "Votekick", "You have been votekicked" );
		}
	} else {
		if( Game == GAME_CSGO ) {
			PrintToChat( target, "[SM] \x01\x0B\x03You have \x01%d\x03 vote%s against you.", votes, votes != 1 ? "s":""  );
		} else {
			PrintToChat( target, "[SM] \x070000AA You have \x01%d\x070000AA vote%s against you.", votes, votes != 1 ? "s":""  );
		}
	}
}
