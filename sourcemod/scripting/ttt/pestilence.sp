stock void Pestilence_FindTarget(int client)
{
	float pos[3], targetPos[3], distance;
	GetClientEyePosition(client, pos);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && i != client)
		{
			GetClientEyePosition(i, targetPos);
			distance = GetVectorDistance(targetPos, pos);
			if (distance <= 50.0)
			{
				g_iLastTouched[client] = i;
				break;
			}
		}
	}
}

stock void PerformInfection(const TTTPlayer player)
{
	int client = player.index;

	ForcePlayerSuicide(g_iLastTouched[client]);
	TTTPlayer(g_iLastTouched[client]).killerRole = PESTILENCE;
	g_iLastTouched[client] = 0;
	player.killCount++;
	
	if(player.killCount == g_cvExposeCount.IntValue)
	{
		CPrintToChatAll("%s The %s is %N! Hunt him down.", TAG, g_sRoles[PESTILENCE], client);
	}
}