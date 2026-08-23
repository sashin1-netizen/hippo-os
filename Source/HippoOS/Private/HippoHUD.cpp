#include "HippoHUD.h"

#include "HippoCharacter.h"
#include "HippoNeedsComponent.h"
#include "HippoMemoryComponent.h"
#include "Engine/Canvas.h"
#include "EngineUtils.h"

void AHippoHUD::DrawHUD()
{
    Super::DrawHUD();
    if (!Canvas || !GetWorld()) return;

    AHippoCharacter* Hippo = nullptr;
    for (TActorIterator<AHippoCharacter> It(GetWorld()); It; ++It)
    {
        Hippo = *It;
        break;
    }

    DrawText(TEXT("HIPPO OS"), FLinearColor::White, 34.0f, 28.0f, nullptr, 1.35f, false);

    if (Hippo)
    {
        const float Hunger = Hippo->Needs ? Hippo->Needs->Needs.Hunger : 0.0f;
        const float Energy = Hippo->Needs ? Hippo->Needs->Needs.Energy : 0.0f;
        const float Bond = Hippo->Memory ? Hippo->Memory->Bond : 0.0f;

        DrawText(Hippo->HippoName, FLinearColor::White, 34.0f, 68.0f, nullptr, 1.1f, false);
        DrawText(FString::Printf(TEXT("Bond %d%%   Hunger %d%%   Energy %d%%"),
            FMath::RoundToInt(Bond * 100.0f),
            FMath::RoundToInt(Hunger * 100.0f),
            FMath::RoundToInt(Energy * 100.0f)),
            FLinearColor::White, 34.0f, 100.0f, nullptr, 0.85f, false);
    }

    const float Bottom = Canvas->ClipY - 90.0f;
    DrawText(TEXT("FEED"), FLinearColor::White, 38.0f, Bottom, nullptr, 1.1f, false);
    DrawText(TEXT("Drag hippo to pet  |  Drag habitat to look around"), FLinearColor::White,
        Canvas->ClipX * 0.28f, Bottom, nullptr, 0.78f, false);
}
