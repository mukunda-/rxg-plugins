
#include <sourcemod>
#include <sdktools>
#include <powerups>

#pragma semicolon 1

#define REGISTER PWR_Register( "Rampage" )

#define PICKUPMODEL "models/rxg/gg/bull.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"

#define HEARTBEAT "player/heartbeatloop.wav"

#define PICKUPSOUND "*rxg/gg/rampage.mp3"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Rampage Powerup",
    author      = "mukunda",
    description = "effective party crashing",
    version     = "1.1.0",
    url         = "www.mukunda.com"
};

new ragesprite;
new g_laser;

new ent_postprocessor;

#define DURATION 20.0

enum {
	D_START,
//	D_LASTDURATION,
	D_TOTAL
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	if( LibraryExists( "powerups" ) ) {
		REGISTER;
	}
	
	HookEvent( "round_start", OnRoundStart );
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
	ragesprite=PrecacheModel( "materials/rxg/gg/rage.vmt" );
	PrecacheSound( HEARTBEAT );
	g_laser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	
	AddFileToDownloadsTable( "models/rxg/gg/bull.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/bull.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/bull.vvd" );
	AddFileToDownloadsTable( "materials/rxg/gg/bull256.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/bull256.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/rage.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/rage.vtf" );
	
	PrecacheSound( PICKUPSOUND );
	AddFileToDownloadsTable( "sound/rxg/gg/rampage.mp3" );
	
	CreatePP();
}

CreatePP() {
	ent_postprocessor = CreateEntityByName( "postprocess_controller" );
	DispatchKeyValue( ent_postprocessor, "fadetime", "0.5" );
	DispatchKeyValue( ent_postprocessor, "localcontraststrength", "-4" );
	DispatchKeyValue( ent_postprocessor, "localcontrastedgestrength", "-1" );
	DispatchKeyValue( ent_postprocessor, "vignettestart", "0" );
	DispatchKeyValue( ent_postprocessor, "vignetteend", "1.1" );
	DispatchKeyValue( ent_postprocessor, "vignetteblurstrength", "1.1" );
	DispatchSpawn(ent_postprocessor);

}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	CreatePP();
}

//-------------------------------------------------------------------------------------------------
ClipCycleTime(client,ent) {
	if( ent == -1 ) return;
	if( GetEntProp( ent, Prop_Send, "m_iClip1" ) < 5 ) SetEntProp( ent, Prop_Send, "m_iClip1", 5 );
	if( GetEntPropFloat( ent, Prop_Send, "m_flNextPrimaryAttack" ) > GetGameTime() + 0.25 ) {
		SetEntPropFloat( ent, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.25 );
		//SetEntPropFloat( ent, Prop_Send, "m_flNextAttack", GetGameTime() + 0.1 );
		new ViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		if (ViewModel != -1) {
			SetEntProp(ViewModel, Prop_Send, "m_nSequence", 0);
		}
	}
}

//-------------------------------------------------------------------------------------------------
public PC_Info( &Float:duration, &Float:fade, &type ) {
	duration = DURATION;//20.0;
	fade = 1.0;
	type = POWERUP_EFFECT;
}

//-------------------------------------------------------------------------------------------------
public PC_Model( String:model[], maxlen, color[4] ) {
	strcopy( model, maxlen, PICKUPMODEL );
	color[0] = 255;
	color[1] = 24;
	color[2] = 15;
	color[3] = 255;
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	new Handle:data = CreateArray( 1, D_TOTAL );
	SetArrayCell( data, D_START, GetGameTime() );
	//SetArrayCell( data, D_LASTDURATION, 0 );
	
	
	SetEntityRenderColor( client, 255,24,15 );
	
	SetEntPropEnt( client, Prop_Send, "m_hPostProcessCtrl", ent_postprocessor );
	
	EmitSoundToClient( client, HEARTBEAT,_,_,_,_,0.1 );
	EmitSoundToAll( PICKUPSOUND,client );
	
	LightningEffect( client, g_laser,252,11,5 );
	// play sounds
	return data;
}

//-------------------------------------------------------------------------------------------------
AddClientSparkle( const Float:vec[3], Float:delay=0.0 ) {
	decl Float:pos[3];
	pos[0] = vec[0] + GetRandomFloat( -22.0, 22.0 );
	pos[1] = vec[1] + GetRandomFloat( -22.0, 22.0 );
	pos[2] = vec[2] + GetRandomFloat( 15.0, 70.0 );
	
	TempGlowSprite( pos, ragesprite, 1.5, GetRandomFloat( 0.1,0.5 ), GetRandomInt( 10,30 ),delay );
}

