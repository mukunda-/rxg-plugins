
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
	version = "1.2.0",
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
 * Grenades get locked after a player throws one. When locked they cannot
 * purchase any more.
 */
new g_nades_locked[MAXPLAYERS+1];

new g_nades_graceperiod;

new Handle:ammo_grenade_limit_default;
new Handle:ammo_grenade_limit_flashbang;
new Handle:ammo_grenade_limit_total;
new Handle:mp_buytime;
new Handle:rxg_auto_rebuy;

new c_ammo_grenade_limit_default;
new c_ammo_grenade_limit_flashbang;
new c_ammo_grenade_limit_total;
  
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

new CSWeaponID:RebuyGrenadeIDs[] = { 
	CSWeapon_NONE, CSWeapon_NONE, CSWeapon_NONE,
	CSWeapon_HEGRENADE, CSWeapon_FLASHBANG, CSWeapon_SMOKEGRENADE,
	CSWeapon_MOLOTOV, CSWeapon_DECOY
};

// saved player loadouts 
new g_rebuy_data[MAXPLAYERS+1][REBUY_COUNT]; 

// if they used rebuy this round yet
new g_rebuy_used[MAXPLAYERS+1];

// price of each weapon
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

// if they are using rebuy (and g_rebuy_data should not be updated.)
new bool:g_rebuy_in_progress[MAXPLAYERS+1]; 

