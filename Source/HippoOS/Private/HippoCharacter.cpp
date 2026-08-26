#include "HippoCharacter.h"

#include "HippoAIController.h"
#include "HippoNeedsComponent.h"
#include "HippoPersonalityComponent.h"
#include "HippoMemoryComponent.h"
#include "HippoBrainComponent.h"

#include "AIController.h"
#include "Components/CapsuleComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Navigation/PathFollowingComponent.h"
#include "UObject/ConstructorHelpers.h"

AHippoCharacter::AHippoCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    Needs = CreateDefaultSubobject<UHippoNeedsComponent>(TEXT("Needs"));
    Personality = CreateDefaultSubobject<UHippoPersonalityComponent>(TEXT("Personality"));
    Memory = CreateDefaultSubobject<UHippoMemoryComponent>(TEXT("Memory"));
    Brain = CreateDefaultSubobject<UHippoBrainComponent>(TEXT("Brain"));

    AIControllerClass = AHippoAIController::StaticClass();
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

    GetCapsuleComponent()->InitCapsuleSize(62.0f, 78.0f);
    GetCharacterMovement()->MaxWalkSpeed = 180.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    bUseControllerRotationYaw = false;

    BuildFallbackHippo();
}

void AHippoCharacter::BuildFallbackHippo()
{
    VisualRoot = CreateDefaultSubobject<USceneComponent>(TEXT("VisualRoot"));
    VisualRoot->SetupAttachment(GetCapsuleComponent());
    VisualRoot->SetRelativeLocation(FVector(0.0f, 0.0f, -32.0f));

    static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(TEXT("/Engine/BasicShapes/Sphere.Sphere"));
    UStaticMesh* Sphere = SphereMesh.Succeeded() ? SphereMesh.Object : nullptr;

    auto MakePart = [this, Sphere](const TCHAR* Name, FVector Location, FVector Scale)
    {
        UStaticMeshComponent* Part = CreateDefaultSubobject<UStaticMeshComponent>(Name);
        Part->SetupAttachment(VisualRoot);
        Part->SetStaticMesh(Sphere);
        Part->SetRelativeLocation(Location);
        Part->SetRelativeScale3D(Scale);
        Part->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
        Part->SetCollisionResponseToAllChannels(ECR_Ignore);
        Part->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);
        Part->SetGenerateOverlapEvents(false);
        return Part;
    };

    Body = MakePart(TEXT("Body"), FVector(-10.0f, 0.0f, 56.0f), FVector(1.20f, 0.78f, 0.68f));
    Head = MakePart(TEXT("Head"), FVector(82.0f, 0.0f, 65.0f), FVector(0.70f, 0.62f, 0.58f));
    Snout = MakePart(TEXT("Snout"), FVector(126.0f, 0.0f, 53.0f), FVector(0.52f, 0.58f, 0.34f));
    EarL = MakePart(TEXT("EarL"), FVector(76.0f, -44.0f, 102.0f), FVector(0.15f, 0.12f, 0.20f));
    EarR = MakePart(TEXT("EarR"), FVector(76.0f, 44.0f, 102.0f), FVector(0.15f, 0.12f, 0.20f));

    LegFL = MakePart(TEXT("LegFL"), FVector(52.0f, -38.0f, 9.0f), FVector(0.23f, 0.23f, 0.45f));
    LegFR = MakePart(TEXT("LegFR"), FVector(52.0f, 38.0f, 9.0f), FVector(0.23f, 0.23f, 0.45f));
    LegRL = MakePart(TEXT("LegRL"), FVector(-56.0f, -38.0f, 9.0f), FVector(0.25f, 0.25f, 0.48f));
    LegRR = MakePart(TEXT("LegRR"), FVector(-56.0f, 38.0f, 9.0f), FVector(0.25f, 0.25f, 0.48f));
}

void AHippoCharacter::BeginPlay()
{
    Super::BeginPlay();

    if (Personality && Personality->PersonalitySeed == 0)
    {
        Personality->GeneratePersonality(FMath::RandRange(100000, 999999999));
    }
}

