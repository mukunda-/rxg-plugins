
#include <sourcemod>
#include <sdktools>
//#include <tf2_stocks>
#include <rxgcommon>
#include <dbrelay>
#include <rxgstore>
//#include <morecolors>
	
#pragma semicolon 1
//#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Reflex Easter Egg Hunt",
	author = "Roker",
	description = "Pickup dem eggs.",
	version = "1.0.2",
	url = "www.reflex-gamers.com"
};

char files[][] = {
	"materials/models/props_easteregg/c_easteregg.vtf",
	"materials/models/props_easteregg/c_easteregg.vmt",
	"materials/models/props_easteregg/c_easteregg_gold.vmt",
	"models/player/saxton_hale/w_easteregg{version}.mdl",
	"models/player/saxton_hale/w_easteregg{version}.dx90.vtx",
	"models/player/saxton_hale/w_easteregg{version}.vvd",
	"models/player/saxton_hale/w_easteregg{version}.phy",
	"sound/rxg/items/egg_sound.mp3"
};
char egg_model[64] = "models/player/saxton_hale/w_easteregg{version}.mdl";
char egg_sound[64] = "rxg/items/egg_sound.mp3";

int GAME;

char item_color[24];
char initial_space[24];

#define GAME_CSGO	0
#define GAME_TF2	1

