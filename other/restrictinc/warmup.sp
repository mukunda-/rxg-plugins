new WeaponID:g_iWarmupWeapon = WEAPON_NONE;
new warmupcount;
new ffvalue;

new Handle:RespawnTimer[MAXPLAYERS+1];

RegisterWarmup()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("hegrenade_detonate", OnHegrenadeDetonate);
}
KillRespawnTimer(client)
{
	if(RespawnTimer[client] != INVALID_HANDLE)
	{
		KillTimer(RespawnTimer[client]);
		RespawnTimer[client] = INVALID_HANDLE;
	}
}
bool:StartWarmup()
{
	for(new i = 1; i <= MaxClients; i++)
		RespawnTimer[i] = INVALID_HANDLE;
	
	g_iWarmupWeapon = GetWarmupWeapon();
	
	if(g_iWarmupWeapon == WEAPON_NONE)
		return false;
	
	new String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "configs/restrict/prewarmup.cfg");
	RunFile(file);
	
	StripGroundWeapons();
	ffvalue = GetConVarInt(ffcvar);
	
	if(GetConVarBool(warmupff))
	{
		SetConVarInt(ffcvar, 0, true, false);
	}
	warmupcount = 1;
	if(g_iGame == GAME_CSS)
	{
		PrintCenterTextAll("%t", "WarmupCountdown", GetConVarInt(WarmupTime));
	}
	else
	{
		SetConVarInt(FindConVar("mp_do_warmup_period"), 0, true, false);
		SetConVarInt(FindConVar("mp_warmuptime"), GetConVarInt(WarmupTime), true, false);
		GameRules_SetProp("m_bWarmupPeriod", true, _, _, true);
		GameRules_SetPropFloat("m_fWarmupPeriodEnd", (GetGameTime()+GetConVarFloat(WarmupTime)), _, true);
	}
	CreateTimer(1.0, WarmupCount, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	OnWarmupStart_Post();
	return true;
}
WeaponID:GetWarmupWeapon()
{
	decl String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM,file,sizeof(file),"configs/restrict/warmup.cfg");
	if(!FileExists(file))
	{
		LogError("Cannot find warmup.cfg. Disabling warmup.");
		return WEAPON_NONE;
	}
	new Handle:hFile = OpenFile(file, "r");
	decl WeaponID:iWeaponArray[_:WeaponID];
	new String:weapon[WEAPONARRAYSIZE];
	new weaponcount = 0;
	while(!IsEndOfFile(hFile))
	{
		ReadFileLine(hFile, weapon, sizeof(weapon));
		if(strncmp(weapon, "//", 2) != 0)
		{
			TrimString(weapon);
			new WeaponID:id = Restrict_GetWeaponIDExtended(weapon);
			if(id == WEAPON_NONE)
				continue;
			
			new WeaponSlot:slot = GetSlotFromWeaponID(id);
			
			if(slot == SlotNone || slot == SlotUnknown)
				continue;
			
			iWeaponArray[weaponcount] = id;
			weaponcount++;
		}
	}
	CloseHandle(hFile);
	
	if(weaponcount == 0)
		return WEAPON_NONE;
	
	new index = GetRandomInt(0, weaponcount-1);
	
	return iWeaponArray[index];
}
public Action:WarmupCount(Handle:timer)
{
	if(GetConVarInt(WarmupTime) <= warmupcount)
	{
		EndWarmup();
		if(g_iGame == GAME_CSS)
		{
			ServerCommand("mp_restartgame 1");
		}
		
		return Plugin_Stop;
	}
	if(g_iGame == GAME_CSS)
	{
		PrintCenterTextAll("%t", "WarmupCountdown", GetConVarInt(WarmupTime)-warmupcount);
	}
	else
	{
		GameRules_SetProp("m_bWarmupPeriod", true, _, _, true);
		GameRules_SetPropFloat("m_fWarmupPeriodEnd", GetGameTime()+(GetConVarFloat(WarmupTime)-float(warmupcount)), _, true);
		FireEvent(CreateEvent("round_announce_warmup", true));
	}
	warmupcount++;
	return Plugin_Continue;
}
EndWarmup()
{
	g_currentRoundSpecial = RoundType_None;
	OnWarmupEnd_Post();
	new String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "configs/restrict/postwarmup.cfg");
	RunFile(file);
		
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			KillRespawnTimer(i);
	}
		
	CreateTimer(1.1, ResetFF, _, TIMER_FLAG_NO_MAPCHANGE);
}
public Action:ResetFF(Handle:timer)
{
	//Check if special round was set
	g_currentRoundSpecial = g_nextRoundSpecial;
	g_nextRoundSpecial = RoundType_None;
		
	SetConVarInt(ffcvar, ffvalue, true, false);
}
GiveWarmupWeapon(client)
{
	if(g_iWarmupWeapon != WEAPON_KNIFE && IsClientInGame(client) && GetClientTeam(client) > CS_TEAM_SPECTATOR && Restrict_IsWarmupRound())
	{
		if(GetPlayerWeaponSlot(client, _:GetSlotFromWeaponID(g_iWarmupWeapon)) == -1 || (GetSlotFromWeaponID(g_iWarmupWeapon) == SlotKnife && g_iWarmupWeapon == WEAPON_TASER))// avoids giving player weapon twice for some odd reason grenade is given twice without this
		{
			new String:weapon[WEAPONARRAYSIZE];
			Format(weapon, sizeof(weapon), "weapon_%s", weaponNames[_:g_iWarmupWeapon]);
			GivePlayerItem(client, weapon);
		}
	}
}
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	RespawnTimer[client] = INVALID_HANDLE;
	
	if(Restrict_IsWarmupRound() && IsClientInGame(client) && GetClientTeam(client) > CS_TEAM_SPECTATOR && IsPlayerAlive(client))
	{
		GiveWarmupWeapon(client);
	}
}
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(Restrict_IsWarmupRound() && GetConVarInt(WarmupRespawn) == 1)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		
		if(RespawnTimer[client] == INVALID_HANDLE)
			RespawnTimer[client] = CreateTimer(GetConVarFloat(WarmupRespawnTime), RespawnFunc, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:OnHegrenadeDetonate(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!Restrict_IsWarmupRound() || g_iWarmupWeapon != WEAPON_HEGRENADE || !GetConVarBool(grenadegive))
		return Plugin_Continue;
	
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if(client != 0 && IsClientInGame(client) && GetClientTeam(client) > CS_TEAM_SPECTATOR && IsPlayerAlive(client))
	{
		if(Restrict_GetClientGrenadeCount(client, WEAPON_HEGRENADE) <= 0)
		{
			new weapon = GivePlayerItem(client,"weapon_hegrenade");
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}
	
	return Plugin_Continue;
}
public Action:RespawnFunc(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if(client != 0)
		RespawnTimer[client] = INVALID_HANDLE;
		
	if(client != 0 && GetConVarInt(WarmupRespawn) == 1 && Restrict_IsWarmupRound() && IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_SPECTATOR)
	{
		CS_RespawnPlayer(client);
	}
}
StripGroundWeapons()
{
	for (new i = MaxClients; i <= GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			decl String:name[WEAPONARRAYSIZE];
			GetEdictClassname(i, name, sizeof(name));
			if((strncmp(name, "weapon_", 7, false) == 0 || strncmp(name, "item_", 5, false) == 0) && Restrict_GetWeaponIDExtended(name) != WEAPON_NONE && GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity") == -1)
				AcceptEntityInput(i, "Kill");
		}
	}
}