#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "HippoGameInstance.generated.h"

class AHippoCharacter;
class UHippoSaveGame;

UCLASS()
class HIPPOOS_API UHippoGameInstance : public UGameInstance
{
    GENERATED_BODY()

public:
    virtual void Init() override;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Save") FString SaveSlotName = TEXT("HippoOS_Main");
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Save") int32 UserIndex = 0;

    UFUNCTION(BlueprintCallable) bool SaveHippo(AHippoCharacter* Hippo);
    UFUNCTION(BlueprintCallable) bool LoadHippo(AHippoCharacter* Hippo);
    UFUNCTION(BlueprintPure) float GetOfflineMinutes() const;

private:
    UPROPERTY() TObjectPtr<UHippoSaveGame> CachedSave;
    FDateTime LoadedLastSaveUtc;
};
