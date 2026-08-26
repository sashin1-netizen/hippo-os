#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "HippoTypes.h"
#include "HippoBrainComponent.generated.h"

class UHippoNeedsComponent;
class UHippoPersonalityComponent;
class UHippoMemoryComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FHippoActionSelected, EHippoAction, Action, float, Score);

UCLASS(ClassGroup=(Hippo), meta=(BlueprintSpawnableComponent))
class HIPPOOS_API UHippoBrainComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UHippoBrainComponent();
    virtual void BeginPlay() override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    UPROPERTY(BlueprintReadOnly, Category="Hippo|Brain")
    EHippoAction CurrentAction = EHippoAction::Idle;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Brain")
    float DecisionIntervalSeconds = 2.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Brain|Learning")
    TMap<EHippoAction, float> LearnedActionAffinity;

    UPROPERTY(BlueprintAssignable)
    FHippoActionSelected OnActionSelected;

    UFUNCTION(BlueprintCallable)
    void DecideNow();

    UFUNCTION(BlueprintPure)
    float ScoreAction(EHippoAction Action) const;

    UFUNCTION(BlueprintCallable, Category="Hippo|Brain|Learning")
    void ReinforceAction(EHippoAction Action, float Amount);

    UFUNCTION(BlueprintCallable, Category="Hippo|Brain|Priority")
    void SetActionOverride(EHippoAction Action, float DurationSeconds = 4.0f);

    UFUNCTION(BlueprintCallable, Category="Hippo|Brain|Priority")
    void ClearActionOverride();

    UFUNCTION(BlueprintPure, Category="Hippo|Brain|Priority")
    bool HasActionOverride() const { return OverrideRemainingSeconds > 0.0f; }

private:
    UPROPERTY() TObjectPtr<UHippoNeedsComponent> Needs;
    UPROPERTY() TObjectPtr<UHippoPersonalityComponent> Personality;
    UPROPERTY() TObjectPtr<UHippoMemoryComponent> Memory;

    EHippoAction OverrideAction = EHippoAction::Idle;
    float OverrideRemainingSeconds = 0.0f;
    float DecisionClock = 0.0f;
};