 
//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools> 
#include <sdkhooks>
#include <rxgstore>
#include <rxgcommon>

#undef REQUIRE_PLUGIN
#include <tf2use>

#pragma semicolon 1 

// 1.0.4
//   check if store is connected before spawning cash

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "RXGCASH",
	author = "mukunda",
	description = "Dat monay",
	version = "2.0.0",
	url = "www.mukunda.com"
};
 
new String:money_model[64];
new String:take_sound[64];
//#define money_model "models/props/cs_assault/money.mdl"
//#define take_sound "weapons/flashbang/flashbang_draw.wav"
   
new pickup_message_amount[MAXPLAYERS+1];
new Float:pickup_message_time[MAXPLAYERS+1];
#define PICKUP_MESSAGE_LEN 6.0

// for preventing prop spawn abuse
new cash_drop_counter[MAXPLAYERS+1];

#define CASHDROP_MAX 15

new entprop_cash_amount[2048];
new entprop_cash_owner[2048];
  
new Handle:sm_dropcash_chance;
new Handle:sm_dropcash_amount;
new Handle:sm_dropcash_min;
new Handle:sm_dropcash_max;
new Float:c_dropcash_chance;
new c_dropcash_amount;
new c_dropcash_min;
new c_dropcash_max;

new Handle:sm_dropcash_limitents;
new c_dropcash_limitents;

new cash_ent_buffer[500]; // max=500
new cash_ent_next;

//#define TF2_CASH_SCALE 1.5
new Float:g_cash_spawn_time[2048];
#define TF2_CASH_ACTIVATION_DELAY 1.0
#define TF2_VERTICAL_OFFSET 20.0

new GAME;

#define GAME_CSGO	0
#define GAME_TF2	1
 
    
//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_dropcash_chance = GetConVarFloat( sm_dropcash_chance );
	c_dropcash_amount = GetConVarInt( sm_dropcash_amount );
	c_dropcash_min = GetConVarInt( sm_dropcash_min );
	c_dropcash_max = GetConVarInt( sm_dropcash_max );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}


