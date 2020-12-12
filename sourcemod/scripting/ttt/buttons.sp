#define MAX_BUTTONS 25
static int g_LastButtons[MAXPLAYERS + 1];
static Handle g_hSearch[MAXPLAYERS + 1];

/* Scanner & Shop
==================================================================================================== */

public Action OnPlayerRunCmd(int client, int &buttons)
{
	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);

		if (buttons & button)
		{
			if (!(g_LastButtons[client] & button))
			{
				OnPress(client, button);
			}
		}
		else if (g_LastButtons[client] & button)
		{
			OnRelease(client, button);
		}
	}

	g_LastButtons[client] = buttons;
	return Plugin_Continue;
}

void OnPress(int client, int button)
{
	switch (button)
	{
		case IN_RELOAD:
		{
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
				TTTPlayer player = TTTPlayer(GetEntPropEnt(target, Prop_Data, "m_hOwnerEntity"));
				CPrintToChat(client, "%s {community}%N{default} was %s and died %0.1f seconds ago.", TAG, player.index, g_sRoles[player.role], GetGameTime() - player.deathTime);
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

		case IN_SCORE:
		{
			TTTPlayer player = TTTPlayer(client);
			if(player.role == TRAITOR)
				OpenShop(player);
		}

		case IN_USE:
		{
            if (TTTPlayer(client).role != DETECTIVE || !IsMeleeActive(client))
                return;

            int target = GetClientAimTarget(client);
            if (target == -1)
            {
                return;
            }

            float now = GetGameTime();
            if (now - g_fLastSearch[client] < g_Cvar_Delay.IntValue)
            {
                CPrintToChat(client, "%s Please wait %0.1f seconds before using the scanner again.", TAG, g_Cvar_Delay.IntValue - (now - g_fLastSearch[client]));
                return;
            }

            float pos[3], pos2[3];
            GetClientAbsOrigin(client, pos);
            GetClientAbsOrigin(target, pos2);
            if (GetVectorDistance(pos, pos2) >= 100.0)
            {
                return;
            }

            g_fStartSearchTime[client] = now;
            delete g_hSearch[client];
            g_hSearch[client] = CreateTimer(0.1, ScanPlayer, client, TIMER_REPEAT);
        }
	}
}

Action ScanPlayer(Handle timer, int client)
{
	if (g_hSearch[client] == null || TTTPlayer(client).role != DETECTIVE || !IsMeleeActive(client))
	{
		g_hSearch[client] = null;
		return Plugin_Stop;
	}

	int target = GetClientAimTarget(client);
	if (target == -1)
	{
		g_hSearch[client] = null;
		return Plugin_Stop;
	}

	float now = GetGameTime();
	int progress = RoundToNearest(now - g_fStartSearchTime[client]);

	if (progress >= 5)
	{
		g_fLastSearch[client] = now;
		bool isTraitor = TTTPlayer(target).role == TRAITOR;

		// default: 20% chance to fake results
		isTraitor = GetRandomInt(1, 100) <= g_Cvar_Chance.IntValue ? !isTraitor : isTraitor;
		CPrintToChat(client, "%s %N is %s.", TAG, target, !isTraitor ? g_sRoles[INNOCENT] : g_sRoles[TRAITOR]);
		g_hSearch[client] = null;
		return Plugin_Stop;
	}

	char szBuffer[32];
	int len = Format(szBuffer, sizeof(szBuffer), "[");
	for (int i = 0; i < 5; i++)
		len += Format(szBuffer[len], sizeof(szBuffer) - len, progress >= i ? "|" : "  ");
	Format(szBuffer[len], sizeof(szBuffer) - len, "]");

	SetHudTextParams(-1.0, 0.3, 0.1, 255, 255, 255, 255);
	ShowHudText(client, 5, "Scanning %N\n%s", target, szBuffer);
	ShowHudText(target, 5, "You are being scanned!\n%s", szBuffer);

	return Plugin_Continue;
}

void OnRelease(int client, int button)
{
	switch (button)
	{
		case IN_USE:
		{
			delete g_hSearch[client];
		}
	}
}