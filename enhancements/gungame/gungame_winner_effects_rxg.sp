
/*----------------------------------------------------------------------+
| INÑLUDES                                                              |
+----------------------------------------------------------------------*/
#include <sourcemod>
#include <sdktools>
#include <gungame_const>
#include <gungame_config>
#include "gungame/stock.sp"

#pragma semicolon 1

/*----------------------------------------------------------------------+
| PLUGIN INFO                                                           |
+----------------------------------------------------------------------*/
public Plugin:myinfo = {
    name        = "GunGame:SM Winner Effects",
    author      = GUNGAME_AUTHOR,
    description = "Show winner effects on gungame win",
    version     = GUNGAME_VERSION,
    url         = GUNGAME_URL
};

/*----------------------------------------------------------------------+
| INIT VARS                                                             |
+----------------------------------------------------------------------*/
#define SPRITE_CSGO     "sprites/ledglow.vmt"
#define SPRITE_CSS      "sprites/orangeglow1.vmt"

new State:g_ConfigState     = CONFIG_STATE_NONE;
new g_Cfg_WinnerEffect      = 0;
new g_GlowSprite            = -1;
new GameName:g_GameName     = GameName:None;
new g_winner                = 0;

new UserMsg:g_FadeUserMsgId;


new mat_halosprite;
new mat_fatlaser;

/*----------------------------------------------------------------------+
| LOAD CONFIG                                                           |
+----------------------------------------------------------------------*/
public GG_ConfigNewSection(const String:NewSection[]) {
    if (strcmp(NewSection, "Config", false) == 0) {
        g_ConfigState = CONFIG_STATE_CONFIG;
    }
}

public GG_ConfigKeyValue(const String:key[], const String:value[]) {
    if (g_ConfigState == CONFIG_STATE_CONFIG) {
        if  (strcmp("WinnerEffect", key, false) == 0) {
            g_Cfg_WinnerEffect = StringToInt(value);
        }
    }
}

public GG_ConfigParseEnd() {
    g_ConfigState = CONFIG_STATE_NONE;
}

/*----------------------------------------------------------------------+
| PUBLIC EVENTS                                                         |
+----------------------------------------------------------------------*/
public OnMapStart() {
	g_winner = 0;

	if (g_GameName == GameName:Csgo) {
		g_GlowSprite = PrecacheModel(SPRITE_CSGO);
	} else {
		g_GlowSprite = PrecacheModel(SPRITE_CSS);
	}
	
	mat_fatlaser = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	mat_halosprite = PrecacheModel("materials/sprites/glow01.vmt");

}

public OnPluginStart() {
    g_FadeUserMsgId = GetUserMessageId("Fade");
    g_GameName = DetectGame();
    if (g_GameName == GameName:None) {
        SetFailState("ERROR: Unsupported game. Please contact the author.");
    }

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    if (!g_Cfg_WinnerEffect) {
        return;
    }

    if (!g_winner) {
        return;
    }

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client) {
        return;
    }

    WinnerEffectsStartOne(g_winner, client);
}

/*----------------------------------------------------------------------+
| GUNGAME EVENTS                                                        |
+----------------------------------------------------------------------*/
public GG_OnStartup(bool:Command) {
    g_winner = 0;
    if (!g_Cfg_WinnerEffect) {
        return;
    }

}

public GG_OnWinner(client, const String:Weapon[], victim) {
    if (!g_Cfg_WinnerEffect) {
        return;
    }

    g_winner = client;
    WinnerEffectsStart(client);
    ScreenFlash();
}

/*----------------------------------------------------------------------+
| WINNER EFFECTS                                                        |
+----------------------------------------------------------------------*/
WinnerEffectsStart(winner) {
    if (g_Cfg_WinnerEffect == 1) {
        WinnerEffect(winner);
    }
}

WinnerEffectsStartOne(winner, client) {
    if (g_Cfg_WinnerEffect == 1) {
        WinnerEffectOne(winner, client);
    }
}

WinnerEffect(winner) {
	for (new i=1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			WinnerEffectOne(winner, i);
		}
	}
	CreateTimer( 4.0, UnfreezePlayers, _, TIMER_FLAG_NO_MAPCHANGE  );
	CreateTimer( 2.0, IgnitePlayers, _, TIMER_FLAG_NO_MAPCHANGE  );
	
}

public Action:UnfreezePlayers( Handle:tmr ) {
	for (new i=1; i <= MaxClients; i++) {
		if ( !IsClientInGame(i) || !IsPlayerAlive(i)) continue;
 
		SetEntityFlags( i, GetEntityFlags(i) & ~FL_FROZEN );
	
	}
	return Plugin_Handled;
}

