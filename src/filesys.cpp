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