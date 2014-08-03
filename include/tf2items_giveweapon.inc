#if defined _tf2items_giveweapon_included
  #endinput
#endif
#define _tf2items_giveweapon_included

/**
 * Gives a client a weapon by weapon index.
 *
 * @param client			Client Index. Does an alive/in-game/valid check.
 * @param weaponIndex		Item Definition Index of weapon being given. Also works with custom weapons.
 * @return					Entity index of given weapon.
 * @error					Invalid/dead client, or weaponIndex not found.
 */
native TF2Items_GiveWeapon(client, weaponIndex);

/**
 * Creates a trie entry for a new weapon.
 *
 * @param desiredIndex		Desired weapon index of your weapon.
 * @param classname			Weapon classname (tf_weapon_*) to base the new weapon on.
 * @param weaponIndex		Index of weapon to base the new weapon on. Make sure it matches with classname.
 * @param weaponSlot		Slot the weapon goes to/clears to make room for.
 * @param weaponQuality		Quality of weapon. Look at the top of items_game.txt or the TF2Items thread for these.
 * @param weaponLevel		Level of weapon, must be between 0 and 127.
 * @param weaponAttribs		The attributes of the weapon, formatted "attribute index ; attribute value ; attribute index ; attribute value". Default is empty.
 * @param weaponAmmo		Optional to set the amount of ammo given to the weapon slot on give.
 * @param weaponModel		IF you are using VisWeps, then define this to a model like models/advancedweaponiser/w_sickle_sniper.mdl. It will try to precache it. Default is empty.
 * @param overwrite			If true (default is false), if the desired index is already defined, it overwrites those trie values with these.
								ONLY USE THIS TO REDEFINE A WEAPON YOU CREATED, NOT TO REDEFINE A WEAPON THAT EXISTS WITHIN THE PLUGIN BY DEFAULT.
								IT WILL BREAK A LOT OF STUFF.
 * @noreturn
 */
native TF2Items_CreateWeapon(desiredIndex, const String:classname[], weaponIndex, weaponSlot, weaponQuality, weaponLevel, const String:weaponAttribs[] = "", weaponAmmo = -1, const String:weaponModel[] = "", bool:overwrite = false);

/**
 * Checks if a weapon is in the trie.
 *
 * @param weaponIndex		Index to check.
 * @return				True if it's there, false if not.
 */
native bool:TF2Items_CheckWeapon(weaponIndex);

/**
 * Checks a weapon's slot in the trie.
 *
 * @param weaponIndex		Index to check.
 * @return				Slot of the weapon.
 * @error				(If index does not exist) "[TF2Items] Weapon %d does not exist"
 */
native TF2Items_CheckWeaponSlot(weaponIndex);

public SharedPlugin:__pl_tf2items_giveweapon = 
{
	name = "tf2items_giveweapon",
	file = "tf2items_giveweapon.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_tf2items_giveweapon_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Items_GiveWeapon");
	MarkNativeAsOptional("TF2Items_CreateWeapon");
	MarkNativeAsOptional("TF2Items_CheckWeapon");
	MarkNativeAsOptional("TF2Items_CheckWeaponSlot");
}
#endif