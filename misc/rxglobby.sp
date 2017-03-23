
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma semicolon 1

// 1.0.2 2:34 PM 7/14/2013
//  new maps
//  custom map command
// 1.0.1 1:39 PM 5/19/2013
//  bugfixes
//  nospecs
//  minplayers
//  etc!

public Plugin:myinfo = {
	name="rxglobby",
	author="mukunda",
	description="rxg scrim lobby scripting",
	version="1.0.2",
	url="www.mukunda.com"
};

new Handle:sm_rxglobby_map;
new Handle:sm_rxglobby_minplayers;
new Handle:sm_rxglobby_hostprefix;
new Handle:sm_rxglobby_nospecs;
new bool:c_rxglobby_nospecs;
new String:c_rxglobby_hostprefix[64];

new Float:round_start_time;
new Float:c_round_time;
new bool:round_terminated;

#define RESPAWN_TIME 2.0

#define HIDEHUD ((1<<12))

new Float:death_time[MAXPLAYERS+1];

new player_zone[MAXPLAYERS+1];

// radio ------------------------------------------------------------------------------------------

new radio1;
new Handle:radio_loop_timer;

#define RADIO_SOUND "*officeradio/harlmeshake.mp3"
#define RADIO_SOUND_DL "sound/officeradio/harlmeshake.mp3"
#define RADIO_DURATION 43.19	// harlmeshake

// weapons range-----------------------------------------------------------------------------------

//new button_weaponsrange;
//new bool:wr_active;
//new Float:wr_start_time;
//new Handle:wr_targets;
//new wr_tick;
//new wr_target_spawndelay;
//new wr_alive_targets;

// practice range ---------------------------------------------------------------------------------

new pr_team[MAXPLAYERS+1];

new bool:hooked;

// departure --------------------------------------------------------------------------------------

new dep_team[MAXPLAYERS+1];
new mapscreen_picture;
new selected_map;

new dep_team_count[2];

new ready_team[2];
new ready_buttons[2];

new last_player_ready_pressed[2];

new Handle:countdown_timer = INVALID_HANDLE;
new countdown;

new match_locked;
new String:match_player_ids[10][32]; // steam IDs first 5 start as T, second 5 start as CT

new String:custom_map_name[64];

#define READY_SOUND "buttons/button3.wav"
#define READY_SOUND_RESET "buttons/button10.wav"
#define COUNTDOWN_SOUND "ui/beep07.wav"

#define SCREAM_SOUND "*rxg_lobby/scream4.mp3"

#define SCARE_MATERIAL "rxg_lobby/scare.vmt"

// scare ------------------------------------------------------------------------------------------

new scare_active;
new scare_userid;
new Float:scare_time;
new scare_used;
new scare_sprite;

new UserMsg:g_FadeUserMsgId;

//-------------------------------------------------------------------------------------------------

new last_hostname_state;
new last_hostname_arg1;
new last_hostname_arg2;

enum {
	HOSTNAME_WAITING_FOR_PLAYERS,
	HOSTNAME_FULL,
	HOSTNAME_INPROGRESS_FULL,
	HOSTNAME_INPROGRESS_SLOTS
};


//-------------------------------------------------------------------------------------------------
// map list, textures for screen must be in this order
enum {
	MAP_DUST2,
	MAP_DUST,
	MAP_INFERNO,
	MAP_TRAIN,
	MAP_OFFICE,
	MAP_AZTEC,
	MAP_NUKE,
	MAP_MIRAGE,
	MAP_MILITIA,
	MAP_VERTIGO,
	MAP_ITALY,
	MAP_CUSTOM,
	MAP_TOTAL
};

//-------------------------------------------------------------------------------------------------
new const String:map_names[][] = {
	"de_dust2",
	"de_dust",
	"de_inferno",
	"de_train",
	"cs_office",
	"de_aztec",
	"de_nuke",
	"de_mirage",
	"cs_militia",
	"de_vertigo",
	"cs_italy",
	"(custom)"
};

//-------------------------------------------------------------------------------------------------
enum {
	ZONE_OTHER,
	ZONE_PRACTICE_ENTRANCE1,
	ZONE_PRACTICE_ENTRANCE2,
	ZONE_PRACTICE,
	ZONE_TEAM_A,
	ZONE_TEAM_B
};

//-------------------------------------------------------------------------------------------------
new Float:zone_list[] = {
	0.0, 0.0, 0.0, 0.0,
	-435.0,  -750.0,  -97.0,  -640.0, // practice entrance 1
	-434.0, -1938.0, -114.0, -1812.0, // practice entrance 2
	-568.0, -1936.0,  112.0, -641.0, // practice zone (LIVE FIRE ZONE)
	-159.0,   128.0,  334.0,   310.0, // team a
	-160.0,  -310.0,  333.0,  -128.0 // team b
};

// match state ------------------------------------------------------------------------------------

new match_halftime_passed;
new match_client_team[MAXPLAYERS+1]; // team which clients are supposed to be on

new client_lobby_vote[MAXPLAYERS+1];
new lobby_votes_total, lobby_votes_required, lobby_votes_clients;
new bool:returning_to_lobby;

#define TEAM_WAIT_TIME 60.0

