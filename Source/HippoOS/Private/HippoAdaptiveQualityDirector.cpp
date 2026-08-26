#include "HippoAdaptiveQualityDirector.h"

#include "HAL/IConsoleManager.h"

AHippoAdaptiveQualityDirector::AHippoAdaptiveQualityDirector()
{
    PrimaryActorTick.bCanEverTick = true;
    SetActorEnableCollision(false);
}

void AHippoAdaptiveQualityDirector::BeginPlay()
{
    Super::BeginPlay();

#if PLATFORM_ANDROID
    ApplyTier(CurrentTier);
#else
    SetActorTickEnabled(false);
#endif
}

void AHippoAdaptiveQualityDirector::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    AccumulatedTime += DeltaSeconds;
    ++AccumulatedFrames;

    if (AccumulatedTime >= EvaluationIntervalSeconds)
    {
        EvaluatePerformance();
        AccumulatedTime = 0.0f;
        AccumulatedFrames = 0;
    }
}

void AHippoAdaptiveQualityDirector::EvaluatePerformance()
{
    if (AccumulatedTime <= KINDA_SMALL_NUMBER || AccumulatedFrames <= 0)
    {
        return;
    }

    const float AverageFps = static_cast<float>(AccumulatedFrames) / AccumulatedTime;

    if (AverageFps < DowngradeBelowFps)
    {
        ++SlowSamples;
        FastSamples = 0;
    }
    else if (AverageFps > UpgradeAboveFps)
    {
        ++FastSamples;
        SlowSamples = 0;
    }
    else
    {
        SlowSamples = 0;
        FastSamples = 0;
    }

    if (SlowSamples >= SamplesBeforeDowngrade)
    {
        if (CurrentTier == EHippoQualityTier::High)
        {
            SetQualityTier(EHippoQualityTier::Medium);
        }
        else if (CurrentTier == EHippoQualityTier::Medium)
        {
            SetQualityTier(EHippoQualityTier::Low);
        }
        SlowSamples = 0;
    }
    else if (FastSamples >= SamplesBeforeUpgrade)
    {
        if (CurrentTier == EHippoQualityTier::Low)
        {
            SetQualityTier(EHippoQualityTier::Medium);
        }
        else if (CurrentTier == EHippoQualityTier::Medium)
        {
            SetQualityTier(EHippoQualityTier::High);
        }
        FastSamples = 0;
    }
}

void AHippoAdaptiveQualityDirector::SetQualityTier(EHippoQualityTier NewTier)
{
    if (CurrentTier == NewTier)
    {
        ApplyTier(NewTier);
        return;
    }

    CurrentTier = NewTier;
    ApplyTier(CurrentTier);
}

void AHippoAdaptiveQualityDirector::ApplyTier(EHippoQualityTier Tier)
{
    switch (Tier)
    {
        case EHippoQualityTier::Low:
            SetCVar(TEXT("r.ScreenPercentage"), 78.0f);
            SetCVar(TEXT("sg.ViewDistanceQuality"), 1);
            SetCVar(TEXT("sg.ShadowQuality"), 0);
            SetCVar(TEXT("sg.EffectsQuality"), 1);
            SetCVar(TEXT("sg.FoliageQuality"), 0);
            SetCVar(TEXT("sg.PostProcessQuality"), 1);
            break;

        case EHippoQualityTier::Medium:
            SetCVar(TEXT("r.ScreenPercentage"), 90.0f);
            SetCVar(TEXT("sg.ViewDistanceQuality"), 2);
            SetCVar(TEXT("sg.ShadowQuality"), 1);
            SetCVar(TEXT("sg.EffectsQuality"), 2);
            SetCVar(TEXT("sg.FoliageQuality"), 1);
            SetCVar(TEXT("sg.PostProcessQuality"), 2);
            break;

        case EHippoQualityTier::High:
        default:
            SetCVar(TEXT("r.ScreenPercentage"), 100.0f);
            SetCVar(TEXT("sg.ViewDistanceQuality"), 3);
            SetCVar(TEXT("sg.ShadowQuality"), 2);
            SetCVar(TEXT("sg.EffectsQuality"), 3);
            SetCVar(TEXT("sg.FoliageQuality"), 2);
            SetCVar(TEXT("sg.PostProcessQuality"), 3);
            break;
    }

    // Keep temporal/mobile anti-aliasing available while reducing expensive scene detail first.
    SetCVar(TEXT("r.PostProcessAAQuality"), 4);
}

void AHippoAdaptiveQualityDirector::SetCVar(const TCHAR* Name, int32 Value) const
{
    if (IConsoleVariable* Variable = IConsoleManager::Get().FindConsoleVariable(Name))
    {
        Variable->Set(Value, ECVF_SetByGameSetting);
    }
}

void AHippoAdaptiveQualityDirector::SetCVar(const TCHAR* Name, float Value) const
{
    if (IConsoleVariable* Variable = IConsoleManager::Get().FindConsoleVariable(Name))
    {
        Variable->Set(Value, ECVF_SetByGameSetting);
    }
}