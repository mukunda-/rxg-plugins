
/*

printed after every kill:

xxx fragged yyy with zzz


printed after death or round end:

====================== RXG COMBAT LOG ======================

--- Victims --- *:killed, +:headshot --- (xxx damage total)
( )name: 159 in 11 | AK47 86dmg Legs/1/22 Chest/1/11 Arms/2/24 | Bizon 85dmg Chest/85 | HE 45dmg+22dmg+11dmg | Misc 14dmg

--- Attackers --- *=killer, +=headshot --- (xxx damage total)
(+)name: [AK47] Legs:1 Chest:1 Arms:2 [86 damage], [PP-Bizon] Chest:85 [85 damage], [HE] 81dmg+15dmg, [Misc] 1dmg

damage groups [GUN] [HE] [TASER] [KNIFE] [MISC]

--- Flashbangs --- (Toggle with !settings)
Flash 1: xxx (5.6) yyy (2.5) (1 good blind)
Flash 2: xxx (4.5) yyy (2.5) zzz (1.4) (1 good blind)

--- Session ---  K=kills,R=rounds,D=deaths,M=minutes
KILLS DEATHS K/D  K/R  DMG/R  DMG/D  HS   F/B  TIME  K/M  SUICIDE
25    10     2.5  5.0  500    9000   90%  2.5  2.5m  0.75 1
% DMGTYPE (TAKEN): Bullets: 0%, Grenades:98%, Fire:2%, Other:0%
% DMGTYPE (GIVEN): Bullets: 0%, Grenades:98%, Fire:2%, Other:0%

--- Total --- (use !rs to reset)
KILLS DEATHS K/D  K/R  DMG/R  DMG/D  HS   F/B  TIME  K/M  SUICIDE
25    10     2.5  5.0  500    9000   90%  2.5  2.5m  0.75 0
% DMGTYPE (TAKEN): Bullets: 0%, Grenades:98%, Fire:2%, Other:0%
% DMGTYPE (GIVEN): Bullets: 0%, Grenades:98%, Fire:2%, Other:0%

DATA REQUIRED for stats
total: kills, deaths, damage, headshots, rounds played, flashbangs thrown, people flashed, grenade dmg, fire dmg, bullet dmg, time played
*/


#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <cstrike_weapons>
#include <flashmod>

#pragma semicolon 1

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL "http://www.mukunda.com/plagins/combatlog/update.txt"

#define VERSION "1.3.0"

// 1.3.0
//   easier to disable panels
//   minor bugfix
//   panel fixes
// 1.2.0
//   LDR menu
//   !settings
//   improved formatting
// 1.1.5 ignore flashing spectators (!)
// 1.1.4 statchart alignment fix
// 1.1.3 sg553 name correction
// 1.1.2 kill menu adjustment
// 1.1.1 minor bugfix
// 1.1.0
//   total kill tracker
//   total kill menu
//   kill announcement in console
// 1.0.0
//   initial release

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Combat Log",
	author = "mukunda",
	description = "Extra combat information printed via console",
	version = VERSION,
	url = "www.mukunda.com"
};

new const String:print_weapon_names[_:WeaponID][] = 
{ 
	"???",			"P228",			"GLOCK",		"SCOUT",		
	"HE",			"XM1014",		"C4",			"MAC10",		
	"AUG",			"SMOKE",		"DUALIES",		"FIVESEVEN",
	"UMP",			"SG550",		"GALIL",		"FAMAS",
	"USP",			"AWP",			"MP5NAVY",		"M249",
	"M3",			"M4",			"TMP",			"G3SG1",
	"FLASHBANG",	"DEAGLE",		"SG552",		"AK47",
	"KNIFE",		"P90",			"SHIELD",		"VEST",			
	"VESTHELM",		"NVGS",			"GALILAR",		"BIZON",
	"MAG7",			"NEGEV",		"SAWEDOFF",		"TEC9",
	"TASER",		"P2000",		"MP7",			"MP9",
	"NOVA",			"P250",			"SCAR17",		"SCAR20",
	"SG553",		"SSG08",		"KNIFEGG",		"MOLOTOV",
	"DECOY",		"INCGRENADE",	"DEFUSER",
	
	"M4A1-S",
	"USP-S",
	"CZ75A"
};

//----------------------------------------------------------------------------------------------------------------------
new const String:hitgroup_names[][] = {
	"Head",
	"Arms",
	"Chest",
	"Stomach",
	"Legs"
};

//----------------------------------------------------------------------------------------------------------------------
enum {DATA_VERSION=1}; // for dealing with cookies, older versions must be converted

enum {
	STAT_KILLS,
	STAT_ASSISTS,
	STAT_DEATHS,
	STAT_DAMAGE,
	STAT_DAMAGETAKEN,
	STAT_HEADSHOTS,
	STAT_ROUNDS,
	STAT_FLASHES,  // incremented with each flashbang thrown
	STAT_FLASHED,  // total of all enemy blind duration, times 10 and converted to integer
	STAT_DMGGRENADES_GIVEN,
	STAT_DMGGRENADES_TAKEN,
	STAT_DMGFIRE_GIVEN,
	STAT_DMGFIRE_TAKEN,
	STAT_DMGBULLETS_GIVEN,
	STAT_DMGBULLETS_TAKEN,
	STAT_TIMEPLAYED,
	STAT_SUICIDE,
	STAT_COUNT
};

enum {
	STATS_SESSION,
	STATS_TOTAL,
	STATS_TYPE
}

//----------------------------------------------------------------------------------------------------------------------

new player_stats[MAXPLAYERS][STAT_COUNT][STATS_TYPE];
new bool:totals_loaded[MAXPLAYERS];

new bool:round_ended;
new bool:player_roundend[MAXPLAYERS+1]; // set after a players round is secured (and round counter incremented)
new Float:player_round_start[MAXPLAYERS+1]; // start of a player's round

new Handle:ldr_panels[MAXPLAYERS+1] = {INVALID_HANDLE,...};

new Handle:frags_panel = INVALID_HANDLE;

#define SOUND_BEEP "buttons/button24.wav"

#define MAX_PANEL_SIZE 15
#define LDR_PANEL_TIME 20

//----------------------------------------------------------------------------------------------------------------------
// round data, // target,weapon,hitgroups,dmg64

enum {
	HITGROUP_HEAD,
	HITGROUP_ARMS,
	HITGROUP_CHEST,
	HITGROUP_STOMACH,
	HITGROUP_LEGS,
	HITGROUP_COUNT
};

enum {
	HITDATA_TARGET,
	HITDATA_WEAPON,
	HITDATA_GROUPS,
	HITDATA_DMG=HITDATA_GROUPS+HITGROUP_COUNT,
	HITDATA_SIZE=HITDATA_DMG+HITGROUP_COUNT
};

enum {
	HITDATA_GIVEN,
	HITDATA_TAKEN
};

enum {
	KILLED_NO,
	KILLED_YES,
	KILLED_HS
};

new players_killed[MAXPLAYERS][MAXPLAYERS];

