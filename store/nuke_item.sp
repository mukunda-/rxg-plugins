#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgstore>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "nuke item",
	author = "mukunda",
	description = "server crash",
	version = "1.0.2",
	url = "www.mukunda.com"
};

#define ITEM_NAME "nuke"
#define ITEM_FULLNAME "nuke"
#define ITEMID 5

new g_active;
new Float:g_time;


new g_bloodstain;
new g_physbeam;
new g_startsound1;
new g_c4div;
new g_fade;
#define SOUND1 "ambient/energy/force_field_loop1.wav"

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}
 
//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	if( g_active ) {
		PrintToChat( client, "A nuke has already gone off." );
		return false;
	}
	new players=0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) ) players++;
	}
	if( players < 16 ) {
		PrintToChat( client, "You can't nuke when there's less than 16 players alive." );
		return false;
	}
	LogAction( client, -1, "%s", "USED A NUKE" );
	NukeServer();
	return true;
}

Invulnerate() {
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		SDKHook( i, SDKHook_OnTakeDamage, OnTakeDamage );
		
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	damage = 0.0;
	return Plugin_Changed;
	
}

#define shit "decals/bloodstain_002"
//-------------------------------------------------------------------------------------------------
NukeServer() {
	g_active = true;
	g_time= GetGameTime();
	g_bloodstain = PrecacheDecal( shit ); 
	g_physbeam = PrecacheModel( "materials/sprites/physbeam.vmt" );
	PrecacheModel( "models/gibs/hgibs.mdl" );
	PrecacheSound(SOUND1);
	PrintToChatAll( "\x01 \x02*** Nuclear Launch Detected ***" );
	
	Invulnerate();
	
	CreateTimer( 0.1, OnNuke, _, TIMER_REPEAT );
	
}

//-------------------------------------------------------------------------------------------------
public Action:StartNuke( Handle:timer, any:data ) {
	 
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:OnNuke( Handle:timer, any:data ) {
	new Float:time = GetGameTime() - g_time;
	
	new clients[MAXPLAYERS+1];
	new pcount;
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if( !IsClientInGame(i) ) continue;
		clients[pcount++] = i;
		
		
	}
	
	
	
	if( pcount > 0 ) {
		SpawnChicken( clients[GetRandomInt( 0, pcount-1 )] );
		//SpawnChicken( clients[GetRandomInt( 0, pcount-1 )] );
	//
		if( time < 3.0 ) {
			// precache time
			return Plugin_Continue;
		}
		
		
		for( new i = 0; i < pcount; i++ ) {
			new client = clients[i];
			if( !IsPlayerAlive(client) ) continue;
			BloodSquirt( client, 1  );
			
			if( !g_startsound1 ) {
				EmitSoundToAll( SOUND1, client, _, SNDLEVEL_SCREAMING );
				
				
			}
			IgniteEntity( client,300.0 );
		}
		
		if( time > 10.0 ) {
			g_c4div++;
			if( g_c4div >= 3 ) {
				new client = clients[GetRandomInt( 0, pcount-1 )];
				Detonate(client);
				g_c4div = 0;
			}
		}
		
		if( time > 15.0 ) {
			if( !g_fade ) {
				g_fade=1;
				new color[4] = { 200,0,0, 255};
				new Handle:message = StartMessageAll( "Fade" );
				new flags = 0x10|0x2|0x4|0x8;
				PbSetInt(message, "duration", 512);
				PbSetInt(message, "hold_time", 512);
				PbSetInt(message, "flags", flags );
				PbSetColor(message, "clr", color);
				EndMessage();
			}
			for( new i = 0; i < 10; i++ ) {
				SpawnSkull( clients[GetRandomInt( 0, pcount-1 )] );
			}
		}
		g_startsound1 = true;
	}
	return Plugin_Continue;
}

SpawnChicken(client) {
	new Float:vec[3];
	GetClientAbsOrigin(client,vec);
	new ent = CreateEntityByName( "chicken" );
	DispatchSpawn(ent);
	TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR);
}

SpawnSkull(client) {
	new Float:vec[3];
	new Float:vel[3];
	new Float:ang[3];
	new Float:v = 100.0;
	vel[0] = GetRandomFloat( -v, v );
	vel[1] = GetRandomFloat( -v, v );
	vel[2] = 200.0+GetRandomFloat( 0.0, v );

	ang[0] = GetRandomFloat( 0.0, 360.0 );
	ang[1] = GetRandomFloat( 0.0, 360.0 );
	ang[2] = GetRandomFloat( 0.0, 360.0 );
	GetClientEyePosition(client,vec);
 
	new ent = CreateEntityByName( "prop_physics_override" );
	
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	DispatchKeyValue(ent, "model", "models/gibs/hgibs.mdl");
	DispatchSpawn(ent);
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2); // set non-collidable
 
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);   
	
	TeleportEntity( ent, vec, ang, vel);
}
//----------------------------------------------------------------------------------------------------------------------
Detonate( player ) {
	  
	new ent = CreateEntityByName( "planted_c4" );
	SetEntProp( ent, Prop_Send, "m_bBombTicking", 1 );
	decl Float:pos[3];
	GetClientEyePosition(player,pos);
	pos[2] -= 20.0;
	
	TeleportEntity( ent, pos, NULL_VECTOR, NULL_VECTOR );
	DispatchSpawn(ent);
	SetEntPropFloat( ent, Prop_Send, "m_flC4Blow", GetGameTime() + 1.0 );
	SetEntPropFloat( ent, Prop_Send, "m_flTimerLength", 0.0 );
	
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
BloodSquirt( client, count ) {

	new Float:origin[3];
	GetClientEyePosition(client,origin);
	for( new i = 0; i< count; i++ ) {
		decl Float:dir[3];
		dir[0] = GetRandomFloat(0.0,360.0);
		dir[1] = GetRandomFloat(0.0,360.0);
		dir[2] = 0.0;
		
		TR_TraceRayFilter( origin, dir, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_Infinite, TraceFilter_All );
		if( TR_DidHit( INVALID_HANDLE ) ) {
			
			decl Float:end[3];
			TR_GetEndPosition( end, INVALID_HANDLE );
			new ent = CreateEntityByName("infodecal");
			DispatchKeyValue( ent, "texture", shit );
			DispatchKeyValue( ent, "LowPriority", "0" );
			DispatchSpawn(ent);
			TeleportEntity(ent,end,NULL_VECTOR,NULL_VECTOR);
			AcceptEntityInput(ent,"Activate");
			AcceptEntityInput(ent,"Kill");
			 
			new color[4] = {128,0,0,255};
			color[1] = GetRandomInt(0,255);
			TE_SetupBeamPoints( origin, end, g_physbeam, 0, 0, 30, 0.5, 44.0, 44.0, 0, 40.0, color, 25 ); 
			TE_SendToAll();
		}
	}
}
