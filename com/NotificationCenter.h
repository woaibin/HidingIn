//
// Created by 宾小康 on 2024/10/22.
//

#ifndef HIDINGIN_NOTIFICATIONCENTER_H
#define HIDINGIN_NOTIFICATIONCENTER_H
#include <iostream>
#include <string>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <memory>
#include <unordered_map>

// Enum for Message Types
enum MessageType {
    Render,
    Control,
    Device
};

struct SubMsg{
};

struct DeviceSubMsg: public SubMsg{
};

struct WindowSubMsg : public SubMsg{
    WindowSubMsg(int x, int y, int width, int height, float factor):
    xPos(x), yPos(y), width(width),height(height), scalingFactor(factor){}
    int xPos;
    int yPos;
    int width;
    int height;
    int capturedAppX;
    int capturedAppY;
    int capturedAppWidth;
    int capturedAppHeight;
    int capturedWinId;
    int appPid;
    float scalingFactor;
    std::atomic_bool needResizeForRender = false;
};

// Struct for Messages
struct Message {
    MessageType msgType;
    std::string whatHappen;

    std::shared_ptr<SubMsg> subMsg = nullptr;
};

// NotificationCenter Singleton Class
class NotificationCenter {
public:
    // Get the single instance (Singleton pattern)
    static NotificationCenter& getInstance() {
        static NotificationCenter instance;
        return instance;
    }

    // Push message into the notification center
    void pushMessage(const Message& msg, bool persistent = false) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (persistent) {
            // Add the message to the persistent message map
            persistentMessages[msg.msgType] = msg;
        } else {
            // Add the message to the regular queue
            messageQueue[msg.msgType].push(msg);
        }
        cv.notify_one();  // Notify a waiting thread that a new message has arrived
    }

    // Receive message from the notification center (blocking)
    // to-do separate different types:
    std::optional<Message> receiveMessage(MessageType msgType) {
        std::unique_lock<std::mutex> lock(mutex_);
        if(!messageQueue[msgType].empty()){
            Message msg = messageQueue[msgType].front();
            messageQueue[msgType].pop();
            return msg;
        }else{
            return std::nullopt;
        }
    }

    // Retrieve a persistent message by type
    bool getPersistentMessage(MessageType msgType, Message& msg) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = persistentMessages.find(msgType);
        if (it != persistentMessages.end()) {
            msg = it->second;
            return true;
        }
        return false;  // No persistent message of that type found
    }

    // Remove a persistent message by type (optional, if you want to allow removal)
    bool removePersistentMessage(MessageType msgType) {
        std::lock_guard<std::mutex> lock(mutex_);
        return persistentMessages.erase(msgType) > 0;
    }

private:
    NotificationCenter() = default;
    ~NotificationCenter() = default;

    // Disable copy constructor and assignment operator
    NotificationCenter(const NotificationCenter&) = delete;
    NotificationCenter& operator=(const NotificationCenter&) = delete;

    std::unordered_map<MessageType, std::queue<Message>> messageQueue;  // Queue for storing regular messages
    std::unordered_map<MessageType, Message> persistentMessages;  // Map for storing persistent messages
    std::mutex mutex_;                 // Mutex to protect the queue and the persistent message map
    std::condition_variable cv;        // Condition variable to block the receiver thread if the queue is empty
};

#endif //HIDINGIN_NOTIFICATIONCENTER_H