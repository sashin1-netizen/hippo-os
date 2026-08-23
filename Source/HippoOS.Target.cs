using UnrealBuildTool;
using System.Collections.Generic;

public class HippoOSTarget : TargetRules
{
    public HippoOSTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("HippoOS");
    }
}
