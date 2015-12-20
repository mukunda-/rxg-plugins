#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgcommon>
#include <rxgstore>
#include <dbrelay>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "",
    author = "grimAuxiliatrix",
    description = "",
    version = "1.0.0",
    url = "www.reflex-gamers.com"
};

#define GIFT_MODEL "models/rxg/items/gift/tf_gift_rxg.mdl"
#define GIFT_SOUND "misc/jingle_bells/jingle_bells_nm_0%i.wav"

char files[][] = {
	"models/rxg/items/gift/tf_gift_rxg.mdl",
	"models/rxg/items/gift/tf_gift_rxg.dx80.vtx",
	"models/rxg/items/gift/tf_gift_rxg.dx90.vtx",
	"models/rxg/items/gift/tf_gift_rxg.phy",
	"models/rxg/items/gift/tf_gift_rxg.sw.vtx",
	"models/rxg/items/gift/tf_gift_rxg.vvd",
	"materials/models/rxg/items/gift/tf_gift_rxg.vmt",
	"materials/models/rxg/items/gift/tf_gift_rxg.vtf"
};

Handle sm_gift_chance;

float c_gift_chance;

int GAME;

char item_color[24];
char initial_space[24];

#define GAME_CSGO   0
#define GAME_TF2    1


//-------------------------------------------------------------------------------------------------
void RecacheConvars() {
   c_gift_chance = GetConVarFloat( sm_gift_chance ); 

}

//-------------------------------------------------------------------------------------------------
public void OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval ) {
    RecacheConvars();
}

//-------------------------------------------------------------------------------------------------
public void OnPluginStart(){
    char gamedir[64];
    GetGameFolderName( gamedir, sizeof gamedir );
    
    if( StrEqual( gamedir, "csgo" ) ) {  
        GAME = GAME_CSGO;
    } else {
        GAME = GAME_TF2;
    }
    
    item_color = GAME == GAME_TF2 ? "\x07874fad" : "\x03";
    initial_space = GAME == GAME_CSGO ? "\x01 " : "\x01";

    HookEvent ("player_death", Event_Player_Death, EventHookMode_Pre);
    
    sm_gift_chance = CreateConVar("sm_gift_chance", "0.2", "Chance of a gift to drop", FCVAR_PLUGIN, true, 0.1);
    
    HookConVarChange( sm_gift_chance, OnConVarChanged );
    RecacheConvars();
}

//-------------------------------------------------------------------------------------------------
public void OnMapStart() {
    PrecacheModel( GIFT_MODEL );
    char sound[64];
    for( int i = 1; i <= 5; i++ ){
        Format(sound, sizeof(sound), GIFT_SOUND, i);
        PrecacheSound( sound );
    }
    for( int i = 0; i < sizeof files; i++ ) {
		char file[64];
		strcopy( file, sizeof file, files[i] );
		
		if( GAME == GAME_CSGO ) {
			ReplaceString( file, sizeof file, "{version}", "_csgo3" );
		} else {
			ReplaceString( file, sizeof file, "{version}", "" );
		}
		
		AddFileToDownloadsTable( file );
	}
}

