
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <cstrike_weapons> // weapon restrict (utilities)
#include <restrict>
#include <dropgrenade>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name        = "rxg-weapons",
	author      = "REFLEX",
	description = "Weapon purchasing management.",
	version     = "1.3.2",
	url         = "www.reflex-gamers.com"
};

// ----------------------------------------------------------------------------

// A trie that maps similar weapons from the opposite team
// e.g. "m4a1" -> "ak47", "mp9" -> "mac10", etc and vice versa
//
Handle g_weapon_opposites = null;

// Player ammo table indexes.
//
enum {
	AMMO_INDEX_HE=14,
	AMMO_INDEX_FLASH,
	AMMO_INDEX_SMOKE,
	AMMO_INDEX_FIRE,
	AMMO_INDEX_DECOY
};

// Grenades get locked after a player throws one. When locked they cannot
// purchase any more.
//
int g_nades_locked[MAXPLAYERS+1];

// Time before the grenade lock becomes activated
int g_nades_graceperiod;

// convar handles
Handle ammo_grenade_limit_default;
Handle ammo_grenade_limit_flashbang;
Handle ammo_grenade_limit_total;
Handle mp_buytime;
Handle rxg_auto_rebuy;

// cached convar values
int c_ammo_grenade_limit_default;
int c_ammo_grenade_limit_flashbang;
int c_ammo_grenade_limit_total;

// indexes for the rebuy data
enum {
	REBUY_MAIN,			// MAIN WEAPON	  (id) updated on buy primary
	REBUY_PISTOL,		// PISTOL WEAPON  (id) updated on buy pistol
	REBUY_TASER,		// TASER	      (bool) updated on buy zues
	REBUY_HE,			// HEGRENADES	  (count) updated on buy grenade
	REBUY_FLASH,		// FLASHBANGS	  (count) updated on buy grenade
	REBUY_SMOKE,		// SMOKEGRENADES  (count) updated on buy grenade
	REBUY_MOLOTOV,		// MOLOTOVS       (count) updated on buy grenade
	REBUY_DECOY,		// DECOYS         (count) updated on buy grenade
	REBUY_COUNT
};

// this maps a rebuy data index to a grenade id
CSWeaponID RebuyGrenadeIDs[] = { 
	CSWeapon_NONE, CSWeapon_NONE, CSWeapon_NONE,
	CSWeapon_HEGRENADE, CSWeapon_FLASHBANG, CSWeapon_SMOKEGRENADE,
	CSWeapon_MOLOTOV, CSWeapon_DECOY
};

// saved player loadouts 
int g_rebuy_data[MAXPLAYERS+1][REBUY_COUNT]; 

// if they used rebuy this round yet
bool g_rebuy_used[MAXPLAYERS+1];

// price of each weapon
int WeaponPrices[CSWeaponID] = {
	0,200,200,1700,300,2000,0,1050,
	3300,300,500,500,1200,3300,2000,
	2250,200,4750,1700,5200,1200,3100,
	1050,5000,200,700,3000,2700,0,
	2350,0,650,1000,1000,2000,1400,
	1800,5700,1200,500,400,200,1700,
	1250,1200,300,5000,5000,3000,
	1700,0,400,50,600,400 // might have been a good idea to make this
	                      // more readable.
};

// if they are using rebuy (and g_rebuy_data should not be updated.)
bool g_rebuy_in_progress[MAXPLAYERS+1]; 

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	InitOppositeMap();
	
	HookEvent( "round_start",      OnRoundStart );
	HookEvent( "round_freeze_end", OnFreezeEnd ); 
	
	// hook the rebuy command
	RegConsoleCmd( "rebuy", Command_Rebuy );
	
	
	ammo_grenade_limit_default   = FindConVar( "ammo_grenade_limit_default" );
	ammo_grenade_limit_flashbang = FindConVar( "ammo_grenade_limit_flashbang" );
	ammo_grenade_limit_total     = FindConVar( "ammo_grenade_limit_total" );
	
	rxg_auto_rebuy = CreateConVar( "rxg_auto_rebuy", "1", 
		"Auto-rebuy for players who afk during the buy period.", 
		FCVAR_PLUGIN );
		
	mp_buytime = FindConVar( "mp_buytime" );
	
	HookConVarChange( ammo_grenade_limit_default,   OnCVarChanged );
	HookConVarChange( ammo_grenade_limit_flashbang, OnCVarChanged );
	HookConVarChange( ammo_grenade_limit_total,     OnCVarChanged );
	
	CacheCVars();
	
	// hook existing clients for late load
	for( int i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		SDKHook( i, SDKHook_WeaponDropPost, OnWeaponDrop );
	}
}

