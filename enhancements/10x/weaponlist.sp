#include <sourcemod>
#include <sdktools>
#include <rxgtfcommon>

public Plugin myinfo =
{
    name = "MOTD Weapon List",
    author = "Roker",
    description = "Opens MOTD with Mayhem Weapon list",
    version = "1.1.0",
    url = "http://www.reflex-gamers.com"
}
public OnPluginStart()
{
    RegConsoleCmd("sm_weapons", viewList, "Type to view weapon list.");
    RegConsoleCmd("sm_weaponlist", viewList, "Type to view weapon list.");
    RegConsoleCmd("sm_list", viewList, "Type to view weapon list.");
    
    RegConsoleCmd("sm_loadout", viewLoadout, "Type to view weapon list.");
    RegConsoleCmd("sm_mywep", viewLoadout, "Type to view weapon list.");
}

//Displays WEAPON LIST
public Action viewList(client,args) {
    ShowMOTDPanel(client, "WeaponList", "http://reflex-gamers.com/weaponlist/pages/home-game", MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action viewLoadout(client,args) {
	int loadout[4];
	GetLoadout(client, loadout);
	
	char url[128];
	Format(url, sizeof(url), "http://reflex-gamers.com/weaponlist/pages/view-weapons/%i/%i/%i/%i", loadout[0], loadout[1] , loadout[2], loadout[3]);
	ShowMOTDPanel(client, "Loadout", url , MOTDPANEL_TYPE_URL);
	return Plugin_Handled;
}
