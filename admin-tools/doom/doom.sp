//----------------------------------------------------------------------------------
//
// THE DOOM COMMAND
//
//----------------------------------------------------------------------------------

// SPECIAL THANKS TO https://www.youtube.com/user/SoundTubeHD FOR THE MOST AMAZING SOUND EFFECT THAT DOESNT SOUND LIKE SHIT LIKE THE REST OF YOUTUBE

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "Doom",
	author = "mukunda",
	description = "oh shit",
	version = "1.0.0",
	url = "www.mukunda.com"
};

#define ADMIN_FLAG ADMFLAG_SLAY

#define SOUND1 "ambient/energy/force_field_loop1.wav"
#define SOUND2 "ambient/energy/weld1.wav"
#define SOUND3 "ambient/energy/spark5.wav"
#define SOUND4 "ambient/energy/zap9.wav"
#define SOUND5 "player/orch_hit_csharp_short.wav"
#define SOUND6 "player/heartbeatloop.wav"
#define SOUND7 "player/headshot1.wav"
#define SOUND8 "player/headshot2.wav"

#define SND_SCREAM2 "doom/doom_screaming.mp3"
#define SND_SCREAM2_FILE "sound/doom/doom_screaming.mp3"

new String:pain_sounds[][] = {
	"player/damage1.wav",
	"player/damage2.wav",
	"player/damage3.wav",
	"player/pl_pain5.wav",
	"player/pl_pain6.wav",
	"player/pl_pain7.wav"
};

new String:sound_list[][] = {
	SOUND1,
	SOUND2,
	SOUND3,
	SOUND4,
	SOUND5,
	SOUND6,
	SOUND7,
	SOUND8
	//SND_SCREAM
	//SND_SCREAM2
};

#define FRAMERATE 0.05 // 20 fps

new String:DoomSequence1[] = "                aaaaaaaaaaaaaa           e e e e e e e e e e e e e e e e e e e e e e e e e eeeeeeeeeee    ";
new String:DoomSequence2[] = "                p  pp  p  p   p   p  pp  p p p p p p ppbpp p p p p p p p p p p p pp pp p p p pp pp p p    ";
new String:DoomSequence3[] = "5      1     L            p   L   L  LL      L   H   HH    H   H   r   H f f f f f fHf f f fHf f fffff    ";
new String:DoomSequence4[] = "      6      2  4             3   2   34  3  3   2   4  3    3 2 3   4    3     2    3      3    4       x";
							//# # # . # # # . # # # .


new String:FastDoomSequence1[] = "5        3 4x";           
new String:FastDoomSequence2[] = "         e f ";

new DoomSequenceLength = 0;
new FastDoomSequenceLength = 0;

new g_physbeam;
new g_bloodspray;

new g_bloodstain;

new g_hex;

new g_skull;
new g_skullskin;

new bool:precached_stuff;

new bool:doom_active[MAXPLAYERS+1];

//----------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");

	RegAdminCmd( "sm_doom", Command_Doom, ADMIN_FLAG );
	RegAdminCmd( "sm_fastdoom", Command_FastDoom, ADMIN_FLAG );
	HookEvent("round_start", Event_RoundStart ); // cancel active doom
	DoomSequenceLength = strlen(DoomSequence1);
	FastDoomSequenceLength = strlen(FastDoomSequence1);
}

//----------------------------------------------------------------------------------
public OnClientConnected(client) {
	doom_active[client] = false;
}

//----------------------------------------------------------------------------------
public PrecacheStuff() {
	if( precached_stuff ) return;
	precached_stuff = true;
	g_physbeam = PrecacheModel( "materials/sprites/physbeam.vmt" );
	g_bloodspray = PrecacheModel( "materials/sprites/bloodspray.vmt" );// "materials/sprites/bloodspray.vmt" );
	g_bloodstain = PrecacheDecal( "decals/bloodstain_002" );// "materials/sprites/bloodspray.vmt" );

	g_skull = PrecacheModel( "models/gibs/hgibs.mdl" );
	g_skullskin = PrecacheModel( "materials/models/gibs/hgibs/skull1.vmt" );

	for( new i = 0; i < sizeof(sound_list); i++ )
		PrecacheSound(sound_list[i]);
	for( new i = 0; i < sizeof(pain_sounds); i++ )
		PrecacheSound(pain_sounds[i]);

	//AddToStringTable( FindStringTable( "soundprecache" ), SND_SCREAM2 );
	PrecacheSound( SND_SCREAM2 );

	g_hex = PrecacheDecal( "doom/hex" );
	precached_stuff=true;
}

