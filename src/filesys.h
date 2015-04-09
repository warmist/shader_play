#pragma once

#include <string>
#include <vector>

std::vector<std::string> enum_files(const std::string& path);

struct dir_watcher
{
    void* change_handle;

    dir_watcher(const std::string& path);
    ~dir_watcher();

    dir_watcher(const dir_watcher& other) = delete;
    dir_watcher& operator=(const dir_watcher& other) = delete;

    bool check_changes();
};
