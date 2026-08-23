#include "HippoBrainComponent.h"
#include "HippoNeedsComponent.h"
#include "HippoPersonalityComponent.h"
#include "HippoMemoryComponent.h"

UHippoBrainComponent::UHippoBrainComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
}

void UHippoBrainComponent::BeginPlay()
{
    Super::BeginPlay();
    AActor* Owner = GetOwner();
    Needs = Owner ? Owner->FindComponentByClass<UHippoNeedsComponent>() : nullptr;
    Personality = Owner ? Owner->FindComponentByClass<UHippoPersonalityComponent>() : nullptr;
    Memory = Owner ? Owner->FindComponentByClass<UHippoMemoryComponent>() : nullptr;
}

void UHippoBrainComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    DecisionClock += DeltaTime;
    if (DecisionClock >= DecisionIntervalSeconds)
    {
        DecisionClock = 0.0f;
        DecideNow();
    }
}

void UHippoBrainComponent::DecideNow()
{
    static const EHippoAction Candidates[] = {
        EHippoAction::Idle,
        EHippoAction::Wander,
        EHippoAction::ApproachPlayer,
        EHippoAction::SeekFood,
        EHippoAction::Sleep,
        EHippoAction::Explore,
        EHippoAction::Play
    };

    EHippoAction BestAction = EHippoAction::Idle;
    float BestScore = -1.0f;

    for (const EHippoAction Candidate : Candidates)
    {
        const float Score = ScoreAction(Candidate);
        if (Score > BestScore)
        {
            BestScore = Score;
            BestAction = Candidate;
        }
    }

    CurrentAction = BestAction;
    OnActionSelected.Broadcast(CurrentAction, BestScore);
}

float UHippoBrainComponent::ScoreAction(EHippoAction Action) const
{
    if (!Needs) return 0.0f;

    const FHippoNeedsSnapshot& N = Needs->Needs;
    const float Bond = Memory ? Memory->Bond : 0.35f;
    float Score = 0.0f;

    switch (Action)
    {
        case EHippoAction::Idle: Score = 0.18f + (1.0f - N.Curiosity) * 0.12f; break;
        case EHippoAction::Wander: Score = 0.25f + N.Energy * 0.25f + (1.0f - N.Curiosity) * 0.20f; break;
        case EHippoAction::ApproachPlayer: Score = 0.15f + Bond * 0.45f + N.Affection * 0.20f; break;
        case EHippoAction::SeekFood: Score = N.Hunger * 0.95f; break;
        case EHippoAction::Sleep: Score = (1.0f - N.Energy) * 1.05f; break;
        case EHippoAction::Explore: Score = (1.0f - N.Curiosity) * 0.65f + N.Energy * 0.20f; break;
        case EHippoAction::Play: Score = N.Energy * 0.35f + N.Curiosity * 0.25f + Bond * 0.15f; break;
        default: break;
    }

    if (Personality)
    {
        Score *= Personality->GetActionMultiplier(Action);
    }

    Score += FMath::FRandRange(-0.035f, 0.035f);
    return FMath::Max(0.0f, Score);
}
