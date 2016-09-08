/obj/HUD
	icon = 'images/HUD.dmi'
	mouse_opacity = 0
	layer = 20
	var/menu_id

	/obj/HUD/New(s_loc, b_name, i_state, m_id)
		..()
		if(s_loc)
			screen_loc = s_loc
		if(b_name)
			name = b_name
		if(i_state)
			icon_state = i_state
		if(m_id)
			menu_id = m_id
			tag = "[menu_id] [screen_loc]"

/world/proc/CREATE_HUD(var/nw_x, var/nw_y, var/se_x, var/se_y, var/m_id, var/close_button)
	var/obj/HUD/H
	var/tmp/list/hud_objects = new/list()

	H = new/obj/HUD(s_loc="[nw_x],[nw_y]",i_state="M_NW",m_id=m_id)
	hud_objects += H

	if(close_button)
		H = new/obj/HUD/Button(s_loc="[se_x],[nw_y]",b_name="Close Window",i_state="M_Close",m_id=m_id)
	else
		H = new/obj/HUD(s_loc="[se_x],[nw_y]",i_state="M_NE",m_id=m_id)
	hud_objects += H

	H = new/obj/HUD(s_loc="[nw_x],[se_y]",i_state="M_SW",m_id=m_id)
	hud_objects += H

	H = new/obj/HUD(s_loc="[se_x],[se_y]",i_state="M_SE",m_id=m_id)
	hud_objects += H



	var/tmp/screen_x = nw_x
	var/tmp/screen_y = nw_y-1

	while(screen_y > se_y)
		if(screen_x == nw_x || screen_x == se_x)
			if(screen_x == nw_x)
				H = new/obj/HUD(s_loc="[screen_x],[screen_y]",i_state="M_W",m_id=m_id)
				hud_objects += H
			if(screen_x == se_x)
				H = new/obj/HUD(s_loc="[screen_x],[screen_y]",i_state="M_E",m_id=m_id)
				hud_objects += H

				screen_y -= 1
				screen_x = nw_x-1
		else
			H = new/obj/HUD(s_loc="[screen_x],[screen_y]",i_state="M_Back",m_id=m_id)
			hud_objects += H

		screen_x += 1



	var/tmp/edgemaker = nw_x+1

	while(edgemaker < se_x)
		H = new/obj/HUD(s_loc="[edgemaker],[nw_y]",i_state="M_N",m_id=m_id)
		hud_objects += H

		H = new/obj/HUD(s_loc="[edgemaker],[se_y]",i_state="M_S",m_id=m_id)
		hud_objects += H

		edgemaker += 1

	world_hud[m_id] = hud_objects