#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "HippoSanctuaryManager.generated.h"

class AHippoCharacter;
class USceneComponent;
class UStaticMeshComponent;

UCLASS()
class HIPPOOS_API AHippoSanctuaryManager : public AActor
{
    GENERATED_BODY()

public:
    AHippoSanctuaryManager();
    virtual void BeginPlay() override;

    UPROPERTY(BlueprintReadOnly, Category="Hippo|Sanctuary") TObjectPtr<AHippoCharacter> Hippo;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Sanctuary") float AutoSaveIntervalSeconds = 45.0f;

    UFUNCTION(BlueprintCallable) bool SaveNow();

private:
    UPROPERTY() TObjectPtr<USceneComponent> Root;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Ground;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Pond;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> MudPatch;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> RockA;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> RockB;
    FTimerHandle AutoSaveTimer;
};
