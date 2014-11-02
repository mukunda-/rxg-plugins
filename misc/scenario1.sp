
#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "SCENARIO1",
	author = "mukunda",
	description = "SCENARIO1",
	version = "1.0.0",
	url = "www.mukunda.com"
};

enum {
	SOUND_SIREN,
};

new String:soundlist[][] = {
	"*rxgscenario1/siren.mp3"
};

#define HEIGHT_TO_SUBLEVEL1 560.0

new Float:oldtime;

new UserMsg:g_FadeUserMsgId;

new Float:wobble0[3] = {4.0,4.0,3.0};
new Float:wobble1[3] = {2.4,244.0,35.0};

new gamestate;

// INITIALWOBBLE
new Float:initialwobbletime;

// state1 - sinking 1 ----------

new Float:outside1_origin[3];
new Float:outside1_scroll;

// state2 - scroller 1
new Float:scroller1_origin[3];
new Float:scroller1_pos;


enum {
	MAPENT_OUTSIDE1,
	MAPENT_SHAKE1,
	MAPENT_SCROLLER1,
	MAPENT_SCROLLERLIGHT,
	MAPENT_SCROLLERLIGHTFOCUS,
	MAPENT_RAIDSIREN,
	MAPENT_TOTAL
};

enum {
	GAMESTATE_IDLE,
	GAMESTATE_INITIALWOBBLE,
	GAMESTATE_SINKING1,
	GAMESTATE_DESCENT
};

new mapents[MAPENT_TOTAL];

new Handle:mapent_trie;

//-------------------------------------------------------------------------------------------------
ArgToInt( index ) {
	decl String:arg[32];
	GetCmdArg( index, arg,sizeof(arg) );
	return StringToInt(arg);
}

//-------------------------------------------------------------------------------------------------
Float:ArgToFloat( index ) {
	decl String:arg[32];
	GetCmdArg( index, arg,sizeof(arg) );
	return StringToFloat(arg);
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	HookEvent( "round_prestart", Event_RoundPreStart, EventHookMode_PostNoCopy );
	RegConsoleCmd( "sm_start", start );
	RegConsoleCmd( "test2", test2 );

	g_FadeUserMsgId = GetUserMessageId("Fade");

	mapent_trie = CreateTrie();
	
	SetTrieValue( mapent_trie, "outside1", MAPENT_OUTSIDE1 );
	SetTrieValue( mapent_trie, "shake1", MAPENT_SHAKE1 );
	SetTrieValue( mapent_trie, "scroller1", MAPENT_SCROLLER1 );
	SetTrieValue( mapent_trie, "scrollerlight2", MAPENT_SCROLLERLIGHT );
	SetTrieValue( mapent_trie, "scrollerlightfocus", MAPENT_SCROLLERLIGHTFOCUS );
	SetTrieValue( mapent_trie, "raidsiren", MAPENT_RAIDSIREN );
}
//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	
	OnRoundStart();
	GetEntPropVector( mapents[MAPENT_OUTSIDE1], Prop_Data, "m_vecAbsOrigin", outside1_origin );
	GetEntPropVector( mapents[MAPENT_SCROLLER1], Prop_Data, "m_vecAbsOrigin", scroller1_origin );

	for( new i = 0; i < sizeof(soundlist); i++ ) {
		decl String:sound[128];
		Format( sound, sizeof(sound), "sound/%s", soundlist[i][1] );
		AddFileToDownloadsTable( sound );
		PrecacheSound( soundlist[i] );
	}
}

//-------------------------------------------------------------------------------------------------
StartShake( ent, Float:amp = 4.0, Float:duration = 1.0, Float:frequency = 2.5 ) {
	StopShake( ent );
	decl String:value[32];
	Format( value, sizeof(value), "%f", amp );
	SetVariantString( value );
	AcceptEntityInput( ent, "Amplitude" );

	Format( value, sizeof(value), "%f", duration );
	
	DispatchKeyValue( ent, "duration", value );//( ent, "Duration" );

	Format( value, sizeof(value), "%f", frequency );
	SetVariantString( value );
	AcceptEntityInput( ent, "Frequency" );

	AcceptEntityInput( ent, "StartShake" );
}

//-------------------------------------------------------------------------------------------------
StopShake( ent ) {
	AcceptEntityInput( ent, "StopShake" );
}