//----------------------------------------------------------------------------------
public OnMapStart() {
	precached_stuff=false;
	PrecacheStuff();

	AddFileToDownloadsTable( "materials/doom/hex.vmt" );
	AddFileToDownloadsTable( "materials/doom/hex.vtf" );
	//AddFileToDownloadsTable( SND_SCREAM_FILE );
	AddFileToDownloadsTable( SND_SCREAM2_FILE );
}

//----------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//----------------------------------------------------------------------------------
public Action:Command_Doom( client, args ) {
	if( args < 1 ) {
		PrintToConsole( client, "sm_doom <player> - Opens a portal to hell." );
		return Plugin_Handled;
	}
 
	decl String:arg[64];
	GetCmdArg( 1, arg, 64 ); 
	
	new target = FindTarget( client, arg );
	if( target == -1 ) return Plugin_Handled;
	
	Doom( client, target );

	return Plugin_Handled;
}

public Action:Command_FastDoom( client, args ) {
	if( args < 1 ) {
		PrintToConsole( client, "sm_fastdoom <player> - Hexes a player." );
		return Plugin_Handled;
	}
 
	decl String:arg[64];
	GetCmdArg( 1, arg, 64 );
 
	new target = FindTarget( client, arg );
	if( target == -1 ) return Plugin_Handled;
	
	FastDoom( client, target);

	return Plugin_Handled;
}

// doom datapack:
// CELL:state
// CELL:timer

//----------------------------------------------------------------------------------
ReadDoomData( Handle:data, &pstate, &ptick, &puserid, &pclient ) {
	ResetPack(data);
	pstate = ReadPackCell(data);
	ptick = ReadPackCell(data);
	puserid = ReadPackCell(data);
	pclient = ReadPackCell(data);
}

//----------------------------------------------------------------------------------
SaveDoomData( Handle:data, pstate, ptick ) {
	ResetPack(data);
	WritePackCell( data, pstate );
	WritePackCell( data, ptick );
}

BloodSquirt( Float:origin[3], Float:dir[3], Float:length, type, Float:beamsize=8.0 ) {
	
	new Float:end[3];
	for( new i = 0; i < 3; i++ ) {
		end[i] = origin[i] + dir[i] * length;
	}
	TR_TraceRayFilter( origin, end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0 );
	if( TR_DidHit( INVALID_HANDLE ) ) {

		TR_GetEndPosition( end, INVALID_HANDLE );

		TE_Start( "World Decal" );
		TE_WriteVector( "m_vecOrigin", end );
		TE_WriteNum( "m_nIndex", g_bloodstain );
		TE_SendToAll();

		new color[4] = {128,0,0,255};
		TE_SetupBeamPoints( origin, end, g_physbeam, 0, 0, 30, 0.5, beamsize, beamsize, 0, 30.0, color, 25 );
		//TE_SetupBeamPoints( vec, top, g_physbeam, 0, 0, 30, 10.0, 4.0, 4.0, 0, 50.0, color, 25 );
		TE_SendToAll();
	}

}

BloodSprite( Float:origin[3] ) {
	new color[4] = {128,0,0,255};
	new Float:norm[3];
	
	TE_SetupBloodSprite( origin, norm, color, 20, g_bloodspray, 0 );
	TE_SendToAll();
}
 
DrawHex( client ) {
	new Float:vec[3];
	GetClientAbsOrigin(client,vec);
	TE_Start( "World Decal" );
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteNum( "m_nIndex", g_hex );
	TE_SendToAll();
}

Lightning( Float:vec[3] ) {

	
	new Float:top[3], Float:bottom[3];
	for( new i = 0; i < 3; i++ ) {
		top[i] = vec[i];
		bottom[i] = vec[i];
	}
	top[2] += 50.0;
	bottom[2] -= 50.0;

	new color[4] = {128,50,55,255};
	TE_SetupBeamPoints( top, bottom, g_physbeam, 0, 0, 30, 5.0, 8.0, 8.0, 0, 50.0, color, 25 );
	//TE_SetupBeamPoints( vec, top, g_physbeam, 0, 0, 30, 10.0, 4.0, 4.0, 0, 50.0, color, 25 );
	TE_SendToAll();
}

