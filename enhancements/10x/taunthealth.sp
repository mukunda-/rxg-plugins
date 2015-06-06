#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgtfcommon>
#include <rxgcommon>

public Plugin myinfo = 
{
	name = "Taunt Health",
	author = "Roker",
	description = "Taunting with specified weapon returns players health.",
	version = "1.0",
	url = "www.reflex-gamers.com."
};

int validWeapons[] =  { 42 };

//-----------------------------------------------------------------------------
public TF2_OnConditionAdded(int client, TFCond condition){
	if (condition != TFCond_Taunting) { return;}
	if (!IntArrayContains(GetActiveIndex(client), validWeapons, sizeof(validWeapons))) { return;}
	
	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
	SetEntityHealth(client, maxHealth);
}