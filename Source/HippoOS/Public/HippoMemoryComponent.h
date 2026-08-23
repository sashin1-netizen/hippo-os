#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "HippoTypes.h"
#include "HippoMemoryComponent.generated.h"

UCLASS(ClassGroup=(Hippo), meta=(BlueprintSpawnableComponent))
class HIPPOOS_API UHippoMemoryComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UHippoMemoryComponent();

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Memory") int32 SessionCount = 0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Memory") float Bond = 0.35f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Memory") TArray<FHippoInteractionRecord> Interactions;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Memory") FDateTime LastSeenUtc;

    UFUNCTION(BlueprintCallable) void RecordInteraction(EHippoInteractionType Type, float AffinityDelta);
    UFUNCTION(BlueprintPure) int32 GetInteractionCount(EHippoInteractionType Type) const;
};
