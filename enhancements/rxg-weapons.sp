
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <cstrike_weapons> // weapon restrict (utilities)
#include <restrict>
#include <dropgrenade>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rxg-weapons",
	author = "REFLEX",
	description = "Weapon purchasing management.",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

//-----------------------------------------------------------------------------
// a trie that maps similar weapons from the opposite team
// e.g. "m4a1" -> "ak47", "mp9" -> "mac10", etc and vice versa
new Handle:g_weapon_opposites;

// definitions for the player ammo table
//
enum {
	AMMO_INDEX_HE=14,
	AMMO_INDEX_FLASH,
	AMMO_INDEX_SMOKE,
	AMMO_INDEX_FIRE,
	AMMO_INDEX_DECOY
};

/** ---------------------------------------------------------------------------
 * How many special grenades the player can buy.
 *
 * Set to 0 if the player spawns with the limit already, or if he cannot
 * buy any more.
 * Set to 1 or 2 if the player is eligible to buy 1 or 2 of them.
 *
 * Also incremented if the player drops them.
 */
new g_can_buy_fire[MAXPLAYERS+1];  // 0 or 1
new g_can_buy_smoke[MAXPLAYERS+1]; // 0 or 1
new g_can_buy_flash[MAXPLAYERS+1]; // 0 or 2 (how many they can buy.)

new Handle:ammo_grenade_limit_default;
new Handle:ammo_grenade_limit_flashbang;
new Handle:ammo_grenade_limit_total;

new c_ammo_grenade_limit_default;
new c_ammo_grenade_limit_flashbang;
new c_ammo_grenade_limit_total;

new Handle:rxg_hegrenade_buyable;
new bool:c_hegrenade_buyable;

new Handle:rxg_hegrenade_dropchance;
new Float:c_hegrenade_dropchance;

enum {
	REBUY_MAIN,			// MAIN WEAPON	  (id) updated on buy/drop main weapon
	REBUY_PISTOL,		// PISTOL WEAPON  (id) updated on buy/drop pistol
	REBUY_TASER,		// TASER	      (bool) updated on buy/drop zues
	REBUY_HE,			// HEGRENADES	  (count) updated on buy/drop grenade
	REBUY_FLASH,		// FLASHBANGS	  (count) updated on buy/drop grenade
	REBUY_SMOKE,		// SMOKEGRENADES  (count) updated on buy/drop grenade
	REBUY_MOLOTOV,		// MOLOTOVS       (count) updated on buy/drop grenade
	REBUY_DECOY,		// DECOYS         (count) updated on buy/drop grenade
	REBUY_COUNT
};

new CSWeaponID:RebuyGrenadeIDs[] = { 
	CSWeapon_HEGRENADE, CSWeapon_FLASHBANG, CSWeapon_SMOKEGRENADE,
	CSWeapon_MOLOTOV, CSWeapon_DECOY
};

// saved player loadouts
// restored each round
new g_rebuy_data[MAXPLAYERS+1][REBUY_COUNT]; 

new WeaponPrices[_:CSWeaponID] = {
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

// TODO molly/incgrenade cost different make sure you handle it right.

new bool:g_rebuying_in_progress;
//new bool:g_cleaning_grenades; // to stop from updating 
                              // grenade data during cleanup.

//-----------------------------------------------------------------------------
public OnPluginStart() {
	InitOppositeMap();
	
	HookEvent( "round_start", OnRoundStart );
	HookEvent( "player_death", OnPlayerDeath );
	//RegConsoleCmd( "rebuy", BlockCommand );
	
	ammo_grenade_limit_default   = FindConVar( "ammo_grenade_limit_default" );
	ammo_grenade_limit_flashbang = FindConVar( "ammo_grenade_limit_flashbang" );
	ammo_grenade_limit_total     = FindConVar( "ammo_grenade_limit_total" );
	
	rxg_hegrenade_buyable =  
			CreateConVar( "rxg_hegrenade_buyable", "1", 
		                  "Allow players to purchase HE grenades." );
						  
	rxg_hegrenade_dropchance = 
			CreateConVar( "rxg_hegrenade_dropchance", "0.33",
			              "Chance that a player will spawn an HE grenade on death." );
	
	HookConVarChange( ammo_grenade_limit_default,   OnCVarChanged );
	HookConVarChange( ammo_grenade_limit_flashbang, OnCVarChanged );
	HookConVarChange( ammo_grenade_limit_total,     OnCVarChanged );
	HookConVarChange( rxg_hegrenade_buyable,        OnCVarChanged );
	HookConVarChange( rxg_hegrenade_dropchance,     OnCVarChanged );
	
	CacheCVars();
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		SDKHook( i, SDKHook_WeaponDropPost, OnWeaponDrop );
	}
}