//-----------------------------------------------------------------------------
bool IsValidClient( int client ) {
	return ( client > 0 && client <= MaxClients && IsClientInGame(client) );
}

//-----------------------------------------------------------------------------
void CacheCVars() {
	c_ammo_grenade_limit_default   = GetConVarInt( ammo_grenade_limit_default );
	c_ammo_grenade_limit_flashbang = GetConVarInt( ammo_grenade_limit_flashbang );
	c_ammo_grenade_limit_total     = GetConVarInt( ammo_grenade_limit_total );
}

//-----------------------------------------------------------------------------
public void OnCVarChanged( Handle convar, const char[] oldValue, 
						   const char[] newValue ) {
	CacheCVars();
}

/** ---------------------------------------------------------------------------
 * Map weapons to each other in the opposite trie.
 *
 * @param weapon1 Weapon ID to map.
 * @param weapon2 Weapon ID to map to, and vice versa.
 */
void MapOpposite( CSWeaponID weapon1, CSWeaponID weapon2 ) {
	
	char str[64];
	
	FormatEx( str, sizeof str, "%s", weapon1 );
	SetTrieValue( g_weapon_opposites, str, weapon2 );
	
	FormatEx( str, sizeof str, "%s", weapon2 );
	SetTrieValue( g_weapon_opposites, str, weapon1 );
}

/** ---------------------------------------------------------------------------
 * Build the opposite weapons map.
 */
void InitOppositeMap() {
	g_weapon_opposites = CreateTrie();
	
	MapOpposite( CSWeapon_AUG,        CSWeapon_SG556    );
	MapOpposite( CSWeapon_FAMAS,      CSWeapon_GALILAR  );
	MapOpposite( CSWeapon_M4A1,       CSWeapon_AK47     );
	MapOpposite( CSWeapon_SCAR20,     CSWeapon_G3SG1    );
	MapOpposite( CSWeapon_MAG7,       CSWeapon_SAWEDOFF );
	MapOpposite( CSWeapon_FIVESEVEN,  CSWeapon_TEC9     );
	MapOpposite( CSWeapon_MP9,        CSWeapon_MAC10    );
	MapOpposite( CSWeapon_INCGRENADE, CSWeapon_MOLOTOV  );
	
	// hack this up too. (need to remove const from cstrike_weapons.inc)
	BuyTeams[WEAPON_ELITE] = BOTHTEAMS;
}

/** ---------------------------------------------------------------------------
 * Clear the rebuy data for a client (for when they connect)
 */
void ResetRebuyData( int client ) {
	for( int i = 0; i < REBUY_COUNT; i++ ) {
		g_rebuy_data[client][i] = 0;
	}
}

//-----------------------------------------------------------------------------
public void OnClientPutInServer( int client ) {
	ResetRebuyData( client );
	g_nades_locked[client] = false;
	g_rebuy_used[client] = true;
	SDKHook( client, SDKHook_WeaponDropPost, OnWeaponDrop );
}

/** ---------------------------------------------------------------------------
 * Check if a weapon is only usable on the opposite team, and try to remap
 * it to a usable one.
 *
 * @param client The player who is trying to buy a weapon.
 * @param from   The weapon ID they want to purchase.
 *
 * @returns The original weapon ID if it is purchasable, a similar ID if 
 *          it was not purchasable on his team, or CSWeapon_NONE if the
 *          weapon is not purchasable and there is no similar mapping.
 */
CSWeaponID TranslateWeaponForTeam( int client, CSWeaponID from ) {
	int team = GetClientTeam( client );
	bool canbuy = BuyTeams[from] == team || BuyTeams[from] == BOTHTEAMS;
	
	if( !canbuy ) {
		// try to find similar
		char from_string[64];
		FormatEx( from_string, sizeof from_string, "%s", from );
		int similar;
		if( !GetTrieValue( g_weapon_opposites, from_string, similar )) {
		
			// no similar mapped. cannot buy.
			return CSWeapon_NONE;
		}
		
		return view_as<CSWeaponID>similar;
	} else {
	
		// already purchasable 
		return from;
	}
}

