/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Communication Plugin
 * Provides fucntionality for controlling communication on the server
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 1
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <basecomm>

#undef REQUIRE_PLUGIN
#include <adminmenu>

//#define RXG

#if defined RXG
#include <donations>
#endif


#pragma semicolon 1

public Plugin:myinfo =
{
	name = "Basic Comm Control (rxg edition)",
	author = "AlliedModders LLC",
	description = "Provides methods of controlling communication.",
	version = "2.0.2",
	url = "http://www.sourcemod.net/"
};

new bool:g_Muted[MAXPLAYERS+1];			// Is the player muted?
new bool:g_Gagged[MAXPLAYERS+1];		// Is the player gagged?
new bool:g_Intercom[MAXPLAYERS+1];		// Is the player being a badass?
new bool:g_PlayerAllTalk[MAXPLAYERS+1];		// Is the player using alltalk?
new bool:g_PlayerListenAll[MAXPLAYERS+1];	// Is the player using admin listen?

new Handle:g_Cvar_Deadtalk = INVALID_HANDLE;	// Holds the handle for sm_deadtalk
new Handle:g_Cvar_Alltalk = INVALID_HANDLE;	// Holds the handle for sv_alltalk
new bool:g_Hooked = false;			// Tracks if we've hooked events for deadtalk

new Handle:sm_allow_playeralltalk;
new c_allow_playeralltalk;

new bool:c_alltalk;
new c_deadtalk;

new Handle:hTopMenu = INVALID_HANDLE;

new Handle:cookie_bansaw = INVALID_HANDLE;
new c_bansaw[MAXPLAYERS+1];

new g_GagTarget[MAXPLAYERS+1];

new bool:game_csgo;

#include "source/gag.sp"
#include "source/natives.sp"
#include "source/forwards.sp"

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("BaseComm_IsClientGagged", Native_IsClientGagged);
	CreateNative("BaseComm_IsClientMuted",  Native_IsClientMuted);
	CreateNative("BaseComm_SetClientGag",   Native_SetClientGag);
	CreateNative("BaseComm_SetClientMute",  Native_SetClientMute);
	RegPluginLibrary("basecomm");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basecomm.phrases");
	
	decl String:gamedir[64];
	GetGameFolderName( gamedir, sizeof(gamedir) );
	game_csgo = StrEqual(gamedir, "csgo",false);

	cookie_bansaw = RegClientCookie( "cookie_bansaw", "cookie bansaw", CookieAccess_Private );
	for( new i = 0; i < MAXPLAYERS; i++ ) c_bansaw[i] = 0;
	
	g_Cvar_Deadtalk = CreateConVar("sm_deadtalk", "0", "Controls how dead communicate. 0 - Off. 1 - Dead players ignore teams. 2 - Dead players talk to living teammates.", 0, true, 0.0, true, 2.0);
	g_Cvar_Alltalk = FindConVar("sv_alltalk");
	sm_allow_playeralltalk = CreateConVar( "sm_allow_playeralltalk", "0", "Allow players to control their alltalk when alive.", FCVAR_PLUGIN );
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	RegAdminCmd("sm_mute", Command_Mute, ADMFLAG_CHAT, "sm_mute <player> - Removes a player's ability to use voice.");
	RegAdminCmd("sm_gag", Command_Gag, ADMFLAG_CHAT, "sm_gag <player> - Removes a player's ability to use chat.");
	RegAdminCmd("sm_silence", Command_Silence, ADMFLAG_CHAT, "sm_silence <player> - Removes a player's ability to use voice or chat.");
	
	RegAdminCmd( "sm_bansaw", Command_Bansaw, ADMFLAG_BAN, "sm_bansaw <player> - Secretly silences player for X hours" );
	
	RegAdminCmd("sm_unmute", Command_Unmute, ADMFLAG_CHAT, "sm_unmute <player> - Restores a player's ability to use voice.");
	RegAdminCmd("sm_ungag", Command_Ungag, ADMFLAG_CHAT, "sm_ungag <player> - Restores a player's ability to use chat.");
	RegAdminCmd("sm_unsilence", Command_Unsilence, ADMFLAG_CHAT, "sm_unsilence <player> - Restores a player's ability to use voice and chat.");	
	
	RegAdminCmd( "sm_intercom", Command_Intercom, ADMFLAG_CHAT, "sm_intercom - Toggle admin intercom." );
	RegAdminCmd( "sm_eavesdrop", Command_eavesdrop, ADMFLAG_CHAT, "sm_eavesdrop <player> - Toggle hearing of player at all times." );
	RegAdminCmd( "sm_listenall", Command_listenall, ADMFLAG_CHAT, "sm_listenall - Toggle hearing of all players at all times." );

	RegConsoleCmd( "sm_togglealltalk", Command_togglealltalk );
	RegConsoleCmd( "sm_stfu", Command_stfu );
	RegConsoleCmd( "sm_unstfu", Command_unstfu );

	
	#if defined RXG
	RegConsoleCmd( "buyammo1", Command_togglealltalk );
	#endif
	
	HookConVarChange( g_Cvar_Deadtalk, ConVarChange_Deadtalk );
	HookConVarChange( g_Cvar_Alltalk, ConVarChange_Alltalk );
	HookConVarChange( sm_allow_playeralltalk, ConVarChange_PlayerAllTalk );
	
	c_alltalk = GetConVarBool( g_Cvar_Alltalk );
	c_allow_playeralltalk = GetConVarInt( sm_allow_playeralltalk );
	
	/* Account for late loading */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Build the "Player Commands" category */
	new TopMenuObject:player_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);
	
	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hTopMenu, 
			"sm_gag",
			TopMenuObject_Item,
			AdminMenu_Gag,
			player_commands,
			"sm_gag",
			ADMFLAG_CHAT);
	}
}

