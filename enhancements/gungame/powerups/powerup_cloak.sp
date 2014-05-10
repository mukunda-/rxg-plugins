#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <powerups>

#pragma semicolon 1

#define REGISTER PWR_Register( "Cloak" )

#define PICKUPMODEL "models/rxg/gg/ghost.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define MAT_OVERLAY "materials/sprites/glow.vmt"

#define SOUND_START "*rxg/gg/invis.mp3"
#define SOUND_END "*rxg/gg/cloakfade.mp3"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Cloak Powerup",
    author      = "mukunda",
    description = "might mess up the knife level",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};


new g_laser;
	

new bool:g_hooked[MAXPLAYERS+1];

#define DURATION 20.0

enum {
	D_START,
	D_HIDDEN,
	D_OVERLAY,
	D_VISTIME,
	D_TOTAL
};

new ent_postprocessor;

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	if( LibraryExists( "powerups" ) ) {
		REGISTER;
	}
	
	HookEvent( "round_start", OnRoundStart );
	HookEvent( "weapon_fire", Event_WeaponFire );
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
	PrecacheModel( MAT_OVERLAY );
	PrecacheModel( "sprites/purpleglow1.vmt" );
	g_laser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	

	AddFileToDownloadsTable( "models/rxg/gg/ghost.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/ghost.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/ghost.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/boo.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/boo.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	
	PrecacheSound( SOUND_START );
	PrecacheSound( SOUND_END );
	AddFileToDownloadsTable( "sound/rxg/gg/invis.mp3" );
	AddFileToDownloadsTable( "sound/rxg/gg/cloakfade.mp3" );
	
	CreatePP();
}

CreatePP() {
	ent_postprocessor = CreateEntityByName( "postprocess_controller" );
	DispatchKeyValue( ent_postprocessor, "fadetime", "1.5" );
	DispatchKeyValue( ent_postprocessor, "localcontraststrength", "-1" );
	DispatchKeyValue( ent_postprocessor, "localcontrastedgestrength", "0" );
	DispatchKeyValue( ent_postprocessor, "vignettestart", "1.5" );
	DispatchKeyValue( ent_postprocessor, "vignetteend", "0" );
	DispatchKeyValue( ent_postprocessor, "vignetteblurstrength", "4" );
	DispatchSpawn(ent_postprocessor);
}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	CreatePP();

}

public OnClientPutInServer(client) {
	g_hooked[client]=false;
}

//-------------------------------------------------------------------------------------------------
public PC_Info( &Float:duration, &Float:fade, &type ) {
	duration = DURATION;
	fade = 0.0;
	type = POWERUP_EFFECT;
}

//-------------------------------------------------------------------------------------------------
public PC_Model( String:model[], maxlen, color[4] ) {
	strcopy( model, maxlen, PICKUPMODEL );
	color[0] = 255;
	color[1] = 255;
	color[2] = 255;
	color[3] = 255;
}


//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	
	if( GetClientHealth(client) < 75 )
		SetEntityHealth( client, 75 );
	
	SetArrayCell( data, D_START, GetGameTime() );
	SetArrayCell( data, D_HIDDEN, false );
	SetArrayCell( data, D_VISTIME, GetGameTime() );
	if( !g_hooked[client] )SDKHook( client, SDKHook_PostThinkPost, OnPostThinkPost);
	g_hooked[client]=true;
	
	//SetEntityRenderMode(client,  RENDER_NORMAL );
	new ent = CreateEntityByName( "env_sprite" );
	SetEntityModel( ent, MAT_OVERLAY );
	SetEntityRenderMode( ent, RENDER_WORLDGLOW );
	DispatchKeyValue( ent, "GlowProxySize", "50.0" );
	DispatchKeyValue( ent, "framerate", "15.0" ); 
	DispatchKeyValue( ent, "scale", "64" ); 
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", client );
	new Float:pos[3] = {0.0,0.0,40.0};
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	SetEntityRenderColor( ent, 255,255,255,0 );
	SetArrayCell( data, D_OVERLAY, EntIndexToEntRef(ent) );
	
	// todo lightning effect
	// play sounds
	LightningEffect( client,g_laser,100,100,140) ;
	
	SetEntPropEnt( client, Prop_Send, "m_hPostProcessCtrl", ent_postprocessor );
	EmitSoundToAll( SOUND_START, client );
	
	return data;
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast) {

	// emit paintball
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( PWR_IsPowerupActive(client) ) {
		
		new Handle:data = PWR_GetClientData(client);
		SetArrayCell( data, D_VISTIME, GetGameTime() );
	}
//	ShootPaintball( client );
}