//-----------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//-----------------------------------------------------------------------------
CacheCVars() {
	c_ammo_grenade_limit_default   = GetConVarInt( ammo_grenade_limit_default );
	c_ammo_grenade_limit_flashbang = GetConVarInt( ammo_grenade_limit_flashbang );
	c_ammo_grenade_limit_total     = GetConVarInt( ammo_grenade_limit_total );
	
	c_hegrenade_buyable = GetConVarBool( rxg_hegrenade_buyable );
	c_hegrenade_dropchance = GetConVarFloat( rxg_hegrenade_dropchance );
}

//-----------------------------------------------------------------------------
public OnCVarChanged( Handle:convar, const String:oldValue[], 
						const String:newValue[] ) {
	CacheCVars();
}

/** ---------------------------------------------------------------------------
 * Map weapons to each other in the opposite trie.
 *
 * @param weapon1 Weapon ID to map.
 * @param weapon2 Weapon ID to map to, and vice versa.
 */
MapOpposite( CSWeaponID:weapon1, CSWeaponID:weapon2 ) {
	
	decl String:str[64];
	
	FormatEx( str, sizeof str, "%s", weapon1 );
	SetTrieValue( g_weapon_opposites, str, _:weapon2 );
	
	FormatEx( str, sizeof str, "%s", weapon2 );
	SetTrieValue( g_weapon_opposites, str, _:weapon1 );
}

/** ---------------------------------------------------------------------------
 * Build the opposite weapons map.
 */
InitOppositeMap() {
	g_weapon_opposites = CreateTrie();
	
	MapOpposite( CSWeapon_AUG,        CSWeapon_SG556    );
	MapOpposite( CSWeapon_FAMAS,      CSWeapon_GALILAR  );
	MapOpposite( CSWeapon_M4A1,       CSWeapon_AK47     );
	MapOpposite( CSWeapon_SCAR20,     CSWeapon_G3SG1    );
	MapOpposite( CSWeapon_MAG7,       CSWeapon_SAWEDOFF );
	MapOpposite( CSWeapon_FIVESEVEN,  CSWeapon_TEC9     );
	MapOpposite( CSWeapon_MP9,        CSWeapon_MAC10    );
	MapOpposite( CSWeapon_INCGRENADE, CSWeapon_MOLOTOV  );
}

/** ---------------------------------------------------------------------------
 * Clear the rebuy data for a client (for when they connect)
 */
ResetRebuyData( client ) {
	for( new i = 0; i < REBUY_COUNT; i++ ) {
		g_rebuy_data[client][i] = 0;
	}
}

