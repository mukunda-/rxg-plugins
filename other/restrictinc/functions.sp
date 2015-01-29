stock WeaponType:GetTypeGroup(const String:weapon[])
{
	for(new i = 0; i < MAXWEAPONGROUPS; i++)
	{
		if(StrEqual(weapon, g_WeaponGroupNames[i]))
			return WeaponType:i;
	}
	return WeaponTypeNone;
}
stock bool:RunFile(String:file[])
{
	if(!FileExists(file))
	{
		return false;
	}
	new Handle:FileHandle = OpenFile(file, "r");
	new String:Command[50];
	while(!IsEndOfFile(FileHandle))
	{
		ReadFileLine(FileHandle, Command, sizeof(Command));
		TrimString(Command);
		if(strncmp(Command, "//", 2) != 0 && strlen(Command) != 0)
		{
			ServerCommand("%s", Command);
		}
	}
	CloseHandle(FileHandle);
	return true;
}
stock GetCurrentMapEx(String:map[], size)
{
	GetCurrentMap(map, size);
	
	new index = -1;
	for(new i = 0; i < strlen(map); i++)
	{
		if(StrContains(map[i], "/") != -1 || StrContains(map[i], "\\") != -1)
		{
			if(i != strlen(map) - 1)
				index = i;
		}
		else
		{
			break;
		}
	}
	strcopy(map, size, map[index+1]);
}
stock RemoveForSpecialRound(client)
{
	new WeaponID:weapon = WEAPON_NONE;
	new ent = 0;
	if(g_currentRoundSpecial == RoundType_Pistol)
	{
		weapon = Restrict_GetWeaponIDFromSlot(client, SlotPrimmary);
		if(weapon != WEAPON_NONE)
		{
			ent = GetPlayerWeaponSlot(client, _:SlotPrimmary);
			Restrict_RefundMoney(client, weapon);
			Restrict_RemoveWeaponDrop(client, ent);
		}
	}
	else if(g_currentRoundSpecial == RoundType_Knife)
	{
		weapon = Restrict_GetWeaponIDFromSlot(client, SlotPrimmary);
		if(weapon != WEAPON_NONE)
		{
			ent = GetPlayerWeaponSlot(client, _:SlotPrimmary);
			Restrict_RefundMoney(client, weapon);
			Restrict_RemoveWeaponDrop(client, ent);
		}
		weapon = Restrict_GetWeaponIDFromSlot(client, SlotPistol);
		if(weapon != WEAPON_NONE)
		{
			ent = GetPlayerWeaponSlot(client, _:SlotPistol);
			Restrict_RefundMoney(client, weapon);
			Restrict_RemoveWeaponDrop(client, ent);
		}
		new index = 0;
		for(new x = 0; x <= g_iMyWeaponsMax; x++)
		{
			index = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", x);
			if(index && IsValidEdict(index))
			{
				weapon = GetWeaponIDFromEnt(index);
				if(weapon != WEAPON_NONE && GetSlotFromWeaponID(weapon) == SlotGrenade)
				{
					new count = Restrict_GetClientGrenadeCount(client, weapon);
					for(new i = 1; i <= count; i++)
						Restrict_RefundMoney(client, weapon);
					
					Restrict_RemoveWeaponDrop(client, index);
				}
			}
		}
	}
}
stock GetWeaponRestrictSound()
{
	g_bRestrictSound = false;
	new String:file[PLATFORM_MAX_PATH];
	GetConVarString(RestrictSound, file, sizeof(file));
	if(strlen(file) > 0 && FileExists(file, true))
	{
		AddFileToDownloadsTable(file);
		if(StrContains(file, "sound/", false) == 0)
		{
			ReplaceStringEx(file, sizeof(file), "sound/", "", -1, -1, false);
			strcopy(g_sCachedSound, sizeof(g_sCachedSound), file);
		}
		if(PrecacheSound(g_sCachedSound, true))
		{
			g_bRestrictSound = true;
		}
		else
		{
			LogError("Failed to precache restrict sound please make sure path is correct in %s and sound is in the sounds folder", file);
		}
	}
	else if(strlen(file) > 0)
	{
		LogError("Sound %s dosnt exist", file);
	}
}
stock IsGoingToPickup(client, WeaponID:id)
{
	new WeaponSlot:slot = GetSlotFromWeaponID(id);
	
	if(IsValidWeaponSlot(slot))
	{
		if(slot == SlotGrenade)
		{
			new count = Restrict_GetClientGrenadeCount(client, id);
			if(hHeAmmo == INVALID_HANDLE || hFlashAmmo == INVALID_HANDLE || hSmokeAmmo == INVALID_HANDLE)
			{
				if(((id == WEAPON_HEGRENADE || id == WEAPON_SMOKEGRENADE) && count == 0) || (id == WEAPON_FLASHBANG && count < 2))
					return true;
			}
			else
			{
				if((id == WEAPON_HEGRENADE && count < GetConVarInt(hHeAmmo)) || (id == WEAPON_SMOKEGRENADE && count < GetConVarInt(hSmokeAmmo)) || (id == WEAPON_FLASHBANG && count < GetConVarInt(hSmokeAmmo)))
					return true;
			}
		}
		else //Only 1 check needed
		{
			new weapon = GetPlayerWeaponSlot(client, _:slot);
			if(weapon == -1)
				return true;
		}
	}
	return false;
}
stock ClearOverride()
{
	for(new i = 1; i < _:WeaponID; i++)
	{
		Restrict_RemoveFromOverride(CS_TEAM_T, WeaponID:i);
		Restrict_RemoveFromOverride(CS_TEAM_CT, WeaponID:i);
	}
}
stock GetMaxGrenades()
{
	if(hHeAmmo == INVALID_HANDLE || hFlashAmmo == INVALID_HANDLE || hSmokeAmmo == INVALID_HANDLE)
	{
		return 2;//Return flash count
	}
	new hecount = GetConVarInt(hHeAmmo);
	new flashcount = GetConVarInt(hFlashAmmo);
	new smokecount = GetConVarInt(hSmokeAmmo);
	
	return (hecount > flashcount)? ((hecount > smokecount)? hecount:smokecount):((flashcount > smokecount)? flashcount:smokecount);
}
stock bool:IsValidClient(client, isZeroValid=false)
{
	if(isZeroValid && client == 0)
		return true;
	
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return false;
	
	return true;
}
stock bool:IsValidWeaponID(WeaponID:id)
{
	if(_:id <= _:WEAPON_NONE || _:id >= _:WeaponID)
		return false;
	
	return true;
}
stock bool:IsValidTeam(team, isSpecValid=false)
{
	if(isSpecValid && (team == CS_TEAM_NONE || team == CS_TEAM_SPECTATOR))
		return true;
	else if(team == CS_TEAM_NONE || team == CS_TEAM_SPECTATOR)
		return false;
	
	return true;
}
stock bool:IsValidWeaponSlot(WeaponSlot:slot)
{
	if(slot < SlotPrimmary || slot > SlotC4)
		return false;
	return true;
}
stock bool:IsValidWeaponGroup(WeaponType:group)
{
	if(group > WeaponTypeOther || group < WeaponTypePistol)
		return false;
	return true;
}