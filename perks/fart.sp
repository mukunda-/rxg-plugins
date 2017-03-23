#include <sourcemod>
#include <sdktools>

#include <donations>

#pragma semicolon 1

// 1.1.0
//   vip menu

public Plugin:myinfo = {
	name = "fart",
	author = "mukunda",
	description = "slashfart",
	version = "1.1.1",
	url = "www.mukunda.com"
};

#define SOUND "*fart/smokenweewalt_fart.mp3"

new roundcounter;

new Float:time_used[MAXPLAYERS+1];

new Handle:sm_fart_cooldown;
new Float:c_fart_cooldown;

new UserMsg:g_FadeUserMsgId;

#define BLIND_RADIUS 80.0

//----------------------------------------------------------------------------------------
public FartCooldownChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	c_fart_cooldown = GetConVarFloat( sm_fart_cooldown );
}

//----------------------------------------------------------------------------------------
public OnPluginStart() {
	sm_fart_cooldown = CreateConVar( "sm_fart_cooldown", "120.0", "Amount of time needed to build flatulence.", FCVAR_PLUGIN );
	HookConVarChange( sm_fart_cooldown, FartCooldownChanged );
	c_fart_cooldown = GetConVarFloat( sm_fart_cooldown );

	g_FadeUserMsgId = GetUserMessageId("Fade");
	RegConsoleCmd( "fart", Command_fart );
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	
	VIP_Register( "Fart", OnVIPMenu );
}

public OnLibraryAdded( const String:name[] ) {
	if( StrEqual(name,"donations") ) 
		VIP_Register( "Fart", OnVIPMenu );
}
public OnPluginEnd() {
	VIP_Unregister();
}

//----------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	roundcounter++;
}

//----------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheSound( SOUND );
	AddFileToDownloadsTable( "sound/fart/smokenweewalt_fart.mp3" );
	
	// preload steam to prevent lag
	int ent = CreateEntityByName( "env_steam" );
	DispatchSpawn(ent);
	if( IsValidEntity(ent) ) {
		AcceptEntityInput( ent, "Kill" );
	}
}

//----------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	time_used[client] = GetGameTime();
}

//----------------------------------------------------------------------------------------
public Action:KillFart( Handle:timer, any:data ) {
	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	if( !client ) { CloseHandle(data); return Plugin_Handled; }
	if( roundcounter != ReadPackCell(data) ) { CloseHandle(data); return Plugin_Handled; }
	
	AcceptEntityInput( ReadPackCell( data ), "Kill" );
	AcceptEntityInput( ReadPackCell( data ), "Kill" );
	CloseHandle(data);
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------
public Action:StopFart( Handle:timer, any:data ) {
	ResetPack(data);
	new client = GetClientOfUserId( ReadPackCell(data) );
	if( !client ) return Plugin_Handled;
	if( roundcounter != ReadPackCell(data) ) return Plugin_Handled;

	AcceptEntityInput( ReadPackCell( data ), "TurnOff" );
	AcceptEntityInput( ReadPackCell( data ), "TurnOff" );

	new Handle:data2 = CloneHandle(data);
	CreateTimer( 5.0, KillFart, data2, TIMER_FLAG_NO_MAPCHANGE );
	
	return Plugin_Handled;
}

BlindPlayers( client ) {
	new Float:pos[3];
	GetClientAbsOrigin( client, pos );
	pos[2] += 32.0;

	new clients[MAXPLAYERS+1];
	new count;


	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		new Float:pos2[3];
		GetClientEyePosition( i, pos2 );
	
		/* compute distance from eyes to anus */
		if( GetVectorDistance( pos, pos2 ) < BLIND_RADIUS ) {
			clients[count++] = i;
		}
	}
	
	new duration2 = 400;
	new holdtime = 0;
	new color[4] = { 0,255,0, 128};
	new flags = 0x04+0x01;
	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, count);
	PbSetInt(message, "duration", duration2);
	PbSetInt(message, "hold_time", holdtime);
	PbSetInt(message, "flags", flags);
	PbSetColor(message, "clr", color);
	EndMessage();
}

SpawnFart( client, &steam1, &steam2 ) {
	if( !IsClientInGame(client) ) return;
	if( GetClientTeam(client) < 2 ) return;
	if( !IsPlayerAlive(client) ) return;

	new Float:vec[3];
	//GetClientEyePosition( client, vec );
	new Float:ang[3];
	//GetClientEyeAngles(client,ang);
	ang[1] += 180.0;
	ang[0] = 90.0;

	decl String:attachment[64];
	if( GetClientTeam( client) == 3 ) { // ct
		Format(attachment, sizeof(attachment),"defusekit" );
		vec[2] -= 8.0;
		ang[0] = 45.0;
	} else if( GetClientTeam(client)==2) { // t
		Format(attachment, sizeof(attachment),"forward" );

		vec[2] = -30.0;
		vec[0] = -10.0;
	//	vec[1] = -2.0;
	}

	new ent = CreateEntityByName( "env_steam" );
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", client );
	SetVariantString( attachment );
	AcceptEntityInput( ent, "SetParentAttachment" );
	TeleportEntity( ent, vec ,ang, NULL_VECTOR);
	DispatchKeyValue( ent, "type", "0" );
	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "SpreadSpeed", "2" );
	DispatchKeyValue( ent, "Speed", "30" );
	DispatchKeyValue( ent, "StartSize", "0.1" );
	DispatchKeyValue( ent, "EndSize", "3" );
	DispatchKeyValue( ent, "Rate", "40" );
	DispatchKeyValue( ent, "rendercolor", "50 255 30 40" );
	DispatchKeyValue( ent, "JetLength", "30" );
	DispatchKeyValue( ent, "rollspeed", "8" );
	DispatchSpawn(ent);
	AcceptEntityInput(ent, "TurnOn");
	steam1 = ent;

	ent = CreateEntityByName( "env_steam" );
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", client );
	SetVariantString( attachment );
	AcceptEntityInput( ent, "SetParentAttachment" );
	TeleportEntity( ent, vec ,ang, NULL_VECTOR);
	DispatchKeyValue( ent, "type", "1" );		// heatwave
