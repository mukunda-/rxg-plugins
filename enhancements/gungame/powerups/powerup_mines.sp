#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <powerups>
#include <vphysics>

#pragma semicolon 1

#define REGISTER PWR_Register( "Mines" )

#define PICKUPMODEL "models/rxg/gg/mineicon.mdl"
#define FLARE1 "materials/rxg/gg/flare.vmt"
#define PULSE "materials/rxg/gg/pulse.vmt"

#define DETONATE_BEEP "buttons/blip2.wav"
#define EXPLODE_SOUND "*rxg/gg/explode1.mp3"
#define ACTIVATE_SOUND "*rxg/gg/mine.mp3"

#define MONEY_MODEL "models/props/cs_assault/money.mdl"
#define MINE_MODEL "models/rxg/gg/mine.mdl"

#define THROW_SOUND "weapons/hegrenade/he_draw.wav"
#define PICKUP_SOUND "weapons/g3sg1/g3sg1_draw.wav"

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
    name        = "Mines Powerup",
    author      = "mukunda",
    description = "for those pesky road runners",
    version     = "1.0.0",
    url         = "www.mukunda.com"
};

new player_mines[MAXPLAYERS+1];

new Handle:mine_data;
new mine_map[2048]; // indexes into mine data

#define WAIT_TIME 1.5 // time until the mine activates
#define THROW_VELOCITY 300.0
#define DETONATE_TIME 0.4
#define DAMAGE 180


new glow_color[4][3] = {
	{255,255,255}, // spec/unassigned, anyone can use
	{255,5,1},
	{255,240,47}, //t
	{120,150,255} // ct
};


/*
enum {
	P_YTHRESHOLD,
	P_YCONST,
	P_YMAXE,
	
	P_XTHRESHOLD,
	P_XCONST,
	P_XMAX,
	P_TOTAL
};
*/
new Float:fparams[] = {
	50.0,
	50.0,
	20.0,
	
	200.0,
	50.0,
	1.0
};
//new Float:testvec[3];


//-------------------------------------------------------------------------------------------------
enum {
	MD_STATE,
	MD_TIME,
	MD_ENT,
	MD_VEC,
	MD_VEC2,
	MD_VEC3,
	MD_TEAM,
	MD_OWNER,
//	MD_STEAM,

	MD_OLDANG,
	MD_OLDANG2,
	MD_OLDANG3,
	
	MD_TOTAL
};

enum {
	STATE_WAIT,
	STATE_ACTIVE,
	STATE_DETONATING
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	if( LibraryExists( "powerups" ) ) {
		REGISTER;
		PWR_HookUse( OnPlayerUse );
	}
	
	mine_data = CreateArray( MD_TOTAL );
	// RegConsoleCmd( "minetest", minetest );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "powerups" ) ) {
		REGISTER;
		PWR_HookUse( OnPlayerUse );
	}
}

public OnPlayerDisconnect( client ) {
	// disable mines
	
}
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	
}

public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
}

public OnClientConnected( client ) {
	player_mines[client] = 0;
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( PICKUPMODEL );
	PrecacheModel( MONEY_MODEL );
	PrecacheModel( MINE_MODEL );
	PrecacheModel( FLARE1 );
	PrecacheModel( PULSE );
	
	AddFileToDownloadsTable( "models/rxg/gg/mineicon.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/mineicon.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/mineicon.vvd" );
	AddFileToDownloadsTable( "models/rxg/gg/mine.dx90.vtx" );
	AddFileToDownloadsTable( "models/rxg/gg/mine.mdl" );
	AddFileToDownloadsTable( "models/rxg/gg/mine.vvd" );
	AddFileToDownloadsTable( "models/rxg/gg/mine.phy" );
	AddFileToDownloadsTable( "materials/rxg/gg/mine.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/mine.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/flare.vtf" );
	AddFileToDownloadsTable( "materials/rxg/gg/pulse.vmt" );
	AddFileToDownloadsTable( "materials/rxg/gg/pulse.vtf" );
	
	PrecacheSound( DETONATE_BEEP );
	PrecacheSound( EXPLODE_SOUND );
	PrecacheSound( ACTIVATE_SOUND );
	AddFileToDownloadsTable( "sound/rxg/gg/explode1.mp3" );
	AddFileToDownloadsTable( "sound/rxg/gg/mine.mp3" );
	
	PrecacheSound( THROW_SOUND );
	PrecacheSound( PICKUP_SOUND );
	
	
}

