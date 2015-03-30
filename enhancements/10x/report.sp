#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
    name = "Report",
    author = "Roker",
    description = "Opens MOTD with help desk of forums.",
    version = "1.0.0",
    url = "http://www.reflex-gamers.com"
}
public OnPluginStart()
{
    RegConsoleCmd("sm_report", report, 	"Type to go to help desk on forums.");
    //RegConsoleCmd("sm_admin", report, 		"Type to go to help desk on forums.");
}

//Displays WEAPON LIST
public Action:report(client,args) {
    ShowMOTDPanel(client, "Report", "http://reflex-gamers.com/forumdisplay.php?f=35", MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}