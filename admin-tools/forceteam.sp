// forceteam
//----------------------------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "forceteam",
	author = "REFLEX-GAMERS",
	description = "force player switch team",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegAdminCmd( "sm_forceteam", Command_forceteam, ADMFLAG_KICK );
	RegAdminCmd( "sm_swap", Command_swap, ADMFLAG_KICK );
}

//----------------------------------------------------------------------------------------------------------------------
TranslateClient( client, const String:text[] ) {
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	target_count = ProcessTargetString(
			text,
			client, 
			target_list, 
			MAXPLAYERS, 
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml);

	if( target_count > 1 ) {
		return -1;
	} else if( target_count == 1 ) {
		return target_list[0];

	} else {
		return 0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
bool:PrintTranslateError(client,client1) {
	if( client1 == -1 ) {
		PrintToConsole( client, "sm: ambiguous name" );
		return true;
	} else if( !IsValidClient(client1) ) {
		PrintToConsole( client, "sm: can't find player" );
		return true;
	}
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_forceteam( client, args ) {
	// forceteam <client> <team>
	if( args < 2 ) {
		PrintToConsole( client, "sm_forceteam <player> <team> | 1 = SPEC, 2 = RED/T, 3 = BLU/CT" );
		return Plugin_Handled;
	}
	decl String:target[64];
	GetCmdArg( 2, target, 64 );
	if( StrEqual( target, "ct", false ) ) target = "3";
	else if( StrEqual( target, "t", false ) ) target = "2";
	else if( StrEqual( target, "spec", false ) ) target = "1";
	else if( StrEqual( target, "red", false ) ) target = "2";
	else if( StrEqual( target, "blu", false ) ) target = "3";

	new target_team = StringToInt( target );
	if( target_team < 1 || target_team > 3 ) {
		PrintToConsole( client, "sm: invalid team index" );
		return Plugin_Handled;
	}
	decl String:arg[64];
	GetCmdArg( 1, arg, 64 );
	new client1 = TranslateClient(client,arg);
	if( PrintTranslateError(client, client1) ) return Plugin_Handled;
	
	new team = GetClientTeam(client1);
	if( team == target_team ) {
		PrintToConsole( client, "sm: player is already on that team" );
		return Plugin_Handled;
	}
	PrintToConsole( client, "sm_forceteam: changing player's team!!!" );
	ChangeClientTeam( client1, target_team );
	return Plugin_Handled;
}

//---------------------------------------------------------------------------------------------------------------------- 
public Action:Command_swap( client, args ) {
	// swap <client1> <client2>
	if( args < 2 ) {
		PrintToConsole( client, "sm_swap <player1> <player2>" );
		return Plugin_Handled;
	}

	decl String:arg[64];
	GetCmdArg( 1, arg, 64 );
	new client1 = TranslateClient(client,arg);
	if( PrintTranslateError(client, client1) ) return Plugin_Handled;

	GetCmdArg( 2, arg, 64 );
	new client2 = TranslateClient(client,arg);
	if( PrintTranslateError(client, client2) ) return Plugin_Handled;

	new team1 = GetClientTeam(client1);
	new team2 = GetClientTeam(client2);
	if( team1 == team2 ) {
		PrintToConsole( client, "sm: both players are on the same team..." );
	}
	ChangeClientTeam( client1, team2 );
	ChangeClientTeam( client2, team1 );
	return Plugin_Handled;
}
