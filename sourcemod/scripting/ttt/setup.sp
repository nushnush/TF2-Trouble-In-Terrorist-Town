stock void FF(bool status)
{
	ConVar hFF = FindConVar("mp_friendlyfire");
	int iFlags = hFF.Flags;
	hFF.Flags = iFlags & ~FCVAR_NOTIFY;
	hFF.SetBool(status);
	hFF.Flags = iFlags; 
}

stock void OpenDoors()
{
	int ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
	{
		AcceptEntityInput(ent, "Unlock");
		AcceptEntityInput(ent, "Open");
	}
	
	/*for (int i = 0; i < sizeof(g_sDoorList); i++)
	{
		ent = -1;
		while ((ent = FindEntityByClassname(ent, g_sDoorList[i])) != -1)
		{
			AcceptEntityInput(ent, "Unlock");
			AcceptEntityInput(ent, "Open");
		}
	}*/
}

stock void MakeRoundTimer()
{
	//Kill the timer created by the game
	int iGameTimer = MaxClients + 1;
	while ((iGameTimer = FindEntityByClassname(iGameTimer, "team_round_timer")) > MaxClients)
	{
		if (GetEntProp(iGameTimer, Prop_Send, "m_bShowInHUD"))
		{
			AcceptEntityInput(iGameTimer, "Kill");
			break;
		}
	}

	//Initiate our timer with our time
	int iTimer = CreateEntityByName("team_round_timer");
	char time[8];
	DispatchKeyValue(iTimer, "show_in_hud", "1");
	FormatEx(time, sizeof(time), "%i", g_cvSetupTime.IntValue);
	DispatchKeyValue(iTimer, "setup_length", time);
	DispatchKeyValue(iTimer, "reset_time", "1");
	DispatchKeyValue(iTimer, "auto_countdown", "1");
	FormatEx(time, sizeof(time), "%i", g_cvRoundTime.IntValue);
	DispatchKeyValue(iTimer, "timer_length", time);
	DispatchSpawn(iTimer);

	AcceptEntityInput(iTimer, "Resume");
	AcceptEntityInput(iTimer, "Enable");

	HookSingleEntityOutput(iTimer, "OnSetupFinished", OnSetupFinished, true);
	HookSingleEntityOutput(iTimer, "OnFinished", OnRoundEnd, true);

	Event event = CreateEvent("teamplay_update_timer", true);
	event.Fire();

	g_eRound = Round_Setup;
}

stock void StartTTT()
{
	if (GetClientCount() == 0)
	{
		ForceTeamWin(2);
		return;
	}

	OpenDoors();
	AssignTraitors();
	AssignDetectives();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			TTTPlayer player = TTTPlayer(i);

			if (player.role == NOROLE)
			{
				CPrintToChat(i, "%s {community}You are an %s.", TAG, g_sRoles[INNOCENT]);
				CPrintToChat(i, "%s {community}You have %i karma. You deal %i%% damage.", TAG, player.karma, player.karma);
				player.role = INNOCENT;
			}

			if (player.role > INNOCENT && requiredClass[player.role - DETECTIVE] != TFClass_Unknown)
			{
				TF2_SetPlayerClass(i, requiredClass[player.role - DETECTIVE]);
			}

			if (player.role >= TRAITOR)
			{
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
			}

			SendProxy_Hook(i, "m_bGlowEnabled", Prop_Int, SendProxy_Glow);
			player.Setup();
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && TTTPlayer(i).role >= TRAITOR)
		{
			for (int j = 1; j <= MaxClients; j++)
			{
				if (IsValidClient(j))
				{
					Role role = TTTPlayer(j).role;
					if(role >= TRAITOR)
					{
						CPrintToChat(i, "%N - %s.", j, g_sRoles[role]);
					}
				}
			}
		}
	}

	int ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}

	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "team_control_point")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}

	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}

	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "func_capturezone")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}

	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "func_regenerate")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}

	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "trigger_capture_area")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}
	
	/*ent = FindEntityByClassname(MaxClients + 1, "tf_gamerules");
	if (ent != -1)
	{
		SetVariantFloat(999.9);
		AcceptEntityInput(ent, "SetBlueTeamRespawnWaveTime");
		SetVariantFloat(999.9);
		AcceptEntityInput(ent, "SetRedTeamRespawnWaveTime");
	}*/

	g_eRound = Round_Active;
	FF(true);
}

