#include <sourcemod>
#include <sdktools>
#include <rxgtfcommon>
#include <weblink>

public Plugin myinfo =
{
    name = "MOTD Weapon List",
    author = "Roker",
    description = "Opens MOTD with Mayhem Weapon list",
    version = "1.2.1",
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
    WEBLINK_OpenUrl(client, "https://weaponlist.reflex-gamers.com/weaponlist/pages/home-game");
    return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public Action viewLoadout(client,args) {
	int loadout[4];
	GetLoadout(client, loadout);
	
	char url[128];
	Format(url, sizeof(url), "https://weaponlist.reflex-gamers.com/weaponlist/pages/view-weapons/%i/%i/%i/%i", loadout[0], loadout[1] , loadout[2], loadout[3]);
	WEBLINK_OpenUrl(client, url);
	return Plugin_Handled;
}
