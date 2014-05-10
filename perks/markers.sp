
#include <sourcemod>
#include <sdktools>
#include <donations>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
//-------------------------------------------------------------------------------------------------
	name = "markers",
	author = "mukunda",
	description = "ground markers",
	version = "1.0.0",
	url="www.mukunda.com"
};

new mat_halosprite;
new mat_fatlaser;

new Float:last_time[MAXPLAYERS+1];

public bool:TraceFilter_All( entity, contentsMask ) {
	
	return false;
}
public OnPluginStart() {
	 
	RegConsoleCmd( "mark", Command_mark );
}

public OnMapStart() {
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	mat_halosprite = PrecacheModel("materials/sprites/glow01.vmt");
}

IntArg( index ) {
	decl String:arg[64];
	GetCmdArg( index, arg, sizeof arg );
	return StringToInt( arg );
}

Clamp( num, min, max ) {
	if( num < min ) return min;
	if( num > max ) return max ;
	return num;
}

public Action:Command_mark( client,args ) {

	if( client == 0 ) return Plugin_Handled;
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	if( Donations_GetClientLevel( client ) == 0 ) return Plugin_Handled;
	if( FloatAbs(GetGameTime() - last_time[client]) < 1.0 ) return Plugin_Handled;
	last_time[client] = GetGameTime();	
	
	
	new color[4] = { 0, 128, 0, 255 };
	if( args >= 1 ) color[0] = Clamp(IntArg(1),0,255);
	if( args >= 2 ) color[1] = Clamp(IntArg(2),0,255);
	if( args >= 3 ) color[2] = Clamp(IntArg(3),0,255);

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
		ReplyToCommand( client, "Mark: Invalid location." );
		return Plugin_Handled;
	}
	
	Effect( end, GetClientTeam(client), color );
	
	return Plugin_Handled;
}

Effect( const Float:pos[3], team, color[4] ) {
	
	
	new clients[MAXPLAYERS];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( GetClientTeam(i) != team && IsPlayerAlive(i) ) continue;
		clients[count++] = i;
	}


	TE_SetupBeamRingPoint( pos, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 1.0, 0.0, color, 10, 0 );
	TE_Send( clients, count, 0.0 );
	TE_SetupBeamRingPoint( pos, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 1.0, 0.0, color, 10, 0 );
	TE_Send( clients, count, 1.0 );
	TE_SetupBeamRingPoint( pos, 10.0, 100.0, mat_fatlaser, mat_halosprite, 0, 15, 0.5, 1.0, 0.0, color, 10, 0 );
	TE_Send( clients, count,3.0 );
}
