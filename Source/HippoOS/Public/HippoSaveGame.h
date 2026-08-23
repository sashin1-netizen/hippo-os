#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "HippoTypes.h"
#include "HippoSaveGame.generated.h"

UCLASS()
class HIPPOOS_API UHippoSaveGame : public USaveGame
{
    GENERATED_BODY()

public:
    UPROPERTY(BlueprintReadWrite) FString HippoName = TEXT("Mochi");
    UPROPERTY(BlueprintReadWrite) FHippoNeedsSnapshot Needs;
    UPROPERTY(BlueprintReadWrite) FHippoPersonality Personality;
    UPROPERTY(BlueprintReadWrite) int32 PersonalitySeed = 0;
    UPROPERTY(BlueprintReadWrite) int32 SessionCount = 0;
    UPROPERTY(BlueprintReadWrite) float Bond = 0.35f;
    UPROPERTY(BlueprintReadWrite) TArray<FHippoInteractionRecord> Interactions;
    UPROPERTY(BlueprintReadWrite) FDateTime LastSaveUtc;
};
