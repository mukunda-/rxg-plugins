#include <sourcemod>
#include <sdktools>
#include <powerups>
#include <sdkhooks>


#pragma semicolon 1

#define REGISTER PWR_Register( "Explosive" )

#define PICKUPMODEL "models/rxg/gg/firecoin.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define START_SOUND "*rxg/gg/powerup.mp3"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Explosive Powerup",
    author      = "mukunda",
    description = "feel the burn",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

#define DURATION 20.0

#define EXPLOSION_COOLDOWN 0.2
#define EXPLOSION_DAMAGE 42

new hooked_players[MAXPLAYERS+1];

new lelsprite;

#define STATUSCOL "ffe020"

new Handle:explosions;

enum {
	D_START,
	D_NEXT_EXPLOSION,
	D_TOTAL
};


//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	if( LibraryExists( "powerups" ) ) {
		REGISTER;
	}
	
	HookEvent( "bullet_impact", OnBulletImpact );
	
	explosions = CreateStack( 4 );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "powerups" ) ) {
		REGISTER;
	}
}

/*
public Action:SpawnExplosion( Handle:timer, any:data ) {
	ResetPack(data);
	new client= GetClientOfUserId( ReadPackCell(data) );
	decl Float:pos[3];
	for( new i = 0; i < 3; i++ )
		pos[i] = ReadPackFloat( data );
		
	CreateExplosion( pos, EXPLOSION_DAMAGE, client );
	return Plugin_Handled;
}*/

//-------------------------------------------------------------------------------------------------
public OnBulletImpact( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( !hooked_players[client] ) return;
	if( !PWR_IsPowerupActive( client ) ) return;
	
	new Handle:data = PWR_GetClientData( client );
	
	
	new Float:vec[3];
	vec[0] = GetEventFloat( event, "x" );
	vec[1] = GetEventFloat( event, "y" );
	vec[2] = GetEventFloat( event, "z" );
	new Float:start[3];
	GetClientEyePosition( client, start );
	
	
	//TempGlowSprite( vec, lelsprite, 0.25, 1.0, 80 );
	
	if( GetGameTime() >= GetArrayCell( data, D_NEXT_EXPLOSION ) ) {
		SetArrayCell( data, D_NEXT_EXPLOSION, GetGameTime() + D_NEXT_EXPLOSION );
		
		new any:exp[4];
		for( new i = 0; i < 3; i++ )
			exp[i+1] = vec[i];
			
		exp[0] = GetClientUserId( client );
		PushStackArray( explosions, exp );
		
		new color[4] = {150,100,20,255};
		TE_SetupBeamPoints( start, vec, lelsprite, 0, 0, 30, 0.25, 4.0, 4.0, 512, 10.0, color, 20);
		TE_SendToAll();
		
		/*
		new Handle:datat;
		CreateDataTimer( 1.0, SpawnExplosion, datat, TIMER_FLAG_NO_MAPCHANGE );
		WritePackCell( datat, GetClientUserId( client ) );
		WritePackFloat( datat, GetEventFloat( event, "x" ) );
		WritePackFloat( datat, GetEventFloat( event, "y" ) );
		WritePackFloat( datat, GetEventFloat( event, "z" ) );
		*/
		//decl Float:pos[3];
		//pos[0] = GetEventFloat( event, "x" );
		//pos[1] = GetEventFloat( event, "y" );
		//pos[2] = GetEventFloat( event, "z" );
		
		//CreateExplosion( pos, EXPLOSION_DAMAGE, client );
	}
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( PICKUPMODEL );
	PrecacheModel( FLARE1 );
	
	lelsprite = PrecacheModel( "materials/sprites/physbeam.vmt" );
	
	AddFileToDownloadsTable( "models/rxg/gg/firecoin.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/firecoin.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/firecoin.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/firecoin.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/firecoin.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	
	PrecacheSound( START_SOUND );
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
	color[0] = 15;
	color[1] = 84;
	color[2] = 255;
	color[3] = 255;
}


//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	SetArrayCell( data, D_START, GetGameTime() );
	SetArrayCell( data, D_NEXT_EXPLOSION, GetGameTime() + EXPLOSION_COOLDOWN );
	
	EmitSoundToAll( START_SOUND, client );
	hooked_players[client]  = true;
	return data;
}


//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new Float:time = GetGameTime() - Float:GetArrayCell( data, D_START );
	
	PWR_ShowStatusBoxSeconds( client, STATUSCOL, "EXPLOSIVE", DURATION-time, 1.0-time/DURATION );
	
	new Float:end[3];
	
	new color6[4] = { 128, 90, 5, 255 };
	
	//GetClientAbsOrigin( client, end );
	//end[2] += GetRandomFloat( 4.0,64.0 );
