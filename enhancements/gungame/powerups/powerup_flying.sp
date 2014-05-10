#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <powerups>
#include <vphysics>

#pragma semicolon 1

#define REGISTER PWR_Register( "Flying" )

#define PICKUPMODEL "models/rxg/gg/rocket.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define SOUND_START "*rxg/gg/jetboots2.mp3"
#define SOUND_ACTIVE "*rxg/gg/rocket.mp3"

//
//
//steamtest 1 0 12 50 3 15 32 "200 200 200" 255 30 0; steamtest 1 1 20 80 5 15 25 "200 200 200" 255 38 0

//lighttest 30 5 "255 100 50"

//1.1
//  changed way player lifts off of ground (SAFER)

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Flying Powerup",
    author      = "mukunda",
    description = "for fat people",
    version     = "1.1.0",
    url         = "www.mukunda.com"
};

//new flare1;

#define STATUSCOL "ffe00f"
#define DURATION 30.0

enum {
	D_START,
	D_CARPET,
	D_LIGHTS,
	D_LIGHTS2,
	D_SMOKES,
	D_SMOKES2,
	D_HEATS,
	D_HEATS2,
	
	D_NEXTSOUND,
	D_NEXTSOUND_INDEX,
	D_TOTAL
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	if( LibraryExists( "powerups" ) ) {
		REGISTER;
	}
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "powerups" ) ) {
		REGISTER;
	}
}

public OnMapStart() {
	PrecacheModel( PICKUPMODEL );
	PrecacheModel( FLARE1 );
	
	AddFileToDownloadsTable( "models/rxg/gg/rocket.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/rocket.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/rocket.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/rocket.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/rocket.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	
	AddFileToDownloadsTable( "sound/rxg/gg/jetboots2.mp3" );
	AddFileToDownloadsTable( "sound/rxg/gg/rocket.mp3" );
	PrecacheSound( SOUND_START );
	PrecacheSound( SOUND_ACTIVE );
}

//-------------------------------------------------------------------------------------------------
public PC_Info( &Float:duration, &Float:fade, &type ) {
	duration = DURATION;
	fade = 1.0;
	type = POWERUP_EFFECT;
}

//-------------------------------------------------------------------------------------------------
public PC_Model( String:model[], maxlen, color[4] ) {
	strcopy( model, maxlen, PICKUPMODEL );
	color[0] = 255;
	color[1] = 240;
	color[2] = 11;
	color[3] = 255;
}

GearUpFoot( client, Handle:data, index ) {
	
	
	//steamtest 1 0 12 50 3 15 32 "200 200 200" 255 30 0; steamtest 1 1 20 80 5 15 25 "200 200 200" 255 38 0

//lighttest 30 5 "255 100 50"
//	updown,fwd,leftright	
	new Float:pos[3] = {2.0,-6.5,0.0};
	new Float:angle[3] = {0.0,0.0,0.0};
	new ent;

	ent = CreateEntityByName( "env_steam" );
	DispatchKeyValue( ent, "spawnflags", "0" );
	DispatchKeyValue( ent, "type", "0" );
	DispatchKeyValue( ent, "SpreadSpeed", "12" );
	DispatchKeyValue( ent, "Speed", "40" );
	DispatchKeyValue( ent, "StartSize", "3" );
	DispatchKeyValue( ent, "EndSize",  "18" );
	DispatchKeyValue( ent, "Rate", "32" );
	DispatchKeyValue( ent, "rendercolor", "255 255 255" );
	DispatchKeyValue( ent, "renderamt", "255" );
	DispatchKeyValue( ent, "JetLength", "30" );
	DispatchKeyValue( ent, "rollspeed", "5" );
	DispatchSpawn(ent);
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", client );
	SetVariantString( index?"lfoot":"rfoot" );
	AcceptEntityInput( ent, "SetParentAttachment" );	
	TeleportEntity(ent, pos, angle,NULL_VECTOR );
	SetArrayCell( data, D_SMOKES+index, EntIndexToEntRef( ent ) );
	AcceptEntityInput( ent, "turnon" );
	
	//steamtest 1 1 20 80 5 15 25 "200 200 200" 255 38 0
	ent = CreateEntityByName( "env_steam" );
	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "type", "1" );
	DispatchKeyValue( ent, "SpreadSpeed", "20" );
	DispatchKeyValue( ent, "Speed", "80" );
	DispatchKeyValue( ent, "StartSize", "5" );
	DispatchKeyValue( ent, "EndSize",  "25" );
	DispatchKeyValue( ent, "Rate", "25" );
	DispatchKeyValue( ent, "rendercolor", "200 200 200" );
	DispatchKeyValue( ent, "renderamt", "255" );
	DispatchKeyValue( ent, "JetLength", "38" );
	DispatchKeyValue( ent, "rollspeed", "5" );
	DispatchSpawn(ent);
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", client );
	SetVariantString( index?"lfoot":"rfoot" );
	AcceptEntityInput( ent, "SetParentAttachment" );
	TeleportEntity(ent, pos, angle,NULL_VECTOR );
	SetArrayCell( data, D_HEATS+index, EntIndexToEntRef( ent ) );
	AcceptEntityInput( ent, "turnon" );
	
	ent = CreateEntityByName( "point_spotlight" );
	DispatchKeyValue( ent, "spawnflags", "2" );
	DispatchKeyValue( ent, "spotlightlength", "20" );
	DispatchKeyValue( ent, "spotlightwidth", "10" );
	DispatchKeyValue( ent, "rendercolor", "255 100 50" );	
	DispatchSpawn(ent);
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", client );
	SetVariantString( index?"lfoot":"rfoot" );
	AcceptEntityInput( ent, "SetParentAttachment" );	
	TeleportEntity(ent, pos, angle,NULL_VECTOR );
	AcceptEntityInput(ent,"LightOn" );
	SetArrayCell( data, D_LIGHTS+index, EntIndexToEntRef( ent ) );
	
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	
	SetEntityHealth( client, 100 );
	SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
	
	SetArrayCell( data, D_START, GetGameTime() );
	
	GearUpFoot( client, data, 0 );
	GearUpFoot( client, data, 1 );

	// play sounds
	
	
	
	
	
	EmitSoundToAll( SOUND_START, client, _, SNDLEVEL_GUNFIRE  );
	
	SetArrayCell( data, D_NEXTSOUND, 0.7 );
	SetArrayCell( data, D_NEXTSOUND_INDEX, 0  );
	return data;
}

