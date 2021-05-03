#include <amxmodx>
#include <reapi>

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

new const g_Prefix[] = ">";

enum _:Data
{
	Team,
	He,
    Smoke,
    Flash,
	Float:Health,
	Float:Origin[3],
    Float:Velocity[3],
    Float:Angles[3],
};

new g_FirstId[33], g_SecondId[33][33], g_arrData[33][Data];

new Float:g_Delay[33];

new bool:g_Control[33];
new bool:g_Invited[33];
new bool:g_GiveWeapons[33];

public plugin_init()
{
	register_plugin("ReControl", "1.0", "Conor");
	
	register_clcmd("drop", "Control");
	register_clcmd("say /co", "Control");
	register_clcmd("say_team /co", "Control");
	register_clcmd("say /control", "Control");
	register_clcmd("say_team /control", "Control");
	
	register_clcmd("say /re", "Replace");
	register_clcmd("say_team /re", "Replace");
	register_clcmd("say /replace", "Replace");
	register_clcmd("say_team /replace", "Replace");
	
	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "@CSGameRules_PlayerSpawn", true);
}

public client_disconnected(id)
{
	if (task_exists(1337))
		remove_task(1337);
	
	g_Invited[id] = false;
}

@CSGameRules_PlayerSpawn(id)
{
	if (is_user_alive(id))
		GiveWeapons(id);
}

public Control(id)
{
	g_Control[id] = true;
	Menu(id);
	
	return;
}

public Replace(id)
{
	g_Control[id] = false;
	Menu(id);
	
	return;
}

public Menu(id)
{
	if ((is_user_alive(id) && g_Control[id] || is_user_alive(id) && !g_Control[id] || !is_user_alive(id) && !g_Control[id]) && (rg_get_user_team(id) == 1 || rg_get_user_team(id) == 2))
	{
		new m_Menu = menu_create(fmt("%s", g_Control[id] ? "\rChoose a player to give control" : "\rSelect a player to replace"), "MenuHandler");
		
		new Players[32], Count, szPlayer[10], Player, szName[MAX_NAME_LENGTH], szBuffer[64];
		
		if (g_Control[id])
		{
			switch (rg_get_user_team(id))
			{
				case 1: get_players(Players, Count, "bce", "TERRORIST");
				case 2: get_players(Players, Count, "bce", "CT");
			}
		}
		else
			get_players(Players, Count, "bce", "SPECTATOR");
		
		for (new i; i < Count; i++)
		{
			Player = Players[i];
			
			if (id == Player)
				continue;
			
			get_user_name(Player, szName, charsmax(szName));
			
			num_to_str(Player, szPlayer, charsmax(szPlayer));
			
			formatex(szBuffer, charsmax(szBuffer), "%s \d[\rInvited\d]", szName);
			
			if (g_Invited[Player])
				menu_additem(m_Menu, szBuffer, szPlayer);
			else
				menu_additem(m_Menu, szName, szPlayer);
		}
		
		menu_setprop(m_Menu, MPROP_EXIT, MEXIT_ALL);
		
		menu_display(id, m_Menu, 0);
	}
	
	return;
}

public MenuHandler(id, m_Menu, szKeys)
{
	if (!is_user_connected(id))
	{
        menu_destroy(m_Menu);
        return;
    }
	
	if (szKeys == MENU_EXIT)
    {
        menu_destroy(m_Menu);
        return;
    }
	
	new szData[6], szName[64], _Access, _Callback;
	
	menu_item_getinfo(m_Menu, szKeys, _Access, szData, charsmax(szData), szName, charsmax(szName), _Callback);
	
	new UserId = str_to_num(szData);
	
	new SecondId = g_SecondId[id][UserId] = UserId;
	new FirstId = g_FirstId[UserId] = id;
	
	if (!g_Invited[SecondId])
	{
		new Float:szTime = get_gametime();
		
		if(szTime < g_Delay[FirstId])
			client_print_color(FirstId, print_team_blue, "%s Please wait ^3%.1f^1 sec..", g_Prefix, g_Delay[FirstId] - szTime);
		else
		{
			g_Invited[SecondId] = true;
			g_Delay[FirstId] = get_gametime() + 10.0;
			
			Confirmation(SecondId);
			
			new Parms[2];
			Parms[0] = FirstId;
			Parms[1] = SecondId;
			
			set_task(10.0, "task_Response", 1337, Parms, 2);
		}
	}
	
	if (g_Invited[SecondId])
	{
		Menu(FirstId);
		return;
	}
	
	menu_destroy(m_Menu);
	
	return;	
}

public Confirmation(id)
{
	if (!is_user_alive(id))
	{
		new m_Confirmation;
		new FirstId = g_FirstId[id];
		
		if (g_Control[FirstId])
			m_Confirmation = menu_create(fmt("\rTake control of %n?", FirstId), "ConfirmationHandler");
		else
			m_Confirmation = menu_create(fmt("\r%n wants you to replace him", FirstId), "ConfirmationHandler");
		
		menu_additem(m_Confirmation, "Yes");
		menu_additem(m_Confirmation, "No");
		
		menu_setprop(m_Confirmation, MPROP_EXIT, MEXIT_NEVER);
		
		menu_display(id, m_Confirmation, 0);
	}
	
	return;
}