//	TE_SetupBeamRingPoint( end, 150.0, 5.0, lelsprite, 0, 0, 30, 0.25, 0.8, 6.0, color6, 5,0 );
	//TE_SendToAll(0.05);
	
	GetClientAbsOrigin( client, end );
	end[2] += GetRandomFloat( 4.0,64.0 );
	TE_SetupBeamRingPoint( end, 5.0, 150.0, lelsprite, 0, 0, 30, 0.25, 1.8, 6.0, color6, 5,0 );
	TE_SendToAll(0.0);
	end[2] -= 20.0;
	
	return PC_UPDATE_CONTINUE;
}


//-------------------------------------------------------------------------------------------------
public PC_Stop( client, Handle:data, bool:death ) {
	SetArrayCell( data, D_START, GetGameTime() );
	hooked_players[client] = false;
	PWR_ShowStatusBoxExpired( client, STATUSCOL, "EXPLOSIVE" );
	
}

public PC_Fading( client, Handle:data ) {
}

//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	hooked_players[client] = false;
	
}

//-------------------------------------------------------------------------------------------------
public PC_OnGiveDamage( client, victim, &Float:damage, Float:vec[3] ) {
	
	if( victim >= 1 && victim <= MaxClients && victim != client ) {
		IgniteEntity( victim, 10.0, false, 100.0 );
	}
}

//-------------------------------------------------------------------------------------------------
public PC_OnTakeDamage( client, source, &Float:damage, type ) {
	
	if( type & (DMG_BURN|DMG_SLOWBURN|DMG_BLAST) ) {
		damage = 0.0;
	}
}


// thank you pirate wars:
//----------------------------------------------------------------------------------------------------------------------
CreateExplosion( Float:vec[3], damage,owner,bool:suppress=false ) {
	new ent = CreateEntityByName("env_explosion");	 
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", owner );
	DispatchSpawn(ent);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_iMagnitude",damage); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",200); 
	
	if( !suppress )
		EmitAmbientSound( ")weapons/hegrenade/explode3.wav", vec, _, SNDLEVEL_GUNFIRE  );
		
	if( suppress ) {
		DispatchKeyValue( ent, "spawnflags", "89" );
	}

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
	
	new Float:shakelen = 150.0;
	new Float:shakediv = 3.0; // want:50
	if( suppress ) {
		// want:15
		shakelen = 120.0;
		shakediv = 6.0;
	}
	// shake screens
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		new Float:pos[3];
		GetClientEyePosition( i, pos );
		new Float:dist = GetVectorDistance( vec, pos, true );
		if( dist < shakelen*shakelen ) {
			ShakeScreen( i, (shakelen - SquareRoot(dist)) / shakediv );
		}
	}
	
	ThrowPlayers( vec, 300.0 );
}
//----------------------------------------------------------------------------------------------------------------------
ShakeScreen( client, Float:amplitude ) {
	 
	new Handle:message = StartMessageOne( "Shake", client );
	PbSetInt( message, "command", 0 );
	PbSetFloat(message, "local_amplitude", amplitude);
	PbSetFloat(message, "frequency", 25.0);
	PbSetFloat(message, "duration", 1.0);
	
	EndMessage();

}

ThrowPlayers( const Float:vec[3], Float:power ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) || !IsPlayerAlive(i) ) continue;
		new Float:cpos[3];
		GetClientAbsOrigin(i,cpos);
		cpos[2] += 40.0;
		
		new Float:dist = GetVectorDistance( vec, cpos, true );
		if( dist < power*power ) {
			dist = SquareRoot(dist);
			dist = dist / power;
			dist = 1.0 - dist;
			dist = dist*dist;
			dist = dist * power;
			cpos[2] += 32.0;
			new Float:dir[3];
			SubtractVectors( cpos, vec, dir );
			NormalizeVector( dir, dir);
			ScaleVector( dir ,dist * 5.0);
			cpos[2] = cpos[2]- 32.0-40.0+5.0;
			TeleportEntity( i, cpos, NULL_VECTOR, dir );
		}
	}
}

public OnMapEnd() {
	while( !IsStackEmpty( explosions ) ) 
		PopStack(explosions);
}

public OnGameFrame() {
	while( !IsStackEmpty( explosions ) ) {
		new any:data[4];
		PopStackArray( explosions, data );
		new client = GetClientOfUserId( data[0] );
		if( !client ) continue;
		new Float:pos[3];
		for( new i = 0; i < 3; i++ )
			pos[i] = data[i+1];
		pos[2] += 10.0;
		CreateExplosion( pos, EXPLOSION_DAMAGE, client );
	}
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetEntityRenderColor( sprite, 225, 200,10 );
	return INVALID_HANDLE;
}