//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	LoadTranslations("common.phrases");
	
	decl String:gamedir[64];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual(gamedir, "csgo") ){ 
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	
	
	
	if( GAME == GAME_CSGO ) {
		money_model = "models/props/cs_assault/money.mdl";
		take_sound = "weapons/flashbang/flashbang_draw.wav";
	} else {
		//money_model = "models/rxg/items/cash.mdl";
		//take_sound = "weapons/draw_melee.wav";
		//take_sound = "ui/credits_updated.wav";
		take_sound = "mvm/mvm_money_pickup.wav";
	}
	
	sm_dropcash_chance = CreateConVar( "sm_dropcash_chance", "0.1", "Chance that a CASHWADS will drop.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
	sm_dropcash_amount = CreateConVar( "sm_dropcash_amount", "3", "How many CASHWADS will try to drop from killed players.", FCVAR_PLUGIN, true, 0.0 );
	sm_dropcash_min = CreateConVar( "sm_dropcash_min", "10", "Minimum amount of CASH a single CASHWAD can give.", FCVAR_PLUGIN, true, 0.0 );
	sm_dropcash_max = CreateConVar( "sm_dropcash_max", "50", "Maximum amount of CASH a single CASHWAD can give.", FCVAR_PLUGIN, true, 0.0 );
	HookConVarChange( sm_dropcash_chance, OnConVarChanged );
	HookConVarChange( sm_dropcash_amount, OnConVarChanged );
	HookConVarChange( sm_dropcash_min, OnConVarChanged );
	HookConVarChange( sm_dropcash_max, OnConVarChanged );
	RecacheConvars();
	
	sm_dropcash_limitents = CreateConVar( "sm_dropcash_limitents", "0", "Limit number of cash entities, 0=unlimited, takes effect next round start.", FCVAR_PLUGIN, true, 0.0, true, 500.0 );
	c_dropcash_limitents = GetConVarInt( sm_dropcash_limitents );
	
	if( GAME == GAME_TF2 ) {
		HookEvent( "teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy ); 
	} else {
		HookEvent( "round_start", OnRoundStart, EventHookMode_PostNoCopy ); 
	}
	
	HookEvent( "player_death", OnPlayerDeath ); 
	RegAdminCmd( "sm_spawncash", Command_SpawnCash, ADMFLAG_RCON );
	RegConsoleCmd( "sm_dropcash", Command_DropCash );
    
	if( GAME==GAME_TF2 ) {
		//RegConsoleCmd( "voicemenu", Command_voicemenu );
	} else {
		HookEvent( "player_use", OnPlayerUse );
	}
}

public OnAllPluginsLoaded() {
	if( GAME == GAME_TF2 ) {
		if( !LibraryExists( "tf2use" ) ) {
			SetFailState( "Required Library \"tf2use\" not installed!" );
			return;
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_SpawnCash( client, args ) {

	if( !RXGSTORE_IsConnected() ) {
		ReplyToCommand( client, "Store is not connected yet." );
		return Plugin_Handled;
	}
	new Float:vec[3];
	if( GAME == GAME_TF2 ) {
		GetClientAbsOrigin( client, vec );
		vec[2] += TF2_VERTICAL_OFFSET;
	} else {
		GetClientEyePosition( client, vec );
	}
	SpawnCash( vec, NULL_VECTOR, 5,  0 );
	return Plugin_Handled;
}
 
//-------------------------------------------------------------------------------------------------
ResetCounters() {
	for( new i = 1; i <= MaxClients; i++ ) { 
		cash_drop_counter[i] = 0;
	}
	cash_ent_next = 0;
	c_dropcash_limitents = GetConVarInt( sm_dropcash_limitents );
}
//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	if( GAME == GAME_TF2 ) {
		/*
		AddFileToDownloadsTable( "materials/rxg/items/cash.vmt" );
		AddFileToDownloadsTable( "materials/rxg/items/cash.vtf" );
		AddFileToDownloadsTable( "models/rxg/items/cash.dx80.vtx" );
		AddFileToDownloadsTable( "models/rxg/items/cash.dx90.vtx" );
		AddFileToDownloadsTable( "models/rxg/items/cash.mdl" );
		AddFileToDownloadsTable( "models/rxg/items/cash.phy" );
		AddFileToDownloadsTable( "models/rxg/items/cash.sw.vtx" );
		AddFileToDownloadsTable( "models/rxg/items/cash.vvd" );
		*/
		PrecacheModel( "models/items/currencypack_small.mdl" );
		PrecacheModel( "models/items/currencypack_medium.mdl" );
		PrecacheModel( "models/items/currencypack_large.mdl" );
	} else {
		PrecacheModel( money_model );
	}
	PrecacheSound( take_sound );
	ResetCounters();
}

//-------------------------------------------------------------------------------------------------
public OnRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	ResetCounters();
}

//-------------------------------------------------------------------------------------------------
public OnPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new attacker = GetClientOfUserId(GetEventInt( event, "attacker" ));
	new victim = GetClientOfUserId(GetEventInt( event, "userid" )); 
	if( victim == 0 ) return; // ???
	 
	if( IsFakeClient( victim ) ) return;
	
	if( attacker == victim ) {
		// suicide 
		return;
	}
	if( attacker == 0 ) {
		// slayed/world 	
		return;
	}
	
	new Float:multiplier = 1.0;
	
	if( GAME == GAME_CSGO ) {
		decl String:weap[64];
		GetEventString( event, "weapon", weap, sizeof(weap) );
		if( StrContains( weap, "knife" ) >= 0 ) {
			multiplier = 4.0;
		}
	}
	
	decl Float:vec[3];
	
	if( GAME == GAME_TF2 ) {
		GetClientAbsOrigin( victim, vec );
	} else {
		GetClientEyePosition( victim, vec );
	}
	
	for( new i = 0; i < c_dropcash_amount; i++ ) {
		 
		if( GetRandomFloat(0.0,1.0) > c_dropcash_chance*multiplier ) continue;
		 
		DropPlayerCashFunc( victim, vec, false, GetRandomInt( c_dropcash_min, c_dropcash_max ), false );
	}
}

//-------------------------------------------------------------------------------------------------
PrintPickupMessage( client, amount ) {
	new Float:time = GetGameTime();
	
	if( (time - pickup_message_time[client]) > PICKUP_MESSAGE_LEN ) {
		// new msg
		pickup_message_time[client] = time;
		pickup_message_amount[client] = amount;
	} else {
		// add to msg
		pickup_message_time[client] = time;
		pickup_message_amount[client] += amount;
	}
	
	new cash = pickup_message_amount[client];
	
	decl String:cash_string[16];
	FormatNumberInt( cash, cash_string, sizeof cash_string, ',' );
	
	//PrintHintText( client, "<font size='20px'>You picked up %d\xC2\xA2!", pickup_message_amount[client] );
	if( GAME == GAME_CSGO ) {
		PrintHintText( client, "<font size='24'>You picked up <font color='#53ed53'>$%s</font>!!</font>", cash_string );
	} else {
		PrintHintText( client, "You picked up $%s!!", cash_string );
	}
}


//-------------------------------------------------------------------------------------------------
SpawnCash( const Float:pos[3], const Float:vel[3], amount, dropper ) {
	if( !RXGSTORE_IsConnected() ) {
		return ;
	}
	new ent;

	if( GAME == GAME_TF2 ) {
		ent = CreateEntityByName( "item_currencypack_custom" );
		DispatchSpawn(ent);
		g_cash_spawn_time[ent] = GetGameTime();
	} else {
		ent = CreateEntityByName( "prop_physics_override" );
		DispatchKeyValue( ent, "model", money_model ); 
		DispatchKeyValue( ent, "spawnflags", "256" );	// usable
		DispatchKeyValue( ent, "targetname", "RXGCASHMONAY" );
		
		SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 ); // set non-collidable  
		AcceptEntityInput( ent, "DisableDamageForces" );
		DispatchSpawn(ent);
		
		// we delay damage forces so when someone dies, the bullets that killed them arent able to instantly knock the cash away
		CreateTimer( 1.2, EDFTimer, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE );
	}
	
	/*
	if( GAME == GAME_TF2 ){
		SetEntPropFloat( ent, Prop_Data, "m_flModelScale", TF2_CASH_SCALE );
	}
	*/
	
	entprop_cash_amount[ent] = amount;
	entprop_cash_owner[ent] = dropper;

	new Float:ang[3];
	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );
	TeleportEntity( ent, pos, ang, vel );
 
	if( GAME == GAME_TF2 ) {
		SDKHook( ent, SDKHook_Touch, OnCashTouch_TF2 );
		//TF2Use_Hook( ent, OnCashTouch );
	}
	
	if( c_dropcash_limitents ) {
		if( cash_ent_buffer[cash_ent_next] && EntRefToEntIndex( cash_ent_buffer[cash_ent_next] ) != INVALID_ENT_REFERENCE ) {
			AcceptEntityInput( cash_ent_buffer[cash_ent_next], "kill" );
		}
		cash_ent_buffer[cash_ent_next++] = EntIndexToEntRef( ent );
		if( cash_ent_next == c_dropcash_limitents ) cash_ent_next = 0;
	}
}

