#include <sourcemod>
#pragma semicolon 1

public Plugin:myinfo =
{
    name = "Toggle Viewmodel",
    author = "grimAuxiliatrix",
    description = "Toggle Weapon Visibility",
    version = "1.0.1",
    url = "http://www.reflex-gamers.com"
};

public OnPluginStart()
{
    RegAdminCmd("sm_invis", Command_Invis, 0, "Type to toggle weapon visibility.");
    RegAdminCmd("sm_invisible", Command_Invis, 0, "Type to toggle weapon visibility.");
}

public Action:Command_Invis(client, args)
{
	if (!IsPlayerAlive(client))
	{
		// print to chat if player is dead
		ReplyToCommand(client, "[TF2Items] Cannot use command while dead.");
		return Plugin_Handled;
	}
	decl String:classname[32];
	new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		// print to chat if player does not have an active weapon
		ReplyToCommand(client, "[TF2Items] You don't have an active weapon to make invisible!");
		return Plugin_Handled;
	}
	if (GetEntityClassname(entity, classname, sizeof(classname)) && strncmp(classname, "tf_weapon_", 10, false) == 0)
	{
		// if weapon is invisible, make visible
		if (GetEntityRenderMode(entity) == RENDER_NONE)
		{
			SetEntityRenderMode(entity, RENDER_NORMAL); 
			SetEntityRenderColor(entity, 255, 255, 255, 255);
			ReplyToCommand(client, "[TF2Items]Randomizer: Made your active weapon fully visible.");
		}
		// if weapon is visible, make invisible
		else
		{
			SetEntityRenderMode(entity, RENDER_NONE);
			SetEntityRenderColor(entity, 0, 0, 0, 0);
			ReplyToCommand(client, "[TF2Items]Randomizer: Made your active weapon invisible.");
		}
	}
	return Plugin_Handled;
}