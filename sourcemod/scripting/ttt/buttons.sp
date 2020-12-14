#define MAX_BUTTONS 25
static int g_LastButtons[MAXPLAYERS + 1];
static Handle g_hSearch[MAXPLAYERS + 1];

/* Scanner & Shop
==================================================================================================== */

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	TTTPlayer player = TTTPlayer(client);

	if (player.role == PESTILENCE)
	{
		Pestilence_FindTarget(client);
	}
		
	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);

		if (buttons & button)
		{
			if (!(g_LastButtons[client] & button))
			{
				OnPress(player, button);
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

void OnPress(const TTTPlayer player, int button)
{
	int client = player.index;

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
				TTTPlayer other = TTTPlayer(GetEntPropEnt(target, Prop_Data, "m_hOwnerEntity"));
				if(other.killerRole == PESTILENCE)
				{
					CPrintToChat(client, "%s {community}%N{default} was %s and died %0.1f seconds ago, murdered by the %s.", 
					TAG, other.index, g_sRoles[other.role], GetEngineTime() - other.deathTime, g_sRoles[PESTILENCE]);
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

		case IN_USE:
		{
            if (!IsPlayerAlive(client) || player.role != DETECTIVE || !IsMeleeActive(client))
                return;

            int target = GetClientAimTarget(client);
            if (target == -1)
            {
                return;
            }

            float now = GetEngineTime();
            if (g_fLastAbility[client] + g_cvScannerDelay.IntValue - now > 0)
            {
                CPrintToChat(client, "%s Please wait %0.1f seconds before using the scanner again.", TAG, g_fLastAbility[client] + g_cvScannerDelay.IntValue - now);
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

		case IN_SCORE:
		{
			if (player.role == TRAITOR)
				OpenShop(player);
		}

		case IN_ATTACK2:
		{
			if (player.role == DISGUISER)
			{
				if(!IsPlayerAlive(client))
				{
					return;
				}

				int target = GetClientAimTarget(client);
				if (target == -1)
				{
					return;
				}

				float now = GetEngineTime();
				if (g_fLastAbility[client] + g_cvDisguiseDelay.IntValue - now > 0)
				{
					CPrintToChat(client, "%s Please wait %0.1f seconds before using the disguise again.", TAG, g_fLastAbility[client] + g_cvDisguiseDelay.IntValue - now);
					return;
				}

				PerformDisguise(client, target);
				ForcePlayerSuicide(target);
				g_fLastAbility[client] = now;
			}
			else if (player.role == NECROMANCER)
			{
				if(!IsPlayerAlive(client))
				{
					return;
				}

				float now = GetEngineTime();
				
				if (g_fLastAbility[client] + g_cvEarthquakeDelay.IntValue - now > 0)
				{
					CPrintToChat(client, "%s Please wait %0.1f seconds before summoning earthquakes again.", TAG, g_fLastAbility[client] + g_cvEarthquakeDelay.IntValue - now);
					return;
				}

				PerformEarthquakes();
				g_fLastAbility[client] = now;
			}
			else if (player.role == PESTILENCE)
			{
				if(!IsPlayerAlive(client))
				{
					return;
				}

				if (!IsValidClient(g_iLastTouched[client]))
				{
					CPrintToChat(client, "%s You don't have a valid target.", TAG);
					return;
				}

				float now = GetEngineTime();
				
				if (g_fLastAbility[client] + g_cvInfectDelay.IntValue - now > 0)
				{
					CPrintToChat(client, "%s Please wait %0.1f seconds before summoning earthquakes again.", TAG, g_fLastAbility[client] + g_cvInfectDelay.IntValue - now);
					return;
				}

				PerformInfection(player);
			}
			else if (player.role == THUNDER)
			{
				if(!IsPlayerAlive(client))
				{
					return;
				}

				int target = GetClientAimTarget(client);
				if (target == -1)
				{
					return;
				}

				PerformThunder(player, target);
			}
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

	float now = GetEngineTime();
	int progress = RoundToNearest(now - g_fStartSearchTime[client]);

	if (progress >= 5)
	{
		g_fLastAbility[client] = now;
		Role role = TTTPlayer(target).role;
		bool isTraitor = role >= TRAITOR;

		// default: 20% chance to fake results
		isTraitor = GetRandomInt(1, 100) <= g_cvScannerChance.IntValue ? !isTraitor : isTraitor;
		CPrintToChat(client, "%s %N is %s.", TAG, target, !isTraitor ? g_sRoles[INNOCENT] : g_sRoles[role]);
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