//-------------------------------------------------------------------------------------------------
public CacheConVar( Handle:convar, const String:oldValue[], const String:newValue[] ) {

	if( convar == sm_rxglobby_hostprefix ) {
		GetConVarString( sm_rxglobby_hostprefix, c_rxglobby_hostprefix, sizeof(c_rxglobby_hostprefix) );
	} else if( convar == sm_rxglobby_nospecs ) {
		c_rxglobby_nospecs = GetConVarBool( sm_rxglobby_nospecs );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	//wr_targets = CreateArray(8);
	RegConsoleCmd( "jointeam", Command_jointeam );
	RegConsoleCmd( "sm_cointoss", Command_cointoss );
	RegConsoleCmd( "scrim_map", Command_map );
	RegConsoleCmd( "say" ,Command_say );
	RegConsoleCmd( "say_team" ,Command_say );
	RegServerCmd( "rxg_debug1", debug1 );
	g_FadeUserMsgId = GetUserMessageId("Fade");
	
	sm_rxglobby_map = CreateConVar( "sm_rxglobby_map", "rxglobby", "rxglobby map name", FCVAR_PLUGIN );
	sm_rxglobby_hostprefix = CreateConVar( "sm_rxglobby_hostprefix", " rxg | SCRIMS | ", "prefix for hostname", FCVAR_PLUGIN );
	sm_rxglobby_minplayers = CreateConVar( "sm_rxglobby_minplayers", "5", "requires this many people on each team for ready buttons to work", FCVAR_PLUGIN );
	sm_rxglobby_nospecs = CreateConVar( "sm_rxglobby_nospecs", "0", "dont allow spectating and kick non participants from live games", FCVAR_PLUGIN );
	c_rxglobby_nospecs = GetConVarBool( sm_rxglobby_nospecs );
	c_round_time = GetConVarFloat( FindConVar("mp_roundtime_hostage") );
	GetConVarString( sm_rxglobby_hostprefix, c_rxglobby_hostprefix, sizeof(c_rxglobby_hostprefix) );
	HookConVarChange( sm_rxglobby_hostprefix, CacheConVar );
	HookConVarChange( sm_rxglobby_nospecs, CacheConVar );
	
	HookEvent( "announce_phase_end", Event_Halftime );
	HookEvent( "player_disconnect", Event_PlayerDisconnect );
	
	hooked = false;
}

//-------------------------------------------------------------------------------------------------
ChangeMap( newmap ) {
	newmap = newmap + MAP_TOTAL;
	newmap = newmap % MAP_TOTAL;
	selected_map = newmap;
	SetEntProp( mapscreen_picture, Prop_Send, "m_iTextureFrameIndex", selected_map );
	ResetReadyState();
}

//-------------------------------------------------------------------------------------------------
public OnButtonMapScreenPrev( const String:output[], caller, activator, Float:delay ) {
	ChangeMap( selected_map-1 );
	if( selected_map == MAP_CUSTOM ) ChangeMap( selected_map-1 );
}

//-------------------------------------------------------------------------------------------------
public OnButtonMapScreenNext( const String:output[], caller, activator, Float:delay ) {
	ChangeMap( selected_map+1 );
	if( selected_map == MAP_CUSTOM ) ChangeMap( selected_map+1 );
}

//-------------------------------------------------------------------------------------------------
CountTeamPlayers() {
	dep_team_count[0] = 0;
	dep_team_count[1] = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		
		if( dep_team[i] == 1 ) {
			dep_team_count[0]++;
		} else if( dep_team[i] == 2 ) {
			dep_team_count[1]++;
		}
	}
}