//-------------------------------------------------------------------------------------------------
public PC_Info( &Float:duration, &Float:fade, &type ) {
	duration = 0.0;
	fade = 0.0;
	type = POWERUP_CUSTOM;
}

//-------------------------------------------------------------------------------------------------
public PC_Model( String:model[], maxlen, color[4] ) {
	strcopy( model, maxlen, PICKUPMODEL );
	color[0] = 255;
	color[1] = 255;
	color[2] = 0;
	color[3] = 255;
}

//-------------------------------------------------------------------------------------------------
//public TriggerTouched( const String:output[], caller,activator, Float:delay ) {
public TriggerTouched( entity, other ) {
	new ent = entity;
	new client = other;
	if( client < 1 || client > MaxClients ) return;
	
	new parent = GetEntPropEnt( ent, Prop_Data, "m_pParent" );
	
	
	new index = mine_map[parent];
	
	if( GetClientTeam( client ) != GetArrayCell( mine_data, index, MD_TEAM ) ) {
		DetonateMine( index );
		AcceptEntityInput( ent, "Kill" ); // disable trigger
		return;
	}
	//AcceptEntityInput( ent, "Disable" );
	//AcceptEntityInput( ent, "Enable" );
}

AddPulse( parent, const color[3] ) {
	new ent = CreateEntityByName( "env_sprite" );
	SetEntityModel( ent, PULSE );
	SetEntityRenderMode( ent, RENDER_WORLDGLOW );
	DispatchKeyValue( ent, "GlowProxySize", "25.0" );
	DispatchKeyValue( ent, "framerate", "0" ); 
	DispatchKeyValue( ent, "HDRColorScale", "0.6" ); 
	DispatchKeyValue( ent, "scale", "40" ); 
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	
	AcceptEntityInput( ent, "ShowSprite" );
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", parent );
	new Float:pos[3] = {0.0,0.0,0.0};
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	SetEntityRenderColor( ent, color[0], color[1], color[2],255 );
}

//-------------------------------------------------------------------------------------------------
AddTrigger( parent ) {
	
	new ent = CreateEntityByName( "trigger_multiple" );
	
	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "StartDisabled", "1" );
	
	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", parent );
	AcceptEntityInput( ent, "Disable" ); // i dont get this lol, jsut copied and pasted

	SetEntityModel( ent, MONEY_MODEL );
	new Float:minbounds[3] = {-42.0, -42.0, -42.0};//what is the answer to life
	new Float:maxbounds[3] = {42.0, 42.0, 42.0};
	SetEntPropVector( ent, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", maxbounds);
	SetEntProp( ent, Prop_Send, "m_usSolidFlags", 4|8 |0x400); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test
	new enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);  

	new Float:pos[3];
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	SDKHook( ent, SDKHook_StartTouchPost, TriggerTouched );
	//HookSingleEntityOutput( ent, "OnStartTouch", TriggerTouched );
	return ent;
	
}

//-------------------------------------------------------------------------------------------------
RemoveMineData( index ) {
	new size = GetArraySize(mine_data);
	for( new i = index+1; i < size; i++ ) {
		new ent = GetArrayCell( mine_data, i, MD_ENT );
		if( !IsValidEntity(ent) ) continue;
		new entindex = EntRefToEntIndex(ent);
		mine_map[entindex]--;
	}
	RemoveFromArray( mine_data, index );
}

