import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    signal unlocked()
    signal failed()

    function tryUnlock() {
        if (currentText === "")
            return ;

        unlockInProgress = true;
        pam.start();
    }

    onCurrentTextChanged: showFailure = false

    PamContext {
        id: pam

        config: "quickshell-lock"
        onPamMessage: {
            if (responseRequired)
                respond(root.currentText);

        }
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                root.unlocked();
            } else {
                root.currentText = "";
                root.showFailure = true;
                root.failed();
            }
            root.unlockInProgress = false;
        }
    }

}
