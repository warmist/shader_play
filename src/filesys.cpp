#include "filesys.h"

#include <windows.h>
#include <tchar.h>
#include <stdio.h>



std::vector<std::string> enum_files(const std::string& path)
{
    WIN32_FIND_DATA FindFileData;
    HANDLE hFind;

    std::vector<std::string> ret;
    hFind = FindFirstFile(path.c_str(), &FindFileData);
    if (hFind == INVALID_HANDLE_VALUE)
    {
        return ret;
    }
    else
    {
        while (hFind)
        {
            ret.push_back(FindFileData.cFileName);
            if (!FindNextFile(hFind, &FindFileData))
                break;
        }
    }
    FindClose(hFind);
    return ret;
}

dir_watcher::dir_watcher(const std::string& path)
{
    change_handle = FindFirstChangeNotification(path.c_str(), false, FILE_NOTIFY_CHANGE_CREATION | FILE_NOTIFY_CHANGE_LAST_WRITE);
}
dir_watcher::~dir_watcher()
{
    FindCloseChangeNotification(change_handle);
}

bool dir_watcher::check_changes()
{
    unsigned long  stat = WaitForSingleObject(change_handle, 0);
    if (stat == WAIT_TIMEOUT)
    {
        return false;
    }
    if (FindNextChangeNotification(change_handle) == FALSE)
    {
        throw std::runtime_error("Find next change failed");
    }
    return true;
}