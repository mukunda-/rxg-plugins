#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Mayhem Manager",
	author = "Roker",
	description = "Manages the 10x plugins.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

Handle sm_mayhem_enabled;

public void OnPluginStart(){
	sm_mayhem_enabled = CreateConVar( "sm_mayhem_enabled", "1", "If mayhem plugins are enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0 );
	HookConVarChange( sm_mayhem_enabled, OnConVarChanged );
	SetPluginsEnabled();
}

public void OnPluginEnd(){
	SetPluginsEnabled();
}

//-------------------------------------------------------------------------------------------------
public void OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval ) {
	PrintToChatAll("%s" , newval);
	SetPluginsEnabled();
}

void SetPluginsEnabled(){
	bool enabled = GetConVarBool(sm_mayhem_enabled);
	
	char path[PLATFORM_MAX_PATH], filename[PLATFORM_MAX_PATH];
	FileType filetype;
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/mayhem");
	
	Handle directory = OpenDirectory(path);
	
	while(ReadDirEntry(directory, filename, PLATFORM_MAX_PATH, filetype)){
		if(filetype==FileType_File && StrContains(filename, ".mayhem", false)!=-1){
			char cmd[6];
			if(enabled){
				cmd = "load";
			}else{
				cmd = "unload";
			}
		
			ServerCommand("sm plugins %s mayhem/%s", cmd, filename);
		}
	}
}