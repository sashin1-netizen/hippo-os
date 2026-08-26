#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "HippoTypes.h"
#include "HippoAIController.generated.h"

class AHippoCharacter;

UCLASS()
class HIPPOOS_API AHippoAIController : public AAIController
{
    GENERATED_BODY()

public:
    AHippoAIController();

    virtual void OnPossess(APawn* InPawn) override;
    virtual void Tick(float DeltaSeconds) override;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|AI")
    float DecisionMoveInterval = 0.65f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|AI")
    float WanderRadius = 700.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|AI")
    float ExploreRadius = 1300.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|AI")
    float PlayerAcceptanceRadius = 220.0f;

private:
    UPROPERTY()
    TObjectPtr<AHippoCharacter> Hippo;

    float MoveClock = 0.0f;
    EHippoAction LastAction = EHippoAction::Idle;

    void UpdateMovementForAction();
    void MoveToRandomReachable(float Radius, float AcceptanceRadius);
    bool MoveToNearestTaggedActor(FName Tag, float AcceptanceRadius);
};