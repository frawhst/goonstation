//TODO: let living objects use special attacks that would be cool as hell
/obj/item/attackdummy
	name = "attack dummy"
	hit_type = DAMAGE_BLUNT
	force = 5
	throwforce = 5

/mob/living/object
	name = "living object"
	var/obj/possessed_thing //possessed thing which is PROBABLY an object. We error out in New() if it isn't.
	var/obj/item/possessed_item //if the possessed thing is an item, this var is set to it.
	var/mob/owner //mob who's driving this. makkes sense for wraiths, but humans can also get stuffed in. very silly.
	var/obj/item/attackdummy/dummy //dummy attack, used for non-items so they have something to slap people with
	var/datum/hud/object/hud
	density = 0
	canmove = 1
	use_stamina = FALSE
	flags = FPRINT | NO_MOUSEDROP_QOL

	blinded = FALSE
	anchored = FALSE
	a_intent = "disarm"
	var/name_prefix = "living "

	New(var/atom/loc, var/obj/possessed, var/mob/controller)
		..(loc, null, null)

		if (isitem(possessed))
			src.possessed_item = possessed
		src.possessed_thing = possessed

		src.hud = new(src)
		src.attach_hud(hud)
		src.zone_sel = new(src)
		src.attach_hud(zone_sel)

		if (controller)
			message_admins("[key_name(controller)] possessed [possessed_thing] at [log_loc(loc)].")

		if (src.possessed_item)
			src.possessed_item.cant_drop = TRUE
			src.max_health = 25 * src.possessed_item.w_class
			src.health = 25 * src.possessed_item.w_class
		else
			if (isobj(possessed_thing))
				src.dummy = new /obj/item/attackdummy(src)
				src.dummy.name = possessed_thing.name
				src.dummy.cant_drop = TRUE
				src.max_health = 100
				src.health = 100
			else
				stack_trace("Tried to create a possessed object from invalid thing [src.possessed_thing] of type [src.possessed_thing.type]!")
				boutput(controller, "<h3 class='alert'>Uh oh, you tried to possess something illegal! Here's a toolbox instead!</h3>")
				src.possessed_thing = new /obj/item/storage/toolbox/artistic


		set_loc(get_turf(src.possessed_thing))
		possessed_thing.set_loc(src)

		//Appearance Stuff
		src.update_icon()
		src.desc = possessed_thing.desc
		src.pixel_x = possessed_thing.pixel_x
		src.pixel_y = possessed_thing.pixel_y
		src.set_density(possessed_thing.density)
		src.RL_SetOpacity(possessed_thing.opacity)
		src.create_submerged_images()
		src.flags = possessed_thing.flags
		src.event_handler_flags = src.flags
		//this is a mistake
		src.bound_height = possessed_thing.bound_height
		src.bound_width = possessed_thing.bound_width

		//Relay these signals
		RegisterSignal(src.possessed_thing, COMSIG_ATOM_POST_UPDATE_ICON, /atom/proc/UpdateIcon)

		src.owner = controller
		if (src.owner)
			if (!src.owner.mind) //what the fuck
				src.death(TRUE)
				return
			src.owner.set_loc(src)
			src.owner.mind.transfer_to(src)

		src.visible_message("<span class='alert'><b>[src.possessed_thing] comes to life!</b></span>")
		animate_levitate(src, -1, 20, 1)
		APPLY_ATOM_PROPERTY(src, PROP_MOB_STUN_RESIST_MAX, "living_object", 100)
		APPLY_ATOM_PROPERTY(src, PROP_MOB_STUN_RESIST, "living_object", 100)

		remove_lifeprocess(/datum/lifeprocess/blindness)
		remove_lifeprocess(/datum/lifeprocess/viruses)
		remove_lifeprocess(/datum/lifeprocess/blood)
		remove_lifeprocess(/datum/lifeprocess/breath)

	mouse_drop(atom/over_object, src_location, over_location, over_control, params)
		src.possessed_thing.MouseDrop(over_object, src_location, over_location, over_control, params)

	MouseDrop_T(atom/dropped, mob/user)
		return src.possessed_thing._MouseDrop_T(dropped, user)

	disposing()
		REMOVE_ATOM_PROPERTY(src, PROP_MOB_STUN_RESIST, "living_object")
		REMOVE_ATOM_PROPERTY(src, PROP_MOB_STUN_RESIST_MAX, "living_object")
		..()

	Exited(var/atom/movable/AM, var/atom/newloc)
		if (AM == src.possessed_thing && newloc != src)
			src.death(FALSE) //uh oh
			boutput(src, "<span class='alert'>You feel yourself being ripped away from this object!</h1>") //no destroying spacetime

	equipped()
		if (src.possessed_item)
			return src.possessed_item
		else
			return src.dummy

	get_desc()
		. = ..()
		. += "<span class='alert'>It seems to be alive.</span><br>"
		if (src.health < src.max_health * 0.5)
			. += "<span class='notice'>The ethereal grip on this object appears to be weakening.</span>"

	meteorhit(var/obj/O as obj)
		src.death(TRUE)

	updatehealth()
		return

	is_spacefaring()
		// Let's just say it's powered by ethereal bullshit like ghost farts.
		return TRUE

	clamp_values()
		delStatus("slowed")
		sleeping = 0
		change_misstep_chance(-INFINITY)
		src.delStatus("drowsy")
		dizziness = 0
		is_dizzy = 0
		is_jittery = 0
		jitteriness = 0


	bullet_act(var/obj/projectile/P)
		var/damage = 0
		damage = round((P.power*P.proj_data.ks_ratio), 1.0)

		switch (P.proj_data.damage_type)
			if (D_KINETIC)
				src.TakeDamage(null, damage, 0)
			if (D_PIERCING)
				src.TakeDamage(null, damage / 2.0, 0)
			if (D_SLASHING)
				src.TakeDamage(null, damage, 0)
			if (D_BURNING)
				src.TakeDamage(null, 0, damage)
			if (D_ENERGY)
				src.TakeDamage(null, 0, damage)

		if(!P.proj_data.silentshot)
			src.visible_message("<span class='alert'>[src] is hit by the [P]!</span>")

	blob_act(var/power)
		logTheThing("combat", src, null, "is hit by a blob")
		if (isdead(src) || src.nodamage)
			return

		var/modifier = power / 20
		var/damage = rand(modifier, 12 + 8 * modifier)

		src.TakeDamage(null, damage, 0)

		src.show_message("<span class='alert'>The blob attacks you!</span>")

	attack_hand(mob/user)
		if (user.a_intent == "help")
			user.visible_message("<span class='alert'>[user] pets [src]!</span>")
		else
			..()

	TakeDamage(zone, brute, burn, tox, damage_type, disallow_limb_loss)
		health -= burn
		health -= brute
		health = min(max_health, health)
		if (src.health <= 0)
			src.death(FALSE)

	HealDamage(zone, brute, burn)
		TakeDamage(zone, -brute, -burn)

	change_eye_blurry(var/amount, var/cap = 0)
		if (amount < 0)
			return ..()
		else
			return 1

	take_eye_damage(var/amount, var/tempblind = 0)
		if (amount < 0)
			return ..()
		else
			return 1

	take_ear_damage(var/amount, var/tempdeaf = 0)
		if (amount < 0)
			return ..()
		else
			return 1

	click(atom/target, params)
		if (target == src)
			src.self_interact()
		else
			. = ..()

	proc/self_interact()
		if (src.possessed_item)
			src.possessed_item.AttackSelf(src)
		else
			src.possessed_thing.Attackhand(src)
		//To reflect updates of the items appearance etc caused by interactions.
		src.update_density()
		src.item_position_check()

	death(gibbed)

		if (src.possessed_thing && !gibbed)
			src.possessed_thing.set_dir(src.dir)
			if (src.possessed_thing.loc == src)
				src.possessed_thing.set_loc(get_turf(src))
			if (src.possessed_item)
				possessed_item.cant_drop = initial(possessed_item.cant_drop)

		if (src.owner)
			src.owner.set_loc(get_turf(src))
			src.visible_message("<span class='alert'><b>[src] is no longer possessed.</b></span>")

			if (src.mind)
				mind.transfer_to(src.owner)
			else if (src.client)
				src.client.mob = src.owner
			else
				src.owner.key = src.key
		else
			if(src.mind || src.client)
				var/mob/dead/observer/O = new/mob/dead/observer()
				O.set_loc(get_turf(src))
				if (isrestrictedz(src.z) && !restricted_z_allowed(src, get_turf(src)) && !(src.client && src.client.holder))
					var/OS = pick_landmark(LANDMARK_OBSERVER, locate(1, 1, 1))
					if (OS)
						O.set_loc(OS)
					else
						O.z = 1
				if (src.client)
					src.client.mob = O
				O.name = src.name
				O.real_name = src.real_name
				if (src.mind)
					src.mind.transfer_to(O)

		playsound(src.loc, "sound/voice/wraith/wraithleaveobject.ogg", 40, 1, -1, 0.6)

		for (var/atom/movable/AM in src.contents)
			AM.set_loc(src.loc)

		if (gibbed)
			qdel(src.possessed_thing)

		src.owner = null
		src.possessed_thing = null
		qdel(src)
		..()

	movement_delay()
		return 4 + movement_delay_modifier

	item_attack_message(var/mob/T, var/obj/item/S, var/d_zone)
		if (d_zone)
			return "<span class='alert'><B>[src] attacks [T] in the [d_zone]!</B></span>"
		else
			return "<span class='alert'><B>[src] attacks [T]!</B></span>"

	return_air()
		return loc?.return_air()

	assume_air(datum/air_group/giver)
		return loc?.assume_air(giver)

	can_strip()
		return FALSE

	Cross(atom/movable/mover) //Makes radioactive stuff work. Also glass shards and whatever
		return src.possessed_thing.Cross(mover)

	update_icon()
		..()
		src.appearance = src.possessed_thing.appearance
		src.name = "[name_prefix][src.possessed_thing.name]"
		src.real_name = src.name

	///Ensure the item is still inside us. If it isn't, die and return false. Otherwise, return true.
	proc/item_position_check()
		if (!src.possessed_thing || src.possessed_thing.loc != src) //item somewhere else? we no longer exist
			boutput(src, "<span class='alert'>You feel yourself being ripped away from this object!</h1>")
			src.death(0)
			return FALSE
		return TRUE

	///Update the density of ourselves
	proc/update_density()
		src.density = src.possessed_thing.density

