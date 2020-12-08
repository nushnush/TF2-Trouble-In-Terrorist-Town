static Menu menu;

public void Shop_Refresh()
{
	char sPath[128];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt_shop.cfg");
	if (!FileExists(sPath))
	{
		LogError("[SM] Could not find file %s.", sPath);
		return;
	}

	KeyValues kv = new KeyValues("TTT_SHOP");
	menu = new Menu(Handler_Shop);
	kv.ImportFromFile(sPath);
	kv.GotoFirstSubKey();
	do 
	{
		char name[16], display[256];
		kv.GetSectionName(name, sizeof(name));

		int price = kv.GetNum("price", 3);
		kv.GetString("display", display, sizeof(display), "");

		char info[32];
		FormatEx(info, sizeof(info), "%s;%i", name, price);
		menu.AddItem(info, display);
	}
	while (kv.GotoNextKey());

	kv.Rewind();
	delete kv;
}

public void OpenShop(const TTTPlayer player)
{
	menu.SetTitle("Shop Menu\nYou have %i credits", player.credits);
	menu.Display(player.index, 15);
}

public int Handler_Shop(Menu smenu, MenuAction action, int client, int param2) 
{  
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32], strings[2][32];
			menu.GetItem(param2, info, sizeof(info));
			ExplodeString(info, ";", strings, sizeof(strings), sizeof(strings[]));
			TTTPlayer player = TTTPlayer(client);
			
			int price = StringToInt(strings[1]);
			if(!IsPlayerAlive(client) || player.role != TRAITOR || player.credits < price)
				return;

			if(StrEqual(strings[0], "rocket"))
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				int wep = player.SpawnWeapon("tf_weapon_rocketlauncher", 18, 1, 6);
				SetAmmo(client, wep, 0);
			}
			else if(StrEqual(strings[0], "minigun"))
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				int wep = player.SpawnWeapon("tf_weapon_minigun", 15, 1, 6, "305 ; 1.0");
				SetAmmo(client, wep, 100);
			}
			else if(StrEqual(strings[0], "rifle"))
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				int wep = player.SpawnWeapon("tf_weapon_sniperrifle", 851, 1, 6, "308 ; 1.0 ; 297 ; 1.0 ; 305 ; 1.0");
				SetAmmo(client, wep, 10);
			}
			else if(StrEqual(strings[0], "heal"))
			{
				SetEntityHealth(client, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client));
			}
			else if(StrEqual(strings[0], "fakebody") || StrEqual(strings[0], "explosivebody"))
			{
				SpawnRagdoll(player, strings[0]);
			}
			else if(StrEqual(strings[0], "radar"))
			{
				TF2_AddCondition(client, TFCond_SpawnOutline, 30.0);
			}

			player.credits -= price;
		}
	}
}