public Action:IgnitePlayers( Handle:tmr ) {
	for (new i=1; i <= MaxClients; i++) {
		if ( !IsClientInGame(i) || !IsPlayerAlive(i)) continue;
		if( i == g_winner ) continue;
		IgniteEntity(i, 60.0);
	
	}
	CreateTimer( 0.1, WinnerPulse, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
	return Plugin_Handled;
}

public Action:WinnerPulse( Handle:tmr ) {
	if( !g_winner ) return Plugin_Stop;
	
	new Float:pos[3];
	GetClientAbsOrigin( g_winner, pos );
	pos[2] += 32.0;
	new color[4] = {0 ,72,11,80};
	color[0] = RoundToNearest(Sine(GetGameTime())*40.0) + 60;
	TE_SetupBeamRingPoint( pos, 10.0, 1000.0, mat_fatlaser, mat_halosprite, 0, 15, 5.0, 2.5, 0.0, color, 10, 0);
	TE_SendToAll();
	return Plugin_Continue;
}

WinnerEffectOne(winner, client) {
    SetPlayerWinnerEffectAll(client);
    if (winner==client) {
        SetPlayerWinnerEffectWinner(client);
    } else {
		
	}
}

SetPlayerWinnerEffectAll(client) {
	// fly
	//SetEntityGravity(client, 0.001);
	SetEntityMoveType( client, MOVETYPE_FLY );
	
///	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);

	new Float:pos[3], Float:vel[3];
	GetClientAbsOrigin(client, pos);
	pos[2] += 2.0;
	vel[0] = GetRandomFloat(-10.0, 10.0);
	vel[1] = GetRandomFloat(-10.0, 10.0);
	vel[2] = GetRandomFloat(30.0, 80.0);

	TeleportEntity(client, pos, NULL_VECTOR, vel);
	
}

SetPlayerWinnerEffectWinner(client) {
    //CreateLight(client);
    SetPlayerWinnerEffectWinnerRepeate(client);
}

SetPlayerWinnerEffectWinnerRepeate(client) {
    CreateTimer(0.1, Timer_SetPlayerWinnerEffectWinner, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SetPlayerWinnerEffectWinner(Handle:timer, any:data) {
    if (!IsClientInGame(data)||!IsPlayerAlive(data)) {
        return Plugin_Stop;
    }
    SetPlayerWinnerEffectWinnerReal(data);
    return Plugin_Continue;
}

SetPlayerWinnerEffectWinnerReal(client) {
    // shine    
    new Float:vec[3];
    GetClientAbsOrigin(client, vec);
    vec[2] += 40;

    TE_SetupGlowSprite(vec, g_GlowSprite, GetRandomFloat(0.3,0.6), GetRandomFloat(3.5,4.5), GetRandomInt(60,80));
    TE_SendToAll();
}

// TODO: test it
stock CreateLight(client) {
    new Float:clientposition[3];
    GetClientAbsOrigin(client, clientposition);
    clientposition[2] += 40.0;

    new GLOW_ENTITY = CreateEntityByName("env_glow");

    SetEntProp(GLOW_ENTITY, Prop_Data, "m_nBrightness", 70, 4);

    //new String:model[100];
    //FormatEx(model, sizeof(model), "materials/%s", g_GameName == GameName:Csgo?SPRITE_CSGO:SPRITE_CSS);
    //DispatchKeyValue(GLOW_ENTITY, "model", model);
    DispatchKeyValue(GLOW_ENTITY, "model", g_GameName == GameName:Csgo?SPRITE_CSGO:SPRITE_CSS);

    DispatchKeyValue(GLOW_ENTITY, "rendermode", "3");
    DispatchKeyValue(GLOW_ENTITY, "renderfx", "14");
    DispatchKeyValue(GLOW_ENTITY, "scale", "4.0");
    DispatchKeyValue(GLOW_ENTITY, "renderamt", "255");
    DispatchKeyValue(GLOW_ENTITY, "rendercolor", "255 255 255 255");
    DispatchSpawn(GLOW_ENTITY);
    AcceptEntityInput(GLOW_ENTITY, "ShowSprite");
    TeleportEntity(GLOW_ENTITY, clientposition, NULL_VECTOR, NULL_VECTOR);

    new String:target[20];
    FormatEx(target, sizeof(target), "glowclient_%d", client);
    DispatchKeyValue(client, "targetname", target);
    SetVariantString(target);
    AcceptEntityInput(GLOW_ENTITY, "SetParent");
    AcceptEntityInput(GLOW_ENTITY, "TurnOn");
}    

#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT		( 1<<1 )
#define	HIDEHUD_ALL			( 1<<2 )
#define HIDEHUD_HEALTH			( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD		( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT		( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS		( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT			( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR		( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE		( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)
#define HIDEHUD_RADAR			( 1<<12 )	// Hide the radar


//-------------------------------------------------------------------------------------------------
ScreenFlash() {
	new clients[MAXPLAYERS+1];
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) ) {
			clients[count] = i;
			count++;	
			if( IsPlayerAlive(i) ){ 
				SetEntProp( i, Prop_Send, "m_iHideHUD", ~(HIDEHUD_CHAT|HIDEHUD_ALL) );
			}
		}
	}
	
	new duration2 = 1500;
	new holdtime = 50;

	new flags = 0x10|1;
	//new color[4] = { 255,60,10, 192};
	new color[4] = { 255,255,255, 255};
	new Handle:message = StartMessageEx( g_FadeUserMsgId, clients, count );
	PbSetInt(message, "duration", duration2);
	PbSetInt(message, "hold_time", holdtime);
	PbSetInt(message, "flags", flags);
	PbSetColor(message, "clr", color);
	EndMessage();
}