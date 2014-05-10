// spawn doors in cs_office

// because doors are awesome

//-------------------------------------------------------------------------------------------------

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "windowhack",
	author = "mukunda",
	description = "Windows break instantly",
	version = "1.0.0",
	url = "http://www.reflex-gamers.com"
};

new Handle:sm_windowhack = INVALID_HANDLE;
 
//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	sm_windowhack = CreateConVar( "sm_windowhack", "0", "1 = make windows nongay", FCVAR_PLUGIN );
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );

}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {

}

ReplaceWindow( ent ) {

	new ent2 = CreateEntityByName( "func_breakable" );
	DispatchKeyValue( ent2, "propdata", "Glass.Window" );
	DispatchKeyValue( ent2, "material", "Glass" );
//	DispatchKeyValue( ent2, "explosion", "1" ); //relative to attack
	DispatchSpawn( ent2 );

//	new Float:pos[3];
//	GetEntPropVector( ent, Prop_Send, "m_vecOrigin", pos );
//	TeleportEntity( ent2, pos, NULL_VECTOR, NULL_VECTOR );
	SetEntProp( ent2, Prop_Data, "m_iHammerID", GetEntProp( ent, Prop_Data, "m_iHammerID" ) );
	AcceptEntityInput( ent, "kill" );


//	PrintToServer( "debug %f %f %f", pos[0], pos[1], pos[2] );
/*
	new String:test[64];
	GetEntPropString( ent, Prop_Data, "m_iszBasePropData", test, sizeof( test ) );
	PrintToServer( "debug1: %s", test );
	PrintToServer( "debug2: %d", GetEntProp( ent, Prop_Data, "m_iHammerID" ) );
//	PrintToServer( "debug3: %d", GetEntProp( ent, Prop_Data, ) );
//	PrintToServer( "debug4: %d", GetEntProp( ent, Prop_Data, ) );
	DispatchKeyValue( ent, "propdata", "Pottery.Huge" );
*/
}

public Action:DelayExec( Handle:timer ) {
	
	new wh = GetConVarInt( sm_windowhack );
	if( wh == 1 ) {
		new ent = -1;
		while( (ent = FindEntityByClassname( ent, "func_breakable_surf" )) != -1 ) {
			
			SetEntProp( ent, Prop_Data, "m_nFragility", 1000 );
		}
	} else if( wh == 2 ) {

		new ent = -1;
		while( (ent = FindEntityByClassname( ent, "func_breakable_surf" )) != -1 ) {
			
			ReplaceWindow( ent );

		}
	}
	
	
	return Plugin_Handled;
}

//------------------------------------------------------------------------------------------------- 
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {

	CreateTimer( 1.0, DelayExec );
}

//-------------------------------------------------------------------------------------------------
