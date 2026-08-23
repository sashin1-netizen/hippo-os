#include "HippoGameMode.h"
#include "HippoPlayerController.h"
#include "HippoCameraPawn.h"
#include "HippoSanctuaryManager.h"
#include "Engine/World.h"

AHippoGameMode::AHippoGameMode()
{
    PlayerControllerClass = AHippoPlayerController::StaticClass();
    DefaultPawnClass = AHippoCameraPawn::StaticClass();
}

void AHippoGameMode::BeginPlay()
{
    Super::BeginPlay();
    if (GetWorld())
    {
        GetWorld()->SpawnActor<AHippoSanctuaryManager>(AHippoSanctuaryManager::StaticClass(), FVector::ZeroVector, FRotator::ZeroRotator);
    }
}