//-------------------------------------------------------------------------------------------------
DetonateMine( mine ) {
	new mstate = GetArrayCell( mine_data, mine, MD_STATE );
	if( mstate != STATE_ACTIVE ) return; // cannot detonate in this state
	mstate = STATE_DETONATING;
	SetArrayCell( mine_data, mine, STATE_DETONATING, MD_STATE );
	SetArrayCell( mine_data, mine, GetGameTime(), MD_TIME );
	
	new ent = GetArrayCell( mine_data, mine, MD_ENT );
	if( !IsValidEntity(ent) ) return;
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	ent = EntRefToEntIndex(ent);

	EmitSoundToAll( DETONATE_BEEP, ent,_, 90,_, _, 150 );
}
//new g_test;
AddSteam( mine ) {

//	minetest jetlength 15; minetest startsize 5; minetest endsize 20; minetest speed 40; minetest spreadspeed 10;
	new ent = CreateEntityByName( "env_steam" );
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", mine );
	new Float:vec[3];
	new Float:ang[3] = {90.0,0.0,0.0};
	TeleportEntity( ent, vec ,ang, NULL_VECTOR);
	DispatchKeyValue( ent, "type", "1" );		// heatwave
//	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "SpreadSpeed", "10" );
	DispatchKeyValue( ent, "Speed", "50" );
	DispatchKeyValue( ent, "StartSize", "5" );
	DispatchKeyValue( ent, "EndSize", "20" );
	DispatchKeyValue( ent, "Rate", "10" );
	DispatchKeyValue( ent, "rendercolor", "255 255 255 255" );
	DispatchKeyValue( ent, "JetLength", "15" );
	DispatchKeyValue( ent, "rollspeed", "8" );
	DispatchSpawn(ent);
	AcceptEntityInput(ent, "TurnOn");
	
}

Float:thingy( Float:a, Float:threshold, Float:scale, Float:clamp ) {
	// god knows that this does
	a = a / threshold;
	a = a * a;
	a = a * scale;
	if( a > clamp ) a = clamp;
	return a;
}