/mob/living/object/ai_controlled
	is_npc = 1
	New()
		..()
		src.ai = new /datum/aiHolder/living_object(src)

	death(var/gibbed)
		qdel(src.ai)
		src.ai = null
		..()




// Extremely simple AI for living objects.
// Essentially:
// 1. Is there a person to hit? If yes, go hit the closest person. If no, wander around
// 2. Repeat
/datum/aiHolder/living_object
	exclude_from_mobs_list = TRUE

/datum/aiHolder/living_object/New()
	..()
	var/datum/aiTask/timed/targeted/living_object/attack = get_instance(/datum/aiTask/timed/targeted/living_object, list(src))
	var/datum/aiTask/timed/wander/wander = get_instance(/datum/aiTask/timed/wander, list(src))
	default_task = attack
	attack.transition_task = attack
	// wander.transition_task = attack

/datum/aiHolder/living_object/was_harmed(obj/item/W, mob/M)
	. = ..()
	if (!src.target)
		src.target = M
	src.current_task = default_task


// /datum/aiTask/prioritizer/living_object/New() // immediately do violence if someone is nearby, otherwise wander
// 	src.transition_tasks += get_instance()
// 	src.transition_tasks += get_instance(/datum/aiTask/timed/wander, list(holder, src))

/datum/aiTask/timed/targeted/living_object
	name = "attack"
	minimum_task_ticks = 8
	maximum_task_ticks = 20
	frustration_threshold = 2

