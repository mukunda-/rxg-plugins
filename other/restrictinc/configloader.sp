//Config loader. Loads configs for specific map or prefix.
CheckConfig()
{
	decl String:file[PLATFORM_MAX_PATH];
	decl String:map[64];
	decl String:pref[10];
	GetCurrentMapEx(map, sizeof(map));
	BuildPath(Path_SM, file, sizeof(file), "configs/restrict/%s.cfg", map);
	if(!RunFile(file))
	{
		SplitString(map, "_", pref, sizeof(pref));
		BuildPath(Path_SM, file, sizeof(file), "configs/restrict/%s_.cfg", pref);
		RunFile(file);
	}
}