UpdateMine( ent, index ) {
	new owner = GetArrayCell( mine_data, index, MD_OWNER );
	if( !IsClientInGame(owner) || GetClientTeam(owner) != GetArrayCell( mine_data,index,MD_TEAM) ) {
		AcceptEntityInput(ent, "Kill" );
		return;
	}
	new mstate = GetArrayCell( mine_data, index, MD_STATE );
	new Float:time = GetArrayCell( mine_data, index, MD_TIME );
	time = GetGameTime() - time;
	
	if( mstate == STATE_WAIT ) {
		// wait state, do nothing until time expires
		if( time >= WAIT_TIME ) {
			// activate mine
			AddTrigger( ent );
			AddPulse(ent, glow_color[GetArrayCell( mine_data, index, MD_TEAM )]);
			AddSteam(ent);
			SetEntityRenderColor( ent, 255,255,255);	
			//SetEntProp( ent, Prop_Send, "m_CollisionGroup", 0 );
			SetArrayCell( mine_data, index, STATE_ACTIVE, MD_STATE );
			EmitSoundToAll( ACTIVATE_SOUND, ent  );
			decl Float:vec[3];
			GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", vec );
			vec[2] += 70.0;
			for( new i =0 ; i < 3; i++ )
				SetArrayCell( mine_data, index, vec[i], MD_VEC+i );
		}
	} else if( mstate == STATE_ACTIVE || mstate == STATE_DETONATING ) {
		//decl Float:vec[3];
		
		
		new Float:addvel[3] = {0.0,0.0,0.0};
		//new Float:ang[3];
		decl Float:position[3];
		GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", position );
		//GetEntPropVector( ent, Prop_Data, "m_angAbsRotation", ang );
		
		new Float:desired[3];
		desired[0] = GetArrayCell( mine_data, index, MD_VEC );
		desired[1] = GetArrayCell( mine_data, index, MD_VEC+1 );
		desired[2] = GetArrayCell( mine_data, index, MD_VEC+2 );
		
		
		
		
		new Float:ydiff = desired[2] - position[2];
		if( ydiff >	5.0 ) {
			ydiff = ydiff / fparams[0];//100;
			addvel[2] = ydiff*ydiff;
			addvel[2] *= fparams[1];//20.0;
			
			if( addvel[2] > fparams[2]  ) {
				addvel[2] = fparams[2]; 
			}
		}
		//PrintToConsole( 1, "TEST %.2f - %.2f / %.2f / %.2f", fparams[0], fparams[1], fparams[2], addvel[2] );
		
		
		position[2] = 0.0;
		desired[2] = 0.0;
		new Float:dist = GetVectorDistance( position, desired );
		decl Float:hvel[3];
		SubtractVectors( desired, position, hvel );
		NormalizeVector(hvel,hvel);
		
		dist = dist / fparams[3];//100.0;
		dist = dist*dist;
		dist = dist * fparams[4];//5.0;
		if( dist > fparams[5] ) dist = fparams[5];
		
		addvel[0] = hvel[0] * dist;
		addvel[1] = hvel[1] * dist;
		
		new Float:addavel[3] = {0.0,0.0,0.0};
		new Float:ang[3];
		GetEntPropVector( ent, Prop_Data, "m_angAbsRotation", ang );
		if( ang[0] > 180.0 ) ang[0] -= 360.0;
		if( ang[2] > 180.0 ) ang[2] -= 360.0;
		
		new Float:newang[3];
		
		{
			new Float:cvel[3];
			for( new i = 0; i < 3; i++ ) {
				cvel[i] = ang[i] - Float:GetArrayCell( mine_data, index, MD_OLDANG+i );
				SetArrayCell( mine_data, index, ang[i], MD_OLDANG+i );
			}
			
			new Float:a;
			if( FloatAbs(ang[0]) > 5.0 ) {
				a = thingy(ang[0],100.0,50.0,2.0);//
				
				if( ang[0] > 0.0 && cvel[0] < 0.0 ) a += cvel[0] * 0.1;
				else if( ang[0] < 0.0 && cvel[0] > 0.0 ) a -= cvel[0] * 0.1;
				if( a > 2.0 ) a = 2.0;
				
				//newang[0] = Lerpfcl( ang[0], 0.0, 0.2 );
				newang[0] = ang[0] > 0 ? -a:a;// Lerpfcl( ang[2], 0.0, 0.2 );
			}
			
			if( FloatAbs(ang[2]) > 5.0 ) {
				a = thingy(ang[2],100.0,50.0,2.0);//
				
				if( ang[2] > 0.0 && cvel[2] < 0.0 ) a += cvel[2] * 0.6;
				else if( ang[2] < 0.0 && cvel[2] > 0.0 ) a -= cvel[2] * 0.6;
				if( a > 2.0 ) a = 2.0;
				
				newang[2] = ang[2] > 0 ? -a:a;
			}
			addavel[1] = newang[0];//(newang[0] - ang[0]) * 1.0;
			addavel[0] = newang[2];//(newang[2] - ang[2]) * 1.0;
		}
		//addavel[0] = testvec[0];
		//addavel[1] = testvec[1];
		//addavel[2] = testvec[2];
		
		//PrintToConsole( 1, "TEST %.2f - %.2f / %.2f / %.2f", addvel[2], ydiff, desired[2], position[2] );
		Phys_AddVelocity( ent, addvel, addavel );
	//	PrintToConsole( 1, "TEST %.2f / %.2f / %.2f", ang[0],ang[1],ang[2] );
		
		
		//TeleportEntity( ent, NULL_VECTOR, newang, NULL_VECTOR );
		/*
		vec[0] = ang[0]*ang[0];
		if(vec[0] > 5.0 ) vec[0] = 5.0;
		if( ang[0] > 0.0 ) {
			vec[0] = -vec[0];
		}*/
		//PrintToConsole( 1, "TEST %.2f %.2f %.2f", ang[0], ang[1], ang[2] );
		//GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", vec );
		//vec[0] = Lerpfcl( vec[0], 0.0	
		
		if( mstate == STATE_DETONATING ) {
			if( time >= DETONATE_TIME ) {
				GetEntPropVector( ent, Prop_Data, "m_vecAbsOrigin", position );
				AcceptEntityInput(ent,"Kill");
				CreateExplosion( position, DAMAGE, owner );
				
				return;
			}
		}
	} 
	/*
	decl Float:vec[3];
	for( new j = 0; j < 3; j++ )
		vec[j] = GetArrayCell( mine_data, i, MD_VEC+j );
	vec[2] += Sine( time * 4.0 ) * 20.0;
	new Float:ang[3];
	ang[1] = time*270.0;
	TeleportEntity( ent, vec, ang, NULL_VECTOR );
	*/
}

//-------------------------------------------------------------------------------------------------
UpdateMines() {
	for( new i = 0; i < GetArraySize(mine_data); i++ ) {
		new ent = GetArrayCell( mine_data, i, MD_ENT );
		if( !IsValidEntity(ent) ) {
			RemoveMineData( i ); // prune zombies
			i--;
			continue;
		}
		
		UpdateMine(EntRefToEntIndex( ent ), i );
		
		
		
	}
}