void AHippoCharacter::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);
    UpdateAutonomousMovement(DeltaTime);

    const float T = GetWorld() ? GetWorld()->GetTimeSeconds() : 0.0f;
    const float Breathing = FMath::Sin(T * 2.2f) * 0.012f;
    if (Body)
    {
        Body->SetRelativeScale3D(FVector(1.20f + Breathing, 0.78f + Breathing * 0.6f, 0.68f + Breathing * 0.8f));
    }

    const float EarFlick = FMath::Sin(T * 5.3f) * 5.0f;
    if (EarL) EarL->SetRelativeRotation(FRotator(EarFlick, 0.0f, -15.0f));
    if (EarR) EarR->SetRelativeRotation(FRotator(-EarFlick, 0.0f, 15.0f));

    if (PetPulse > 0.0f)
    {
        PetPulse = FMath::Max(0.0f, PetPulse - DeltaTime);
        if (Head)
        {
            Head->SetRelativeRotation(FRotator(8.0f * PetPulse, 0.0f, 0.0f));
        }
    }
    else if (Head)
    {
        Head->SetRelativeRotation(FRotator::ZeroRotator);
    }
}

void AHippoCharacter::UpdateAutonomousMovement(float DeltaTime)
{
    if (!Brain || !GetWorld()) return;

    // Prefer NavMesh movement when the AI controller has an active path.
    // If the generated sanctuary has no nav data, continue using the proven direct fallback.
    if (AAIController* AI = Cast<AAIController>(GetController()))
    {
        if (AI->GetMoveStatus() != EPathFollowingStatus::Idle)
        {
            return;
        }
    }

    const EHippoAction Action = Brain->CurrentAction;

    if (Action == EHippoAction::Sleep || Action == EHippoAction::Idle || Action == EHippoAction::SeekFood)
    {
        return;
    }

    if (Action == EHippoAction::ApproachPlayer)
    {
        if (APlayerController* PC = UGameplayStatics::GetPlayerController(GetWorld(), 0))
        {
            FVector CameraLocation;
            FRotator CameraRotation;
            PC->GetPlayerViewPoint(CameraLocation, CameraRotation);
            FVector Target = CameraLocation;
            Target.Z = GetActorLocation().Z;
            const FVector ToPlayer = Target - GetActorLocation();
            if (ToPlayer.Size2D() > 220.0f)
            {
                AddMovementInput(ToPlayer.GetSafeNormal2D(), 0.85f);
            }
        }
        return;
    }

    WanderTimer -= DeltaTime;
    if (WanderTimer <= 0.0f || FVector::Dist2D(GetActorLocation(), WanderTarget) < 80.0f)
    {
        WanderTimer = FMath::FRandRange(2.5f, 5.5f);
        const FVector Origin(0.0f, 0.0f, GetActorLocation().Z);
        WanderTarget = Origin + FVector(FMath::FRandRange(-650.0f, 650.0f), FMath::FRandRange(-500.0f, 500.0f), 0.0f);
    }

    const FVector Direction = (WanderTarget - GetActorLocation()).GetSafeNormal2D();
    const float SpeedScale = Action == EHippoAction::Play ? 1.0f : 0.62f;
    AddMovementInput(Direction, SpeedScale);
}

void AHippoCharacter::ReceivePet(float Strength)
{
    if (Needs) Needs->ApplyPetting(Strength);
    if (Memory) Memory->RecordInteraction(EHippoInteractionType::Pet, 0.05f * FMath::Clamp(Strength, 0.0f, 2.0f));
    if (Brain) Brain->ReinforceAction(EHippoAction::ApproachPlayer, 0.015f * FMath::Clamp(Strength, 0.0f, 2.0f));
    PetPulse = 1.0f;
}

void AHippoCharacter::ReceiveFood(float Nutrition)
{
    if (Needs) Needs->ApplyFeeding(Nutrition);
    if (Memory) Memory->RecordInteraction(EHippoInteractionType::Feed, 0.08f);
    if (Brain) Brain->ReinforceAction(EHippoAction::SeekFood, 0.02f);
}