public ConVarChange_Deadtalk(Handle:convar, const String:oldValue[], const String:newValue[])
{
	c_deadtalk = GetConVarInt(g_Cvar_Deadtalk);
	if (GetConVarInt(g_Cvar_Deadtalk))
	{
		HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		g_Hooked = true;
	}
	else if (g_Hooked)
	{
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_death", Event_PlayerDeath);		
		g_Hooked = false;
	}
}

 

public OnClientPutInServer(client) {
	g_Gagged[client] = false;
	g_Muted[client] = false;
	g_PlayerListenAll[client] = false;
	g_PlayerAllTalk[client] = false;
	g_Intercom[client] = false;
	UpdateClientVoice( client );

	EnforceBansaw( client );
	
}

EnforceBansaw( client ) {
	
	if( !AreClientCookiesCached(client) ) return;
	if( !IsClientInGame(client) ) return;
	if( GetTime() < c_bansaw[client] ) {

		// apply bansaw
		BaseComm_SetClientGag( client, true );
	}
	
}

public OnClientCookiesCached( client ) {
	decl String:cookie[64];
	GetClientCookie( client, cookie_bansaw, cookie, sizeof cookie );
	if( cookie[0] == 0 ) {
		c_bansaw[client] = 0;
		return;
	}
	new time = StringToInt( cookie );
	c_bansaw[client] = time;
	EnforceBansaw( client );
}

ShowChatThing( client, const String:format[], any:... ) {
	new Handle:pb = StartMessageOne( "SayText2", client );
	
	decl String:msg[256];
	VFormat( msg, sizeof(msg), format, 3 );
 
	PbSetInt( pb, "ent_idx", client );
	PbSetString( pb, "msg_name", msg );
	PbAddString( pb, "params", "" );
	PbAddString( pb, "params", "" );
	PbAddString( pb, "params", "" );
	PbAddString( pb, "params", "" );	
	PbSetBool(pb, "chat", true);
	EndMessage();
}