//-------------------------------------------------------------------------------------------------
CreateMine( const Float:pos[3], const Float:vel[3], owner ) {
	new ent = CreateEntityByName( "prop_physics_multiplayer" );
	DispatchKeyValue( ent, "model" , MINE_MODEL );
	DispatchSpawn(ent);
	TeleportEntity(ent, pos, NULL_VECTOR, vel );
	//SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	SetEntProp( ent, Prop_Send, "m_hOwnerEntity", owner );
	SetEntityRenderColor( ent, 0,0,0 );
	
	new i = PushArrayCell( mine_data, 0 );
	SetArrayCell( mine_data, i, EntIndexToEntRef(ent), MD_ENT );
	SetArrayCell( mine_data, i, GetGameTime(), MD_TIME );
	
	//for( new j = 0; j < 3; j++ )
	//	SetArrayCell( mine_data, i, pos[j], MD_VEC+j );
	SetArrayCell( mine_data, i, STATE_WAIT, MD_STATE );
	SetArrayCell( mine_data, i, GetClientTeam( owner ), MD_TEAM );
	SetArrayCell( mine_data, i, owner, MD_OWNER );
	for( new j = 0; j < 3; j++ )
		SetArrayCell( mine_data, i, 0.0, MD_OLDANG+j );
//	Phys_EnableGravity( ent, false );
	//g_test = ent;
	mine_map[ent] = i;
}

//-------------------------------------------------------------------------------------------------
public OnPlayerUse( client ) {
	if( player_mines[client] > 0 ) {
		player_mines[client]--;
		decl Float:pos[3];
		GetClientEyePosition( client, pos );
		decl Float:angles[3];
		GetClientEyeAngles( client, angles );
		decl Float:vel[3];
		GetAngleVectors( angles, vel, NULL_VECTOR, NULL_VECTOR );
		vel[2] += 0.55;
		NormalizeVector(vel,vel);
		ScaleVector( vel, THROW_VELOCITY );
		CreateMine( pos,vel, client );
		
		EmitSoundToAll( THROW_SOUND, client );
	}
}

//-------------------------------------------------------------------------------------------------
public OnGameFrame() {
	 UpdateMines();
}


//-------------------------------------------------------------------------------------------------
public Handle:PC_Start( client ) {
	
	player_mines[client] += 5;
	
	PrintToChat( client, "\x01 \x04Item Obtained: \x01Mines\x04; Press E to throw." );
	PrintHintText( client, "ITEM OBTAINED: MINES\n PRESS E TO THROW." );
	EmitSoundToAll( PICKUP_SOUND, client );
	
	// todo; translation
	return INVALID_HANDLE;
}
//public Action:minetest( client,args ) {
/*
	decl String:arg[2][64];
	GetCmdArg( 1, arg[0], sizeof arg[] );
	GetCmdArg( 2, arg[1], sizeof arg[] );
	DispatchKeyValue( g_test, arg[0], arg[1] );
	AcceptEntityInput( g_test, "TurnOff" );
	AcceptEntityInput( g_test, "TurnOn" );*/
	
	//PrintToChatAll( "TEST=%d", args );
	/*for( new i = 0 ;i < args; i++ ) {
		decl String:arg[64];
		GetCmdArg( i+1, arg, sizeof arg );
		fparams[i] = StringToFloat( arg );
	}*/
	/*
	for( new i = 0; i < 3; i++ ){ 
		decl String:arg[64];
		GetCmdArg( i+1, arg, sizeof arg );
		testvec[i] = StringToFloat( arg );
	}
	new Float:a[3];
	TeleportEntity(g_test, NULL_VECTOR,a,a);
	Phys_SetVelocity( g_test, a, a );
	return Plugin_Handled;
}*/


// thank you pirate wars:
//----------------------------------------------------------------------------------------------------------------------
CreateExplosion( Float:vec[3], damage,owner,bool:suppress=false ) {
	new ent = CreateEntityByName("env_explosion");	 
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", owner );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",damage); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",300); 
	
	if( !suppress )
		//EmitAmbientSound( ")weapons/hegrenade/explode3.wav", vec, _, SNDLEVEL_GUNFIRE  );
		EmitAmbientSound( EXPLODE_SOUND, vec, _, SNDLEVEL_GUNFIRE  );
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
	
	ThrowPlayers( vec, 200.0 );
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

//-------------------------------------------------------------------------------------------------
public Handle:PC_PickupSpawned( ent ) {	
	new sprite = AttachGlowSprite( ent, FLARE1, 64.0 );
	SetEntityRenderColor( sprite, 255, 128,25 );
	return INVALID_HANDLE;
}