//-------------------------------------------------------------------------------------------------
public Action Event_Player_Death(Handle event, char[] arg, bool noBroadcast){
    int victim = GetClientOfUserId( GetEventInt ( event, "userid" ) );
    int attacker = GetClientOfUserId( GetEventInt ( event, "attacker" ) );
    
    if ( victim == attacker ){
        return Plugin_Continue;
    }
    
    if ( GetRandomFloat( 0.0, 1.0 ) <= c_gift_chance ){
        float location[3];
        GetClientEyePosition( victim, location );
        
        SpawnGift(location);
    }
    return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
void SpawnGift(float location[3]){

    int ent = CreateEntityByName( "prop_physics_override" );
    DispatchKeyValue( ent, "targetname", "RXG_GIFT" );
    SetEntityModel( ent, GIFT_MODEL );
    
    float scale = 1.3;
    SetEntPropFloat( ent, Prop_Data, "m_flModelScale", scale );
    
    DispatchKeyValue( ent, "spawnflags", "256" );
    SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
    DispatchSpawn( ent );
    ActivateEntity( ent );
        
    TeleportEntity( ent, location, NULL_VECTOR, NULL_VECTOR );
    
    AddTrigger( ent ); 
}

//-----------------------------------------------------------------------------
public Action GiftTouched(int gift, int client){
    if( !IsValidClient(client) || IsFakeClient(client) ) return Plugin_Continue;
    if( !givePrize(client) ) return Plugin_Continue;
    
    giftDB(client);
    
    char sound[64];
    Format( sound, sizeof( sound ), GIFT_SOUND, GetRandomInt( 1, 5 ) );
    
    EmitSoundToAll( sound , client );
    
    //if( GAME == GAME_TF2 ) {
        // get trigger parent
    gift = GetEntPropEnt( gift, Prop_Send, "m_hOwnerEntity" );
    //}
    
    AcceptEntityInput( gift, "Kill" );
    return Plugin_Continue;
}

//-----------------------------------------------------------------------------
int AddTrigger( int parent ) {
    
    int ent = CreateEntityByName( "trigger_multiple" );
    SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", parent );
    DispatchKeyValue( ent, "spawnflags", "1" );
    
    DispatchSpawn(ent);
    SetVariantString( "!activator" );
    AcceptEntityInput( ent, "SetParent", parent );
    
    float minbounds[3] = {-33.0, -33.0, -33.0};
    float maxbounds[3] = {33.0, 33.0, 33.0};
    SetEntPropVector( ent, Prop_Send, "m_vecMins", minbounds);
    SetEntPropVector( ent, Prop_Send, "m_vecMaxs", maxbounds);
    SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // something to do with bounding box test

    float pos[3];
    TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
    
    SDKHook( ent, SDKHook_Touch, GiftTouched );
    return ent;
}

//-----------------------------------------------------------------------------
bool givePrize( int client ) {

    int random = GetRandomInt(0, 5000);
    int itemID = -1;
    char itemName[64];
    bool bigItem = false;
    int cashDropped = 0;
    char clientName[64];
    
    GetClientName( client, clientName, sizeof clientName );
    
    if( GAME == GAME_CSGO ) {
        if( random <= 1 && RXGSTORE_IsItemRegistered(5) ) {
            //nuke
            itemName = "Nuke";
            itemID = 5;
        } else if( random <= 250 && RXGSTORE_IsItemRegistered(13) ) {
            //negev
            itemName = "AWP";
            itemID = 13;
        } else if( random <= 500 && RXGSTORE_IsItemRegistered(3) ) {
            //negev
            itemName = "Negev";
            itemID = 3;
        } else if( random <= 1000 && RXGSTORE_IsItemRegistered(2) ) {
            //radio
            itemName = "Disposable Radio";
            itemID = 2;
        } else if( random <= 2500 && RXGSTORE_IsItemRegistered(4) ) {
            //cookie
            itemName = "Cookie";
            itemID = 4;
        } else if( random <= 3500 && RXGSTORE_IsItemRegistered(7) ) {
            //chicken
            itemName = "Chicken";
            itemID = 7;
        } else {
            
            cashDropped = GetRandomInt(50, 150);
            
            if(!RXGSTORE_AddCash( client,  cashDropped)){
                LogError("Tried to give %s %i cash. Failed.", clientName, cashDropped);
                return false;
            }
            
            PrintToChat( client, "You found \x04$%i \x01in a gift!", cashDropped );
        }
    }
    
    if( GAME == GAME_TF2 ) {
        if( random <= 50 && RXGSTORE_IsItemRegistered(12) ) {
            //time warp
            itemName = "Time Warp";
            itemID = 12;
        } else if( random <= 175 && RXGSTORE_IsItemRegistered(8) ) {
            //boss monoculus
            itemName = "Boss Monoculus";
            itemID = 8;
        } else if( random <= 425 && RXGSTORE_IsItemRegistered(10) ) {
            //roman candle
            itemName = "Roman Candle";
            itemID = 10;
        } else if( random <= 600 && RXGSTORE_IsItemRegistered(11) ) {
            //fire cracker
            itemName = "Fire Cracker";
            itemID = 11;
        } else if( random <= 1175 && RXGSTORE_IsItemRegistered(9) ) {
            //spectral monoculus
            itemName = "Spectral Monoculus";
            itemID = 9;
        } else if( random <= 1675 && RXGSTORE_IsItemRegistered(4) ) {
            //cookie
            itemName = "Cookie";
            itemID = 4;
        }else if( random <= 2500 && RXGSTORE_IsItemRegistered(14) ) {
            //skeleton
            itemName = "Skeleton";
            itemID = 14;
        }else if( random <= 3875 && RXGSTORE_IsItemRegistered(6) ) {
            //pumpkin
            itemName = "Pumpkin Bomb";
            itemID = 6;
        }else {
            cashDropped = GetRandomInt(100, 200);
            if( !RXGSTORE_AddCash( client,  cashDropped) ) {
                LogError("Tried to give %s %i cash. Failed.", clientName, cashDropped);
                return false;
            }
            
            PrintToChat( client, "%sYou found \x04$%i \x01in a gift", initial_space, cashDropped );
        }
    }
    
    if( itemID != -1 ) {
    
        if( !RXGSTORE_GiveItem( client, itemID ) ) {
            LogError("Tried to give %s item '%s' with ID %i. Failed.", clientName, itemName, itemID);
            return false;
        }
        
        bigItem = ( random <= 50 );
        
        if( bigItem ) {
            PrintCenterTextAll( "%s%s has just found a %s in a gift!!!", initial_space, clientName, itemName );
        } else {
            PrintCenterText( client, "You found a %s store item!", itemName );
        }
        
        PrintToChat( client, "%sYou found a %s%s \x01in a gift. Type \x04!useitem \x01to use it.", initial_space, item_color, itemName );
    }
    
    itemDropDB(client,itemID,cashDropped);
    return true;
}

//-----------------------------------------------------------------------------
void itemDropDB( int client, int itemID, int cashDropped ) {

	if( DBRELAY_IsConnected() ) {
	
	    int account = GetSteamAccountID(client);
	    if( account == 0 ){ return; }
	    
	    int val = 1;
	    char query[1024];
	    
	    if( itemID == -1 ){
	    	val = cashDropped;
	    }
	    
	    FormatEx( query, sizeof query, "INSERT INTO sourcebans_xmas.drops( account, item, count ) VALUES ( %i, %i, %i ) ON DUPLICATE KEY UPDATE count = count + %i", account, itemID, val , val );
	    
	    DBRELAY_TQuery( IgnoredSQLResult, query );
	 }
}

//-----------------------------------------------------------------------------
void giftDB( int client ) {

	if( DBRELAY_IsConnected() ) {
		int account = GetSteamAccountID(client);
		if( account == 0 ){ return; }
		
		char query[1024];
		FormatEx( query, sizeof query, "INSERT INTO sourcebans_xmas.players( account, gift_count ) VALUES ( %i, %i ) ON DUPLICATE KEY UPDATE gift_count = gift_count + 1", account, 1 );
		DBRELAY_TQuery( IgnoredSQLResult, query );
	}
}

//-----------------------------------------------------------------------------
public void IgnoredSQLResult( Handle owner, Handle hndl, const char [] error, any data ) {
    if( !hndl ) {
        LogError( "SQL Error --- %s", error );
        return;
    }
}