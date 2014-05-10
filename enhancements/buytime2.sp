
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "buytime2",
	author = "mukunda",
	description = "buy anywhere for first x seconds",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new Handle:sm_buytime2;
new Float:c_buytime2;

new rounds;

new bool:hooked_clients[MAXPLAYERS+1];
new Float:round_start_time;

public OnBuyTimeChanged( Handle:convar, const String:oldval[], const String:newval[] ) {
	c_buytime2 = GetConVarFloat( sm_buytime2 );
}

public OnPluginStart() {
	sm_buytime2 = CreateConVar( "sm_buytime2", "10", "Duration of buy-anywhere at round start" );
	HookConVarChange( sm_buytime2, OnBuyTimeChanged );
	c_buytime2 = GetConVarFloat( sm_buytime2 );
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
}

public OnClientConnected( client )  {
	hooked_clients[client] = false;
}

public Event_RoundStart( Handle:event, const String:name[], bool:db ) {
	rounds++;
	round_start_time = GetGameTime();
	//SetConVarInt( mp_buy_anywhere, 1 );
	StartBuyAnywhere();
	CreateTimer( GetConVarFloat( sm_buytime2 ), Timer_DisableBuying, rounds, TIMER_FLAG_NO_MAPCHANGE );
	
}

public Action:Timer_DisableBuying( Handle:timer,any:data ) {
	if( rounds != data ) return Plugin_Handled;
	StopBuyAnywhere();
	return Plugin_Handled;
}

StartBuyAnywhere() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !hooked_clients[i] ) {
			hooked_clients[i] = SDKHookEx( i, SDKHook_PostThink, OnPostThink );
		}
	}
	CreateTimer( GetConVarFloat( sm_buytime2 ), Timer_DisableBuying, rounds, TIMER_FLAG_NO_MAPCHANGE );
}

StopBuyAnywhere() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( hooked_clients[i] ) {
			hooked_clients[i] = false;
			SDKUnhook( i, SDKHook_PostThink, OnPostThink );
		}
	}	
}

public OnPostThink(client) {
	if( GetGameTime() - round_start_time < c_buytime2 ) 
		SetEntProp(client, Prop_Send, "m_bInBuyZone", 1);
}


