#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <cstrike_weapons>

#pragma semicolon 1

// 1.0.2
//   cz75a patch
// 1.0.1
//   improved system
//   included defusers/armor

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "rebuyfix",
	author = "REFLEX-GAMERS",
	description = "server rebuy fix",
	version = "1.0.2",
	url = "www.reflex-gamers.com"
};

new const WeaponID:weapon_opposits[] = 
{ 
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,		
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_MP9,		
	WEAPON_SG556,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_TEC9,
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_GALILAR,
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,
	WEAPON_NONE,	WEAPON_AK47,	WEAPON_NONE,	WEAPON_SCAR20,
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_M4A1,
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,			
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_FAMAS,	WEAPON_NONE,
	WEAPON_SAWEDOFF,WEAPON_NONE,	WEAPON_MAG7,	WEAPON_FIVESEVEN,
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_MAC10,
	WEAPON_NONE,	WEAPON_NONE,	WEAPON_NONE,	WEAPON_G3SG1,
	WEAPON_AUG,		WEAPON_NONE,	WEAPON_NONE,	WEAPON_INCGRENADE,
	WEAPON_NONE,	WEAPON_MOLOTOV,	WEAPON_NONE,
	
	WEAPON_AK47,
	WEAPON_NONE
};

//
// definitions for the player ammo table
//
enum {
	AMMO_INDEX_HE=14,
	AMMO_INDEX_FLASH,
	AMMO_INDEX_SMOKE,
	AMMO_INDEX_FIRE,
	AMMO_INDEX_DECOY
};

new bool:purchased_fire[MAXPLAYERS+1];			// player has purchased a firebomb this round
new bool:purchased_smoke[MAXPLAYERS+1];			// player has purchased a smoke this round

new bool:bypass_buycommand[MAXPLAYERS+1];		

new Handle:sm_limit_firesmoke;
new bool:c_limit_firesmoke;

new Handle:ammo_grenade_limit_default;
new Handle:ammo_grenade_limit_flashbang;
new Handle:ammo_grenade_limit_total;

new c_ammo_grenade_limit_default;
new c_ammo_grenade_limit_flashbang;
new c_ammo_grenade_limit_total;

new bool:buytime_ended;

enum {
	REBUY_MAIN,			// MAIN WEAPON		(id)
	REBUY_PISTOL,		// PISTOL WEAPON	(id)
	REBUY_ZUES,			// BUY ZUES			(bool)
	REBUY_HE,			// HEGRENADE COUNT	(count)
	REBUY_FLASH,		// FLASHBANG COUNT	(count)
	REBUY_SMOKE,		// SMOKEGRENADE COUNT	(count)
	REBUY_MOLOTOV,		// MOLOTOV OR INCENDIARY COUNT	(count)
	REBUY_DECOY,		// DECOY COUNT	(count)
	REBUY_ARMOR,		// 0 = none, 1 = vest, 2 = vesthelm
	REBUY_DEFUSER,		// BUY DEFUSER (bool)
	REBUY_COUNT
};

new rebuy_data[MAXPLAYERS+1][REBUY_COUNT];	// rebuy data array
new rebuy_flags[MAXPLAYERS+1];		// &1 = player died last round, &2 = rebuy changed this round, &4 = rebuy was used this round

//----------------------------------------------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

RecacheGrenadeCVars() {
	c_ammo_grenade_limit_default = GetConVarInt( ammo_grenade_limit_default );
	c_ammo_grenade_limit_flashbang = GetConVarInt( ammo_grenade_limit_flashbang );
	c_ammo_grenade_limit_total = GetConVarInt( ammo_grenade_limit_total );
}

public AmmoCVarChanged( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	RecacheGrenadeCVars();
}

public LimitFireSmokeChanged( Handle:convar, const String:oldValue[], const String:newValue[] ) {
	c_limit_firesmoke = GetConVarBool( convar );
}

