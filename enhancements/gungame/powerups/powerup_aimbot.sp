

#include <sourcemod>
#include <sdktools>
#include <powerups>

#pragma semicolon 1

#define REGISTER PWR_Register( "Aimbot" )

#define PICKUPMODEL "models/rxg/gg/xhair.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define SOUND_START "*rxg/gg/powerup.mp3"

#define XSPRITE_MODEL "materials/rxg/gg/lelhair.vmt"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Aimbot Powerup",
    author      = "mukunda",
    description = "smac ban inc",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

#define STATUSCOL  "22FFFF"
#define DURATION 20.0
#define MOUSE1HOLDUNLOCKTIME 0.45

#define LOCK_MAX_ANGLE 20.0 // how many degrees can the user be aiming off when locking on targets
#define ATTACKERLOCK 0.4

enum {
	D_START,
	D_TARGET,
	D_ATTACKER,
	D_ATTACKERTIME,
	D_MOUSE1TIME,
	
	D_ANGLES,
	D_ANGLES2,
	D_ANGLES3,
	
	D_XSPRITE,
	D_UPDATESPRITE,
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


//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( PICKUPMODEL );
	PrecacheModel( FLARE1 );
	PrecacheModel( XSPRITE_MODEL );
	
	AddFileToDownloadsTable( "models/rxg/gg/xhair.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/xhair.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/xhair.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/xhair.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/xhair.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/lelhair.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/lelhair.vtf" );
	
	PrecacheSound( SOUND_START );
	AddFileToDownloadsTable( "sound/rxg/gg/powerup.mp3" );
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
	color[0] = 10;
	color[1] = 20;
	color[2] = 255;
	color[3] = 255;
}

//-------------------------------------------------------------------------------------------------
CreateSprite( Handle:data ) {
	new ent = CreateEntityByName( "env_sprite" );
	SetEntityModel( ent, XSPRITE_MODEL );
	//SetEntityRenderColor( ent, 255,255,255,255);
	SetEntityRenderMode( ent, RENDER_WORLDGLOW );
	DispatchKeyValue( ent,"scale", "64" );
	DispatchKeyValue( ent, "GlowProxySize", "30.0" );
	//DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "HDRColorScale", "0.58" );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn(ent);
	new ref = EntIndexToEntRef(ent);
	SetArrayCell( data, D_XSPRITE, ref );
	
	AcceptEntityInput(ent,"ShowSprite" );
	return ref;
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	SetArrayCell( data, D_START, GetGameTime() );
	SetArrayCell( data, D_TARGET, 0 );
	SetArrayCell( data, D_ATTACKER, 0 );
	SetArrayCell( data, D_XSPRITE, -1 );
	
	SetArrayCell( data, D_ATTACKERTIME, -1.0 );
	
	decl Float:angles[3];
	GetClientEyeAngles( client, angles );
	for( new i = 0; i < 3; i++ ) {
	
		SetArrayCell( data, D_ANGLES+i, angles[i] );
	}
	
	SetArrayCell( data, D_UPDATESPRITE, 0 );
	SetArrayCell( data, D_MOUSE1TIME, 0.0 );
	EmitSoundToAll( SOUND_START, client  );
	return data;
}

public bool:TraceFilter( entity, contentsMask ) {
	if( entity <= MaxClients )
		return false;
	return true;
}

//-------------------------------------------------------------------------------------------------
CanClientSeeTarget( client, target ) {
	decl Float:start[3], Float:end[3];
	GetClientAbsOrigin(client,start);
	GetClientAbsOrigin(target,end);
	
	start[2] += 40.0;
	end[2] += 40.0;
	TR_TraceRayFilter( start, end, CONTENTS_SOLID, RayType_EndPoint, TraceFilter );
	if( TR_DidHit() ) return false;
	start[2] += 20.0;
	end[2] += 20.0;
	TR_TraceRayFilter( start, end, CONTENTS_SOLID, RayType_EndPoint, TraceFilter );
	return !TR_DidHit();
}

Float:GetAngleDiff( Float:ang1, Float:ang2 ) {
	new Float:a = ang1 -ang2;
	a += 360.0*2.0+180.0;
	while( a > 360.0 ) a -= 360.0;
	a -= 180.0;
	return a;
}

