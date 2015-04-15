#if defined _FLASHMOD_INCLUDED
  #endinput
#endif
#define _FLASHMOD_INCLUDED

/** ---------------------------------------------------------------------------
 * Called when a player flashers another player.
 *
 * @param flasher  The client that used the flashbang.
 * @param flashee  The client that was flashed.
 * @param alpha    The m_flFlashMaxAlpha value.
 * @param duration The m_flFlashDuration value, or the duration that they were
 *                 flashed (seconds).
 *
 * Return Plugin_Continue for normal behavior, if you change alpha or duration
 * in the callback, return Plugin_Changed for them to take effect.
 */
forward Action Flashmod_OnPlayerFlashed( int flasher, int flashee, 
                                         float &alpha, float &duration );

/** ---------------------------------------------------------------------------
 * Called when a player flashes their teammate(s).
 *
 * @param flasher The client that used the flashbang.
 *
 * @param num_teammates_flashed The number of teammates that were flashed.
 *                              There is a minimum duration threshold that
 *                              must be met to be considered a team flash.
 */
forward void Flashmod_OnPlayerTeamflash( int flasher, 
                                         int num_teammates_flashed );

/** ---------------------------------------------------------------------------
 * Called after processing a flashbang detonation.
 *
 * @param flasher         The client that threw the flashbang.
 * @param enemies_flashed The number of enemies that were flashed.
 * @param team_flashed    The number of teammates that were flashed.
 *
 * @param enemies_duration_sum The sum of the number of seconds that each
 *                             enemy was flashed for.
 * @param team_duration_sum    The nsum of the number of seconds that each
 *                             teammate was flashed for.
 */
forward void Flashmod_FlashbangStats( int flasher, int enemies_flashed, 
                                      int team_flashed, float enemies_duration_sum, 
                                      float team_duration_sum );
