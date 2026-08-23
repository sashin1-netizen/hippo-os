#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "HippoPlayerController.generated.h"

class AHippoCharacter;
class AHippoCameraPawn;

UCLASS()
class HIPPOOS_API AHippoPlayerController : public APlayerController
{
    GENERATED_BODY()

public:
    AHippoPlayerController();
    virtual void SetupInputComponent() override;
    virtual void PlayerTick(float DeltaTime) override;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Touch") float MinimumPetDistancePixels = 38.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Touch") float PetCooldownSeconds = 0.14f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Camera") float OrbitDegreesPerPixel = 0.10f;

private:
    void TouchPressed(ETouchIndex::Type FingerIndex, FVector Location);
    void TouchReleased(ETouchIndex::Type FingerIndex, FVector Location);
    void UpdateTouch(float DeltaTime);
    bool TraceHippo(const FVector2D& ScreenPosition, AHippoCharacter*& OutHippo) const;

    bool bTouchActive = false;
    bool bPetMode = false;
    ETouchIndex::Type ActiveFinger = ETouchIndex::Touch1;
    FVector2D LastTouch = FVector2D::ZeroVector;
    float PetDistance = 0.0f;
    float PetCooldown = 0.0f;

    UPROPERTY() TObjectPtr<AHippoCharacter> ActiveHippo;
};
