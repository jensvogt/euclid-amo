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

        // iconPath is stated rather than left to default, so the desktop shortcut is declared
        // the same way as the Start menu one above. Both resolve to the icon compiled into the
        // .exe by dist/win32/euclid-amo.rc - there is no separate .ico deployed next to the
        // binary to go missing or get out of step with it.
        component.addOperation(
            "CreateShortcut",
            targetExe,
            installer.value("DesktopDir") + "/euclid-amo.lnk",
            "workingDirectory=" + installer.value("TargetDir"),
            "iconPath=" + targetExe,
            "description=Euclid AMO"
        );
    }
};