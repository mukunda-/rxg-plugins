
#include <sourcemod>
#include <sdktools>
 
public Plugin:myinfo =
{
	name = "Bullettrace",
	author = "mukunda",
	description = "Admin command to view client bullet trails",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new admins_viewing_total;

new admins_viewing[64];// number of admins viewing a certain client

new admin_viewing[64][4]; //userid of admins viewing a target
new admin_target[64]; // client index of 
new admin_target_userid[64];

#define MATERIAL "materials/deathshot/deathshot.vmt"
#define TEXTURE "materials/deathshot/deathshot.vtf"

new g_sprite;


enum {
	ADDADMIN_FULL = -1,
	ADDADMIN_EXISTING = -2,
};

public OnPluginStart() {
	LoadTranslations("common.phrases");

	RegAdminCmd( "sm_bt", Command_bt, ADMFLAG_SLAY ); 
	
	HookEvent( "bullet_impact", BulletImpact );
}

public OnMapStart() {
	AddFileToDownloadsTable( MATERIAL );
	AddFileToDownloadsTable( TEXTURE );
	g_sprite = PrecacheModel(MATERIAL);

}

ValidateAdminTarget(client) {
	if( admin_target[client] == 0 ) return;
	new target = admin_target[client];
	if( GetClientOfUserId(target) == admin_target_userid[client] ) return;
	TurnOffBt( client );
}

public OnClientPutInServer( client ) {
	for( new i = 0; i < 4; i++ ) {
		admin_viewing[client][i] = 0;
	}
	admins_viewing[client] = 0;
	admin_target[client] = 0;
}

public OnClientDisconnect(client) {
	TurnOffBt(client);
}

TurnOffBt( client ) {
	if( !admin_target[client] ) return;
	new target = admin_target[client];
	for( new i = 0; i < 4; i++ ) {
		if( admin_viewing[target][i] == client ) {
			admin_viewing[target][i] = 0;
			break;
		}
	}
	admin_target[client] = 0;
	admins_viewing[target]--;
	admins_viewing_total--;
}

TurnOnBt( client, target ){
	if( admin_target[client] ) return; // admin alrady has a target (should assert)

	new result = AddAdminViewing( client, target );
	if( result == ADDADMIN_FULL ) {
		ReplyToCommand( client, "That client has too many admins tracing him." );
		return;
	} else if( result == ADDADMIN_EXISTING ) {
		ReplyToCommand( client, "You are already tracing that client." );
		return;
	}
	admin_target[client] = target;
	admins_viewing[target]++;
	admins_viewing_total++;
	admin_target_userid[client] = GetClientUserId(target);
	admin_viewing[target][result] =client;

	LogAction( client, target, "\"%L\" activated bullet trace on \"%L\"", client, target );
	
}

public Action:Command_bt( client, args ) {
	decl String:arg[64];
	new target= 0 ;
	if( args == 0 ) {
		
	} else {
		GetCmdArg(1,arg,sizeof(arg));
		target = FindTarget( client, arg );
		if( target == -1 ) return Plugin_Handled;
	}

	ValidateAdminTarget(client);
	
	if( target == 0 ) {
		ReplyToCommand( client, "Bullet tracing turned off." );
		TurnOffBt(client);
		return Plugin_Handled;
	}
	if( admin_target[client] ) {
		if(admin_target[client] == target) {
			ReplyToCommand( client, "You are already tracing that client." );
			return Plugin_Handled;
		}
		TurnOffBt(client);
	}
	TurnOnBt( client, target );
	ReplyToCommand( client, "You are now tracing \x01\x0B\x07%N.", target );
	return Plugin_Handled;
}

AddAdminViewing( admin, target ) {
	for( new i = 0; i < 4; i++ ) {
		if( admin_viewing[target][i] == admin ) return ADDADMIN_EXISTING;
	}
	for( new i = 0; i < 4; i++ ) {
		if( admin_viewing[target][i] == 0 ) return i+1;
	}
	return ADDADMIN_FULL;
}

public BulletImpact( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( admins_viewing_total == 0 ) return;
	new userid = GetEventInt( event, "userid" );
	new attacker = GetClientOfUserId( userid );
	if( attacker > 0 && attacker <= MaxClients ) {
		
		if( admins_viewing[attacker] == 0 ) return;

		// build target list
	
		new admins[8];
		new admincount=0;
		for( new i = 0; i < 4; i++ ) {
			new a = admin_viewing[attacker][i];
			if( a == 0 ) continue;
			if( admin_target_userid[a] != userid ) {
				TurnOffBt(a); // admin target was invalidated
			}
			admins[admincount] = a;
			admincount++;
		}
		if(admincount==0)return;
		
		new Float:end[3];
		new Float:start[3];
		end[0] = GetEventFloat( event, "x" );
		end[1] = GetEventFloat( event, "y" );
		end[2] = GetEventFloat( event, "z" );
		GetClientEyePosition( attacker, start );
		
		new color[4];
		color[0] = 128;
		color[1] = 128;
		color[2] = 0;
		color[3] = 255;
		TE_SetupBeamPoints( end,start, g_sprite, 0, 0,0, 10.0, 0.4, 0.4, 2, 0.0, color, 4);
		TE_Send( admins, admincount );
	//	TE_SendToAll();
	//	PrintToChatAll( "%d %d %d", admins[0], admincount, admins_viewing_total);
		return;
	}
//	PrintToChatAll( "%d", admins_viewing_total);

}
