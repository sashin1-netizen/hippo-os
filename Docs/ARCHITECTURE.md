# Hippo OS Architecture

## Prime directive

The animal simulation is authoritative. Animation, sound, VFX and UI are presentation layers that observe simulation state.

## Runtime domains

```text
AHippoCharacter
├── UHippoNeedsComponent
├── UHippoPersonalityComponent
├── UHippoMemoryComponent
└── UHippoBrainComponent

UHippoGameInstance
└── persistent save / offline simulation

AHippoAIController
└── movement and action execution

AHippoPlayerController
└── touch traces / pet gestures / camera input

AHippoSanctuaryManager
└── environment state / autosave / world orchestration
```

## Needs

Normalized values `[0,1]`:

- Hunger: `0 = full`, `1 = urgent hunger`
- Energy: `0 = exhausted`, `1 = rested`
- Affection: current social warmth
- Curiosity: stimulation/arousal
- Cleanliness: mud/wet presentation input

## Personality

Persistent traits:

- Mischief
- Affectionateness
- Energy
- Curiosity
- Stubbornness
- Boldness

A seeded personality is generated once and saved. Traits modify action utility rather than directly choosing behaviour.

## Memory

Persist:

- bond
- session count
- interaction counts
- interaction affinity
- last-seen timestamp
- favourite interaction
- later: learned routines and significant events

## Utility AI

Candidate actions include:

- Idle
- Wander
- ApproachPlayer
- SeekFood
- Sleep
- Explore
- Play
- EnterWater
- Zoomies

Each action computes utility from needs, personality, relationship, world opportunities, cooldowns and bounded noise. Imperfect predictability is intentional.

## Offline simulation

On save, persist UTC time. On load, calculate elapsed time and advance needs with a capped simulation window. The pet can rest while away. Absence never causes death or catastrophic relationship loss.

## Presentation stack

`ABP_HippoBaby` should eventually layer:

1. locomotion
2. full-body action montage
3. breathing
4. ear motion
5. head look-at
6. eye tracking
7. facial morphs
8. touch response

## Mobile rule

Optimise the environment before degrading the hero animal's face. One convincing character is the product.
