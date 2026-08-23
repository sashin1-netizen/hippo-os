#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "HippoHUD.generated.h"

UCLASS()
class HIPPOOS_API AHippoHUD : public AHUD
{
    GENERATED_BODY()

public:
    virtual void DrawHUD() override;
};
