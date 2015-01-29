RegisterAdminCommands()
{
	RegAdminCmd("sm_restrict", RestrictAdminCmd, ADMFLAG_CONVARS, "Restrict weapons");
	RegAdminCmd("sm_unrestrict", UnrestrictAdminCmd, ADMFLAG_CONVARS, "Unrestrict weapons");
	RegAdminCmd("sm_knives", KnifeRound, ADMFLAG_CONVARS, "Sets up a knife round.");
	RegAdminCmd("sm_pistols", PistolRound, ADMFLAG_CONVARS, "Sets up a pistol round.");
	RegAdminCmd("sm_dropc4", DropC4, ADMFLAG_BAN, "Forces bomb drop");
	RegAdminCmd("sm_reload_restrictions", ReloadRestrict, ADMFLAG_CONVARS, "Reloads all restricted weapon cvars and removes any admin overrides");
	RegAdminCmd("sm_remove_restricted", RemoveRestricted, ADMFLAG_CONVARS, "Removes restricted weapons from players to the limit the weapons are set to.");
}
public Action:RemoveRestricted(client, args)
{
	LogAction(client, -1, "\"%L\" removed all restricted weapons", client);
	ShowActivity2(client, ADMINCOMMANDTAG, "%t", "RemovedRestricted");
	Restrict_CheckPlayerWeapons();
	return Plugin_Handled;
}
stock bool:HandleRestrictionCommand(client, String:weapon[], team=0, amount=-1, bool:shouldbeall = false)
{
	if(StrEqual(weapon, "@all", false) || StrEqual(weapon, "all", false))
	{
		for(new i = 1; i < _:WeaponID; i++)
		{
			Restrict_SetRestriction(WeaponID:i, CS_TEAM_CT, amount, true);
			Restrict_SetRestriction(WeaponID:i, CS_TEAM_T, amount, true);
		}
		if(amount != -1)
		{
			ShowActivity2(client, ADMINCOMMANDTAG, "%t", "RestrictedAll");
		}
		else
		{
			ShowActivity2(client, ADMINCOMMANDTAG, "%t", "UnrestrictedAll");
		}
		return true;
	}
	else if(!shouldbeall)
	{
		new len = strlen(weapon);
		for(new i = 0; i < len; i++)
		{
			weapon[i] = CharToLower(weapon[i]);
		}
		new WeaponID:id = Restrict_GetWeaponIDExtended(weapon);
		new WeaponType:group = GetTypeGroup(weapon);//For group restrictions.
		if(id == WEAPON_NONE && group == WeaponTypeNone)
		{
			ReplyToCommand(client, "%T", "InvalidWeapon", client);
			return false;
		}
		if(amount != -1)
		{
			if(team == 3 || team == 0)
			{
				if(group == WeaponTypeNone && Restrict_SetRestriction(id, CS_TEAM_CT, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", weaponNames[_:id], "ToAmount", amount, "ForCT");
				else if(id == WEAPON_NONE && Restrict_SetGroupRestriction(group, CS_TEAM_CT, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", g_WeaponGroupNames[_:group], "ToAmount", amount, "ForCT");
			}
			if(team == 2 || team == 0)
			{
				if(group == WeaponTypeNone && Restrict_SetRestriction(id, CS_TEAM_T, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", weaponNames[_:id], "ToAmount", amount, "ForT");
				else if(id == WEAPON_NONE && Restrict_SetGroupRestriction(group, CS_TEAM_T, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", g_WeaponGroupNames[_:group], "ToAmount", amount, "ForT");
			}
		}
		else
		{
			if(team == 3 || team == 0)
			{
				if(group == WeaponTypeNone && Restrict_SetRestriction(id, CS_TEAM_CT, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", weaponNames[_:id], "ForCT");
				else if(id == WEAPON_NONE && Restrict_SetGroupRestriction(group, CS_TEAM_CT, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", g_WeaponGroupNames[_:group], "ForCT");
			}
			if(team == 2 || team == 0)
			{
				if(group == WeaponTypeNone && Restrict_SetRestriction(id, CS_TEAM_T, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", weaponNames[_:id], "ForT");
				else if(id == WEAPON_NONE && Restrict_SetGroupRestriction(group, CS_TEAM_T, amount, true))
					ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", g_WeaponGroupNames[_:group], "ForT");
			}
		}
		return true;
	}
	return false;
}
public Action:RestrictAdminCmd(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "RestrictReply", client);
		return Plugin_Handled;
	}
	decl String:weapon[100];
	GetCmdArg(1, weapon, sizeof(weapon));
	if(args == 1)
	{
		if(!HandleRestrictionCommand(client, weapon, _, 0, true))
			ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "RestrictReply", client);
		return Plugin_Handled;
	}
	new amount = 0;
	if(args >= 2)
	{
		decl String:amountString[5];
		GetCmdArg(2, amountString, sizeof(amountString));
		amount = StringToInt(amountString);
		if((amount == 0 && !StrEqual(amountString, "0")) || amount < -1)
		{
			ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "InvalidAmount", client);
			return Plugin_Handled;
		}
	}
	new teams = 0;
	if(args == 3)
	{
		decl String:team[10];
		GetCmdArg(3, team, sizeof(team));
		if(StrEqual(team, "both", false))
			teams = 0;
		else if(StrEqual(team, "ct", false))
			teams = CS_TEAM_CT;
		else if(StrEqual(team, "t", false))
			teams = CS_TEAM_T;
		else
		{
			ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "InvalidTeam", client);
			return Plugin_Handled;
		}
	}
	HandleRestrictionCommand(client, weapon, teams, amount, false);
	return Plugin_Handled;
}
public Action:UnrestrictAdminCmd(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "UnrestrictReply", client);
		return Plugin_Handled;
	}
	decl String:weapon[100];
	GetCmdArg(1, weapon, sizeof(weapon));
	if(args == 1)
	{
		if(!HandleRestrictionCommand(client, weapon, _, -1, true) && !HandleRestrictionCommand(client, weapon, 0, -1, false))
			ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "UnrestrictReply", client);
		return Plugin_Handled;
	}
	new teams = 0;
	if(args == 2)
	{
		decl String:team[10];
		GetCmdArg(2, team, sizeof(team));
		if(StrEqual(team, "both", false))
			teams = 0;
		else if(StrEqual(team, "ct", false))
			teams = CS_TEAM_CT;
		else if(StrEqual(team, "t", false))
			teams = CS_TEAM_T;
		else
		{
			ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "InvalidTeam", client);
			return Plugin_Handled;
		}
	}
	HandleRestrictionCommand(client, weapon, teams, -1, false);
	return Plugin_Handled;
}
public Action:DropC4(client, args)
{
	new bomb = -1;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != CS_TEAM_T)
			continue;
		
		if((bomb = GetPlayerWeaponSlot(i, _:SlotC4)) != -1)
		{
			CS_DropWeapon(i, bomb, true, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t", "ForcedBombDrop");
			LogAction(client, -1, "\"%L\" forced the C4 bomb to be dropped.", client);
			return Plugin_Handled;
		}
	}
	ReplyToCommand(client, "%T", "NoOneHasBomb", client);
	return Plugin_Handled;
}
public Action:KnifeRound(client, args)
{
	if(g_nextRoundSpecial != RoundType_None)
	{
		ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "SpecialRoundAlreadySet", client);
		return Plugin_Handled;
	}
	ShowActivity2(client, ADMINCOMMANDTAG, "%t", "KnivesRoundSetup");
	LogAction(client, -1, "\"%L\" setup a knives only round for the next round.", client);	
	g_nextRoundSpecial = RoundType_Knife;
	return Plugin_Handled;
}
public Action:PistolRound(client, args)
{
	if(g_nextRoundSpecial != RoundType_None)
	{
		ReplyToCommand(client, "\x01\x0B\x04[SM] %T", "SpecialRoundAlreadySet", client);
		return Plugin_Handled;
	}
	ShowActivity2(client, ADMINCOMMANDTAG, "%t", "PistolRoundSetup");
	LogAction(client, -1, "\"%L\" setup a pistol round for the next round.", client);	
	g_nextRoundSpecial = RoundType_Pistol;
	return Plugin_Handled;
}
public Action:ReloadRestrict(client, args)
{
	ClearOverride();
	CreateTimer(0.1, LateLoadExec, _, TIMER_FLAG_NO_MAPCHANGE);
	ShowActivity2(client, ADMINCOMMANDTAG, "%t", "ReloadedRestricitions");
	LogAction(client, -1, "\"%L\" reloaded the restrictions.", client);
	#if defined CONFIGLOADER
	CheckConfig();
	#endif
	#if defined PERPLAYER
	PerPlayerInit();
	CheckPerPlayer();
	#endif
	return Plugin_Handled;
}