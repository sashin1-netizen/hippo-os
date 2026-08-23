#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "HippoTypes.h"
#include "HippoPersonalityComponent.generated.h"

UCLASS(ClassGroup=(Hippo), meta=(BlueprintSpawnableComponent))
class HIPPOOS_API UHippoPersonalityComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UHippoPersonalityComponent();

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Personality")
    FHippoPersonality Personality;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Personality")
    int32 PersonalitySeed = 0;

    UFUNCTION(BlueprintCallable) void GeneratePersonality(int32 Seed);
    UFUNCTION(BlueprintPure) float GetActionMultiplier(EHippoAction Action) const;
};