//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new color[4] = {0,0,128,128};
	
	new Float:a = GetArrayCell( data, D_VISTIME );
	new overlay = GetArrayCell( data, D_OVERLAY );
	new Float:time = GetGameTime() - Float:GetArrayCell( data, D_START );
	a = GetGameTime() - a;
	if( a < 0.25 ) {
		
		
		new oc = Lerpcl( 255,0,a/0.25);
		SetEntityRenderColor( overlay, 255,255,255, oc );
	} else {
		SetEntityRenderColor( overlay, 255,255,255,0 );
	}
	if( time < 1.5 ) {
		color[3] = Lerpcl( 32,128,time/1.5 );
	} else if( a < 0.25 ) {
		color[3] = Lerpcl( 50,128,a/0.25 );
	}
	PWR_ColorOverlay( client, color, true );
	
	PWR_ShowStatusBoxSeconds( client, "C0D0FF", "CLOAK", DURATION-time, 1.0-time/DURATION  );
	
	/*
	if( !GetArrayCell(data, D_HIDDEN) ) {
		if( GetGameTime() > Float:GetArrayCell( data, D_START ) + 0.25 ) {
			PrintToChatAll( "\x01 \x02 DEBUG1" );
			//SetEntityRenderMode(client,  RENDER_NONE);
			SetArrayCell( data, D_HIDDEN, true );
		}
	}*/
	
	new enteffects = GetEntProp( client, Prop_Send, "m_fEffects");
	enteffects |= 32; // EF_NODRAW
	SetEntProp( client, Prop_Send, "m_fEffects", enteffects); 
}

//-------------------------------------------------------------------------------------------------
public Float:PC_Stop( client, Handle:data, bool:death ) {
	// todo lightning effect
	EmitSoundToAll( SOUND_END, client );
	PWR_ShowStatusBoxExpired( client, "C0D0FF", "CLOAK"   );
	SetEntPropEnt( client, Prop_Send, "m_hPostProcessCtrl", -1 );
	LightningEffect( client,g_laser,100,100,140) ;
}


//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	if( g_hooked[client] )SDKUnhook( client, SDKHook_PostThinkPost, OnPostThinkPost);
	g_hooked[client]=false;
	SetEntPropEnt( client, Prop_Send, "m_hPostProcessCtrl", -1 );
	
//	SetEntityRenderMode(client,  RENDER_NORMAL );
	new color[4] = {255,255,255,0};
	PWR_ColorOverlay( client, color, true );
	
	AcceptEntityInput( GetArrayCell( data, D_OVERLAY ), "Kill" );

	SetEntProp( client, Prop_Send, "m_fEffects", GetEntProp( client, Prop_Send, "m_fEffects") & ~32); 
	
	if( IsPlayerAlive(client) ) {
		// unhide weapons
		for( new i = 0; i < 64; i++ ) {
			new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
			if( ent != -1 ) {
				new enteffects = GetEntProp( ent, Prop_Send, "m_fEffects");
				enteffects &= ~32; // EF_NODRAW
				SetEntProp( ent, Prop_Send, "m_fEffects", enteffects); 
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {
	new Handle:data = CreateArray(1,1);
	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetArrayCell( data, 0,  sprite);
	SetEntityRenderColor( sprite, 255, 255,255 );
	
	return data;
}

//-------------------------------------------------------------------------------------------------
public PC_OnTakeDamage( client, source, &Float:damage ) {
	// disable damage for 2 seconds after grabbing powerup
	new Handle:data = PWR_GetClientData(client);
	if( (GetGameTime() - Float:GetArrayCell( data, D_START )) < 2.0 ) {
		damage = 0.0;
	}
}


//-------------------------------------------------------------------------------------------------
public OnPostThinkPost(client)
{
	if( !PWR_IsPowerupActive( client ) ) return;
	if( !IsPlayerAlive(client) ) return;
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0 );
	
	new weapon = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( weapon != -1 ) {
		new enteffects = GetEntProp( weapon, Prop_Send, "m_fEffects");
		enteffects |= 32; // EF_NODRAW
		SetEntProp( weapon, Prop_Send, "m_fEffects", enteffects);  
	}
}
