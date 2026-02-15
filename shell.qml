//@ pragma UseQApplication
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "."

ShellRoot {
    id: shellRoot

    NotificationServer {
        id: notifServer
        onNotification: (notification) => {
            notification.tracked = true;
            // broadcast to all full bars
            for (let i = 0; i < barVariants.instances.length; i++) {
                let bar = barVariants.instances[i];
                if (bar && bar.isFull) {
                    bar.showNotification(
                        notification.summary,
                        notification.body,
                        notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 5000
                    );
                }
            }
        }
    }

    Variants {
        id: barVariants
        model: Config.monitors

        WitchesBrewBar {
            required property var modelData

            monitorName:    modelData.name
            workspaceStart: modelData.workspaceStart
            workspaceCount: modelData.workspaceCount
            isFull:         modelData.full
            notifServer:    notifServer
        }
    }
}
