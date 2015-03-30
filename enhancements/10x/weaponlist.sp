#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
    name = "MOTD Weapon List",
    author = "Roker",
    description = "Opens MOTD with Mayhem Weapon list",
    version = "1.0.1",
    url = "http://www.reflex-gamers.com"
}
public OnPluginStart()
{
    RegConsoleCmd("sm_weapons", list, "Type to view weapon list.");
    RegConsoleCmd("sm_weaponlist", list, "Type to view weapon list.");
    RegConsoleCmd("sm_list", list, "Type to view weapon list.");
}

//Displays WEAPON LIST
public Action:list(client,args) {
    ShowMOTDPanel(client, "WeaponList", "http://reflex-gamers.com/cmps_index.php?pageid=weaponlist", MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}