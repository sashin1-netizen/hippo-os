#include "HippoPersonalityComponent.h"

UHippoPersonalityComponent::UHippoPersonalityComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UHippoPersonalityComponent::GeneratePersonality(int32 Seed)
{
    PersonalitySeed = Seed;
    FRandomStream Stream(Seed);

    Personality.Mischief = Stream.FRandRange(0.25f, 0.95f);
    Personality.Affectionateness = Stream.FRandRange(0.45f, 0.95f);
    Personality.Energy = Stream.FRandRange(0.40f, 0.95f);
    Personality.Curiosity = Stream.FRandRange(0.45f, 0.95f);
    Personality.Stubbornness = Stream.FRandRange(0.15f, 0.90f);
    Personality.Boldness = Stream.FRandRange(0.30f, 0.95f);
}

float UHippoPersonalityComponent::GetActionMultiplier(EHippoAction Action) const
{
    switch (Action)
    {
        case EHippoAction::ApproachPlayer:
            return FMath::Lerp(0.70f, 1.45f, Personality.Affectionateness);
        case EHippoAction::Explore:
            return FMath::Lerp(0.70f, 1.40f, Personality.Curiosity);
        case EHippoAction::Play:
            return FMath::Lerp(0.75f, 1.50f, Personality.Energy);
        case EHippoAction::Zoomies:
            return FMath::Lerp(0.60f, 1.65f, (Personality.Energy + Personality.Mischief) * 0.5f);
        case EHippoAction::Wander:
            return FMath::Lerp(0.85f, 1.20f, Personality.Curiosity);
        default:
            return 1.0f;
    }
}