#define MAX_ENTRIES 64
#define MAX_WEAPONS 64
new String:hitdata_map[MAXPLAYERS][MAXPLAYERS][MAX_WEAPONS][2];
new hitdata[MAXPLAYERS][MAX_ENTRIES][HITDATA_SIZE][2];
new hitdata_entries[MAXPLAYERS][2];
new hitdata_hurt[MAXPLAYERS][MAXPLAYERS][2]; // hits
new hitdata_hurt_dmg[MAXPLAYERS][MAXPLAYERS][2]; // damage

#define HITDATA_STRINGSIZE 8

new hitdata_taser[MAXPLAYERS][MAXPLAYERS][2]; // contains total dmg
new hitdata_fire[MAXPLAYERS][MAXPLAYERS][2];
//new hitdata_misc[MAXPLAYERS][MAXPLAYERS][2]; // contains other damage that doesnt fall into any category (ie nade impact or fall damage) ... WHO CARES?
new String:hitdata_knife[MAXPLAYERS][MAXPLAYERS][2][HITDATA_STRINGSIZE]; // contains each knife hit damage as a string
new hitdata_knife_write[MAXPLAYERS][MAXPLAYERS][2];
new String:hitdata_he[MAXPLAYERS][MAXPLAYERS][2][HITDATA_STRINGSIZE]; // contains each HE hit as a string
new hitdata_he_write[MAXPLAYERS][MAXPLAYERS][2];
new String:hitdata_flash[MAXPLAYERS][MAXPLAYERS][2][HITDATA_STRINGSIZE];
new hitdata_flash_write[MAXPLAYERS][MAXPLAYERS][2];

new player_total_kills[MAXPLAYERS];
new player_total_hs[MAXPLAYERS];
new player_total_damage[MAXPLAYERS];

//new Handle:combatlog_show_top;
new Handle:combatlog_default_ldr;
new Handle:combatlog_default_endround;

new c_combatlog_default_ldr;
new c_combatlog_default_endround;

#define PREF_ENDROUND_DEFAULT 0
#define PREF_ENDROUND_NONE 1
#define PREF_ENDROUND_LDR 2
#define PREF_ENDROUND_FRAGS 3

#define PREF_LDR_DEFAULT 0 
#define PREF_LDR_NONE 1 
#define PREF_LDR_SHORT 2
#define PREF_LDR_FULL 3

new Handle:menu_ldrpref = INVALID_HANDLE;
new Handle:menu_endroundpref = INVALID_HANDLE;
new Handle:menu_prefs = INVALID_HANDLE;



//----------------------------------------------------------------------------------------------------------------------
new Handle:cookie_total; // cookie for total stats
new Handle:cookie_prefs; // cookie for preferences - format: "ab" a = '0,1,2,3' on death: default, dont show ldr, show short ldr, show full ldr, b = '0,1,2' default,show nothing,show ldr,show top players 

#define PREF_LDR 0
#define PREF_ENDROUND 1
new player_prefs[MAXPLAYERS+1][4];

//----------------------------------------------------------------------------------------------------------------------

