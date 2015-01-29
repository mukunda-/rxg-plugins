new g_iMenuAmount[MAXPLAYERS+1];
new WeaponID:g_iWeaponSlected[MAXPLAYERS+1];
new WeaponType:g_iGroupSelected[MAXPLAYERS+1];
new bool:g_bIsGroup[MAXPLAYERS+1];
new bool:g_bIsUnrestrict[MAXPLAYERS+1];
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu")) 
	{
		hAdminMenu = INVALID_HANDLE;
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;
	
	new TopMenuObject:menu = FindTopMenuCategory(hAdminMenu, "restrict");
	
	if (menu == INVALID_TOPMENUOBJECT)
	{
		menu = AddToTopMenu(
		hAdminMenu,		// Menu
		"restrict",		// Name
		TopMenuObject_Category,	// Type
		Handle_Category,	// Callback
		INVALID_TOPMENUOBJECT	// Parent
		);
	}
	
	AddToTopMenu(hAdminMenu, "sm_restrict", TopMenuObject_Item, AdminMenu_Restrict, menu, "sm_restrict", ADMFLAG_CONVARS);
	AddToTopMenu(hAdminMenu, "sm_unrestrict", TopMenuObject_Item, AdminMenu_Unrestrict, menu, "sm_unrestrict", ADMFLAG_CONVARS);
	AddToTopMenu(hAdminMenu, "sm_dropc4", TopMenuObject_Item, AdminMenu_dropc4, menu, "sm_dropc4", ADMFLAG_BAN);
	AddToTopMenu(hAdminMenu, "sm_knives", TopMenuObject_Item, AdminMenu_Knives, menu, "sm_knives", ADMFLAG_CONVARS);
	AddToTopMenu(hAdminMenu, "sm_pistols", TopMenuObject_Item, AdminMenu_Pistols, menu, "sm_pistols", ADMFLAG_CONVARS);
}
public Handle_Category(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength )
{
	switch(action)
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "%T", "RestrictMenuMainTitle", param);
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "RestrictMenuMainOption", param);
	}
}
public AdminMenu_Restrict(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id,param, String:buffer[], maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "RestrictWeaponsOption", param);
		case TopMenuAction_SelectOption:
		{
			g_bIsUnrestrict[param] = false;
			DisplayTypeMenu(param);
		}
	}
}
public AdminMenu_Unrestrict(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id,param, String:buffer[], maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "UnrestrictWeaponsOption", param);
		case TopMenuAction_SelectOption:
		{
			g_bIsUnrestrict[param] = true;
			g_iMenuAmount[param] = -1;
			DisplayTypeMenu(param);
		}
	}
}
public AdminMenu_dropc4(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id,param, String:buffer[], maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "ForceBombDropOption", param);
		case TopMenuAction_SelectOption:
			DropC4(param, 0);
	}
}
public AdminMenu_Knives(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id,param, String:buffer[], maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "SetupKnivesOption", param);
		case TopMenuAction_SelectOption:
			KnifeRound(param, 0);
	}
}
public AdminMenu_Pistols(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id,param, String:buffer[], maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "SetupPistolsOption", param);
		case TopMenuAction_SelectOption:
			PistolRound(param, 0);
	}
}
DisplayTypeMenu(client)
{
	new Handle:menu = CreateMenu(Handle_TypeMenu);
	
	decl String:title[64];
	
	Format(title, sizeof(title), "%T", "RestrictionTypeMenuTitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	Format(title, sizeof(title), "%T", "TypeWeaponRestrict", client);
	AddMenuItem(menu, "0", title);
	Format(title, sizeof(title), "%T", "TypeGroupRestrict", client);
	AddMenuItem(menu, "1", title);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public Handle_TypeMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
		case MenuAction_Select:
		{
			decl String:type[5];
			GetMenuItem(menu, param2, type, sizeof(type));
			g_bIsGroup[param1] = bool:StringToInt(type);
			DisplayRestrictMenu(param1);
		}
	}
}
DisplayRestrictMenu(client)
{
	new Handle:menu = CreateMenu(Handle_WeaponMenu);
	
	decl String:title[64];
	
	if(!g_bIsUnrestrict[client])
		Format(title, sizeof(title), "%T", "RestrictMenuTitle", client);
	else
		Format(title, sizeof(title), "%T", "UnrestrictMenuTitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	if(g_bIsGroup[client])
		AddGroupsToMenu(menu, client);
	else
		AddWeaponsToMenu(menu, client);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public Handle_WeaponMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
				DisplayTypeMenu(param1);
		}
		case MenuAction_Select:
		{
			decl String:weapon[WEAPONARRAYSIZE];
			GetMenuItem(menu, param2, weapon, sizeof(weapon));
			if(g_bIsGroup[param1])
				g_iGroupSelected[param1] = GetTypeGroup(weapon);
			else
				g_iWeaponSlected[param1] = GetWeaponID(weapon);
		
			if(g_bIsGroup[param1] && g_bIsUnrestrict[param1])
			{
				DisplayTeamMenu(param1);
			}
			else if(!g_bIsUnrestrict[param1])
			{
				DisplayAmountMenu(param1);
			}
			else
			{
				switch(g_iWeaponSlected[param1])
				{
					case WEAPON_C4:
						HandleMenuRestriction(param1, WEAPON_C4, -1, CS_TEAM_T);
					case WEAPON_DEFUSER:
						HandleMenuRestriction(param1, WEAPON_DEFUSER, -1, CS_TEAM_CT);
					default:
						DisplayTeamMenu(param1);
				}
			}
		}
	}
}
DisplayAmountMenu(client)
{
	new Handle:menu = CreateMenu(Handle_AmountMenu);
	
	decl String:title[64];
	
	Format(title, sizeof(title), "%T", "AmountMenuTitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	decl String:num[5];
	for(new i = 0; i <= MaxClients; i++)
	{
		Format(num, sizeof(num), "%i", i);
		AddMenuItem(menu, num, num);
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
DisplayTeamMenu(client)
{
	new Handle:menu = CreateMenu(Handle_TeamMenu);
	
	decl String:title[64];
	
	Format(title, sizeof(title), "%T", "SelectTeamMenuTitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	Format(title, sizeof(title), "%T", "CounterTerrorists", client);
	AddMenuItem(menu, "3", title);
	
	Format(title, sizeof(title), "%T", "Terrorists", client);
	AddMenuItem(menu, "2", title);
	
	Format(title, sizeof(title), "%T", "Allteams", client);
	AddMenuItem(menu, "0", title);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public Handle_TeamMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				if(!g_bIsUnrestrict[param1])
					DisplayAmountMenu(param1);
				else
					DisplayRestrictMenu(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sTeam[5];
			GetMenuItem(menu, param2, sTeam, sizeof(sTeam));
			new team = StringToInt(sTeam);
			if(!g_bIsGroup[param1])
				HandleMenuRestriction(param1, g_iWeaponSlected[param1], g_iMenuAmount[param1], team);
			else
				HandleMenuGroupRestriction(param1, g_iGroupSelected[param1], g_iMenuAmount[param1], team);
		}
	}
}
public Handle_AmountMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
				DisplayRestrictMenu(param1);
		}
		case MenuAction_Select:
		{
			decl String:amount[10];
			GetMenuItem(menu, param2, amount, sizeof(amount));
			g_iMenuAmount[param1] = StringToInt(amount);
			switch(g_iWeaponSlected[param1])
			{
				case WEAPON_C4:
					HandleMenuRestriction(param1, WEAPON_C4, g_iMenuAmount[param1], CS_TEAM_T);
				case WEAPON_DEFUSER:
					HandleMenuRestriction(param1, WEAPON_DEFUSER, g_iMenuAmount[param1], CS_TEAM_CT);
				default:
					DisplayTeamMenu(param1);
			}
		}
	}
}
stock HandleMenuRestriction(client, WeaponID:id, amount, team)
{
	if(amount != -1)
	{
		if(team == 3 || team == 0)
		{
			Restrict_SetRestriction(id, CS_TEAM_CT, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", weaponNames[_:id], "ToAmount", amount, "ForCT");
		}
		if(team == 2 || team == 0)
		{
			Restrict_SetRestriction(id, CS_TEAM_T, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", weaponNames[_:id], "ToAmount", amount, "ForT");
		}
	}
	else
	{
		if(team == 3 || team == 0)
		{
			Restrict_SetRestriction(id, CS_TEAM_CT, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", weaponNames[_:id], "ForCT");
		}
		if(team == 2 || team == 0)
		{
			Restrict_SetRestriction(id, CS_TEAM_T, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", weaponNames[_:id], "ForT");
		}
	}
}
stock HandleMenuGroupRestriction(client, WeaponType:group, amount, team)
{
	if(group == WeaponTypeNone)
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
		return;
	}
	if(amount != -1)
	{
		if(team == 3 || team == 0)
		{
			Restrict_SetGroupRestriction(group, CS_TEAM_CT, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", g_WeaponGroupNames[_:group], "ToAmount", amount, "ForCT");
		}
		if(team == 2 || team == 0)
		{
			Restrict_SetGroupRestriction(group, CS_TEAM_T, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t %t", "RestrictedCmd", g_WeaponGroupNames[_:group], "ToAmount", amount, "ForT");
		}
	}
	else
	{
		if(team == 3 || team == 0)
		{
			Restrict_SetGroupRestriction(group, CS_TEAM_CT, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", g_WeaponGroupNames[_:group], "ForCT");
		}
		if(team == 2 || team == 0)
		{
			Restrict_SetGroupRestriction(group, CS_TEAM_T, amount, true);
			ShowActivity2(client, ADMINCOMMANDTAG, "%t %t %t", "UnrestrictedCmd", g_WeaponGroupNames[_:group], "ForT");
		}
	}
}
AddGroupsToMenu(Handle:menu, client)
{
	decl String:weaponArray[MAXWEAPONGROUPS][WEAPONARRAYSIZE];
	new size;
	
	for(new i = 0; i < MAXWEAPONGROUPS; i++)
	{
		strcopy(weaponArray[size], WEAPONARRAYSIZE, g_WeaponGroupNames[i]);
		size++;
	}
	SortStrings(weaponArray, size-1, Sort_Ascending);
	
	decl String:weapon[WEAPONARRAYSIZE];
	Format(weapon, sizeof(weapon), "%T", "AllWeapons", client);
	AddMenuItem(menu, "all", weapon);
	
	for(new i = 0; i < size-1; i++)
	{
		Format(weapon, sizeof(weapon), "%T", weaponArray[i], client); 
		AddMenuItem(menu, weaponArray[i], weapon);
	}
}
AddWeaponsToMenu(Handle:menu, client)
{
	new int = _:WeaponID;
	decl String:weaponArray[int][WEAPONARRAYSIZE];
	new size;
	
	for(new i = 0; i < _:WeaponID; i++)
	{
		if(WeaponID:i == WEAPON_NONE || WeaponID:i == WEAPON_SHIELD)
			continue;
		
		strcopy(weaponArray[size], WEAPONARRAYSIZE, weaponNames[WeaponID:i]);
		size++;
	}
	SortStrings(weaponArray, size-1, Sort_Ascending);
	decl String:weapon[WEAPONARRAYSIZE];
	for(new i = 0; i < size-1; i++)
	{
		Format(weapon, sizeof(weapon), "%T", weaponArray[i], client); 
		AddMenuItem(menu, weaponArray[i], weapon);
	}
}