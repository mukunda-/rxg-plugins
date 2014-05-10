
//----------------------------------------------------------------------------------------------------------------------

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "revive",
	author = "mukunda",
	description = "player reviver",
	version = "1.0.0",
	url = "www.mukunda.com"
};

new mat_halosprite;
new mat_fatlaser;
new UserMsg:g_FadeUserMsgId;

public bool:TraceFilter_All( entity, contentsMask ) {
	
	return false;
}

public OnPluginStart() {
	g_FadeUserMsgId = GetUserMessageId("Fade");
	RegAdminCmd( "sm_revive", Command_revive, ADMFLAG_SLAY, "Revives a person and/or teleports them to your crosshair target." );
	
}

public OnMapStart() { 
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	mat_halosprite = PrecacheModel("materials/sprites/glow01.vmt");

	PrecacheSound( "items/suitchargeok1.wav" );
	
}
//-------------------------------------------------------------------------------------------------
RapeColor( color[4] ) {
	for( new i = 0; i < 3 ;i++ ){
		color[i] = color[i] + (128-color[i])/4;
	}
}

//-------------------------------------------------------------------------------------------------
Revive_Effect( const Float:pos[3] ) {
	EmitAmbientSound( "items/suitchargeok1.wav", pos );

	new color[4] = {229/2,103/2,40/2,255};

	new Float:pos2[3];
	pos2 = pos;

	pos2[2] += 64.0;
	TE_SetupBeamRingPoint(pos2, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 6.0, 0.0, color, 10, 0);
	TE_SendToAll( 0.0 );

	RapeColor(color);
	pos2[2] -= 20.0;
	TE_SetupBeamRingPoint(pos2, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 6.0, 0.0, color, 10, 0);
	TE_SendToAll( 0.1 );

	RapeColor(color);
	pos2[2] -= 20.0;
	TE_SetupBeamRingPoint(pos2, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 6.0, 0.0, color, 10, 0);
	TE_SendToAll( 0.2 );

	RapeColor(color);
	pos2[2] -= 20.0;
	TE_SetupBeamRingPoint(pos2, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 6.0, 0.0, color, 10, 0);
	TE_SendToAll( 0.3 );
}

//-------------------------------------------------------------------------------------------------
public Action:Revive_Timer( Handle:timer, any:data ) {
	ResetPack(data);
	new userid = ReadPackCell(data);
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return Plugin_Handled;
	if( !IsClientInGame(client) ) return Plugin_Handled;
	if( GetClientTeam(client) < 2 ) return Plugin_Handled;

	new Float:end[3];
	for( new i = 0; i < 3; i++ )
		end[i] = ReadPackFloat(data);

	if( !IsPlayerAlive(client) ) {
		CS_RespawnPlayer(client);
		PrintToChat( client, "You have been revived." );
	} else {
	}

	new Float:vel[3] = {0.0,0.0,200.0};
	TeleportEntity( client, end, NULL_VECTOR, vel );
	
	return Plugin_Handled;
}


//-------------------------------------------------------------------------------------------------
public Action:Command_revive( client, args ) {


	if( client == 0 ) return Plugin_Handled;
	if( args < 1 ) {
		ReplyToCommand( client, "[SM] Usage: sm_revive <player>" );
		return Plugin_Handled;
	}

	decl String:name[64];
	GetCmdArg( 1, name, sizeof(name) );
	new target = FindTarget( client, name );
	if( target == -1 ) return Plugin_Handled;

	if( !IsClientInGame(target) ) {
		ReplyToCommand( client, "[SM] sm_revive: Invalid target." );
		return Plugin_Handled;
	}

	if( GetClientTeam(target) < 2 ) {
		ReplyToCommand( client, "[SM] sm_revive: Invalid target." );
		return Plugin_Handled;
	}

	new Float:start[3];
	new Float:angle[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );

	new Float:end[3];
	new bool:valid_location;

	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		new Float:norm[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		new Float:norm_angles[3];
		GetVectorAngles( norm, norm_angles );

		if( FloatAbs( norm_angles[0] - (270) ) < 30 ) {

			valid_location = true;
		}
			
		TR_GetEndPosition( end );
		end[2] += 10.0;
	}

	if( !valid_location ) {
		ReplyToCommand( client, "[SM] sm_revive: Invalid location." );
		return Plugin_Handled;
	}

	Revive_Effect( end );

	new Handle:data;
	CreateDataTimer( 0.5, Revive_Timer, data );
	ResetPack(data);
	WritePackCell( data, GetClientUserId( target ) );
	WritePackFloat( data, end[0] );
	WritePackFloat( data, end[1] );
	WritePackFloat( data, end[2] );
	
	/* Screen Fade Effect */
	new clients[2];
	clients[0] = target;
	new duration2 = 200;
	new holdtime = 100;

	new flags = 0x10|0x02;
	new color[4] = { 255,50,10, 128};
	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration2);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	} else {
		BfWriteShort( message, duration2 );
		BfWriteShort( message, holdtime );
		BfWriteShort( message, flags );
		for( new i = 0; i < 4; i++ )
			BfWriteByte( message, color[i] );
	}
	EndMessage();

	if( !IsPlayerAlive(target) ) {
		ReplyToCommand( client, "[SM] Revived %N.", target );
	} else {
		ReplyToCommand( client, "[SM] Teleported %N.", target );
	}

	return Plugin_Handled;
}