//-------------------------------------------------------------------------------------------------
public Action:start( client, args ) {
	gamestate = GAMESTATE_INITIALWOBBLE;
	
	initialwobbletime = 0.0;
	outside1_scroll = 0.0;
	scroller1_pos = 0.0;
	TeleportScrollerThing(false);
	StartShake( mapents[MAPENT_SHAKE1], wobble0[0], wobble0[1], wobble0[2] );

	decl Float:pos[3];
	GetEntPropVector( mapents[MAPENT_RAIDSIREN], Prop_Data, "m_vecAbsOrigin", pos );
	EmitAmbientSound( soundlist[SOUND_SIREN], pos, _, SNDLEVEL_RAIDSIREN );
	EmitAmbientSound( soundlist[SOUND_SIREN], pos, _, SNDLEVEL_RAIDSIREN );
	EmitAmbientSound( soundlist[SOUND_SIREN], pos, _, SNDLEVEL_RAIDSIREN );
	EmitAmbientSound( soundlist[SOUND_SIREN], pos, _, SNDLEVEL_RAIDSIREN );
	EmitAmbientSound( soundlist[SOUND_SIREN], pos, _, SNDLEVEL_RAIDSIREN );
	/*EmitSoundToAll( soundlist[SOUND_SIREN], mapents[MAPENT_RAIDSIREN], _, SNDLEVEL_RAIDSIREN );
	EmitSoundToAll( soundlist[SOUND_SIREN], mapents[MAPENT_RAIDSIREN], _, SNDLEVEL_RAIDSIREN );
	EmitSoundToAll( soundlist[SOUND_SIREN], mapents[MAPENT_RAIDSIREN], _, SNDLEVEL_RAIDSIREN );
	EmitSoundToAll( soundlist[SOUND_SIREN], mapents[MAPENT_RAIDSIREN], _, SNDLEVEL_RAIDSIREN );
	EmitSoundToAll( soundlist[SOUND_SIREN], mapents[MAPENT_RAIDSIREN], _, SNDLEVEL_RAIDSIREN );*/

	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:test2( client, args ) {
	StopShake( mapents[MAPENT_SHAKE1] );
	StartShake( mapents[MAPENT_SHAKE1], ArgToFloat(1), ArgToFloat(2), ArgToFloat(3) );
	return Plugin_Handled;
}


//-------------------------------------------------------------------------------------------------
public OnRoundStart() {
	gamestate = 0;
	
	SearchEntities();
}

//-------------------------------------------------------------------------------------------------
public Event_RoundPreStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	TeleportEntity( mapents[MAPENT_OUTSIDE1], outside1_origin, NULL_VECTOR, NULL_VECTOR );
	TeleportEntity( mapents[MAPENT_SCROLLER1], scroller1_origin, NULL_VECTOR, NULL_VECTOR );
}

//-------------------------------------------------------------------------------------------------
SearchEntities() {
	for( new i = MaxClients+1; i < GetMaxEntities(); i++ ) {
		decl String:name[64];
		if( !IsValidEntity(i) ) continue;
		GetEntPropString( i, Prop_Data, "m_iName", name, sizeof(name) );
		if( name[0] == 0 ) continue;
		new index;
		if( !GetTrieValue( mapent_trie, name, index ) ) continue;
		
		mapents[index] = i;
	}
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	OnRoundStart();
}

TeleportPlayersLevel2() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		
		decl Float:pos[3];
		GetEntPropVector( i, Prop_Data, "m_vecAbsOrigin", pos );
		pos[2] -= HEIGHT_TO_SUBLEVEL1;
		TeleportEntity( i, pos, NULL_VECTOR, NULL_VECTOR );

	}
}

TeleportScrollerThing( bool:light=true) {
	
		decl Float:vec[3];
		for( new i = 0; i < 3; i++ )
			vec[i] = scroller1_origin[i];
		vec[2] += scroller1_pos + 460.0;

		decl Float:vec1[3];
		decl Float:vec2[3];
		GetEntPropVector( mapents[MAPENT_SCROLLERLIGHTFOCUS], Prop_Data, "m_vecAbsOrigin", vec2 );
		GetEntPropVector( mapents[MAPENT_SCROLLERLIGHT], Prop_Data, "m_vecAbsOrigin", vec1 );
		for(new i = 0; i < 3; i++ )
			vec2[i] -= vec1[i];
		GetVectorAngles(vec2,vec1);
		vec1[0] =0.0;
		if( light ) {
			vec1[0] = ((scroller1_pos - 144.0) / (144.0*2.0)) * 240.0;
		} else {
			vec1[0] = -90.0;
		}

		SetEntityRenderColor(mapents[MAPENT_SCROLLERLIGHT],255,0,0,255);
		TeleportEntity( mapents[MAPENT_SCROLLER1], vec, NULL_VECTOR, NULL_VECTOR );
		TeleportEntity( mapents[MAPENT_SCROLLERLIGHT], NULL_VECTOR, vec1,NULL_VECTOR );
}

//-------------------------------------------------------------------------------------------------
public OnGameFrame() {
	new Float:time = GetGameTime();
	new Float:timepassed = time - oldtime;
	oldtime = time;

	switch( gamestate ) {
		case GAMESTATE_INITIALWOBBLE:
		{
			initialwobbletime += timepassed;
			if( initialwobbletime >= 12.0 ) {
				gamestate = GAMESTATE_SINKING1;
				StartShake( mapents[MAPENT_SHAKE1], wobble1[0], wobble1[1], wobble1[2] );
			}
		}
		case GAMESTATE_SINKING1:
		{
			outside1_scroll += 0.2;
			if( outside1_scroll >= 150 ) {
				StopShake(mapents[MAPENT_SHAKE1]);
				StartShake( mapents[MAPENT_SHAKE1], 18.0, 50.0, 15.0 );
				TeleportPlayersLevel2();
				ScreenFlash();
				gamestate = GAMESTATE_DESCENT;
				return;
			}
			decl Float:vec[3];
			for( new i =0; i < 3;i++ )
				vec[i] = outside1_origin[i];
			vec[2] += outside1_scroll;

			TeleportEntity( mapents[MAPENT_OUTSIDE1], vec, NULL_VECTOR, NULL_VECTOR );
		}
		case GAMESTATE_DESCENT:
		{
			scroller1_pos += 25.0;
			if( scroller1_pos >= 144*2 ) scroller1_pos -= 144*2;
			TeleportScrollerThing();
		}
	}
}

//-------------------------------------------------------------------------------------------------
ScreenFlash() {
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			clients[count] = i;
			count++;
		}
	}
	new duration2 = 500;
	new holdtime = 20;

	new flags = 0x10|1;
	//new color[4] = { 255,60,10, 192};
	new color[4] = { 255,255,255, 255};
	new Handle:message = StartMessageEx( g_FadeUserMsgId, clients, count );
	PbSetInt(message, "duration", duration2);
	PbSetInt(message, "hold_time", holdtime);
	PbSetInt(message, "flags", flags);
	PbSetColor(message, "clr", color);
	EndMessage();
}
