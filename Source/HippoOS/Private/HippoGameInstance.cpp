#include "HippoGameInstance.h"

#include "HippoCharacter.h"
#include "HippoSaveGame.h"
#include "HippoNeedsComponent.h"
#include "HippoPersonalityComponent.h"
#include "HippoMemoryComponent.h"
#include "Kismet/GameplayStatics.h"

void UHippoGameInstance::Init()
{
    Super::Init();

    if (UGameplayStatics::DoesSaveGameExist(SaveSlotName, UserIndex))
    {
        CachedSave = Cast<UHippoSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlotName, UserIndex));
        if (CachedSave)
        {
            LoadedLastSaveUtc = CachedSave->LastSaveUtc;
        }
    }
}

bool UHippoGameInstance::SaveHippo(AHippoCharacter* Hippo)
{
    if (!IsValid(Hippo)) return false;

    UHippoSaveGame* Save = Cast<UHippoSaveGame>(UGameplayStatics::CreateSaveGameObject(UHippoSaveGame::StaticClass()));
    if (!Save) return false;

    Save->HippoName = Hippo->HippoName;
    if (Hippo->Needs) Save->Needs = Hippo->Needs->Needs;
    if (Hippo->Personality)
    {
        Save->Personality = Hippo->Personality->Personality;
        Save->PersonalitySeed = Hippo->Personality->PersonalitySeed;
    }
    if (Hippo->Memory)
    {
        Save->SessionCount = Hippo->Memory->SessionCount;
        Save->Bond = Hippo->Memory->Bond;
        Save->Interactions = Hippo->Memory->Interactions;
    }

    Save->LastSaveUtc = FDateTime::UtcNow();
    const bool bSaved = UGameplayStatics::SaveGameToSlot(Save, SaveSlotName, UserIndex);
    if (bSaved)
    {
        CachedSave = Save;
        LoadedLastSaveUtc = Save->LastSaveUtc;
    }
    return bSaved;
}

bool UHippoGameInstance::LoadHippo(AHippoCharacter* Hippo)
{
    if (!IsValid(Hippo)) return false;

    if (!CachedSave && UGameplayStatics::DoesSaveGameExist(SaveSlotName, UserIndex))
    {
        CachedSave = Cast<UHippoSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlotName, UserIndex));
    }

    if (!CachedSave)
    {
        if (Hippo->Personality && Hippo->Personality->PersonalitySeed == 0)
        {
            Hippo->Personality->GeneratePersonality(FMath::RandRange(100000, 999999999));
        }
        if (Hippo->Memory)
        {
            Hippo->Memory->SessionCount = 1;
            Hippo->Memory->LastSeenUtc = FDateTime::UtcNow();
        }
        return SaveHippo(Hippo);
    }

    Hippo->HippoName = CachedSave->HippoName;

    if (Hippo->Needs)
    {
        Hippo->Needs->Needs = CachedSave->Needs;
        const FTimespan Elapsed = FDateTime::UtcNow() - CachedSave->LastSaveUtc;
        Hippo->Needs->SimulateOffline(static_cast<float>(FMath::Max(0.0, Elapsed.GetTotalMinutes())));
    }

    if (Hippo->Personality)
    {
        Hippo->Personality->Personality = CachedSave->Personality;
        Hippo->Personality->PersonalitySeed = CachedSave->PersonalitySeed;
    }

    if (Hippo->Memory)
    {
        Hippo->Memory->SessionCount = CachedSave->SessionCount + 1;
        Hippo->Memory->Bond = CachedSave->Bond;
        Hippo->Memory->Interactions = CachedSave->Interactions;
        Hippo->Memory->LastSeenUtc = FDateTime::UtcNow();
    }

    LoadedLastSaveUtc = CachedSave->LastSaveUtc;
    return true;
}

float UHippoGameInstance::GetOfflineMinutes() const
{
    if (LoadedLastSaveUtc.GetTicks() <= 0) return 0.0f;
    const FTimespan Elapsed = FDateTime::UtcNow() - LoadedLastSaveUtc;
    return static_cast<float>(FMath::Max(0.0, Elapsed.GetTotalMinutes()));
}
