#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "HippoTypes.h"
#include "HippoNeedsComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FHippoNeedsChanged, const FHippoNeedsSnapshot&, NewNeeds);

UCLASS(ClassGroup=(Hippo), meta=(BlueprintSpawnableComponent))
class HIPPOOS_API UHippoNeedsComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UHippoNeedsComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Needs")
    FHippoNeedsSnapshot Needs;

    UPROPERTY(BlueprintAssignable)
    FHippoNeedsChanged OnNeedsChanged;

    UFUNCTION(BlueprintCallable) void ApplyPetting(float Strength = 1.0f);
    UFUNCTION(BlueprintCallable) void ApplyFeeding(float Nutrition = 0.25f);
    UFUNCTION(BlueprintCallable) void ApplySleep(float RestoredEnergy);
    UFUNCTION(BlueprintCallable) void SimulateOffline(float ElapsedMinutes);

private:
    void ClampNeeds();
};
