#include "HippoMemoryComponent.h"

UHippoMemoryComponent::UHippoMemoryComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UHippoMemoryComponent::RecordInteraction(EHippoInteractionType Type, float AffinityDelta)
{
    FHippoInteractionRecord* Found = Interactions.FindByPredicate(
        [Type](const FHippoInteractionRecord& Record) { return Record.Type == Type; });

    if (!Found)
    {
        FHippoInteractionRecord NewRecord;
        NewRecord.Type = Type;
        Interactions.Add(NewRecord);
        Found = &Interactions.Last();
    }

    Found->Count++;
    Found->Affinity += AffinityDelta;
    Bond = FMath::Clamp(Bond + AffinityDelta * 0.05f, 0.0f, 1.0f);
    LastSeenUtc = FDateTime::UtcNow();
}

int32 UHippoMemoryComponent::GetInteractionCount(EHippoInteractionType Type) const
{
    const FHippoInteractionRecord* Found = Interactions.FindByPredicate(
        [Type](const FHippoInteractionRecord& Record) { return Record.Type == Type; });

    return Found ? Found->Count : 0;
}