/** ---------------------------------------------------------------------------
 * @returns The total number of grenades a player has.	
 */
int TotalGrenades( int client ) {
	if( !IsClientInGame( client )) return 0;

	return GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE    )
	     + GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FLASH )
		 + GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_SMOKE )
		 + GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FIRE  )
		 + GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_DECOY );
}

/** ---------------------------------------------------------------------------
 * @returns The game's ammo index for a grenade weapon ID.
 */
int AmmoIndexForID( CSWeaponID id ) {
	if( id == CSWeapon_HEGRENADE    ) return AMMO_INDEX_HE   ;
	if( id == CSWeapon_FLASHBANG    ) return AMMO_INDEX_FLASH;
	if( id == CSWeapon_MOLOTOV      ) return AMMO_INDEX_FIRE ;
	if( id == CSWeapon_INCGRENADE   ) return AMMO_INDEX_FIRE ;
	if( id == CSWeapon_SMOKEGRENADE ) return AMMO_INDEX_SMOKE;
	if( id == CSWeapon_DECOY        ) return AMMO_INDEX_DECOY;
	
	return 0;
}

/** ---------------------------------------------------------------------------
 * Checks if a player can buy a grenade.
 *
 * @param client Player to test.
 * @param id     WeaponID of grenade. If not a grenade ID, true will always
 *               be returned.
 * 
 * @returns true if the player can purchase this grenade type. false if the
 *          player has too many total or cannot carry any more of that type.
 */
bool CanBuyGrenade( int client, CSWeaponID id ) {
	WeaponType type = weaponGroups[ id ];
	if( type != WeaponTypeGrenade ) return true;
	
	if( TotalGrenades( client ) >= c_ammo_grenade_limit_total ) {
		return false;
	}
	
	int ammo_index = AmmoIndexForID( id );
	int limit = id == CSWeapon_FLASHBANG ? c_ammo_grenade_limit_flashbang 
	                                     : c_ammo_grenade_limit_default;
	
	if( GetEntProp( client, Prop_Send, "m_iAmmo", _, ammo_index ) >= limit ) {
		// cannot carry any more of this type
		return false;
	}
	
	return true;
}

/** ---------------------------------------------------------------------------
 * Checks if a player is allowed to buy a grenade.
 *
 * @param client Player to check.
 * @param id     Grenade ID. If not a grenade, will always return FALSE.
 * 
 * @returns true if the player should be blocked from buying the weapon.
 */
bool GrenadeLimited( int client, CSWeaponID id ) {
	
	if( g_nades_locked[client] && weaponGroups[id] == WeaponTypeGrenade ) {
		
		PrintToChat( client, 
		    "You may not purchase more grenades this round." );
		
		return true;
	}
		
	return false;
}

//-----------------------------------------------------------------------------
public Action CS_OnBuyCommand( int client, const char[] weapon ) {
	if( !IsValidClient( client )) return Plugin_Continue;
	
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) {
		return Plugin_Continue;
	}
	
	// get the weapon ID
	char real_name[64];
	CS_GetTranslatedWeaponAlias( weapon, real_name, sizeof real_name );

	// SPECIAL FIXES
	if( StrEqual( real_name, "cutters" ) ) real_name = "defuser"; 
	if( StrEqual( real_name, "cz75a" ) )   real_name = "tec9"; // tec9 because fivseven has problems.
	
	CSWeaponID id = CS_AliasToWeaponID( real_name );
	
	// catch invalid weapon name.
	if( id == CSWeapon_NONE ) return Plugin_Continue;
	
	// TODO verify all weapons being translated correctly.
	
	// catch invalid weapon name.
	if( id == CSWeapon_NONE ) return Plugin_Continue; 
	
	// catch weapons that aren't in the game.
	if( AllowedGame[id] != 3 && AllowedGame[id] != 1 ) return Plugin_Continue;

	// catch trying to buy opposing team's weapons (and remap)
	id = TranslateWeaponForTeam( client, id );
	if( id == CSWeapon_NONE ) return Plugin_Handled;
	
	// from here on we have a valid weapon ID that they want to purchase...
	if( WeaponPrices[id] > GetEntProp( client, Prop_Send, "m_iAccount" )) {
		
		// cannot afford.
		// this will print a insufficient funds message
		return Plugin_Continue;
	}
	
	if( !CanBuyGrenade( client, id )) {
		// will print "you cant carry anymore"
		return Plugin_Continue; 
	}
	
	// block players from buying too many special grenades.
	if( GrenadeLimited( client, id ) ) {
		return Plugin_Handled;
	}

	if( g_rebuy_in_progress[client] ) {
		// dont update loadout if they are rebuying.
		return Plugin_Continue;
	}		
	
	// update the client's rebuy loadout.
	UpdateLoadout( client, id );
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public void OnWeaponDrop( int client, int weapon ) {
	if( !IsPlayerAlive( client )) return;
	
	char name[32];
	GetEntityClassname( weapon, name, sizeof name );
	if( strncmp( name, "weapon_", 7 ) != 0 ) return;
	
	char real_name[32];
	CS_GetTranslatedWeaponAlias( name[7], real_name, sizeof real_name );
	
	CSWeaponID id = CS_AliasToWeaponID( real_name );
	if( id == CSWeapon_NONE ) return;
	
	if( weaponGroups[id] == WeaponTypeGrenade ) {
	
		if( !DropGrenadeCheck() && !g_nades_graceperiod ) {
			g_nades_locked[client] = true;
		}
	}
}
 
