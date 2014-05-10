
#include <sourcemod>
#include <sdktools>
#include <powerups>

#pragma semicolon 1

#define REGISTER PWR_Register( "Lifeleech" )

#define PICKUPMODEL "models/rxg/gg/metroid.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define START_SOUND "*rxg/gg/powerup.mp3"
#define LEECH_SOUND "*rxg/gg/leech.mp3"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Lifeleech Powerup",
    author      = "mukunda",
    description = "nom nom nom nom",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

#define LEECHSOUND_COOLDOWN 1.0
#define STATUSCOL "992299"
#define DURATION 30.0

new purple;

new mat_fatlaser;

enum {
	D_START,
	D_LIFE,
	D_NEXTSOUND,
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
	
	purple =  PrecacheModel( "materials/sprites/purpleglow1.vmt" );
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	
	AddFileToDownloadsTable( "models/rxg/gg/metroid.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/metroid.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/metroid.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/metroid.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/metroid.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	
	AddFileToDownloadsTable( "sound/rxg/gg/leech.mp3" );
	AddFileToDownloadsTable( "sound/rxg/gg/powerup.mp3" );
	
	PrecacheSound( LEECH_SOUND );
	PrecacheSound( START_SOUND );
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
	color[0] = 45;
	color[1] = 255;
	color[2] = 11;
	color[3] = 255;
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	SetArrayCell( data, D_START, GetGameTime() );
	SetArrayCell( data, D_NEXTSOUND, GetGameTime() );
	
	EmitSoundToAll( START_SOUND, client );
	
	return data;
}

//-------------------------------------------------------------------------------------------------
AddClientSparkle( const Float:vec[3], Float:delay=0.0 ) {
	decl Float:pos[3];
	pos[0] = vec[0] + GetRandomFloat( -28.0, 28.0 );
	pos[1] = vec[1] + GetRandomFloat( -28.0, 28.0 );
	pos[2] = vec[2] + GetRandomFloat( 15.0, 70.0 );
	
	TempGlowSprite( pos, purple, GetRandomFloat( 0.1, 0.8 ), 0.6, GetRandomInt( 2,40 ),delay );
}

//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new Float:totaltime = GetGameTime() - Float:GetArrayCell( data, D_START );
	
	
	PWR_ShowStatusBoxSeconds( client, STATUSCOL, "LIFELEECH", DURATION-totaltime, 1.0-totaltime/DURATION );
	
	

	
	new Float:life = GetArrayCell( data, D_LIFE );
	new lifeget = RoundToZero(life * 0.25);
	new hp = GetClientHealth( client );
	hp += lifeget;
	life -= float( lifeget );
	if( hp > 175 ) hp = 175;
	SetEntityHealth( client, hp );
	SetArrayCell( data, D_LIFE, life );
	
	decl Float:vec[3];
	GetClientAbsOrigin(client,vec);
	AddClientSparkle( vec );
	return PC_UPDATE_CONTINUE;
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Stop( client, Handle:data, bool:death ) {
//	if( GetClientHealth(client) > 100 ) SetEntityHealth( client, 100 );	
	PWR_ShowStatusBoxExpired( client, STATUSCOL, "LIFELEECH" );
	
	
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Fading( client, Handle:data, bool:death ) {
	
	
}

//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	
	
}

//-------------------------------------------------------------------------------------------------
public PC_OnGiveDamage( client, victim, &Float:damage, Float:vec[3] ) {
	if( client == victim || victim < 1 ) return;
	if( GetClientTeam(victim) == GetClientTeam(client) ) return;
	new Handle:data = PWR_GetClientData(client);
	new Float:life = GetArrayCell( data, D_LIFE);
	life += damage * 0.6;
	SetArrayCell( data, D_LIFE, life );
	
	decl Float:start[3], Float:end[3];
	
	GetClientAbsOrigin( victim, start );
	GetClientAbsOrigin( client, end );
	start[2] += 40.0;
	end[2] += 40.0;
	
	new color1[4] = { 5, 125, 2, 255 };
	new color2[4] = { 27, 128, 30, 255 };
	new color3[4] = { 65, 128, 75, 255 };
	new color4[4] = { 128, 128, 128, 255 };
	TE_SetupBeamPoints( start, end, mat_fatlaser, 0, 0, 0, 0.25, 4.0, 4.0, 0, 0.0, color1, 0 );
	TE_SendToAll();

	TE_SetupBeamPoints( start, end, mat_fatlaser, 0, 0, 0, 0.25, 2.5, 2.5, 0, 2.0, color2, 0 );
	TE_SendToAll(0.05);

	TE_SetupBeamPoints( start, end, mat_fatlaser, 0, 0, 0, 0.25, 1.25, 1.25, 0, 4.0, color3, 0 );
	TE_SendToAll(0.1);

	TE_SetupBeamPoints( start, end, mat_fatlaser, 0, 0, 0, 0.25, 0.625, 0.625, 0, 6.0, color4, 0 );
	TE_SendToAll(0.15);
	
	new color6[4] = { 128, 22, 5, 255 };
	TE_SetupBeamRingPoint( end, 150.0, 5.0, mat_fatlaser, 0, 0, 0, 0.25, 0.8, 6.0, color6, 0,0 );
	TE_SendToAll(0.05);
	TE_SetupBeamRingPoint( end, 5.0, 150.0, mat_fatlaser, 0, 0, 0, 0.25, 0.8, 6.0, color2, 0,0 );
	TE_SendToAll(0.1);
	end[2] -= 20.0;
	TE_SetupBeamRingPoint( end, 150.0, 5.0, mat_fatlaser, 0, 0, 0, 0.25, 0.8, 6.0, color6, 0,0 );
	TE_SendToAll(0.1);
	TE_SetupBeamRingPoint( end, 5.0, 150.0, mat_fatlaser, 0, 0, 0, 0.25, 0.8, 6.0, color2, 0,0 );
	TE_SendToAll(0.15);
	
	new color5[4] = { 10,255,50, 140};
	PWR_ColorFlash( client, color5, 0.05, 0.25, true );
	
	if( GetGameTime() >= GetArrayCell( data, D_NEXTSOUND ) ) {
		SetArrayCell( data, D_NEXTSOUND, GetGameTime() + LEECHSOUND_COOLDOWN );
		EmitSoundToAll( LEECH_SOUND, client,_, SNDLEVEL_GUNFIRE );
	}
}



//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetEntityRenderColor( sprite, 86, 4,86 );
	return INVALID_HANDLE;
}
