#include "HippoSanctuaryManager.h"

#include "HippoCharacter.h"
#include "HippoGameInstance.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"

AHippoSanctuaryManager::AHippoSanctuaryManager()
{
    PrimaryActorTick.bCanEverTick = false;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(TEXT("/Engine/BasicShapes/Cube.Cube"));
    static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(TEXT("/Engine/BasicShapes/Sphere.Sphere"));

    auto MakeCube = [this, &CubeMesh](const TCHAR* Name, FVector Location, FVector Scale, bool bCollision)
    {
        UStaticMeshComponent* Part = CreateDefaultSubobject<UStaticMeshComponent>(Name);
        Part->SetupAttachment(Root);
        Part->SetStaticMesh(CubeMesh.Succeeded() ? CubeMesh.Object : nullptr);
        Part->SetRelativeLocation(Location);
        Part->SetRelativeScale3D(Scale);
        Part->SetCollisionEnabled(bCollision ? ECollisionEnabled::QueryAndPhysics : ECollisionEnabled::NoCollision);
        return Part;
    };

    Ground = MakeCube(TEXT("Ground"), FVector(0.0f, 0.0f, -30.0f), FVector(16.0f, 12.0f, 0.6f), true);
    Pond = MakeCube(TEXT("Pond"), FVector(320.0f, 260.0f, 2.0f), FVector(3.6f, 2.5f, 0.08f), false);
    MudPatch = MakeCube(TEXT("MudPatch"), FVector(-350.0f, 260.0f, 4.0f), FVector(2.2f, 1.8f, 0.05f), false);

    auto MakeRock = [this, &SphereMesh](const TCHAR* Name, FVector Location, FVector Scale)
    {
        UStaticMeshComponent* Part = CreateDefaultSubobject<UStaticMeshComponent>(Name);
        Part->SetupAttachment(Root);
        Part->SetStaticMesh(SphereMesh.Succeeded() ? SphereMesh.Object : nullptr);
        Part->SetRelativeLocation(Location);
        Part->SetRelativeScale3D(Scale);
        Part->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
        return Part;
    };

    RockA = MakeRock(TEXT("RockA"), FVector(-520.0f, -270.0f, 35.0f), FVector(0.75f, 0.55f, 0.55f));
    RockB = MakeRock(TEXT("RockB"), FVector(510.0f, -310.0f, 24.0f), FVector(0.52f, 0.42f, 0.38f));
}

void AHippoSanctuaryManager::BeginPlay()
{
    Super::BeginPlay();

    if (GetWorld())
    {
        Hippo = GetWorld()->SpawnActor<AHippoCharacter>(AHippoCharacter::StaticClass(), FVector(0.0f, 0.0f, 82.0f), FRotator::ZeroRotator);
    }

    if (Hippo)
    {
        if (UHippoGameInstance* GI = GetGameInstance<UHippoGameInstance>())
        {
            GI->LoadHippo(Hippo);
        }
    }

    if (AutoSaveIntervalSeconds > 0.0f)
    {
        GetWorldTimerManager().SetTimer(AutoSaveTimer, this, &AHippoSanctuaryManager::SaveNow, AutoSaveIntervalSeconds, true);
    }
}

bool AHippoSanctuaryManager::SaveNow()
{
    if (!Hippo) return false;
    if (UHippoGameInstance* GI = GetGameInstance<UHippoGameInstance>())
    {
        return GI->SaveHippo(Hippo);
    }
    return false;
}