LightningH( Float:vec[3] ) {

	
	new Float:top[3], Float:bottom[3];
	for( new i = 0; i < 3; i++ ) {
		top[i] = vec[i];
		bottom[i] = vec[i];
	}
	top[2] += 100.0;
	bottom[2] -= 50.0;

	new color[4] = {128,64,128,255};
	TE_SetupBeamPoints( top, bottom, g_physbeam, 0, 0, 30, 0.5, 15.0, 15.0, 0, 35.0, color, 25 );
	//TE_SetupBeamPoints( vec, top, g_physbeam, 0, 0, 30, 10.0, 4.0, 4.0, 0, 50.0, color, 25 );
	TE_SendToAll();
}

StopLoopSounds(client) {
	StopSound( client, SNDCHAN_AUTO, SOUND1 );
	StopSound( client, SNDCHAN_AUTO, SOUND6 );
	//StopSound( client, SNDCHAN_AUTO, SND_SCREAM );
	StopSound( client, SNDCHAN_AUTO, SND_SCREAM2 );
}

SpawnSkull(client) {
	new Float:vec[3];
	new Float:vel[3];
	new Float:ang[3];
	new Float:v = 100.0;
	vel[0] = GetRandomFloat( -v, v );
	vel[1] = GetRandomFloat( -v, v );
	vel[2] = 200.0+GetRandomFloat( 0.0, v );

	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );
	GetClientEyePosition(client,vec);

	/*
	TE_Start( "physicsprop" );
	TE_WriteVector( "m_vecOrigin", vec );
	TE_WriteFloat( "m_angRotation[0]", ang[0] );
	TE_WriteFloat( "m_angRotation[1]", ang[1] );
	TE_WriteFloat( "m_angRotation[2]", ang[2] );
	TE_WriteVector( "m_vecVelocity", vel );

	TE_WriteNum( "m_nModelIndex", g_skull );
//	TE_WriteNum( "m_nSkin", g_skullskin );
	TE_WriteNum( "m_nSkin", 1 );
	TE_SendToAll();*/
	
	new ent = CreateEntityByName( "prop_physics_override" );
	
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	DispatchKeyValue(ent, "model", "models/gibs/hgibs.mdl");
	DispatchSpawn(ent);
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2); // set non-collidable
 
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);   
	
	TeleportEntity( ent, vec, ang, vel);
}

