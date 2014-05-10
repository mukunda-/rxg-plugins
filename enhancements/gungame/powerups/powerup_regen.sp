

#include <sourcemod>
#include <sdktools>
#include <powerups>

#pragma semicolon 1

#define REGISTER PWR_Register( "Regen" )

#define PICKUPMODEL "models/rxg/gg/plus.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define HEALSPRITE "materials/rxg/gg/health.vmt"

#define SOUND_START "*rxg/gg/powerup.mp3"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Regen Powerup",
    author      = "mukunda",
    description = "shoot them in the head",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

new color_overlay[4] = { 15,255,42,0};

new healsprite;

#define HP_PER_SECOND 50.0
#define HP_CAP 200
#define STATUSCOL  "22FF22"
#define DURATION 30.0

enum {
	D_START,
	D_LASTUPDATE,
	D_REMAINDER,
	D_NEXTSPARKLE,
	
	D_SINE,
	D_COLI, // COLOR INTENSITY
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
	healsprite = PrecacheModel( HEALSPRITE );
	
	AddFileToDownloadsTable( "models/rxg/gg/plus.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/plus.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/plus.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/plus.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/plus.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/health.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/health.vtf" );
	
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
	color[1] = 255;
	color[2] = 45;
	color[3] = 255;
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	SetArrayCell( data, D_START, GetGameTime() );
	SetArrayCell( data, D_LASTUPDATE, GetGameTime() );
	SetArrayCell( data, D_REMAINDER, 0.0 );
	SetArrayCell( data, D_COLI, 0.0 );
	SetArrayCell( data, D_SINE, 0.0 );
	SetArrayCell( data, D_NEXTSPARKLE, 0.0 );
	
	EmitSoundToAll( SOUND_START, client  );
	return data;
}

//-------------------------------------------------------------------------------------------------
AddClientSparkle( const Float:vec[3], Float:delay=0.0 ) {
	decl Float:pos[3];
	pos[0] = vec[0] + GetRandomFloat( -12.0, 12.0 );
	pos[1] = vec[1] + GetRandomFloat( -12.0, 12.0 );
	pos[2] = vec[2] + GetRandomFloat( 35.0, 45.0 );
	
	TempGlowSprite( pos, healsprite, 1.6, GetRandomFloat( 1.0, 1.4 ), GetRandomInt( 100,190 ),delay );
}

//-------------------------------------------------------------------------------------------------
AddClientSparkle2( const Float:vec[3], Float:delay=0.0 ) {
	decl Float:pos[3];
	pos[0] = vec[0] + GetRandomFloat( -32.0, 32.0 );
	pos[1] = vec[1] + GetRandomFloat( -32.0, 32.0 );
	pos[2] = vec[2] + GetRandomFloat( 15.0, 75.0 );
	
	TempGlowSprite( pos, healsprite, 1.6, GetRandomFloat( 0.1, 0.5 ), GetRandomInt( 10,170 ),delay );
}
//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new Float:totaltime = GetGameTime() - Float:GetArrayCell( data, D_START );
	
	PWR_ShowStatusBoxSeconds( client, STATUSCOL, "REGEN", DURATION-totaltime, 1.0-totaltime/DURATION );
	
	
	new hp = GetClientHealth(client);
	new Float:time = GetArrayCell( data, D_LASTUPDATE );
	time = GetGameTime() - time;
	SetArrayCell( data, D_LASTUPDATE, GetGameTime() );
	
	new Float:addition = time * HP_PER_SECOND + Float:GetArrayCell( data, D_REMAINDER );
	new iaddition = RoundToZero( addition );
	
	addition -= float(iaddition);
	SetArrayCell( data, D_REMAINDER, addition );
	
	decl Float:vec[3];
	GetClientAbsOrigin( client, vec );
	
	if( hp < 200 && totaltime > Float:GetArrayCell( data, D_NEXTSPARKLE ) ) {
		SetArrayCell( data, D_NEXTSPARKLE, totaltime + 0.5 );
		AddClientSparkle(  vec );
	}
	AddClientSparkle2(  vec );
	
	hp = hp + iaddition;
	if( hp > HP_CAP ) hp = HP_CAP;
	SetEntityHealth( client, hp );
	SetEntProp(client, Prop_Send, "m_ArmorValue", 100 );
	
	new Float:sine = GetArrayCell( data, D_SINE );
	new Float:hpval = (float(hp)/float(HP_CAP));
	sine += time * (1.0 + Lerpfcl( 2.0, 0.0, hpval*hpval ) ); 
	SetArrayCell( data, D_SINE, sine );
	
	new Float:coli = Float:GetArrayCell( data, D_COLI );
	coli = Lerpfcl( coli, 0.1 + (1.1-(FloatAbs(Sine(sine)) * float(hp)/float(HP_CAP))) * 0.3, 0.4 );
	SetArrayCell( data, D_COLI, coli );
	color_overlay[3] = RoundToNearest(coli*255.0);
	PWR_ColorOverlay( client ,color_overlay,false );
	
	return PC_UPDATE_CONTINUE;
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Stop( client, Handle:data, bool:death ) {
	//SetArrayCell( data, D_START, GetGameTime() );
	//if( GetClientHealth(client) > 100 ) 
	//	SetEntityHealth( client, 100 );
	PWR_ShowStatusBoxExpired( client, STATUSCOL, "REGEN" );
	
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Fading( client, Handle:data, bool:death ) {
	
	new Float:coli = Float:GetArrayCell( data, D_COLI );
	coli = Lerpfcl( coli, 0.0, 0.1 );
	SetArrayCell( data, D_COLI, coli );
	color_overlay[3] = RoundToNearest(coli*255.0);
	PWR_ColorOverlay( client ,color_overlay,false );
}

//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	
	color_overlay[3] = 0;
	PWR_ColorOverlay( client ,color_overlay,false );
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetEntityRenderColor( sprite, 11, 255,64 );
	return INVALID_HANDLE;
}
 
