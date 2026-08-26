#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "HippoAdaptiveQualityDirector.generated.h"

UENUM(BlueprintType)
enum class EHippoQualityTier : uint8
{
    Low,
    Medium,
    High
};

UCLASS()
class HIPPOOS_API AHippoAdaptiveQualityDirector : public AActor
{
    GENERATED_BODY()

public:
    AHippoAdaptiveQualityDirector();

    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

    UPROPERTY(BlueprintReadOnly, Category="Hippo|Quality")
    EHippoQualityTier CurrentTier = EHippoQualityTier::High;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Quality")
    float EvaluationIntervalSeconds = 2.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Quality")
    float DowngradeBelowFps = 28.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Quality")
    float UpgradeAboveFps = 48.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Quality")
    int32 SamplesBeforeDowngrade = 2;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Quality")
    int32 SamplesBeforeUpgrade = 4;

    UFUNCTION(BlueprintCallable, Category="Hippo|Quality")
    void SetQualityTier(EHippoQualityTier NewTier);

private:
    float AccumulatedTime = 0.0f;
    int32 AccumulatedFrames = 0;
    int32 SlowSamples = 0;
    int32 FastSamples = 0;

    void EvaluatePerformance();
    void ApplyTier(EHippoQualityTier Tier);
    void SetCVar(const TCHAR* Name, int32 Value) const;
    void SetCVar(const TCHAR* Name, float Value) const;
};