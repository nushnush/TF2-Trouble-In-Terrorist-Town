UserMsg g_EarthquakeMsgId;

#define SOUND_EARTHQUAKE "ambient/atmosphere/terrain_rumble1.wav"
#define SOUND_RESPAWN "ui/halloween_boss_summoned_monoculus.wav"

stock void Necromancer_OnMapStart()
{
	PrecacheSound(SOUND_EARTHQUAKE, true);
	PrecacheSound(SOUND_RESPAWN, true);
	g_EarthquakeMsgId = GetUserMessageId("Shake");
}

stock void PerformEarthquakes()
{
	int[] clients = new int[MaxClients];
	int clientCount;
	
	for (int i = 1; i <= MaxClients; i++)  
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && (INNOCENT <= TTTPlayer(i).role <= DETECTIVE))
		{
			clients[clientCount++] = i;
			EmitSoundToAll(SOUND_EARTHQUAKE, i);
		}
	}
	
	Handle hMsg = StartMessageEx(g_EarthquakeMsgId, clients, clientCount);
	if (hMsg != INVALID_HANDLE)
	{
		BfWriteByte(hMsg, 0);
		BfWriteFloat(hMsg, 45.0); // amplitude
		BfWriteFloat(hMsg, 45.0); // frequency
		BfWriteFloat(hMsg, 25.0); // duration
		EndMessage();
	}

	CPrintToChatAll("%s {fullred}BEWARE:{default} The %s has cast some earthquakes!", TAG, g_sRoles[NECROMANCER]);
}

stock void PerformResurrect()
{
	int client = GetRandomPlayer(TRAITOR, true);
	if(client == -1)
		return;

	TF2_ChangeClientTeam(client, TFTeam_Red);
	TF2_RespawnPlayer(client);
	TTTPlayer(client).Setup();
	EmitSoundToAll(SOUND_RESPAWN, _, _, SNDLEVEL_RAIDSIREN);
}