# Hippo OS — Three Species Simulation

## Product rule

The app contains three deeply simulated animals only:

1. Baby pygmy hippo
2. Pig
3. Chinese Shar-Pei

They must not share one generic pet brain. Species biology constrains behaviour, individual temperament creates variation, and learned experience creates history.

```text
SPECIES ETHOLOGY
      +
INDIVIDUAL TEMPERAMENT
      +
CURRENT NEEDS
      +
EMOTIONAL STATE
      +
MEMORY
      +
OWNER RELATIONSHIP
      +
ANIMAL RELATIONSHIPS
      +
TIME / ENVIRONMENT
      ↓
DECISION
      ↓
MOVEMENT + BODY LANGUAGE + AUDIO
```

## Baby pygmy hippo

Core tendencies:
- solitary / low social dependence
- strong water and cover preference
- resting and concealment during much of the day
- increased activity around dusk/night
- browsing / foraging
- wallowing and water use
- habitual paths and preferred rest zones
- curiosity tempered by security
- interaction is trust-based, not obedience-based
- can disengage from unwanted attention

Hidden drives:
- security
- water
- forage
- novelty
- social tolerance
- rest

Signature behaviours:
- enter/leave pond
- partially submerge
- wallow
- forage
- investigate scent
- hide/rest under cover
- approach owner only when sufficiently comfortable
- short juvenile play bursts / zoomies
- discreet territory-marking event system

## Pig

Core tendencies:
- highly exploratory and social
- strong food motivation
- extensive rooting and substrate investigation
- manipulates objects with snout
- strong spatial memory
- enrichment-seeking
- mud use and rubbing/scratching
- learns food and object associations quickly

Hidden drives:
- rooting
- food
- novelty
- social contact
- manipulation
- mud
- rest

Signature behaviours:
- root
- forage
- push/flip object
- remember food location
- investigate novel object
- wallow
- social contact
- carry/nudge enrichment
- playful burst

## Chinese Shar-Pei

Core tendencies:
- strong family bond with meaningful independence
- calm / observant baseline
- reserved around unfamiliar stimuli
- watchful rather than continuously hyperactive
- follows owner selectively
- rests nearby without demanding contact
- brief play periods
- may withdraw when interaction becomes unwanted

Hidden drives:
- owner bond
- watchfulness
- independence
- rest
- caution
- play

Signature behaviours:
- observe
- follow owner
- rest near owner
- patrol
- inspect sound/stimulus
- approach owner
- withdraw
- brief play / zoomies
- alert posture / context-sensitive bark

## Emotional model

All three animals use the same emotional dimensions but species interpret them differently:

- valence: unpleasant ↔ pleasant
- arousal: relaxed ↔ activated
- security: threatened ↔ safe
- social motivation: avoid ↔ engage
- curiosity: familiar ↔ investigate

## Learned owner relationship

Persist per animal:
- familiarity
- trust
- interaction history
- learned touch preferences
- food preferences
- activity preferences
- preferred zones
- recent annoyance
- recent reward

A high bond never forces obedience. Species limits remain authoritative.

## Inter-animal relationships

Each pair stores:
- familiarity
- trust
- interest
- avoidance
- play compatibility
- resource tension
- preferred distance
- encounter count

Cross-species interaction should be supervised and occasional. The default sanctuary layout keeps the animals in biologically appropriate primary zones.

## Sanctuary topology

### Pygmy hippo zone
- pond
- shallow water
- mud/wallow
- dense cover
- browse trail
- secluded rest areas

### Pig zone
- rooting substrate
- mud
- shelter
- enrichment objects
- forage scatter
- social resting area

### Shar-Pei zone
- home/yard
- shaded bed/rest area
- observation points
- garden path
- owner interaction area

### Shared transition ground
Used for controlled cross-species encounters rather than permanent unrestricted mixing.

## Audio architecture

Audio events are contextual, not random.

Pygmy hippo:
- grunt
- snort
- exhale
- breathing
- chewing
- water entry
- splash
- mud
- footsteps

Pig:
- exploration grunt
- contact grunt
- snuffle
- bark/alarm context
- rooting
- chewing
- drinking
- mud
- footsteps

Shar-Pei:
- sniffing
- breathing
- panting where appropriate
- quiet vocalisation
- alert bark
- play bark
- drinking
- eating
- footsteps

## Release requirement

A species is not considered implemented merely because a model exists. It must pass:
- species-specific decision tests
- species-specific idle behaviour
- locomotion
- body language
- audio context
- touch preferences
- owner relationship persistence
- rejection/withdrawal behaviour
- time-of-day influence
- save/load
- on-device Android testing