//-------------------------------------------------------------------------------------------------
public Action:EDFTimer( Handle:timer, any:ent ) {
	
	if( !IsValidEntity(ent) ) return Plugin_Handled;
	AcceptEntityInput( ent, "EnableDamageForces" );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
GetClientThrowVector( client, Float:vec[], Float:power=1000.0 ) {

	new Float:eyeang[3];
	new Float:eyenorm[3];
	new Float:eyenorm_up[3];

	GetClientEyeAngles( client, eyeang );
	GetAngleVectors( eyeang, eyenorm, NULL_VECTOR, eyenorm_up );
	
	for( new i = 0; i < 3; i++ )
		vec[i] = eyenorm[i]*power + eyenorm_up[i] *power * 0.2;
}

//-------------------------------------------------------------------------------------------------
DropPlayerCashFunc( client, Float:vec[], bool:throw, amount, bool:count ) {
	new Float:vel[3];
	 
	// randomize throw/drop
	if( !throw ) {
		vel[0] = GetRandomFloat( -100.0, 100.0 );
		vel[1] = GetRandomFloat( -100.0, 100.0 );
		vel[2] = GetRandomFloat( 0.0, 400.0 );
	} else {
		GetClientThrowVector( client, vel, 200.0 );
		for( new i = 0; i < 3; i++ )
			vel[i] += GetRandomFloat( -20.0, 20.0 );
	}
	
	// randomize origin
	new Float:vec2[3];
	for( new i = 0; i < 3; i++ ) vec2[i] = vec[i];
	if( GAME == GAME_TF2 ) {
		vec2[0] += GetRandomFloat( -25.0, 25.0 );
		vec2[1] += GetRandomFloat( -25.0, 25.0 );
		vec2[2] += TF2_VERTICAL_OFFSET;
	} else {
		vec2[0] += GetRandomFloat( -5.0, 5.0 );
		vec2[1] += GetRandomFloat( -5.0, 5.0 );
		vec2[2] += GetRandomFloat( -25.0, 0.0 );
	}
	
	if( count ) cash_drop_counter[client]++;
	// spawn
	SpawnCash( vec2, vel, amount, count?client:0 );
}


//-------------------------------------------------------------------------------------------------
public OnPlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {  
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client <= 0 ) return;
	new ent = GetEventInt( event, "entity" );
	decl String:entname[64];
	GetEntPropString( ent, Prop_Data, "m_iName", entname, sizeof(entname) );
	if( !StrEqual( entname, "RXGCASHMONAY" ) ) return;
	OnCashTouch( client, ent ); 
}

