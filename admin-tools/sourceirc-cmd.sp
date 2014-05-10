// ServerCommand plugin

#undef REQUIRE_PLUGIN
#include <sourceirc>

#pragma semicolon 1

public Plugin:myinfo = {
	name = "SourceIRC -> CMD",
	author = "mukunda",
	description = "Allows you to run server commands",
	version = "1.0.0",
	url = "peepee"
};

public OnAllPluginsLoaded() {
	if (LibraryExists("sourceirc"))
		IRC_Loaded();
}

public OnLibraryAdded(const String:name[]) {
	if (StrEqual(name, "sourceirc"))
		IRC_Loaded();
}

IRC_Loaded() {
	IRC_CleanUp(); // Call IRC_CleanUp as this function can be called more than once.
	IRC_RegAdminCmd("cmd", Command_CMD, ADMFLAG_RCON, "cmd <command> - Run a command on the server.");
}

public Action:Command_CMD(const String:nick[], args) {
	decl String:cmd[256];
	IRC_GetCmdArgString( cmd, sizeof(cmd) );
	IRC_ReplyToCommand( nick, "Running command: %s", cmd );
	ServerCommand(cmd);
	return Plugin_Handled;
}

public OnPluginEnd() { IRC_CleanUp(); }