public bool:TraceFilter_All( ent, contentsmask ) {
	return false;
}

Float:DistanceToGround2( client ) {
	
	new Float:start[3];
	GetClientAbsOrigin( client, start );
	new Float:end[3];
	for( new i = 0; i < 3; i++ ) {
		end[i] = start[i];
	}
	end[2] -= 250.0;
	
	TR_TraceRayFilter( start, end, CONTENTS_SOLID, RayType_EndPoint, TraceFilter_All );
	if( TR_DidHit() ) {
		TR_GetEndPosition( end );
		return GetVectorDistance( start, end  );
	} 
	
	return 250.0 ;
	
}
/*
AddPlayerVelocity( client, const Float:vec[3] ) {
	new Float:vec2[3];
	vec2[0] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]" );
	vec2[1] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]" );
	vec2[2] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[2]" );
	//PrintToConsole( client, "TESTVEL : %f %f %f", vec2[0], vec2[1], vec2[2] );
	for( new i = 0; i < 3; i++ ) {
		vec2[i] += vec[i];
	}
	TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vec2 );
}*/


StopThingy( const Float:dir[3], Float:playervel[3], Float:scale ) {

	new Float:vec[3];
	for( new i = 0; i < 3; i++ ) vec[i] = dir[i];
	new Float:dot = GetVectorDotProduct( vec, playervel );
	ScaleVector( vec, dot * scale );
	SubtractVectors( playervel, vec, playervel );
	
	/*
	new Float:vec[3];
	for( new i = 0; i < 2; i++ ) {
		vec[i] = dir[i] * playervel[i];
	}
	new Float:length = SquareRoot(GetVectorDotProduct( vec,vec ));
	for( new i = 0; i < 2; i++ ) {
		vec[i] = dir[i];
	}
	ScaleVector( vec, length * scale );
	new Float:dot = GetVectorDotProduct( dir, playervel );
	if( dot > 0.0 ) {
		SubtractVectors( playervel, vec, playervel );
	} else {
		AddVectors( playervel, vec, playervel );
	}*/
}

