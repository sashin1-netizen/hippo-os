#pragma once

#include "CoreMinimal.h"
#include "HippoTypes.generated.h"

UENUM(BlueprintType)
enum class EHippoAction : uint8
{
    Idle,
    Wander,
    ApproachPlayer,
    SeekFood,
    Sleep,
    Explore,
    Play,
    EnterWater,
    Zoomies
};

UENUM(BlueprintType)
enum class EHippoInteractionType : uint8
{
    Pet,
    Scratch,
    Feed,
    Hose,
    Toy,
    CallName,
    Annoy
};

USTRUCT(BlueprintType)
struct FHippoNeedsSnapshot
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Hunger = 0.15f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Energy = 0.85f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Affection = 0.50f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Curiosity = 0.65f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Cleanliness = 0.80f;
};

USTRUCT(BlueprintType)
struct FHippoPersonality
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Mischief = 0.55f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Affectionateness = 0.75f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Energy = 0.75f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Curiosity = 0.70f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Stubbornness = 0.40f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Boldness = 0.65f;
};

USTRUCT(BlueprintType)
struct FHippoInteractionRecord
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite) EHippoInteractionType Type = EHippoInteractionType::Pet;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) int32 Count = 0;
    UPROPERTY(EditAnywhere, BlueprintReadWrite) float Affinity = 0.0f;
};
