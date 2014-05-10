

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike_weapons>

//#define USE_DONATIONS

#if defined USE_DONATIONS

#include <donations>

#endif


//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "GRENADELIMITER",
	author = "mukunda",
	description = "Limit of grenade uses per team",
	version = "1.0.1",
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
enum {
	GRENADE_SMOKE,
	GRENADE_FRAG,
	GRENADE_FLASH,
	GRENADE_DECOY,
	GRENADE_INC,
	GRENADE_TYPES
};

new String:grenade_names[][] = {
	"SMOKE","FRAG","FLASH","DECOY","INC"
};

new String:grenade_names2[][] = {
	"Smoke Grenades", "Frags", "Flashbangs", "Decoys", "Firebombs"
};

new String:grenade_classnames[][] = {
	"smokegrenade_projectile","hegrenade_projectile","flashbang_projectile","decoy_projectile","incgrenade_projectile","molotov_projectile"
};

new String:team_names[][] = {
	"TERRORIST","COUNTER-TERRORIST","BOTH TEAMS"
};

//-------------------------------------------------------------------------------------------------
new String:usage[] = "usage: sm_nadelimit smoke/frag/flash/decoy/inc -1/<amount> ct/t/both";
new limits[GRENADE_TYPES*2];
new counters[GRENADE_TYPES*2];

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	for( new i = 0; i < GRENADE_TYPES*2; i++ ) {
		limits[i] = -1;
	}
	
	HookEvent( "round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	RegServerCmd( "sm_nadelimit", Command_nadelimit );
}

//-------------------------------------------------------------------------------------------------
ResetCounters() {
	for( new i = 0; i < GRENADE_TYPES*2; i++ ) {
		counters[i] = 0;
	}
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	ResetCounters();
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	ResetCounters();
}

//-------------------------------------------------------------------------------------------------
GetArgType( arg ) {
	decl String:test[32];
	GetCmdArg( arg, test, sizeof(test) );
	for( new i = 0; i < GRENADE_TYPES; i++ ) {
		if( StrEqual( test, grenade_names[i], false ) ) {
			return i;
		}
	}
	return -1;
}

//-------------------------------------------------------------------------------------------------
GetArgInt( arg ) {
	decl String:data[32];
	GetCmdArg( arg, data, sizeof(data) );
	return StringToInt( data );
}

//-------------------------------------------------------------------------------------------------
GetArgTeam( arg ) {
	decl String:test[32];
	GetCmdArg( arg, test, sizeof(test) );
	if( StrEqual( test, "t", false ) ) {
		return 1;
	} else if( StrEqual( test, "ct", false ) ) {
		return 2;
	} else if( StrEqual( test, "both", false ) ) {
		return 3;
	}
	return 0;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_nadelimit( args ) {
	// nadelimit <type> <amount> <team>

	if( args < 3 ) {
		ReplyToCommand( 0, usage );
		return Plugin_Handled;
	}
	new type = GetArgType( 1 );
	if( type == -1 ) {
		ReplyToCommand( 0, "Invalid TYPE" );
		ReplyToCommand( 0, usage );
		return Plugin_Handled;
	}
	
	new amount = GetArgInt( 2 );
	if( amount < 0 ) amount = -1;
	
	new team = GetArgTeam( 3 );
	if( team == 0 ) {
		ReplyToCommand(0, "Invalid TEAM" );
		ReplyToCommand( 0, usage );
		return Plugin_Handled;
	}
	
	if( team & 1 ) {
		limits[type*2] = amount;
	}
	if( team & 2 ) {
		limits[type*2+1] = amount;
	}
	if( amount == -1 ) {
		ReplyToCommand( 0, "Removed limit from %s for %s", grenade_names[type], team_names[team-1] );
	} else {
		ReplyToCommand( 0, "Set limit for %s to %d for %s", grenade_names[type], amount, team_names[team-1] );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------

// now for the limiting...

GrenadeSpawned( ent, type ) {

	new owner = GetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity" );
	
	if( owner <= 0 ) return;
	new team = GetClientTeam(owner);
	team -= 2;
	if( team < 0 ) return;
	// 0=t, 1=ct
	new limit = limits[type*2+team];
	
	if( limit != -1 && (counters[type*2+team] >= limits[type*2+team]) ) {
		
		
		#if defined USE_DONATIONS
		if( Donations_GetClientLevel(owner) ) {
			return; // donators bypass limit
		}
		#endif
		
		decl Float:the_nether[3] = {2000.0,2000.0,-2000.0}
		//SetEntPropFloat( ent, Prop_Data, "m_flDetonateTime", 0.0 );
		//AcceptEntityInput( ent, "Kill" );
		TeleportEntity( ent, the_nether, NULL_VECTOR, NULL_VECTOR );
		PrintToChat( owner, "\x01 \x02(Grenade Removed)\x01 Your team cannot use any more %s this round.", grenade_names2[type] );
		PrintHintText( owner, "(Grenade Removed) Your team cannot use any more %s this round.", grenade_names2[type] );
	} else {
		counters[type*2+team]++;
	}
}

public Action:DelayTest( Handle:timer, any:data ) {
	decl String:classname[64];
	new entity = data;
	if( !IsValidEntity(entity) ) return Plugin_Handled;

	GetEntityClassname( data, classname, sizeof(classname) );
	

	for( new i = 0; i < GRENADE_TYPES; i++ ) {
		if( StrEqual(classname, grenade_classnames[i]) ) {
			
			GrenadeSpawned( entity, i );
			return Plugin_Handled;
		}
	}
	if( StrEqual(classname, grenade_classnames[GRENADE_INC+1]) ) {
		GrenadeSpawned( entity, GRENADE_INC );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnEntityCreated( entity, const String:classname[] ) {

	for( new i = 0; i < GRENADE_TYPES; i++ ) {
		if( StrEqual(classname, grenade_classnames[i]) ) {
			
			CreateTimer( 0.1, DelayTest, entity, TIMER_FLAG_NO_MAPCHANGE );
			return;
			//GrenadeSpawned( entity, i );

		}
	}
	if( StrEqual(classname, grenade_classnames[GRENADE_INC+1]) ) {
		CreateTimer( 0.1, DelayTest, entity, TIMER_FLAG_NO_MAPCHANGE );
		
		
		//GrenadeSpawned( entity, GRENADE_INC );
	}
}

//-------------------------------------------------------------------------------------------------