//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new Float:time = GetGameTime() - Float:GetArrayCell( data, D_START );
	
	
	PWR_ShowStatusBoxSeconds( client, STATUSCOL, "AIMBOT", DURATION-time, 1.0-time/DURATION );
	
	if(GetGameTime()- Float:GetArrayCell( data, D_ATTACKERTIME ) < ATTACKERLOCK ) {
		// currently locked onto attacker
		new attacker = GetArrayCell( data, D_ATTACKER ) ;
		if( !IsClientInGame(attacker) || !IsPlayerAlive(attacker ) ) {
			SetArrayCell( data, D_TARGET,0);
		}
		
		
	} else {
		
		new best_match = 0;
		new Float:best_dist = LOCK_MAX_ANGLE;
		decl Float:origin[3];
		GetClientEyePosition( client, origin );
		
		
		decl Float:angles[3];
		GetClientEyeAngles( client, angles );
		decl Float:fwd[3];
		GetAngleVectors( angles, fwd, NULL_VECTOR, NULL_VECTOR );
		
		for( new i = 1; i <= MaxClients; i++ ) {
			if( i == client ) continue;
			if( !IsClientInGame(i) || !IsPlayerAlive(i) ) continue;
			if( GetClientTeam(i) == GetClientTeam(client) ) continue;
			
			decl Float:end[3];
			GetClientAbsOrigin( i, end );
			end[2] += 40.0;
			decl Float:tang[3];
			SubtractVectors( end, origin, end );
			GetVectorAngles( end, tang );
			
			new Float:dist = FloatAbs(GetAngleDiff( tang[0], angles[0] )) + FloatAbs(GetAngleDiff( tang[1], angles[1] ));
			
			if( dist < best_dist ) {
				if( CanClientSeeTarget( client, i ) ) {
					best_match = i;
					best_dist = dist;
				}
			}	
		}
		
		if( GetArrayCell( data, D_TARGET ) != best_match ) {
			SetArrayCell( data, D_TARGET, best_match );
			SetArrayCell( data, D_UPDATESPRITE, 1 );
		}
	}
	
	{
		new sprite = GetArrayCell( data, D_XSPRITE );
		new target = GetArrayCell( data, D_TARGET );
		if( !IsValidEntity(sprite) ) {
			sprite = CreateSprite(data);
			
		}
		
		if( target <= 0 ) {
			
			SetEntityRenderColor( sprite, 0,0,0,0);
		} else {
			
			if( GetArrayCell( data, D_UPDATESPRITE ) ) {
				SetArrayCell( data, D_UPDATESPRITE, 0 );
				
				new Float:pos[3];
				//GetClientAbsOrigin( target, end );
				pos[2] += 40.0;
				
				AcceptEntityInput( sprite, "ClearParent", target );
				SetVariantString( "!activator" );
				AcceptEntityInput( sprite, "SetParent", target );
				
				TeleportEntity( sprite, pos, NULL_VECTOR, NULL_VECTOR );
				SetEntityRenderColor( sprite, 255,255,255,255);
			}
		}
		
		new buttons = GetClientButtons(client);
		new Float:atime = Float:GetArrayCell( data, D_MOUSE1TIME );
		new bool:lock = !!target;
		
		while( lock ) { // this isnt a loop, just a way to easily break out of different conditions
			if( atime == 0.0 ) {
				if( buttons & IN_ATTACK ) {
					SetArrayCell( data, D_MOUSE1TIME, time );
				}
			} else {
				if( buttons & IN_ATTACK ) {
					if( time >= (atime + MOUSE1HOLDUNLOCKTIME ) ) {
						lock = false;
						break;
					}
				} else {
					SetArrayCell( data, D_MOUSE1TIME, 0.0 );
				}
			} 
			if( buttons & IN_ATTACK2 ) {
				lock = false;
				break;
			}
			break;
		} 
		
		if( lock ) {
		 
			
			decl Float:origin[3];
			decl Float:angles[3];
			GetClientEyePosition(client,origin);
			GetClientEyeAngles(client,angles);
			decl Float:tang1[3];
			decl Float:end[3];
			GetClientEyePosition( target, end );
			end[2] -= 15.0;
			
			
			
			// compensate for movement
			new Float:vel[3];
			vel[0] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[0]" );
			vel[1] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[1]" );
			vel[2] = GetEntPropFloat( client, Prop_Send, "m_vecVelocity[2]" );
			// tweak this
			for( new i = 0; i < 3; i++ ){
				vel[i] *= -0.1;
			}
			
			AddVectors( end, vel, end );
			
			SubtractVectors( end, origin, end );
			GetVectorAngles( end, tang1 );
			
			new Float:diffx,Float:diffy;
			diffx = GetAngleDiff( tang1[0], angles[0] );
			diffy = GetAngleDiff( tang1[1], angles[1] );
			
			// lock yaw
			angles[0] += diffx * 0.25;//Lerpfcl( angles[0], tang1[0], 0.1 );
			angles[1] += diffy * 0.25;//Lerpfcl( angles[1], tang1[1], 0.1 );
			
			TeleportEntity( client, NULL_VECTOR, angles, NULL_VECTOR );	
			
			
		}
	}
	
	return PC_UPDATE_CONTINUE;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {
	if( !PWR_IsPowerupActive( client ) ) return Plugin_Continue;
	
	new Handle:data = PWR_GetClientData(client);
	
	for( new i = 0; i < 3; i++ ) {
	
		SetArrayCell( data, D_ANGLES+i, angles[i] );
	}
	
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Stop( client, Handle:data, bool:death ) {
	
	PWR_ShowStatusBoxExpired( client, STATUSCOL, "AIMBOT" );
	
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Fading( client, Handle:data, bool:death ) {
	
	
}

//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	AcceptEntityInput( GetArrayCell( data, D_XSPRITE ), "kill" );
	
}

//-------------------------------------------------------------------------------------------------
public PC_OnTakeDamage( client, source, &Float:damage, damagetype ) {
	if( source > 0 ) {
		new Handle:data = PWR_GetClientData(client);
		if( GetGameTime() - Float:GetArrayCell( data, D_ATTACKERTIME ) >= ATTACKERLOCK ) {
			SetArrayCell( data, D_ATTACKERTIME, GetGameTime() );
			SetArrayCell( data, D_ATTACKER, source );
			
			if( GetArrayCell( data, D_TARGET ) != source ) {
				SetArrayCell( data, D_TARGET, source );
				SetArrayCell( data, D_UPDATESPRITE, 1 );
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetEntityRenderColor( sprite, 0, 255,255 );
	return INVALID_HANDLE;
}
 

 