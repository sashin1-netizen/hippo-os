extends RefCounted

const PYGMY_HIPPO = "pygmy_hippo"
const PIG = "pig"
const SHAR_PEI = "shar_pei"

static func all_species():
    return [PYGMY_HIPPO, PIG, SHAR_PEI]

static func default_name(species_id):
    if species_id == PYGMY_HIPPO:
        return "Mochi"
    if species_id == PIG:
        return "Truffle"
    if species_id == SHAR_PEI:
        return "Bao"
    return "Animal"

static func profile(species_id):
    if species_id == PYGMY_HIPPO:
        return {
            "display_name": "Pygmy Hippo",
            "activity_peak": "dusk_night",
            "social_style": "solitary_tolerant",
            "base_speed": 0.85,
            "burst_speed": 2.9,
            "needs": {
                "water_drive": 0.90,
                "security_drive": 0.84,
                "forage_drive": 0.70,
                "social_drive": 0.36,
                "novelty_drive": 0.48,
                "rest_drive": 0.72
            },
            "behaviour_weights": {
                "hide": 0.72,
                "wallow": 0.78,
                "enter_water": 0.90,
                "forage": 0.74,
                "rest": 0.76,
                "approach_owner": 0.36,
                "investigate": 0.48,
                "play": 0.36,
                "zoomies": 0.20,
                "mark_territory": 0.32
            },
            "touch_preferences": {
                "forehead": 0.75,
                "cheek": 0.55,
                "snout": 0.40,
                "back": 0.62,
                "belly": 0.18,
                "ears": 0.48
            },
            "audio_events": ["grunt", "snort", "exhale", "chew", "splash", "mud", "footstep"]
        }

    if species_id == PIG:
        return {
            "display_name": "Pig",
            "activity_peak": "day_evening",
            "social_style": "highly_social",
            "base_speed": 1.05,
            "burst_speed": 3.1,
            "needs": {
                "rooting_drive": 0.94,
                "food_drive": 0.88,
                "social_drive": 0.80,
                "novelty_drive": 0.86,
                "mud_drive": 0.68,
                "rest_drive": 0.56
            },
            "behaviour_weights": {
                "root": 0.94,
                "forage": 0.90,
                "investigate": 0.88,
                "push_object": 0.82,
                "wallow": 0.64,
                "approach_owner": 0.62,
                "social_contact": 0.76,
                "rest": 0.48,
                "play": 0.65,
                "zoomies": 0.38
            },
            "touch_preferences": {
                "forehead": 0.55,
                "cheek": 0.62,
                "snout": 0.30,
                "back": 0.78,
                "belly": 0.45,
                "ears": 0.52
            },
            "audio_events": ["grunt", "contact_grunt", "snuffle", "bark", "chew", "root", "mud", "footstep"]
        }

    if species_id == SHAR_PEI:
        return {
            "display_name": "Chinese Shar-Pei",
            "activity_peak": "day_evening",
            "social_style": "family_bonded_independent",
            "base_speed": 1.20,
            "burst_speed": 3.6,
            "needs": {
                "owner_bond_drive": 0.82,
                "watch_drive": 0.76,
                "rest_drive": 0.68,
                "play_drive": 0.50,
                "novelty_drive": 0.42,
                "stranger_caution": 0.70
            },
            "behaviour_weights": {
                "follow_owner": 0.72,
                "observe": 0.82,
                "rest_near_owner": 0.76,
                "patrol": 0.58,
                "investigate": 0.44,
                "play": 0.50,
                "zoomies": 0.30,
                "approach_owner": 0.68,
                "withdraw": 0.42
            },
            "touch_preferences": {
                "forehead": 0.62,
                "cheek": 0.66,
                "snout": 0.34,
                "back": 0.72,
                "belly": 0.28,
                "ears": 0.40
            },
            "audio_events": ["sniff", "breath", "pant", "quiet_vocal", "alert_bark", "play_bark", "drink", "footstep"]
        }

    return {}

static func default_temperament(species_id):
    if species_id == PYGMY_HIPPO:
        return {
            "boldness": 0.42,
            "curiosity": 0.58,
            "social_tolerance": 0.48,
            "routine_preference": 0.78,
            "playfulness": 0.50,
            "food_motivation": 0.58
        }
    if species_id == PIG:
        return {
            "boldness": 0.66,
            "curiosity": 0.88,
            "social_tolerance": 0.82,
            "routine_preference": 0.56,
            "playfulness": 0.70,
            "food_motivation": 0.90
        }
    if species_id == SHAR_PEI:
        return {
            "boldness": 0.62,
            "curiosity": 0.44,
            "social_tolerance": 0.58,
            "routine_preference": 0.72,
            "playfulness": 0.48,
            "food_motivation": 0.52,
            "independence": 0.78,
            "watchfulness": 0.80
        }
    return {}
