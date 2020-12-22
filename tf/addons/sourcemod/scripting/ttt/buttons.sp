#define MAX_BUTTONS 25
static int g_LastButtons[MAXPLAYERS + 1];

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!g_cvEnabled.BoolValue || !IsValidClient(client))
		return Plugin_Continue;
		
	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);

		if (buttons & button)
		{
			if (!(g_LastButtons[client] & button))
			{
				OnPress(TTTPlayer(client), button);
			}
		}
		else if (g_LastButtons[client] & button)
		{
			OnRelease(TTTPlayer(client), button);
		}
	}

	g_LastButtons[client] = buttons;
	return Plugin_Continue;
}

void OnPress(const TTTPlayer player, int button)
{
	int client = player.index;

	if (g_eRound != Round_Active || !IsPlayerAlive(client))
		return;

	if (button == IN_RELOAD)	// Body Scan - All Roles
	{
		if (!IsPlayerAlive(client))
			return;

		int target = GetClientAimTarget(client, false);
		if (target == -1)
			return;

		char name[64];
		GetEntPropString(target, Prop_Data, "m_iName", name, sizeof(name));
		float origin[3], clientOrigin[3];
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", origin);	// Position of the body
		GetClientAbsOrigin(client, clientOrigin);

		if (GetVectorDistance(origin, clientOrigin) >= 300.0)
			return;

		if (StrEqual(name, "deadbody") || StrEqual(name, "fakebody"))
		{
			TTTPlayer other = TTTPlayer(GetEntPropEnt(target, Prop_Data, "m_hOwnerEntity"));
			if (other.killerRole == PESTILENCE)
			{
				CPrintToChat(client, "%s {community}%N{default} the %s was killed by the %s, %0.1f seconds ago.",
					TAG, other.index, g_sRoles[other.role], g_sRoles[PESTILENCE], GetEngineTime() - other.deathTime);
			}
			else
			{
				CPrintToChat(client, "%s {community}%N{default} was %s and died %0.1f seconds ago.",
					TAG, other.index, g_sRoles[other.role], GetEngineTime() - other.deathTime);
			}
		}
		else if (StrEqual(name, "explosivebody"))
		{
			int iBomb = CreateEntityByName("tf_generic_bomb");
			DispatchKeyValueVector(iBomb, "origin", origin);
			DispatchKeyValueFloat(iBomb, "damage", 500.0);
			DispatchKeyValueFloat(iBomb, "radius", 500.0);
			DispatchKeyValue(iBomb, "health", "1");
			DispatchKeyValue(iBomb, "explode_particle", "fireSmokeExplosion2");
			DispatchKeyValue(iBomb, "sound", "vo/null.mp3");
			DispatchSpawn(iBomb);
			AcceptEntityInput(iBomb, "Detonate");

			AcceptEntityInput(target, "Kill");
		}
	}
	else if (player.role == TRAITOR)
	{
		Traitor_OnRunCmd(player, button);
	}
	else if (player.role == DETECTIVE)
	{
		Detective_OnRunCmd(player, button);
	}
	else if (player.role == DISGUISER)
	{
		Disguiser_OnRunCmd(player, button);
	}
	else if (player.role == NECROMANCER)
	{
		Necromancer_OnRunCmd(player, button);
	}
	else if (player.role == PESTILENCE)
	{
		Pestilence_OnRunCmd(player, button);
	}
	else if (player.role == THUNDER)
	{
		Thunder_OnRunCmd(player, button);
	}
}

void Traitor_OnRunCmd(const TTTPlayer player, int button)
{
	if (button == IN_SCORE)
	{
		OpenShop(player);
	}
}

void OnRelease(const TTTPlayer player, int button)
{
	int client = player.index;

	if (player.role == DETECTIVE)
	{
		Detective_OnRelease(client, button);
	}
}