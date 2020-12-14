stock void PerformDisguise(int client, int target)
{
	TF2_SetPlayerClass(client, TF2_GetPlayerClass(target));
	TF2_RegeneratePlayer(client);
	TTTPlayer(client).GiveInitialWeapon();

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
			TF2_SpawnHat(client, GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex"));
		}
	}

	/*char name[MAX_NAME_LENGTH], name2[MAX_NAME_LENGTH];
	GetClientName(client, name, MAX_NAME_LENGTH);
	GetClientName(target, name2, MAX_NAME_LENGTH);
	SetClientInfo(target, "name", "bruh"); // prevents (1)yelks
	SetClientInfo(client, "name", name2);
	SetClientInfo(target, "name", name);*/
}
