public void FF(bool status)
{
	ConVar hFF = FindConVar("mp_friendlyfire");
	int iFlags = hFF.Flags;
	hFF.Flags = iFlags & ~FCVAR_NOTIFY;
	hFF.SetBool(status);
	hFF.Flags = iFlags; 
}

public void OpenDoors()
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

public void MakeRoundTimer()
{
	//Kill the timer created by the game
	int iGameTimer = -1;
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
	FormatEx(time, sizeof(time), "%i", g_Cvar_SetupTime.IntValue);
	DispatchKeyValue(iTimer, "setup_length", time);
	DispatchKeyValue(iTimer, "reset_time", "1");
	DispatchKeyValue(iTimer, "auto_countdown", "1");
	FormatEx(time, sizeof(time), "%i", g_Cvar_RoundTime.IntValue);
	DispatchKeyValue(iTimer, "timer_length", time);
	DispatchSpawn(iTimer);

	AcceptEntityInput(iTimer, "Resume");
	AcceptEntityInput(iTimer, "Enable");

	HookSingleEntityOutput(iTimer, "OnSetupFinished", OnSetupFinished, true);
	HookSingleEntityOutput(iTimer, "OnFinished", OnRoundEnd, true);

	Event event = CreateEvent("teamplay_update_timer", true);
	event.Fire();
}

public void StartTTT()
{
	if(GetClientCount() == 0)
	{
		ForceTeamWin();
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

			player.Setup();
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
	
	ent = FindEntityByClassname(MaxClients + 1, "tf_gamerules");
	if (ent != -1)
	{
		SetVariantFloat(999.9);
		AcceptEntityInput(ent, "SetBlueTeamRespawnWaveTime");
		SetVariantFloat(999.9);
		AcceptEntityInput(ent, "SetRedTeamRespawnWaveTime");
	}

	roundStarted = true;
	FF(true);
}

public void AssignTraitors()
{
	int required = GetClientCount() / g_Cvar_TraitorRatio.IntValue;

	while(required > 0)
	{
		int random = GetRandomPlayer();
		if(random != -1)
		{
			TTTPlayer player = TTTPlayer(random);
			player.role = TRAITOR;
			player.credits = 3;
			CPrintToChat(random, "%s {community}You are a %s.", TAG, g_sRoles[TRAITOR]);
			CPrintToChat(random, "%s {fullred}You can use teamchat to communicate with your fellow Traitors.", TAG);
		}
		required--;
	}
}

public void AssignDetectives()
{
	int required = GetClientCount() / g_Cvar_DetectiveRatio.IntValue;

	while(required > 0)
	{
		int random = GetRandomPlayer();
		if(random != -1)
		{
			TTTPlayer player = TTTPlayer(random);
			player.role = DETECTIVE;
			player.credits = 3;
			CPrintToChat(random, "%s {community}You are a %s.", TAG, g_sRoles[DETECTIVE]);
			CPrintToChat(random, "%s {community}You have %i karma. You deal %i%% damage.", TAG, player.karma, player.karma);
		}
		required--;
	}
}

public int GetRandomPlayer()  
{  
	int[] clients = new int[MaxClients];
	int clientCount;
	for (int i = MaxClients; i; --i)  
	{
		if (IsValidClient(i) && TTTPlayer(i).role == NOROLE)
		{
			TTTPlayer player = TTTPlayer(i);
			if(player.role == NOROLE)
				clients[clientCount++] = i;
		}
			
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount - 1)];  
}