//-------------------------------------------------------------------------------------------------
StartMatch() {

	CountTeamPlayers();
	if(dep_team_count[0] > 5 || dep_team_count[1] > 5 ) {
		ResetReadyState();
		return;
	}
	
	new team_min = GetConVarInt(sm_rxglobby_minplayers);
	if( dep_team_count[0] < team_min || dep_team_count[1] < team_min ) {
		// ???
		ResetReadyState();
		
		
		return;
	}
	
	new write_1,write_2;
	
	for( new i = 0; i < 10; i++ ) {
		match_player_ids[i][0] = 0;
	}
	
	match_locked = true;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		 
		if( dep_team[i] == 1 ) {
			if(write_1<5)
				GetClientAuthString( i, match_player_ids[write_1++], sizeof(match_player_ids[]) );
		} else if( dep_team[i] == 2 ) {
			if( write_2<5)
				GetClientAuthString( i, match_player_ids[5+write_2++], sizeof(match_player_ids[]) );
		}
	}

	if( selected_map != MAP_CUSTOM ) {
		ForceChangeLevel( map_names[selected_map], "Starting Scrim" );
	} else {
		ForceChangeLevel( custom_map_name, "Starting Scrim" );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:TimerCountdown( Handle:timer ) {
	countdown--;
	if( countdown <= 5 ) {
		if( countdown == 0 ){
			// start map
			StartMatch();
			countdown_timer = INVALID_HANDLE;
			return Plugin_Stop;
		} else {
			EmitSoundToAll( COUNTDOWN_SOUND );
			PrintCenterTextAll( "Game begins in %d seconds...", countdown );
		}
	}
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
AddRoundTime( float seconds ) {
	float start = GameRules_GetPropFloat( "m_fRoundStartTime" );
	start += seconds;
	float gt = GetGameTime();
	if( start > (gt - 0.1) ) start = gt - 0.1;
	GameRules_SetPropFloat( "m_fRoundStartTime", start );
}

//-------------------------------------------------------------------------------------------------
StartCountdown() {
	float start = GameRules_GetPropFloat( "m_fRoundStartTime" );
	float time_left = c_round_time * 60.0 - ( GetGameTime() - start );
	if( time_left < 60.0 ) {
		AddRoundTime( 60.0 - time_left );
	}
	
	PrintToChatAll( "\x01\x0B\x04Both teams are ready." );
	PrintToChatAll( "\x01\x0B\x04Game begins in 10 seconds..." );
	
	if( dep_team_count[0] < 5 ) {
		PrintToChatAll( "\x01\x0B\x09Warning: CT only has %d human player%s.", dep_team_count[0], dep_team_count[0] != 1 ? "s":"" );
	}
	
	if( dep_team_count[1] < 5 ) {
		PrintToChatAll( "\x01\x0B\x09Warning: Terrorist only has %d human player%s.", dep_team_count[1],dep_team_count[1] != 1 ? "s":"" );
	}
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( dep_team[i] == 0 ) {
			PrintToChat( i, "\x01\x0B\x09Warning: You are not assigned a team. Get to the departure zone if you want to play!" );
		}
	}
	
	countdown_timer = CreateTimer( 1.0, TimerCountdown, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT );
	countdown = 10;
}

//-------------------------------------------------------------------------------------------------
StopCountdown() {
	if( countdown_timer ) {
		PrintToChatAll( "\x01\x0B\x08The countdown was cancelled." );
		KillTimer( countdown_timer );
		countdown_timer = INVALID_HANDLE;
	}
}

//-------------------------------------------------------------------------------------------------
SetReadyState( index ) {
	if( ready_team[index] ) {
		return;
	}
	
	// check conditions
	
	
	CountTeamPlayers();
	if( dep_team_count[index] != 5 ) {
		if( IsClientInGame(last_player_ready_pressed[index]) ){
		
		
			new team_min = GetConVarInt(sm_rxglobby_minplayers);
			
			if( dep_team_count[index] > 5 ) {
				
				PrintToChat( last_player_ready_pressed[index], "\x01\x0B\x09More than 5 players on team." );
				ResetReadyButton(index);
				return;
				
			} else if( dep_team_count[index] < team_min ) {
			
				
				
				if( team_min < 5 ) {
					PrintToChat( last_player_ready_pressed[index], "\x01\x0B\x09Only %d/5 players on team. Need at least %d.", dep_team_count[index], team_min );
				} else {
					PrintToChat( last_player_ready_pressed[index], "\x01\x0B\x09Only %d/5 players on team.", dep_team_count[index] );
				}
				
				ResetReadyButton(index);
				return;
			}
		}
		
	}
	ready_team[index] = 1;
	EmitSoundToAll( READY_SOUND, ready_buttons[index] );
	SetEntProp( ready_buttons[index], Prop_Send, "m_iTextureFrameIndex", 1 );
	
	if(ready_team[0] && ready_team[1] ) {
		StartCountdown();
	}
}

//-------------------------------------------------------------------------------------------------
ResetReadyButton(index) {
	
	AcceptEntityInput( ready_buttons[index], "PressOut" );
	EmitSoundToAll( READY_SOUND_RESET, ready_buttons[index] );
	SetEntProp( ready_buttons[index], Prop_Send, "m_iTextureFrameIndex", 0 );
}

//-------------------------------------------------------------------------------------------------
ResetReadyState() {
	if( match_locked ) return;
	for( new i = 0; i < 2; i++ ) {
		if( ready_team[i] ) {
			ready_team[i] = 0;
			ResetReadyButton(i);
		}
	}
	StopCountdown();
}

//-------------------------------------------------------------------------------------------------
public OnButtonReadyTeam1( const String:output[], caller, activator, Float:delay ) {
	last_player_ready_pressed[0] = activator;
	SetReadyState( 0 );
}

//-------------------------------------------------------------------------------------------------
public OnButtonReadyTeam2( const String:output[], caller, activator, Float:delay ) {
	last_player_ready_pressed[1] = activator;
	SetReadyState( 1 );
}

//-------------------------------------------------------------------------------------------------
FindButtons() {
	new ent = -1;
	decl String:name[64];
	
	while( (ent = FindEntityByClassname( ent, "func_button" )) != -1 ) {
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof(name) );
		
		
		// hook mapscreen buttons
		if( StrEqual( name, "mapscreen_prev" ) ) {
			HookSingleEntityOutput( ent, "OnPressed", OnButtonMapScreenPrev );
		} else if( StrEqual( name, "mapscreen_next" ) ) {
			HookSingleEntityOutput( ent, "OnPressed", OnButtonMapScreenNext );
		} else
		
		// ready buttons
		if( StrEqual( name, "ready_team1" ) ) {
			ready_buttons[0] = ent;
			HookSingleEntityOutput( ent, "OnIn", OnButtonReadyTeam1 );
		} else if( StrEqual( name, "ready_team2" ) ) {
			ready_buttons[1] = ent;
			HookSingleEntityOutput( ent, "OnIn", OnButtonReadyTeam2 );
		} else
		
		// weapons range
		if( StrEqual( name, "button_weaponsrange" ) ) {
			//button_weaponsrange = ent;
			HookSingleEntityOutput( ent, "OnPressed", OnButtonWeaponsRange );
		}
	}
	
	ent = -1;
	while( (ent = FindEntityByClassname( ent, "prop_physics_override" )) != -1 ) {
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof(name) );
		
		// hook mapscreen picture
		if( StrEqual( name, "mapscreen_picture" ) ) {
			mapscreen_picture = ent;
		}
	}
	
	ent = -1;
	while( (ent = FindEntityByClassname( ent, "prop_physics_multiplayer" )) != -1 ) {
		GetEntPropString( ent, Prop_Data, "m_iName", name, sizeof(name) );
		
		// hook mapscreen picture
		if( StrEqual( name, "radio1" ) ) {
			radio1 = ent;
			HookSingleEntityOutput(radio1, "OnPlayerUse", StartSoundEvent, true );
			HookSingleEntityOutput(radio1, "OnBreak", StopSoundEvent, true );

		}
	}
}

