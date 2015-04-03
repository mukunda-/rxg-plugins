
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>
#include <dbrelay>
#include <rxgstore>
#include <morecolors>
	
#pragma semicolon 1
//#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Reflex Easter Egg Hunt",
	author = "Roker",
	description = "Pickup dem eggs.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

char files[][] = {
	"materials/models/props_easteregg/c_easteregg.vtf",
	"materials/models/props_easteregg/c_easteregg.vmt",
	"materials/models/props_easteregg/c_easteregg_gold.vmt",
	"models/player/saxton_hale/w_easteregg.mdl",
	"models/player/saxton_hale/w_easteregg.dx90.vtx",
	"models/player/saxton_hale/w_easteregg.vvd",
	"models/player/saxton_hale/w_easteregg.phy",
	"sound/rxg/items/egg_sound.mp3"
};
char egg_model[64] = "models/player/saxton_hale/w_easteregg.mdl";
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
	
	item_color = GAME == GAME_TF2 ? "\x07874fad" : "\x03";
	initial_space = GAME == GAME_CSGO ? "\x01 " : "";
	
	HookEvent("player_death", Event_Player_Death, EventHookMode_Pre);
}
//-----------------------------------------------------------------------------
public OnMapStart() {
	PrecacheModel( egg_model );
	PrecacheSound( egg_sound );
	
	for( new i = 0; i < sizeof files; i++ ) {
		AddFileToDownloadsTable( files[i] );
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
	if(killer != client){
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
	entity = GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" );
	EmitSoundToAll( egg_sound, client );
	
	AcceptEntityInput( entity, "Kill" );
	givePrize(client);
	eggDB(client);
}
givePrize(client){
	int random = GetRandomInt(0, 5000);
	int itemID = -1;
	char itemName[100];
	bool bigItem = false;
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
			itemID = 7;
		}else if(random <= 1675){
			//cookie
			itemName = "Cookie";
			itemID = 4;
		}else if(random <= 3340){
			//pumpkin
			itemName = "Pumpkin Bomb";
			itemID = 6;
		}else{
			int cashDropped = GetRandomInt(10, 500);
			RXGSTORE_AddCash( client,  cashDropped);
			PrintToChat(client, "%sYou found a {limegreen}$%i \x01in an easter egg!",initial_space,cashDropped);
		}
	}
	if(itemID != -1){
		RXGSTORE_GiveItem( client, itemID );
		bigItem = (random <= 50);
		if(bigItem){
			char clientName[64];
			GetClientName(client,clientName,64);
			PrintCenterTextAll("%s has just found a %s in an Easter Egg!!!",clientName,itemName);
		}else{
			PrintCenterText(client, "You found a %s store item!",itemName);
		}
		CPrintToChat(client, "You found a {unusual}%s \x01store item in an Easter Egg. Use {unusual}!useitem\x01 to use it.",itemName);
		CPrintToChatAll("You found a {unusual}%s \x01store item in an Easter Egg. Use {unusual}!useitem\x01 to use it.",itemName);
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