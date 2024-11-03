#ifndef TSAIDEMO_EVENTMANAGER_H
#define TSAIDEMO_EVENTMANAGER_H

#include <string>
#include <functional>
#include <map>
#include <vector>
#include <variant>
#include <unordered_map>
#include <memory>
#include <condition_variable>
#include <mutex>
#include <thread>
#include <iostream>

enum class EventType{
    General
};

struct EventRegisterParam {
    virtual ~EventRegisterParam() = default;

    EventRegisterParam(){}
    EventRegisterParam(std::string eventName, EventType type) : eventName(eventName), type(type){

    }

    std::string eventName;
    EventType type;
    void* param;
};

struct EventParam {
    using Value = std::variant<std::string, int, void*>;
    void addParameter(const std::string& key, const Value& value) {
        parameters[key] = value;
    }

    std::unordered_map<std::string, Value> parameters;
};


class EventManager
{
public:
    // Get global unique instance
    static std::shared_ptr<EventManager> getInstance() {
        static std::shared_ptr<EventManager> g_instance;

        if (!g_instance) {
            g_instance = std::make_shared<EventManager>();
        }
        return g_instance;
    }

    // Register an input
    void registerEvent(const EventRegisterParam& eventRegisterParam) {
        switch (eventRegisterParam.type) {
            case EventType::General:
            {
                EventRegisterParam registerParam = eventRegisterParam;
                m_registeredEvents[eventRegisterParam.eventName] = registerParam;
                break;
            }
        }
    }

    // Register a listener for a specific event
    void registerListener(std::string eventName, std::function<void(EventParam& eventParam)> handler) {
        m_listeners[eventName].push_back(handler);
    }

    // Unregister a listener
    void unregisterListener(std::string eventName){
        m_listeners[eventName].clear();
    }

    // Call this method when a specific event is triggered
    void triggerEvent(const std::string& registerName, const EventParam& param) {
        // Check if the event is registered
        for (auto& listener : m_listeners[registerName]) {
            listener((EventParam &)param);
        }

        // Notify waiters if they are waiting for this event
        {
            std::lock_guard<std::mutex> lock(m_eventMutex);
            m_triggeredEvents[registerName] = true;
        }
        m_eventCondition.notify_all();
    }

    // Wait for a specific event to be triggered
    void waitForEvent(const std::string& eventName) {
        std::unique_lock<std::mutex> lock(m_eventMutex);
        m_eventCondition.wait(lock, [&] { return m_triggeredEvents[eventName]; });
        // Once the event is triggered, reset its state
        m_triggeredEvents[eventName] = false;
    }

    // Clear all events and listeners
    void clearAllEventsAndListeners(){
        m_registeredEvents.clear();
        m_listeners.clear();
        m_triggeredEvents.clear();
    }

private:
    // This map holds registered events and their details
    std::map<std::string, std::variant<EventRegisterParam>> m_registeredEvents;

    // This map holds listeners registered for specific events
    std::map<std::string, std::vector<std::function<void(EventParam& eventParam)>>> m_listeners;

    // Mutex and condition variable to handle waiting for events
    std::mutex m_eventMutex;
    std::condition_variable m_eventCondition;

    // Keeps track of triggered events
    std::unordered_map<std::string, bool> m_triggeredEvents;
};

#endif  // TSAIDEMO_EVENTMANAGER_H