//-------------------------------------------------------------------------------------------------
AddHooks() {
	if( hooked ) return;
	hooked = true;
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent( "player_death", Event_PlayerDeath );
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	HookEvent( "hostage_follows", Event_HostageFollows );
	
	BlockFFmessages();
	
	SetConVarInt( FindConVar( "mp_ignore_round_win_conditions" ), 1 );
	
	HookExistingClients();
}

//-------------------------------------------------------------------------------------------------
RemoveHooks() {
	if( !hooked ) return;
	hooked = false;
	UnhookEvent( "player_spawn", Event_PlayerSpawn );
	UnhookEvent( "player_death", Event_PlayerDeath );
	UnhookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	UnhookEvent( "hostage_follows", Event_HostageFollows );
	
	UnblockFFmessages();
	
	SetConVarInt( FindConVar( "mp_ignore_round_win_conditions" ), 0 );
}

//-------------------------------------------------------------------------------------------------
OnRxgLobbyLoaded() {
	match_locked = false;
	for( new i = 1; i <= MaxClients; i++ ) {
		player_zone[i] = 0;
		dep_team[i] = 0;
		death_time[i] = 0.0;
		
	}
	AddHooks();
	
	CreateTimer( 0.1, Timer_Update, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT );
	
	Event_RoundStart( INVALID_HANDLE, "", false ); // catch first round hooks
	
	
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	decl String:map[64];
	GetCurrentMap( map, sizeof(map) );
	if( strncmp( "rxglobby", map, 8 ) == 0 ) {
		ServerCommand( "exec sourcemod/rxglobby.cfg" );
		
		PrecacheSound( READY_SOUND );
		PrecacheSound( READY_SOUND_RESET );
		PrecacheSound( COUNTDOWN_SOUND );
		PrecacheSound( SCREAM_SOUND );
		
		PrecacheModel( SCARE_MATERIAL );
		
		AddFileToDownloadsTable( RADIO_SOUND_DL );
		PrecacheSound( RADIO_SOUND );
	}
	returning_to_lobby = false;
	match_halftime_passed = false;
	
	CreateTimer( 10.0, TimerUpdateHostname, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT );
}

//-------------------------------------------------------------------------------------------------
public OnConfigsExecuted() {
	decl String:map[64];
	GetCurrentMap( map, sizeof(map) );
	if( strncmp( "rxglobby", map, 8, false ) == 0 ) {
		//ServerCommand( "exec rxglobby.cfg" );
		OnRxgLobbyLoaded();
	}
	
	
}

//-------------------------------------------------------------------------------------------------
public OnMapEnd() {
	RemoveHooks();
}

//-------------------------------------------------------------------------------------------------
PlayerInZone( client, zone ) {
	new Float:pos[3];
	GetClientAbsOrigin( client, pos );
	
	return ( pos[0] >= zone_list[zone*4] && pos[1] >= zone_list[zone*4+1] && pos[0] < zone_list[zone*4+2] && pos[1] < zone_list[zone*4+3] );
}

//-------------------------------------------------------------------------------------------------
EnterPracticeZone( client, index ) {
	pr_team[client] = index;
	player_zone[client] = ZONE_PRACTICE;
	SetEntityRenderColor( client, index==0?255:0, 0, index==1? 255:0 );
	PrintCenterText( client, "Entering Live Fire Zone" );
}

//-------------------------------------------------------------------------------------------------
LeavePracticeZone( client ) {
	player_zone[client] = ZONE_OTHER;
	SetEntityRenderColor( client, 255,255,255 );
	PrintCenterText( client, "Leaving Live Fire Zone" );
	SetEntityHealth( client, 100 );
}

//-------------------------------------------------------------------------------------------------
EnterTeamZone( client, index ) {
	if( match_locked ) return;
	
	dep_team[client] = index+1;
	player_zone[client] = index ==0 ? ZONE_TEAM_A : ZONE_TEAM_B;
	PrintToChatAll( "\x01\x0B\x01%N has joined %s\x01.", client, index == 0 ? "\x03Counter-Terrorist" : "\x09Terrorist" );
	ResetReadyState();
}

