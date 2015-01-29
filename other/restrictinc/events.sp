#define PRINTDELAY 2.0
new bool:g_bSpamProtectPrint[MAXPLAYERS+1];

HookEvents()
{
	AddCommandListener(OnJoinClass, "joinclass");
	HookEvent("round_start", EventRoundStart);
	HookEvent("round_end", EventRoundEnd);
}
public Action:OnJoinClass(client, const String:command[], args) 
{
	#if defined PERPLAYER
	CheckPerPlayer();
	#endif
	#if defined WARMUP
	if(!Restrict_IsWarmupRound() || !IsClientInGame(client) || GetClientTeam(client) <= CS_TEAM_SPECTATOR || !GetConVarBool(WarmupRespawn))
		return Plugin_Continue;
	
	if(RespawnTimer[client] == INVALID_HANDLE)
		RespawnTimer[client] = CreateTimer(GetConVarFloat(WarmupRespawnTime), RespawnFunc, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	#endif
	return Plugin_Continue;
}
public OnClientPutInServer(client)
{
	#if defined PERPLAYER
	CheckPerPlayer();
	#endif
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}
public OnClientDisconnect(client)
{
	#if defined PERPLAYER
	CheckPerPlayer();
	#endif
	#if defined WARMUP
	KillRespawnTimer(client);
	#endif
}
public Action:OnWeaponCanUse(client, weapon)
{
	if(!IsClientInGame(client))
		return Plugin_Continue;
	
	new team = GetClientTeam(client);
	
	if(team <= CS_TEAM_SPECTATOR)
		return Plugin_Continue;

	new WeaponID:id = GetWeaponIDFromEnt(weapon);
	
	if(id == WEAPON_NONE)
		return Plugin_Continue;
	
	#if defined WARMUP
	if(Restrict_IsWarmupRound() && Restrict_CanPickupWeapon(client, team, id))
	{
		return Plugin_Continue;
	}
	else if(Restrict_IsWarmupRound())
	{
		AcceptEntityInput(weapon, "Kill");
		return Plugin_Handled;
	}
	#endif
	
	if(Restrict_CanPickupWeapon(client, team, id) || !IsGoingToPickup(client, id))
		return Plugin_Continue;
	
	if(id == WEAPON_C4 || id == WEAPON_KNIFE)
		AcceptEntityInput(weapon, "Kill");
	
	if(!g_bSpamProtectPrint[client])
	{
		if(Restrict_IsSpecialRound() && !Restrict_AllowedForSpecialRound(id))
		{
			PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "SpecialNotAllowed", client);
		}
		else if(team == CS_TEAM_CT)
		{
			PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "IsRestrictedPickupCT", client, Restrict_GetRestrictValue(team, id));
		}
		else
		{
			PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "IsRestrictedPickupT", client, Restrict_GetRestrictValue(team, id));
		}
		g_bSpamProtectPrint[client] = true;
		CreateTimer(PRINTDELAY, ResetPrintDelay, client);
	}
	return Plugin_Handled;
}
public Action:ResetPrintDelay(Handle:timer, any:client)
{
	g_bSpamProtectPrint[client] = false;
}
public OnMapStart()
{
	g_nextRoundSpecial = RoundType_None;
	g_currentRoundSpecial = RoundType_None;
	#if defined PERPLAYER
	g_bPerPlayerReady = false;
	#endif
	
	ClearOverride();
	CheckWeaponArrays();
	for(new i = 1; i <= MaxClients; i++)
	{
		g_bSpamProtectPrint[i] = false;
	}
	SetConVarString(g_version, PLUGIN_VERSION, true, false);
	if(g_bLateLoaded)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
			
			OnClientPutInServer(i);
		}
	}
}
public OnConfigsExecuted()
{
	#if defined CONFIGLOADER
	CheckConfig();
	#endif
	
	CreateTimer(0.1, DelayExec);
}
public Action:DelayExec(Handle:timer)
{
	#if defined WARMUP
	if(GetConVarBool(WarmUp) && !g_bLateLoaded)
	{
		if(StartWarmup())
			g_currentRoundSpecial = RoundType_Warmup;
	}
	#endif
	GetWeaponRestrictSound();
	#if defined PERPLAYER
	PerPlayerInit();
	CheckPerPlayer();
	#endif
	g_bLateLoaded = false;
}
public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(Restrict_IsSpecialRound())
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
			RemoveForSpecialRound(i);
		}
	}
	else
	{
		Restrict_CheckPlayerWeapons();
	}
	return Plugin_Continue;
}
public Action:EventRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_currentRoundSpecial == RoundType_Warmup)
		return Plugin_Continue;
	
	g_currentRoundSpecial = g_nextRoundSpecial;
	g_nextRoundSpecial = RoundType_None;
	
	return Plugin_Continue;
}
public Action:CS_OnBuyCommand(client, const String:weapon[])
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_bInBuyZone") == 0)
		return Plugin_Continue;
	
	#if defined WARMUP
	if(Restrict_IsWarmupRound())
	{
		if(!g_bSpamProtectPrint[client])
		{
			PrintToChat(client, "\x01\x0B\x04[SM] %T", "CannotBuyWarmup", client);
			g_bSpamProtectPrint[client] = true;
			CreateTimer(PRINTDELAY, ResetPrintDelay, client);
		}
		
		return Plugin_Handled;
	}
	#endif
	
	new team = GetClientTeam(client);
	
	if(team <= CS_TEAM_SPECTATOR)
		return Plugin_Continue;
	
	new WeaponID:id = Restrict_GetWeaponIDExtended(weapon);
	
	if(id == WEAPON_NONE || id == WEAPON_C4 || id == WEAPON_SHIELD)
		return Plugin_Continue;
	
	new buyteam = BuyTeams[_:id];
	
	if(team != buyteam && buyteam != 0)
		return Plugin_Continue;
	
	new CanBuyResult:result = Restrict_CanBuyWeapon(client, team, id);
	if(result == CanBuy_Block || result == CanBuy_BlockDontDisplay)
	{
		if(team == CS_TEAM_CT && result != CanBuy_BlockDontDisplay)
		{
			if(Restrict_IsSpecialRound() && !Restrict_AllowedForSpecialRound(id))
				PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "SpecialNotAllowed", client);
			else
				PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "IsRestrictedBuyCT", client, Restrict_GetRestrictValue(team, id));
		}
		else if(team == CS_TEAM_T && result != CanBuy_BlockDontDisplay)
		{	if(Restrict_IsSpecialRound() && !Restrict_AllowedForSpecialRound(id))
				PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "SpecialNotAllowed", client);
			else
				PrintToChat(client, "\x01\x0B\x04[SM] %T %T", weaponNames[_:id], client, "IsRestrictedBuyT", client, Restrict_GetRestrictValue(team, id));
		}
		Restrict_PlayRestrictSound(client, id);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}