//-------------------------------------------------------------------------------------------------
public bool:OnCashTouch( client, entity ) { 

	if( !RXGSTORE_IsClientLoaded(client) ) {
		PrintToChat( client, "Your items are still being loaded; cannot pickup cash!" );
		return false;
	}
	RXGSTORE_AddCash( client, entprop_cash_amount[entity] );
	PrintPickupMessage( client, entprop_cash_amount[entity] );
	if( entprop_cash_owner[entity] ) {
		cash_drop_counter[entprop_cash_owner[entity]]--;
	}
	EmitSoundToAll( take_sound, client );
	AcceptEntityInput( entity, "Kill" );
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action:OnCashTouch_TF2( entity, client ) {
	
	if( GetGameTime() < g_cash_spawn_time[entity] + TF2_CASH_ACTIVATION_DELAY ) {
		return Plugin_Handled;
	}
	
	if( client > 0 && client <= MaxClients ) {
		if( !RXGSTORE_IsClientLoaded(client) ) {
			// do not print for TF2 because this event happens to often
			//PrintToChat( client, "Your items are still being loaded; cannot pickup cash!" );
			return Plugin_Handled;
		}
		
		RXGSTORE_AddCash( client, entprop_cash_amount[entity] );
		PrintPickupMessage( client, entprop_cash_amount[entity] );
		if( entprop_cash_owner[entity] ) {
			cash_drop_counter[entprop_cash_owner[entity]]--;
		}
		
		EmitSoundToAll( take_sound, client );
		AcceptEntityInput( entity, "Kill" );
	}
	
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_DropCash( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	if( !IsPlayerAlive(client) ) return Plugin_Handled;
	
	if( !RXGSTORE_IsClientLoaded(client) ) {
		PrintToChat( client, "Your items are still being loaded." );
		return Plugin_Handled;
		
	}
	
	new amount = 50;
	if( args >= 1 ) {
		decl String:arg[32];
		GetCmdArg( 1, arg, sizeof( arg ) );
		amount = StringToInt( arg );
		if( amount < 50 ) {
			PrintCenterText( client, "You need to drop at least $50." );
			return Plugin_Handled;
		}
	}
	
	if( cash_drop_counter[client] >= CASHDROP_MAX ) {
		PrintCenterText( client, "You can't drop more cash." );
		return Plugin_Handled;
	}
	
	if( RXGSTORE_GetCash( client ) < amount ) {
		PrintCenterText( client, "You don't have enough cash." );
		return Plugin_Handled;
	}
	pickup_message_time[client] = 0.0; // magical
	
	RXGSTORE_TakeCash( client, amount, OnTakeCash );
	
	return Plugin_Handled;
} 

//-------------------------------------------------------------------------------------------------
public OnTakeCash( userid, amount, any:data, bool:failed ) {
	
	new client = GetClientOfUserId(userid);
	if( !client ) return; // disconnected, cash went into oblivion.
	
	if( failed ) {
		PrintCenterText( client, "Couldn't drop cash." );
		return;
	}
	
	
	new Float:vec[3];
	
	if( GAME == GAME_TF2 ) {
		GetClientAbsOrigin( client, vec );
	} else {
		GetClientEyePosition( client, vec );
	}
	
	DropPlayerCashFunc( client, vec, true, amount, true );
}
 