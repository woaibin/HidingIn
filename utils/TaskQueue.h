#include <iostream>
#include <thread>
#include <queue>
#include <unordered_map>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <string>
#include <functional>
#include <future>

class TaskQueue {
public:
    TaskQueue(unsigned int numThreads, std::vector<std::string>& threadNames, unsigned int maxTasks, bool execInPlace = false)
            : stopFlag(false), isExecInPlace(execInPlace), maxTaskCount(maxTasks) {
        if (!execInPlace) {
            for (unsigned int i = 0; i < numThreads; ++i) {
                threadsMap[threadNames[i]] = std::thread(&TaskQueue::worker, this, threadNames[i]);
            }
        }
        execInPlaceThreadName = threadNames[0];
    }

    ~TaskQueue() {
        stop();
        for (auto& pair : threadsMap) {
            if (pair.second.joinable()) {
                pair.second.join();
            }
        }
    }

    bool empty(){
        std::unique_lock<std::mutex> lock(queueMutex);
        return taskQueue.empty();
    }

    int size(){
        std::unique_lock<std::mutex> lock(queueMutex);
        return taskQueue.size();
    }

    // Enqueue tasks that take the thread name as a parameter and return a future to wait for completion
    std::future<void> enqueueTask(const std::function<void(const std::string&)>& task) {
        auto promisePtr = std::make_shared<std::promise<void>>();
        auto future = promisePtr->get_future();

        {
            std::unique_lock<std::mutex> lock(queueMutex);

            // Wait if the task queue is full
            if (stopFlag) return future;  // Check if stop flag is set

            // Wrap the task to fulfill the promise upon completion
            taskQueue.push([task, promisePtr](const std::string& threadName) {
                try {
                    task(threadName);  // Execute the task
                    promisePtr->set_value();  // Fulfill the promise
                } catch (...) {
                    promisePtr->set_exception(std::current_exception());  // Set exception if task throws
                }
            });
        }
        return future;  // Return the future to the caller
    }

    // for exec in place mode:
    void execAllTasksInPlace() {
        while (!taskQueue.empty()) {
            std::unique_lock<std::mutex> lock(queueMutex);
            auto& task = taskQueue.front();
            task(execInPlaceThreadName);
            taskQueue.pop();
        }
    }

    bool getIsExecInPlace() {
        return isExecInPlace;
    }

    void stop() {
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            stopFlag = true;
        }
    }

private:
    std::unordered_map<std::string, std::thread> threadsMap;
    std::string execInPlaceThreadName;
    std::queue<std::function<void(const std::string&)>> taskQueue;
    std::mutex queueMutex;
    std::condition_variable condition;
    std::atomic<bool> stopFlag;
    bool isExecInPlace = false;
    unsigned int maxTaskCount;  // Maximum number of tasks allowed in the queue

    // Worker function for threads
    void worker(const std::string& threadName) {
        while (true) {
            {
                std::unique_lock<std::mutex> lock(queueMutex);

                if (stopFlag || taskQueue.empty()) {
                    return;  // Exit the loop if stop flag is set and no tasks are left
                }

                auto &task = taskQueue.front();
                // Execute the task and pass the thread name (ID) to it
                std::cerr << "bxk exec task" << std::endl;
                task(threadName);
                taskQueue.pop();
            }
        }
    }
};