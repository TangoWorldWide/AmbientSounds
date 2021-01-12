#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

// Server variables.
bool g_bLateLoaded;
Handle g_hAmbientSounds;

// Client variables.
bool g_bAmbientSounds[MAXPLAYERS + 1] = {true, ...};

public Plugin myinfo = {
	name = "Ambient Sounds",
	author = "Adam",
	description = "Allow clients to toggle ambient sounds.",
	version = "1.0",
	url = "https://tangoworldwide.net"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// All the aliases!
	RegConsoleCmd("sm_mapsound", SM_AmbientSounds);
	RegConsoleCmd("sm_mapmusic", SM_AmbientSounds);
	RegConsoleCmd("sm_stopmusic", SM_AmbientSounds);
	RegConsoleCmd("sm_stopsound", SM_AmbientSounds);

	// Store players' preferences.
	g_hAmbientSounds = RegClientCookie("ambient-sounds", "", CookieAccess_Private);

	AddAmbientSoundHook(SoundHook_Ambient);
}

public void OnAllPluginsLoaded()
{
	if (!g_bLateLoaded)
		return;

	// Can this forward be called more than once?
	g_bLateLoaded = false;

	// Support late-loading.
	for (int i = 1; i <= MaxClients; i++)
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
}

public void OnClientCookiesCached(int client)
{
	char sValue[2];
	GetClientCookie(client, g_hAmbientSounds, sValue, sizeof(sValue));

	// It's unset on first join.
	if(sValue[0] == '\0')
	{
		sValue = "1";
		SetClientCookie(client, g_hAmbientSounds, sValue);
	}

	g_bAmbientSounds[client] = view_as<bool>(StringToInt(sValue));
	if (!g_bAmbientSounds[client])
		StopAllExceptMusic(client);
}

public void OnClientDisconnect(int client)
{
	g_bAmbientSounds[client] = true;
}

/**
 * Command callbacks.
 */
public Action SM_AmbientSounds(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	g_bAmbientSounds[client] = !g_bAmbientSounds[client];

	// Update their stored preference if possible.
	if(AreClientCookiesCached(client))
		SetClientCookie(client, g_hAmbientSounds, g_bAmbientSounds[client] ? "1" : "0");

	// Try and a stop a currently playing sound immediately.
	if (!g_bAmbientSounds[client])
		StopAllExceptMusic(client);

	ReplyToCommand(client, "[SM] Ambient sounds %s\x01.", g_bAmbientSounds[client] ? "\x05unmuted" : "\x0Fmuted");
	return Plugin_Handled;
}

/**
 * SoundHook callbacks.
 */
public Action SoundHook_Ambient(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	// Simulate a post hook.
	RequestFrame(Frame_AfterAmbientSound);
	return Plugin_Continue;
}

/**
 * RequestFrame callbacks.
 */
public void Frame_AfterAmbientSound(any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		// Check if this index has ambient sounds disabled first.
		if (g_bAmbientSounds[i])
			continue;

		// No out-of-game or bot clients.
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		StopAllExceptMusic(i);
	}
}

/**
 * Helpers.
 */
void StopAllExceptMusic(int client)
{
	ClientCommand(client, "playgamesound Music.StopAllExceptMusic");
}