//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart() {

	CSWeapons_Init();

	RegConsoleCmd("rebuy", Command_Rebuy );

	HookEvent( "round_start", Event_RoundStart );
	
	ammo_grenade_limit_default = FindConVar( "ammo_grenade_limit_default" );
	ammo_grenade_limit_flashbang = FindConVar( "ammo_grenade_limit_flashbang" );
	ammo_grenade_limit_total = FindConVar( "ammo_grenade_limit_total" );
	sm_limit_firesmoke = CreateConVar( "sm_limit_firesmoke", "1", "Only allow purchasing of one fire or smoke grenade", FCVAR_PLUGIN );
	
	HookConVarChange( ammo_grenade_limit_default, AmmoCVarChanged );
	HookConVarChange( ammo_grenade_limit_flashbang, AmmoCVarChanged );
	HookConVarChange( ammo_grenade_limit_total, AmmoCVarChanged );
	HookConVarChange( sm_limit_firesmoke, LimitFireSmokeChanged );
	
	RecacheGrenadeCVars();

//	HookEvent( "enter_buyzone", Event_EnterBuyZone );
//	HookEvent( "exit_buyzone", Event_ExitBuyZone );
	HookEvent( "buytime_ended", Event_BuyTimeEnded );
	
	HookEvent( "player_death", Event_PlayerDeath );
}
/*
//----------------------------------------------------------------------------------------------------------------------
public Event_EnterBuyZone( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	players_in_buy_zone[client] = 1;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_ExitBuyZone( Handle:event, const String:name[], bool:dontBroadcast ) {
	new userid = GetEventInt( event, "userid" );
	new client = GetClientOfUserId( userid );
	players_in_buy_zone[client] = 0;
}
*/
//----------------------------------------------------------------------------------------------------------------------
public Event_BuyTimeEnded( Handle:event, const String:name[], bool:dontBroadcast ) {
//	for( new i = 0; i < MAXPLAYERS+1; i++ ) {
//		players_in_buy_zone[i] = 0;
// 	}
	buytime_ended = true;

}
/*
GiveDefuser() {
	PrintToServer("giving defusers..." );
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		if( !IsPlayerAlive(i) ) continue;
		SetEntProp( i, Prop_Send, "m_bHasDefuser", 1 );
		
	}
}*/

//----------------------------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	SetRebuyNewRound();
	ResetMolotovCounter();
	//GiveDefuser();
}

//----------------------------------------------------------------------------------------------------------------------
public OnClientConnected( client ) {
	ClearRebuyData( client );
	rebuy_flags[client] = 0;
	purchased_fire[client] = false;
	purchased_smoke[client] = false;
	bypass_buycommand[client] = false;
}

