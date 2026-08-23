#include "HippoNeedsComponent.h"

UHippoNeedsComponent::UHippoNeedsComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.TickInterval = 1.0f;
}

void UHippoNeedsComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    const float Minutes = DeltaTime / 60.0f;
    Needs.Hunger += 0.006f * Minutes;
    Needs.Energy -= 0.004f * Minutes;
    Needs.Curiosity -= 0.003f * Minutes;
    ClampNeeds();
    OnNeedsChanged.Broadcast(Needs);
}

void UHippoNeedsComponent::ApplyPetting(float Strength)
{
    Needs.Affection += 0.02f * FMath::Max(0.0f, Strength);
    Needs.Curiosity += 0.005f * FMath::Max(0.0f, Strength);
    ClampNeeds();
    OnNeedsChanged.Broadcast(Needs);
}

void UHippoNeedsComponent::ApplyFeeding(float Nutrition)
{
    Needs.Hunger -= FMath::Max(0.0f, Nutrition);
    ClampNeeds();
    OnNeedsChanged.Broadcast(Needs);
}

void UHippoNeedsComponent::ApplySleep(float RestoredEnergy)
{
    Needs.Energy += FMath::Max(0.0f, RestoredEnergy);
    ClampNeeds();
    OnNeedsChanged.Broadcast(Needs);
}

void UHippoNeedsComponent::SimulateOffline(float ElapsedMinutes)
{
    const float SafeMinutes = FMath::Clamp(ElapsedMinutes, 0.0f, 4320.0f);
    Needs.Hunger += 0.006f * SafeMinutes * 0.55f;
    Needs.Curiosity -= 0.003f * SafeMinutes * 0.60f;
    Needs.Energy += SafeMinutes * 0.0015f;
    ClampNeeds();
    OnNeedsChanged.Broadcast(Needs);
}

void UHippoNeedsComponent::ClampNeeds()
{
    Needs.Hunger = FMath::Clamp(Needs.Hunger, 0.0f, 1.0f);
    Needs.Energy = FMath::Clamp(Needs.Energy, 0.0f, 1.0f);
    Needs.Affection = FMath::Clamp(Needs.Affection, 0.0f, 1.0f);
    Needs.Curiosity = FMath::Clamp(Needs.Curiosity, 0.0f, 1.0f);
    Needs.Cleanliness = FMath::Clamp(Needs.Cleanliness, 0.0f, 1.0f);
}
