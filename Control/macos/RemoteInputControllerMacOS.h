//
// Created by 宾小康 on 2024/10/24.
//

#ifndef HIDINGIN_REMOTEINPUTCONTROLLERMACOS_H
#define HIDINGIN_REMOTEINPUTCONTROLLERMACOS_H

#include <string>

class RemoteInputControllerMacOS {
public:
    // Constructor with app name
    explicit RemoteInputControllerMacOS(const std::string& appName);

    // Constructor with app PID
    explicit RemoteInputControllerMacOS(pid_t pid);

    // Destructor
    ~RemoteInputControllerMacOS();

    // Method to send keyboard input (string) to the app
    void sendString(const std::string& message);

    void sendKey(int keyCode);

    // Method to send mouse click to a specific position
    void sendMouseClickAt(double x, double y);

    // Method to focus the app (bring it to the foreground)
    bool focusApp();

private:
    pid_t appPid;
    std::string appName;

    // Helper function to find the PID of an application by its name
    pid_t findAppPidByName(const std::string& appName);
};

#endif // HIDINGIN_REMOTEINPUTCONTROLLERMACOS_H