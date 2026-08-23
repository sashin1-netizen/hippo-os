#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "HippoTypes.h"
#include "HippoCharacter.generated.h"

class UHippoNeedsComponent;
class UHippoPersonalityComponent;
class UHippoMemoryComponent;
class UHippoBrainComponent;
class UStaticMeshComponent;
class USceneComponent;

UCLASS()
class HIPPOOS_API AHippoCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AHippoCharacter();
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaTime) override;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hippo|Identity")
    FString HippoName = TEXT("Mochi");

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UHippoNeedsComponent> Needs;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UHippoPersonalityComponent> Personality;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UHippoMemoryComponent> Memory;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) TObjectPtr<UHippoBrainComponent> Brain;

    UFUNCTION(BlueprintCallable) void ReceivePet(float Strength = 1.0f);
    UFUNCTION(BlueprintCallable) void ReceiveFood(float Nutrition = 0.25f);

private:
    UPROPERTY() TObjectPtr<USceneComponent> VisualRoot;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Body;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Head;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> Snout;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> EarL;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> EarR;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> LegFL;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> LegFR;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> LegRL;
    UPROPERTY() TObjectPtr<UStaticMeshComponent> LegRR;

    FVector WanderTarget = FVector::ZeroVector;
    float WanderTimer = 0.0f;
    float PetPulse = 0.0f;

    void BuildFallbackHippo();
    void UpdateAutonomousMovement(float DeltaTime);
};