DoomCommand( client, cmd, ticks ) {
	PrecacheStuff();
	decl Float:vec[3],Float:ang[3];
	GetClientAbsOrigin(client,vec);
	GetClientEyeAngles(client,ang);

	if( cmd == 'a' ) {
		
		vec[2] += 2.0;
		
		TeleportEntity( client, vec, ang, NULL_VECTOR );
	} else if( cmd == 'b' ) {
		IgniteEntity( client, 60.0, _, 250.0 );
	} else if( cmd == 'L' ) {
		Lightning(vec);
	} else if( cmd == 'H' ) {
		LightningH(vec);
	} else if( cmd == '1' ) {

		EmitSoundToAll( SOUND1, client, _, SNDLEVEL_NORMAL,_,_,_,_,_,_,_,5.0 );
	} else if( cmd == '2' ) {
		EmitSoundToAll( SOUND2, client );
	} else if( cmd == '3' ) {
		EmitSoundToAll( SOUND3, client );
	} else if( cmd == '4' ) {
		EmitSoundToAll( SOUND4, client );
	} else if( cmd == '5' ) {
		EmitSoundToAll( SOUND5, client, _, _, _, _, 50 );
	} else if( cmd == '6' ) {
		EmitSoundToAll( SOUND6, client );
	} else if( cmd == 'p' ) {
		EmitSoundToAll( pain_sounds[GetRandomInt(0,sizeof(pain_sounds)-1)], client );
	} else if( cmd == 'e' ) {
		
		new Float:vec2[3], Float:dir[3];
		GetClientEyePosition(client,vec2);
	//	vec2[0] = vec[0];
		//vec2[1] = vec[1];
		//vec2[2] = vec[2] + 32.0;
		vec2[2] += 0.1;

		for( new i = 0; i <= 2; i++ ) {
			dir[0] = GetRandomFloat( -1.0, 1.0 );
			dir[1] = GetRandomFloat( -1.0, 1.0 );
			dir[2] = GetRandomFloat( -1.0, -0.8 );
			BloodSquirt( vec2, dir, 1000.0, 0 );
		}

		vec[0] += GetRandomFloat( -10.0, 10.0 );
		vec[1] += GetRandomFloat( -10.0, 10.0 );
		vec[2] += GetRandomFloat( -10.0, 10.0 );
		BloodSprite( vec );
		//EmitSoundToAll( pain_sounds[GetRandomInt(0,sizeof(pain_sounds)-1)], client );
	} else if( cmd == 'f' ) {
		
		new Float:vec2[3], Float:dir[3];
		GetClientEyePosition(client,vec2);
	//	vec2[0] = vec[0];
		//vec2[1] = vec[1];
		//vec2[2] = vec[2] + 32.0;
		vec2[2] += 0.1;

		for( new i = 0; i <= 2; i++ ) {
			dir[0] = GetRandomFloat( -1.0, 1.0 );
			dir[1] = GetRandomFloat( -1.0, 1.0 );
			dir[2] = GetRandomFloat( 0.0, 1.0 );
			BloodSquirt( vec2, dir, 1000.0, 0 );
		}

		vec[0] += GetRandomFloat( -10.0, 10.0 );
		vec[1] += GetRandomFloat( -10.0, 10.0 );
		vec[2] += GetRandomFloat( -10.0, 10.0 );
		BloodSprite( vec );
		EmitSoundToAll( pain_sounds[GetRandomInt(0,sizeof(pain_sounds)-1)], client );

	} else if( cmd == 'g' ) {
		
		new Float:vec2[3], Float:dir[3];
		GetClientEyePosition(client,vec2);
		vec2[2] += 0.1;

		for( new i = 0; i <= 6; i++ ) {
			dir[0] = GetRandomFloat( -1.0, 1.0 );
			dir[1] = GetRandomFloat( -1.0, 1.0 );
			dir[2] = GetRandomFloat( 0.5, 1.0 );
			BloodSquirt( vec2, dir, 1000.0, 0, 30.0 );
		}

	} else if( cmd == 'x' ) {
		new Float:vec2[3], Float:dir[3];
		GetClientAbsOrigin(client,vec2);
		vec2[2] += 32.0;
		CreateExplosion(vec2);
		EmitSoundToAll( SOUND7, client );
		EmitSoundToAll( SOUND8, client );

		for( new i = 0; i <= 20; i++ ) {
			dir[0] = GetRandomFloat( -1.0, 1.0 );
			dir[1] = GetRandomFloat( -1.0, 1.0 );
			dir[2] = GetRandomFloat( -1.0, 1.0 );
			BloodSquirt( vec2, dir, 1000.0, 0 );

			vec[0] += GetRandomFloat( -10.0, 10.0 );
			vec[1] += GetRandomFloat( -10.0, 10.0 );
			vec[2] += GetRandomFloat( -10.0, 10.0 );
			BloodSprite( vec );
		}

		StopLoopSounds(client);

		
		for( new i = 0; i < 10; i++ ) {
			SpawnSkull( client );
		}

		// klil player
		ForcePlayerSuicide(client);

		new ent = GetEntPropEnt(client,Prop_Send,"m_hRagdoll");
		SetEntPropEnt(client,Prop_Send,"m_hRagdoll",-1);
		AcceptEntityInput(ent,"kill");
		
	} else if( cmd == 'r' ) {
		SetEntityFlags( client, GetEntityFlags(client) & ~FL_FROZEN );
		SetEntityMoveType( client, MOVETYPE_WALK );
	}
}

public Action:DoomUpdate( Handle:timer, any:data ) {
	new doom_state, tick, userid,pclient;
	ReadDoomData( data, doom_state,tick,userid,pclient);
	new client = GetClientOfUserId(userid);
	if( !doom_active[client] ) {
		StopLoopSounds(pclient);
		return Plugin_Stop;
	}
	if( client <= 0 ) {
		// victim disconnected
		//CreateTimer(2.0,test2,pclient);
		StopLoopSounds(pclient);
		return Plugin_Stop;
	}
	if( !IsPlayerAlive(client) ) {
		StopLoopSounds(client);
		return Plugin_Stop;
	}

	
	DoomCommand( client, DoomSequence1[tick], tick );
	DoomCommand( client, DoomSequence2[tick], tick );
	DoomCommand( client, DoomSequence3[tick], tick );
	DoomCommand( client, DoomSequence4[tick], tick );

	tick++;
	if( tick == DoomSequenceLength ) {
		doom_active[client] = false;
		return Plugin_Stop;
	}

	SaveDoomData( data, doom_state, tick );
	return Plugin_Continue;
}

