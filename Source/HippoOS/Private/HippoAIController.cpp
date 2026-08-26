#include "HippoAIController.h"

#include "HippoBrainComponent.h"
#include "HippoCharacter.h"
#include "HippoNeedsComponent.h"
#include "EngineUtils.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "NavigationSystem.h"

AHippoAIController::AHippoAIController()
{
    PrimaryActorTick.bCanEverTick = true;
}

void AHippoAIController::OnPossess(APawn* InPawn)
{
    Super::OnPossess(InPawn);
    Hippo = Cast<AHippoCharacter>(InPawn);
    MoveClock = 0.0f;
}

void AHippoAIController::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Hippo || !Hippo->Brain)
    {
        return;
    }

    MoveClock -= DeltaSeconds;
    const EHippoAction Current = Hippo->Brain->CurrentAction;
    if (MoveClock <= 0.0f || Current != LastAction)
    {
        MoveClock = DecisionMoveInterval;
        LastAction = Current;
        UpdateMovementForAction();
    }
}

void AHippoAIController::UpdateMovementForAction()
{
    if (!Hippo || !Hippo->Brain)
    {
        return;
    }

    const EHippoAction Action = Hippo->Brain->CurrentAction;
    UCharacterMovementComponent* Movement = Hippo->GetCharacterMovement();

    switch (Action)
    {
        case EHippoAction::Idle:
        case EHippoAction::Sleep:
            StopMovement();
            return;

        case EHippoAction::ApproachPlayer:
        {
            if (APawn* PlayerPawn = UGameplayStatics::GetPlayerPawn(GetWorld(), 0))
            {
                if (Movement) Movement->MaxWalkSpeed = 190.0f;
                MoveToLocation(PlayerPawn->GetActorLocation(), PlayerAcceptanceRadius, true, true, false, true);
            }
            return;
        }

        case EHippoAction::SeekFood:
            if (Movement) Movement->MaxWalkSpeed = 165.0f;
            if (!MoveToNearestTaggedActor(TEXT("HippoFood"), 95.0f))
            {
                StopMovement();
            }
            return;

        case EHippoAction::EnterWater:
            if (Movement) Movement->MaxWalkSpeed = 170.0f;
            if (!MoveToNearestTaggedActor(TEXT("HippoWater"), 120.0f))
            {
                MoveToRandomReachable(WanderRadius, 90.0f);
            }
            return;

        case EHippoAction::Play:
        case EHippoAction::Zoomies:
            if (Movement) Movement->MaxWalkSpeed = Action == EHippoAction::Zoomies ? 330.0f : 245.0f;
            MoveToRandomReachable(WanderRadius, 70.0f);
            return;

        case EHippoAction::Explore:
            if (Movement) Movement->MaxWalkSpeed = 205.0f;
            MoveToRandomReachable(ExploreRadius, 90.0f);
            return;

        case EHippoAction::Wander:
        default:
            if (Movement) Movement->MaxWalkSpeed = 175.0f;
            MoveToRandomReachable(WanderRadius, 90.0f);
            return;
    }
}

void AHippoAIController::MoveToRandomReachable(float Radius, float AcceptanceRadius)
{
    if (!Hippo || !GetWorld())
    {
        return;
    }

    UNavigationSystemV1* Nav = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld());
    if (!Nav)
    {
        return;
    }

    FNavLocation Destination;
    if (Nav->GetRandomReachablePointInRadius(Hippo->GetActorLocation(), Radius, Destination))
    {
        MoveToLocation(Destination.Location, AcceptanceRadius, true, true, false, true);
    }
}

bool AHippoAIController::MoveToNearestTaggedActor(FName Tag, float AcceptanceRadius)
{
    if (!Hippo || !GetWorld())
    {
        return false;
    }

    AActor* Best = nullptr;
    float BestDistanceSq = TNumericLimits<float>::Max();
    for (TActorIterator<AActor> It(GetWorld()); It; ++It)
    {
        AActor* Candidate = *It;
        if (!IsValid(Candidate) || !Candidate->ActorHasTag(Tag))
        {
            continue;
        }

        const float DistanceSq = FVector::DistSquared2D(Hippo->GetActorLocation(), Candidate->GetActorLocation());
        if (DistanceSq < BestDistanceSq)
        {
            Best = Candidate;
            BestDistanceSq = DistanceSq;
        }
    }

    if (!Best)
    {
        return false;
    }

    MoveToLocation(Best->GetActorLocation(), AcceptanceRadius, true, true, false, true);
    return true;
}