public ConfirmationHandler(id, m_Confirmation, szKeys)
{
	if (!is_user_connected(id))
	{
        menu_destroy(m_Confirmation);
        return;
    }
	
	new FirstId = g_FirstId[id];
	new SecondId = g_SecondId[FirstId][id];
	
	g_Invited[id] = false;
	
	switch (szKeys)
	{
		case 0:
		{
			ReControl(SecondId);
			
			show_menu(FirstId, 0, "", 1);
        }
		case 1:
		{
			client_print_color(FirstId, SecondId, "%s ^3%n^1 refused to %s", g_Prefix, SecondId, g_Control[FirstId] ? "take control" : "replace");
			
			Menu(FirstId);
		}
	}
	
	menu_destroy(m_Confirmation);
	
	return;
}

public GiveWeapons(id)
{
	if (is_user_alive(id) && g_GiveWeapons[id])
	{
		new FirstId = g_FirstId[id];
		
		rg_remove_all_items(id);
		
		rg_give_item(id, "weapon_knife");
		
		set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
		set_entvar(id, var_health, g_arrData[FirstId][Health]);
		set_entvar(id, var_origin, g_arrData[FirstId][Origin]);
		set_entvar(id, var_velocity, g_arrData[FirstId][Velocity]);
		set_entvar(id, var_angles, g_arrData[FirstId][Angles]);
		set_entvar(id, var_fixangle, 1);
		
		switch (rg_get_user_team(id))
		{
            case 1:
			{
				rg_set_user_footsteps(id, true);
				
				if (g_arrData[FirstId][He])
				{
                    rg_give_item(id, "weapon_hegrenade");
                    rg_set_user_bpammo(id, WEAPON_HEGRENADE, g_arrData[FirstId][He]);
                }
				
				if (g_arrData[FirstId][Flash])
				{
                    rg_give_item(id, "weapon_flashbang");
                    rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_arrData[FirstId][Flash]);
                }
				
				if (g_arrData[FirstId][Smoke])
				{
                    rg_give_item(id, "weapon_smokegrenade");
                    rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_arrData[FirstId][Smoke]);
                }
            }
            case 2: rg_set_user_footsteps(id, false);
		}
		
		g_GiveWeapons[id] = false;
    }
}

public ReControl(id)
{
	new FirstId = g_FirstId[id];
	new SecondId = g_SecondId[FirstId][id];
	
	g_arrData[FirstId][Team] = rg_get_user_team(FirstId);
	
	if (is_user_alive(FirstId))
	{
		get_entvar(FirstId, var_origin, g_arrData[FirstId][Origin], 3);
		get_entvar(FirstId, var_velocity, g_arrData[FirstId][Velocity], 3);
		get_entvar(FirstId, var_v_angle, g_arrData[FirstId][Angles], 3);
		
		g_arrData[FirstId][He] = rg_get_user_bpammo(FirstId, WEAPON_HEGRENADE);
		g_arrData[FirstId][Flash] = rg_get_user_bpammo(FirstId, WEAPON_FLASHBANG);
		g_arrData[FirstId][Smoke] = rg_get_user_bpammo(FirstId, WEAPON_SMOKEGRENADE);
		g_arrData[FirstId][Health] = get_entvar(FirstId, var_health);
		
		if (!g_Control[FirstId])
		{
			rg_set_user_team(SecondId, g_arrData[FirstId][Team]);
			rg_set_user_team(FirstId, TEAM_SPECTATOR);
		}
		
		g_GiveWeapons[SecondId] = true;
		
		rg_round_respawn(SecondId);
		
		user_kill(FirstId, true);
	}
	else
	{
		if (!g_Control[FirstId])
		{
			rg_set_user_team(SecondId, g_arrData[FirstId][Team]);
			rg_set_user_team(FirstId, TEAM_SPECTATOR);
		}
	}
	
	if (!g_Control[FirstId])
		client_print_color(0, print_team_blue, "%s ^3%n^1 was replaced by ^3%n", g_Prefix, SecondId, FirstId);
	
	show_menu(FirstId, 0, "", 1);
}

public task_Response(Parms[], task_id)
{
	new FirstId = Parms[0];
	new SecondId = Parms[1];
	
	if (g_Invited[SecondId])
	{
		g_Invited[SecondId] = false;
		
		Menu(FirstId);
		client_print_color(FirstId, SecondId, "%s Player ^3%n^1 didn't chose anything", g_Prefix, SecondId);
		
		show_menu(SecondId, 0, "", 1);
		client_print_color(SecondId, print_team_blue, "%s Time expired", g_Prefix);
	}
	
	return;
}