/datum/aiTask/timed/targeted/living_object/get_targets()
	var/list/humans = list() // Only care about humans since that's all wraiths eat. TODO maybe borgs too?
	for (var/mob/living/carbon/human/H in view(src.target_range, src.holder.owner))
		if (isalive(H) && !H.nodamage)
			humans += H
	return humans

/datum/aiTask/timed/targeted/living_object/evaluate() //always attack if we can see a person
	return length(get_targets()) ? 999 : 0

/datum/aiTask/timed/targeted/living_object/on_tick() //TODO make sure we don't keep beating dead dudes
	. = ..()
	// see if we can find someone
	if (!holder.target)
		var/list/possible = get_targets()
		if (length(possible))
			holder.target = pick(possible)
	if (!holder.target) // we didn't find anyone, wander around
		holder.owner.move_dir = pick(alldirs)
		holder.owner.process_move()
		return
	var/mob/living/object/spooker = holder.owner
	process_special_intent()
	spooker.hud.update_intent()
	if (BOUNDS_DIST(holder.target, holder.owner))
		holder.move_to(holder.target)
	else
		attack_twitch(src)
		holder.owner.weapon_attack(holder.target, holder.owner.equipped(), TRUE)

/datum/aiTask/timed/targeted/living_object/frustration_check()
	.= 0
	if (holder)
		if (!IN_RANGE(holder.owner, holder.target, target_range))
			return 1

		if (ismob(holder.target))
			var/mob/M = holder.target
			. = !(holder.target && isalive(M))
		else
			. = !(holder.target)

/// For items with special intent, bodypart, etc targeting requirements. Mostly for batons, but do tack on any other edge cases.
/datum/aiTask/timed/targeted/living_object/proc/process_special_intent()
	var/mob/living/object/spooker = holder.owner
	if (istype(spooker.possessed_thing, /obj/item/baton))
		var/obj/item/baton/bat = spooker.possessed_thing
		if (!bat.is_active)
			spooker.self_interact() // (attempt to) turn that shit on
		if (!(SEND_SIGNAL(bat, COMSIG_CELL_CHECK_CHARGE, bat.cost_normal) & CELL_SUFFICIENT_CHARGE)) // Not enough charge for a hit
			spooker.set_a_intent(INTENT_HARM) // harmbaton
		else
			spooker.set_a_intent(INTENT_DISARM) // have charge, baton normally
	else if (istype(spooker.possessed_thing, /obj/item/sword))
		var/obj/item/sword/saber = spooker.possessed_thing
		if (!saber.active)
			spooker.self_interact() // turn that sword on
		spooker.set_a_intent(INTENT_HARM)
	else if(istype(spooker.possessed_thing, /obj/item/gun))
		var/obj/item/gun/pew = spooker.possessed_thing
		if (pew.canshoot())
			spooker.set_a_intent(INTENT_HARM) // we can shoot, so... shoot
		else
			spooker.set_a_intent(INTENT_HELP) // otherwise go on help for gun whipping
	else
		spooker.set_a_intent(INTENT_HARM)

	//TODO katana limb targeting, make guns fire at range?, c saber deflect (if possible i forget if arbitrary mobs can block)

/datum/aiTask/timed/wander/living_object //shorter so we're more responsive
	minimum_task_ticks = 1
	maximum_task_ticks = 5
