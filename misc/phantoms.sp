
//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "phantoms",
	author = "mukunda",
	description = "makes players invisible",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
new Handle:phantoms;
new c_phantoms;
new bool:hooked;

new bool:client_hooked[MAXPLAYERS+1];

new g_bits[MAXPLAYERS+1];

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	 
	phantoms = CreateConVar( "phantoms", "0", "Enable phantom mode", FCVAR_PLUGIN );
	HookConVarChange( phantoms, OnConVarChanged );
	c_phantoms = GetConVarInt( phantoms );
	
	RegConsoleCmd( "phantomtest", test );

	if( c_phantoms ) HookEvents();
}


//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:convar, const String:oldValue[], const String:newValue[]) {
	if( convar == phantoms ) {
		c_phantoms = GetConVarBool( phantoms );
		if( c_phantoms ) HookEvents();
		else UnhookEvents();
	}
}


//-------------------------------------------------------------------------------------------------
HookEvents() {
	if( hooked ) return;
	hooked = true;
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookClients();
}

//-------------------------------------------------------------------------------------------------
UnhookEvents() {
	if( !hooked ) return;
	hooked = false;
	UnhookEvent( "player_spawn", Event_PlayerSpawn );
	UnhookClients();
}

//-------------------------------------------------------------------------------------------------
HookClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		HookClient(i);
	}
}

//-------------------------------------------------------------------------------------------------
UnhookClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		UnhookClient(i);
	}
}

//-------------------------------------------------------------------------------------------------
HookClient( client ) {
	if( client_hooked[client] ) return;
	client_hooked[client] = true;
	SDKHook( client, SDKHook_WeaponDropPost, OnWeaponDrop );
	SDKHook( client, SDKHook_WeaponEquipPost, OnWeaponEquip );
	SDKHook( client, SDKHook_PostThinkPost, OnPostThinkPost);
//	SDKHook( client, SDKHook_WeaponCanSwitchToPost, OnWeaponSwitchPost );
}

//-------------------------------------------------------------------------------------------------
UnhookClient( client ) {
	if( !client_hooked[client] ) return;
	client_hooked[client] = false;
	SDKUnhook( client, SDKHook_WeaponDropPost, OnWeaponDrop );
	SDKUnhook( client, SDKHook_WeaponEquipPost, OnWeaponEquip );
	SDKUnhook( client, SDKHook_PostThinkPost, OnPostThinkPost);
//	SDKUnhook( client, SDKHook_WeaponCanSwitchToPost, OnWeaponSwitchPost );
}

//-------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	client_hooked[client] = false;
	if( !c_phantoms ) return;
	HookClient( client );
}

//-------------------------------------------------------------------------------------------------
public OnPostThinkPost(client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", g_bits[client]);
	
	new weapon = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( weapon != -1 ) {
		new enteffects = GetEntProp( weapon, Prop_Send, "m_fEffects");
		enteffects |= 32; // EF_NODRAW
		SetEntProp( weapon, Prop_Send, "m_fEffects", enteffects);  
	}
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	SetEntityRenderMode(client,  RENDER_NORMAL );
//	SetEntityRenderMode(client,  RENDER_ENVIRONMENTAL );	
	
//	new enteffects = GetEntProp( client, Prop_Send, "m_fEffects");
///	enteffects |= 32; // EF_NODRAW
//	SetEntProp( client, Prop_Send, "m_fEffects", enteffects);  
	
	CreateTimer( 0.5, HideWeaponsDelayed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE );
}

//-------------------------------------------------------------------------------------------------
public Action:HideWeaponsDelayed( Handle:timer, any:id ) {
	new client = GetClientOfUserId(id);
	SetEntityRenderMode(client,  RENDER_ENVIRONMENTAL );
	
	if( client == 0 || !IsClientInGame(client) ) return Plugin_Handled;
	
	for( new i = 0; i < 64; i++ ) {
		new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		if( ent != -1 ) {
			new enteffects = GetEntProp( ent, Prop_Send, "m_fEffects");
			enteffects |= 32; // EF_NODRAW
			SetEntProp( ent, Prop_Send, "m_fEffects", enteffects);  
//			SetEntityRenderColor( ent, 0,0,0,0 );
//			AcceptEntityInput( ent, "HideWeapon" );
			
//			decl String:classname[64];
//			GetEntityClassname( ent, classname, sizeof classname );
//			PrintToChatAll( "\x01 \x02DEBUG: %s", classname );
		}
	}
	return Plugin_Handled;
}

