#include "HippoPlayerController.h"

#include "HippoCharacter.h"
#include "HippoCameraPawn.h"
#include "Engine/World.h"

AHippoPlayerController::AHippoPlayerController()
{
    bEnableTouchEvents = true;
    bEnableClickEvents = true;
    bShowMouseCursor = false;
    PrimaryActorTick.bCanEverTick = true;
}

void AHippoPlayerController::SetupInputComponent()
{
    Super::SetupInputComponent();
    InputComponent->BindTouch(IE_Pressed, this, &AHippoPlayerController::TouchPressed);
    InputComponent->BindTouch(IE_Released, this, &AHippoPlayerController::TouchReleased);
}

void AHippoPlayerController::PlayerTick(float DeltaTime)
{
    Super::PlayerTick(DeltaTime);
    PetCooldown = FMath::Max(0.0f, PetCooldown - DeltaTime);
    if (bTouchActive)
    {
        UpdateTouch(DeltaTime);
    }
}

void AHippoPlayerController::TouchPressed(ETouchIndex::Type FingerIndex, FVector Location)
{
    float X = 0.0f;
    float Y = 0.0f;
    bool bPressed = false;
    GetInputTouchState(FingerIndex, X, Y, bPressed);
    if (!bPressed) return;

    bTouchActive = true;
    ActiveFinger = FingerIndex;
    LastTouch = FVector2D(X, Y);
    PetDistance = 0.0f;
    bPetMode = TraceHippo(LastTouch, ActiveHippo);
}

void AHippoPlayerController::TouchReleased(ETouchIndex::Type FingerIndex, FVector Location)
{
    if (FingerIndex != ActiveFinger) return;

    if (bPetMode && ActiveHippo && PetDistance < MinimumPetDistancePixels * 0.5f)
    {
        ActiveHippo->ReceivePet(0.35f);
    }

    bTouchActive = false;
    bPetMode = false;
    ActiveHippo = nullptr;
    PetDistance = 0.0f;
}

void AHippoPlayerController::UpdateTouch(float DeltaTime)
{
    float X = 0.0f;
    float Y = 0.0f;
    bool bPressed = false;
    GetInputTouchState(ActiveFinger, X, Y, bPressed);

    if (!bPressed)
    {
        bTouchActive = false;
        bPetMode = false;
        ActiveHippo = nullptr;
        return;
    }

    const FVector2D Current(X, Y);
    const FVector2D Delta = Current - LastTouch;
    LastTouch = Current;

    if (bPetMode && ActiveHippo)
    {
        AHippoCharacter* HitHippo = nullptr;
        if (TraceHippo(Current, HitHippo) && HitHippo == ActiveHippo)
        {
            PetDistance += Delta.Size();
            if (PetDistance >= MinimumPetDistancePixels && PetCooldown <= 0.0f)
            {
                const float Strength = FMath::Clamp(PetDistance / 150.0f, 0.35f, 1.5f);
                ActiveHippo->ReceivePet(Strength);
                PetDistance = 0.0f;
                PetCooldown = PetCooldownSeconds;
            }
        }
        return;
    }

    if (AHippoCameraPawn* CameraPawn = Cast<AHippoCameraPawn>(GetPawn()))
    {
        const FRotator CurrentRotation = CameraPawn->GetActorRotation();
        CameraPawn->SetActorRotation(FRotator(0.0f, CurrentRotation.Yaw + Delta.X * OrbitDegreesPerPixel, 0.0f));
    }
}

bool AHippoPlayerController::TraceHippo(const FVector2D& ScreenPosition, AHippoCharacter*& OutHippo) const
{
    OutHippo = nullptr;

    FVector WorldOrigin;
    FVector WorldDirection;
    if (!DeprojectScreenPositionToWorld(ScreenPosition.X, ScreenPosition.Y, WorldOrigin, WorldDirection))
    {
        return false;
    }

    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(HippoTouchTrace), true);
    const FVector End = WorldOrigin + WorldDirection * 100000.0f;

    if (!GetWorld()->LineTraceSingleByChannel(Hit, WorldOrigin, End, ECC_Visibility, Params))
    {
        return false;
    }

    OutHippo = Cast<AHippoCharacter>(Hit.GetActor());
    return IsValid(OutHippo);
}