//-------------------------------------------------------------------------------------------------
LeaveTeamZone( client ) {
	
	if( match_locked ) return;
	
	if( dep_team[client] ) {
		PrintToChatAll( "\x01\x0B\x01%N has left %s\x01.", client, dep_team[client] == 1 ? "\x03Counter-Terrorist" : "\x09Terrorist" );
		player_zone[client] = ZONE_OTHER;
		dep_team[client] = 0;
	}
	ResetReadyState();
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_Update( Handle:timer ) {
	if( !hooked ) return Plugin_Stop;
	new Float:time = GetGameTime();
	
	for( new client = 1; client <= MaxClients; client++ ) {
		if( !IsClientInGame(client) ) continue;
		if( IsFakeClient(client) ) continue;
		if( GetClientTeam(client) < 2 ) continue;
		
		// respawn
		if( !IsPlayerAlive(client) ) {
			new Float:dtime = time - death_time[client];
			if( dtime > RESPAWN_TIME ) {
				CS_RespawnPlayer( client ); 
			}
			continue;
		}
		
		if( player_zone[client] == ZONE_OTHER ) {
			
			if( PlayerInZone( client, ZONE_PRACTICE_ENTRANCE1 ) ) {
				EnterPracticeZone( client, 0 );
			} else if( PlayerInZone( client, ZONE_PRACTICE_ENTRANCE2 ) ) {
				EnterPracticeZone( client, 1 );
			} else if( PlayerInZone( client, ZONE_TEAM_A ) ) {
				
				EnterTeamZone( client, 0 );
			} else if( PlayerInZone( client, ZONE_TEAM_B ) ) {
				EnterTeamZone( client, 1 );
			}
		} else if( player_zone[client] == ZONE_PRACTICE ) {
			if( !PlayerInZone( client, ZONE_PRACTICE ) ) {
				LeavePracticeZone( client );
			}
		} else if( player_zone[client] == ZONE_TEAM_A ) {
			if( !PlayerInZone( client, ZONE_TEAM_A ) ) {
				LeaveTeamZone( client );
			}
		} else if( player_zone[client] == ZONE_TEAM_B ) {
			if( !PlayerInZone( client, ZONE_TEAM_B ) ) {
				LeaveTeamZone( client );
			}
		}
		
		if( GetGameTime() - round_start_time > 60.0 * 10.0 && !round_terminated ) {
			CS_TerminateRound( 5.0, CSRoundEnd_Draw );
			round_terminated =true;
		}
	}
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_cointoss( client, args ) {
	new result = GetRandomInt(0,1);
	PrintToChatAll( "%N flips a coin...%s", client, result ? "Heads!" : "Tails!" );
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_map( client, args ) {
	if( !IsPlayerAlive(client) ) {
		ReplyToCommand( client, "You are not alive." );
		return Plugin_Handled;
	}
	
	if( dep_team[client] != 0 ) {
		ReplyToCommand( client, "You cannot use that command in this zone." );
		return Plugin_Handled;
	}
	
	
	GetCmdArg( 1, custom_map_name, sizeof custom_map_name );
	
	PrintToChatAll( "\x01\x0B\x09%N selected custom map: %s", client, custom_map_name );
	
	ChangeMap( MAP_CUSTOM );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:PlayerSpawnDelayed( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return;
	
	SetEntProp( client, Prop_Send, "m_iHideHUD", HIDEHUD );
	
	// give moneys
	SetEntProp( client, Prop_Send, "m_iAccount", 15000 );
	
	death_time[client] = GetGameTime();
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !hooked ) SetFailState( "PlayerSpawn called while not hooked" );
	
	new userid = GetEventInt( event, "userid" );
	if( userid == 0 ) return;
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return;
	CreateTimer( 0.1, PlayerSpawnDelayed, userid, TIMER_FLAG_NO_MAPCHANGE );
	
	// if player dies in practice zone, respawn nearby
	if( player_zone[client] == ZONE_PRACTICE ){
		SetEntityRenderColor( client, 255,255,255 );
		if( pr_team[client] == 0 ) {
			new Float:pos[3] = {-75.227623, -482.942261, 0.031250};
			new Float:ang[3] = {0.000000, -133.067993, 0.000000};
			new Float:vel[3];
			TeleportEntity( client, pos,ang,vel );
		} else {
			new Float:pos[3] = {-125.256409, -2064.427734 ,0.020500};
			new Float:ang[3] = {0.000000 ,136.649811 ,0.000000};
			new Float:vel[3];
			TeleportEntity( client, pos,ang,vel );
		}
	}
	
	death_time[client] = GetGameTime();
	player_zone[client] = ZONE_OTHER;
	dep_team[client] = 0;
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !hooked ) SetFailState( "PlayerDeath called while not hooked" );
	new userid = GetEventInt( event, "userid" );
	if( userid == 0 ) return;
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return;
	
	death_time[client] = GetGameTime();
	LeaveTeamZone(client);
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( !hooked ) SetFailState( "RoundStart called while not hooked" );
	FindButtons();
	selected_map = 0;
	scare_used = 0;
	
	if( radio_loop_timer != INVALID_HANDLE ) {
		KillTimer( radio_loop_timer );
		radio_loop_timer = INVALID_HANDLE;
	}
	
	round_start_time = GetGameTime();
	round_terminated=false;
}

//-------------------------------------------------------------------------------------------------
public Event_HostageFollows( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	if( client == 0 ) return;
	if( scare_used ) return;
	scare_used = true;
	
	ScarePlayer(client);
}


//-------------------------------------------------------------------------------------------------
BlockFFmessages() {
	HookUserMessage(GetUserMessageId("TextMsg"), Hook_TextMsg, true);
	HookUserMessage(GetUserMessageId("HintText"), Hook_HintText, true);
}

//-------------------------------------------------------------------------------------------------
UnblockFFmessages() {
	UnhookUserMessage(GetUserMessageId("TextMsg"), Hook_TextMsg, true);
	UnhookUserMessage(GetUserMessageId("HintText"), Hook_HintText, true);
}

//-------------------------------------------------------------------------------------------------
public Action:Hook_TextMsg(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	/* Block team-attack messages from being shown to players. */ 
	decl String:message[256];
	PbReadString( bf, "params", message, sizeof(message), 0 );
	
	if (StrContains(message, "teammate_attack") != -1)
		return Plugin_Handled;
	
	if (StrContains(message, "Killed_Teammate") != -1)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public Action:Hook_HintText(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	/* Block team-attack "tutorial" messages from being shown to players. */ 
	decl String:message[256];
	PbReadString(bf, "text", message, sizeof(message));
	
	if (StrContains(message, "spotted_a_friend") != -1)
		return Plugin_Handled;

	if (StrContains(message, "careful_around_teammates") != -1)
		return Plugin_Handled;
	
	if (StrContains(message, "try_not_to_injure_teammates") != -1)
		return Plugin_Handled;
		
	return Plugin_Continue;
}


//-------------------------------------------------------------------------------------------------
// stop damage outside of practice range

HookExistingClients() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			if( IsFakeClient(i) ) continue;
			SDKHook( i, SDKHook_OnTakeDamage, OnTakeDamage );
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
		Float:damageForce[3], Float:damagePosition[3]) {

	if(!(attacker > 0 && attacker <= MaxClients && victim > 0 && victim <= MaxClients)) {
		return Plugin_Continue;
	}
	/*
	if( damage <= 0 || weapon <= 0 ) {
		return Plugin_Continue;
	}*/
	
	if( attacker == victim ) return Plugin_Continue;
	 
	if( player_zone[attacker] != ZONE_PRACTICE || player_zone[victim] != ZONE_PRACTICE ||
			pr_team[attacker] == pr_team[victim] ) {
		damage = 0.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public OnButtonWeaponsRange( const String:output[], caller, activator, Float:delay ) {
	PrintToChat( activator, "\x01\x0B\x09I'm sorry to be the one to tell you this, but the weapons range program isn't implemented yet." );
}

bool:SteamIDMatch( const String:a[], const String:b[] ) {
	if( strlen(a) < 9 || strlen(b) < 9 ) return false;
	return StrEqual( a[8], b[8] );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:OnClientPutInServerDelayed( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	if( !client ) return Plugin_Handled;
	
	if( !hooked ) {
		// in-match, set client team
		if( match_client_team[client] ) {
			if( GetClientTeam(client) != match_client_team[client] ) {
				ChangeClientTeam( client, match_client_team[client] );
			}
		} else {
			ChangeClientTeam( client, 1 ); // force spec (they should have been kicked if nospecs was set )
		}
	} else {
		// not in-match, set to CT 
		if( GetClientTeam(client) != 3 ) {
		
			ChangeClientTeam( client, 3 );
		}
	}
	
	
	death_time[client] = GetGameTime();
	
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	if( IsFakeClient(client) ) return;
	if( hooked ) {
		SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
	} else {
		decl String:auth[32];
		GetClientAuthString( client, auth, sizeof(auth) );
		match_client_team[client] = 0;
		for( new i = 0; i < 10; i++ ) {
			
			if( SteamIDMatch( auth, match_player_ids[i] ) )  {
				new t = (i >= 5) ? 1:0;
				match_client_team[client] = match_halftime_passed ? (2+t) : (3-t);
				
					
				break;
			}
		}
		if( match_client_team[client] == 0 ) {
			if( c_rxglobby_nospecs ) {
				KickClient( client, "Locked match in progress; try again later" );
			}
		}
	}
	client_lobby_vote[client] = 0;
	CreateTimer( 3.0, OnClientPutInServerDelayed, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}

//----------------------------------------------------------------------------------------------------------------------
public OnGameFrame() {
	if( !hooked ) return;

	UpdateScare();
	
///	WeaponsRange_Update();
	
}

//----------------------------------------------------------------------------------------------------------------------
ScreenFade( client, duration, hold, flags, r,g,b,a ) {
	new clients[2];
	clients[0] = client;

	new color[4];//
	color[0]= r;
	color[1] =g;
	color[2]=b;
	color[3] = a;
	new Handle:message = StartMessageEx(g_FadeUserMsgId, clients, 1);
	PbSetInt(message, "duration", duration);
	PbSetInt(message, "hold_time", hold);
	PbSetInt(message, "flags", flags);
	PbSetColor(message, "clr", color);
	EndMessage();
}

//----------------------------------------------------------------------------------------------------------------------
ScarePlayer( client ) {
	scare_userid = GetClientUserId(client);
	scare_time = GetGameTime();
	scare_active =true;
	
	SetEntityFlags( client, GetEntityFlags(client) | FL_FROZEN );
	
	//ScreenFade( client, 400, 0, 0x01|0x04, 255,0,0,255 );
	ScreenFade( client, 100, 0, 0x01, 255,0,0,255 );
	EmitSoundToClient( client, SCREAM_SOUND );
	SetEntProp( client, Prop_Send, "m_iHideHUD", 4 ); // hide hud
	
	new ent = CreateEntityByName( "env_sprite" );
	DispatchKeyValue( ent, "rendercolor", "255 255 255" );
	DispatchKeyValue( ent, "rendermode", "2" );
	DispatchKeyValue( ent, "renderamt", "255" );
	DispatchKeyValue( ent, "scale", "25.0" );
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );
	DispatchSpawn( ent );
	AcceptEntityInput( ent, "ShowSprite" );
	SetEntityModel( ent, SCARE_MATERIAL );
	
	new vm = GetEntPropEnt( client, Prop_Send, "m_hViewModel" );
	
	SetVariantString( "!activator" );
	AcceptEntityInput( ent, "SetParent", vm );
	
	new Float:pos[3];
	pos[0] = 7.0;
	pos[1] = 0.7;
	pos[2] = 1.0;
	
	new Float:ident[3];
	
	
	TeleportEntity( ent, pos, ident,ident );
	scare_sprite=ent;
}

//----------------------------------------------------------------------------------------------------------------------
UpdateScare() {
	if( !scare_active ) return;
	
	new Float:time = (GetGameTime()-scare_time);
	
	new client = GetClientOfUserId( scare_userid );
	if( !client ) {
		scare_active = false;
		return;
	}
	
	if( !IsPlayerAlive(client) ) {
		scare_active =false;
		if( scare_sprite ) {
			AcceptEntityInput(scare_sprite,"Kill" );
			scare_sprite=0;
		}
		SetEntProp( client, Prop_Send, "m_iHideHUD", HIDEHUD );
		SetEntityFlags( client, GetEntityFlags(client) & ~FL_FROZEN );
		return;
	}
	
	if( scare_sprite ) {
		SetEntPropFloat( scare_sprite, Prop_Send, "m_flSpriteScale", 25.0+ (100.0 * time / 2.0) );
		
		if( time > 0.25 ) {
			new alpha = RoundToFloor(255.0-((time-0.25) / 0.25) * 255.0);
			if( alpha < 0 ) {
				AcceptEntityInput(scare_sprite,"Kill" );
				scare_sprite=0;
				
				return;
			} else {
				SetEntityRenderColor( scare_sprite, 255,255,255, alpha );
			}
		}
	}
	
	if( time > 1.0 ) {
		if( scare_sprite ) {
			AcceptEntityInput(scare_sprite,"Kill" );
			scare_sprite=0;
		}
		SetEntProp( client, Prop_Send, "m_iHideHUD", HIDEHUD );
		SetEntityFlags( client, GetEntityFlags(client) & ~FL_FROZEN );
		scare_active=0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_jointeam( client, args ) {

	if( IsFakeClient(client) ) return Plugin_Continue;
	
	
	
	decl String:arg[32];
	GetCmdArg( 1, arg, sizeof(arg) );
	new team;
	if( StrEqual( arg, "ct", false ) || StrEqual( arg, "counter-terrorist", false ) || StrEqual( arg, "3" ) ) {
		team = 3;
	} else if( StrEqual( arg, "t", false ) || StrEqual( arg, "terrorist", false ) || StrEqual( arg, "2" ) ) {
		team = 2;
	} else {
		team = 1;
	}
	
	//PrintToChatAll( "TEST: %N, %d, %d, %d", client, team, match_client_team[client], c_rxglobby_nospecs );
	
	if( !hooked && c_rxglobby_nospecs ) {
		if( team != match_client_team[client] )
			return Plugin_Handled;
	}
	
	if( hooked ) {
		
		if( team != 3 ) {
			if( GetClientTeam( client ) != 3 ) {
				ChangeClientTeam( client, 3 );
			}
			return Plugin_Handled;
		}
		return Plugin_Continue;
	}
	
	//if( GetGameTime() > TEAM_WAIT_TIME ) return Plugin_Continue;
	
	if( team < 2 ){
		if( c_rxglobby_nospecs ) {
			return Plugin_Handled;
		}
	}
	
	if( match_client_team[client] && team > 1 ) {
			
		if( team != match_client_team[client] ) {
			return Plugin_Handled;
		}
		
	} else if( !match_client_team[client] ) { // only allow pubs to spectate
		if( team != 1 ) {
			return Plugin_Handled;
		}
	}
	
	// hopefully this isnt shitty
	//if( GetTeamClientCount( team ) >= 5 ) return Plugin_Handled; // do not allow more than 5 players
	return Plugin_Continue;
}

public Action:ReturnToLobby( Handle:timer ) {
	decl String:map[64];
	GetConVarString( sm_rxglobby_map, map, sizeof(map) );
	ForceChangeLevel( map, "Returning to lobby" );
}

bool:ProcessLobbyVotes() {
	lobby_votes_clients = 0;
	lobby_votes_total = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			if( IsFakeClient(i) ) continue;
			lobby_votes_clients++;
			if( client_lobby_vote[i] ) lobby_votes_total++;
		}
		
	}
	lobby_votes_required = RoundToCeil( float(lobby_votes_clients) * 0.6 );
	if( lobby_votes_total >= lobby_votes_required ) {
		PrintToChatAll( "\x01\x0B\x09Returning to lobby..." );
		returning_to_lobby = true;
		CreateTimer( 3.0, ReturnToLobby, _, TIMER_FLAG_NO_MAPCHANGE );
		return true;
	
	}
	return false;
}

public Action:Command_say( client, args ) {
	
	if( !hooked ) {
		if( returning_to_lobby ) return Plugin_Continue;
		decl String:arg[16];
		GetCmdArgString( arg,sizeof(arg) );
		StripQuotes(arg);
		
		if( StrEqual( arg, "lobby", false ) ) {
			
			client_lobby_vote[client] = 1;
			if( !ProcessLobbyVotes() ) {
				PrintToChatAll( "\x01\x0B\x09%N wants to return to the lobby, %d more vote%s needed.", client, lobby_votes_required-lobby_votes_total, (lobby_votes_required-lobby_votes_total) != 1 ? "s":"" );
			}
		}
	}
	return Plugin_Continue;
}

public Action:TimerUpdateHostname(Handle:timer) {
	
	new newstate, arg1, arg2;
	
	if( hooked ) {
		new clients = 0;
		for( new i = 1; i <= MaxClients; i++ ) {
			if( IsClientInGame(i) ) {
				if( IsFakeClient(i) ) continue;
				clients++;
			}
		}
		
		if( clients < 10 ) {
			newstate = HOSTNAME_WAITING_FOR_PLAYERS;
			arg1 = 10 - clients;
		} else {
			newstate = HOSTNAME_FULL;
		}
		
	} else {
	
		newstate = HOSTNAME_INPROGRESS_FULL;
		arg1 = GetTeamScore(3);
		arg2 = GetTeamScore(2);
		/*
		new clients1 = GetTeamClientCount(3);
		new clients2 = GetTeamClientCount(2);
		new extraslots = (5 - clients1) + (5 - clients2);
		
		if( extraslots ) {
			newstate = HOSTNAME_INPROGRESS_SLOTS;
			arg1 = extraslots;
		} else {
			
			arg1 = GetTeamScore(3);
			arg2 = GetTeamScore(2);
		}*/
	}
	
	if( last_hostname_state == newstate && last_hostname_arg1 == arg1 && last_hostname_arg2 == arg2 ) return Plugin_Continue;
	last_hostname_state = newstate;
	last_hostname_arg1 = arg1;
	last_hostname_arg2 = arg2;
	
	decl String:hostname[128];
	if( newstate == HOSTNAME_WAITING_FOR_PLAYERS ) {
		Format( hostname, sizeof(hostname), "\"%sWaiting for players; Need %d more%s\"", c_rxglobby_hostprefix, arg1, arg1 == 1 ? "!":"." );
	} else if( newstate == HOSTNAME_FULL ) {
		Format( hostname, sizeof(hostname), "\"%sFull!\"", c_rxglobby_hostprefix );
	} else if( newstate == HOSTNAME_INPROGRESS_SLOTS ) {
		Format( hostname, sizeof(hostname), "\"%sIn Progress; %d open slot%s!\"", c_rxglobby_hostprefix, arg1, arg1 != 1 ? "s" : "" );
	} else if( newstate == HOSTNAME_INPROGRESS_FULL ) {
		Format( hostname, sizeof(hostname), "\"%sIn Progress; Score: %d - %d\"", c_rxglobby_hostprefix, arg1, arg2 );
	}
	
	ServerCommand( "hostname %s", hostname );
	return Plugin_Continue;
}


//-------------------------------------------------------------------------------------------------
//radio
//-------------------------------------------------------------------------------------------------
public Action:RadioLoopTimer( Handle:timer ) {
	if( radio1 ) {
		EmitSoundToAll( RADIO_SOUND, radio1 );
		
		return Plugin_Handled;
	}
	radio_loop_timer = INVALID_HANDLE;
	return Plugin_Stop;
}

public StartSoundEvent(const String:output[], caller, activator, Float:delay) { 
	// EmitSound
	EmitSoundToAll( RADIO_SOUND, radio1 );
	radio_loop_timer = CreateTimer( RADIO_DURATION, RadioLoopTimer, _, TIMER_REPEAT );
}

public StopSoundEvent(const String:output[], caller, activator, Float:delay) { 
	// EmitSound

	// stop twice to account for loop point area
	StopSound( radio1, SNDCHAN_AUTO, RADIO_SOUND );
	StopSound( radio1, SNDCHAN_AUTO, RADIO_SOUND );
	radio1 = 0;
}

public Action:debug1( args ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		SetEntProp( i, Prop_Send, "m_iHideHUD", 0 );
	}
	PrintToChatAll( "\x01\x0B\x03***running debug1 command" );
	return Plugin_Handled;
}

public Event_Halftime( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( hooked ) return;
	if( match_halftime_passed ) return;
	match_halftime_passed = true;
	// switch teams
	for( new i = 1; i <= MaxClients; i++ ) {
		if( match_client_team[i] ) {
			match_client_team[i] = 1-match_client_team[i] +4; // swap 2 and 3
		}
	}
}

public Event_PlayerDisconnect( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( hooked ) return;
	
	/* do not allow people who have been kicked to rejoin the match */
	decl String:reason[64];
	GetEventString( event, "reason", reason, sizeof(reason) );
	
	if( strncmp( reason, "kick", 4, false ) == 0 ) {
		// remove from registration
		decl String:steamid[64];
		GetEventString( event, "networkid", steamid, sizeof(steamid) );
		
		for( new i = 0; i < 10; i++ ) {
			if( SteamIDMatch( steamid, match_player_ids[i] ) ) {
				match_player_ids[i][0] = 0;
				return;
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------

#define WR_TIMESPAN 30.0
/*
WeaponsRange_Start() {
	if( wr_active ) return;
	wr_active = true;
	wr_start_time = GetGameTime();
	wr_tick = 0;
	wr_target_spawndelay = 0;
	wr_alive_targets = 0;
}

//-------------------------------------------------------------------------------------------------
WeaponsRange_Update() {
	wr_tick++;
	wr_target_spawndelay++;
	
	new time = GetGameTime();
	if( (time - wr_start_time) < WR_TIMESPAN ) {
	
		if( wr_alive_targets < 2 && wr_target_spawndelay >= 10 ) {
			WeaponsRange_SpawnTarget();
			
		}
	}
}
*/