public OnConVarChanged( Handle:convar, const String:oldval[], const String:newval[] ) {
	if( convar == combatlog_default_ldr ) {
		c_combatlog_default_ldr = GetConVarInt( combatlog_default_ldr );

	} else if( convar == combatlog_default_endround ) {
		c_combatlog_default_endround = GetConVarInt( combatlog_default_endround );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {
	CSWeapons_Init();
	
	SetupPrefMenus();
	
	cookie_total = RegClientCookie( "combatlog_totals", "combatlog data", CookieAccess_Private );
	cookie_prefs = RegClientCookie( "combatlog_prefs", "combatlog preferences", CookieAccess_Private );
	
	//combatlog_show_top = CreateConVar( "combatlog_show_top", "0", "Display top fraggers after each round.", FCVAR_PLUGIN );
	combatlog_default_ldr = CreateConVar( "combatlog_default_ldr", "0", "default LDR dipslay", FCVAR_PLUGIN );
	combatlog_default_endround = CreateConVar( "combatlog_default_endround", "0", "default endround display", FCVAR_PLUGIN );
	
	HookConVarChange( combatlog_default_ldr, OnConVarChanged );
	HookConVarChange( combatlog_default_endround, OnConVarChanged );
	
	c_combatlog_default_ldr = GetConVarInt( combatlog_default_ldr );
	c_combatlog_default_endround = GetConVarInt( combatlog_default_endround );
	
	
	HookEvent( "player_hurt", Event_PlayerHurt );
	HookEvent( "player_spawn", Event_PlayerSpawn );
	HookEvent( "player_death", Event_PlayerDeath );
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "round_end", Event_RoundEnd );
	
	RegConsoleCmd( "rs", Command_rs );
	RegConsoleCmd( "ldr", Command_ldr );
	
	// late load stuff
	for( new i = 1; i <= MaxClients; i++ ) {
		player_round_start[i] = GetGameTime();
		if( IsClientInGame(i) ) {
			if( AreClientCookiesCached(i) ) {
				
				LoadClientTotals(i);
			}
		}
	}
	
	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}
public OnMapStart() {
	PrecacheSound( SOUND_BEEP );
	Event_RoundStart( INVALID_HANDLE, "", false );
}
//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	// nobody likes old bacon
	if( StrEqual( name, "updater" ) ) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

//----------------------------------------------------------------------------------------------------------------------
LoadClientTotals(client) {
	decl String:totals[256];
	decl String:buffers[32][32];
	GetClientCookie( client, cookie_total, totals, sizeof totals );
	ExplodeString(totals, " ", buffers, sizeof buffers, sizeof buffers[] );
	
	new data_version = StringToInt( buffers[0] );
	if( data_version == DATA_VERSION ) {
		// current version, load data
		for( new i = 0; i < STAT_COUNT; i++ ) {
			player_stats[client][i][STATS_TOTAL] = StringToInt(buffers[i+1]);
		}
	} else {
		// older version, convert data
		
		// todo lol
		ClearTotalStats(client);
	}
	
	totals_loaded[client] = true;
}

//----------------------------------------------------------------------------------------------------------------------
SaveClientTotals(client) {
	decl String:totals[256];
	Format( totals, sizeof totals, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d", 
		DATA_VERSION,
		player_stats[client][STAT_KILLS][STATS_TOTAL],
		player_stats[client][STAT_ASSISTS][STATS_TOTAL],
		player_stats[client][STAT_DEATHS][STATS_TOTAL],
		player_stats[client][STAT_DAMAGE][STATS_TOTAL],
		player_stats[client][STAT_DAMAGETAKEN][STATS_TOTAL],
		player_stats[client][STAT_HEADSHOTS][STATS_TOTAL],
		player_stats[client][STAT_ROUNDS][STATS_TOTAL],
		player_stats[client][STAT_FLASHES][STATS_TOTAL],
		player_stats[client][STAT_FLASHED][STATS_TOTAL],
		player_stats[client][STAT_DMGGRENADES_GIVEN][STATS_TOTAL],
		player_stats[client][STAT_DMGGRENADES_TAKEN][STATS_TOTAL],
		player_stats[client][STAT_DMGFIRE_GIVEN][STATS_TOTAL],
		player_stats[client][STAT_DMGFIRE_TAKEN][STATS_TOTAL],
		player_stats[client][STAT_DMGBULLETS_GIVEN][STATS_TOTAL],
		player_stats[client][STAT_DMGBULLETS_TAKEN][STATS_TOTAL],
		player_stats[client][STAT_TIMEPLAYED][STATS_TOTAL],
		player_stats[client][STAT_SUICIDE][STATS_TOTAL] );
	
	SetClientCookie( client, cookie_total, totals );
}

//----------------------------------------------------------------------------------------------------------------------
ClearSessionStats(client) {
	
	for( new i = 0; i < STAT_COUNT; i++ ) {
		player_stats[client][i][STATS_SESSION] = 0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
ClearTotalStats(client) {
	
	for( new i = 0; i < STAT_COUNT; i++ ) {
		player_stats[client][i][STATS_TOTAL] = 0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected(client) {
	ClearSessionStats(client);
	player_roundend[client] = true;
	totals_loaded[client] = false;
	if( ldr_panels[client] != INVALID_HANDLE ) {
		CloseHandle( ldr_panels[client] );
	}
	ldr_panels[client] = INVALID_HANDLE;
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientDisconnect(client) {
	// treat as a round end for the client
	SaveClientTotals(client);
}

LoadPlayerPrefs( client ) {
	decl String:cookie[64];
	GetClientCookie( client, cookie_prefs, cookie,sizeof(cookie) );
	if( strlen( cookie ) < 2 ) {
		player_prefs[client][0] = 0;
		player_prefs[client][1] = 0;
		player_prefs[client][2] = 0;
		player_prefs[client][3] = 0;
	} else {
		player_prefs[client][0] = cookie[0] - '0';
		player_prefs[client][1] = cookie[1] - '0';
		player_prefs[client][2] = 0;
		player_prefs[client][3] = 0;
	}
}

SavePlayerPrefs(client) {
	decl String:cookie[64];
	Format(  cookie, sizeof(cookie), "%c%c%c%c", '0'+player_prefs[client][0], '0'+player_prefs[client][1], '0'+player_prefs[client][2], '0'+player_prefs[client][3] );
	SetClientCookie( client, cookie_prefs, cookie );
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientCookiesCached(client) {
	
	LoadClientTotals(client);
	LoadPlayerPrefs(client);
}

//----------------------------------------------------------------------------------------------------------------------
ClampDivide( a, b ) {
	if( b < 1 ) b = 1;
	return a/b;
}

//----------------------------------------------------------------------------------------------------------------------
Float:FClampDivide( Float:a, Float:b ) {
	if( b < 1.0 ) b = 1.0;
	return a/b;  
}

//----------------------------------------------------------------------------------------------------------------------
FormatTimePlayed( value, String:output[], maxlen ) {
	if( value < 60 ) {
		// seconds
		Format( output, maxlen, "%ds", value );
	} else if( value < 60*60 ) {
		// minutes
		Format( output, maxlen, "%.1fm", float(value)/60.0 );
	} else if( value < 60*60*24 ) {
		// hours
		Format( output, maxlen, "%.1fh", float(value)/(60.0*60.0) );
	} else {
		// days
		Format( output, maxlen, "%.1fd", float(value)/(60.0*60.0*24.0) );
	}
}

//----------------------------------------------------------------------------------------------------------------------
PrintShit( client, type, String:paneltext[], panelmaxlen, &panelwrite, &panel_entries ) {

	
	
	
	decl String:data[4096];
	//decl String:paneltext[4096];
	//paneltext[0] = 0;
	//new panelwrite = 0;
	//new panel_entries = 0;
	
	data[0] = 0;
	new datawrite = 0;
	
	
	new total_damage = 0;
	new total_entries = 0;
	
	new ecount = hitdata_entries[client][type];
	for( new target = 0; target <= MaxClients; target++ ) {
		if( !hitdata_hurt[client][target][type] ) continue;
		total_entries++;
		
		data[datawrite++] = ' ';
		if( type == HITDATA_GIVEN ) {
			if( players_killed[client][target] == 0 ) {
				data[datawrite++] = '-'; data[datawrite++] = ' ';
				paneltext[panelwrite++] = '-'; paneltext[panelwrite++] = '-';
			} else if( players_killed[client][target] == KILLED_YES ) {
				data[datawrite++] = 'X'; data[datawrite++] = ' ';
				paneltext[panelwrite++] = 'X'; paneltext[panelwrite++] = ' ';
			} else if( players_killed[client][target] == KILLED_HS ) {
				data[datawrite++] = 'X'; data[datawrite++] = '+';
				paneltext[panelwrite++] = 'X'; paneltext[panelwrite++] = ' ';
			}
		} else {
			if( players_killed[target][client] == 0 ) {
				data[datawrite++] = '-'; data[datawrite++] = ' ';
				paneltext[panelwrite++] = '-'; paneltext[panelwrite++] = '-';
			} else if( players_killed[target][client] == KILLED_YES ) {
				data[datawrite++] = 'X'; data[datawrite++] = ' ';
				paneltext[panelwrite++] = 'X'; paneltext[panelwrite++] = ' ';
			} else if( players_killed[target][client] == KILLED_HS ) {
				data[datawrite++] = 'X'; data[datawrite++] = '+';
				paneltext[panelwrite++] = 'X'; paneltext[panelwrite++] = ' ';
			}
		}
		
		if( target == 0 ) {
			datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "World" );
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "World" );
		} else if( IsClientInGame(target) ) {
			datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "%N", target );
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "%N", target );
		} else {
			datawrite += strcopy( data[datawrite], sizeof data-datawrite, "???" );
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "???" );
		}
		
		datawrite += FormatEx( data[datawrite], sizeof data-datawrite, " [%d dmg, %d hits]\n   ", hitdata_hurt_dmg[client][target][type], hitdata_hurt[client][target][type] - hitdata_flash_write[client][target][type] );
		panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, " [%d dmg, %d hits]", hitdata_hurt_dmg[client][target][type], hitdata_hurt[client][target][type] - hitdata_flash_write[client][target][type] );
		paneltext[panelwrite++] = 0;
		paneltext[panelwrite++] = ' ';
		paneltext[panelwrite++] = ' ';
		paneltext[panelwrite++] = ' ';
		
		//new p = hitdata_hurt[client][target][type];
		new printed_sections = 0;
		
		for( new e = 0; e < ecount; e++ ) {
			if( hitdata[client][e][HITDATA_TARGET][type] == target ) {
				if( printed_sections != 0 ) {
					datawrite += strcopy( data[datawrite], sizeof data-datawrite, " |" );
					panelwrite += strcopy( paneltext[panelwrite], panelmaxlen-panelwrite, " ," );
				}
				data[datawrite++] = ' ';
				datawrite += strcopy( data[datawrite], sizeof data-datawrite, print_weapon_names[hitdata[client][e][HITDATA_WEAPON][type]] );
				panelwrite += strcopy( paneltext[panelwrite], panelmaxlen-panelwrite, print_weapon_names[hitdata[client][e][HITDATA_WEAPON][type]] );
				
				new damage = 0;//, hits = 0;
				for( new hit = 0; hit < HITGROUP_COUNT; hit++ ) {
					damage += hitdata[client][e][HITDATA_DMG+hit][type];
					//hits += hitdata[client][e][HITDATA_GROUPS+hit][type];
				}
				total_damage += damage;
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, " %ddmg", damage );
				
				for( new hit = 0; hit < HITGROUP_COUNT; hit++ ) {
					if( hitdata[client][e][HITDATA_GROUPS+hit][type] ) {
						datawrite += FormatEx( data[datawrite], sizeof data-datawrite, " %s:%d for %d", hitgroup_names[hit], hitdata[client][e][HITDATA_GROUPS+hit][type], hitdata[client][e][HITDATA_DMG+hit][type] );
						panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, " %s:%d", hitgroup_names[hit], hitdata[client][e][HITDATA_GROUPS+hit][type], hitdata[client][e][HITDATA_DMG+hit][type] );
					}
				}
				printed_sections++;
			}
		}
		
		if( hitdata_he_write[client][target][type] ) {
			if( printed_sections != 0 ) {
				datawrite += strcopy( data[datawrite], sizeof data-datawrite, " | HE " );
				panelwrite += strcopy( paneltext[panelwrite], panelmaxlen-panelwrite, ", HE " );
			} else {
				datawrite += strcopy( data[datawrite], sizeof data-datawrite, "HE " );
				panelwrite += strcopy( paneltext[panelwrite], panelmaxlen-panelwrite, "HE " );
			}
			
			new count = hitdata_he_write[client][target][type];
			new he_damage = 0;
			for( new grenade = 0; grenade < count; grenade++ ) {
				if( grenade!=0 ) {
					data[datawrite++] = '+';
				}
				new damage = hitdata_he[client][target][type][grenade];
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "%d", damage );
				he_damage += damage;
				total_damage += damage;
			}
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "%ddmg", he_damage );
			
			printed_sections++;
			
		}
		
		if( hitdata_knife_write[client][target][type] ) {
			if( printed_sections != 0 ) {
				datawrite += strcopy( data[datawrite], sizeof data-datawrite, " | Knife " );
				panelwrite += strcopy( paneltext[panelwrite], panelmaxlen-panelwrite, ", Knife" );
			} else {
				datawrite += strcopy( data[datawrite], sizeof data-datawrite, "Knife" );
				panelwrite += strcopy( paneltext[panelwrite], panelmaxlen-panelwrite, "Knife" );
			}
			
			new count = hitdata_knife_write[client][target][type];
			new dmg = 0;
			for( new stab = 0; stab < count; stab++ ) {
				if( stab!=0 ) {
					data[datawrite++] = '+';
				}
				new damage = hitdata_knife[client][target][type][stab];
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "%d", damage );
				dmg += dmg;
				total_damage += damage;
			}
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "%ddmg (%d swings)", dmg, count );
			
			printed_sections++;
		}
		
		if( hitdata_taser[client][target][type] ) {
			new damage = hitdata_taser[client][target][type];
			if( printed_sections != 0 ) {
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, " | Taser %d", damage );
				panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, ", Taser %ddmg", damage );
			} else {
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "Taser %d", damage );
				panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "Taser %ddmg", damage );
			}
			total_damage += damage;
			printed_sections++;
		}
		
		if( hitdata_flash_write[client][target][type] ) {
			if( printed_sections != 0 ) {
				datawrite += strcopy( data[datawrite], sizeof data-datawrite,  " |" );
				panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "," );
			}
			datawrite += strcopy( data[datawrite], sizeof data-datawrite, "Flashed " );
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "Flashed " );

			new count = hitdata_flash_write[client][target][type];
			new Float:total= 0.0;
			for( new flash = 0; flash < count; flash++ ) {
				if( flash!=0 ) {
					data[datawrite++] = ',';
				}
				new Float:duration = float(hitdata_flash[client][target][type][flash])/10.0;
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "%.1fs", duration );
				total += duration;
			}
			panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "%.1fs", total );
			printed_sections++;
		}
		
		if( hitdata_fire[client][target][type] ) {
			new damage = hitdata_fire[client][target][type];
			if( printed_sections != 0 ) {
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, " | Fire %d", damage );
				panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, ", Fire %ddmg", damage );
			} else {
				datawrite += FormatEx( data[datawrite], sizeof data-datawrite, "Fire %d", damage );
				panelwrite += FormatEx( paneltext[panelwrite], panelmaxlen-panelwrite, "Fire %ddmg", damage );
			}
			total_damage += damage;
			printed_sections++;
		}
		data[datawrite++] = '\n';
		paneltext[panelwrite++] = 0;
		panel_entries++;
	}
	data[datawrite++] = 0;
	if( total_entries == 0 ) return;
	
	decl String:killstring[32];
	killstring[0] = 0;
	if( type == 0 ) FormatEx( killstring, sizeof(killstring), " (%d kills)", player_total_kills[client] );
	PrintToConsole( client, "%s (%d damage total)%s\n------------------------------------\n%s", type == 0 ? "Victims" : "Attackers", total_damage,killstring,data );
	
	
	 
}

