function Component() {}

Component.prototype.createOperations = function()
{
    component.createOperations();

    if (systemInfo.productType === "windows") {

        var targetExe = installer.value("TargetDir") + "/euclid-amo.exe";

        var startMenuDir =
            installer.value("StartMenuDir") + "/euclid";

        component.addOperation(
            "CreateShortcut",
            targetExe,
            startMenuDir + "/euclid-amo.lnk",
            "workingDirectory=" + installer.value("TargetDir"),
            "iconPath=" + targetExe,
            "description=Euclid AMO"
        );

        component.addOperation(
            "CreateShortcut",
            installer.value("TargetDir") + "/euclid-amo.exe",
            installer.value("DesktopDir") + "/euclid-amo.lnk",
            "workingDirectory=" + installer.value("TargetDir")
        );
    }
};