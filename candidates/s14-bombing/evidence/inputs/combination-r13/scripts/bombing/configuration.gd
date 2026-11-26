class_name BombingConfiguration
extends RefCounted

## Called before catalog/world install. No implicit scans or production registration.
static func validate(record: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray=[]
	if not SimData.pure_data(record):return ["bombing_finite_pure_data_required"]
	for key: String in ["aircraft","ammunition","ammo_profiles"]:
		if not record.get(key) is Dictionary:return ["bombing_missing_dictionary:"+key]
	for id: String in record.aircraft:
		var p: Dictionary=record.aircraft[id]
		if p.get("mode","") not in ["dive","level"]:errors.append("bombing_invalid_role:"+id)
		if not record.ammunition.has(str(p.get("ammo_id",""))):errors.append("bombing_missing_ammunition:"+id)
		if not p.get("slots_m") is Array or p.slots_m.is_empty() or p.slots_m.size()>16:errors.append("bombing_invalid_slots:"+id)
		for slot: Variant in p.get("slots_m",[]):
			if not SimData.valid_vector(slot):errors.append("bombing_invalid_slot:"+id)
		for key: String in ["interval_s","min_release_agl_m","min_release_mps","max_release_mps","formation_spacing_m"]:
			if not SimData.finite_number(p.get(key)) or float(p[key])<=0:errors.append("bombing_invalid_limit:"+id+":"+key)
	for id: String in record.ammunition:
		var ammo: Dictionary=record.ammunition[id]
		if not record.ammo_profiles.has(id):errors.append("bombing_missing_blast_profile:"+id);continue
		var profile: Dictionary=record.ammo_profiles[id]
		if ammo.get("release_mode","")!="gravity_release" or float(ammo.get("muzzle_speed_mps",-1))!=0:errors.append("bombing_release_mode_required:"+id)
		for key: String in ["blast_radius_m","visual_radius_m","explosive_kg"]:
			if not SimData.finite_number(profile.get(key)) or float(profile[key])<=0:errors.append("bombing_invalid_blast:"+id+":"+key)
		if float(profile.get("blast_radius_m",1000))>100:errors.append("bombing_radius_budget:"+id)
	return errors