/** ---------------------------------------------------------------------------
 * Scan the grenades a player has equipped and save them in the
 * rebuy data.
 */
void SaveClientGrenades( int client ) {
	if( !IsClientInGame( client )) return;

	for( int i = 0; i < 5; i++ ) {
		g_rebuy_data[client][REBUY_HE+i] = 
			GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE+i );
	}
}
 
/** ---------------------------------------------------------------------------
 * Update a client's loadout for next round.
 *
 * @param client  Index of client.
 * @param id      ID of weapon that they bought.
 */
void UpdateLoadout( int client, CSWeaponID id ) {
	WeaponType weapon_type = weaponGroups[id];
	
	if( !g_rebuy_used[client] ) {
		g_rebuy_used[client] = true;
		ResetRebuyData( client );
	}
	
	if( weapon_type == WeaponTypeTaser ) {
		    
		g_rebuy_data[client][REBUY_TASER] = 1;
		
	} else if( weapon_type == WeaponTypeGrenade ) {
		
		if( id == CSWeapon_INCGRENADE ) id = CSWeapon_MOLOTOV;
		int ammo_index = AmmoIndexForID( id );
		SaveClientGrenades( client );
		
		// grenade data is currently set to what they have equipped
		// increment the slot that they are currently purchasing.
		g_rebuy_data[client][REBUY_HE+(ammo_index-AMMO_INDEX_HE)]++;
		
	} else if( weapon_type == WeaponTypeSMG 
	        || weapon_type == WeaponTypeShotgun 
			|| weapon_type == WeaponTypeRifle // (any primary)
			|| weapon_type == WeaponTypeSniper 
			|| weapon_type == WeaponTypeMachineGun ) {
		
		if( id == CSWeapon_G3SG1 || id == CSWeapon_SCAR20
		    || id == CSWeapon_AWP || id == CSWeapon_NEGEV ) {
			// kind of hacky, but an easy solution
			// we dont want to be giving them these weapons.
			
			return;
		}
		
		g_rebuy_data[client][REBUY_MAIN] = view_as<int>(id);
		
	} else if( weapon_type == WeaponTypePistol ) {
	
		g_rebuy_data[client][REBUY_PISTOL] = view_as<int>(id);
	}
}

//-----------------------------------------------------------------------------
public void OnRoundStart( Handle event, const char[] name, bool db ) {
	
	for( int i = 1; i <= MaxClients; i++ ) {
		g_rebuy_used[i] = false;
		g_nades_locked[i] = false;
	}
	
	g_nades_graceperiod = true;
	
	if( GetConVarBool( rxg_auto_rebuy )) {
		CreateTimer( GetConVarFloat( mp_buytime ) - 5.0, 
					 DoAutoRebuy, _, TIMER_FLAG_NO_MAPCHANGE );
	}
}

//-----------------------------------------------------------------------------
public Action DoAutoRebuy( Handle timer ) {
	for( int i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i)   // is connected
			|| IsFakeClient(i)   // is not a bot
			|| !IsPlayerAlive(i) // is alive
			|| !GetEntProp( i, Prop_Send, "m_bInBuyZone" ) // is in buy zone
			|| g_rebuy_used[i] ) { // didn't buy anything
			continue;
		}
		
		g_rebuy_used[i] = true;
		RebuyPlayerLoadout( i );
	}
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public void OnFreezeEnd( Handle event, const char[] name, bool db ) {
	g_nades_graceperiod = true;
	CreateTimer( 5.0, EndGracePeriod );
}

