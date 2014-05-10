// name alert

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike_weapons>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "nerf",
	author = "mukunda",
	description = "nerf/god",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

new Handle:sm_shotgun_mod;
new c_sm_shotgun_mod;

new bool:nerflist[MAXPLAYERS+1];
new bool:godlist[MAXPLAYERS+1];

public CVarShotgunMod(Handle:convar, const String:oldValue[], const String:newValue[]) {
	c_sm_shotgun_mod = GetConVarInt( sm_shotgun_mod );
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");
	RegAdminCmd( "sm_nerf", Command_nerf, ADMFLAG_SLAY, "sm_nerf <player> - toggle damage done by this player" );
	RegAdminCmd( "sm_god", Command_god, ADMFLAG_SLAY, "sm_god <player> - toggle damage done to this player" );
	HookExistingClients();

	sm_shotgun_mod = CreateConVar( "sm_shotgun_mod", "1", "Increase shotgun kill velocity" );
	HookConVarChange( sm_shotgun_mod, CVarShotgunMod );
	c_sm_shotgun_mod = GetConVarInt( sm_shotgun_mod );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_nerf( client, args ) {
	new String:targetstring[64];
	GetCmdArg( 1, targetstring, sizeof(targetstring) );
	new target = FindTarget( client, targetstring );
	if( target == -1 ) return Plugin_Handled;
	nerflist[target] = !nerflist[target];
	ReplyToCommand( client, "%N nerf %s.", target, nerflist[target] ? "enabled" : "disabled" );

	LogAction(client, target, "\"%L\" toggled nerf on \"%L\"", client, target );

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_god( client, args ) {
	new String:targetstring[64];
	GetCmdArg( 1, targetstring, sizeof(targetstring) );
	new target = FindTarget( client, targetstring );
	if( target == -1 ) return Plugin_Handled;
	godlist[target] = !godlist[target];
	ReplyToCommand( client, "%N godmode %s.", target, godlist[target] ? "enabled" : "disabled" );
	LogAction(client, target, "\"%L\" toggled god on \"%L\"", client, target );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
	nerflist[client] = false;
	godlist[client] = false;
}

HookExistingClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			SDKHook( i, SDKHook_OnTakeDamage, OnTakeDamage );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
		Float:damageForce[3], Float:damagePosition[3]) {

	if(!(attacker > 0 && attacker <= MaxClients && victim > 0 && victim <= MaxClients)) {
		return Plugin_Continue;
	}
	if( damage <= 0 || weapon <= 0 ) {
		return Plugin_Continue;
	}
	 
	if( nerflist[attacker] || godlist[victim] ) {
		damage = 0.0;
		return Plugin_Changed;
	} else {
		if( c_sm_shotgun_mod ) {
			decl String:weapname[64];
			GetEntityClassname( weapon, weapname, sizeof(weapname) );
			ReplaceString( weapname, 32, "weapon_", "" );
			new WeaponID:id = GetWeaponID( weapname );
			
			if( id == WEAPON_NEGEV || GetWeaponTypeFromID( id ) == WeaponTypeShotgun ) {
				damageForce[0] *= 50.0;
				damageForce[1] *= 50.0;
				damageForce[2] *= 50.0; 
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}