//-----------------------------------------------------------------------------
public OnPluginStart() {
	InitOppositeMap();
	
	HookEvent( "round_start", OnRoundStart );
	HookEvent( "round_freeze_end", OnFreezeEnd );
	//HookEvent( "round_end", OnRoundEnd );
	//HookEvent( "player_death", OnPlayerDeath );
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
	
	// hack this up too. (need to remove const from cstrike_weapons.inc)
	BuyTeams[WEAPON_ELITE] = BOTHTEAMS;
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
 * Checks if a player is allowed to buy a grenade.
 *
 * @param client Player to check.
 * @param id     Grenade ID. If not a grenade, will always return FALSE.
 * 
 * @returns true if the player should be blocked from buying the weapon.
 */
bool:GrenadeLimited( client, CSWeaponID:id ) {
	
	if( g_nades_locked[client] && weaponGroups[id] == WeaponTypeGrenade ) {
		
		PrintToChat( client, 
		    "You may not purchase more grenades this round." );
		
		return true;
	}
		
	return false;
}

//-----------------------------------------------------------------------------
public Action:CS_OnBuyCommand( client, const String:weapon[] ) {
	if( !IsValidClient( client )) return Plugin_Continue;
	
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) {
		return Plugin_Continue;
	}
	
	// get the weapon ID
	decl String:real_name[64];
	CS_GetTranslatedWeaponAlias( weapon, real_name, sizeof real_name );

	// SPECIAL FIXES
	if( StrEqual( real_name, "cutters" ) ) real_name = "defuser"; 
	if( StrEqual( real_name, "cz75a" ) ) real_name = "tec9"; //tec9 because fivseven has problems.
	
	new CSWeaponID:id = CS_AliasToWeaponID( real_name );
	
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
public OnWeaponDrop( client, weapon ) {
	if( !IsPlayerAlive(client) ) return;
	
	decl String:name[64];
	GetEntityClassname( weapon, name, sizeof name );
	if( strncmp( name, "weapon_", 7 ) != 0 ) return;
	
	decl String:real_name[64];
	CS_GetTranslatedWeaponAlias( name[7], real_name, sizeof real_name );
	
	new CSWeaponID:id = CS_AliasToWeaponID( real_name );
	if( id == CSWeapon_NONE ) return;
	
		
	if( weaponGroups[id] == WeaponTypeGrenade ) {
	
		if( !DropGrenadeCheck() && !g_nades_graceperiod ) {
			g_nades_locked[client] = true;
		}
	}
}

//-----------------------------------------------------------------------------
public OnPlayerDroppedGrenade( client, CSWeaponID:id, amount ) {
	if( !IsPlayerAlive(client) ) return;
	
	/*
	// dropgrenade.smx allows players to drop grenades
	// restore allowed special grenade purchases
	if( id == CSWeapon_FLASHBANG ) {
		g_can_buy_flash[client] += amount;
	}
	
	if( id == CSWeapon_MOLOTOV || id == CSWeapon_INCGRENADE ) {
		g_can_buy_fire[client]++;
	}
	
	if( id == CSWeapon_SMOKEGRENADE ) g_can_buy_smoke[client]++;
	
	new Handle:data;
	CreateDataTimer( 0.1, UpdateLoadoutDelayed, data, TIMER_FLAG_NO_MAPCHANGE );
	WritePackCell( data, GetClientUserId( client ));
	WritePackCell( data, _:id );*/
}
/*
//-----------------------------------------------------------------------------
public Action:UpdateLoadoutDelayed( Handle:timer, any:data ) {
	ResetPack( data );
	new client = GetClientOfUserId( ReadPackCell( data ));
	if( client == 0 ) return Plugin_Handled;
	new CSWeaponID:id = CSWeaponID:ReadPackCell( data );
	
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	UpdateLoadout( client, id, true );
	
	return Plugin_Handled;
}*/

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

//#define ITEM_CZ75A 63
/*
//-----------------------------------------------------------------------------
CSWeaponID:WeaponIDfromEntity( ent ) {
	if( ent == -1 ) return CSWeapon_NONE;
	decl String:classname[64];
	GetEntityClassname( ent, classname, sizeof(classname) );
	ReplaceString( classname, sizeof(classname), "weapon_", "" );
	
	if( GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex") == ITEM_CZ75A ) {
		// this is not a p250, its a fucking cz.
		return CSWeapon_TEC9;
	}

	return CS_AliasToWeaponID( classname );
}*/

/** ---------------------------------------------------------------------------
 * Update a client's loadout for next round.
 *
 * @param client  Index of client.
 * @param id      ID of weapon that they bought.
 */
UpdateLoadout( client, CSWeaponID:id ) {
	new WeaponType:weapon_type = weaponGroups[id];
	
	if( !g_rebuy_used[client] ) {
		g_rebuy_used[client] = true;
		ResetRebuyData( client );
	}
	
	if( weapon_type == WeaponTypeTaser ) {
		    
		g_rebuy_data[client][REBUY_TASER] = 1;
		
	} else if( weapon_type == WeaponTypeGrenade ) {
		
		if( id == CSWeapon_INCGRENADE ) id = CSWeapon_MOLOTOV;
		new ammo_index = AmmoIndexForID( id );
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
		
		g_rebuy_data[client][REBUY_MAIN] = _:id;
		
	} else if( weapon_type == WeaponTypePistol ) {
	
		g_rebuy_data[client][REBUY_PISTOL] = _:id;
	}
}

//-----------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	for( new i = 1; i <= MaxClients; i++ ) {
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
public Action:DoAutoRebuy( Handle:timer ) {
	for( new i = 1; i <= MaxClients; i++ ) {
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
public OnFreezeEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	g_nades_graceperiod = true;
	CreateTimer( 5.0, EndGracePeriod );
}

//-----------------------------------------------------------------------------
public Action:EndGracePeriod( Handle:timer ) {
	g_nades_graceperiod = false;
	return Plugin_Handled;
}
 /*
//-----------------------------------------------------------------------------
public Action:RebuyPlayerLoadouts( Handle:timer ) {
	
	// get a list of clients
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) ) {
			clients[count] = i;
			count++;
		}
	}
	 
	ResetSpecialGrenadeCounters( INVALID_HANDLE ); 
	  
	for( new i = 0; i < count; i++ ) {
		RebuyPlayerLoadout( clients[i] );
	}
	
	CreateTimer( 0.1, ResetSpecialGrenadeCounters, _, 
	                         TIMER_FLAG_NO_MAPCHANGE );
	
	g_rebuy_in_progress = false;
	
	return Plugin_Handled;
}*/
/*
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
}*/

/** ---------------------------------------------------------------------------
 * Give a player an item by weapon ID.
 */
GivePlayerWeapon( client, CSWeaponID:id ) { 
	if( id == CSWeapon_FIVESEVEN ) id = CSWeapon_TEC9; // hacks
	
	if( id == CSWeapon_TASER ) { // hack number 2
		ClientCommand( client, "buy taser 34" );
		return;
	}
	ClientCommand( client, "buy %s", weaponNames[WeaponID:id] ); 
}

//-----------------------------------------------------------------------------
public Action:ResetRebuyInProgress( Handle:timer, any:client ) {
	g_rebuy_in_progress[client] = false;
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public RebuyPlayerLoadout( client ) {
	if( !IsClientInGame(client) 
	    || IsFakeClient(client) 
		|| !IsPlayerAlive(client) ) return;
		 
	g_rebuy_in_progress[client] = true;
	CreateTimer( 0.1, ResetRebuyInProgress, client, TIMER_FLAG_NO_MAPCHANGE );
	
	new team = GetClientTeam( client ); 
	new cash = GetEntProp( client, Prop_Send, "m_iAccount" );
	if( cash < 1000 ) return; // no rebuy on pistol round.
	
	// give a primary only if they dont have one
	if( GetPlayerWeaponSlot( client, _:SlotPrimmary ) == -1 ) {
		
		new CSWeaponID:weap = CSWeaponID:g_rebuy_data[client][REBUY_MAIN];
		weap = TranslateWeaponForTeam( client, weap );
		
		if( weap != CSWeapon_NONE ) {
			
			GivePlayerWeapon( client, weap );
		}
	}
	
	// pistol
	new pistol = GetPlayerWeaponSlot( client, int:SlotPistol );
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
			// dont need to do this nemore
			//if( pistol != -1 ) {
			//	CS_DropWeapon( client, pistol, false );
			//}
			
			GivePlayerWeapon( client, weap );
		}
	}
	
	// give grenades
	for( new i = REBUY_HE; i <= REBUY_DECOY; i++ ) {
		if( g_rebuy_data[client][i] ) {
			new CSWeaponID:nadeid = RebuyGrenadeIDs[i];
			nadeid = TranslateWeaponForTeam( client, nadeid );
			
			for( new j = 0; j < g_rebuy_data[client][i]; j++ ) {
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
public Action:Command_Rebuy( client, args ) {
	if( client == 0 ) return Plugin_Handled;
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" )) {
		return Plugin_Continue;
	}
	
	if( g_rebuy_used[client] ) return Plugin_Handled;
	
	g_rebuy_used[client] = true;
	RebuyPlayerLoadout( client );
	
	return Plugin_Handled;
}