//-----------------------------------------------------------------------------
public Action EndGracePeriod( Handle timer ) {
	g_nades_graceperiod = false;
	return Plugin_Handled;
}
   
/** ---------------------------------------------------------------------------
 * Give a player an item by weapon ID.
 */
void GivePlayerWeapon( int client, CSWeaponID id ) { 
	if( id == CSWeapon_FIVESEVEN ) id = CSWeapon_TEC9; // hacks
	
	if( id == CSWeapon_TASER ) { // hack number 2
		ClientCommand( client, "buy taser 34" );
		return;
	}
	
	if( id == CSWeapon_SAWEDOFF ) { // hack number 3 and counting because this game is a heap of shit.
		ClientCommand(client, "buy sawedoff 22");
		return;
	}
	
	ClientCommand( client, "buy %s", weaponNames[id] ); 
}

//-----------------------------------------------------------------------------
public Action ResetRebuyInProgress( Handle timer, int client ) {
	g_rebuy_in_progress[client] = false;
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public void RebuyPlayerLoadout( int client ) {
	if( !IsClientInGame(client) 
	    || IsFakeClient(client) 
		|| !IsPlayerAlive(client) ) return;
		 
	g_rebuy_in_progress[client] = true;
	CreateTimer( 0.1, ResetRebuyInProgress, client, TIMER_FLAG_NO_MAPCHANGE );
	
	int team = GetClientTeam( client ); 
	int cash = GetEntProp( client, Prop_Send, "m_iAccount" );
	if( cash < 1000 ) return; // no rebuy on pistol round.
	
	// give a primary only if they dont have one
	if( GetPlayerWeaponSlot( client, view_as<int>(SlotPrimmary) ) == -1 ) {
		
		CSWeaponID weap = view_as<CSWeaponID>(g_rebuy_data[client][REBUY_MAIN]);
		weap = TranslateWeaponForTeam( client, weap );
		
		if( weap != CSWeapon_NONE ) {
			
			GivePlayerWeapon( client, weap );
		}
	}
	
	// pistol
	int pistol = GetPlayerWeaponSlot( client, view_as<int>(SlotPistol) );
	bool buy_pistol;
	if( pistol == -1 ) {
		buy_pistol = true;
	} else {
		char classname[32];
		GetEntityClassname( pistol, classname, sizeof classname );
		
		if( team == 2 ) {
			buy_pistol = StrEqual( classname, "weapon_glock" );
		} else if( team == 3 ) {
			buy_pistol = StrEqual( classname, "weapon_hkp2000" );
		}
	}
	
	if( buy_pistol ) {
		CSWeaponID weap = view_as<CSWeaponID>(g_rebuy_data[client][REBUY_PISTOL]);
		weap = TranslateWeaponForTeam( client, weap );
		
		if( weap != CSWeapon_NONE ) {
		 
			GivePlayerWeapon( client, weap );
		}
	}
	
	// give grenades
	for( int i = REBUY_HE; i <= REBUY_DECOY; i++ ) {
		if( g_rebuy_data[client][i] ) {
			CSWeaponID nadeid = RebuyGrenadeIDs[i];
			nadeid = TranslateWeaponForTeam( client, nadeid );
			
			for( int j = 0; j < g_rebuy_data[client][i]; j++ ) {
				GivePlayerWeapon( client, nadeid );
				// this might fuck up, but meh 
			}
			
		}
	}
	
	if( g_rebuy_data[client][REBUY_TASER] ) {
		 
		GivePlayerWeapon( client, CSWeapon_TASER );
	}
	
	// and fuck shit fuck. 
	// (mp_defuser_allocation doesn't work in hostage??)
	ClientCommand( client, "buy defuser" );
}

//-----------------------------------------------------------------------------
public Action Command_Rebuy( int client, int args ) {
	if( client == 0 ) return Plugin_Handled;
	if( !IsPlayerAlive( client )) return Plugin_Handled;
	
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) {
		return Plugin_Continue;
	}
	
	if( g_rebuy_used[client] ) return Plugin_Handled;
	g_rebuy_used[client] = true;
	
	RebuyPlayerLoadout( client );
	
	return Plugin_Handled;
}