public PC_Update( client, Handle:data ) {
	new Float:time = GetGameTime() - Float:GetArrayCell( data, D_START );
	SetEntityFlags( client, (GetEntityFlags(client)|FL_ATCONTROLS) );// & (~FL_ONGROUND) );
	SetEntityMoveType( client, MOVETYPE_FLY );//GRAVITY );
	new buttons = GetClientButtons(client);
	
	if( time >= Float:GetArrayCell( data, D_NEXTSOUND ) ) {
		SetArrayCell( data, D_NEXTSOUND, time + 1.5 );
		new index = GetArrayCell( data, D_NEXTSOUND_INDEX );
		SetArrayCell( data, D_NEXTSOUND_INDEX, 1-index );
		EmitSoundToAll( SOUND_ACTIVE, GetArrayCell( data,  D_SMOKES+index ), _, SNDLEVEL_GUNFIRE );
	}
	
	PWR_ShowStatusBoxSeconds( client, STATUSCOL, "JETBOOTS", DURATION-time, 1.0-time/DURATION );
	
	new Float:playervel[3];
	playervel[0] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]" );
	playervel[1] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]" );
	playervel[2] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[2]" );
	
	if( !(buttons & IN_SPEED) ) {
		playervel[2] -= 10.0;
	}
	
	new Float:dist = DistanceToGround2( client );
	if( dist < 100.0 ) {
	
		if( dist < 10.0 ) {
		
			new Float:vec[3];
			GetClientAbsOrigin(client,vec);
			vec[2] += 10.0;
			TeleportEntity(client,vec,NULL_VECTOR,NULL_VECTOR );
			
			//playervel[2] += 200.0;
		}
		
		new Float:vel[3] = {0.0,0.0,0.0};
		vel[2] = Lerpfcl( 1.0,0.0,(dist/100.0) );
	//	vel[2] = vel[2] * vel[2];
		vel[2] *=20.0;
		
//		new Float:avel[3];
		AddVectors( playervel, vel, playervel );
	//	AddPlayerVelocity( client, vel );
	}
	
	if( buttons & IN_JUMP ) {
		new Float:vel[3] = {0.0,0.0,20.0};
		AddVectors( playervel, vel, playervel );
	}
	
	new Float:angles[3];
	GetClientEyeAngles( client, angles );
	angles[0] = 0.0;
	new Float:fwd[3];
	new Float:right[3];
	
	GetAngleVectors( angles, fwd, right, NULL_VECTOR );
	
	new Float:dot1 = GetVectorDotProduct( fwd,playervel );
	if( buttons & IN_FORWARD && !(buttons & IN_BACK)  ) {
		if( dot1 < 0.0 ) {
			StopThingy( fwd, playervel, 0.1 );
		}
		ScaleVector( fwd, 25.0 );
		AddVectors( playervel, fwd, playervel );
	} else if( buttons & IN_BACK && !(buttons & IN_FORWARD)  ) {
		if( dot1 > 0.0 ) {
			StopThingy( fwd, playervel, 0.1 );
		}
		ScaleVector( fwd, 25.0 );
		SubtractVectors( playervel, fwd, playervel );
	} else {
//		new Float:vec[3];
//		for( new i = 0; i < 2; i++ ) {
//			vec[i] = fwd[i] * playervel[i];
//		}
//		new Float:length = SquareRoot(GetVectorDotProduct( vec,vec )) * 0.1;
		
		StopThingy( fwd, playervel, 0.1 );
	}
	
	dot1 = GetVectorDotProduct( right,playervel );
	if( buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT)  ) {
		if( dot1 < 0.0 ) {
			StopThingy( right, playervel, 0.1 );
		}
		ScaleVector( right, 25.0 );
		AddVectors( playervel, right, playervel );
	} else if( buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT)   ) {
		if( dot1 > 0.0 ) {
			StopThingy( right, playervel, 0.1 );
		}
		ScaleVector( right, 25.0 );
		SubtractVectors( playervel, right, playervel );
	} else {
//		new Float:vec[3];
//		for( new i = 0; i < 2; i++ ) {
//			vec[i] = right[i] * playervel[i];
//		}
//		new Float:length = SquareRoot(GetVectorDotProduct( vec,vec )) * 0.1;
		
		
		StopThingy( right, playervel, 0.1 );
		
		//new Float:dot = GetVectorDotProduct( right, playervel );
		//ScaleVector( right, dot * 0.1 );
		//SubtractVectors( playervel, right, playervel );
	}
	
	ScaleVector( playervel, 0.98 );
	
	new Float:jetlength = 20.0;
	
	jetlength = Lerpfcl( jetlength, jetlength * 1.5, playervel[2]/ 300.0);
	//jetlength = jetlength + Sine(GetGameTime()*20.0)*5;
	
	
	
	{
		decl String:length[64];
		FormatEx(length, sizeof length, "%d", RoundToNearest( jetlength ) );
		for( new i = 0; i < 2; i++ ) DispatchKeyValue( GetArrayCell( data, D_LIGHTS+i), "spotlightlength", length );

	}
	
//	PrintToConsole( client, "TESTVEL : %f %f %f", playervel[0], playervel[1], playervel[2] );
	TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, playervel );
}


public PC_Stop( client, Handle:data ) {
	SetEntityFlags( client, GetEntityFlags(client)& ~FL_ATCONTROLS );
	SetEntityMoveType( client, MOVETYPE_WALK );//GRAVITY );
	
	PWR_ShowStatusBoxExpired( client, STATUSCOL, "JETBOOTS"   );

}

public PC_Fading( client, Handle:data ) {
	
}

public PC_End( client, Handle:data ) {
	SetEntityFlags( client, GetEntityFlags(client)& ~FL_ATCONTROLS );
	SetEntityMoveType( client, MOVETYPE_WALK );//GRAVITY );
	
	
	for( new i = 0; i < 6; i++ )
		AcceptEntityInput( GetArrayCell( data, D_LIGHTS+i ), "kill" );
		
	new ent = -1;
	while( (ent = FindEntityByClassname(ent, "spotlight_end" )) != -1 ) {
		AcceptEntityInput(ent,"kill" );
	}
}


//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {
	new Handle:data = CreateArray(1,1);
	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetArrayCell( data, 0,  sprite);
	SetEntityRenderColor( sprite, 255, 240,10 );
	
	return data;
}
