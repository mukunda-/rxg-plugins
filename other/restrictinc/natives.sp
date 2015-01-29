new Handle:hCanBuyForward = INVALID_HANDLE;
new Handle:hCanPickupForward = INVALID_HANDLE;
new Handle:hRestrictSoundForward = INVALID_HANDLE;
new Handle:hWarmupStartForward = INVALID_HANDLE;
new Handle:hWarmupEndForward = INVALID_HANDLE;
#if defined PERPLAYER
new bool:g_bOverideT[_:WeaponID];
new bool:g_bOverideCT[_:WeaponID];
#endif

//m_iAmmo array index
new HEGRENADE_AMMO = 11;
new FLASH_AMMO = 12;
new SMOKE_AMMO = 13;

//CS:GO ONLY
new INC_AMMO = 16;
new DECOY_AMMO = 17;

RegisterNatives()
{
	if(g_iGame == GAME_CSGO)
	{
		HEGRENADE_AMMO = 13;
		FLASH_AMMO = 14;
		SMOKE_AMMO = 15;
	}
	RegPluginLibrary("weaponrestrict");
	
	CreateNative("Restrict_RefundMoney", Native_RefundMoney);
	CreateNative("Restrict_RemoveRandom", Native_RemoveRandom);
	CreateNative("Restrict_GetTeamWeaponCount", Native_GetTeamWeaponCount);
	CreateNative("Restrict_GetRestrictValue", Native_GetRestrictValue);
	CreateNative("Restrict_GetWeaponIDExtended", Native_GetWeaponIDExtended);
	CreateNative("Restrict_GetClientGrenadeCount", Native_GetClientGrenadeCount);
	CreateNative("Restrict_GetWeaponIDFromSlot", Native_GetWeaponIDFromSlot);
	CreateNative("Restrict_RemoveSpecialItem", Native_RemoveSpecialItem);
	CreateNative("Restrict_CanBuyWeapon", Native_CanBuyWeapon);
	CreateNative("Restrict_CanPickupWeapon", Native_CanPickupWeapon);
	CreateNative("Restrict_IsSpecialRound", Native_IsSpecialRound);
	CreateNative("Restrict_IsWarmupRound", Native_IsWarmupRound);
	CreateNative("Restrict_HasSpecialItem", Native_HasSpecialItem);
	CreateNative("Restrict_SetRestriction", Native_SetRestriction);
	CreateNative("Restrict_SetGroupRestriction", Native_SetGroupRestriction);
	CreateNative("Restrict_GetRoundType", Native_GetRoundType);
	CreateNative("Restrict_CheckPlayerWeapons", Native_CheckPlayerWeapons);
	CreateNative("Restrict_RemoveWeaponDrop", Native_RemoveWeaponDrop);
	CreateNative("Restrict_ImmunityCheck", Native_ImmunityCheck);
	CreateNative("Restrict_AllowedForSpecialRound", Native_IsAllowedForSpecialRound);
	CreateNative("Restrict_PlayRestrictSound", Native_PlayRestrictSound);
	CreateNative("Restrict_AddToOverride", Native_AddToOverride);
	CreateNative("Restrict_RemoveFromOverride", Native_RemoveFromOverride);
	CreateNative("Restrict_IsWeaponInOverride", Native_IsWeaponInOverride);
	CreateNative("Restrict_IsWarmupWeapon", Native_IsWarmupWeapon);
}
RegisterForwards()
{
	hCanBuyForward = CreateGlobalForward("Restrict_OnCanBuyWeapon", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	hCanPickupForward = CreateGlobalForward("Restrict_OnCanPickupWeapon", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	hRestrictSoundForward = CreateGlobalForward("Restrict_OnPlayRestrictSound", ET_Event, Param_Cell, Param_Cell, Param_String);
	hWarmupStartForward = CreateGlobalForward("Restrict_OnWarmupStart_Post", ET_Ignore);
	hWarmupEndForward = CreateGlobalForward("Restrict_OnWarmupEnd_Post", ET_Ignore);
}
stock OnWarmupStart_Post()
{
	Call_StartForward(hWarmupStartForward);
	Call_Finish();
}
stock OnWarmupEnd_Post()
{
	Call_StartForward(hWarmupEndForward);
	Call_Finish();
}
public Native_RefundMoney(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new amount = GetWeaponPrice(client, id);
		
	new max = 16000;
	if(mp_maxmoney != INVALID_HANDLE)
		max = GetConVarInt(mp_maxmoney);
	
	new account = GetEntProp(client, Prop_Send, "m_iAccount");
	account += amount;
	if(account < max)
		SetEntProp(client, Prop_Send, "m_iAccount", account);
	else
		SetEntProp(client, Prop_Send, "m_iAccount", max);
		
	PrintToChat(client, "\x01\x0B\x04[SM] %T %T", "Refunded", client, amount,  weaponNames[_:id], client);
	
	return 1;
}
public Native_RemoveRandom(Handle:hPlugin, iNumParams)
{
	new count = GetNativeCell(1);
	new team = GetNativeCell(2);
	new WeaponID:id = GetNativeCell(3);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new WeaponSlot:slot = GetSlotFromWeaponID(id);
	new weaponArray[MAXPLAYERS*GetMaxGrenades()];//Times X since a player can have X flashes/he/smokes x being the value of the ammo cvars
	
	new index = 0;
	if(slot == SlotUnknown)
		return ThrowNativeError(SP_ERROR_NATIVE, "Unknown weapon slot returned.");
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || Restrict_ImmunityCheck(i) || GetClientTeam(i) != team)
			continue;
		
		if(slot == SlotGrenade || id == WEAPON_TASER || id == WEAPON_KNIFE || id == WEAPON_KNIFE_GG)// CSGO has 2 "knives" slots
		{
			new gcount;
			if(id == WEAPON_TASER || id == WEAPON_KNIFE || id == WEAPON_KNIFE_GG)//CSGO 
			{
				gcount = 1;
			}
			else
			{
				gcount = Restrict_GetClientGrenadeCount(i, id);
			}
			new ent = 0;
			for(new x = 0; x <= g_iMyWeaponsMax; x++)
			{
				ent = GetEntPropEnt(i, Prop_Send, "m_hMyWeapons", x);
				if(ent != -1 && ent && IsValidEdict(ent) && GetWeaponIDFromEnt(ent) == id)
				{
					for(new z = 1; z <= gcount; z++)
					{
						weaponArray[index] = ent;
						index++;
					}
				}
			}
		}
		else if(slot == SlotNone)
		{
			if(Restrict_HasSpecialItem(i, id))
			{
				weaponArray[index] = i;
				index++;
			}
		}
		else
		{
			new ent = GetPlayerWeaponSlot(i, _:slot);
			if(ent != -1 && GetWeaponIDFromEnt(ent) == id)
			{
				weaponArray[index] = ent;
				index++;
			}
		}
	}
	SortIntegers(weaponArray, index-1, Sort_Random);
	
	if(slot == SlotGrenade)
	{
		new ammoindex = -1;
		switch(id)
		{
			case WEAPON_HEGRENADE:
			{
				ammoindex = HEGRENADE_AMMO;
			}
			case WEAPON_FLASHBANG:
			{
				ammoindex = FLASH_AMMO;
			}
			case WEAPON_SMOKEGRENADE:
			{
				ammoindex = SMOKE_AMMO;
			}
			case WEAPON_INCGRENADE, WEAPON_MOLOTOV:
			{
				ammoindex = INC_AMMO;
			}
			case WEAPON_DECOY:
			{
				ammoindex = DECOY_AMMO;
			}
		}
		for(new i = 0; i < count; i++)
		{
			if(i <= index-1 && IsValidEdict(weaponArray[i]))
			{
				new client = GetEntPropEnt(weaponArray[i], Prop_Data, "m_hOwnerEntity");
				if(client != -1)
				{
					new gcount = Restrict_GetClientGrenadeCount(client, id);
					if(gcount == 0)
						continue;
					
					if(gcount == 1)
					{
						if(Restrict_RemoveWeaponDrop(client, weaponArray[i]))
						{
							Restrict_RefundMoney(client, id);
						}
					}
					else
					{
						SetEntProp(client, Prop_Send, "m_iAmmo", gcount-1, _, ammoindex);
						Restrict_RefundMoney(client, id);
					}
				}
			}
		}
	}
	else if(slot != SlotNone)
	{
		for(new i = 0; i < count; i++)
		{
			if(i <= index-1 && IsValidEdict(weaponArray[i]))
			{
				new client = GetEntPropEnt(weaponArray[i], Prop_Data, "m_hOwnerEntity");
				if(client != -1)
				{
					if(Restrict_RemoveWeaponDrop(client, weaponArray[i]))
					{
						Restrict_RefundMoney(client, id);
					}
				}
			}
		}
	}
	else
	{
		for(new i = 0; i < count; i++)
		{
			if(i > index -1)
				break;
			
			if(IsClientInGame(weaponArray[i]))
			{
				if(Restrict_RemoveSpecialItem(weaponArray[i], id))
				{
					Restrict_RefundMoney(weaponArray[i], id);
				}
			}
		}
	}
	return 1;
}
public Native_GetTeamWeaponCount(Handle:hPlugin, iNumParams)
{
	new team = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new weaponcount = 0;
	new WeaponSlot:slot = GetSlotFromWeaponID(id);
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || Restrict_ImmunityCheck(i) || GetClientTeam(i) != team)
			continue;
		
		if(slot == SlotGrenade)
		{
			weaponcount += Restrict_GetClientGrenadeCount(i, id);
		}
		else if(slot == SlotNone)
		{
			if(Restrict_HasSpecialItem(i, id))
				weaponcount++;
		}
		else
		{
			if(Restrict_GetWeaponIDFromSlot(i, slot) == id)
				weaponcount++;
		}
	}
	return weaponcount;
}
public Native_GetRestrictValue(Handle:hPlugin, iNumParams)
{
	new team = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new val = -1;
	if(team == CS_TEAM_T && id != WEAPON_DEFUSER)
	{
		new arraycell = CvarArrayHandleValT[_:id];
		if(arraycell == -1)
			return -1;
		val = GetConVarInt(hRestrictCVarsT[arraycell]);
	}
	else if(team == CS_TEAM_CT && id != WEAPON_C4)
	{
		new arraycell = CvarArrayHandleValCT[_:id];
		if(arraycell == -1)
			return -1;
		val = GetConVarInt(hRestrictCVarsCT[arraycell]);
	}
	
	if(val <= -1)
		return -1;
		
	return val;
}
public Native_GetWeaponIDExtended(Handle:hPlugin, iNumParams)
{
	decl String:weapon[WEAPONARRAYSIZE];
	GetNativeString(1, weapon, sizeof(weapon));
	
	new WeaponID:id = GetWeaponID(weapon);
	
	if(id != WEAPON_NONE)
		return _:id;
	
	//Check for weird buy strings...
	decl String:weapon2[WEAPONARRAYSIZE];
	CS_GetTranslatedWeaponAlias(weapon, weapon2, sizeof(weapon2));
	
	id = WeaponID:_:CS_AliasToWeaponID(weapon2); //New method as of 1.4.3
	
	/*for(new i = 0; i < MAXALIASES; i++)
	{
		if(StrContains(weapon2, g_WeaponAliasNames[i], false) != -1)
		{
			id = GetWeaponID(g_WeaponAliasReplace[i]);
			
			if(id != WEAPON_NONE)
				return _:id;
		}
	}
	
	for(new i = 1; i < _:WeaponID; i++)
	{
		if(StrContains(weapon2, weaponNames[WeaponID:i], false) != -1)
		{
			return _:WeaponID:i;
		}
	}*/
	
	return _:id;
}
public Native_GetClientGrenadeCount(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new index = -1;
	switch(id)
	{
		case WEAPON_HEGRENADE:
		{
			index = HEGRENADE_AMMO;
		}
		case WEAPON_FLASHBANG:
		{
			index = FLASH_AMMO;
		}
		case WEAPON_SMOKEGRENADE:
		{
			index = SMOKE_AMMO;
		}
		case WEAPON_INCGRENADE, WEAPON_MOLOTOV:
		{
			index = INC_AMMO;
		}
		case WEAPON_DECOY:
		{
			index = DECOY_AMMO;
		}
		default:
		{
			return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is not a grenade.", _:id);
		}
	}
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, index);
}
public Native_GetWeaponIDFromSlot(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new WeaponSlot:slot = GetNativeCell(2);
	
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidWeaponSlot(slot))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon slot index %d is invalid.", _:slot);
	}
	new ent = GetPlayerWeaponSlot(client, _:slot);
		
	if(ent != -1)
	{
		return _:GetWeaponIDFromEnt(ent);
	}
	return _:WEAPON_NONE;
}
public Native_RemoveSpecialItem(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	if(id == WEAPON_DEFUSER && GetEntProp(client, Prop_Send, "m_bHasDefuser") !=0)
	{
		SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
		return true;
	}
	else if(id == WEAPON_ASSAULTSUIT && GetEntProp(client, Prop_Send, "m_ArmorValue") != 0 && GetEntProp(client, Prop_Send, "m_bHasHelmet") != 0)
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
		return true;
	}
	else if(id == WEAPON_KEVLAR && GetEntProp(client, Prop_Send, "m_ArmorValue") != 0 && GetEntProp(client, Prop_Send, "m_bHasHelmet") == 0)
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
		return true;
	}
	else if(id == WEAPON_NIGHTVISION && GetEntProp(client, Prop_Send, "m_bHasNightVision") !=0)
	{
		SetEntProp(client, Prop_Send, "m_bHasNightVision", 0);
		return true;
	}
	return false;
}
public Native_CanBuyWeapon(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new team = GetNativeCell(2);
	new WeaponID:id = GetNativeCell(3);
	new bool:blockhook = GetNativeCell(4);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new CanBuyResult:result = CanBuy_Block;
	new maxamount = Restrict_GetRestrictValue(team, id);
	if(!Restrict_IsSpecialRound())
	{
		if(maxamount == -1 || Restrict_ImmunityCheck(client) || (Restrict_GetTeamWeaponCount(team, id) < maxamount))
			result = CanBuy_Allow;
	}
	else if(Restrict_AllowedForSpecialRound(id))
	{
		//If pistol round always allow any pistol
		//If knife round always allow knife
		//If Warmup always allow warmup weapon
		new WeaponSlot:slot = GetSlotFromWeaponID(id);
		#if defined WARMUP
		if((g_currentRoundSpecial == RoundType_Pistol && slot == SlotPistol) || (g_currentRoundSpecial == RoundType_Knife && slot == SlotKnife) || (g_currentRoundSpecial == RoundType_Warmup && id == g_iWarmupWeapon))
		#else
		if((g_currentRoundSpecial == RoundType_Pistol && slot == SlotPistol) || (g_currentRoundSpecial == RoundType_Knife && slot == SlotKnife))
		#endif
			result = CanBuy_Allow;
		else if(maxamount == -1 || Restrict_ImmunityCheck(client) || (Restrict_GetTeamWeaponCount(team, id) < maxamount))
			result = CanBuy_Allow;
	}
	if(!blockhook)
	{
		new CanBuyResult:orgresult = result;
		new Action:res = Plugin_Continue;
		Call_StartForward(hCanBuyForward);
		Call_PushCell(client);
		Call_PushCell(team);
		Call_PushCell(id);
		Call_PushCellRef(result);
		Call_Finish(res);
		if(res == Plugin_Continue)
			return _:orgresult;
		if(res >= Plugin_Handled)
			return _:CanBuy_Block;
	}
	return _:result;
}
public Native_CanPickupWeapon(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new team = GetNativeCell(2);
	new WeaponID:id = GetNativeCell(3);
	new bool:blockhook = GetNativeCell(4);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new bool:result = false;
	new restrictval = Restrict_GetRestrictValue(team, id);
	new teamval = Restrict_GetTeamWeaponCount(team, id);
	if(Restrict_IsWarmupRound())
	{
		if(Restrict_IsWarmupWeapon(id) || id == WEAPON_KNIFE)
			result = true;
	}
	else if(!Restrict_IsSpecialRound())
	{
		if(id == WEAPON_AWP && !GetConVarBool(AwpAllowPickup))
		{
			if(restrictval == -1 || Restrict_ImmunityCheck(client) || (teamval < restrictval))
				result = true;
		}
		else if(restrictval == -1 || Restrict_ImmunityCheck(client) || (teamval < restrictval) || GetConVarBool(AllowPickup))
			result = true;
	}
	else if(Restrict_AllowedForSpecialRound(id))
	{
		//If pistol round always allow any pistol
		//If knife round always allow knife
		//If Warmup always allow warmup weapon
		new WeaponType:type = GetWeaponTypeFromID(id);
		#if defined WARMUP
		if((g_currentRoundSpecial == RoundType_Pistol && type == WeaponTypePistol) || (g_currentRoundSpecial == RoundType_Knife && type == WeaponTypeKnife) || (g_currentRoundSpecial == RoundType_Warmup && id == g_iWarmupWeapon))
		#else
		if((g_currentRoundSpecial == RoundType_Pistol && type == WeaponTypePistol) || (g_currentRoundSpecial == RoundType_Knife && type == WeaponTypeKnife))
		#endif
			result = true;
		else if(restrictval == -1 || Restrict_ImmunityCheck(client) || (teamval < restrictval))
			result = true;
	}
	if(!blockhook)
	{
		new bool:orgresult = result;
		new Action:res = Plugin_Continue;
		Call_StartForward(hCanPickupForward);
		Call_PushCell(client);
		Call_PushCell(team);
		Call_PushCell(id);
		Call_PushCellRef(result);
		Call_Finish(res);
		if(res == Plugin_Continue)
			return orgresult;
		if(res >= Plugin_Handled)
			return false;
	}
	return result;
}
public Native_IsSpecialRound(Handle:hPlugin, iNumParams)
{
	if(g_currentRoundSpecial == RoundType_None)
		return false;
	return true;
}
public Native_IsWarmupRound(Handle:hPlugin, iNumParams)
{
	#if defined WARMUP
	if(g_currentRoundSpecial == RoundType_Warmup)
		return true;
	#endif
	return false;
}
public Native_HasSpecialItem(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	if(id == WEAPON_DEFUSER && GetEntProp(client, Prop_Send, "m_bHasDefuser") != 0)
		return true;
	else if(id == WEAPON_ASSAULTSUIT && GetEntProp(client, Prop_Send, "m_ArmorValue") != 0 && GetEntProp(client, Prop_Send, "m_bHasHelmet") != 0)
		return true;
	else if(id == WEAPON_KEVLAR && GetEntProp(client, Prop_Send, "m_ArmorValue") != 0 && GetEntProp(client, Prop_Send, "m_bHasHelmet") == 0)
		return true;
	else if(id == WEAPON_NIGHTVISION && GetEntProp(client, Prop_Send, "m_bHasNightVision") != 0)
		return true;
	
	return false;
}
public Native_SetRestriction(Handle:hPlugin, iNumParams)
{
	new WeaponID:id = GetNativeCell(1);
	new team = GetNativeCell(2);
	new amount = GetNativeCell(3);
	#if defined PERPLAYER //avoid warnings this is only needed if perplayer is compiled in.
	new bool:override = GetNativeCell(4);
	#endif
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	if(amount < -1)
		amount = -1;
	new arraycell = -1;
	if(team == CS_TEAM_T && id != WEAPON_DEFUSER)
	{
		arraycell = CvarArrayHandleValT[_:id];
		if(arraycell == -1)
			return false;
		
		SetConVarInt(hRestrictCVarsT[arraycell], amount, true, false);
	}
	else if(team == CS_TEAM_CT && id != WEAPON_C4)
	{
		arraycell = CvarArrayHandleValCT[_:id];
		if(arraycell == -1)
			return false;
		
		SetConVarInt(hRestrictCVarsCT[arraycell], amount, true, false);
	}
	#if defined PERPLAYER
	if(override)
	{
		Restrict_AddToOverride(team, id);
	}
	#endif
	return true;
}
public Native_SetGroupRestriction(Handle:hPlugin, iNumParams)
{
	new WeaponType:group = GetNativeCell(1);
	new team = GetNativeCell(2);
	new amount = GetNativeCell(3);
	new bool:override = GetNativeCell(4);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponGroup(group))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon group index %d is invalid.", _:group);
	}
	for(new i = 1; i < _:WeaponID; i++)
	{
		if(group == GetWeaponTypeFromID(WeaponID:i))
			Restrict_SetRestriction(WeaponID:i, team, amount, override);
	}
	return true;
}
public Native_GetRoundType(Handle:hPlugin, iNumParams)
{
	return _:g_currentRoundSpecial;
}
public Native_CheckPlayerWeapons(Handle:hPlugin, iNumParams)
{
	for(new i = 1; i < _:WeaponID; i++)
    {
		if(WeaponID:i == WEAPON_SHIELD)//need to skip items.
			continue;
		
		if(WeaponID:i != WEAPON_DEFUSER)
		{
			new val = Restrict_GetRestrictValue(CS_TEAM_T, WeaponID:i);
			
			if(val == -1)
				continue;
			
			new count = Restrict_GetTeamWeaponCount(CS_TEAM_T, WeaponID:i);
			
			if(count > val)
				Restrict_RemoveRandom(count-val, CS_TEAM_T, WeaponID:i);
		}
		if(WeaponID:i != WEAPON_C4)
		{
			new val = Restrict_GetRestrictValue(CS_TEAM_CT, WeaponID:i);
			
			if(val == -1)
				continue;
			
			new count = Restrict_GetTeamWeaponCount(CS_TEAM_CT, WeaponID:i);
			
			if(count > val)
				Restrict_RemoveRandom(count-val, CS_TEAM_CT, WeaponID:i);
		}
	}
}
public Native_RemoveWeaponDrop(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new entity = GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidEntity(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon index %d is invalid.", entity);
	}
	CS_DropWeapon(client, entity, true, true);
	if(AcceptEntityInput(entity, "Kill"))
		return true;
	
	return false;
}
public Native_ImmunityCheck(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(GetConVarInt(AdminImmunity) == 1 && CheckCommandAccess(client, "sm_restrict_immunity_level", ADMFLAG_RESERVATION))
		return true;
	
	return false;
}
public Native_IsAllowedForSpecialRound(Handle:hPlugin, iNumParams)
{
	new WeaponID:id = GetNativeCell(1);
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	//Get the easy stuff out of the way
	//Always allow knife.
	if(id == WEAPON_KNIFE)
		return true;
	
	new WeaponSlot:slot = GetSlotFromWeaponID(id);
	//For pistol round and knife allow kevlar and stuff
	if((g_currentRoundSpecial == RoundType_Pistol || g_currentRoundSpecial == RoundType_Knife) && (slot == SlotNone || slot == SlotC4))
		return true;
	//Pistol round allow anything in slot 1
	if(g_currentRoundSpecial == RoundType_Pistol && (slot == SlotPistol || slot == SlotGrenade))
		return true;
	#if defined WARMUP
	if(g_currentRoundSpecial == RoundType_Warmup && id == g_iWarmupWeapon)
		return true;
	#endif
	return false;
}
public Native_PlayRestrictSound(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid.", client);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	new Action:res = Plugin_Continue;
	new String:forwardFile[PLATFORM_MAX_PATH];
	strcopy(forwardFile, sizeof(forwardFile), g_sCachedSound);
	
	Call_StartForward(hRestrictSoundForward);
	Call_PushCell(client);
	Call_PushCell(id);
	Call_PushStringEx(forwardFile, sizeof(forwardFile), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish(res);
	if(res == Plugin_Continue && g_bRestrictSound)
		EmitSoundToClient(client, g_sCachedSound);
	if(res == Plugin_Changed && IsSoundPrecached(forwardFile))
		EmitSoundToClient(client, forwardFile);
	
	return 1;
}
public Native_AddToOverride(Handle:hPlugin, iNumParams)
{	
	#if defined PERPLAYER
	new team = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	if(team == CS_TEAM_T)
		g_bOverideT[_:id] = true;
	if(team == CS_TEAM_CT)
		g_bOverideCT[_:id] = true;
	#endif
	return 1;
}
public Native_RemoveFromOverride(Handle:hPlugin, iNumParams)
{	
	#if defined PERPLAYER
	new team = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	if(team == CS_TEAM_T)
		g_bOverideT[_:id] = false;
	if(team == CS_TEAM_CT)
		g_bOverideCT[_:id] = false;
	#endif
	return 1;
}
public Native_IsWeaponInOverride(Handle:hPlugin, iNumParams)
{	
	#if defined PERPLAYER
	new team = GetNativeCell(1);
	new WeaponID:id = GetNativeCell(2);
	if(!IsValidTeam(team))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Team index %d is invalid.", team);
	}
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	if(team == CS_TEAM_T && g_bOverideT[_:id])
		return true;
	if(team == CS_TEAM_CT && g_bOverideCT[_:id])
		return true;
	#endif
	return false;
}
public Native_IsWarmupWeapon(Handle:hPlugin, iNumParams)
{	
	#if defined WARMUP
	new WeaponID:id = GetNativeCell(1);
	if(!IsValidWeaponID(id))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Weapon id %d is invalid.", _:id);
	}
	return (g_iWarmupWeapon == id && Restrict_IsWarmupRound())? true:false;
	#else
	return false;
	#endif
}