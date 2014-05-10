#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// 1.0.1
//	safer handling of disconnects
//	new sprite image
//

public Plugin:myinfo = {
	name = "flashmark",
	author = "mukunda",
	description = "marks flashed teammates",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

#define FM_MATERIAL "materials/flashmark/flashmark2.vmt"
#define FM_MATERIAL_VTF "materials/flashmark/flashmark2.vtf"

new bool:files_precached = false;

#define FM_HEIGHT 75.0
#define FM_SCALE "22.0"

#define ENDTIME_GRACE_THRESHOLD 0.1

new fm_sprites[MAXPLAYERS+1];
new fm_userid[MAXPLAYERS+1];
new fm_round[MAXPLAYERS+1];
new Float:fm_endtime[MAXPLAYERS+1];

new round_counter = 0;

//----------------------------------------------------------------------------------------------------------------------
bool:IsValidClient( client ) {
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	HookEvent( "round_prestart", Event_RoundStart );
	HookEvent( "player_blind", Event_PlayerBlind);
}

//-------------------------------------------------------------------------------------------------
public PrecacheFiles() {
	if( !files_precached ) {
		PrecacheModel( FM_MATERIAL );
		files_precached = true;
	}
}

//-------------------------------------------------------------------------------------------------
public AddDownloads() {
	AddFileToDownloadsTable( FM_MATERIAL );
	AddFileToDownloadsTable( FM_MATERIAL_VTF );
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	files_precached = false;

	AddDownloads();
	PrecacheFiles();
}

//-------------------------------------------------------------------------------------------------
public Action:DeleteSpriteTimer( Handle:timer, any:userid ) {
	//ResetPack(data);
	//new userid = ReadPackCell(data);
	new client = GetClientOfUserId(userid);//ReadPackCell(data);
	
	if( client == 0 ) {
		// client DCd, the sprite was destroyed
		return Plugin_Handled;
	}

	if( fm_round[client] != round_counter ) {
		// the sprite was cleaned up
		fm_sprites[client] = 0;
		return Plugin_Handled;
	}
	
	

	if( fm_sprites[client] != 0 ) {
		
		// if time of the sprite has expired, delete it, otherwise create a new timer at the end time
		if( GetGameTime() >= (fm_endtime[client] - ENDTIME_GRACE_THRESHOLD) ) {
			AcceptEntityInput( fm_sprites[client], "kill" );
			fm_sprites[client] = 0;
		} else {
			CreateTimer( fm_endtime[client] - GetGameTime(), DeleteSpriteTimer, userid, TIMER_FLAG_NO_MAPCHANGE );
		}
	}
	
	return Plugin_Handled;
}
 
//-------------------------------------------------------------------------------------------------
public Action:OnSpriteSetTransmit( entity, client ) {
	new owner_client = GetEntPropEnt( entity, Prop_Send, "m_hOwnerEntity" );
	if( IsClientInGame(client) ) {
		new team = GetClientTeam(client);
		if( team == 1 ) {
			return Plugin_Continue; // spectator
		} else if( GetClientTeam(owner_client) == team || !IsPlayerAlive(client) ) {
			return Plugin_Continue; // same team or dead
		}
	}
	
	return Plugin_Handled;
}


//-------------------------------------------------------------------------------------------------
CreateSprite( client ) {
 
	new ent = CreateEntityByName( "env_sprite" );
	SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
 
	SDKHook( ent, SDKHook_SetTransmit, OnSpriteSetTransmit );

	SetEntityModel( ent, FM_MATERIAL );
	DispatchKeyValue( ent, "rendercolor", "128 128 128" );
	DispatchKeyValue( ent, "rendermode", "2" );
	DispatchKeyValue( ent, "renderamt", "255" ); 
	DispatchKeyValue( ent, "framerate", "20.0" ); 
	DispatchKeyValue( ent, "scale", FM_SCALE );

	// todo: turn off?
	
	SetEntProp( ent, Prop_Data, "m_bWorldSpaceScale", 1 );

	DispatchSpawn( ent );

	AcceptEntityInput( ent, "ShowSprite" );
	
	SetVariantString("!activator");
	AcceptEntityInput( ent, "SetParent", client );
	//SetVariantString("forward");
	//AcceptEntityInput( ent, "SetParentAttachment", client );
	
	new Float:pos[3];
	pos[0] = 10.0;
	pos[1] = 0.0;
	pos[2] = FM_HEIGHT;

	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );

	return ent;
}

//-------------------------------------------------------------------------------------------------
ShowFM( client, Float:duration ) {
	if( !IsValidClient(client) ) return;
	if( !IsPlayerAlive(client) ) return;

	if( fm_sprites[client] == 0 || GetClientOfUserId(fm_userid[client]) == 0 || fm_round[client] != round_counter ) {
		// sprite does not exist, create a new one

		new ent = CreateSprite( client );
		fm_sprites[client] = ent;
		fm_userid[client] = GetClientUserId( client );
		fm_round[client] = round_counter;
		fm_endtime[client] = GetGameTime() + duration;
 
		CreateTimer( duration, DeleteSpriteTimer, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
 

	} else {
		new Float:endtime = GetGameTime() + duration;
		if( endtime > fm_endtime[client] ) {
			fm_endtime[client] = GetGameTime() + duration;
		}
	}
}

//-------------------------------------------------------------------------------------------------
public Event_PlayerBlind(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	/* The client that was blinded */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	/* Check and see if the flash magnitude is high (255) */
	if (GetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha") == 255)
	{
		new Float:flash_duration = GetEntPropFloat(client, Prop_Send, "m_flFlashDuration" );

		if( flash_duration > 1.5 ) {
			ShowFM( client, flash_duration );
		}
		
	}
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	round_counter++;
}