//----------------------------------------------------------------------------------------------------------------------
PrintStats( client, const String:header[], type ) { 
	decl String:timeplayed[8];
	FormatTimePlayed( player_stats[client][STAT_TIMEPLAYED][type], timeplayed, sizeof(timeplayed) );
	decl String:text[1020];
	
	new deaths = player_stats[client][STAT_DEATHS][type];
	new rounds = player_stats[client][STAT_ROUNDS][type];
	Format( text, sizeof text, "\
%s\n\
KILLS | ASSISTS | DEATHS | ROUNDS | K/D  | K/R  | DMG/D | DMG/R | HS  | F/B  | TIME  | K/M  | SUICIDES\n\
%-5d | %-7d | %-6d | %-6d | %-4.2f | %-4.2f | %-5d | %-5d | %2d%% | %-.2f | %-5s | %-.2f | %-5d",
	header,
	player_stats[client][STAT_KILLS][type],
	player_stats[client][STAT_ASSISTS][type],
	deaths,
	rounds,
	FClampDivide( float(player_stats[client][STAT_KILLS][type]), float(deaths) ),
	FClampDivide( float(player_stats[client][STAT_KILLS][type]), float(rounds) ),
	ClampDivide( player_stats[client][STAT_DAMAGE][type], deaths ),
	ClampDivide( player_stats[client][STAT_DAMAGE][type], rounds ),
	ClampDivide( player_stats[client][STAT_HEADSHOTS][type]*100, player_stats[client][STAT_KILLS][type] ),
	
	FClampDivide( float(player_stats[client][STAT_FLASHED][type]), float(player_stats[client][STAT_FLASHES][type])*10 ), // f/b
	
	timeplayed,
	FClampDivide( float(player_stats[client][STAT_KILLS][type]*60), float(player_stats[client][STAT_TIMEPLAYED][type]) ),
	player_stats[client][STAT_SUICIDE][type]
);
	//ReplaceString( text, sizeof text, "|", "a\xE2\x94\x82" );

	PrintToConsole( client, "%s", text );
	
	
	new Float:fdmg = float(player_stats[client][STAT_DAMAGE][type]);
	new Float:fdmgt = float(player_stats[client][STAT_DAMAGETAKEN][type]);
	if( fdmg == 0.0 ) fdmg = 1.0;
	if( fdmgt == 0.0 ) fdmgt = 1.0;
	
	PrintToConsole( client, "\
%%Dmg Given: Bullets: %.2f%% | Grenades: %.2f%% | Fire: %.2f%%\n\
%%Dmg Taken: Bullets: %.2f%% | Grenades: %.2f%% | Fire: %.2f%%\n",
		float(player_stats[client][STAT_DMGBULLETS_GIVEN][type]*100) / fdmg,
		float(player_stats[client][STAT_DMGGRENADES_GIVEN][type]*100) / fdmg,
		float(player_stats[client][STAT_DMGFIRE_GIVEN][type]*100) / fdmg,
	
		float(player_stats[client][STAT_DMGBULLETS_TAKEN][type]*100) / fdmgt,
		float(player_stats[client][STAT_DMGGRENADES_TAKEN][type]*100) / fdmgt,
		float(player_stats[client][STAT_DMGFIRE_TAKEN][type]*100) / fdmgt );
	
	
}