//-----------------------------------------------------------------------------
public OnClientPutInServer( client ) {
	ResetRebuyData( client );
	g_can_buy_fire[client]  = 1;
	g_can_buy_smoke[client] = 1;
	g_can_buy_flash[client] = c_ammo_grenade_limit_flashbang;
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
CSWeaponID:TranslateWeaponForTeam( client, CSWeaponID:from ) {
	new team = GetClientTeam( client );
	new canbuy = BuyTeams[from] == team || BuyTeams[from] == BOTHTEAMS;
	
	if( !canbuy ) {
		// try to find similar
		decl String:from_string[64];
		FormatEx( from_string, sizeof from_string, "%s", from );
		new similar;
		if( !GetTrieValue( g_weapon_opposites, from_string, similar )) {
		
			// no similar mapped. cannot buy.
			return CSWeapon_NONE;
		}
		
		return CSWeaponID:similar;
	} else {
	
		// already purchasable 
		return from;
	}
}

/** ---------------------------------------------------------------------------
 * @returns The total number of grenades a player has.
 */
TotalGrenades( client ) {
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
AmmoIndexForID( CSWeaponID:id ) {
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
bool:CanBuyGrenade( client, CSWeaponID:id ) {
	new WeaponType:type = weaponGroups[ _:id ];
	if( type != WeaponTypeGrenade ) return true;
	
	if( TotalGrenades( client ) >= c_ammo_grenade_limit_total ) {
		return false;
	}
	
	new ammo_index = AmmoIndexForID( id );
	new limit = id == CSWeapon_FLASHBANG ? c_ammo_grenade_limit_flashbang 
	                                     : c_ammo_grenade_limit_default;
	
	if( GetEntProp( client, Prop_Send, "m_iAmmo", _, ammo_index ) >= limit ) {
		// cannot carry any more of this type
		return false;
	}
	
	return true;
}

/** ---------------------------------------------------------------------------
 * Checks if a player is allowed to buy a special grenade.
 *
 * @param client Player to check.
 * @param id     Grenade ID.
 * 
 * @returns true if the player should be blocked from buying the weapon.
 *
 * Note that this function decrements the available amount they can buy, so
 * you need to make sure that they get the item they want after calling this.
 */
bool:SpecialGrenadeLimited( client, CSWeaponID:id ) {
	
	if( id == CSWeapon_MOLOTOV || id == CSWeapon_INCGRENADE ) {
		
		if( g_can_buy_fire[client] == 0 ) {
			PrintToChat( client, 
		                 "You may not purchase another %s this round.", 
					     id == CSWeapon_MOLOTOV ? "molotov"
					                              : "incendiary grenade" );
			return true;
		}
		
		g_can_buy_fire[client]--;
		return false;
	}
	
	if( id == CSWeapon_SMOKEGRENADE ) {
		if( g_can_buy_smoke[client] == 0 ) {
			PrintToChat( client, 
		        "You may not purchase another smoke grenade this round." );
			return true;
		}
		
		g_can_buy_smoke[client]--;
		return false;
	}
	
	if( id == CSWeapon_FLASHBANG ) {
		if( g_can_buy_flash[client] == 0 ) {
			PrintToChat( client, 
		        "You may not purchase another flashbang this round." );
			return true;
		}
		
		g_can_buy_flash[client]--;
		return false;
	}
	
	return false;
}

//-----------------------------------------------------------------------------
public Action:CS_OnBuyCommand( client, const String:weapon[] ) {

	if( !IsValidClient( client )) return Plugin_Continue;
	if( g_rebuying_in_progress ) return Plugin_Continue;
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) {
		return Plugin_Continue;
	}
	
	// get the weapon ID
	decl String:real_name[64];
	CS_GetTranslatedWeaponAlias( weapon, real_name, sizeof real_name );
	
	if( StrEqual( real_name, "cutters" ) ) real_name = "defuser"; //special fix
	
	new CSWeaponID:id = CS_AliasToWeaponID( real_name );
	
	// catch invalid weapon name.
	if( id == CSWeapon_NONE ) return Plugin_Continue;
	
	// TODO verify all weapons being translated correctly.
	decl String:debug1[64];
	CS_WeaponIDToAlias( id, debug1, sizeof debug1 );
	
	// catch invalid weapon name.
	if( id == CSWeapon_NONE ) return Plugin_Continue; 
	
	// catch weapons that aren't in the game.
	if( AllowedGame[id] != 3 && AllowedGame[id] != 1 ) return Plugin_Continue;
	 
	// catch trying to buy opposing team's weapons (and remap)
	id = TranslateWeaponForTeam( client, id );
	if( id == CSWeapon_NONE ) return Plugin_Handled;
	 
	// from here on we have a valid weapon ID that they want to purchase...
	
	if( id == CSWeapon_HEGRENADE && !c_hegrenade_buyable ) {
		PrintToChat( client, "HE grenades cannot be bought." );
		return Plugin_Handled;
	}
	
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
	if( SpecialGrenadeLimited( client, id ) ) {
		return Plugin_Handled;
	}
	
	// update the client's rebuy (autobuy) loadout.
	UpdateLoadout( client, id, false );
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public OnWeaponDrop( client, weapon ) {

	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) return;
	if( !IsPlayerAlive(client) ) return;
	if( g_rebuying_in_progress ) return;
	
	decl String:name[64];
	GetEntityClassname( weapon, name, sizeof name );
	if( strncmp( name, "weapon_", 7 ) != 0 ) return;
	
	decl String:real_name[64];
	CS_GetTranslatedWeaponAlias( name[7], real_name, sizeof real_name );
	
	new CSWeaponID:id = CS_AliasToWeaponID( real_name );
	if( id == CSWeapon_NONE ) return;
	
	// remap this here--remember to make special cases for this...
	// like below
	if( id == CSWeapon_INCGRENADE ) id = CSWeapon_MOLOTOV;
	
	if( weaponGroups[id] == WeaponTypeGrenade ) {
		new ammo = AmmoIndexForID( id );
		ammo = GetEntProp( client, Prop_Send, "m_iAmmo", ammo );
		
		if( ammo == 0 ) {
			// quit if they are throwing a grenade.
			return;
		}
	}
	
	if( id != CSWeapon_MOLOTOV ) {
		// they may be dropping an enemy weapon from last round.
		// in which case do not modify their loadout.
		new team = GetClientTeam( client );
		if( BuyTeams[id] != BOTHTEAMS && BuyTeams[id] != team ) return;
	}
	
	new Handle:data;
	CreateDataTimer( 0.1, UpdateLoadoutDelayed, data, TIMER_FLAG_NO_MAPCHANGE );
	WritePackCell( data, GetClientUserId( client ));
	WritePackCell( data, _:id );
}

//-----------------------------------------------------------------------------
public OnPlayerDroppedGrenade( client, CSWeaponID:id, amount ) {
	if( !IsPlayerAlive(client) ) return;
	
	// dropgrenade.smx allows players to drop grenades
	// restore allowed special grenade purchases
	if( id == CSWeapon_FLASHBANG ) {
		g_can_buy_flash[client] += amount;
	}
	
	if( id == CSWeapon_MOLOTOV ) g_can_buy_fire[client]++;
	if( id == CSWeapon_SMOKEGRENADE ) g_can_buy_smoke[client]++;
	
	new Handle:data;
	CreateDataTimer( 0.1, UpdateLoadoutDelayed, data, TIMER_FLAG_NO_MAPCHANGE );
	WritePackCell( data, GetClientUserId( client ));
	WritePackCell( data, _:id );
}

//-----------------------------------------------------------------------------
public Action:UpdateLoadoutDelayed( Handle:timer, any:data ) {
	ResetPack( data );
	new client = GetClientOfUserId( ReadPackCell( data ));
	if( client == 0 ) return Plugin_Handled;
	new CSWeaponID:id = CSWeaponID:ReadPackCell( data );
	
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	UpdateLoadout( client, id, true );
	
	return Plugin_Handled;
}

/** ---------------------------------------------------------------------------
 * Scan the grenades a player has equipped and save them in the
 * rebuy data.
 */
SaveClientGrenades( client ) {
	if( !IsClientInGame( client )) return;

	for( new i = 0; i < 5; i++ ) {
		g_rebuy_data[client][REBUY_HE+i] = 
			GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE+i );
	}
}

//-----------------------------------------------------------------------------
CSWeaponID:WeaponIDfromEntity( ent ) {
	if( ent == -1 ) return CSWeapon_NONE;
	decl String:classname[64];
	GetEntityClassname( ent, classname, sizeof(classname) );
	ReplaceString( classname, sizeof(classname), "weapon_", "" );
	return CS_AliasToWeaponID( classname );
}

/** ---------------------------------------------------------------------------
 * Update a client's loadout for next round.
 *
 * @param client  Index of client.
 * @param id      ID of weapon that they bought.
 * @param dropped true if they are dropping the item and not buying it.
 */
UpdateLoadout( client, CSWeaponID:id, bool:dropped ) {
	new WeaponType:weapon_type = weaponGroups[id];
	
	if( weapon_type == WeaponTypeTaser ) {
		    
		g_rebuy_data[client][REBUY_TASER] = dropped ? 0 : 1;
		
	} else if( weapon_type == WeaponTypeGrenade ) {
		
		if( id == CSWeapon_INCGRENADE ) id = CSWeapon_MOLOTOV;
		new ammo_index = AmmoIndexForID( id );
		SaveClientGrenades( client );
		
		if( !dropped ) {
			// grenade data is currently set to what they have equipped
			// increment the slot that they are currently purchasing.
			g_rebuy_data[client][REBUY_HE+(ammo_index-AMMO_INDEX_HE)]++;
		}
		
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
			
		if( dropped ) {
			g_rebuy_data[client][REBUY_MAIN] = 
				_:WeaponIDfromEntity( 
					GetPlayerWeaponSlot( client, _:SlotPrimmary ));
		} else {
			g_rebuy_data[client][REBUY_MAIN] = _:id;
		}
	} else if( weapon_type == WeaponTypePistol ) {
	
		if( dropped ) {
			id = WeaponIDfromEntity( 
					GetPlayerWeaponSlot( client, _:SlotPistol ));
					
			g_rebuy_data[client][REBUY_PISTOL] = _:id;
					
		} else {
			g_rebuy_data[client][REBUY_PISTOL] = _:id;
		}
	}
}

//-----------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	CleanupGrenades();
	CreateTimer( 0.4, RebuyPlayerLoadouts, _, TIMER_FLAG_NO_MAPCHANGE );
}

