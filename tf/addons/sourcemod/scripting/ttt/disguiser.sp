void PerformDisguise(int client, int target)
{
	TF2_SetPlayerClass(client, TF2_GetPlayerClass(target));
	TF2_RegeneratePlayer(client);
	TTTPlayer player = TTTPlayer(client);
	player.GiveInitialWeapon();

	int ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
		{
			TF2_RemoveWearable(client, ent);
		}
	}

	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == target)
		{
			player.SpawnItem("tf_wearable", GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex"));
		}
	}

	/*char name[MAX_NAME_LENGTH], name2[MAX_NAME_LENGTH];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientName(target, name2, MAX_NAME_LENGTH);
	SetClientInfo(target, "name", "bruh"); // prevents (1)yelks
	SetClientInfo(client, "name", name2);
	SetClientInfo(target, "name", name);*/
}

void Disguiser_OnRunCmd(const TTTPlayer player, int button)
{
	int client = player.index;

	if (button == IN_ATTACK2)
	{
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
}