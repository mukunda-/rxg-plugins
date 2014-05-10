#if defined _powerups_included
	#endinput
#endif

#define _powerups_included


// powerup plugin API
//
// must implement these functions
//
// PC_Info( &Float:duration, &Float:fade, &type ); 		
//    returns info about powerup
//
// PC_Model( String:model[], maxlen, color[4] );		
//    model file used for pickup animation
//    color for glow behind it
//
// Handle:PC_Start( client );								
//    when powerup is activated on a client, return userdata for other functions
//
// Float:PC_Stop( client, Handle:data );			
//    when powerup starts fading on a client
//
// bool:PC_Update( client, Handle:data );						
//    called every frame for clients who have powerups
//    return false if powerup has been terminated early
//
// PC_Fading( client, Handle:data )
//    called when powerup is fading, update is not called
//
// Float:PC_End( client, Handle:data );			
//    when powerup is done fading
//
// flow: info/modelfile ......... start ... update ... update ... update ... stop ... fading ... fading ... end
//
// optional functions:
// 
// PC_OnGiveDamage( client, victim, &Float:damage, Float:vec[3] );
// PC_OnTakeDamage( client, source, &Float:damage, damagetype );
//
// Handle:PC_PickupSpawned( ent )
// PC_PickupUpdate( ent, state, Float:time, Handle:data )
// PC_PickupTaken( ent, Handle:data )
// PC_PickupEnd( ent, Handle:data )
//

functag ClientUseForward public(client);
native PWR_HookUse( ClientUseForward:handler );

enum {
	POWERUP_EFFECT,
	POWERUP_CUSTOM
};

enum {
	PICKUPSTATE_FADEIN,
	PICKUPSTATE_READY,
	PICKUPSTATE_FADEOUT,
	PICKUPSTATE_TAKEN
};

enum {
	PC_UPDATE_CONTINUE,
	PC_UPDATE_FADE,
	PC_UPDATE_END
};

native PWR_Register( const String:name[] );
native PWR_ColorOverlay( client, color[4], bool:modulate, bool:clear=true );
native PWR_ColorFlash( client, color[4], Float:holdtime, Float:fadetime, bool:modulate, bool:clear=false );

native PWR_ShowStatusBox( client, const String:color[], const String:name[], const String:duration[], Float:percent, serial );//i know it says percent but it accepts 0-1
native PWR_ShowStatusBoxExpired( client, const String:color[], const String:name[] );//i know it says percent but it accepts 0-1
native PWR_ShowStatusBoxSeconds( client, const String:color[], const String:name[], Float:seconds, Float:percent, serial=-1 );//i know it says percent but it accepts 0-1

native Handle:PWR_GetClientData( client ); // for functions that don't have data passed to them
//native PWR_SetClientData( client, Handle:data ); // ONLY USE THIS IN PC_START
native bool:PWR_IsPowerupActive( client ); // returns TRUE if calling plugin has an active powerup on a client

stock Lerpcl( a, b, Float:c ) {
	if( c > 1.0 ) c = 1.0;
	if( c < 0.0 ) c = 0.0;
	return a + RoundToNearest((float(b)-float(a))*c);
}

stock Float:Lerpfcl( Float:a, Float:b, Float:c ) {
	if( c > 1.0 ) c = 1.0;
	if( c < 0.0 ) c = 0.0;
	return a + (b-a)*c;
}

stock AttachGlowSprite( parent, const String:model[], Float:scale ) {
	
	new ent = CreateEntityByName( "env_sprite" );
	SetEntityModel( ent, model );
	SetEntityRenderColor( ent, 255,255,255 );
	SetEntityRenderMode( ent, RENDER_WORLDGLOW );
	DispatchKeyValue( ent, "GlowProxySize", "30.0" );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "15.0" ); 
	SetEntPropFloat(ent, Prop_Send, "m_flSpriteScale", scale );
	//DispatchKeyValue( ent, "scale", "40.0" ); 
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	
	AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent",parent );
	
	new Float:pos[3];
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	return ent;
}

stock LightningEffect( client, texture,r,g,b ) {
	new color[4] = {128,0,0,255};
	color[0] = r;
	color[1] = g;
	color[2] = b;
	color[3] = 255;
	decl Float:start[3];
	decl Float:end[3];
	GetClientAbsOrigin(client,end);
	for( new i = 0; i < 3; i++ )
		start[i] = end[i];
	start[2] += 80.0;
	end[2] -= 10.0;
	TE_SetupBeamPoints( start, end, texture, 0, 0, 30, 0.33, 3.0, 3.0, 0, 30.0, color, 25 );
	TE_SendToAll();
}

stock TempGlowSprite( const Float:vec[3], mat, Float:life, Float:size, brightness, Float:delay=0.0 ) {
	
    TE_SetupGlowSprite(vec, mat, life, size, brightness );
    TE_SendToAll( delay);
}

stock TempSprite( const Float:vec[3], mat, Float:size, brightness, Float:delay=0.0 ) {
	TE_Start( "Sprite" );
	//TE_Start( "Smoke" );
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteNum( "m_nModelIndex", mat );
	TE_WriteFloat( "m_fScale", size );
	TE_WriteNum( "m_nBrightness", brightness );
	//TE_WriteNum( "m_nFrameRate", brightness );
	TE_SendToAll( delay);
}