//-----------------------------------------------------------------------------
public Action:RebuyPlayerLoadouts( Handle:timer ) {
	g_rebuying_in_progress = true;
	
	// get a list of clients
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) ) {
			clients[count] = i;
			count++;
		}
	}
	
	
	// we shuffle the player list to distribute the limited grenades
	for( new i = count - 1; i >= 1; i-- ) {
		// fisher-yates shuffle
		new j = GetRandomInt( 0, i );
		new a = clients[i];
		clients[i] = clients[j];
		clients[j] = a;
	}
	 
	for( new i = 0; i < count; i++ ) {
		RebuyPlayerLoadout( clients[i] );
	}
	
	CreateTimer( 0.1, ResetSpecialGrenadeCounters, _, 
	                         TIMER_FLAG_NO_MAPCHANGE );
	
	g_rebuying_in_progress = false;
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action:ResetSpecialGrenadeCounters( Handle:timer ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		
		// if a player has a special grenade, dont allow them to buy more.
		new ammo;
		ammo = GetEntProp( i, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FLASH );
		ammo = c_ammo_grenade_limit_flashbang - ammo;
		if( ammo < 0 ) ammo = 0;
		g_can_buy_flash[i] = ammo;
		
		ammo = GetEntProp( i, Prop_Send, "m_iAmmo", _, AMMO_INDEX_SMOKE );
		ammo = 1 - ammo;
		if( ammo < 0 ) ammo = 0;
		g_can_buy_smoke[i] = ammo;
		
		ammo = GetEntProp( i, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FIRE );
		ammo = 1 - ammo;
		if( ammo < 0 ) ammo = 0;
		g_can_buy_fire[i] = ammo;
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
CleanupGrenades() {

//	g_cleaning_grenades = true;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		// reset grenades
		if( !IsClientInGame(i) ) return;
		
		new grenade;
		while( (grenade = GetPlayerWeaponSlot( i, _:SlotGrenade )) != -1 ) {
			
			CS_DropWeapon( i, grenade, true, true );
			AcceptEntityInput( grenade, "Kill" );
		}
	}
	
//	g_cleaning_grenades = false;
}

