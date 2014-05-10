#include <sourcemod>
#include <sdktools>
#include <powerups>

#pragma semicolon 1

#define REGISTER PWR_Register( "Barrier" )

#define PICKUPMODEL "models/rxg/gg/shield.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"
 
#define MAT_OVERLAY "models/rxg/gg/egg.mdl"
#define MAT_ABSORB "models/rxg/gg/eggshell.mdl"

#define SOUND_START "*rxg/gg/barrier.mp3"
#define SOUND_HIT "*rxg/gg/barrier_impact.mp3"
#define SOUND_ACTIVE "*rxg/gg/bubble.mp3"
#define SOUND_FADE "*rxg/gg/eggfade.mp3"

#define SA_LOOP_TIME 18.9

#define STATUSCOL "2233FF"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Barrier Powerup",
    author      = "mukunda",
    description = "the best offense is a gud defense",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

#define START_STRENGTH 1200.0
 
//-------------------------------------------------------------------------------------------------
enum {
	D_START,
	D_OVERLAY,
	D_ABSORB,
	D_STRENGTH,
	D_STRENGTHTIME,
	D_HITTIME,
	D_NEXT_ACTIVE_SOUND,
	
	D_TOTAL
};

//-------------------------------------------------------------------------------------------------
new String:downloads[][] = {
	"models/rxg/gg/shield.dx90.vtx",
	"models/rxg/gg/shield.mdl",
	"models/rxg/gg/shield.vvd",
	"materials/rxg/gg/shield.vmt",
	"materials/rxg/gg/shield.vtf",
	"materials/rxg/gg/flare.vmt",
	"materials/rxg/gg/flare.vtf",
	
	"models/rxg/gg/egg.mdl",
	"models/rxg/gg/egg.dx90.vtx",
	"models/rxg/gg/egg.vvd",
	"models/rxg/gg/eggshell.mdl",
	"models/rxg/gg/eggshell.dx90.vtx",
	"models/rxg/gg/eggshell.vvd",
	
	"materials/rxg/gg/egg.vmt",
	"materials/rxg/gg/egg.vtf",
	"materials/rxg/gg/eggshell.vmt",
	"materials/rxg/gg/eggshell.vtf",
	
	"sound/rxg/gg/barrier.mp3",
	"sound/rxg/gg/barrier_impact.mp3",
	"sound/rxg/gg/bubble.mp3", //2 much wurk
	"sound/rxg/gg/eggfade.mp3"
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
	PrecacheModel( MAT_OVERLAY );
	PrecacheModel( MAT_ABSORB );
	PrecacheModel( FLARE1 );
	PrecacheModel( "sprites/purpleglow1.vmt" );
	
	for( new i = 0; i < sizeof downloads; i++ ) {
		AddFileToDownloadsTable( downloads[i] );
	}
	
	PrecacheSound( SOUND_START );
	PrecacheSound( SOUND_HIT );
	PrecacheSound( SOUND_ACTIVE );
	PrecacheSound( SOUND_FADE );
}


