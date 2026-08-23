#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "HippoCameraPawn.generated.h"

class UCameraComponent;
class USceneComponent;

UCLASS()
class HIPPOOS_API AHippoCameraPawn : public APawn
{
    GENERATED_BODY()

public:
    AHippoCameraPawn();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<USceneComponent> Root;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UCameraComponent> Camera;
};