//----------------------------------------------------------------------------------------------------------------------
CreateLDRPanel( client, const String:paneltext[], entries_vic, entries_att ) {
	new total;
	new read=  0;
	new Handle:panel = ldr_panels[client];
	
	new bool:short;
	short = (entries_vic*2 + entries_att*2 + (entries_vic>0?1:0) + (entries_att>0?1:0)) >= MAX_PANEL_SIZE;
	new pref = player_prefs[client][PREF_LDR];
	if( pref == PREF_LDR_DEFAULT ) pref = c_combatlog_default_ldr;
	if( pref == PREF_LDR_SHORT ) short = true;
	
	decl String:text[256];
	
	if( entries_vic > 0 ) {
		
		FormatEx(text,sizeof(text),"Victims (%d dmg, %d kills)", player_total_damage[client], player_total_kills[client] );
		DrawPanelItem( panel, text );
		total++;
		
		for( new i = 0; i < entries_vic; i++ ) {
			if( total >= MAX_PANEL_SIZE ) return;
			DrawPanelText( panel, paneltext[read] );
			read += strlen(paneltext[read])+1;
			total++;
			
			if( short ) {
				read += strlen(paneltext[read])+1; /// skip hitdata in short mode
			} else {
				if( total >= MAX_PANEL_SIZE ) return;
				DrawPanelText( panel, paneltext[read] );
				read += strlen(paneltext[read])+1;
			}
			
		}
	}
		
	if( entries_att > 0 ) {
		
		if( total >= MAX_PANEL_SIZE ) return;
		FormatEx(text,sizeof(text),"Attackers" );
		DrawPanelItem( panel, text );
		total++;
		
		for( new i = 0; i < entries_att; i++ ) {
			if( total >= MAX_PANEL_SIZE ) return;
			DrawPanelText( panel, paneltext[read] );
			read += strlen(paneltext[read])+1;
			total++;
			
			if( short ) {
				read += strlen(paneltext[read])+1; /// skip hitdata in short mode
			} else {
				if( total >= MAX_PANEL_SIZE ) return;
				DrawPanelText( panel, paneltext[read] );
				read += strlen(paneltext[read])+1;
			}
			
		}
	}
	
	if( total >= MAX_PANEL_SIZE ) return;
	if( total == 0 ) {
		CloseHandle(ldr_panels[client]);
		ldr_panels[client] = INVALID_HANDLE;
		return;
	}
	if( total < 5 ) {
		DrawPanelItem( panel, "Exit.");
	}
	//DrawPanelItem( panel, "Exit." );
	SetPanelCurrentKey( panel, 9 );
	DrawPanelItem( panel, "Don't show again.");
}

//----------------------------------------------------------------------------------------------------------------------
ShowLDRPanel(client) {
	if( !IsClientInGame(client) ) return;
	if( IsFakeClient(client) ) return;
	if( ldr_panels[client] == INVALID_HANDLE ) return;
	SendPanelToClient( ldr_panels[client], client, PanelHandlerLDR, LDR_PANEL_TIME );
}
 
//----------------------------------------------------------------------------------------------------------------------
PrintCombatLog( client ) {
	if( !IsClientInGame(client) ) return;
	if( IsFakeClient(client) ) return;
	PrintToConsole( client, "====================== RXG COMBAT LOG v%s ======================\n", VERSION );
	if( ldr_panels[client] != INVALID_HANDLE ) {
		CloseHandle(ldr_panels[client]);
	}
	ldr_panels[client] = CreatePanel();
	
	decl String:paneltext[4096];
	new panelwrite= 0;
	paneltext[panelwrite] = 0;
	new panel_entries_vic;
	new panel_entries_att;
	 
	PrintShit( client, HITDATA_GIVEN, paneltext, sizeof paneltext, panelwrite, panel_entries_vic );
	PrintShit( client, HITDATA_TAKEN, paneltext, sizeof paneltext, panelwrite, panel_entries_att );
	PrintStats( client, "--- Session ---  K=kills,R=rounds,D=deaths", STATS_SESSION );
	PrintStats( client, "--- Total ---  (!rs to reset)", STATS_TOTAL );
	
	CreateLDRPanel( client, paneltext, panel_entries_vic, panel_entries_att );
 
	
}

//----------------------------------------------------------------------------------------------------------------------
bool:EndPlayerRound( client, bool:printlog=true ) {
	if( player_roundend[client] ) return false;
	player_roundend[client] = true;
	new time = RoundToNearest(GetGameTime() - player_round_start[client]);
	player_stats[client][STAT_TIMEPLAYED][STATS_SESSION] += time;
	player_stats[client][STAT_TIMEPLAYED][STATS_TOTAL] += time;
	
	player_stats[client][STAT_ROUNDS][STATS_SESSION]++;
	player_stats[client][STAT_ROUNDS][STATS_TOTAL]++;
	
	if( printlog ) {
		PrintCombatLog( client );
	}
	
	return true;
}
 
//----------------------------------------------------------------------------------------------------------------------
new hitgroup_translator[] = {HITGROUP_HEAD,HITGROUP_CHEST,HITGROUP_STOMACH,HITGROUP_ARMS,HITGROUP_ARMS,HITGROUP_LEGS,HITGROUP_LEGS};
TranslateHitgroup( hitgroup ) {
	if( hitgroup > 6 || hitgroup < 0 ) return HITGROUP_CHEST;
	return hitgroup_translator[hitgroup-1];
}

