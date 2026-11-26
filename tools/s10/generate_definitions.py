#!/usr/bin/env python3
"""Rebuild S10 ground catalog records from the same physical mount specifications."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPECS = json.loads((ROOT / "data/ground/models.json").read_text())

def write(path, data):
    (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

for ident, spec in SPECS.items():
    coastal = spec["role"] == "coastal_gun"
    weapon_id = spec["mount"]["weapon_definition_id"]
    ammo_id = "s10_us_127mm_51_common_mk15" if coastal else "s10_us_40mm_mkii_het_sd"
    ref = "OP1112 pp162-163, sheet1945-01-15" if coastal else "TM9-252 (1944-01-17), figs1,4,89,161 and ammunition table row9"
    source = {"status":"provisional", "basis":ref, "reference_pack":"docs/references/weapons/"+ident,
              "service_entry_year_status":"unknown", "documented_by_year":1945 if coastal else 1944,
              "limitations":"Exact first-service year of this variant is unconfirmed (0=unknown); configuration date is documentary. Small model dimensions, crew train/elevation rates, durability and finite inventory are explicit simulation estimates, not balance changes."}
    armament = {"weapon_definition_id":weapon_id,"mount_count":1,"barrels_per_mount":1}
    write("data/units/"+ident+".json", {
        "id":ident, "display_name":"5-inch/51 Mk8 Mod0 · Mk13 Mod4" if coastal else "40-mm M1 · M2A1 · M3 sights",
        "country_id":"us", "domain":"ground", "service_entry_year":0, "configuration_date":"1945-01-15" if coastal else "1944-01-17",
        "dimensions_m":spec["dimensions_m"], "model_scene":"res://scenes/ground/"+ident+".tscn",
        "mounts":[spec["mount"]], "weapon_definitions":[],
        "historical_fixed_armament":[armament] if coastal else [],
        "dedicated_aa_game":[] if coastal else [armament],
        "dedicated_aa_historical":[] if coastal else [{"description":"One M1 single barrel on M2A1 carriage, not naval quadruple Bofors", "mount_count":1,"barrels_per_mount":1}],
        "source":source})
    write("data/units/weapons/"+weapon_id+".json",{
        "id":weapon_id,"ammo_id":ammo_id,"barrel_count":1,"cycle_s":8.0 if coastal else .5,
        "initial_rounds_per_barrel":60 if coastal else 240,
        "train_limits_deg":spec["train_limits_deg"],"elevation_limits_deg":spec["elevation_limits_deg"],
        "train_rate_degps":3.0 if coastal else 20.0,"elevation_rate_degps":3.0 if coastal else 8.0,
        "source":{"status":"provisional","basis":ref,"note":"Coast8s crew cycle and all angular speeds are explicit crew-operation estimates. M1 rapid120rpm (.5s) is manual data; no invented continuous powered traverse."}})
    write("data/ammunition/"+ammo_id+".json",{
        "id":ammo_id,"caliber_m":.127 if coastal else .04,"projectile_mass_kg":22.6796185 if coastal else .8890410452,
        "muzzle_speed_mps":960.12 if coastal else 874.776,"gravity_mps2":9.80665,"max_lifetime_s":40 if coastal else 10,
        "source":{"status":"provisional","basis":ref,"note":"50lb Common Mk15 Mod14; impact termination is a simulation approximation, exact filler/fuze not verified" if coastal else "HE-T(SD No12) MkII, PD M64A1, 1.96lb, 2870ft/s, TNT .14lb; fixed8.5s tracer-burn self-destruction approximates manual7-10s. No intercept-timed flak."}})

if __name__ == "__main__":
    print("Rebuilt",len(SPECS),"S10 definitions and independent weapon/ammunition records")