//-------------------------------------------------------------------------------------------------
public PC_Update( client, Handle:data ) {
	new Float:starttime = GetArrayCell( data, D_START );
	
	new Float:time = GetGameTime() - starttime;
	
	new color[4] = {255,14,5,0};
	new Float:co;  
	/*
	if( time < 0.75 ) {
		//co = 0.5+(time-0.5) / 0.25;
		
	} else {
		//co = 1.0 -0.1 + Sine((time - 0.75)*10.0+0.7853981) * 0.1;
	}*/
	
	{
		PWR_ShowStatusBoxSeconds( client, "ff0000", "RAMPAGE", DURATION-time, 1.0-time/DURATION, RoundToNearest((DURATION-time)*10.0) );
		/*
		new value = RoundToNearest((DURATION-time)*10);
		if( value != GetArrayCell( data, D_LASTDURATION ) ) {
			SetArrayCell( data, D_LASTDURATION, value );
			
			decl String:bar[128];
			new String:block[] = "█";
			new write = 0;
			new barlen = Lerpcl( 20, 0, time/DURATION );
			for( new i = 0; i < barlen; i++ ) {
				bar[write++] = block[0];
				bar[write++] = block[1];
				bar[write++] = block[2];
			}
			bar[write++]= 0 ;
			PrintHintText( client, "<font color=\"#ff0000\" size=\"32\">RAMPAGE: </font><font size=\"32\">%.1fs\n</font><font color=\"#ff0000\" size=\"24\">%s</font>", DURATION-time, bar);
		}*/
	}
	
	if( time < 1.2 )
		EmitSoundToClient( client, HEARTBEAT, _, _, _, SND_CHANGEVOL, Lerpfcl( 0.1,1.0,time/1.0 ) );
	
	new Float:sin = 1.0 -0.15 + Sine((time - 0.75)*10.0+0.7853981) * 0.15;
	co = Lerpfcl(  0.0, sin, (time) / 1.0 );
	
	if( time < 0.5 ) {
		new Float:c = (GetGameTime() - starttime) / 0.4;
		SetEntityHealth( client, Lerpcl(100,200,c) );
		
	}
	
	//color[0] = Lerpcl( 255, 255, time / 0.5 );
	//color[1] = Lerpcl( 64, 0, time / 0.5 );
	
	color[3] = Lerpcl( 0,255, co );
	PWR_ColorOverlay( client, color, true );
	if( time < 0.5 ) {
		new colort[4] = {255,0,0,0};
		colort[3] = Lerpcl( 255, 30, time/0.5 );
		PWR_ColorOverlay( client, colort, false,true );
		//PWR_ColorOverlay( client, colort, false,false );
		//PWR_ColorOverlay( client, color, true,false );
	}
	
	
	
	ClipCycleTime( client,GetPlayerWeaponSlot( client, 0 ) );
	ClipCycleTime( client,GetPlayerWeaponSlot( client, 1 ) );
	ClipCycleTime( client,GetPlayerWeaponSlot( client, 2 ) );
	
	decl Float:vec[3];
	GetClientAbsOrigin( client, vec );
	for( new i = 0; i < 5; i++ ) {
		AddClientSparkle(vec, float(i)*0.1);
	}
	return PC_UPDATE_CONTINUE;
}	

//-------------------------------------------------------------------------------------------------
public Float:PC_Stop( client, Handle:data, bool:death ) {
	SetArrayCell( data, D_START, GetGameTime() );
	
	SetEntPropEnt( client, Prop_Send, "m_hPostProcessCtrl", -1 );

	PWR_ShowStatusBoxExpired( client, "ff0000", "RAMPAGE" );
}
	
//-------------------------------------------------------------------------------------------------
public PC_Fading( client, Handle:data ) {
	new Float:starttime = GetArrayCell( data, D_START );
	new Float:time = GetGameTime() - starttime;
	EmitSoundToClient( client, HEARTBEAT, _, _, _, SND_CHANGEVOL, Lerpfcl( 1.0,0.0,time/1.0 ) );
	if( time < 0.3 ) {
		new Float:c = (GetGameTime() - starttime) / 0.25;
		SetEntityRenderColor( client, 255, Lerpcl( 24,255,c ), Lerpcl( 15,255,c) );
		
		new color[4] = {255,14,5,0};
		color[3] = Lerpcl( 255, 0, c );
		PWR_ColorOverlay( client, color, true );
	}
}

//-------------------------------------------------------------------------------------------------
public Float:PC_End( client, Handle:data, bool:death ) {
	StopSound( client, SNDCHAN_AUTO, HEARTBEAT );
	StopSound( client, SNDCHAN_AUTO, HEARTBEAT );
	SetEntityRenderColor( client, 255, 255, 255 );
	new color[4] = {255,255,255,0};
	PWR_ColorOverlay( client, color,true );
	SetEntPropEnt( client, Prop_Send, "m_hPostProcessCtrl", -1 );

	if( IsPlayerAlive(client) ) {
		if( GetClientHealth(client) > 100 ) {
			SetEntityHealth( client, 100 );
		}
	}
}


//-------------------------------------------------------------------------------------------------
public PC_OnGiveDamage( client, victim, &Float:damage, Float:vec[3] ) {
	vec[0] *= 4.0;
	vec[1] *= 4.0;
	vec[2] *= 4.0;
	damage *= 1.5;
}

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {
	new Handle:data = CreateArray(1,1);
	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetArrayCell( data, 0,  sprite);
	SetEntityRenderColor( sprite, 255, 22,44 );
	
	return data;
}

//-------------------------------------------------------------------------------------------------
//public PC_PickupUpdate( ent, state, Float:time, Handle:data ) {
//	new sprite = GetArrayCell( data, 0, AttachGlowSprite( ent, PICKUPMODEL, 32.0 ) );
//	// todo
//}

