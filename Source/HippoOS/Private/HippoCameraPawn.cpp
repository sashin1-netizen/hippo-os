#include "HippoCameraPawn.h"
#include "Camera/CameraComponent.h"
#include "Components/SceneComponent.h"

AHippoCameraPawn::AHippoCameraPawn()
{
    PrimaryActorTick.bCanEverTick = false;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
    Camera->SetupAttachment(Root);
    Camera->SetRelativeLocation(FVector(-650.0f, 0.0f, 210.0f));
    Camera->SetRelativeRotation(FRotator(-8.0f, 0.0f, 0.0f));
    Camera->FieldOfView = 62.0f;
}