//	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "SpreadSpeed", "2" );
	DispatchKeyValue( ent, "Speed", "30" );
	DispatchKeyValue( ent, "StartSize", "3" );
	DispatchKeyValue( ent, "EndSize", "5" );
	DispatchKeyValue( ent, "Rate", "16" );
	DispatchKeyValue( ent, "rendercolor", "255 255 255 255" );
	DispatchKeyValue( ent, "JetLength", "30" );
	DispatchKeyValue( ent, "rollspeed", "8" );
	DispatchSpawn(ent);
	AcceptEntityInput(ent, "TurnOn");
	steam2=ent;
	
	new Handle:data;
	CreateDataTimer(0.25,StopFart,data,TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell( data, GetClientUserId(client) );
	WritePackCell( data, roundcounter );
	WritePackCell( data, steam1 );
	WritePackCell( data, steam2 );

	EmitSoundToAll( SOUND, steam1, _, _, _, 1.0, GetRandomInt(95,110) );

	BlindPlayers( client );
}

public Action:Command_fart( client, args ) {
 	if( !IsPlayerAlive(client) ) return Plugin_Handled;

	new Float:time = GetGameTime() - time_used[client];
	if( time < c_fart_cooldown ) {
		PrintToChat( client, "You don't have enough flatulence built up. (%d%%)", RoundToZero(time / c_fart_cooldown * 100.0) );
		return Plugin_Handled;
	}
		
	if( Donations_GetClientLevel(client) == 0 ) {
		PrintToChat( client, "Only donators can release their flatulence." );
		return Plugin_Handled;
	}
	time_used[client] = GetGameTime();
	
	new a,b;
	SpawnFart(client,a,b);
	
	
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04Only VIPs can expel their flatus." );
	} else if( action == VIP_ACTION_USE ) {
		PrintToChat( client, "\x01 \x04Use !fart or bind \"fart\" in console (type \"bind <key> fart\")" );
	}
}

/*
	new Float:test[3];
	test[0] = 1.0;
	test[2] = 100.0;
	TE_Start( "Sprite Spray" );
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteVector( "m_vecDirection", test );
	TE_WriteNum( "m_nModelIndex", testmodel );
	TE_WriteNum( "m_nSpeed", 10 );
//	TE_WriteFloat( "m_fScale", 10.0 );
	TE_WriteFloat( "m_fNoise", 100.0 );
	TE_WriteNum( "m_nCount", 50 );
//	TE_WriteNum( "m_nBrightness", 100 );
	TE_SendToAll();
	*/

	/*
	new prop = CreateEntityByName( "env_sprite" );
	SetEntityModel( prop, MODEL1 );
	
	SetEntProp( prop, Prop_Data, "m_bWorldSpaceScale", 1 );
	new Float:test[3];
	test[0] = 55.0;
	TeleportEntity( prop, vec , NULL_VECTOR, test );
//	DispatchKeyValue( prop, "framerate", "1.0" );
//	DispatchKeyValue( prop, "frame", "0.1" );
	SetEntPropFloat( prop, Prop_Send, "m_flFrame" , 0.1 );
//	DispatchKeyValue( prop, "spawnflags", "3" );
	DispatchKeyValue( prop, "rendermode", "2" );
	DispatchKeyValue( prop, "rendercolor", "0 128 0" );
	DispatchKeyValue( prop, "renderamt", "255" );

	DispatchSpawn( prop );
	DispatchKeyValue( prop, "scale", "10.0" );
	AcceptEntityInput( prop, "ShowSprite" );


	
//	SetEntityMoveType( prop, MOVETYPE_VPHYSICS );
	PrintToChatAll( "fart - %f", GetEntPropFloat( prop, Prop_Send, "m_flFrame"  ) );
//	SetEntityGravity( prop, -0.5 );
	//SetEntityGravity( client, -0.1 );
*/

/*
	new ent = CreateEntityByName( "env_steam" );
	new Float:ang[3];
	GetClientEyeAngles(client,ang);
	TeleportEntity( ent, vec ,ang, NULL_VECTOR);
//	DispatchKeyValue( ent, "InitialState", "1" );
	DispatchKeyValue( ent, "type", "0" );
	DispatchKeyValue( ent, "spawnflags", "1" );

	DispatchKeyValue( ent, "SpreadSpeed", "5" );
	DispatchKeyValue( ent, "Speed", "62" );
	DispatchKeyValue( ent, "StartSize", "1" );

	DispatchKeyValue( ent, "EndSize", "10" );
	DispatchKeyValue( ent, "Rate", "16" );

	DispatchKeyValue( ent, "rendercolor", "0 255 0 255" );
	DispatchKeyValue( ent, "JetLength", "20" );
//	DispatchKeyValue( ent, "renderamt", "255" );
	DispatchKeyValue( ent, "rollspeed", "8" );

	DispatchSpawn(ent);
	AcceptEntityInput(ent, "TurnOn");
//	ActivateEntity(ent);
*/
