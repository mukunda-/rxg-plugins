#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>

#pragma semicolon 1;
#pragma newdecls required;

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Give Money",
	author = "WhiteThunder",
	description = "",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	LoadTranslations("common.phrases");
	
	RegAdminCmd( "sm_givemoney", Command_GiveMoney, ADMFLAG_RCON );
}

//-----------------------------------------------------------------------------
public Action Command_GiveMoney( int client, int args ) {
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	int amount;
	
	if( args < 2 ) {
		ReplyToCommand( client, "Usage: sm_givemoney <target> <amount>" );
		return Plugin_Handled;
	}
	
	char targets_arg[32];
	GetCmdArg( 1, targets_arg, sizeof targets_arg );
	
	target_count = ProcessTargetString(
		targets_arg,
		client,
		target_list,
		MAXPLAYERS,
		COMMAND_FILTER_CONNECTED,
		target_name,
		sizeof(target_name),
		tn_is_ml
	);
	
	if( target_count < 1 ) {
		ReplyToCommand( client, "[SM] No matching client found" );
		return Plugin_Handled;
	}
	
	char amount_arg[32];
	GetCmdArg( 2, amount_arg, sizeof amount_arg );
	amount = StringToInt(amount_arg);
	
	for( int i = 0; i < target_count; i++ ) {
		int target = target_list[i];
		
		if( !IsClientInGame(target) || IsFakeClient(target) ) {
			continue;
		}
		
		int current = GetEntProp( target, Prop_Send, "m_iAccount" );
		int new_amount = intmax( 0, current + amount );
		int actual_given = new_amount - current;
		SetEntProp( target, Prop_Send, "m_iAccount", new_amount );
		
		if( actual_given > 0 ) {
			PrintToChat( target, "[SM] Admin deposited \x05$%i\x01.", actual_given );
		} else if( actual_given < 0 ) {
			PrintToChat( target, "[SM] Admin withdrew \x05$%i\x01.", -actual_given );
		}
	}
	
	return Plugin_Handled;
}
