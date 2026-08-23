#include "HippoGameMode.h"
#include "HippoPlayerController.h"
#include "HippoCameraPawn.h"
#include "HippoSanctuaryManager.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "GameFramework/Pawn.h"

AHippoGameMode::AHippoGameMode()
{
    PlayerControllerClass = AHippoPlayerController::StaticClass();
    DefaultPawnClass = AHippoCameraPawn::StaticClass();
}

void AHippoGameMode::BeginPlay()
{
    Super::BeginPlay();

    if (APawn* PlayerPawn = UGameplayStatics::GetPlayerPawn(GetWorld(), 0))
    {
        PlayerPawn->SetActorLocationAndRotation(FVector::ZeroVector, FRotator::ZeroRotator);
    }

    if (GetWorld())
    {
        GetWorld()->SpawnActor<AHippoSanctuaryManager>(AHippoSanctuaryManager::StaticClass(), FVector::ZeroVector, FRotator::ZeroRotator);
    }
}
