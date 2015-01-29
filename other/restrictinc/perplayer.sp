new defaultValuesCT[_:WeaponID];
new defaultValuesT[_:WeaponID];
new WeaponID:currentID = WEAPON_NONE;
new bool:bIsFirstKey = true;
new iLastVal = -1;
new iLastIndex = 0;
new perPlayer[_:WeaponID][MAXPLAYERS+1];
new bool:g_bPerPlayerReady = false;
PerPlayerInit()
{
	for(new i = 0; i < _:WeaponID; i++)
	{
		for(new x = 0; x <= MAXPLAYERS; x++)
		{
			perPlayer[i][x] = -2;
		}
	}
	for(new i = 1; i < _:WeaponID; i++)
	{
		if(WeaponID:i == WEAPON_SHIELD)
			continue;
			
		if(WeaponID:i != WEAPON_DEFUSER)
		{
			defaultValuesT[i] = Restrict_GetRestrictValue(CS_TEAM_T, WeaponID:i);
		}
		if(WeaponID:i != WEAPON_C4)
		{
			defaultValuesCT[i] = Restrict_GetRestrictValue(CS_TEAM_CT, WeaponID:i);
		}
	}
	new String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "configs/restrict/perplayerrestrict.txt");
	if(!FileExists(file))
	{
		LogError("Failed to locate perplayer.txt");
		return;
	}
	new Handle:parser = SMC_CreateParser();
	new line = 0;
	new col = 0;
	
	SMC_SetReaders(parser, Perplayer_NewSection, Perplayer_KeyValue, Perplayer_EndSection);
	SMC_SetParseEnd(parser, Perplayer_ParseEnd);
	
	new SMCError:error = SMC_ParseFile(parser, file, line, col);
	CloseHandle(parser);
	if(error)
	{
		new String:errorString[128];
		SMC_GetErrorString(error, errorString, sizeof(errorString));
		LogError("Perplayer parser error on line %i col %i. Error: %s", line, col, errorString);
		return;
	}
	g_bPerPlayerReady = true;
	#if defined DEBUG
	Perplayer_Debug(0);
	#endif
}
public Action:Perplayer_Debug(args)
{
	new last;
	new lastval;
	for(new i = 0; i < _:WeaponID; i++)
	{
		if(perPlayer[i][0] == -2)
			continue;
		else
		{
			last = 0;
			lastval = perPlayer[i][0];
			for(new x = 1; x <= MAXPLAYERS; x++)
			{
				if(lastval != perPlayer[i][x])
				{
					PrintToServer("Between %i and %i %s will be restricted to %i", last, x-1, weaponNames[WeaponID:i], lastval);
					lastval = perPlayer[i][x];
					last = x;
				}
				if(x == MAXPLAYERS)
				{
					PrintToServer("Between %i and %i %s will be restricted to %i", last, MAXPLAYERS, weaponNames[WeaponID:i], lastval);
				}
			}
		}
	}
	return Plugin_Handled;
}
public SMCResult:Perplayer_NewSection(Handle:parser, const String:section[], bool:quotes)
{
	if(StrEqual(section, "PerPlayer", false))
	{
		return SMCParse_Continue;
	}
	new WeaponID:id = Restrict_GetWeaponIDExtended(section);
	if(IsValidWeaponID(id))
	{
		currentID = id;
		bIsFirstKey = true;
		iLastIndex = 0;
	}
	else
	{
		LogError("Invalid section name found in perplayer.txt");
		return SMCParse_HaltFail;
	}
	return SMCParse_Continue;
}
public SMCResult:Perplayer_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	if(bIsFirstKey)
	{
		if(StrEqual(key, "default", false))
		{
			bIsFirstKey = false;
			iLastVal = StringToInt(value);
			if(iLastVal < -1)
				iLastVal = -1;
		}
		else
		{
			return SMCParse_HaltFail;
		}
	}
	else
	{
		new index = StringToInt(key);
		
		if(index > MAXPLAYERS)
			index = MAXPLAYERS;
		
		for(new i = iLastIndex; i < index; i++)
		{
			perPlayer[currentID][i] = iLastVal;
		}
		iLastIndex = index;
		iLastVal = StringToInt(value);
		if(iLastVal < -1)
			iLastVal = -1;
	}
	return SMCParse_Continue;
}
public SMCResult:Perplayer_EndSection(Handle:parser)
{
	for(new i = iLastIndex; i <= MAXPLAYERS; i++)
	{
		perPlayer[currentID][i] = iLastVal;
	}
	currentID = WEAPON_NONE;
	return SMCParse_Continue;
}
public Perplayer_ParseEnd(Handle:parser, bool:halted, bool:failed)
{
	if(failed)
	{
		LogError("Failed to parse Perplayer fully");
	}
}
CheckPerPlayer()
{
	if(!g_bPerPlayerReady)
		return;
	if(GetConVarBool(PerPlayerRestrict))
	{
		new count = GetPlayerCount();
		for(new i = 1; i < _:WeaponID; i++)
		{
			if(WeaponID:i == WEAPON_SHIELD)
				continue;
			
			if(WeaponID:i != WEAPON_DEFUSER)
			{
				if(perPlayer[i][0] != -2 && Restrict_GetRestrictValue(CS_TEAM_T, WeaponID:i) != perPlayer[i][count] && !Restrict_IsWeaponInOverride(CS_TEAM_T, WeaponID:i))
				{
					Restrict_SetRestriction(WeaponID:i, CS_TEAM_T, perPlayer[i][count], false);
				}
			}
			if(WeaponID:i != WEAPON_C4)
			{
				if(perPlayer[i][0] != -2 && Restrict_GetRestrictValue(CS_TEAM_CT, WeaponID:i) != perPlayer[i][count] && !Restrict_IsWeaponInOverride(CS_TEAM_CT, WeaponID:i))
				{
					Restrict_SetRestriction(WeaponID:i, CS_TEAM_CT, perPlayer[i][count], false);
				}
			}
		}
	}
	else
	{
		for(new i = 1; i < _:WeaponID; i++)
		{
			if(WeaponID:i == WEAPON_SHIELD)
				continue;
			
			if(WeaponID:i != WEAPON_DEFUSER)
			{
				if(Restrict_GetRestrictValue(CS_TEAM_T, WeaponID:i) != defaultValuesT[i] && !Restrict_IsWeaponInOverride(CS_TEAM_T, WeaponID:i))
				{
					Restrict_SetRestriction(WeaponID:i, CS_TEAM_T, defaultValuesT[i], false);
				}
			}
			if(WeaponID:i != WEAPON_C4)
			{
				if(Restrict_GetRestrictValue(CS_TEAM_CT, WeaponID:i) != defaultValuesCT[i] && !Restrict_IsWeaponInOverride(CS_TEAM_CT, WeaponID:i))
				{
					Restrict_SetRestriction(WeaponID:i, CS_TEAM_CT, defaultValuesCT[i], false);
				}
			}
		}
	}
}
GetPlayerCount()
{
	new count = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || (!GetConVarBool(PerPlayerBots) && IsFakeClient(i)) || (!GetConVarBool(PerPlayerSpecs) && (GetClientTeam(i) == CS_TEAM_NONE || GetClientTeam(i) == CS_TEAM_SPECTATOR)))
			continue;
		
		count++;
	}
	return count;
}