/*
**
*/
#if defined _jailbreak_included
 #endinput
#endif
#define _jailbreak_included


/** ---------------------------------------------------------------------------
 * Register a LR.
 *
 *
 *   void JB_Selected( int client )
 *
 * for when the item is being used by the client. Return true to delete
 * one of the item in the clients inventory, or false if the client cannot
 * use the item at that time.
 *
 * @param name     Name of last request.
 *
 * @noreturn
 */
native bool JB_RegisterLastRequest( const char[] name );