//----------------------------------------------------------------------------------------------------------------------
RegisterWeaponHit( attacker, victim, WeaponID:id, damage, hitgroup ) {
	hitgroup = TranslateHitgroup(hitgroup);
	new entry = hitdata_map[attacker][victim][id][HITDATA_GIVEN];
	if( entry == 0 ) {
		if( hitdata_entries[attacker][HITDATA_GIVEN] < MAX_ENTRIES ) { // catch data overflow and skip reg
			entry = hitdata_map[attacker][victim][id][HITDATA_GIVEN] = ++hitdata_entries[attacker][HITDATA_GIVEN]; // we want +1, so pre-increment
			hitdata[attacker][entry-1][HITDATA_TARGET][HITDATA_GIVEN] = victim;
			hitdata[attacker][entry-1][HITDATA_WEAPON][HITDATA_GIVEN] = _:id;
			for( new i = 0; i < HITGROUP_COUNT; i++ ) {
				hitdata[attacker][entry-1][HITDATA_GROUPS+i][HITDATA_GIVEN] = 0;
				hitdata[attacker][entry-1][HITDATA_DMG+i][HITDATA_GIVEN] = 0;
			}
			
			
		}
	}
	if( entry != 0 ) {
		entry--; 
		hitdata[attacker][entry][HITDATA_GROUPS+hitgroup][HITDATA_GIVEN]++;
		hitdata[attacker][entry][HITDATA_DMG+hitgroup][HITDATA_GIVEN] += damage;
	}
	
	entry = hitdata_map[victim][attacker][id][HITDATA_TAKEN];
	if( entry == 0 ) {
		if( hitdata_entries[victim][HITDATA_TAKEN] < MAX_ENTRIES ) { // catch data overflow and skip reg
			entry = hitdata_map[victim][attacker][id][HITDATA_TAKEN] = ++hitdata_entries[victim][HITDATA_TAKEN]; // we want +1, so pre-increment
			
			hitdata[victim][entry-1][HITDATA_TARGET][HITDATA_TAKEN] = attacker;
			hitdata[victim][entry-1][HITDATA_WEAPON][HITDATA_TAKEN] = _:id;
			for( new i = 0; i < HITGROUP_COUNT; i++ ) {
				hitdata[victim][entry-1][HITDATA_GROUPS+i][HITDATA_TAKEN] = 0;
				hitdata[victim][entry-1][HITDATA_DMG+i][HITDATA_TAKEN] = 0;
			}
		}
	}
	if( entry != 0 ) {
		entry--;
		
		hitdata[victim][entry][HITDATA_GROUPS+hitgroup][HITDATA_TAKEN]++;
		hitdata[victim][entry][HITDATA_DMG+hitgroup][HITDATA_TAKEN] += damage;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerHurt( Handle:event, const String:n[], bool:db ){
	if( round_ended ) return;
	
	// dmg_health, hitgroup, userid, attacker, weapon
	new dmg_health = GetEventInt(event,"dmg_health");
	if( dmg_health == 0 ) return;
	new hitgroup = GetEventInt(event, "hitgroup");
	new attacker = GetEventInt( event, "attacker" );
	if( attacker ) attacker = GetClientOfUserId(attacker);
	new victim = GetEventInt( event, "userid" );
	if( victim ) victim = GetClientOfUserId( victim );
	
	hitdata_hurt[attacker][victim][HITDATA_GIVEN]++;
	hitdata_hurt_dmg[attacker][victim][HITDATA_GIVEN]+=dmg_health;
	hitdata_hurt[victim][attacker][HITDATA_TAKEN]++;
	hitdata_hurt_dmg[victim][attacker][HITDATA_TAKEN]+=dmg_health;
	
	player_stats[attacker][STAT_DAMAGE][STATS_SESSION] += dmg_health; // clamp against player health?
	player_stats[attacker][STAT_DAMAGE][STATS_TOTAL] += dmg_health;
	player_stats[victim][STAT_DAMAGETAKEN][STATS_SESSION] += dmg_health;
	player_stats[victim][STAT_DAMAGETAKEN][STATS_TOTAL] += dmg_health;
	
	player_total_damage[attacker] += dmg_health;
	
	decl String:weapon[64];
	GetEventString( event, "weapon", weapon, sizeof weapon );
	
	
	if( StrEqual(weapon,"inferno") ) {
		hitdata_fire[attacker][victim][HITDATA_GIVEN] += dmg_health;
		hitdata_fire[victim][attacker][HITDATA_TAKEN] += dmg_health;
		
		player_stats[attacker][STAT_DMGFIRE_GIVEN][STATS_SESSION] += dmg_health;
		player_stats[attacker][STAT_DMGFIRE_GIVEN][STATS_TOTAL] += dmg_health;
		player_stats[victim][STAT_DMGFIRE_TAKEN][STATS_SESSION] += dmg_health;
		player_stats[victim][STAT_DMGFIRE_TAKEN][STATS_TOTAL] += dmg_health;
		return;
	}
	new WeaponID:wid = GetWeaponID( weapon );
	
	if( wid == WEAPON_HEGRENADE ) {
		if( hitdata_he_write[attacker][victim][HITDATA_GIVEN] < HITDATA_STRINGSIZE ) {
			hitdata_he[attacker][victim][HITDATA_GIVEN][hitdata_he_write[attacker][victim][HITDATA_GIVEN]++] = dmg_health;
		}
		if( hitdata_he_write[victim][attacker][HITDATA_TAKEN] < HITDATA_STRINGSIZE ) {
			hitdata_he[victim][attacker][HITDATA_TAKEN][hitdata_he_write[victim][attacker][HITDATA_TAKEN]++] = dmg_health;
		}
		
		player_stats[attacker][STAT_DMGGRENADES_GIVEN][STATS_SESSION] += dmg_health;
		player_stats[attacker][STAT_DMGGRENADES_GIVEN][STATS_TOTAL] += dmg_health;
		player_stats[victim][STAT_DMGGRENADES_TAKEN][STATS_SESSION] += dmg_health;
		player_stats[victim][STAT_DMGGRENADES_TAKEN][STATS_TOTAL] += dmg_health;
		return;
	}
	
	if( wid == WEAPON_KNIFE ) {
		if( hitdata_knife_write[attacker][victim][HITDATA_GIVEN] < HITDATA_STRINGSIZE ) {
			hitdata_knife[attacker][victim][HITDATA_GIVEN][hitdata_knife_write[attacker][victim][HITDATA_GIVEN]++] = dmg_health;
		}
		if( hitdata_knife_write[victim][attacker][HITDATA_TAKEN] < HITDATA_STRINGSIZE ) {
			hitdata_knife[victim][attacker][HITDATA_TAKEN][hitdata_knife_write[victim][attacker][HITDATA_TAKEN]++] = dmg_health;
		}
		return;
	}
	
	if( wid == WEAPON_TASER ) {
		hitdata_taser[attacker][victim][HITDATA_GIVEN] += dmg_health;
		hitdata_taser[victim][attacker][HITDATA_TAKEN] += dmg_health;
		return;
	}
	
	new WeaponSlot:ws = GetSlotFromWeaponID( wid );
	
	if( ws == SlotPrimmary || ws == SlotPistol ) {
		// actual weapon
		RegisterWeaponHit( attacker, victim, wid, dmg_health, hitgroup );
		player_stats[attacker][STAT_DMGBULLETS_GIVEN][STATS_SESSION] += dmg_health;
		player_stats[attacker][STAT_DMGBULLETS_GIVEN][STATS_TOTAL] += dmg_health;
		player_stats[victim][STAT_DMGBULLETS_TAKEN][STATS_SESSION] += dmg_health;
		player_stats[victim][STAT_DMGBULLETS_TAKEN][STATS_TOTAL] += dmg_health;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:n[], bool:db ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	player_round_start[client] = GetGameTime();
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:n[], bool:db ) {
	new attacker = GetEventInt( event, "attacker" );
	//attacker = 0;//GetClientOfUserId( attacker_id );
	
	new assister = GetEventInt( event, "assister" );
	if( assister ) assister = GetClientOfUserId( assister );
	
	
	
	if(attacker != 0) {
		attacker = GetClientOfUserId( attacker );
		if( !attacker ) return;
	}
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	
	new bool:headshot = GetEventBool( event, "headshot" );
	if( victim == 0 ) return;
 
	
	if( attacker == 0 ) {
		PrintToConsoleAll( "%N died.", victim );
	} else if ( attacker == victim ) {
		PrintToConsoleAll( "%N commit suicide.", victim );
	} else {
		decl String:weapon[64];
		GetEventString( event, "weapon", weapon, sizeof weapon );
		new WeaponID:id = GetWeaponID( weapon) ;
		if( id != WEAPON_NONE ) {
			PrintToConsoleAll( "%N killed %N with %s%s.", attacker,victim,print_weapon_names[id],headshot?" (headshot)":"" );
		}
	}
	
	if( round_ended ) return;
	
	if( assister != 0 ) {
		player_stats[assister][STAT_ASSISTS][STATS_SESSION]++;
		player_stats[assister][STAT_ASSISTS][STATS_TOTAL]++;
	}
	
	players_killed[attacker][victim] = headshot ? KILLED_HS : KILLED_YES;

	if( attacker != victim ) {
		player_stats[attacker][STAT_KILLS][STATS_SESSION]++;
		player_stats[attacker][STAT_KILLS][STATS_TOTAL]++;
		player_total_kills[attacker]++;
	} else {
		player_stats[attacker][STAT_SUICIDE][STATS_SESSION]++;
		player_stats[attacker][STAT_SUICIDE][STATS_TOTAL]++;
	}
	player_stats[victim][STAT_DEATHS][STATS_SESSION]++;
	player_stats[victim][STAT_DEATHS][STATS_TOTAL]++;
	
	
	if( headshot ) {
		player_stats[attacker][STAT_HEADSHOTS][STATS_SESSION]++;
		player_stats[attacker][STAT_HEADSHOTS][STATS_TOTAL]++;
		player_total_hs[attacker]++;
	}
	
	EndPlayerRound( victim );
	if( IsFakeClient(victim) ) return;
	
	new pref = player_prefs[victim][PREF_LDR];
	if( pref == PREF_LDR_DEFAULT ) pref = c_combatlog_default_ldr;
	if( pref >= PREF_LDR_SHORT )
		ShowLDRPanel(victim);
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundEnd( Handle:event, const String:n[], bool:db ){
	round_ended = true;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		EndPlayerRound( i );
	}
	
	PrepTopFraggersMenu();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( IsFakeClient(i) ) continue;
		new pref = player_prefs[i][PREF_ENDROUND];
		if( pref == PREF_ENDROUND_DEFAULT ) pref = c_combatlog_default_endround;
		
		if( pref == PREF_ENDROUND_LDR ) {
			if( IsPlayerAlive(i) ) ShowLDRPanel(i);
		} else if( pref == PREF_ENDROUND_FRAGS ) {
			if( frags_panel == INVALID_HANDLE ) continue;
			SendPanelToClient(frags_panel, i, PanelHandlerEndround, 10);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:n[], bool:db ) {
	round_ended = false;
	// todo: fast way to clear all of this data, right now this could take a few hundred milliseconds?
	
	// clear damage data
	for( new i = 0; i <= MaxClients; i++ ) {
	 
		
		player_roundend[i] = false;
		if( i != 0 && IsClientInGame(i) && totals_loaded[i] ) {
			SaveClientTotals(i);
		}
		hitdata_entries[i][HITDATA_GIVEN] = 0;
		hitdata_entries[i][HITDATA_TAKEN] = 0;
		player_total_kills[i] = 0;
		player_total_hs[i] = 0;
		player_total_damage[i] = 0;
		
		for( new j = 0; j <= MaxClients; j++ ) {
			for( new k = 0; k < MAX_WEAPONS; k++ ) {
				hitdata_map[i][j][k][HITDATA_GIVEN] = 0;
				hitdata_map[i][j][k][HITDATA_TAKEN] = 0;
			}
		}
		
		for( new j = 0; j <= MaxClients; j++ ) {
			hitdata_taser[i][j][HITDATA_GIVEN] = 0;
			hitdata_taser[i][j][HITDATA_TAKEN] = 0;
			hitdata_fire[i][j][HITDATA_GIVEN] = 0;
			hitdata_fire[i][j][HITDATA_TAKEN] = 0;
			//hitdata_misc[i][j][HITDATA_GIVEN] = 0;
			//hitdata_misc[i][j][HITDATA_TAKEN] = 0;
			hitdata_knife[i][j][HITDATA_GIVEN][0] = 0;
			hitdata_knife[i][j][HITDATA_TAKEN][0] = 0;
			hitdata_he[i][j][HITDATA_GIVEN][0] = 0;
			hitdata_he[i][j][HITDATA_TAKEN][0] = 0;
			hitdata_flash[i][j][HITDATA_GIVEN][0] = 0;
			hitdata_flash[i][j][HITDATA_TAKEN][0] = 0;
			
			hitdata_knife_write[i][j][HITDATA_GIVEN] = 0;
			hitdata_knife_write[i][j][HITDATA_TAKEN] = 0;
			
			hitdata_he_write[i][j][HITDATA_GIVEN] = 0;
			hitdata_he_write[i][j][HITDATA_TAKEN] = 0;
			
			hitdata_flash_write[i][j][HITDATA_GIVEN] = 0;
			hitdata_flash_write[i][j][HITDATA_TAKEN] = 0;
			
			hitdata_hurt[i][j][HITDATA_GIVEN] = 0;
			hitdata_hurt[i][j][HITDATA_TAKEN] = 0;
			hitdata_hurt_dmg[i][j][HITDATA_GIVEN] = 0;
			hitdata_hurt_dmg[i][j][HITDATA_TAKEN] = 0;
			
			players_killed[i][j] = KILLED_NO;
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_rs( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( !totals_loaded[client] ) {
		PrintToChat( client, "\x01 \x07An error occurred, please contact an admin if it persists." );
		return Plugin_Handled;
	}
	ClearTotalStats(client);
	PrintToChat( client, "\x01 \x0BCombat Stats Reset." );
	return Plugin_Handled;
}

public Action:Command_ldr( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	if( ldr_panels[client] ) {
		ShowLDRPanel(client);
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Flashmod_FlashbangStats( flasher, enemies_flashed, team_flashed, Float:enemies_duration_sum, Float:team_duration_sum ) {
	if( round_ended ) return;
	new duration = RoundToNearest(enemies_duration_sum*10);
	player_stats[flasher][STAT_FLASHES][STATS_SESSION]++;
	player_stats[flasher][STAT_FLASHED][STATS_SESSION] += duration;
	
	player_stats[flasher][STAT_FLASHES][STATS_TOTAL]++;
	player_stats[flasher][STAT_FLASHED][STATS_TOTAL] += duration;
}

//-------------------------------------------------------------------------------------------------
public Action:Flashmod_OnPlayerFlashed( flasher, flashee, &Float:alpha, &Float:duration ) {
	if( round_ended ) return Plugin_Continue;
	if( !IsPlayerAlive(flashee) ) return Plugin_Continue; // skip "spectator flashes"
	if( GetClientTeam(flasher) == GetClientTeam(flashee) ) return Plugin_Continue; // skip teamflashes
	
	if( hitdata_flash_write[flasher][flashee][HITDATA_GIVEN] < HITDATA_STRINGSIZE ) {
		hitdata_flash[flasher][flashee][HITDATA_GIVEN][hitdata_flash_write[flasher][flashee][HITDATA_GIVEN]++] = RoundToNearest(duration*10);
		hitdata_hurt[flasher][flashee][HITDATA_GIVEN]++;
	}
	if( hitdata_flash_write[flashee][flasher][HITDATA_TAKEN] < HITDATA_STRINGSIZE ) {
		hitdata_flash[flashee][flasher][HITDATA_TAKEN][hitdata_flash_write[flashee][flasher][HITDATA_TAKEN]++] = RoundToNearest(duration*10);
		hitdata_hurt[flashee][flasher][HITDATA_TAKEN]++;
	}
	return Plugin_Continue;
}
//-------------------------------------------------------------------------------------------------
public PanelHandlerLDR(Handle:menu, MenuAction:action, param1, param2)
{
	if( action == MenuAction_Select ) {
		if( param2 == 9 ) {
			// disable menu
			PrintToChat( param1, "\x01 \x04Damage report disabled. Enable again in !settings." );
			player_prefs[param1][PREF_LDR] = PREF_LDR_NONE;
			SavePlayerPrefs(param1);
			EmitSoundToClient( param1, SOUND_BEEP );
		}
	}
}
//-------------------------------------------------------------------------------------------------
public PanelHandlerEndround(Handle:menu, MenuAction:action, param1, param2)
{
	if( action == MenuAction_Select ) {
		if( param2 == 9 ) {
			// disable menu
			PrintToChat( param1, "\x01 \x04Endround report disabled. Enable again in !settings." );
			player_prefs[param1][PREF_ENDROUND] = PREF_ENDROUND_NONE;
			SavePlayerPrefs(param1);
			EmitSoundToClient( param1, SOUND_BEEP );
		}
	}
}

//-------------------------------------------------------------------------------------------------
PrepTopFraggersMenu() {

	if( frags_panel != INVALID_HANDLE )
		CloseHandle(frags_panel);
	frags_panel = INVALID_HANDLE;
	
	new list[MAXPLAYERS+1];
	new total = 0;
	for( new i = 1; i <= MaxClients;i++ ){
		if( !IsClientInGame(i) ) continue;
		if( player_total_kills[i] > 0 ) {
			list[total++] = i + (player_total_kills[i] << 8);
		}
	}
	if( total == 0 ) return;
	
	SortIntegers( list, total, Sort_Descending );
	
	frags_panel = CreatePanel();
	SetPanelTitle(frags_panel, "Top Players:");
	
	for( new i = 0; i < total && i < 5; i++ ) {
		decl String:entry[64];
		new source = list[i]&255;
		FormatEx(entry, sizeof entry, "%s%N: %d Kills (%d HS), %ddmg", IsFakeClient(source)?"BOT ":"",source, player_total_kills[source], player_total_hs[source], player_total_damage[source] );
		DrawPanelItem(frags_panel, entry);
	} 
	SetPanelCurrentKey( frags_panel, 9 );
	DrawPanelItem(frags_panel, "Don't show again.");
}

//-------------------------------------------------------------------------------------------------
stock PrintToConsoleAll(const String:format[], any:...)
{
	decl String:buffer[192];
	VFormat(buffer, sizeof(buffer), format, 2);
			
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;
		PrintToConsole(i, "%s", buffer);
	}
}

//=================================================================================================
// cookie menu

public LDRPrefsHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	decl String:info[32];
	new bool:found = GetMenuItem(menu, param2, info, sizeof(info));
	
	if( action == MenuAction_DrawItem ) {
		
		new index = StringToInt(info);
		if( player_prefs[param1][PREF_LDR] == index ) {
			return ITEMDRAW_DISABLED;
		} else {
			return ITEMDRAW_DEFAULT;
		}
	} else if( action == MenuAction_Select ) { 
		
		
		if( found ) {
			/* Tell the client */
			player_prefs[param1][PREF_LDR] = StringToInt(info);
			PrintToChat(param1, "Changed LDR Display Setting." );
			SavePlayerPrefs(param1);
		}
	}
	return 0;
}

public EndroundPrefsHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	decl String:info[32];
	new bool:found = GetMenuItem(menu, param2, info, sizeof(info));
	
	if( action == MenuAction_DrawItem ) {

		new index = StringToInt(info);
		if( player_prefs[param1][PREF_ENDROUND] == index ) {
			return ITEMDRAW_DISABLED;
		} else {
			return ITEMDRAW_DEFAULT;
		}
	} else if( action == MenuAction_Select ) { 
		
		if( found ) {
			/* Tell the client */
			player_prefs[param1][PREF_ENDROUND] = StringToInt(info);
			PrintToChat(param1, "Changed Endround Display Setting." );
			SavePlayerPrefs(param1);
		}
	}
	return 0;
}


public PrefsHandler( Handle:menu, MenuAction:action, param1, param2 ) {
	
		
	if( action == MenuAction_Select ) {
		if( !AreClientCookiesCached(param1) ) return 0;
		decl String:info[32];
 
		/* Get item info */
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info));
		
		if( found ) {
			if( StrEqual( info, "ldr" ) ) {
				DisplayMenu( menu_ldrpref, param1, MENU_TIME_FOREVER );
			} else if ( StrEqual( info, "end" ) ) {
				DisplayMenu( menu_endroundpref, param1, MENU_TIME_FOREVER );
			}
		}
		
	}
	return 0;
}

public CookieHandlerMain( client, CookieMenuAction:action, any:info, String:buffer[], maxlen ) {

	if( action == CookieMenuAction_DisplayOption ) {

	} else if( action == CookieMenuAction_SelectOption ) {

		DisplayMenu( menu_prefs, client, MENU_TIME_FOREVER );
	}
}

SetupPrefMenus() {
	menu_prefs = CreateMenu(PrefsHandler);
	SetMenuTitle( menu_prefs, "Damage Report Settings" );
	AddMenuItem( menu_prefs, "ldr", "LDR Display" );
	AddMenuItem( menu_prefs, "end", "Endround Display" );
	
	menu_ldrpref=  CreateMenu( LDRPrefsHandler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem );
	SetMenuTitle( menu_ldrpref, "LDR Display" );
	AddMenuItem( menu_ldrpref, "0", "Default" );
	AddMenuItem( menu_ldrpref, "1", "Disabled" );
	AddMenuItem( menu_ldrpref, "2", "Short" );
	AddMenuItem( menu_ldrpref, "3", "Full" );
	
	menu_endroundpref = CreateMenu( EndroundPrefsHandler, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem );
	SetMenuTitle( menu_endroundpref, "Endround Display" );
	AddMenuItem( menu_endroundpref, "0", "Default" );
	AddMenuItem( menu_endroundpref, "1", "Disabled" );
	AddMenuItem( menu_endroundpref, "2", "Show LDR" );
	AddMenuItem( menu_endroundpref, "3", "Show Top Frags" );
	
	SetCookieMenuItem( CookieHandlerMain, 0, "Damage Report" );
}
