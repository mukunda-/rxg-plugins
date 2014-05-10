

/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

// PROPRIETARY RXG CODE BITCHES

//----------------------------------------------------------------------------------------------------------------------

// changelog:
// 7:58 PM 11/30/2012 - v1.1.1
//   fixed molotov/incgrenade buying bug
// 10:11 AM 11/26/2012 - v1.1.0
//   cut down tiebreaker duration
//   no more nightvision sound while dead :(
// 10:52 PM 11/23/2012 - v1.0.9
//   health scaler removed from tiebreaker
//   disabled damage scaler functionality (not used)
//   removed frags from special round
// ???
//   negev added to "lolshotty"
// 12:49 AM 11/4/2012 - v1.0.8
//   NVG sounds
// 2:00 AM 11/1/2012 - v1.0.7
//   radio4
//   potential bug not resetting scores
//   dominations patch
//   negev patch
//   BONUS round
// 4:56 PM 10/25/2012 - v1.0.6b
//   molotovs cannot be re-bought (suggested by scurrydog)
// 1:32 PM 10/24/2012 - v1.0.6
//   domination tracker
// 10:43 AM 10/24/2012 - v1.0.5c
//   minor fixes
// 11:11 PM 10/23/2012 - v1.0.5b
//   clarification on tiebreak scoring
//   hook players at plugin load (can reload midgame)
// 8:43 PM 10/23/2012 - v1.0.5
//   robust tiebreaker joining
//   team verification on tiebreaker respawn
//   tiebreaker win threshold scaled by number of players
//   function to get rounds remaining until a special round occurs
// 1:39 AM 10/23/2012 - v1.0.4b
//   fixed display bug for tiebreaker damage
//   added MVPs to score functions
// 8:48 PM 10/22/2012 - v1.0.4
//   changed special round to be score based rather than elimination
//   added score saving/restoring routines
//   disabled logging during special rounds
//   improved rebuy
//   rebuy once per round only
//   remap rebuy ak47/m4
//   use restrict api instead of restrict cvars
//   /resetscore function
//   optimizations and using cstrike weapons include now
//   alltalk during special rounds
// 3:38 PM 10/20/2012 - v1.0.3
//   special round notice for tiebreaker
//   added function to cutout startup sound
//   added respawn to tiebreaker
//   so basically: generalized special rounds
//   changed tiebreaker round to be one of many 'special rounds'
//   special rounds added, activated at the end of a round
// 2:46 PM 10/19/2012 - v1.0.2
//   added penetration test for automod, adjusted damage values
//   fixed rebuy grenades
// 10/18/2012 v1.0.1
//   added message for people who buy the auto snipers to notify them of the nerf

//----------------------------------------------------------------------------------------------------------------------

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <cstrike_weapons>
#include <restrict>

#pragma semicolon 1

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "peepee",
	author = "REFLEX-GAMERS",
	description = "finally, the peepee mod we all desired",
	version = "1.1.1",
	url = "www.reflex-gamers.com"
};

//----------------------------------------------------------------------------------------------------------------------

#define GameME_RemoteLoggingAddress ""

//----------------------------------------------------------------------------------------------------------------------

#define SOUND_NVG_ON	"items/nvg_on.wav"
#define SOUND_NVG_OFF	"items/nvg_off.wav"

//----------------------------------------------------------------------------------------------------------------------
//
// splash music for tiebreaker round
//
#define TIEBREAKER_SPLASH_PATH "music\\peepee_merica_lq.mp3"
#define TIEBREAKER_SPLASH_COMMAND "play music\\peepee_merica_lq.mp3"
#define TIEBREAKER_SPLASH_PATH_DL "sound/music/peepee_merica_lq.mp3"

//
// other tiebreaker configs
//
//#define TIEBREAKER_LIVES 10
//#define TIEBREAKER_WIN_THRESHOLD 100
//#define TIEBREAKER_KNIFE_THRESHOLD 75

//
// number of special round types
//
#define NUM_SPECIAL_ROUNDS 1

//
// special round definitions
//
#define SPROUND_TIEBREAKER 1

// 
// damage values for auto sniper rifles
//
#define AUTOMOD_DMG_HEAD 110.0		// ~90 armored
#define AUTOMOD_DMG_CHEST 39.0		// ~33 armored
#define AUTOMOD_DMG_STOMACH 48.7	// ~40 armored
#define AUTOMOD_DMG_ARMS 32.0		// (no armor)
#define AUTOMOD_DMG_LEGS 30.0		// (no armor)

//
// health regeneration settings (tiebreaker)
//
#define HEALTH_REGEN_AMOUNT 10
#define HEALTH_REGEN_RATE 1.0

//
// damage scale settings (tiebreaker)
//
#define TIEBREAKER_DAMAGE_SCALE_START 0.2	// start damage
#define TIEBREAKER_DAMAGE_SCALE_END 10.0	// ramps up towards this value

// 
// hack value for setting ammo on inactive weapons
//  (offset to weapon ammo backpack data entry)
//
#define WEAPON_AMMO_BACKPACK 1452


//----------------------------------------------------------------------------------------------------------------------
// CONSOLE VARIABLES
//----------------------------------------------------------------------------------------------------------------------
#define sm_pp_hosties_desc		"1 = invulnerable hosties, 2 = invulnerable until touched by CTs (yes...touched...mmm)"
#define sm_pp_balanceautos_desc		"1 = retune the automatic sniper rifles to be fair"
#define sm_pp_botprogram_desc		"x = enable \"BOTPROGRAM\" with X bots if the server has one player only"
//#define sm_pp_lolshotguns_desc		"1 = lol shotguns"
#define sm_pp_endtalk_desc		"1 = round-end talking enabled"
#define sm_pp_music_desc		"1 = enable pp soundtrack"

#define sm_pp_spround_interval_desc	"interval at which to play a special round, measured in rounds (0=disable)"
#define sm_pp_spround_players_desc	"number of players required to have a special round"

#define sm_pp_dmgscale_on_desc		"(INTERNAL USE) 0 = off, 1 = enable all-damage scaling"
#define sm_pp_dmgscale_desc		"(INTERNAL USE) decimal number to scale damage by ([1.0] = no change, 2.0 = double damage, 0.5 = half damage)"

#define sm_pp_office_physics_desc	"1 = bring back the css memories" // unsupported

//----------------------------------------------------------------------------------------------------------------------
// CONSOLE COMMANDS
//----------------------------------------------------------------------------------------------------------------------
#define sm_peepee_desc			"touch my peepee!"
#define sm_pp_spround_desc		"sm_pp_spround <index> - next round will be a special round"
#define nextspecial_desc		"prints rounds remaining until special round"

//----------------------------------------------------------------------------------------------------------------------
new Handle:sv_alltalk			= INVALID_HANDLE;	// CVARS
new Handle:sv_deadtalk			= INVALID_HANDLE;	//
								//
new Handle:sm_pp_hosties		= INVALID_HANDLE;	//
new Handle:sm_pp_dmgscale_on		= INVALID_HANDLE;	//
new Handle:sm_pp_dmgscale		= INVALID_HANDLE;	//
new Handle:sm_pp_balanceautos		= INVALID_HANDLE;	//
new Handle:sm_pp_botprogram		= INVALID_HANDLE;	//
//new Handle:sm_pp_lolshotguns		= INVALID_HANDLE;	//
new Handle:sm_pp_endtalk		= INVALID_HANDLE;	//
new Handle:sm_pp_music			= INVALID_HANDLE;	//

new Handle:sm_pp_logaddress		= INVALID_HANDLE;

new Handle:sm_pp_spround_interval	= INVALID_HANDLE;
new Handle:sm_pp_spround_players	= INVALID_HANDLE;

new Handle:mp_limitteams		= INVALID_HANDLE;
new Handle:mp_autoteambalance		= INVALID_HANDLE;
new Handle:bot_quota			= INVALID_HANDLE;
new Handle:bot_join_team		= INVALID_HANDLE;

//new Handle:mp_maxrounds			= INVALID_HANDLE;
new Handle:mp_freezetime		= INVALID_HANDLE;
new Handle:mp_join_grace_time		= INVALID_HANDLE;

new Handle:mp_ignore_round_win_conditions = INVALID_HANDLE; // for respawn rounds

new Handle:sm_pp_office_physics		= INVALID_HANDLE;

//----------------------------------------------------------------------------------------------------------------------
new Handle:health_timer			= INVALID_HANDLE;

//---------------------------------------------------------------------------------------------------------------------- 
new Handle:bot_program_message_timer_delay	= INVALID_HANDLE;

//----------------------------------------------------------------------------------------------------------------------
new bool:disable_messages		= true;		// disable messages from cvar changes (for setup)
new gActiveHitgroup[MAXPLAYERS+1];			// last active hitgroup per player 
//----------------------------------------------------------------------------------------------------------------------
new bot_program_active			= 0;		// bot program is actively running
new bot_program_client			= 1;		// the only human client connected to the server
new bot_program_forceteam		= 0;		// force team update (skip duplicate check)
new bot_program_team			= 0;		// the team the client is on
//----------------------------------------------------------------------------------------------------------------------
new current_special_round		= 0;		// current active special round type
new next_round_special			= 0;		// nonzero = next round will be SPECIAL ROUND <X>
new special_round_active		= 0;		// current round is special
new special_round_started		= 0;		// set post mp_freezetime delay
new special_round_winner		= 0;		// set if a winner has been determined
new rounds_until_special		= 0;		//
new bool:teams_are_even			= false;	// set after call to GetRealClientCount
//----------------------------------------------------------------------------------------------------------------------
new Float:tiebreaker_damage		= 0.1;		// variable for ramping the damage scaler
new tiebreaker_damage_percent_report	= 0;		// variable for ramping the damage scaler
new tiebreaker_phase2			= 0;
//new tiebreaker_lives[MAXPLAYERS+1];			// number of lives left per player
new tiebreaker_score_t			= 0;		// score for t side
new tiebreaker_score_ct			= 0;		// score for ct side
new tiebreaker_score_win		= 0;		// score required to win
new tiebreaker_blip_cooldown	= 0;		// cooldown for playing blip sounds
//----------------------------------------------------------------------------------------------------------------------
new game_rounds_passed			= 0;		// number of game rounds passed since the match started
new score_ct				= 0;		// team scores
new score_t				= 0;		//
//----------------------------------------------------------------------------------------------------------------------
new logs_disabled			= 0;
//----------------------------------------------------------------------------------------------------------------------
new default_mp_limitteams		= 2;		// default values to rollback to when a special round is finished
new default_mp_autoteambalance		= 1;		//
new default_mp_freezetime		= 5;		//
new default_mp_join_grace_time		= 20;		//
//----------------------------------------------------------------------------------------------------------------------

new hooked_players[MAXPLAYERS+1];

//----------------------------------------------------------------------------------------------------------------------

new dominating[MAXPLAYERS][MAXPLAYERS]; // [PLAYER][TARGET]

#define dominating_threshold 3

// Following are model indexes for temp entities
new g_BeamSprite        = -1;
new g_BeamSprite2       = -1;
new g_HaloSprite        = -1;
new g_GlowSprite        = -1;

new Handle:radio4_panel;

//----------------------------------------------------------------------------------------------------------------------

///
// path to vending machine model for tiebreaker
//
new String:vending_machine_model[] = "models/props/cs_office/vending_machine.mdl";

// 
// list of all weapon names (for translating to an index)
//

