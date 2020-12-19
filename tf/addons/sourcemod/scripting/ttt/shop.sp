#define MAX_TRAITOR_ITEMS 8
#define MAX_ROLES 6

TFClassType requiredClass[MAX_ROLES] = { TFClass_Unknown, TFClass_Unknown, TFClass_Unknown, TFClass_Unknown};

enum struct MenuItem
{
	char info[16];
	char display[64];
	int price;
}

static MenuItem traitorItems[MAX_TRAITOR_ITEMS];
static MenuItem rolesItems[MAX_ROLES];

void Shop_Refresh()
{
	char sPath[128];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt_shop.cfg");
	if (!FileExists(sPath))
	{
		LogError("[SM] Could not find file %s.", sPath);
		return;
	}

	KeyValues kv = new KeyValues("TTT_SHOP");
	kv.ImportFromFile(sPath);
	int i = 0;
	
	if (kv.JumpToKey("TraitorShop", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				MenuItem item;
				kv.GetSectionName(item.info, sizeof(item.info));
				item.price = kv.GetNum("price", 3);
				kv.GetString("display", item.display, sizeof(item.display), "");
				traitorItems[i++] = item; 
			} 
			while (kv.GotoNextKey(false));
		}
		
		kv.GoBack();
	}

	delete kv;

	kv = new KeyValues("TTT_SHOP");
	kv.ImportFromFile(sPath);
	i = 0;

	if (kv.JumpToKey("RoleShop", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				MenuItem item;
				kv.GetSectionName(item.info, sizeof(item.info));
				item.price = kv.GetNum("price", 3);
				kv.GetString("display", item.display, sizeof(item.display), "");
				rolesItems[i++] = item; 
			} 
			while (kv.GotoNextKey(false));
		}
		
		kv.GoBack();
	}

	delete kv;
}

void OpenShop(const TTTPlayer player)
{
	if (player.role == TRAITOR)
	{
		Menu menu = new Menu(Handler_TraitorShop);
		menu.SetTitle("Shop Menu\nYou have %i credits", player.credits);
		for (int i = 0; i < MAX_TRAITOR_ITEMS; i++)
		{
			char info[32];
			FormatEx(info, sizeof(info), "%s;%i", traitorItems[i].info, traitorItems[i].price);
			menu.AddItem(info, traitorItems[i].display, traitorItems[i].price <= player.credits ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		menu.Display(player.index, 15);
	}
	else if (player.role == NOROLE)
	{
		Menu menu = new Menu(Handler_RoleShop);
		menu.SetTitle("Buy Role\nYou have %i credits", player.credits);
		for (int i = 0; i < MAX_ROLES; i++)
		{
			char info[32];
			FormatEx(info, sizeof(info), "%s;%i", rolesItems[i].info, rolesItems[i].price);
			menu.AddItem(info, rolesItems[i].display, rolesItems[i].price <= player.credits ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		menu.Display(player.index, 15);
	}
}

public int Handler_TraitorShop(Menu smenu, MenuAction action, int client, int param2) 
{  
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32], strings[2][32];
			smenu.GetItem(param2, info, sizeof(info));
			ExplodeString(info, ";", strings, sizeof(strings), sizeof(strings[]));
			TTTPlayer player = TTTPlayer(client);
			
			int price = StringToInt(strings[1]);

			if (player.credits < price)
			{
				CPrintToChat(client, "%s You can don't have enough credits to purchase that.", TAG);
				return;
			}

			if (!IsPlayerAlive(client) || player.role != TRAITOR)
				return;

			if (StrEqual(strings[0], "rocket"))
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				int wep = player.SpawnItem("tf_weapon_rocketlauncher", 18, 1, 6);
				SetAmmo(client, wep, 0);
			}
			else if (StrEqual(strings[0], "minigun"))
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				int wep = player.SpawnItem("tf_weapon_minigun", 15, 1, 6, "305 ; 1.0");
				SetAmmo(client, wep, 100);
			}
			else if (StrEqual(strings[0], "rifle"))
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				int wep = player.SpawnItem("tf_weapon_sniperrifle", 851, 1, 6, "308 ; 1.0 ; 297 ; 1.0 ; 305 ; 1.0");
				SetAmmo(client, wep, 10);
			}
			else if (StrEqual(strings[0], "heal"))
			{
				SetEntityHealth(client, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client));
			}
			else if (StrEqual(strings[0], "fakebody") || StrEqual(strings[0], "explosivebody"))
			{
				SpawnRagdoll(player, strings[0]);
			}
			else if (StrEqual(strings[0], "radar"))
			{
				TF2_AddCondition(client, TFCond_SpawnOutline, 30.0);
			}
			else if (StrEqual(strings[0], "cloak"))
			{
				TF2_AddCondition(client, TFCond_Stealthed, 60.0);
			}

			player.credits -= price;
		}
	}
}

public int Handler_RoleShop(Menu smenu, MenuAction action, int client, int param2)
{  
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32], strings[2][32];
			smenu.GetItem(param2, info, sizeof(info));
			ExplodeString(info, ";", strings, sizeof(strings), sizeof(strings[]));
			TTTPlayer player = TTTPlayer(client);
			
			int price = StringToInt(strings[1]);

			if (player.credits < price)
			{
				CPrintToChat(client, "%s You can don't have enough credits to purchase that.", TAG);
				return;
			}

			if (g_aForceTraitor.FindValue(GetClientUserId(client)) != -1 || g_aForceDetective.FindValue(GetClientUserId(client)) != -1)
			{
				CPrintToChat(client, "%s You have already purchased for a role.", TAG);
				return;
			}

			if (player.role != NOROLE)
			{
				CPrintToChat(client, "%s You can only purchase this during setup time.", TAG);
				return;
			}

			if (StrEqual(strings[0], "traitor"))
			{
				int arr[2];
				arr[0] = GetClientUserId(client);
				arr[1] = view_as<int>(TRAITOR);
				g_aForceTraitor.PushArray(arr);
			}
			else if (StrEqual(strings[0], "disguiser"))
			{
				int arr[2];
				arr[0] = GetClientUserId(client);
				arr[1] = view_as<int>(DISGUISER);
				g_aForceTraitor.PushArray(arr);
			}
			else if (StrEqual(strings[0], "necromancer"))
			{
				int arr[2];
				arr[0] = GetClientUserId(client);
				arr[1] = view_as<int>(NECROMANCER);
				g_aForceTraitor.PushArray(arr);
			}
			else if (StrEqual(strings[0], "pestilence"))
			{
				int arr[2];
				arr[0] = GetClientUserId(client);
				arr[1] = view_as<int>(PESTILENCE);
				g_aForceTraitor.PushArray(arr);
			}
			else if (StrEqual(strings[0], "thunder"))
			{
				int arr[2];
				arr[0] = GetClientUserId(client);
				arr[1] = view_as<int>(THUNDER);
				g_aForceTraitor.PushArray(arr);
			}
			else if (StrEqual(strings[0], "detective"))
			{
				g_aForceDetective.Push(GetClientUserId(client));
			}

			player.credits -= price;
		}
	}
}