//-------------------------------------------------------------------------------------------------
public PC_Info( &Float:duration, &Float:fade, &type ) {
	duration = 120.0;
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

SetupEgg( parent, const String:mat[] ) {
	new ent = CreateEntityByName( "prop_dynamic" );
	SetEntityModel( ent, mat );
	SetEntityRenderMode( ent, RENDER_TRANSADD );
	//DispatchKeyValue( ent, "GlowProxySize", "50.0" );
	//DispatchKeyValue( ent, "framerate", "15.0" ); 
	//DispatchKeyValue( ent, "scale", "64" ); 
	//SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	
	//AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", parent );
	
	new Float:pos[3] = {0.0,0.0,33.0};
	new Float:ang[3];
	TeleportEntity( ent, pos, ang, ang );
	return ent;
}

PlayActiveSound( Handle:data ) {
	EmitSoundToAll( SOUND_ACTIVE, GetArrayCell( data, D_OVERLAY ) );
	SetArrayCell( data, D_NEXT_ACTIVE_SOUND, GetGameTime() + SA_LOOP_TIME );
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	
	
	//SetEntityHealth( client, 200 );
	//SetEntProp( client, Prop_Send, "m_ArmorValue", 100 );
	
	SetArrayCell( data, D_START, GetGameTime() );
	SetArrayCell( data, D_STRENGTHTIME, GetGameTime() );
	SetArrayCell( data, D_STRENGTH, START_STRENGTH );
	SetArrayCell( data, D_HITTIME, GetGameTime() );
	
	new ent = SetupEgg( client, MAT_OVERLAY );
	SetEntityRenderColor( ent, 255,255,255, 255);
	SetArrayCell( data, D_OVERLAY, EntIndexToEntRef(ent) );
	
	ent = SetupEgg( client, MAT_ABSORB );
	SetEntityRenderColor( ent, 0,0,0, 0);
	SetArrayCell( data, D_ABSORB, EntIndexToEntRef(ent) );
	
	EmitSoundToAll( SOUND_START, client );
	PlayActiveSound( data );
	
	return data;///
	
}

//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new Float:starttime = GetArrayCell( data, D_START );
	new Float:ltime = GetGameTime() - starttime;
	new Float:strength = GetArrayCell( data, D_STRENGTH );
	
	new color[4] = {11,84,255,0};
	new Float:co;  
	if( ltime < 0.25 ) {
		co = (ltime) / 0.25;
		
	} else {
		co = 1.0 -0.1 + Sine((ltime - 0.25)*10.0+0.7853981) * 0.1;
	}
	//if( ltime < 0.5 ) {
		//new Float:c = (ltime) / 0.4;
		//SetEntityHealth( client, Lerpcl(100,200,c) );
		
	//}
	
	color[3] = RoundToNearest(Lerpfcl( 0.0, 255.0, co ) * 0.25);// * (strength/START_STRENGTH));
	
	if( GetGameTime() >= Float:GetArrayCell( data, D_NEXT_ACTIVE_SOUND ) ) {
		PlayActiveSound( data );
	}
	
	
	///new overlay = GetArrayCell( data, D_OVERLAY );
	//SetEntityRenderColor( overlay, 15,84,255, RoundToNearest(220.0+Sine(GetGameTime()*10.0) *10.0) );
	new absorb = GetArrayCell( data, D_ABSORB );
	{
		new Float:a = GetArrayCell( data, D_HITTIME );
		a = GetGameTime() - a;
		if( a < 0.25 ) {
			a = (0.25-a) * 4.0;
			a = a*a;
			a = a * 300.0;
			if( a > 255.0 ) a = 255.0;
		//	new color2[4] = {255,255,255,255};
			//color2[3] = RoundToNearest(a * 0.25);
			//PWR_ColorOverlay( client, color2, false, true );
			
			color[0] = Lerpcl( color[0], 255, a/255.0 );
			color[1] = Lerpcl( color[1], 255, a/255.0 );
			color[2] = Lerpcl( color[2], 255, a/255.0 );
			
			color[3] = Lerpcl( color[3], 255, a/512.0 );
			
		} else {
			a = 0.0;
		}
		if( ltime < 1.5 ) {
			a = Lerpfcl( 255.0, a, ltime/1.5 );
			
			new Float:b = (ltime-0.2)/ 1.3 ;
			color[0] = Lerpcl( 255, color[0], b);
			color[1] = Lerpcl( 255, color[1], b );
			color[2] = Lerpcl( 255, color[2],b);
			color[3] = Lerpcl( 200, color[3], b);
			
		}
		
		SetEntityRenderColor( absorb, 220,110,43, RoundToNearest(a) );
		
	
	}
	
	PWR_ColorOverlay( client, color, false );
	
	new Float:delta = GetGameTime() - Float:GetArrayCell( data, D_STRENGTHTIME );
	
	strength = strength - delta * 32.0;
	SetArrayCell( data, D_STRENGTHTIME, GetGameTime() );
	if( strength < 0.0 ) strength = 0.0;
	SetArrayCell( data, D_STRENGTH, strength );
	
	//SetEntityHealth( client, 100 + RoundToNearest(strength*100.0/START_STRENGTH) );
	if( strength <= 0.0 ) {
		return PC_UPDATE_FADE;
	} else {
		decl String:percent[64];
		new ipercent = RoundToNearest(strength*100.0/START_STRENGTH);
		Format( percent, sizeof percent, "%d%%", ipercent );
		PWR_ShowStatusBox( client, STATUSCOL, "BARRIER", percent, strength/START_STRENGTH,ipercent );
	}
	
	return PC_UPDATE_CONTINUE;
}	

//-------------------------------------------------------------------------------------------------
public Float:PC_Stop( client, Handle:data, bool:death ) {
	SetArrayCell( data, D_START, GetGameTime() );
	
	EmitSoundToAll( SOUND_FADE, GetArrayCell( data, D_OVERLAY ) );
	
	PWR_ShowStatusBoxExpired( client, STATUSCOL, "BARRIER" );
}


//-------------------------------------------------------------------------------------------------
public PC_Fading( client, Handle:data ) {
	new Float:starttime = GetArrayCell( data, D_START );
	if( GetGameTime() - starttime < 0.3 ) {
		new Float:c = (GetGameTime() - starttime) / 0.25;
		
		SetEntityRenderColor( GetArrayCell( data, D_OVERLAY ), 255,255,255, Lerpcl( 255, 0, c ) );
		SetEntityRenderColor( GetArrayCell( data, D_ABSORB ), 0,0,0,0 );
		
		
		new color[4] = {11,84,255,0};
		color[3] = RoundToNearest(Lerpcl( 255, 0, c )*0.35);
		PWR_ColorOverlay( client, color, true );
	}
}


//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	SetEntityRenderColor( client, 255, 255, 255 );
	new color[4] = {255,255,255,0};
	PWR_ColorOverlay( client, color,true );
	StopSound( GetArrayCell( data, D_OVERLAY ), SNDCHAN_STREAM, SOUND_ACTIVE  );
	
	
	AcceptEntityInput( GetArrayCell( data, D_OVERLAY ), "Kill" );
	AcceptEntityInput( GetArrayCell( data, D_ABSORB ), "Kill" );
	
	if( IsPlayerAlive(client) ) {
		if( GetClientHealth(client) > 100 ) {
			SetEntityHealth( client, 100 );
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {
	new Handle:data = CreateArray(1,1);
	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetArrayCell( data, 0,  sprite);
	SetEntityRenderColor( sprite, 11, 42,255 );
	
	return data;
}

//-------------------------------------------------------------------------------------------------
public PC_OnTakeDamage( client, source, &Float:damage ) {
	new Handle:data = PWR_GetClientData(client);
	
	new Float:strength = GetArrayCell( data, D_STRENGTH );
	strength -= damage;
	if( strength < 0.0 ) strength = 0.0;
	SetArrayCell( data, D_STRENGTH, strength );
	SetArrayCell( data, D_HITTIME, GetGameTime() );
	EmitSoundToAll( SOUND_HIT, GetArrayCell( data, D_ABSORB ),_,SNDLEVEL_GUNFIRE );
	damage = 0.0;
}