/*
new String:weapon_strings[][] =
{ "",

  "p228", "glock", "elite", "fiveseven", "usp", "deagle", "tec9", "hkp2000", "p250",

  "scout", "xm1014", "mac10", "aug", "ump45", "sg550", "galil", "galilar", "famas", "awp", "mp5navy",
  "m249", "m3", "m4a1", "tmp", "g3sg1", "sg552", "ak47", "p90", "bizon", "mag7", "negev", "sawedoff",
  "mp7", "mp9", "nova", "scar17", "scar20", "sg556", "ssg08",

  "flashbang", "smokegrenade", "hegrenade", "molotov", "decoy", "incgrenade",

  "taser"
};
*/

//
// list of commands to purchase a weapon
//

/*
new String:buy_weapon_strings[][] =
{ "",

  "buy p228;", "buy glock;", "buy elite;", "buy fiveseven;", "buy usp;", "buy deagle;", "buy tec9;", "buy hkp2000;", "buy p250;",

  "buy scout;", "buy xm1014;", "buy mac10;", "buy aug;", "buy ump45;", "buy sg550;", "buy galil;", "buy galilar;", "buy famas;", "buy awp;", "buy mp5navy;",
  "buy m249;", "buy m3;", "buy m4a1;", "buy tmp;", "buy g3sg1;", "buy sg552;", "buy ak47;", "buy p90;", "buy bizon;", "buy mag7;", "buy negev;", "buy sawedoff;",
  "buy mp7;", "buy mp9;", "buy nova;", "buy scar17;", "buy scar20;", "buy sg556;", "buy ssg08;",

  "buy flashbang;", "buy smokegrenade;", "buy hegrenade;", "buy molotov;", "buy decoy;", "buy incgrenade;",

  "buy taser;"
};
*/

//----------------------------------------------------------------------------------------------------------------------
// list of messages to display when the player kills a bot in the bot program
//
new String:bot_killed_messages[][] = {
	"Good Shooting!",
	"You Sure Showed Him!",
	"A Real Human Wouldn't Have Stood A Chance!",
	"Way To Go!",
	"You Are Getting Better!",
	"Just Wait Until You Engage Real Humans, They're Much Easier!"
};

//----------------------------------------------------------------------------------------------------------------------
// list of messages for headshot kills on the bots
//
new String:bot_killed_messages_headshot[][] = {
	"Right In The Domesack!",
	"You Punctured His Face!",
	"Headshot!",
	"Excellent!",
	"Ouch!"
};

//----------------------------------------------------------------------------------------------------------------------
// list of message for when the player dies in the bot program
//
new String:killed_by_bot_messages[][] = {
	"Better Luck Next Time!",
	"Try Aiming!",
	"Try Failing Less!",
	"You Need More Practice!"

};

//----------------------------------------------------------------------------------------------------------------------
// the types of weapons that will spawn in the tiebreaker weapon fountain
//

new WeaponID:tiebreaker_weapon_ids[] = { WEAPON_ELITE, WEAPON_DEAGLE, WEAPON_XM1014, WEAPON_AK47, WEAPON_M4A1, 
	WEAPON_AUG, WEAPON_M249, WEAPON_P90, WEAPON_BIZON, WEAPON_SAWEDOFF, WEAPON_FLASHBANG, WEAPON_SMOKEGRENADE,
	 WEAPON_MOLOTOV };

//----------------------------------------------------------------------------------------------------------------------
// positions for spawning cts/terrorists in the tiebreaker
// computed with interpolated X, and fixed Y and Z (values [5], [6], [7] are not used)
// value [3] is the rotation angle
//
new Float:TiebreakerSpawnPositionsT[] = {
	774.0, -1040.013428, -173.0, 270.0,
	1230.968750, -1040.013428, -173.0, 270.0
};

new Float:TiebreakerSpawnPositionsCT[] = {
	1142.799438, -1991.752930, -282.0, 90.0,
	729.198730, -1991.752930, -282.0, 90.0
};

new Float:TiebreakerMortarSpawns[] = {
759.588928, -1093.056519, -251.863525,
873.998840, -1097.335693, -191.670639,
987.096619, -1098.077393, -193.917725,
1149.276489, -1099.036255, -289.705963,
1271.968750, -1090.915649, -250.357635,
1271.989136, -1225.459229, -272.462799,
1141.886841, -1268.776733, -316.114105,
1013.622253, -1258.197388, -291.986603,
886.169006, -1247.380981, -291.867432,
769.134949, -1254.126099, -283.902557,
745.777832, -1407.238403, -279.968750,
891.556458, -1410.151123, -328.442047,
1036.073120, -1421.596069, -331.521759,
1170.809937, -1425.591553, -327.834595,
1311.871094, -1441.505127, -328.480072,
1315.966919, -1601.090454, -329.254333,
1209.229858, -1622.638672, -321.094177,
1084.656250, -1628.592407, -316.861938,
946.324463, -1628.545288, -313.531311,
820.892212, -1629.099731, -304.095581,
737.759827, -1646.284424, -280.592712,
630.509460, -1784.440430, -329.264191,
749.804443, -1803.464478, -320.564575,
878.234741, -1811.713257, -312.494415,
998.171204, -1810.298950, -297.020874,
1146.502197, -1812.501709, -304.172943,
1267.968750, -1818.021606, -279.968750,
1219.429199, -2019.809204, -285.537109,
1067.879395, -2008.682983, -290.375549,
921.715515, -2006.053467, -297.455994,
778.575928, -2006.720337, -317.460297,
635.514404, -1976.745483, -330.851715
};

//----------------------------------------------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

////----------------------------------------------------------------------------------------------------------------------
//public ResetHookedPlayers() {
//	for( new i = 0; i < MAXPLAYERS+1; i++ ) {
//		hooked_players[i] = 0;
//	}
//}

////----------------------------------------------------------------------------------------------------------------------
//public HookAllPlayers() {
//	new maxc = GetMaxClients();
//	for( new i = 1; i <= maxc; i++ ) {
//		HookPlayer(i);
//	}
//}

//----------------------------------------------------------------------------------------------------------------------
//
// for damage mods
//
/*
public HookPlayer( client ) {
	if( IsClientConnected(client) ) {
		if( IsClientInGame(client) ) {
			if( !hooked_players[client] ) {
				hooked_players[client] = 1;
				// for damage mods
				SDKHook( client, SDKHook_OnTakeDamage, OnTakeDamage );
				SDKHook( client, SDKHook_TraceAttackPost, OnTraceAttackPost );
			}
		}
	}
}*/

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	mp_limitteams		= FindConVar( "mp_limitteams" );
	mp_autoteambalance	= FindConVar( "mp_autoteambalance" );
	bot_quota		= FindConVar( "bot_quota" );
	bot_join_team		= FindConVar( "bot_join_team" );
	
//	mp_maxrounds		= FindConVar( "mp_maxrounds" );
	mp_freezetime		= FindConVar( "mp_freezetime" );
	mp_join_grace_time	= FindConVar( "mp_join_grace_time" );

	mp_ignore_round_win_conditions = FindConVar( "mp_ignore_round_win_conditions" );

	// save values for restoring
	// todo: get values from proper source
	default_mp_limitteams	= 1;//GetConVarInt( mp_limitteams );
	default_mp_autoteambalance= 1;//GetConVarInt( mp_autoteambalance );
	default_mp_freezetime	= 5;//GetConVarInt( mp_freezetime );
	default_mp_join_grace_time = 20;//GetConVarInt( mp_join_grace_time );
	
	sv_alltalk		= FindConVar( "sv_alltalk" );
	sv_deadtalk		= FindConVar( "sv_deadtalk" );

	// disable spamming when all/deadtalk are changed
	SetConVarFlags( sv_alltalk, GetConVarFlags(sv_alltalk) & ~FCVAR_NOTIFY );
	SetConVarFlags( sv_deadtalk, GetConVarFlags(sv_deadtalk) & ~FCVAR_NOTIFY );
	SetConVarFlags( mp_freezetime, GetConVarFlags(mp_freezetime) & ~FCVAR_NOTIFY );
	SetConVarFlags( mp_limitteams, GetConVarFlags(mp_limitteams) & ~FCVAR_NOTIFY );
	SetConVarFlags( mp_autoteambalance, GetConVarFlags(mp_autoteambalance) & ~FCVAR_NOTIFY );
	SetConVarFlags( mp_join_grace_time, GetConVarFlags(mp_join_grace_time) & ~FCVAR_NOTIFY );
	
	// create convars
	sm_pp_hosties		= CreateConVar( "sm_pp_hosties",	"0",	sm_pp_hosties_desc,	FCVAR_PLUGIN ); // debug
	sm_pp_dmgscale_on	= CreateConVar( "sm_pp_dmgscale_on",	"0",	sm_pp_dmgscale_on_desc,	FCVAR_PLUGIN );
	sm_pp_dmgscale		= CreateConVar( "sm_pp_dmgscale",	"1.0",	sm_pp_dmgscale_desc,	FCVAR_PLUGIN, true, 0.1, true, 20.0 );
	sm_pp_balanceautos	= CreateConVar( "sm_pp_balanceautos",	"0",	sm_pp_balanceautos_desc,FCVAR_PLUGIN );
	sm_pp_botprogram	= CreateConVar( "sm_pp_botprogram",	"0",	sm_pp_botprogram_desc,	FCVAR_PLUGIN );
//	sm_pp_lolshotguns	= CreateConVar( "sm_pp_lolshotguns",	"0",	sm_pp_lolshotguns_desc,	FCVAR_PLUGIN );
	sm_pp_endtalk		= CreateConVar( "sm_pp_endtalk",	"0",	sm_pp_endtalk_desc,	FCVAR_PLUGIN );
	sm_pp_spround_interval	= CreateConVar( "sm_pp_spround_interval","0",	sm_pp_spround_interval_desc, FCVAR_PLUGIN );
	sm_pp_spround_players	= CreateConVar( "sm_pp_spround_players", "0",	sm_pp_spround_players_desc, FCVAR_PLUGIN );
	sm_pp_office_physics	= CreateConVar( "sm_pp_office_physics", "0",	sm_pp_office_physics_desc, FCVAR_PLUGIN );
	sm_pp_logaddress	= CreateConVar( "sm_pp_logaddress", "", "GameME logging address", FCVAR_PLUGIN );

	sm_pp_music		= CreateConVar( "sm_pp_music",		"0",	sm_pp_music_desc,	FCVAR_PLUGIN );
	
	// the special command
//	RegConsoleCmd( "sm_peepee", Command_Peepee );
//	RegConsoleCmd( "radio4", Command_radio4 );
//	RegConsoleCmd( "nightvision", Command_nightvision );
	RegAdminCmd( "sm_pp_spround", Command_SPRound, ADMFLAG_SLAY, sm_pp_spround_desc );
	
	LoadConfig();
	
	HookConVarChange( sm_pp_hosties,	CVarChanged_hosties	);
	
	
	
	HookConVarChange( sm_pp_botprogram,	CVarChanged_botprogram	);
	HookConVarChange( sm_pp_endtalk,	CVarChanged_endtalk	);
	HookConVarChange( sm_pp_spround_interval,	CVarChanged_spround_interval	);
	
	
		
	HookEvent( "round_freeze_end", Event_RoundFreezeEnd );
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "round_end", Event_RoundEnd );
	HookEvent( "player_use", Event_PlayerUse );
	HookEvent( "player_team", Event_PlayerTeam );
	HookEvent( "teamchange_pending", Event_PlayerTeamPending );
	HookEvent( "player_death", Event_PlayerDeath, EventHookMode_Pre );  
	//HookEvent( "player_death", Event_PlayerDeathPre, EventHookMode_Pre ); 
	HookEvent( "player_spawn", Event_PlayerSpawn ); 

	

	//HookEvent( "player_say", Event_PlayerSay, EventHookMode_Pre );
	
	 
	HookEvent( "cs_match_end_restart", Event_MatchEndRestart );
	
	