public Action:Command_Say(client, const String:command[], args)
{
	if (client)
	{
		if (g_Gagged[client])
		{
			if( !game_csgo ) return Plugin_Handled;
			if( GetTime() < c_bansaw[client] ) {

				if( !IsClientInGame(client) ) return Plugin_Handled;
				// emulate message
				decl String:arg[256];
				GetCmdArgString( arg, sizeof(arg) );
				StripQuotes( arg );
				if( strlen(arg) == 0 ) return Plugin_Handled;
				new bool:sayteam = StrEqual( "say_team", command, false );
				
				new team = GetClientTeam(client);
				if( team < 1 ) return Plugin_Handled;
				
				
				if( team == 1 ) {
					if( sayteam ) {
						ShowChatThing( client, "(Spectator) %N :  %s", client, arg );
					} else {
						ShowChatThing( client, "*SPEC* %N :  %s", client, arg );
					}
				} else {
					new bool:alive = IsPlayerAlive(client);
					ShowChatThing( client, "\x01\x0B\x03%s%s%s%N : %s", (!alive) ? "*DEAD*":"", sayteam ? ((team==3)?"(Counter-Terrorist)":"(Terrorist)"):"", (sayteam||!alive) ? " ":"", client, arg );
				}

			}
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

UpdateClientVoice( client ) {
	new listenall = g_PlayerListenAll[client] ? VOICE_LISTENALL : 0;

	if( g_Muted[client] ) {
		SetClientListeningFlags( client, VOICE_MUTED|listenall);
		return;
	}
	
	if( g_Intercom[client] || (g_PlayerAllTalk[client] && IsPlayerAlive(client)) ) {
		SetClientListeningFlags( client, VOICE_SPEAKALL|listenall );
		return;
	}
	
	if( c_alltalk ) {
		SetClientListeningFlags( client, VOICE_NORMAL|listenall );
		return;
	}
	
	if( !IsPlayerAlive(client) ) {
		if (c_deadtalk == 1)
		{
			SetClientListeningFlags( client, VOICE_LISTENALL );
		}
		else if (c_deadtalk == 2)
		{
			SetClientListeningFlags( client, VOICE_TEAM|listenall );
		}
		
	} else {
		SetClientListeningFlags( client, VOICE_NORMAL|listenall );
		
	}
}

public Action:Command_Intercom( client, args ) {

	g_Intercom[client] = !g_Intercom[client];
	ReplyToCommand( client, "[SM] Intercom %s.", g_Intercom[client] ? "Enabled":"Disabled" );
	UpdateClientVoice(client);
	return Plugin_Handled;
}

public ConVarChange_PlayerAllTalk(Handle:convar, const String:oldValue[], const String:newValue[]) {
	c_allow_playeralltalk = GetConVarInt( sm_allow_playeralltalk );
}

public ConVarChange_Alltalk(Handle:convar, const String:oldValue[], const String:newValue[])
{
	c_deadtalk = GetConVarInt(g_Cvar_Deadtalk);
	c_alltalk = GetConVarBool(g_Cvar_Alltalk);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		UpdateClientVoice(i);
		/*
		if (g_Muted[i])
		{
			SetClientListeningFlags(i, VOICE_MUTED);
		}
		else if (GetConVarBool(g_Cvar_Alltalk))
		{
			SetClientListeningFlags(i, VOICE_NORMAL);
		}
		else if (!IsPlayerAlive(i))
		{
			if (mode == 1)
			{
				SetClientListeningFlags(i, VOICE_LISTENALL);
			}
			else if (mode == 2)
			{
				SetClientListeningFlags(i, VOICE_TEAM);
			}
		}*/
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
	{
		return;	
	}
	
	UpdateClientVoice(client);
	/*
	if (g_Muted[client])
	{
		SetClientListeningFlags(client, VOICE_MUTED);
	}
	else
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}*/
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
	{
		return;	
	}
	UpdateClientVoice(client);
/*
	if (g_Muted[client])
	{
		SetClientListeningFlags(client, VOICE_MUTED);
		return;
	}
	
	if (GetConVarBool(g_Cvar_Alltalk))
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
		return;
	}
	
	new mode = GetConVarInt(g_Cvar_Deadtalk);
	if (mode == 1)
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
	}
	else if (mode == 2)
	{
		SetClientListeningFlags(client, VOICE_TEAM);
	}*/
}

//-------------------------------------------------------------------------------------------------
public Action:Command_togglealltalk( client, args ) {

#if defined RXG
	if( !Donations_GetClientLevel(client) ) {
		PrintToChat( client, "[SM] This feature is only available to donators." );
		return Plugin_Handled;
	}
#endif
	if( !c_allow_playeralltalk ) {
		PrintToChat( client, "[SM] This command is disabled." );
		return Plugin_Handled;
	}
	
	g_PlayerAllTalk[client] = !g_PlayerAllTalk[client];
	PrintToChat( client, "[SM] Now speaking to %s%s.", g_PlayerAllTalk[client] ? "everyone" : "team", IsPlayerAlive(client) ? "":" (when alive)" );
	UpdateClientVoice(client);
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
GetCommandTarget(client) {
	decl String:arg[64];
	GetCmdArg( 1, arg, sizeof(arg) );
	return FindTarget( client, arg, true, false );
}

//-------------------------------------------------------------------------------------------------
public Action:Command_stfu( client, args ) {
	if( args == 0 ) {
		ReplyToCommand( client, "[SM] Usage: sm_stfu <player> - mutes a player" );
		return Plugin_Handled;
	}
	new target = GetCommandTarget(client);
	if( target == -1 ) return Plugin_Handled;

	SetListenOverride( client, target, Listen_No );
	ReplyToCommand( client, "[SM] Muted %N.", target );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_unstfu( client, args ) {
	if( args == 0 ) {
		ReplyToCommand( client, "[SM] Usage: sm_unstfu <player> - unmutes a player" );
		return Plugin_Handled;
	}
	new target = GetCommandTarget(client);
	if( target == -1 ) return Plugin_Handled;

	SetListenOverride( client, target, Listen_Default );
	ReplyToCommand( client, "[SM] Unmuted %N.", target );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_eavesdrop( client, args ) {
	if( args == 0 ) {
		ReplyToCommand( client, "[SM] Usage: sm_eavesdrop <player> - toggle ability to hear this player at all times" );
		return Plugin_Handled;
	}
	new target = GetCommandTarget(client);
	if( target == -1 ) return Plugin_Handled;
	
	new ListenOverride:lor = GetListenOverride( client, target );
	if( lor == Listen_Default ) {
		SetListenOverride( client, target, Listen_Yes );
		ReplyToCommand( client, "[SM] Eavesdropping on %N.", target );
		LogAction( client, target, "\"%L\" used eavesdrop on \"%L\"", client, target );
	} else {
		SetListenOverride( client, target, Listen_Default );
		ReplyToCommand( client, "[SM] Stopped eavesdropping on %N.", target );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Command_listenall( client, args ) {
	g_PlayerListenAll[client] = !g_PlayerListenAll[client];
	if( g_PlayerListenAll[client] ) {
		ReplyToCommand( client, "[SM] ListenAll (TM) enabled." );
		LogAction( client, -1, "%L enabled ListenAll", client );
	} else {
		ReplyToCommand( client, "[SM] ListenAll (TM) disabled." );
		LogAction( client, -1, "%L disabled ListenAll", client );
	}
	UpdateClientVoice(client);
	return Plugin_Handled;
}