//----------------------------------------------------------------------------------------------------------------------
public ResetMolotovCounter() {
	for( new i = 1; i <= MaxClients; i++ ) {
		purchased_fire[i] = false;
		purchased_smoke[i] = false;
		if( IsClientConnected(i) ) {
			if( IsClientInGame(i) ) {
				if( GetClientTeam(i) >= 2 && IsPlayerAlive(i) ) {
					new ammo_molotov	= GetEntProp( i, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FIRE );
					new ammo_smoke		= GetEntProp( i, Prop_Send, "m_iAmmo", _, AMMO_INDEX_SMOKE );

					if( ammo_molotov != 0 ) purchased_fire[i] = true;
					if( ammo_smoke != 0 ) purchased_smoke[i] = true;
					
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
bool:MolotovCheck( client, WeaponID:id ) {
	new team = GetClientTeam(client);
	new WeaponID:check = WEAPON_NONE;
	if( team == 2 ) {
		check = WEAPON_MOLOTOV;
	} else if( team == 3 ) {
		check = WEAPON_INCGRENADE;
	} else {
		return false;
	}
	
	if( id == check ) {
		if( purchased_fire[client] ) {
			PrintToChat( client, "You cannot purchase another firebomb this round." );
			return true;
		} else {
			purchased_fire[client] = true;
		}
	}
	return false;
}

//----------------------------------------------------------------------------------------------------------------------
bool:SmokeCheck( client, WeaponID:id ) {
	
	if( id != WEAPON_SMOKEGRENADE ) return false;
	
	if( purchased_smoke[client] ) {
		PrintToChat( client, "You cannot purchase another smoke grenade this round." );
		return true;
	} else {
		purchased_smoke[client] = true;
	}
	return false;
}


AmmoIndexForID( WeaponID:id ) {
	if( id == WEAPON_HEGRENADE ) return AMMO_INDEX_HE;
	if( id == WEAPON_FLASHBANG ) return AMMO_INDEX_FLASH;
	if( id == WEAPON_MOLOTOV ) return AMMO_INDEX_FIRE;
	if( id == WEAPON_INCGRENADE ) return AMMO_INDEX_FIRE;
	if( id == WEAPON_SMOKEGRENADE ) return AMMO_INDEX_SMOKE;
	if( id == WEAPON_DECOY ) return AMMO_INDEX_DECOY;
	return 0;
}

bool:CanBuyGrenadeCheck( client, WeaponID:id ) {
	new WeaponType:type = GetWeaponTypeFromID( id );
	if( type != WeaponTypeGrenade ) return true;
	if( GetPlayerTotalGrenades( client ) >= c_ammo_grenade_limit_total ) return false;
	
	new ammo_index = AmmoIndexForID( id );
	
	if( GetPlayerTotalGrenades( client ) >= c_ammo_grenade_limit_total ) return false;
	if( GetEntProp( client, Prop_Send, "m_iAmmo", _, ammo_index ) >= ( id == WEAPON_FLASHBANG ? c_ammo_grenade_limit_flashbang : c_ammo_grenade_limit_default ) ) return false;
	
	return true;
}


//----------------------------------------------------------------------------------------------------------------------
WeaponID:TranslateWeaponForTeam( client, const String:weapon[], WeaponID:id ) {
	new team = GetClientTeam(client);
	new canbuy = CanTeamBuyWeapon( team, weapon );
	if( !canbuy ) {
		return weapon_opposits[id];
	} else {
		return id;
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:CS_OnBuyCommand( client, const String:weapon[] ) {
	 
	if( bypass_buycommand[client] ) return Plugin_Continue;
	if( !IsValidClient(client) ) return Plugin_Continue;
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" ) || buytime_ended ) {
		
		return Plugin_Handled;
	}
	
	 
	
	new WeaponID:id = GetWeaponID( weapon );
 
	if( StrEqual( weapon, "cutters" ) ) id = WEAPON_DEFUSER;
	// special fixes
	
	//PrintToChatAll( "test1: %s", weapon );
	if( StrEqual( weapon, "kevlar" ) ) id = WEAPON_KEVLAR;
	if( StrEqual( weapon, "assaultsuit" ) ) id = WEAPON_ASSAULTSUIT;
	
	if( id == WEAPON_NONE ) return Plugin_Handled;
	
	if( AllowedGame[id] != 3 && AllowedGame[id] != 1 ) {
		// disallowed weapon
		return Plugin_Handled;
	}
	
	// translate weapon, check if player 
	id = TranslateWeaponForTeam( client, weaponNames[id], id );
	if( id == WEAPON_NONE ) return Plugin_Handled;
	//if( CanBuyWeapon( client, id ) == WEAPON_NONE ) return Plugin_Handled;
	
	// catch if player can't afford weapon
	if( GetWeaponPrice(client,id) > GetEntProp( client, Prop_Send, "m_iAccount" ) ) return Plugin_Continue; // this will print a insufficient funds message
	
	if( !CanBuyGrenadeCheck(client, id ) ) return Plugin_Continue; // will print ' you cant carry anymore '
	
	if( c_limit_firesmoke ) {
		if( MolotovCheck(client,id) ) return Plugin_Handled;
		if( SmokeCheck(client,id) ) return Plugin_Handled;
	}
	
	// if player died last round and rebuy was not used yet, reset the data for that player
	if( (rebuy_flags[client] & 1) && !(rebuy_flags[client] & (2+4)) ) {
		rebuy_flags[client] &= ~1;
		
		ClearRebuyData( client );
		rebuy_flags[client] |= 2; // rebuy was changed
	}
	RebuyUpdateLoadout( client, id );

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------------------------
SetRebuyNewRound() {
	for( new i = 0; i < MAXPLAYERS+1; i++ ) {
		rebuy_flags[i] &= 1; // first buy, save death flag
//		players_in_buy_zone[i] = 1;
	}
	buytime_ended = false;
}

//----------------------------------------------------------------------------------------------------------------------
ClearRebuyData( client ) {
	for( new i = 0; i < REBUY_COUNT; i++ ) {
		rebuy_data[client][i] = 0;
	}
}

//----------------------------------------------------------------------------------------------------------------------
GetPlayerTotalGrenades( client ) {
	if( !IsClientInGame( client ) ) { return 0; }

	new ammo_he			= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE      );
	new ammo_flash		= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FLASH   );
	new ammo_smoke		= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_SMOKE   );
	new ammo_molotov	= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_FIRE );
	new ammo_decoy		= GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_DECOY   );
	
	return ammo_he + ammo_flash + ammo_smoke + ammo_molotov + ammo_decoy;
}

//----------------------------------------------------------------------------------------------------------------------
RebuyCopyClientGrenades( client ) {
	if( !IsClientInGame( client ) ) { return; }

	for( new i = 0; i < 5; i++ )
		rebuy_data[client][REBUY_HE+i] = GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE+i );
}

//----------------------------------------------------------------------------------------------------------------------
RebuyUpdateLoadout( client, WeaponID:weapon ) {
	new WeaponType:weapon_type = GetWeaponTypeFromID( weapon );

	if( weapon_type == WeaponTypeTaser ) {
		rebuy_data[client][REBUY_ZUES] = 1;
	} else if( weapon_type == WeaponTypeGrenade ) {
		
		if( weapon == WEAPON_INCGRENADE ) weapon = WEAPON_MOLOTOV;

		
		new ammo_index = AmmoIndexForID( weapon );
		
		RebuyCopyClientGrenades(client);
		
		rebuy_data[client][REBUY_HE+ammo_index-AMMO_INDEX_HE]++;
 
	} else if( weapon_type == WeaponTypeSMG || weapon_type == WeaponTypeShotgun || weapon_type == WeaponTypeRifle || weapon_type == WeaponTypeSniper || weapon_type == WeaponTypeMachineGun ) {
		
		rebuy_data[client][REBUY_MAIN] = _:weapon;
	} else if( weapon_type == WeaponTypePistol ) {
		rebuy_data[client][REBUY_PISTOL] = _:weapon;
	} else if( weapon == WEAPON_KEVLAR ) {
		if( rebuy_data[client][REBUY_ARMOR] < 1 ) rebuy_data[client][REBUY_ARMOR] = 1;
	} else if( weapon == WEAPON_ASSAULTSUIT ) {
		rebuy_data[client][REBUY_ARMOR] = 2;
	} else if( weapon == WEAPON_DEFUSER ) {
		rebuy_data[client][REBUY_DEFUSER] = 1;
	} else {
		return;
	}
}

IssueRebuy_Grenade( String:result[], maxlen, client, index ) {

	
	if( rebuy_data[client][index] == 0 ) return;
	
	new WeaponID:id;
	if( index == REBUY_HE ) id = WEAPON_HEGRENADE;
	else if( index == REBUY_FLASH ) id = WEAPON_FLASHBANG;
	else if( index == REBUY_SMOKE ) id = WEAPON_SMOKEGRENADE;
	else if( index == REBUY_MOLOTOV ) id = (GetClientTeam(client) == 2 ? WEAPON_MOLOTOV : WEAPON_INCGRENADE);
	else if( index == REBUY_DECOY ) id = WEAPON_DECOY;
	
	
	new count = rebuy_data[client][index];
	//PrintToChatAll( "testes2, %d", count );
	new ammo = GetEntProp( client, Prop_Send, "m_iAmmo", _, AMMO_INDEX_HE+index-REBUY_HE );
	//PrintToChatAll( "testes2, %d", ammo );
	count -= ammo;
	new max = (index == REBUY_FLASH ? c_ammo_grenade_limit_flashbang : c_ammo_grenade_limit_default);
	if( ammo+count > max ) count -= (ammo+count)-max;
	//PrintToChatAll( "testes3, %d", max );
	
	if( count <= 0 ) return;
	//PrintToChatAll( "issuerebuy,grenade, index=%d,count=%d,max=%d", index,count,max );
	
	decl String:buy_string[64];
	Format( buy_string, sizeof( buy_string), "buy %s;", weaponNames[id] );
	
	for( new i = 0; i < count && i < 3; i++ ) { 
		StrCat( result, maxlen, buy_string ); 
	}
}

//----------------------------------------------------------------------------------------------------------------------
IssueRebuy( client ) {
	decl String:rebuy_string[1024];
	decl String:buy_string[32];
	rebuy_string[0] = 0;
	new team = GetClientTeam(client);

	if( !IsClientInGame(client) ) return;

	//Rebuy_DiscardUnusedGrenades( client );
	
	// buy a primary ONLY if the player doesn't have one
	if( GetPlayerWeaponSlot(client,int:SlotPrimmary) == -1 ) {
		
		new WeaponID:weap = WeaponID:rebuy_data[client][REBUY_MAIN];
		if( weap != WEAPON_NONE ) {
			weap = TranslateWeaponForTeam( client, weaponNames[weap], weap ); 

			if( weap != WEAPON_NONE ) {
				Format( buy_string, sizeof(buy_string), "buy %s%s;", weaponNames[weap], weap==WEAPON_SAWEDOFF?" 22":"" );
				StrCat( rebuy_string, sizeof(rebuy_string), buy_string );
			}
		}
	}
	
	// buy armor
	if( GetEntProp( client, Prop_Send, "m_ArmorValue" ) == 0 ) {
		if( rebuy_data[client][REBUY_ARMOR] == 1 ) {
			StrCat( rebuy_string, sizeof( rebuy_string), "buy vest;" );
		} else if( rebuy_data[client][REBUY_ARMOR] == 2 ) {
			StrCat( rebuy_string, sizeof( rebuy_string), "buy vesthelm;" );
		}
	}
	
	// grenades flashbang -> smoke -> fire -> he -> decoy
	
	if( GetPlayerTotalGrenades(client) < c_ammo_grenade_limit_total ) {
		for( new i = 0; i < 5; i++ )
			IssueRebuy_Grenade( rebuy_string, sizeof(rebuy_string), client, REBUY_HE+i );
		
	}
		/*
	#define REBUY_GRENADE_MACRO(index,id,ammo_index,max) \
	if( rebuy_data[client][index] > 0 ) { \
		new count = 3; \
		new ammo = GetEntProp( i, Prop_Send, "m_iAmmo", _, ammo_index ); \
		if( (ammo + count) > max ) count = max - ammo; \
		if( count > 0 ) { \
			Format( buy_string, sizeof( buy_string), "buy %s;", weaponNames[id] ); \
			for( new i = 0; i < rebuy_data[client][index] && i < count; i++ ) { \
				StrCat( rebuy_string, sizeof(rebuy_string), buy_string ); \
			} \
		} \
	}
	
	if( GetPlayerTotalGrenades(client) < c_ammo_grenade_limit_total ) {
			
		REBUY_GRENADE_MACRO( REBUY_FLASHBANG, WEAPON_FLASHBANG, AMMO_INDEX_FLASH, c_ammo_grenade_limit_flashbang );
		REBUY_GRENADE_MACRO( REBUY_SMOKE, WEAPON_SMOKE, AMMO_INDEX_SMOKE, c_ammo_grenade_limit_default );
		if( team == 2 ) {
			REBUY_GRENADE_MACRO( REBUY_MOLOTOV, WEAPON_MOLOTOV, AMMO_INDEX_FIRE, c_ammo_grenade_limit_default );
		} else if( team == 3 ) {
			REBUY_GRENADE_MACRO( REBUY_MOLOTOV, WEAPON_INCGRENADE, AMMO_INDEX_FIRE, c_ammo_grenade_limit_default );
		}
		REBUY_GRENADE_MACRO( REBUY_HEGRENADE, WEAPON_HEGRENADE, AMMO_INDEX_HE, c_ammo_grenade_limit_default );
		REBUY_GRENADE_MACRO( REBUY_DECOY, WEAPON_DECOY, AMMO_INDEX_DECOY, c_ammo_grenade_limit_default );
	}*/
	
	// pistol
	new pistol = GetPlayerWeaponSlot(client,int:SlotPistol);
	new bool:buy_pistol;
	if( pistol == -1 ) {
		buy_pistol = true;
	} else {
		GetEntityClassname( pistol, buy_string, sizeof(buy_string) );
		
		if( team == 2 ) {
			buy_pistol = StrEqual( buy_string, "weapon_glock" );
		} else if( team == 3 ) {
			buy_pistol = StrEqual( buy_string, "weapon_hkp2000" );
		}
	}
	if( buy_pistol ) {
		new WeaponID:weap = WeaponID:rebuy_data[client][REBUY_PISTOL];
		if( weap != WEAPON_NONE ) {
			weap = TranslateWeaponForTeam( client, weaponNames[weap], weap );
			
			if( weap != WEAPON_NONE ) {
				if( weap == WEAPON_CZ75A ) weap = WEAPON_P250; // so-many-fucking-hacks-lol
				Format( buy_string, sizeof(buy_string), "buy %s%s;", weaponNames[weap], weap==WEAPON_FIVESEVEN?" 5":"" );
				StrCat( rebuy_string, sizeof(rebuy_string), buy_string );
			}
		}
	}
	
	if( rebuy_data[client][REBUY_DEFUSER] && !GetEntProp( client, Prop_Send, "m_bHasDefuser" ) ) {
		if( team == 2 ) {
			rebuy_data[client][REBUY_DEFUSER] = 0;
		} else {
			StrCat( rebuy_string, sizeof(rebuy_string), "buy defuser;" );
		}
		//PrintToChatAll( "testes2: abc" );
		
	}
	
	if( rebuy_data[client][REBUY_ZUES] ) {
		StrCat( rebuy_string, sizeof(rebuy_string), "buy taser 34;" );
	}
	
	if( rebuy_string[0] != 0 ) {
		ClientCommand( client, rebuy_string );
	}
}

//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Rebuy( client, args ) {
	if( GetEntProp( client, Prop_Send, "m_bInBuyZone" ) ) {
		if( ((rebuy_flags[client]&(4+2))== 0) ) { 
			rebuy_flags[client] = 4;
			
			BypassBuyCommand( client );
			IssueRebuy( client );
		} else {
			if( rebuy_flags[client] &4 ) {
				PrintCenterText( client, "You cannot use Rebuy again until next round." );
			} else if( rebuy_flags[client] &2 ) {
				PrintCenterText( client, "You cannot use Rebuy until next round." );
			}
		}
	} else {
		PrintCenterText( client, "You are not in a buy zone." );
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ){
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client <= 0 ) return;
	
	rebuy_flags[client] |= 1;
}

public Action:BypassBuyCommandTimer( Handle:timer, any:client ) {
	
	bypass_buycommand[client] = false;
	return Plugin_Handled;
}

BypassBuyCommand( client ) {
	if( !bypass_buycommand[client] ) {
		bypass_buycommand[client] = true;
		CreateTimer( 0.2, BypassBuyCommandTimer, client, TIMER_FLAG_NO_MAPCHANGE );
	}
}
