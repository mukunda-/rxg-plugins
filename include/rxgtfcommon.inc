stock GetActiveIndex(int iClient)
{
    return GetWeaponIndex(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"));
}
stock GetWeaponIndex(int iWeapon)
{
    return IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}
stock GetClassID(int pClass)
{
    switch(pClass){
    	case 3: 
    	return 2;//soldier
    	case 7:
    	return 3;//pyro
    	case 6:
    	return 5;//heavy
    	case 9:
    	return 6;//engi
    	case 5:
    	return 7;//medic
    	case 2:
    	return 8;//sniper
    	case 8:
    	return 9;//spy
    	default:
    	return pClass; //scout, demo, unknown
    }
    return pClass;
}

//-------------------------------------------------------------------------------------------------
stock FindDemoShield(int iClient)
{
	//int index = ( IsValidEntity(shield) ? GetEntProp( shield, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
    int iEnt = MaxClients + 1; while ((iEnt = FindEntityByClassname2(iEnt, "tf_wearable_demoshield")) != -1)
    {
        if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(iEnt, Prop_Send, "m_bDisguiseWearable"))
        {
            return iEnt;
        }
    }
    return -1;
}

//-------------------------------------------------------------------------------------------------
stock int FindEntityByClassname2(startEnt, const String:classname[])
{
    /* If startEnt isn't valid shifting it back to the nearest valid one */
    while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
    return FindEntityByClassname(startEnt, classname);
}

//-----------------------------------------------------------------------------
stock void GetLoadout(int client, int loadout[4]){
	for(int i=0; i<sizeof loadout; i++){
		int weapon = GetPlayerWeaponSlot(client, i);
		
		if(!IsValidEntity(weapon)){
			if(i == 1){
				weapon = FindDemoShield(client);
			}
		}
		
		if(!IsValidEntity(weapon)){
			loadout[i] = -1;
		}else{
			loadout[i] = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
		}
	}
}