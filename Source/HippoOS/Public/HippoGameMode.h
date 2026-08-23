#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "HippoGameMode.generated.h"

UCLASS()
class HIPPOOS_API AHippoGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    AHippoGameMode();
    virtual void BeginPlay() override;
};
