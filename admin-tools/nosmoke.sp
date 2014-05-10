
#include <sourcemod>
#include <restrict>
#include <cstrike_weapons>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "nosmoke",
	author = "mukunda",
	description = "ban smoke from players",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new bool:nosmoke[MAXPLAYERS+1];

public OnPluginStart() {
	LoadTranslations( "common.phrases" );
	RegAdminCmd( "sm_nosmoke", Command_nosmoke, ADMFLAG_KICK, "Disallow a player from using smoke" );
}

public OnClientConnected(client) {
	nosmoke[client] = false;
}

public Action:Command_nosmoke( client, args ) {
	if( args < 1 ) {
		ReplyToCommand( client, "Usage: sm_nosmoke <player>" );
		return Plugin_Handled;
	}
	
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof arg );
	
	new target = FindTarget( client, arg );
	if( target == -1 ) return Plugin_Handled;

	nosmoke[target] = !nosmoke[target];
	ReplyToCommand( client, "%s smoke for %N.", nosmoke[target]? "Disabled":"Enabled", target );
	return Plugin_Handled;
}

public Action:Restrict_OnCanBuyWeapon(client, team, WeaponID:id, &CanBuyResult:result) {
	if( !nosmoke[client] ) return Plugin_Continue;
	if( id == WEAPON_SMOKEGRENADE ) {
		result = CanBuy_BlockDontDisplay;
		PrintToChat( client, "\x01 \x04You are not allowed to buy smoke." );
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action:Restrict_OnCanPickupWeapon(client, team, WeaponID:id, &bool:result) {
	if( !nosmoke[client] ) return Plugin_Continue;
	if( id == WEAPON_SMOKEGRENADE ) {	
		result = false;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
