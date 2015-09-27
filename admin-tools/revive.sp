
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

//----------------------------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Revive",
	author = "mukunda",
	description = "Revive/Teleport players",
	version = "1.0.1",
	url = "www.mukunda.com"
};

int mat_halosprite;
int mat_fatlaser;
UserMsg g_FadeUserMsgId;

//-------------------------------------------------------------------------------------------------
public bool TraceFilter_All( int entity, int contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
public void OnPluginStart() {
	
	LoadTranslations( "common.phrases" );
	
	g_FadeUserMsgId = GetUserMessageId("Fade");
	RegAdminCmd( "sm_revive", Command_revive, ADMFLAG_SLAY, "Revives a person and/or teleports them to your crosshair target." );
}

//-------------------------------------------------------------------------------------------------
public void OnMapStart() { 
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	mat_halosprite = PrecacheModel("materials/sprites/glow01.vmt");

	PrecacheSound( "items/suitchargeok1.wav" );
	
}

//-------------------------------------------------------------------------------------------------
void RapeColor( color[4] ) {
	for( int i = 0; i < 3 ;i++ ){
		color[i] = color[i] + (128-color[i])/4;
	}
}

//-------------------------------------------------------------------------------------------------
void Revive_Effect( const float[3] pos ) {
	EmitAmbientSound( "items/suitchargeok1.wav", pos );

	int color[4] = {229/2,103/2,40/2,255};

	float pos2[3];
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
public Action Revive_Timer( Handle timer, any data ) {
	ResetPack(data);
	int userid = ReadPackCell(data);
	int client = GetClientOfUserId( userid );
	if( client == 0 ) return Plugin_Handled;
	if( !IsClientInGame(client) ) return Plugin_Handled;
	if( GetClientTeam(client) < 2 ) return Plugin_Handled;

	float end[3];
	for( int i = 0; i < 3; i++ )
		end[i] = ReadPackFloat(data);

	if( !IsPlayerAlive(client) ) {
		CS_RespawnPlayer(client);
		PrintToChat( client, "You have been revived." );
	} else {
	}

	float vel[3] = {0.0,0.0,200.0};
	TeleportEntity( client, end, NULL_VECTOR, vel );
	
	return Plugin_Handled;
}


//-------------------------------------------------------------------------------------------------
public Action Command_revive( int client, int args ) {


	if( client == 0 ) return Plugin_Handled;
	if( args < 1 ) {
		ReplyToCommand( client, "[SM] Usage: sm_revive <player>" );
		return Plugin_Handled;
	}

	char name[64];
	GetCmdArg( 1, name, sizeof(name) );
	int target = FindTarget( client, name );
	if( target == -1 ) return Plugin_Handled;

	if( !IsClientInGame(target) ) {
		ReplyToCommand( client, "[SM] sm_revive: Invalid target." );
		return Plugin_Handled;
	}

	if( GetClientTeam(target) < 2 ) {
		ReplyToCommand( client, "[SM] sm_revive: Invalid target." );
		return Plugin_Handled;
	}

	float start[3];
	float angle[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );

	float end[3];
	bool valid_location;

	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		float norm[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		float norm_angles[3];
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

	Handle data;
	CreateDataTimer( 0.5, Revive_Timer, data );
	ResetPack(data);
	WritePackCell( data, GetClientUserId( target ) );
	WritePackFloat( data, end[0] );
	WritePackFloat( data, end[1] );
	WritePackFloat( data, end[2] );
	
	/* Screen Fade Effect */
	int clients[2];
	clients[0] = target;
	int duration2 = 200;
	int holdtime = 100;

	int flags = 0x10|0x02;
	int color[4] = { 255,50,10, 128};
	Handle message = StartMessageEx(g_FadeUserMsgId, clients, 1);
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
		for( int i = 0; i < 4; i++ )
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