/** ---------------------------------------------------------------------------
 * Give a player an item by weapon ID.
 */
GivePlayerWeapon( client, CSWeaponID:id ) {
	decl String:name2[64];
	FormatEx( name2, sizeof name2, "weapon_%s", weaponNames[WeaponID:id] );
	GivePlayerItem( client, name2 );
}

//-----------------------------------------------------------------------------
public RebuyPlayerLoadout( client ) {
	if( !IsClientInGame(client) 
	    || IsFakeClient(client) 
		|| !IsPlayerAlive(client) ) return;
		 
	new team = GetClientTeam( client ); 
	new cash = GetEntProp( client, Prop_Send, "m_iAccount" );
	if( cash < 1000 ) return; // no rebuy on pistol round.
	
	// give a primary only if they dont have one
	if( GetPlayerWeaponSlot( client, _:SlotPrimmary ) == -1 ) {
		
		new CSWeaponID:weap = CSWeaponID:g_rebuy_data[client][REBUY_MAIN];
		weap = TranslateWeaponForTeam( client, weap );
		
		if( weap != CSWeapon_NONE ) {
			if( Restrict_CanBuyWeapon( client, team, WeaponID:weap )) {
				GivePlayerWeapon( client, weap );
			}
		}
	}
	
	// pistol
	new pistol = GetPlayerWeaponSlot(client,int:SlotPistol);
	new bool:buy_pistol;
	if( pistol == -1 ) {
		buy_pistol = true;
	} else {
		decl String:classname[64];
		GetEntityClassname( pistol, classname, sizeof classname );
		
		if( team == 2 ) {
			buy_pistol = StrEqual( classname, "weapon_glock" );
		} else if( team == 3 ) {
			buy_pistol = StrEqual( classname, "weapon_hkp2000" );
		}
	}
	
	if( buy_pistol ) {
		new CSWeaponID:weap = CSWeaponID:g_rebuy_data[client][REBUY_PISTOL];
		weap = TranslateWeaponForTeam( client, weap );
		
		if( weap != CSWeapon_NONE ) {
		
			if( pistol != -1 ) {
				CS_DropWeapon( client, pistol, false );
			}

			GivePlayerWeapon( client, weap );
		}
	}
	
	// give grenades
	for( new i = REBUY_HE; i <= REBUY_DECOY; i++ ) {
		if( g_rebuy_data[client][i] ) {
			new CSWeaponID:nadeid = RebuyGrenadeIDs[i-REBUY_HE];
			nadeid = TranslateWeaponForTeam( client, nadeid );
		
			if( Restrict_CanBuyWeapon( client, team, WeaponID:nadeid )) {
				for( new j = 0; j < g_rebuy_data[client][i]; j++ ) {
					GivePlayerWeapon( client, nadeid );
					// this might fuck up, but meh (if somehow the 
					// rebuy data dictates that they can 
					// hold more than they can.)
				}
			}
		}
	}
	
	if( g_rebuy_data[client][REBUY_TASER] ) {
		// give zues (this is really shitty)
		new bool:has_taser = false;
		for( new i = 0; i < 64; i++ ) {
			new ent = GetEntPropEnt( client, Prop_Send, "m_hMyWeapons", i );
			if( ent == -1 ) continue;
			
			decl String:classname[64];
			GetEntityClassname( ent, classname, sizeof classname );
			classname[12] = 0; // make sure we are null terminated.
			
			// "weapon_taser"
			if( StrEqual( classname[7], "taser" )) {
				has_taser = true;
				break;
			}
		}
		
		if( !has_taser ) {
			if( Restrict_CanBuyWeapon( client, team, WEAPON_TASER )) {
				GivePlayerItem( client, "weapon_taser" );
			}
		}
	}
	
}

//-----------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ));
	if( client == 0 ) return;
	
	if( GetRandomFloat( 0.0, 0.99999 ) < c_hegrenade_dropchance ) {
		decl Float:pos[3];
		GetClientAbsOrigin( client, pos );
		pos[2] += 30.0;
		
		new ent = CreateEntityByName( "weapon_hegrenade" );
		new Float:vec[3];
		DispatchSpawn( ent );
		TeleportEntity( ent, pos, vec,vec );
		//GivePlayerItem( client, "weapon_hegrenade" );
	}
}