stock void AssignTraitors()
{
	int required = GetClientCount() / g_cvTraitorRatio.IntValue;

	while (required > 0)
	{
		int random = -1;

		if (g_aForceTraitor.Length > 0)
		{
			int arr[2];
			g_aForceTraitor.GetArray(0, arr);
			random = GetClientOfUserId(arr[0]);

			if (IsValidClient(random))
			{
				Role role = view_as<Role>(arr[1]);
				TTTPlayer player = TTTPlayer(random);
				player.role = role;
				player.credits += 2;
				CPrintToChat(random, "%s {community}You are the %s.", TAG, g_sRoles[role]);
				CPrintToChat(random, "%s {fullred}You can use teamchat to communicate with your fellow Traitors.", TAG);
				required--;
			}

			g_aForceTraitor.Erase(0);
			continue;
		}

		random = GetRandomPlayer();

		if (random != -1)
		{
			TTTPlayer player = TTTPlayer(random);
			
			if (GetRandomInt(1, 100) <= 80)
			{
				player.role = TRAITOR;
			}
			else 
			{
				player.role = view_as<Role>(GetRandomInt(view_as<int>(DISGUISER), view_as<int>(THUNDER)));
			}
			
			player.credits += g_cvCreditsOnRound.IntValue;
			CPrintToChat(random, "%s {community}You are the %s.", TAG, g_sRoles[player.role]);
			CPrintToChat(random, "%s {fullred}You can use teamchat to communicate with your fellow Traitors.", TAG);
		}

		required--;
	}
}

stock void AssignDetectives()
{
	int required = GetClientCount() / g_cvDetectiveRatio.IntValue;

	while (required > 0)
	{
		int random = -1;

		if (g_aForceDetective.Length > 0)
		{
			random = GetClientOfUserId(g_aForceDetective.Get(0));

			if (IsValidClient(random))
			{
				TTTPlayer player = TTTPlayer(random);
				player.role = DETECTIVE;
				CPrintToChat(random, "%s {community}You are a %s.", TAG, g_sRoles[DETECTIVE]);
				CPrintToChat(random, "%s {community}You have %i karma. You deal %i%% damage.", TAG, player.karma, player.karma);
				required--;
			}

			g_aForceDetective.Erase(0);
			continue;
		}

		random = GetRandomPlayer();

		if (random != -1)
		{
			TTTPlayer player = TTTPlayer(random);
			player.role = DETECTIVE;
			CPrintToChat(random, "%s {community}You are a %s.", TAG, g_sRoles[DETECTIVE]);
			CPrintToChat(random, "%s {community}You have %i karma. You deal %i%% damage.", TAG, player.karma, player.karma);
		}

		required--;
	}
}

stock int GetRandomPlayer(Role role = NOROLE, bool deadOnly = false)
{
	int[] clients = new int[MaxClients];
	int clientCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
		{
			continue;
		}

		if (deadOnly && IsPlayerAlive(i))
		{
			continue;
		}

		if (role == TRAITOR)
		{
			if (TTTPlayer(i).role < TRAITOR)
			{
				continue;
			}
		}
		else if (TTTPlayer(i).role != role)
		{
			continue;
		}

		clients[clientCount++] = i;
	}

	if (clientCount == 0)
	{
		return -1;
	}

	SortIntegers(clients, clientCount - 1, Sort_Random);
	return clients[GetRandomInt(0, clientCount - 1)];
}

public Action SendProxy_Glow(const int iEntity, const char[] cPropName, int &iValue, const int iElement, const int iClient)
{
	Role entRole = TTTPlayer(iEntity).role;
	Role clientRole = TTTPlayer(iClient).role;
	
	if (entRole >= TRAITOR && clientRole >= TRAITOR)
	{
		iValue = 1;
		return Plugin_Changed;
	}
	if (entRole >= TRAITOR && clientRole < TRAITOR)
	{
		iValue = 0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}