//-----------------------------------------------------------------------------
public OnPluginStart() {
	char gamedir[64];
	GetGameFolderName( gamedir, sizeof gamedir );
	if( StrEqual(gamedir, "csgo") ) {  
		GAME = GAME_CSGO;
	} else {
		GAME = GAME_TF2;
	}
	if( GAME == GAME_CSGO ) {
		ReplaceString( egg_model, sizeof egg_model, "{version}", "_csgo" );
		Format( egg_sound, sizeof egg_sound, "*%s", egg_sound );
	} else {
		ReplaceString( egg_model, sizeof egg_model, "{version}", "" );
	}
	
	item_color = GAME == GAME_TF2 ? "\x07874fad" : "\x03";
	initial_space = GAME == GAME_CSGO ? "\x01 " : "\x01";
	
	HookEvent("player_death", Event_Player_Death, EventHookMode_Pre);
}
//-----------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( egg_model );
	PrecacheSound( egg_sound );
	
	for( new i = 0; i < sizeof files; i++ ) {
		decl String:file[64];
		strcopy( file, sizeof file, files[i] );
		if( GAME == GAME_CSGO ) {
			ReplaceString( file, sizeof file, "{version}", "_csgo" );
		} else {
			ReplaceString( file, sizeof file, "{version}", "" );
		}
		AddFileToDownloadsTable( file );
	}
	
	if( GAME == GAME_TF2 ) {
		AddFileToDownloadsTable( "models/player/saxton_hale/w_easteregg.dx80.vtx" );
		AddFileToDownloadsTable( "models/player/saxton_hale/w_easteregg.sw.vtx" );
	}
}
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char [] name, bool dontBroadcast ) {
	int killer = GetClientOfUserId( GetEventInt( event, "attacker" ));
	int client = GetClientOfUserId( GetEventInt( event, "userid" ));
	if(killer != client && GetClientCount() > 6){
		if (GetRandomInt(0, 5) == 1){
			dropEgg(client);
		}
	}
}
dropEgg(client){
	int ent = CreateEntityByName( "prop_physics_override" );
	DispatchKeyValue( ent, "targetname", "RXG_EGG" );
	SetEntityModel( ent, egg_model );
	
	float pos[3];
	GetClientEyePosition(client,pos);
	
	
	if( GAME==GAME_CSGO ){
		SetEntityRenderColor( ent, 128,128,128);
	}
	
	DispatchKeyValue( ent, "spawnflags", "256" );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	DispatchSpawn( ent );
	
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	AddTrigger(ent);
}
//-----------------------------------------------------------------------------
AddTrigger( parent ) {
	
	int ent = CreateEntityByName( "trigger_once" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", parent );
	DispatchKeyValue( ent, "spawnflags", "1" );
	DispatchKeyValue( ent, "StartDisabled", "1" );
	
	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", parent );
	AcceptEntityInput( ent, "Disable" );
	
	SetEntityModel( ent, egg_model );
	
	float minbounds[3] = {-33.0, -33.0, -33.0};
	float maxbounds[3] = {33.0, 33.0, 33.0};
	SetEntPropVector( ent, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", maxbounds);


	SetEntProp( ent, Prop_Send, "m_usSolidFlags", 4|8 |0x400); //FSOLID_TRIGGER|FSOLID_TRIGGER_TOUCH_PLAYER
	SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test

	int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);

	float pos[3];
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	
	HookSingleEntityOutput( ent, "OnStartTouch", TriggerTouched );
	return ent;
	
}
//-----------------------------------------------------------------------------
public TriggerTouched( const char [] output, caller,activator, float delay ) {
	OnEggTouch( caller, activator );
}
//-----------------------------------------------------------------------------
public OnEggTouch( entity, client) {
	if( IsFakeClient( client ) ) return;
	if(!givePrize(client)) return;
	eggDB(client);
	
	entity = GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" );
	EmitSoundToAll( egg_sound, client );
	
	AcceptEntityInput( entity, "Kill" );
	givePrize(client);
}
bool givePrize(client){
	int random = GetRandomInt(0, 5000);
	int itemID = -1;
	char itemName[64];
	bool bigItem = false;
	int cashDropped = 0;
	char clientName[64];
	GetClientName(client,clientName,64);
	if(GAME == GAME_CSGO){
		if(random <= 1){
			//nuke
			itemName = "Nuke";
			itemID = 5;
		}else if(random <= 150){
			//negev
			itemName = "Negev";
			itemID = 3;
		}else if(random <= 600){
			//radio
			itemName = "Disposable Radio";
			itemID = 2;
		}else if(random <= 1050){
			//cookie
			itemName = "Cookie";
			itemID = 4;
		}else if(random <= 3300){
			//chicken
			itemName = "Chicken";
			itemID = 7;
		}else{
			cashDropped = GetRandomInt(50, 150);
			if(!RXGSTORE_AddCash( client,  cashDropped)){
				LogError("Tried to give %s %i cash. Failed.", clientName, cashDropped);
				return false;
			}
			PrintToChat(client, "You found \x04$%i \x01in an easter egg!",cashDropped);
		}
	}
	if(GAME == GAME_TF2){
		if(random <= 50){
			//time warp
			itemName = "Time Warp";
			itemID = 12;
		}else if(random <= 175){
			//boss monoculus
			itemName = "Boss Monoculus";
			itemID = 8;
		}else if(random <= 425){
			//roman candle
			itemName = "Roman Candle";
			itemID = 10;
		}else if(random <= 675){
			//fire cracker
			itemName = "Fire Cracker";
			itemID = 11;
		}else if(random <= 1175){
			//spectral monoculus
			itemName = "Spectral Monoculus";
			itemID = 9;
		}else if(random <= 1675){
			//cookie
			itemName = "Cookie";
			itemID = 4;
		}else if(random <= 3340){
			//pumpkin
			itemName = "Pumpkin Bomb";
			itemID = 6;
		}else{
			cashDropped = GetRandomInt(50, 150);
			if(!RXGSTORE_AddCash( client,  cashDropped)){
				LogError("Tried to give %s %i cash. Failed.", clientName, cashDropped);
				return false;
			}
			PrintToChat(client, "%sYou found \x04$%i \x01in an easter egg!", initial_space, cashDropped);
		}
	}
	if(itemID != -1){
		if(!RXGSTORE_GiveItem( client, itemID )){
			LogError("Tried to give %s item '%s' with ID %i. Failed.", clientName, itemName, itemID);
			return false;
		}
		bigItem = (random <= 50);
		if(bigItem){
			PrintCenterTextAll("%s has just found a %s in an Easter Egg!!!", clientName, itemName);
		}else{
			PrintCenterText(client, "You found a %s store item!", itemName);
		}
		PrintToChat(client, "%sYou found a %s%s \x01in an Easter Egg. Type \x04!useitem \x01to use it.", initial_space, item_color, itemName);
	}
	itemDropDB(client,itemID,cashDropped);
	return true;
}
itemDropDB(client,itemID,cashDropped){
	if( DBRELAY_IsConnected() ){
        int account = GetSteamAccountID(client);
        if (account == 0){ return;}
        
        int val = 1;
        char query[1024];
        if(itemID == -1){
        	val = cashDropped;
        }
        FormatEx( query, sizeof query, "INSERT INTO sourcebans_easter.drops( account, item, count ) VALUES ( %i, %i, %i ) ON DUPLICATE KEY UPDATE count = count + %i", account, itemID, val , val);
        
        DBRELAY_TQuery( IgnoredSQLResult, query );
     }
}
//-----------------------------------------------------------------------------
eggDB(client){
     if( DBRELAY_IsConnected() ){
        int account = GetSteamAccountID(client);
        if (account == 0){ return;}
        
        char query[1024];
        FormatEx( query, sizeof query, "INSERT INTO sourcebans_easter.players( account, egg_count ) VALUES ( %i, %i ) ON DUPLICATE KEY UPDATE egg_count = egg_count + 1", account, 1 );
        DBRELAY_TQuery( IgnoredSQLResult, query );
     }
}
//-----------------------------------------------------------------------------
public IgnoredSQLResult( Handle owner, Handle hndl, const char [] error, any data ) {
    if( !hndl ) {
        LogError( "SQL Error --- %s", error );
        return;
    }
}