public Action:FastDoomUpdate( Handle:timer, any:data ) {
	new doom_state,tick,userid,pclient;
	ReadDoomData( data, doom_state,tick,userid,pclient);
	new client = GetClientOfUserId(userid);
	if( !doom_active[client] ) {
		return Plugin_Stop;
	}
	if( client <= 0 ) {
		return Plugin_Stop;
	}
	if( !IsPlayerAlive(client) ) {
		return Plugin_Stop;
	}
	DoomCommand( client, FastDoomSequence1[tick], tick );
	DoomCommand( client, FastDoomSequence2[tick], tick );
	tick++;
	
	if( tick == FastDoomSequenceLength ) {
		doom_active[client] = false;
		return Plugin_Stop;
	}

	SaveDoomData( data, doom_state, tick );
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------
Doom( caster, client ) {


	if( !IsValidClient(client) ) {
		PrintToConsole( caster, "Invalid Client." );
		return;
	}

	if( !IsPlayerAlive(client) ) {
		PrintToConsole( caster, "Player is dead. The victim of this spell must be alive..." );
		return;
	}

	new String:targetname[32];
	GetClientName( client, targetname, 32 );

	doom_active[client] = true;

	PrintCenterTextAll( "Doom cast on %s!", targetname );

	DrawHex(client);

	SetEntityFlags( client, GetEntityFlags(client) | FL_FROZEN );
	SetEntityMoveType( client, MOVETYPE_NONE );
	SetEntityRenderColor( client, 255,0,0 );

	new Handle:data;
	CreateDataTimer( FRAMERATE, DoomUpdate, data, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );

	SaveDoomData( data, 0, 0 );
	WritePackCell( data, GetClientUserId(client) );
	WritePackCell( data, client );

	//EmitSoundToAll( SND_SCREAM, client, _, SNDLEVEL_NORMAL+10 );
	EmitSoundToAll( SND_SCREAM2, client, _, SNDLEVEL_NORMAL+10 );
}

FastDoom( caster, client ) {
	if( !IsValidClient(client) ) {
		PrintToConsole( caster, "Invalid Client." );
		return;
	}
	if( !IsPlayerAlive(client) ) {
		PrintToConsole( caster, "Player is dead. The victim of this spell must be alive..." );
		return;
	}
	doom_active[client] = true;
	DrawHex(client);
	SetEntityFlags( client, GetEntityFlags(client) | FL_FROZEN );
	SetEntityMoveType( client, MOVETYPE_NONE );
	SetEntityRenderColor( client, 255,0,0 );
	
	new Handle:data;
	CreateDataTimer( FRAMERATE, FastDoomUpdate, data, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );

	SaveDoomData( data, 0, 0 );
	WritePackCell( data, GetClientUserId(client) );
	WritePackCell( data, client );
}


public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
public CreateExplosion( Float:vec[3] ) {
	new ent = CreateEntityByName("env_explosion");	
	//DispatchKeyValue(ent, "classname", "env_explosion");
	
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",0); 
	//SetEntProp(ent, Prop_Data, "m_iRadiusOverride",0); 

	//decl String:exp_sample[64];

	//Format( exp_sample, 64, ")weapons/hegrenade/explode%d.wav", GetRandomInt( 3, 5 ) );
	/*
	if( explosion_sound_enable ) {
		explosion_sound_enable = false;
		EmitAmbientSound( exp_sample, vec, _, SNDLEVEL_GUNFIRE  );
		CreateTimer( 0.1, EnableExplosionSound );
	} */
	
	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}
/*
// remove ragdolls on death...
public Action:Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// set the mp_forcecamera value correctly, so he can watch his teammates
	// This doesn't work. Even if the convar is set to 0, the hiders are only able to spectate their teammates..
	if(GetConVarInt(g_forceCamera) == 1)
	{
		if(!IsFakeClient(client) && GetClientTeam(client) != 2)
			SendConVarValue(client, g_forceCamera, "1");
		else if(!IsFakeClient(client))
			SendConVarValue(client, g_forceCamera, "0");
	}
	
	if (!IsValidEntity(client) || IsPlayerAlive(client))
		return;
	
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll<0) 
		return;
	
	RemoveEdict(ragdoll);
}
*/

public Action:Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( doom_active[i] ) {
			doom_active[i] = false;
			if( IsValidClient(i) ) {
				SetEntityRenderColor(i, 255,255,255 );
			}
		}
	}

}