//	RegConsoleCmd("test", Command_Test );
	
	RegConsoleCmd("nextspecial", Command_NextSpecial );

//	RegConsoleCmd("resetscore", Command_ResetScore);

	if( GetConVarInt( sm_pp_botprogram ) > 0 ) {
		SetConVarInt( bot_quota, 0 );
	}

	//AddAmbientSoundHook( test_ambient_sound_hook );
	//AddNormalSoundHook( test_normal_sound_hook );

	SetupRadio4Panel();
	
//	ResetHookedPlayers();
//	HookAllPlayers();

	//DebugFunction();
}

DebugFunction() {
	ServerCommand( "sm_pp_botprogram 0" );



	CreateTimer( 1.0, DebugFunctionDelayed );
}




//----------------------------------------------------------------------------------------------------------------------
public Action:DebugFunctionDelayed( Handle:timer ) {
	ServerCommand( "sm_warmup_enable 0" );
//	ServerCommand( "bot_quota 10" );
	ServerCommand( "bot_join_team any" );

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_NextSpecial( client, args ) {
	PrintToConsole( client, "[PP] Rounds until next special: %i", rounds_until_special );
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
/*
public Action:Event_PlayerSay( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	if( client > 0 ) {
		new String:buffer[32];
		GetEventString( event, "text", buffer, 32 );
		if( StrEqual( buffer, "!resetscore" ) ) {
			Scores_ResetPlayer(client);
			return Plugin_Handled;
		} else if( StrEqual( buffer, "nextspecial" ) ) {
			PrintToChat( client, "[PP] Rounds until next special: %d", rounds_until_special );
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}*/

//----------------------------------------------------------------------------------------------------------------------
/*
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ResetScore( client, args ) {
	Scores_ResetPlayer(client);
	return Plugin_Handled;
}*/

//----------------------------------------------------------------------------------------------------------------------
TurnOffWinning() {
	SetConVarInt( mp_ignore_round_win_conditions, 1 );
}

//----------------------------------------------------------------------------------------------------------------------
TurnOnWinning() {
	SetConVarInt( mp_ignore_round_win_conditions, 0 );
}
 
//----------------------------------------------------------------------------------------------------------------------
public Event_MatchEndRestart( Handle:event, const String:name[], bool:dontBroadcast ) {
	//
	// repeat this just in case, ROBUSTNESS!
	//
	Event_GameStart();

}

//----------------------------------------------------------------------------------------------------------------------
LoadConfig() {
	new String:file[] = "cfg/sourcemod/peepee.cfg";
	if(FileExists(file))
	{
		ServerCommand("exec sourcemod/peepee.cfg");
	}
	rounds_until_special = GetConVarInt( sm_pp_spround_interval );
}

//----------------------------------------------------------------------------------------------------------------------
public OnMapStart() {
	
	health_timer = INVALID_HANDLE;
	TurnOnWinning();
	special_round_active = 0;
	
	PrecacheModel(vending_machine_model);

	if( GetConVarBool(sm_pp_music) ) {
		PrecacheSound( TIEBREAKER_SPLASH_PATH, true );
		AddFileToDownloadsTable( TIEBREAKER_SPLASH_PATH_DL );
	}
	//PrecacheSound("weapons\\hegrenade\\explode1.wav" );
	//PrecacheSound( "weapons\\hegrenade\\explode2.wav" );
	PrecacheSound( "weapons\\hegrenade\\explode3.wav" );
	PrecacheSound( "weapons\\hegrenade\\explode4.wav" );
	PrecacheSound( "weapons\\hegrenade\\explode5.wav" );

	PrecacheSound( SOUND_NVG_ON );
	PrecacheSound( SOUND_NVG_OFF );

	PrecacheSound( "buttons/bell1.wav" );
	
	PrecacheSound(  "music\\cs_stinger.wav"  );

	// get TE materials
	g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
	g_BeamSprite2 = PrecacheModel("materials/sprites/physbeam.vmt");
	g_GlowSprite = PrecacheModel("materials/sprites/blueflare1.vmt");
}

//----------------------------------------------------------------------------------------------------------------------
public Action:BotProgramPrintDeathTextTimerDelay( Handle:timer ) {

	bot_program_message_timer_delay = INVALID_HANDLE;

	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
BotProgramPrintDeathText( const String:text[], bool:bypass=false ) {

	PrintHintText( bot_program_client, text );

	if( !bypass ) {
		bot_program_message_timer_delay = CreateTimer( 5.0, BotProgramPrintDeathTextTimerDelay, _, TIMER_FLAG_NO_MAPCHANGE );
	}
}
/*
public Action:Event_PlayerDeathPre( Handle:event, const String:name[], bool:dontBroadcast ) {
	SetEventInt(event, "dominated", 1);
	return Plugin_Changed;
}*/

//----------------------------------------------------------------------------------------------------------------------
public Action:Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {


	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid ); // this must be valid, someone has to die...
	new attacker = GetEventInt( event, "attacker" ); // this may not be valid
	new att_client = 0;
	if( attacker > 0 ) {
		att_client = GetClientOfUserId( attacker );

		new result = Domination_RegisterKill( att_client, client );

		if( result == 1 ) {
			SetEventInt( event, "dominated", 1 );
		} else if( result == 2 ) {
			SetEventInt( event, "revenge", 1 );
		}
	}
	
	new bool:hs = GetEventBool( event, "headshot" );

	if( bot_program_active ) {
 
		
		if( client == bot_program_client ) {
			BotProgramPrintDeathText( killed_by_bot_messages[ GetRandomInt( 0, sizeof( killed_by_bot_messages ) - 1 ) ], true );
		} else if( att_client == bot_program_client ) {
		
			if( bot_program_message_timer_delay != INVALID_HANDLE ) return Plugin_Continue; 

			if( !hs ) {
				BotProgramPrintDeathText( bot_killed_messages[ GetRandomInt( 0, sizeof( bot_killed_messages ) - 1 ) ] );
			} else {
				BotProgramPrintDeathText( bot_killed_messages_headshot[ GetRandomInt( 0, sizeof( bot_killed_messages_headshot ) - 1 ) ] );
			}
			
		}
	}

	if( special_round_active ) {
		SpecialRound_PlayerDeath(event);
	}
	
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {

	// give nightvision :)
	new client = GetClientOfUserId(GetEventInt( event, "userid" ));
	if( IsValidClient(client) ) {
		SetEntProp( client, Prop_Send, "m_bHasNightVision", 1 );
	}
	
	if( special_round_active ) {
		SpecialRound_PlayerSpawn( event );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_nightvision( client, args ) {
	new nv = GetEntProp( client, Prop_Send, "m_bNightVisionOn" );
	
	if( IsValidClient(client) ) {
		if( IsPlayerAlive(client) ) {
			if( nv ) {
				EmitSoundToAll( SOUND_NVG_OFF, client );
			} else {
				EmitSoundToAll( SOUND_NVG_ON, client );
			}
		}
	}

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerTeam( Handle:event, const String:name[], bool:dontBroadcast ) {

	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	if( bot_program_active ) {
		if( client == bot_program_client ) {
			
			SetBotProgramTeam( GetEventInt( event, "team" ) );
		}
	} else if( special_round_active == SPROUND_TIEBREAKER ) {
		if( GetEventInt( event, "team" ) >= 2 ) {

			Tiebreaker_RespawnPlayerDelayed( client );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerTeamPending( Handle:event, const String:name[], bool:dontBroadcast ) {
	if( bot_program_active ) {
		if( GetClientOfUserId( GetEventInt( event, "userid" ) ) == bot_program_client ) {
			
			SetBotProgramTeam( GetEventInt( event, "toteam" ) );
		}
	} 
}

//----------------------------------------------------------------------------------------------------------------------
GetRealClientCount( bool:inGameOnly = true, bool:includebots = false ) {	
	new clients = 0;
	new maxclients = GetMaxClients();
		
	new team_ct;
	new team_t;
	for( new i = 1; i <= maxclients; i++ ) {	
		if( ( ( inGameOnly ) ? IsClientInGame( i ) : IsClientConnected( i ) ) && (includebots || !IsFakeClient( i )) ) {
			clients++;
			bot_program_client = i;

			if( IsClientInGame(i) ) {
				new t = GetClientTeam( i );
				if( t == CS_TEAM_CT ) {
					team_ct++;
				} else if( t == CS_TEAM_T ) {
					team_t++;
				}
			}
		}
	}

	teams_are_even = (team_ct == team_t);
	return clients;
}
 

//----------------------------------------------------------------------------------------------------------------------
SetBotProgramTeam( team ) {
	if( bot_program_team != team || bot_program_forceteam ) {
		bot_program_forceteam = 0;
		bot_program_team = team;
		ResetBotProgram();
	}
}

//----------------------------------------------------------------------------------------------------------------------
ResetBotProgram() {

	ServerCommand( "bot_kick all" );

	CS_TerminateRound( 1.0, CSRoundEnd_GameStart );
	
	if( bot_program_active ) {
		
		if( IsClientConnected( bot_program_client ) ) {
			


			if( bot_program_team == 2 ) { // T

				SetConVarString( bot_join_team, "ct" );
				ServerCommand( "bot_quota %i", GetConVarInt( sm_pp_botprogram ) );
			} else if( bot_program_team == 3 ) { // CT

				SetConVarString( bot_join_team, "t" );
				ServerCommand( "bot_quota %i", GetConVarInt( sm_pp_botprogram ) );
				
			} else { 
				// player hasnt chosen a team
 
			}
 
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
StartBotProgram() {
	if( bot_program_active != 1 ) {
		bot_program_active = 1;
		bot_program_forceteam = 1;
		SetConVarInt( mp_limitteams, 0 );
		SetConVarInt( mp_autoteambalance, 0 );
		
		
		ServerCommand( "bot_kick all" );
		if( IsClientConnected( bot_program_client ) && IsClientInGame(bot_program_client) ) {

			SetBotProgramTeam( GetClientTeam( bot_program_client ) );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
StopBotProgram() {

	SetConVarInt( mp_limitteams, default_mp_limitteams );
	SetConVarInt( mp_autoteambalance, default_mp_autoteambalance );
	ServerCommand( "bot_kick all" );
	bot_program_active = 0;
	bot_program_team = 0;
}

//----------------------------------------------------------------------------------------------------------------------
ComputeClientsAndRunBotProgram() {

	if( GetConVarInt( sm_pp_botprogram ) > 0 ) {
 
		new clients = GetRealClientCount(false);

		if( clients == 1 ) {
			StartBotProgram();
		} else {
			StopBotProgram();
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected(client) {
	ComputeClientsAndRunBotProgram();

	// tiebreaker initialization
	//tiebreaker_lives[client] = -1;
	Scores_ClientConnected(client);

	Domination_NewPlayer( client );
	
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientDisconnect(client) {
	hooked_players[client] = 0;
	ComputeClientsAndRunBotProgram();

	
}
 
//----------------------------------------------------------------------------------------------------------------------
public Action:HealthTick( Handle:timer ) {
	//
	// timer callback to add health to players for the health regen function
	//

	new max_clients = GetMaxClients();
	for( new i = 1; i <= max_clients; i++ ) {
		if( IsClientConnected(i) && IsClientInGame(i) ) {	
			if( IsPlayerAlive(i) ) {
				new health = GetClientHealth(i);
				if( health != 100 ) {
					health = health + HEALTH_REGEN_AMOUNT;
					if( health > 100 ) health = 100;
					SetEntityHealth( i, health );
				}
			}
		}
	}

	// just hook this here...simple! (every 1 second)
	tiebreaker_blip_cooldown--;
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
SetHealthRegen() {
	// enable health regen for this round
	if( health_timer != INVALID_HANDLE ) return; // timer is already active for this round

	health_timer = CreateTimer( HEALTH_REGEN_RATE, HealthTick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {

	// for invulnerable hostages mod
	//
	// if a CT touches a hostie, it will set the m_takedamage flag to "vulnerable"
	//

	if( GetConVarInt(sm_pp_hosties) == 2 ) {
		new userid = GetEventInt( event, "userid" );
		new client = GetClientOfUserId( userid );
		if( GetClientTeam( client ) == 3 ) { // CT
			new entity = GetEventInt(event,"entity");
			decl String:ent_name[32];
			GetEntityClassname( entity, ent_name, 32 );
			if( StrEqual( ent_name, "hostage_entity" ) ) {
				SetEntProp( entity, Prop_Data, "m_takedamage", 2, 1 );
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
InvulnerateHosties() {
	// set all hosties m_takedamage mode to '1' (register damage events but no health loss)
	
	new hostie = -1;
	
	while( (hostie = FindEntityByClassname( hostie, "hostage_entity" )) != -1 ) {
		SetEntProp( hostie, Prop_Data, "m_takedamage", 1, 1 );
		
	}
}

//----------------------------------------------------------------------------------------------------------------------
public CVarChanged_hosties( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( strcmp( oldval, newval ) == 0 ) return;

	if( !disable_messages ) {
		if( strcmp( newval, "0" ) == 0 ) {
			PrintToChatAll( "[PP] Hostage Mods Disabled" );
		} else if( strcmp( newval, "1" ) == 0 ) {
			PrintToChatAll( "[PP] Hostage Mods Enabled (Mode 1)" );
		} else if( strcmp( newval, "2" ) == 0 ) {	
			PrintToChatAll( "[PP] Hostage Mods Enabled (Mode 2)" );
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public CVarChanged_botprogram( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( strcmp( oldval, newval ) == 0 ) return;

	if( GetConVarInt( sm_pp_botprogram ) > 0 ) {
		ComputeClientsAndRunBotProgram();
	} else {
		StopBotProgram();
	}
}

//----------------------------------------------------------------------------------------------------------------------
public CVarChanged_endtalk( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( strcmp( oldval, newval ) == 0 ) return;

	if( !disable_messages ) {
		if( strcmp( newval, "1" ) == 0 ) {
			PrintToChatAll( "[PP] Endtalk enabled." );
		} else {
			PrintToChatAll( "[PP] Endtalk disabled." );
		}
	}
	
	if( strcmp( newval, "0" ) == 0 ) {
		DisableFulltalk();
	}
}

//----------------------------------------------------------------------------------------------------------------------
public CVarChanged_spround_interval( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( strcmp( oldval, newval ) == 0 ) return;
	rounds_until_special = GetConVarInt( sm_pp_spround_interval );
}

//----------------------------------------------------------------------------------------------------------------------
DisableFulltalk() {
	SetConVarBool( sv_alltalk, false );
	SetConVarBool( sv_deadtalk, false );
}

//----------------------------------------------------------------------------------------------------------------------
EnableFulltalk() {
	SetConVarBool( sv_alltalk, true );
	SetConVarBool( sv_deadtalk, true );	
}

//----------------------------------------------------------------------------------------------------------------------
public CVarChanged_healthregen( Handle:cvar, const String:oldval[], const String:newval[] ) {
	if( strcmp( oldval, newval ) == 0 ) return;
}

//----------------------------------------------------------------------------------------------------------------------
CloseHealthTimer() {
	if( health_timer != INVALID_HANDLE ) {
		CloseHandle(health_timer);
		health_timer = INVALID_HANDLE;
	}
}


//----------------------------------------------------------------------------------------------------------------------
public Event_GameStart() {
	game_rounds_passed = 0;
	score_ct = 0;
	score_t = 0;
	
	next_round_special = 0;
	EndSpecialRound();
	
	rounds_until_special = GetConVarInt( sm_pp_spround_interval );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	if( GetConVarBool( sm_pp_endtalk ) == true ) {
		EnableFulltalk();
	}
	CloseHealthTimer();

	new CSRoundEndReason:reason = CSRoundEndReason:GetEventInt( event, "reason" );
	
	if( reason == CSRoundEnd_GameStart ) {
		Event_GameStart();
	} else if( reason == CSRoundEnd_Draw ) {
		// do nothing!
	} else {
		game_rounds_passed++;

		
		if( reason == CSRoundEnd_TargetBombed || reason == CSRoundEnd_VIPKilled || reason == CSRoundEnd_TerroristsEscaped || reason == CSRoundEnd_TerroristWin || reason == CSRoundEnd_HostagesNotRescued || reason == CSRoundEnd_VIPNotEscaped || reason == CSRoundEnd_CTSurrender ) {
			score_t++;
		} else if( reason == CSRoundEnd_VIPEscaped || reason == CSRoundEnd_CTStoppedEscape || reason == CSRoundEnd_TerroristsStopped || reason == CSRoundEnd_BombDefused || reason == CSRoundEnd_CTWin || reason == CSRoundEnd_HostagesRescued || reason == CSRoundEnd_TerroristsNotEscaped || reason == CSRoundEnd_TerroristsSurrender ) {
			score_ct++;
		}

		
		if( !next_round_special && !special_round_active ) {

			rounds_until_special--;
			if( rounds_until_special <= 0 ) {
			
				if( GetConVarInt( sm_pp_spround_interval ) > 0 && GetRealClientCount(_,true) >= GetConVarInt(sm_pp_spround_players) ) {
		
					if( teams_are_even ) {
						if( !bot_program_active ) {
							SetNextRoundSpecial();
						}
					}
				} else {
					rounds_until_special = GetConVarInt( sm_pp_spround_interval );
				}
			}
		}
	}
	
	if( special_round_active ) {
		EndSpecialRound();
	}
	TurnOnWinning(); // make sure this is on!! in case something went wrong
}

//----------------------------------------------------------------------------------------------------------------------
public Action:TrainingSessionMessage( Handle:timer ) {
	if( IsClientInGame( bot_program_client ) ) {
		PrintHintText( bot_program_client, "Waiting For Players, Enjoy Your Realistic Training Session" );
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
EnableOfficePhysics() {
	// search for office entities and make them movable
}

//----------------------------------------------------------------------------------------------------------------------
ComputeNegevBan() {
	// todo: cleaner

	new amount = 0;
	if( GetTeamClientCount(2) + GetTeamClientCount(3) >= 16 ) {
		amount= 1;
		
	}

	Restrict_SetRestriction( WEAPON_NEGEV, CS_TEAM_T, amount );
	Restrict_SetRestriction( WEAPON_NEGEV, CS_TEAM_CT, amount );
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	if( GetConVarBool( sm_pp_office_physics ) ) {
		EnableOfficePhysics();
	}

	ComputeNegevBan();

	if( GetConVarBool( sm_pp_endtalk ) == true ) {
		DisableFulltalk();
	}
	

	SetConVarBool( sm_pp_dmgscale_on, false );
	
	if( GetConVarInt( sm_pp_hosties ) != 0 ) {
		InvulnerateHosties();
	}
	
	ComputeClientsAndRunBotProgram();
	if( bot_program_active ) {
		CreateTimer( 2.0, TrainingSessionMessage, _, TIMER_FLAG_NO_MAPCHANGE );
	}

	//next_round_tiebreaker = 1; // bypass tiebreaker checks switch
	//if( next_round_tiebreaker ) {
	//	next_round_tiebreaker = 0;
	//	SetupTiebreakerRound();
	//}
	
	if( next_round_special ) {
		SetupSpecialRound();
	}

	
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundFreezeEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	if( special_round_active ) {

		special_round_started = 1;

		if( GetConVarBool(sm_pp_music) ) {
			StopStartupMusic( false );
			PlaySpecialRoundSplash();
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer(client) {
	
	//PrintToServer( "ClientPutInServer: %d", IsClientInGame(client) );
	//////////HookPlayer( client );


	

	SpecialRound_ClientConnected( client );
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Peepee( client, args ) {
	// the peepee command

	PrintToChat( client, "\x01\x0B\x06[Server]\x07 Touch my peepee!" );
	return Plugin_Handled;
}

new String:radiostrings[][] = { "enemydown", "coverme", "takingfire", "regroup", "getout", "reportingin", "report" };

//----------------------------------------------------------------------------------------------------------------------
public radio4_handler( Handle:menu, MenuAction:action, param1, param2 ) {
	decl String:cmd[32];
	if( !IsClientConnected(param1) || !IsClientInGame(param1) ) return;

	if( param2 >= 1 && param2 <= 7 ) {
		Format( cmd, sizeof(cmd), "%s", radiostrings[param2-1] );
		ClientCommand( param1, cmd );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_radio4( client, args ) {
	
	SendPanelToClient( radio4_panel, client, radio4_handler, 10 );

	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
SetupRadio4Panel() {
	radio4_panel = CreatePanel();
	SetPanelTitle( radio4_panel, "Extra Radio Commands" );

	DrawPanelItem( radio4_panel, "Enemy Down" );
	DrawPanelItem( radio4_panel, "Cover Me" );
	DrawPanelItem( radio4_panel, "Taking Fire" );
	DrawPanelItem( radio4_panel, "Regroup" );
	DrawPanelItem( radio4_panel, "It's gonna blow!" );
	DrawPanelItem( radio4_panel, "Reporting In" );
	DrawPanelItem( radio4_panel, "Report In" );
	DrawPanelItem( radio4_panel, "Cancel" );
	

	
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_SPRound( client, args ) {
	// make next round special
	
	if( args > 0 ) {
		new String:buffer[8];
		GetCmdArg( 1, buffer, 8 );
		
		new index = StringToInt( buffer );
		if( index == 0 || index > NUM_SPECIAL_ROUNDS ) {
			PrintToConsole( client, sm_pp_spround_desc );
		}
	
		SetNextRoundSpecial(index);

	} else {
		PrintToConsole( client, sm_pp_spround_desc );
	}

	return Plugin_Handled;
}

////----------------------------------------------------------------------------------------------------------------------
//public OnTraceAttackPost(victimID, attackerID, inflictor, Float:damage, damagetype, ammotype, hitbox, hitgroup) {
//
//	// verify valid message
//	if (!(hitgroup > 0 && attackerID > 0 && attackerID <= MaxClients && victimID > 0 && victimID <= MaxClients)) {
//		return;
//	}
//	gActiveHitgroup[victimID] = hitgroup;
//}
//
////----------------------------------------------------------------------------------------------------------------------
//public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
//		Float:damageForce[3], Float:damagePosition[3]) {
//
//	// verify valid/usable message
//	if(!(attacker > 0 && attacker <= MaxClients && victim > 0 && victim <= MaxClients)) {
//		return Plugin_Continue;
//	}
//	if( damage <= 0 || weapon <= 0 ) {
//		return Plugin_Continue;
//	}
//	 
//	if( !IsValidEntity( weapon ) ) {
//		return Plugin_Continue;
//	}
//	 
//	decl String:sWeapon[32];
//	GetEntityClassname( weapon, sWeapon, sizeof(sWeapon) );
//
//	ReplaceString( sWeapon, 32, "weapon_", "" );
//	new WeaponID:id = GetWeaponID( sWeapon );
//	
//	new bool:changed = false;
// 
//	if( GetConVarBool( sm_pp_balanceautos ) ) {
//		if( id == WEAPON_G3SG1 || id == WEAPON_SCAR20 ) {
//			new hg = gActiveHitgroup[victim];
//			
//			// compute new damage
//			// check if damage < 65% of expected damage to determine if the bullet penetrated an obstacle
//			// the two auto snipers are very similar terms of damage
//			
//			switch( hg ) {
//				case 1:	// headshot (original=317)
//				{
//					if( damage < 206.05 ) { 
//						damage = AUTOMOD_DMG_HEAD/2.0;
//					} else {
//						damage = AUTOMOD_DMG_HEAD;
//					}
//				}
//				case 2:	// body (original=79)
//				{
//					if( damage < 51.35 ) {
//						damage = AUTOMOD_DMG_CHEST/2.0;
//					} else {
//						damage = AUTOMOD_DMG_CHEST;
//					}
//				
//				}
//				case 3: // stomach (original=97) (wow)
//				{
//					if( damage < 63.05 ) {
//						damage = AUTOMOD_DMG_STOMACH/2.0;
//					} else {
//						damage = AUTOMOD_DMG_STOMACH;
//					}
//				}
//				case 4, 5: // arms (original=65)
//				{
//					if( damage < 42.25 ) {
//						damage = AUTOMOD_DMG_ARMS/2.0;
//					} else {
//						damage = AUTOMOD_DMG_ARMS;
//					}
//				}
//				case 6, 7: // legs (original=59)
//				{
//					if( damage < 38.35 ) {
//						damage = AUTOMOD_DMG_LEGS/2.0;
//					} else {
//						damage = AUTOMOD_DMG_LEGS;
//					}
//				}
//			}
//			changed = true;
//		}
//	}
///*
//	if( GetConVarBool( sm_pp_lolshotguns ) == true ) {
//		
//		 if( GetWeaponTypeFromID( id ) == WeaponTypeShotgun || id == WEAPON_NEGEV ) {
//			
//			damageForce[0] *= 50.0;
//			damageForce[1] *= 50.0;
//			damageForce[2] *= 50.0; 
//			changed = true;
//		}
//	}
//*/
//	
////	if( GetConVarBool( sm_pp_dmgscale_on ) ) {
////		damage *= GetConVarFloat( sm_pp_dmgscale );
////		changed = true;
////	}
//	
//	if( changed ) return Plugin_Changed;
//	return Plugin_Continue;
//
//}



/*
new String:grenade_type_classnames[][] = { "weapon_hegrenade", "weapon_flashbang", "weapon_smokegrenade", "weapon_molotov", "weapon_decoy", "weapon_incgrenade" };
new grenade_type_ammo[6] = { AMMO_INDEX_HE, AMMO_INDEX_FLASH, AMMO_INDEX_SMOKE, AMMO_INDEX_MOLOTOV,AMMO_INDEX_DECOY,AMMO_INDEX_MOLOTOV };
	new WeaponID:grenade_types[6] = {WEAPON_HEGRENADE,WEAPON_FLASHBANG,WEAPON_SMOKEGRENADE,WEAPON_MOLOTOV,WEAPON_DECOY,WEAPON_INCGRENADE};
*/

//----------------------------------------------------------------------------------------------------------------------
//Rebuy_DiscardUnusedGrenades( client ) {

	/* ... it just doesnt work right.

	// just discard everything. FUCK.

	for( new i = 0; i < 3; i++ ) {

		new ent = GetPlayerWeaponSlot( client, int:SlotGrenade );
		if( ent != -1 ) {
			
			RemovePlayerItem( client, ent );
		} else {
			break;
		}
	}
	*/

	/* oh FUCK IT ALL ALREADY.

	new WeaponID:grenades[3];	// grenades the user is holding
	new WeaponID:tobuy[3];		// grenades the user wants
	new grenade_count=0;


	for( new i = 0; i < 3; i++ ) {
		tobuy[i] = rebuy_data[client][REBUY_GRENADES+i];
	}
	PrintToChatAll( "debug: TOBUY %d, %d, %d", tobuy[0],tobuy[1],tobuy[2] );
 
	// put grenades on stack
	for( new i = 0; i < 3; i++ ) {

		new ent = GetPlayerWeaponSlot( client, int:SlotGrenade );
		if( ent != -1 ) {
			decl String:name[64];
			GetEntityClassname( ent, name, 64 );
			for( new j = 0; j < 6; j++ ) {
				if( StrEqual( grenade_type_classnames[j], name ) ) {
					new WeaponID:g = grenade_types[j];
					if( g == WEAPON_INCGRENADE ) g = WEAPON_MOLOTOV;
					grenades[grenade_count] = g;
					
					grenade_count++;
					PrintToChatAll( "debug: found grenade %d",g );
					break;
				}
			}
			RemovePlayerItem( client, ent );
		} else {
			break;
		}
	}

	
	for( new i = 0; i < 3; i++ ) {
		new WeaponID:g = grenades[i];
		
		if( g != WEAPON_NONE ) {
			for( new j = 0; j < 3; j++ ) {
				if( g == tobuy[j] ) {		
	
					// ok client wants this one, and already had it
	
					new String:name[32] = "weapon_";
					if( g == WEAPON_MOLOTOV ) {
						if( GetClientTeam(client) == 3 ) g = WEAPON_INCGRENADE;
					}
					StrCat(name, 32, weaponNames[g]);
					GivePlayerItem( client, name );
					PrintToChatAll( "debug: returning grenade %d", grenades[i] );
					grenades[i] = WEAPON_NONE;
					tobuy[j] = WEAPON_NONE;

				}
			}
		}
	}
	*/

//}


/*
public Action:test_ambient_sound_hook( String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay ) {
	PrintToServer( "ambient shook: %s", sample );
	return Plugin_Continue;
}
public Action:test_normal_sound_hook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags ) {
	PrintToServer( "normak shook: %s", sample );
	return Plugin_Continue;
}
*/

public Action:Event_NormalSound( clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags ) {
	// todo :/
	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
StopStartupMusic( bool:playstinger = true ) {
	new maxc = GetMaxClients();
	for( new i = 1; i <= maxc; i++ ) {
		if( IsClientConnected(i) ) {
			if( IsClientInGame(i) && !IsFakeClient(i) ) {
				
				StopSound(i, SNDCHAN_STATIC, "common\\silence_1sec_lp.wav" );

				StopSound(i, SNDCHAN_STATIC, "*music\\003\\startround_b01.wav" );
				StopSound(i, SNDCHAN_STATIC, "*music\\003\\startround_b02.wav" );
				StopSound(i, SNDCHAN_STATIC, "*music\\003\\startround_b03.wav" );
				StopSound(i, SNDCHAN_STATIC, "*music\\001\\startround_b01.wav" );
				StopSound(i, SNDCHAN_STATIC, "*music\\001\\startround_b02.wav" );
				StopSound(i, SNDCHAN_STATIC, "*music\\001\\startround_b03.wav" );

			}
		}
	}
	
	if( playstinger ) {
		EmitSoundToAll( "music\\cs_stinger.wav", _, SNDCHAN_STATIC );
	}
}

/*
new addresses_1[1024];
new addresses_2[1024];

new address_write_1 = 0;
new address_write_2 = 0;

new current_list = 0;
new first_list = 1;

CheatSearch( client, value, bool:reset=false ) {
	if( reset ) {
		current_list = 0;
		address_write_1 = 0;
		address_write_2 = 0;
		current_list = 0;
		first_list = 1;
		PrintToConsole( client, "reset search" );
		return;
	}

	if( first_list ) { // search entire memory
		PrintToConsole( client, " *** performing memory search" );
		for( new i = 4; i < 10000; i+= 4 ) {
			if( GetEntData( client, i ) == argint ) {			
	
				addresses_1[address_write_1] = i;
				address_write_1++;
				PrintToConsole( client, "found %d", i );
			}
		}
		first_list = 0;
		PrintToConsole( client, " *** total %d matches", address_write_1 );
	} else { // search list
		if( current_list == 0 ) {
			for( new i = 0; i < address_write_1; i++ ) {
				if( GetEntData( client, addresses_1[i] ) == argint ) {
					addresses_2[address_write_2] = addresses_1[i];
					address_write_2++;
					PrintToConsole( client, "found %d", addresses_1[i] );
					
				}
			}
			PrintToConsole( client, " *** total %d matches", address_write_2 );
			address_write_1 = 0;
			current_list = 1;
		} else if( current_list == 1 ) {
			for( new i = 0; i < address_write_2; i++ ) {
				if( GetEntData( client, addresses_2[i] ) == argint ) {
					addresses_1[address_write_1] = addresses_2[i];
					address_write_1++;
					PrintToConsole( client, "found %d", addresses_2[i] );
					
				}
			}
			PrintToConsole( client, " *** total %d matches", address_write_1 );
			address_write_2 = 0;
			current_list = 0;
		}
	}
}
*/

//-------------------------------------------------------------------------------------------------
public Action:Command_Test( client, args ) {
//-------------------------------------------------------------------------------------------------
//	Scores_SaveAndReset();
	/*
	new String:arg[64];
	GetCmdArg( 1, arg, 64 );

	new ent = CreateEntityByName( arg );
	
	decl Float:start[3], Float:norm[3], Float:angle[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetAngleVectors( angle, norm, NULL_VECTOR, NULL_VECTOR );
	norm[2] = 0.0;
	NormalizeVector( norm, norm );

	start[0] += norm[0] * 40.0;
	start[1] += norm[1] * 40.0;
	//start[2] += 64.0;

	
	DispatchSpawn(ent);

	TeleportEntity( ent, start, NULL_VECTOR, NULL_VECTOR );
	*/
	/*
	PrintToChatAll( "running test function" );

	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsValidClient(i) ) {
			SetEntPropFloat( i, Prop_Send, "m_flModelScale", 0.5);
			SetEntPropFloat( i, Prop_Send, "m_flStepSize", 18.0 * 0.5);
		}
	}*/

	/*
	PrintToChatAll( "running test function." );
	
	SetEntProp( client, Prop_Send, "m_bIsDefusing", 1 );
	*/

	/* cheat search
	if( args == 0 ) {
		CheatSearch( 0,0,true);
 
		return Plugin_Handled;
	} */

/*
	new String:buffer[32];
	GetCmdArg(1, buffer,32);

	new argint = StringToInt( buffer );
    
	new offset = FindDataMapOffs( client, buffer );
	
	PrintToConsole( client, "datamap entry %s = %d", buffer, offset );
	
	offset = FindSendPropInfo( "CCSPlayer", buffer );
	
	PrintToConsole( client, "sendprop entry %s = %d", buffer, offset );
*/

	
	return Plugin_Handled;
}

//=======================================================================================================================
// special round code
//=======================================================================================================================


new next_vending_machine;
new tiebreaker_weapon_counter;


//-------------------------------------------------------------------------------------------------
new Float:vending_machine_positions[] = {
//	1462.342773,568.176331,-95.906189,	0.0, 0.0, 0.0,
	
	540.0, -1766.0, -333.0,		0.0, 90.0, 0.0,
	540.0, -1836.0, -333.0,		0.0, 90.0, 0.0,
	540.0, -1906.0, -333.0,		0.0, 90.0, 0.0,
	540.0, -1976.0, -333.0,		0.0, 90.0, 0.0,

	863.0, -968.0, -160.0, 0.0, 0.0, 0.0,
	933.0, -968.0, -160.0, 0.0, 0.0, 0.0,
	1003.0, -968.0, -160.0, 0.0, 0.0, 0.0,
	1073.0, -968.0, -160.0, 0.0, 0.0, 0.0,
	1143.0, -968.0, -160.0, 0.0, 0.0, 0.0,

	502.0, -1453.0, -280.0, 0.0, 90.0, 0.0,
	502.0, -1393.0, -280.0, 0.0, 90.0, 0.0,


	1022.997864, -1515.080811, -295.712128, 90.0, 0.0, 0.0,
	939.997864, -1515.080811, -295.712128, 90.0, 0.0, 0.0,

	1200.728271, -1263.703735, -316.893951, 0.0, 180.0, 0.0,
	883.489136, -1326.061646, -321.200409, 0.0, 180.0, 0.0,
	800.522278, -1755.742188, -317.817963, 0.0, 180.0, 0.0,
	1154.615845, -1798.427612, -309.076782, 0.0, 0.0, 0.0,

	1276.413696, -1500.632080, -293.0, 90.0, 90.0, 0.0,
	1276.413696, -1584.632080, -293.0, 90.0, 90.0, 0.0,

};

//----------------------------------------------------------------------------------------------------------------------

public Action:Tiebreaker_InvulnerablePlayerEnd( Handle:timer, any:data2 ) {
	ResetPack(data2);
	new client = ReadPackCell(data2);
	if( IsClientConnected(client) ) {
		SetEntProp( client, Prop_Data, "m_takedamage", 2 );
		SetEntityRenderColor( client, 255,255,255,255 );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Tiebreaker_RespawnPlayer( Handle:timer, any:data ) {
	ResetPack(data);
	new client = ReadPackCell(data);

	if( !IsPlayerAlive(client) ) {

		if( GetClientTeam(client) < 2 ) return Plugin_Handled; // not in game

		CS_RespawnPlayer( client );

		SetEntProp( client, Prop_Data, "m_takedamage", 1 );
		SetEntityRenderColor( client, 0,0,0,255 );

		new Handle:data2;
		CreateDataTimer( 3.0, Tiebreaker_InvulnerablePlayerEnd, data2 );
		WritePackCell( data2, client );
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
Tiebreaker_RespawnPlayerDelayed( client ) {
	
	new Handle:data;
	CreateDataTimer( 2.0, Tiebreaker_RespawnPlayer, data );
	WritePackCell( data, client );
}

//-------------------------------------------------------------------------------------------------
Tiebreaker_TestWinCondition() {
	if( special_round_winner ) return; // already annoucned winner


	if( tiebreaker_score_t >= ((tiebreaker_score_win * 3)/4) || tiebreaker_score_ct >= ((tiebreaker_score_win * 3)/4) ) {
		Tiebreaker_ExecutePhase2_Delayed();
	}

	if( tiebreaker_score_t >= tiebreaker_score_win ) {
		special_round_winner = 1;
		CS_TerminateRound( 8.0, CSRoundEnd_TerroristWin );
	} else if( tiebreaker_score_ct == tiebreaker_score_win ) {
		special_round_winner = 1;
		CS_TerminateRound( 8.0, CSRoundEnd_CTWin );
	}
}

ForcePlayerKnife( client ) {

	if( !IsClientConnected(client) ) return;
	if( !IsClientInGame(client) ) return;
	if( !IsPlayerAlive(client) ) return;

	// strip player weapons
	new ent;
	ent = GetPlayerWeaponSlot( client, int:SlotPrimmary );
	if( ent != -1 ) RemovePlayerItem( client, ent );
	ent = GetPlayerWeaponSlot( client, int:SlotPistol );
	if( ent != -1 ) RemovePlayerItem( client, ent );

	for( new i = 0; i < 3; i++ ) {
		ent = GetPlayerWeaponSlot( client, int:SlotGrenade );
		if( ent != -1 ) 
			RemovePlayerItem( client, ent );
		else
			break;
	}

	ent = GetPlayerWeaponSlot( client, int:SlotKnife );
	if( ent != -1 ) {
		EquipPlayerWeapon( client, ent );
	}
	
}

RemoveAllWeapons()
{
	new maxc = GetMaxClients();
	for (new i = maxc; i <= GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			decl String:name[WEAPONARRAYSIZE];
			GetEdictClassname(i, name, sizeof(name));
			if((strncmp(name, "weapon_", 7, false) == 0 || strncmp(name, "item_", 5, false) == 0) ) {

				new WeaponID:id = Restrict_GetWeaponIDExtended(name);
				if( id != WEAPON_NONE ) {
					new owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");
					if( owner == -1 ) {
						AcceptEntityInput(i, "Kill");
					}


					//	if( id != WEAPON_KNIFE ) {
					//		RemovePlayerItem( owner, i );
						//} else {
						//	EquipPlayerWeapon( owner, i );
						//}
					//}
				}


			}
		}
	}

	for( new i = 1; i <= maxc; i++ ) {
		ForcePlayerKnife(i);
		
	}
}

//-------------------------------------------------------------------------------------------------
Tiebreaker_ExecutePhase2() {
	
	PrintCenterTextAll( "WARNING: PHASE 2" );
	RemoveAllWeapons();

	
	CreateTimer( 3.0, Timer_Mortar, _, TIMER_REPEAT);
	
}

public Action:Tiebreaker_ExecutePhase2_Timer( Handle:timer ) {
	if( !special_round_active ) return Plugin_Handled;

	Tiebreaker_ExecutePhase2();

	return Plugin_Handled;
}

Tiebreaker_ExecutePhase2_Delayed() {
	if( !tiebreaker_phase2 ) {
		tiebreaker_phase2=1;
		CreateTimer( 0.25, Tiebreaker_ExecutePhase2_Timer );
	}
}

//-------------------------------------------------------------------------------------------------
SpecialRound_PlayerDeath( Handle:event ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId(userid);
	
	if( special_round_active == SPROUND_TIEBREAKER ) {
		new team = GetClientTeam(client);
		if( team == 2 ) { // t
			tiebreaker_score_ct++;
		} else if( team == 3 ) { // ct
			tiebreaker_score_t++;			
		}
		Scores_SetTeamScores( tiebreaker_score_ct, tiebreaker_score_t );
		Tiebreaker_TestWinCondition();

		if( tiebreaker_blip_cooldown <= 0 ) {
			EmitSoundToAll( "buttons/bell1.wav" );
			tiebreaker_blip_cooldown = 3;
		}

		if( !special_round_winner ) {
			Tiebreaker_RespawnPlayerDelayed( client );
		}
	}
}

//-------------------------------------------------------------------------------------------------
SpecialRound_PlayerSpawn( Handle:event ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId(userid);
	
	if( special_round_active == SPROUND_TIEBREAKER ) {

		TiebreakerTeleportPlayerRespawned( client );
	}


}

//-------------------------------------------------------------------------------------------------
SpecialRound_ClientConnected( client ) {
	if( special_round_active ) {

	//todo:message for each type of special round
		PrintToChat( client, "\x01\x0B\x04[PP] You have joined during the Bonus Round!" );
	}
}

//-------------------------------------------------------------------------------------------------
/*
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {

	if( tiebreaker_round_active ) {
		if( tiebreaker_started ) {
			new userid = GetEventInt( event, "userid" );
			new client = GetClientOfUserId( userid );
			TiebreakerTeleportPlayerLate( client );
		}
		
	}
}
*/

//-------------------------------------------------------------------------------------------------
SpawnVendingMachine( Float:dest[3], Float:angles[3] ) {
	
	new ent = CreateEntityByName( "prop_physics_override" );
	
	decl String:ent_name[24];
	Format( ent_name, sizeof( ent_name ), "vendingmachine%i", next_vending_machine );

	DispatchKeyValue( ent, "physdamagescale", "0.0" );
	DispatchKeyValue( ent, "model", vending_machine_model );
	DispatchKeyValue( ent, "targetname", ent_name );
	DispatchSpawn( ent );

	TeleportEntity( ent, dest, angles, NULL_VECTOR );
	SetEntityMoveType( ent, MOVETYPE_NONE );

}

//-------------------------------------------------------------------------------------------------
SpawnWeapon( Float:dest[3], const String:weapon_name[], bool:fall=false, clip1 = 0 ) {
	new ent = CreateEntityByName( weapon_name );

	DispatchSpawn( ent );

	SetEntData( ent, WEAPON_AMMO_BACKPACK,250 );

	if( clip1 != 0 ) {
		SetEntProp( ent, Prop_Data, "m_iClip1", clip1 );
	}
//	SetEntProp( ent, Prop_Data, "m_iClip2", 500 );  
	
	new Float:vel[3];
	if( !fall ) {
		vel[0] = GetRandomFloat(-220.0,220.0);
		vel[1] = GetRandomFloat(-220.0,220.0);
		vel[2] = 500.0;
		TeleportEntity( ent, dest, NULL_VECTOR, vel );
	} else {
		TeleportEntity( ent, dest, NULL_VECTOR, NULL_VECTOR );
	}
	
	//SetEntityGravity( ent, -1.0 ); this is not supposed to be here lol
}

//-------------------------------------------------------------------------------------------------
public Action:TimerWeaponSpawner( Handle:timer ) {
	
	if( !special_round_active ) {
		return Plugin_Stop;
	}

	
	
	new Float:dest[3] = {1029.0, -1517.4, -180.0};
	if( tiebreaker_weapon_counter < 70 ) {
		new index = GetRandomInt(0, sizeof(tiebreaker_weapon_ids)-1);
		new String:weapon_name[32];
		Format( weapon_name, 32, "weapon_%s", weaponNames[tiebreaker_weapon_ids[index]] );
		SpawnWeapon( dest, weapon_name );
	} else {
		SpawnWeapon( dest, "weapon_molotov" );
	}

	tiebreaker_weapon_counter++;
	if( tiebreaker_weapon_counter >= 90 ) {
	//	timer_guns = INVALID_HANDLE;
		return Plugin_Stop;
	}
	return Plugin_Handled;
}



new greyColor[4]	= {128, 128, 128, 255};
new redColor[4]	= {250, 22, 10, 255};
new orangeColor[4]	= {249, 136, 16, 255};

#define MORTAR_COUNT 5
#define MORTAR_DETONATE 6 // 3 SECONDS

SpawnLitGrenade( Float:vec[3] ) {
	/*
	new ent = CreateEntityByName( "hegrenade_projectile" );
	
	if( ent > 0 ) {
		//DispatchKeyValue( ent, "m_hThrower", "" );
		//DispatchKeyValue( ent, "m_bIsLive", "1" );
		//D//ispatchKeyValueFloat( ent, "m_flDetonateTime", fuse );
		//DispatchKeyValue( ent, "m_iszBounceSound", "" );

		//SetEntProp( ent, Prop_Data, "m_hThrower", INVALID_HANDLE );
		SetEntProp( ent, Prop_Data, "m_bIsLive", 1, 1 );
		SetEntPropFloat( ent, Prop_Data, "m_flDetonateTime", fuse );

		//SetEntProp( ent, Prop_Data, "m_hThrower", INVALID_HANDLE );

		DispatchSpawn( ent );
		ActivateEntity(ent);

		
	 
		TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR );
	}
	
	*/
	// just spawn an explosion instead
	
	new ent = CreateEntityByName("env_explosion");

	DispatchKeyValue(ent, "classname", "env_explosion");
	SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity",0); //Set the owner of the explosion
	SetEntProp(ent, Prop_Data, "m_iMagnitude",10000); //Set the owner of the explosion
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",175); //Set the owner of the explosion

	DispatchSpawn(ent);
	ActivateEntity(ent);

	decl String:exp_sample[64];

	Format( exp_sample, 64, "weapons\\hegrenade\\explode%d.wav", GetRandomInt( 3, 5 ) );

	EmitSoundToAll( exp_sample, ent, _, SNDLEVEL_GUNFIRE );

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}

//-------------------------------------------------------------------------------------------------
//
// marks zones and launches grenades
//
public Action:Timer_ActiveMortar( Handle:timer, Handle:data ) {
	
	if( !special_round_active ) {
		return Plugin_Stop;
	}
	
	ResetPack(data);

	
	new spawn_timer = ReadPackCell(data);

	new landing_index[MORTAR_COUNT];
	new Float:offsets[MORTAR_COUNT*2];

	for( new i = 0; i < MORTAR_COUNT; i++ ) {
		landing_index[i] = ReadPackCell(data);
		offsets[i*2] = ReadPackFloat(data);
		offsets[i*2+1] = ReadPackFloat(data);
	}
	/////////////////////////
	// inc spawn timer
	spawn_timer++;

	if( spawn_timer == MORTAR_DETONATE ) {
		// spawn grenade and stop

		for( new i = 0; i < MORTAR_COUNT; i++ ) {
			new Float:vec[3];
			vec[0] = TiebreakerMortarSpawns[landing_index[i]+0] + offsets[i*2];
			vec[1] = TiebreakerMortarSpawns[landing_index[i]+1] + offsets[i*2+1];
			vec[2] = TiebreakerMortarSpawns[landing_index[i]+2] + 20.0;

			SpawnLitGrenade( vec );
		}

		return Plugin_Stop;
	}

	ResetPack(data);
	WritePackCell(data, spawn_timer);
	

	for( new i = 0; i < MORTAR_COUNT; i++ ) {
		
		new Float:vec[3];
		vec[0] = TiebreakerMortarSpawns[landing_index[i]+0] + offsets[i*2];
		vec[1] = TiebreakerMortarSpawns[landing_index[i]+1] + offsets[i*2+1];
		vec[2] = TiebreakerMortarSpawns[landing_index[i]+2] + 20.0;
		
		TE_SetupBeamRingPoint(vec, 10.0, 220.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.75, 6.0, 0.0, orangeColor, 10, 0);
		TE_SendToAll();

		//TE_SetupBeamRingPoint(vec, 10.0, 220.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.75, 8.0, 0.0, orangeColor, 10, 0);
		//TE_SendToAll();
	 
		TE_SetupBeamRingPoint(vec, 10.0, 220.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.75, 12.0, 0.0, redColor, 10, 0);
		TE_SendToAll();
		
		
	}

	return Plugin_Handled;
	 
}

//-------------------------------------------------------------------------------------------------
//
// spawns death zones
//
public Action:Timer_Mortar( Handle:timer ) {


	if( !special_round_active ) {
		return Plugin_Stop;
	}

	
	new Handle:data;
	CreateDataTimer( 0.5, Timer_ActiveMortar, data, TIMER_REPEAT );
	WritePackCell( data, 0 ); // spawn timer

	for( new i = 0; i < MORTAR_COUNT; i++ ) {
		WritePackCell( data, GetRandomInt(0, sizeof(TiebreakerMortarSpawns) / 3 - 1 ) * 3 );
		WritePackFloat( data, GetRandomFloat( -80.0, 80.0 ) ); // offset x
		WritePackFloat( data, GetRandomFloat( -80.0, 80.0 ) ); // offset y
	}
	

	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
Float:SpreadPlayerPosition( Float:start, Float:end, Float:index, Float:count ) {

	new Float:middle = (start + end) / 2.0;
	new Float:ret = middle;

	if( index < 0.0 ) {
		return start + ((end-start) * GetRandomFloat());
	}

	if( count > 6.0 ) {
		// even spread
		ret = start + ((end-start) * index / (count - 1.0));
		
	} else {

		new Float:player_spacing = 50.0;
		// middle spread

		if( index == 0.0 ) {
			ret = middle;
		} else if( index == 1.0 ) {
			ret = middle + player_spacing;
		} else if( index == 2.0 ) {
			ret = middle - player_spacing;
		} else if( index == 3.0 ) {
			ret = middle + player_spacing*2;
		} else if( index == 4.0 ) {
			ret = middle - player_spacing*2;
		} else if( index == 5.0 ) {
			ret = middle + player_spacing*3;
		}

	}
	return ret;
}

//-------------------------------------------------------------------------------------------------
TiebreakerTeleportPlayers() {
	new Float:t_index=0.0, Float:ct_index=0.0;
	new maxclients = GetMaxClients();

	// get number of players
	new Float:num_t = 0.0, Float:num_ct = 0.0;
	for( new i = 1; i <= maxclients; i++ ) {
		if( IsClientConnected(i) && IsClientInGame(i) ) {
			new team = GetClientTeam(i);
			if( team == 2 ) { // T
				num_t += 1.0;
			} else if( team == 3 ) {
				num_ct += 1.0;
			}
		}
	}
	
	new Float:pos[3];
	new Float:ang[3] = {0.0, 0.0, 0.0};
	
	for( new i = 1; i <= maxclients; i++ ) {
		if( IsClientConnected(i) && IsClientInGame(i) ) {
			new team = GetClientTeam(i);
			if( team == 2 ) { // T
				pos[0] = SpreadPlayerPosition( TiebreakerSpawnPositionsT[0], TiebreakerSpawnPositionsT[4], t_index, num_t );
				pos[1] = TiebreakerSpawnPositionsT[1];
				pos[2] = TiebreakerSpawnPositionsT[2];
				ang[1] = TiebreakerSpawnPositionsT[3];
				t_index += 1.0;
				
				TeleportEntity( i, pos, ang, NULL_VECTOR );
				
			} else if( team == 3 ) { // CT
				pos[0] = SpreadPlayerPosition( TiebreakerSpawnPositionsCT[0], TiebreakerSpawnPositionsCT[4], ct_index, num_ct );
				pos[1] = TiebreakerSpawnPositionsCT[1];
				pos[2] = TiebreakerSpawnPositionsCT[2];
				ang[1] = TiebreakerSpawnPositionsCT[3];
				ct_index += 1.0;	
				
				TeleportEntity( i, pos, ang, NULL_VECTOR );
			}
		}
	}
 
}

//-------------------------------------------------------------------------------------------------
TiebreakerTeleportPlayerRespawned( client ) {
	new Float:pos[3];
	new Float:ang[3] = {0.0, 0.0, 0.0};

	new team = GetClientTeam(client);
	if( team == 2 ) { // T
		pos[0] = SpreadPlayerPosition( TiebreakerSpawnPositionsT[0], TiebreakerSpawnPositionsT[4], -1.0, 1.0 );
		pos[1] = TiebreakerSpawnPositionsT[1];
		pos[2] = TiebreakerSpawnPositionsT[2];
		ang[1] = TiebreakerSpawnPositionsT[3];
		
		TeleportEntity( client, pos, ang, NULL_VECTOR );
			
	} else if( team == 3 ) { // CT
		pos[0] = SpreadPlayerPosition( TiebreakerSpawnPositionsCT[0], TiebreakerSpawnPositionsCT[4], -1.0, 1.0 );
		pos[1] = TiebreakerSpawnPositionsCT[1];
		pos[2] = TiebreakerSpawnPositionsCT[2];
		ang[1] = TiebreakerSpawnPositionsCT[3];
		
		TeleportEntity( client, pos, ang, NULL_VECTOR );
	}
	
	if( tiebreaker_phase2 ) {
		ForcePlayerKnife( client );
	}
}

//-------------------------------------------------------------------------------------------------
public Action:TiebreakerTeleportPlayersTimer( Handle:timer ) {
	
	if( !special_round_active ) {
		return Plugin_Stop;
	}

	if( special_round_started ) {
		// ticks every half second

	//	if( tiebreaker_damage < 0.4 ) {
	//		tiebreaker_damage += 0.01; // 15 seconds for 0.4
	//	} else {
	//		tiebreaker_damage += 0.005; // 60 seconds for the rest
	//	}

	//	new tbd_percent = RoundToFloor(tiebreaker_damage * 100);
	//	if( tbd_percent >= tiebreaker_damage_percent_report ) {
	//		tiebreaker_damage_percent_report += 10;
	//		PrintToChatAll( "\x01\x0B\x07[PP] Damage Level: %d%%", tbd_percent );
	//	}

	//	SetConVarFloat( sm_pp_dmgscale, tiebreaker_damage );
	//	if( tiebreaker_damage >= TIEBREAKER_DAMAGE_SCALE_END ) {
	//		return Plugin_Stop;
	//	} else {
	//		return Plugin_Handled;
	//	}
		return Plugin_Stop;
	} else {
		TiebreakerTeleportPlayers();
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
PlaySpecialRoundSplash() {

	if( current_special_round == SPROUND_TIEBREAKER ) {
		new mc = GetMaxClients();
		for( new i = 1; i <= mc; i++ ) {
			if( IsClientConnected(i) ) {
				ClientCommand( i, TIEBREAKER_SPLASH_COMMAND );
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Action:SpecialRoundPrintTimer( Handle:timer ) {
	PrintCenterTextAll( "Bonus Round!" );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
/*
Tiebreaker_InitializeLives() {
	new maxc = GetMaxClients();
	for( new i = 1; i <= maxc; i++ ) {
		if( IsClientInGame(i) && IsPlayerAlive(i) ) {
			tiebreaker_lives[i] = TIEBREAKER_LIVES;
		} else {
			tiebreaker_lives[i] = -1;
		}
	}
}
*/
//-------------------------------------------------------------------------------------------------
SetupSpecialRound_Tiebreaker() {

	if( GetConVarBool( sm_pp_endtalk ) ) {
		EnableFulltalk();
	}

	TurnOffWinning();
	StopStartupMusic();

//	Tiebreaker_InitializeLives();

	tiebreaker_phase2 =0 ;
	tiebreaker_score_t = 0;
	tiebreaker_score_ct = 0;
	tiebreaker_blip_cooldown =0 ;

	tiebreaker_score_win = GetTeamClientCount( 2 ) + GetTeamClientCount( 3 );
	tiebreaker_score_win *= 3; // 3 for EXTRAFSAT
	if( tiebreaker_score_win > 100 ) tiebreaker_score_win = 100;

	CreateTimer( 1.5, SpecialRoundPrintTimer );

	PrintToChatAll( "[PP] Your health will regenerate during this round." );
	PrintToChatAll( "\x01\x0B\x04[PP] Welcome to the Bonus Round!" );
	PrintToChatAll( "\x01\x0B\x04[PP] First team to score %i points wins! (Look at the team scores!)", tiebreaker_score_win );
	PrintToChatAll( "\x01\x0B\x04[PP] Ranking and normal scores are not affected by this round." );
	//PrintToChatAll( "\x01\x0B\x07[PP] Damage Level: 20%%" );
	
	next_vending_machine = 0;
	tiebreaker_weapon_counter = 0;
	
	tiebreaker_damage = TIEBREAKER_DAMAGE_SCALE_START;
	tiebreaker_damage_percent_report = 30;
	//
	//
	//SetConVarBool( sm_pp_dmgscale_on, true );
	//SetConVarFloat( sm_pp_dmgscale, tiebreaker_damage );
	
	//StripGroundWeapons();
	
	for( new i = 0; i < sizeof(vending_machine_positions); i += 6 ) {
		new Float:dest[3];
		dest[0] = vending_machine_positions[i];
		dest[1] = vending_machine_positions[i+1];
		dest[2] = vending_machine_positions[i+2];
		new Float:angles[3];
		angles[0] = vending_machine_positions[i+3];
		angles[1] = vending_machine_positions[i+4];
		angles[2] = vending_machine_positions[i+5];
		SpawnVendingMachine( dest, angles );
	}

	{

		CreateTimer( 0.1, TimerWeaponSpawner, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );

		new Float:dest[3] = {576.0, -1409.0, -279.0};
		SpawnWeapon( dest, "weapon_negev", true, 2000 );

		new Float:dest2[3] = {1345.0, -1516.0, -265.0};
		SpawnWeapon( dest2, "weapon_negev", true, 2000 );


	}
	
	SetHealthRegen();

	TiebreakerTeleportPlayers();
	
	CreateTimer( 0.5, TiebreakerTeleportPlayersTimer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT );
	
	// unban negev
	Restrict_SetRestriction( WEAPON_NEGEV, CS_TEAM_T, -1 );
	Restrict_SetRestriction( WEAPON_NEGEV, CS_TEAM_CT, -1 );
	
	// disable damage report for this session
	ServerCommand( "sm_gem_dr_enable 0" );
	
}

//-------------------------------------------------------------------------------------------------
EndSpecialRound_Tiebreaker() {

	SetConVarBool( sm_pp_dmgscale_on, false );
	SetConVarFloat( sm_pp_dmgscale, 1.0 );
	SetConVarInt( mp_freezetime, default_mp_freezetime );
	SetConVarInt( mp_join_grace_time, default_mp_join_grace_time );
	
	
	// reban dat negev
	//Restrict_SetRestriction( WEAPON_NEGEV, CS_TEAM_T, 0 );
	//Restrict_SetRestriction( WEAPON_NEGEV, CS_TEAM_CT, 0 );
}

//-------------------------------------------------------------------------------------------------
//SetNextRoundTiebreaker() {
//	next_round_tiebreaker = 1;
//	SetConVarInt( mp_freezetime, 10 );
//	SetConVarInt( mp_join_grace_time, 0 );
//}

//-------------------------------------------------------------------------------------------------
SetupSpecialRound() {
	ServerCommand("sm_deathshot_enabled 0");
	current_special_round = next_round_special;
	next_round_special = 0;
	special_round_started = 0;
	special_round_active = 1;
	special_round_winner = 0;
	
	if( current_special_round == SPROUND_TIEBREAKER ) {
		SetupSpecialRound_Tiebreaker();
	}

	Scores_SaveAndReset();

	DisableRemoteLogging();
}

//-------------------------------------------------------------------------------------------------
SetNextRoundSpecial( index = 0 ) {
	if( index == 0 ) {
		next_round_special = GetRandomInt( 1, 1 + NUM_SPECIAL_ROUNDS-1 );
	} else {
		next_round_special = index;
	}
	SetConVarInt( mp_freezetime, 10 ); // todo: different times
	SetConVarInt( mp_join_grace_time, 0 );
	rounds_until_special = GetConVarInt( sm_pp_spround_interval );
}

//-------------------------------------------------------------------------------------------------
EndSpecialRound() {

	if( special_round_active ) {
		Scores_RestoreDelayed( 7.75 );
		ServerCommand("sm_deathshot_enabled 1");
	}
	
	TurnOnWinning();
	
	special_round_started = 0;
	special_round_active = 0;
	
	if( current_special_round == SPROUND_TIEBREAKER ) { 
		EndSpecialRound_Tiebreaker();
	}
	current_special_round = 0;
	
	ServerCommand( "sm_gem_dr_enable 1" );
	
	EnableRemoteLogging();
}

//-------------------------------------------------------------------------------------------------
EnableRemoteLogging() {
	if( logs_disabled ) {
		decl String:logaddress[256];
		GetConVarString( sm_pp_logaddress, logaddress, 256 );
		ServerCommand( "logaddress_delall" );
		ServerCommand( "logaddress_add %s", logaddress );
		logs_disabled = 0;
	}
}

//-------------------------------------------------------------------------------------------------
DisableRemoteLogging() {
	logs_disabled = 1;
	ServerCommand( "logaddress_delall" );
}

//-------------------------------------------------------------------------------------------------

//
// score save state
//
new score_frags[MAXPLAYERS+1];
new score_assists[MAXPLAYERS+1];
new score_deaths[MAXPLAYERS+1];
new score_cashspent[MAXPLAYERS+1];
new score_score[MAXPLAYERS+1];
new score_mvp[MAXPLAYERS+1];
new score_team_ct;
new score_team_t;

// NOTE: USING MANUAL DATA OFFSETS BELOW, VERIFY AFTER PATCHES



//-------------------------------------------------------------------------------------------------
Scores_ClientConnected( client ) {

	// reset score entry
	score_frags[client] = 0;
	score_assists[client] = 0;
	score_deaths[client] = 0;
	score_cashspent[client] = 0;
	score_score[client] = 0;
	score_mvp[client] = 0;
}

#define ASSISTS_OFFSET_FROM_FRAGS 4
#define SCORE_OFFSET_FROM_CONTROLLINGBOT -132
#define CASHSPENT_OFFSET_FROM_SCORE 20
#define MVP_OFFSET_FROM_SCORE -20
//-------------------------------------------------------------------------------------------------
Scores_SaveAndReset() {
 
	Scores_SaveTeamScore();
	Scores_SetTeamScores( 0, 0 );
	
	new max = GetMaxClients();
	for( new i = 1; i <= max; i++ ) {
		if( IsClientConnected(i) && IsClientInGame(i) ) {
			new assists_offset = FindDataMapOffs( i, "m_iFrags" ) + ASSISTS_OFFSET_FROM_FRAGS;

			score_frags[i]		= GetEntProp( i, Prop_Data, "m_iFrags" );
			score_assists[i]	= GetEntData( i, assists_offset );
			score_deaths[i]		= GetEntProp( i, Prop_Data, "m_iDeaths" );

			new score_offset = FindSendPropInfo( "CCSPlayer", "m_bIsControllingBot" ) + SCORE_OFFSET_FROM_CONTROLLINGBOT;
			score_score[i]		= GetEntData( i, score_offset );
			score_cashspent[i]	= GetEntData( i, score_offset + CASHSPENT_OFFSET_FROM_SCORE );
			score_mvp[i]	= GetEntData( i, score_offset + MVP_OFFSET_FROM_SCORE );
			

			Scores_SetPlayer( i, 0, 0, 0, 0, 0, 0 );
		}
	}
}

//-------------------------------------------------------------------------------------------------
Scores_SaveTeamScore() {
	score_team_ct = GetTeamScore( CS_TEAM_CT );
	score_team_t = GetTeamScore( CS_TEAM_T );
}

//-------------------------------------------------------------------------------------------------
Scores_SetTeamScores( ct, t ) {
	SetTeamScore( CS_TEAM_CT, ct );
	SetTeamScore( CS_TEAM_T, t );
}

//-------------------------------------------------------------------------------------------------
Scores_Restore() {

	Scores_SetTeamScores( score_team_ct, score_team_t );

	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientConnected(i) ) {
			Scores_SetPlayer( i, score_frags[i], score_assists[i], score_deaths[i], score_cashspent[i], score_score[i], score_mvp[i] );
		}
	}

	PrintToChatAll( "\x01\x0B\x04[PP] Your score has been restored." );
}

//-------------------------------------------------------------------------------------------------
public Action:Scores_RestoreDelayedTimer( Handle:timer ) {
	Scores_Restore();
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
Scores_RestoreDelayed( Float:time ) {
	// dont start a new match while this timer is active :)

	CreateTimer( time, Scores_RestoreDelayedTimer, _, TIMER_FLAG_NO_MAPCHANGE );
}

//-------------------------------------------------------------------------------------------------
Scores_SetPlayer( client, kills, assists, deaths, cashspent, score, mvps ) {
	if( !IsValidClient(client) ) return;
	
	new assists_offset = FindDataMapOffs( client, "m_iFrags" ) + ASSISTS_OFFSET_FROM_FRAGS;
	
	SetEntProp( client, Prop_Data, "m_iFrags", kills );
	SetEntData( client, assists_offset, assists );
	SetEntProp( client, Prop_Data, "m_iDeaths", deaths );
	new score_offset = FindSendPropInfo( "CCSPlayer", "m_bIsControllingBot" ) + SCORE_OFFSET_FROM_CONTROLLINGBOT;
	SetEntData( client, score_offset, score );
	SetEntData( client, score_offset + CASHSPENT_OFFSET_FROM_SCORE, cashspent );
	SetEntData( client, score_offset + MVP_OFFSET_FROM_SCORE, mvps );
	
 	
}

//-------------------------------------------------------------------------------------------------
Scores_ResetPlayer( client ) {
	// done with /resetscore or !resetscore in chat or resetscore in console

	if( !IsClientConnected(client) ) return;
	
	Scores_SetPlayer( client, 0, 0, 0, 0, 0, 0 );
	
	PrintToChat( client, "\x01\x0B\x04[PP] Your score has been reset. Good Luck!" );
}

//----------------------------------------------------------------------------------------------------------------------
// dominating module

Domination_NewPlayer( player ) {
	if( player > 0 ) {
		player--;
		for( new i = 0; i < MAXPLAYERS; i++ ) {
			dominating[player][i] = 0;
			dominating[i][player] = 0;
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
Domination_RegisterKill( player, target ) {
	if( player > 0 && target > 0 ) {
		player--;
		target--;
	} else {
		return 0;
	}

	new result = 0;

	decl String:player_name[64];
	decl String:target_name[64];

	GetClientName( player+1, player_name, 64 );
	GetClientName( target+1, target_name, 64 );

	dominating[player][target]++;
	if( dominating[player][target] >= dominating_threshold ) {
		result = 1;
		PrintToChat( player+1, "\x01\x0B\x04[PP] You are dominating %s! (%d)", target_name, dominating[player][target] );
		PrintToChat( target+1, "\x01\x0B\x07[PP] %s is dominating you! (%d)", player_name, dominating[player][target] );

		//SetEntProp( player+1, Prop_Send, "m_bPlayerDominated", 5, _, target+1 ); i tried :(
		//SetEntProp( target+1, Prop_Send, "m_bPlayerDominatingMe", 5, _, player+1 );
	}

	if( dominating[target][player] >= dominating_threshold ) {
		result = 2;
		PrintToChat( player+1, "\x01\x0B\x04[PP] You have gotten revenge on %s!", target_name );
		PrintToChat( target+1, "\x01\x0B\x07[PP] %s has gotten revenge on you!", player_name );

		//SetEntProp( player+1, Prop_Send, "m_bPlayerDominatingMe", 0, _, target+1 );
		//SetEntProp( target+1, Prop_Send, "m_bPlayerDominated", 0, _, player+1 );
	}

	dominating[target][player] = 0;
	
	return result;
}
