
// this plugin is NOT recommended to be used because it may interfere with hit registration.

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <collisionhook>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "nogrenadeblock",
	author = "mukunda",
	description = "mother fucking shitty team crowding around the door and doing nothing and you can't use smoke or fire because of them",
	version = "1.0.0",
	url = "http://www.reflex-gamers.com"
};

new bool:isgrenade[4096];
/*
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	SetEntProp( client, Prop_Send, "m_CollisionGroup", 2 );
}
*/
/*
public Action:CH_ShouldCollide( ent1, ent2, &bool:result ) {

	result = false;
	return Plugin_Handled;
	if( ent1 >= 1 && ent1 <= MaxClients ) {
		if( ent2 > MaxClients && ent2 < 4096 ) {
			if( isgrenade[ent2] ) {	
				result = false;
				return Plugin_Handled;
			}
			
		}
	}
	return Plugin_Continue;
}
*/

public OnPluginStart() {
//	HookEvent( "player_spawn", Event_PlayerSpawn );

	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			SDKHook( i, SDKHook_ShouldCollide, Event_PlayerTouch );
		}
	}
}

public OnClientPutInServer(client) {
	SDKHook( client, SDKHook_ShouldCollide, Event_PlayerTouch );
}

public bool:Event_PlayerTouch(entity, collisiongroup, contentsmask, bool:originalResult) {
//public Action:Event_PlayerTouch( entity, other ) {
	
//	if(entity>20)
//	if( collisiongroup == 0) return originalResult;
//	//PrintToServer( "ptouch, %2d %2d %2d", entity, collisiongroup, contentsmask );
	if( collisiongroup == 13 ) return false;

	return originalResult;
}

/*
public bool:Event_GrenadeTouch(entity, collisiongroup, contentsmask, bool:originalResult) {
	PrintToChatAll( "testes" );
	if( collisiongroup == 0 ) return false;
	return originalResult;
}
*/

/*
public Action:Event_GrenadeStartTouch( entity, other ) {
	PrintToChatAll( "st :%d %d", entity, other );
	return Plugin_Continue;
}
*/	


public OnEntityCreated( entity, const String:classname[] ) {
	
	if( entity <= MaxClients || entity > 4096 ) return;
	new bool:test = false;
	
	if( StrEqual( classname, "hegrenade_projectile" ) ) test = true;
	else if( StrEqual( classname, "smokegrenade_projectile" ) ) test = true;
	else if( StrEqual( classname, "flashbang_projectile" ) ) test = true;
	else if( StrEqual( classname, "molotov_projectile" ) ) test = true;
	else if( StrEqual( classname, "incgrenade_projectile" ) ) test = true;
	else if( StrEqual( classname, "decoy_projectile" ) ) test = true;

	if( !test ) {
		isgrenade[entity] = false;
		return;
	} else {
		isgrenade[entity] = true;
	}

//	PrintToChatAll( "testes1 %s", classname );
	SetEntProp( entity, Prop_Send, "m_CollisionGroup",13); // set non-collidable
	//SetEntProp( entity, Prop_Data, "m_nSolidType", 0 );

//	SDKHook( entity, SDKHook_ShouldCollide, Event_GrenadeTouch );
//	SDKHook( entity, SDKHook_StartTouch, Event_GrenadeStartTouch );
}