public Action:test( client, args ) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof arg );
	new target = FindTarget( client, arg );
	if( target == -1 ) return Plugin_Handled;
	PrintToChatAll( "\x01 \x04 running test function" );
//	HideWeaponsDelayed( INVALID_HANDLE, GetClientUserId(target) );
	Colorize(target);
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnWeaponEquip( client, weapon ) {
	if( weapon <= 0 ) return;
	new enteffects = GetEntProp( weapon, Prop_Send, "m_fEffects");
	enteffects |= 32; // EF_NODRAW
	SetEntProp( weapon, Prop_Send, "m_fEffects", enteffects);  
//	PrintToChatAll( "\x01 \x04OnWeaponEquip %d %d", client, weapon );
//	AcceptEntityInput( weapon, "HideWeapon" );

}

//-------------------------------------------------------------------------------------------------
public OnWeaponDrop( client, weapon ) {
	if( weapon <= 0 ) return;
	new enteffects = GetEntProp( weapon, Prop_Send, "m_fEffects");
	enteffects &= ~32; // EF_NODRAW
	SetEntProp( weapon, Prop_Send, "m_fEffects", enteffects);  

//	PrintToChatAll( "\x01 \x04OnWeaponDrop %d %d", client, weapon );	
}

//-------------------------------------------------------------------------------------------------
Colorize( client )
{
	 // Colorize player and weapons
	 new args[5];
	for( new i = 0; i < 5; i++ ) {
		decl String:a[16];
		GetCmdArg( 2+i,a,sizeof(a) );
		args[i] = StringToInt(a);
	}
	for(new i = 0 ; i < 64; i += 1)
	{
		new weapon = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
		
		if(weapon > -1 )
		{
			decl String:strClassname[250];
			GetEdictClassname(weapon, strClassname, sizeof(strClassname));
			//PrintToChatAll("strClassname is: %s", strClassname);
			 
			
//			SetEntityRenderMode( weapon, RENDER_TRANSCOLOR);
//			SetEntityRenderColor(weapon, 255,0,0,255);
		//	AcceptEntityInput( weapon, "HideWeapon" ); 
		}
	}
	
	
	SetEntityRenderMode(client, args[0] );// RENDER_ENVIRONMENTAL);	
	//SetEntityRenderColor(client, args[1], args[2], args[3], args[4] );// 255,0,0,0);
	/*
	// Colorize any wearable items
	for(new i=MaxClients+1; i <= maxents; i++)
	{
		if(!IsValidEntity(i)) continue;
		
		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));
		
		if(strcmp(netclass, "CTFWearableItem") == 0)
		{
			if(GetEntDataEnt2(i, g_wearableOffset) == client)
			{
				SetEntityRenderMode(i, RENDER_TRANSCOLOR);
				SetEntityRenderColor(i, color[0], color[1], color[2], color[3]);
			}
		}else if(strcmp(netclass, "CTFWearableItemDemoShield") == 0)
		{
			if(GetEntDataEnt2(i, g_shieldOffset) == client)
			{
				SetEntityRenderMode(i, RENDER_TRANSCOLOR);
				SetEntityRenderColor(i, color[0], color[1], color[2], color[3]);
			}
		}
	}
	
	if(g_CurrentMod == Game_TF)
	{
		if(TF2_GetPlayerClass(client) == TFClass_Spy)
		{
			new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
			if(iWeapon && IsValidEntity(iWeapon))
			{
				SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iWeapon, color[0], color[1], color[2], color[3]);
			}
		}
	}*/ 
}
/*
public OnWeaponSwitchPost( client, weapon ) {
	new enteffects = GetEntProp( weapon, Prop_Send, "m_fEffects");
	enteffects |= 32; // EF_NODRAW
	SetEntProp( weapon, Prop_Send, "m_fEffects", enteffects);  
	PrintToChatAll("testes");
}*/
