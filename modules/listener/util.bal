// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerinax/googleapis_drive as drive;
import ballerina/log;
import ballerina/time;
import ballerina/regex;

# Subscribes to all the changes or specific fileId.
# + callbackURL - Registered callback URL of the 
# + driveClient - Google drive client.
# + fileId - FileId that you want to initiate watch operations. Optional. 
#            Dont specify if you want TO trigger the listener for all the changes.
# + return 'drive:WatchResponse' on success and error if unsuccessful. 
function startWatch(string callbackURL, drive:Client driveClient, string? fileId = ()) 
                        returns @tainted drive:WatchResponse|error {
    if (fileId is string) {
        // Watch for specified file changes
        return driveClient->watchFilesById(fileId, callbackURL);
    } else {
        // Watch for all file changes.
        return driveClient->watchFiles(callbackURL);
    }
}

# List changes by page token
# + driveClient - The HTTP Client
# + pageToken - The token for continuing a previous list request on the next page. This should be set to the value of 
#               'nextPageToken' from the previous response or to the response from the getStartPageToken method.
# + return 'drive:ChangesListResponse' on success and error if unsuccessful. 
function getAllChangeList(string pageToken, drive:Client driveClient) 
                          returns @tainted drive:ChangesListResponse|error {
    drive:ChangesListResponse response = {};
    string? token = pageToken;
    if (token is string) {
        response = check driveClient->listChanges(pageToken);
        token = response?.nextPageToken;
    }
    return response;
}

# Maps Events to Change records
# + changeList - 'ChangesListResponse' record that contains the whole changeList.
# + driveClient - Http client for client connection.
# + return if unsucessful, returns error. Else EventInfo object
function mapEvents(drive:ChangesListResponse changeList, drive:Client driveClient, json[] statusStore) 
                    returns @tainted EventInfo[]|error {
    EventInfo[] events = [];
    drive:Change[]? changes = changeList?.changes;
    if (changes is drive:Change[] && changes.length() > 0) {
        foreach drive:Change changeLog in changes {
            string fileOrFolderId = changeLog?.fileId.toString();
            drive:File|error fileOrFolder = driveClient->getFile(fileOrFolderId);
            if (fileOrFolder is drive:File) {
                string mimeType = fileOrFolder?.mimeType.toString();
                if (mimeType == changeLog?.file?.mimeType.toString()) {
                    if (mimeType != FOLDER) {
                        log:print("File change event found file id : " + fileOrFolderId + " | Mime type : " +mimeType);
                        if (changeLog?.removed == true) {
                            // eventService.onFileDeletedEvent(fileOrFolderId);
                            EventInfo event = {eventType:FILE_DELETED, fileOrFolderId:fileOrFolderId};
                            events.push(event);
                        } else {
                            EventInfo? event = check identifyFileEvent(fileOrFolderId, driveClient, statusStore);
                            if (event is EventInfo){
                                events.push(event);
                            }
                        }
                    } else  {
                        log:print("Folder change event found folder id : " + fileOrFolderId);
                        if (changeLog?.removed == true) {
                            EventInfo event = {eventType:FOLDER_DELETED, fileOrFolderId:fileOrFolderId};
                            events.push(event);
                        } else {
                            EventInfo? event = check identifyFolderEvent(fileOrFolderId, driveClient, statusStore);
                            if (event is EventInfo){
                                events.push(event);
                            }
                        }
                    }
                }
            } else {
                log:printError(fileOrFolder.message());
            }
        }
    }
    return events;
}

# Maps and identify folder change events.
# + folderId - folderId that subjected to a change. 
# + statusStore - JSON that carries the current status (optional).
# + driveClient - Http client for client connection.
# + return if unsucessful, returns error. Else EventInfo object
function identifyFolderEvent(string folderId, drive:Client driveClient, json[] statusStore, 
                             boolean isSepcificFolder = false, string? specFolderId = ()) 
                             returns @tainted EventInfo|error? {
    EventInfo info = {};
    drive:File folder = check driveClient->getFile(folderId, "createdTime,modifiedTime,trashed,parents");
    log:print(folder.toString());
    boolean isExisitingFolder = check checkAvailability(folderId, statusStore);
    boolean? isTrashed = folder?.trashed;
    string[]? parentList = folder?.parents;
    string parent = EMPTY_STRING;
    if (parentList is string[] && parentList.length() > 0) {
        parent = parentList[0].toString();
    }
    info.fileOrFolderId = folderId;
    if (isTrashed is boolean) {
        if (!isExisitingFolder && !isTrashed) {
            if (isSepcificFolder && parent == specFolderId.toString()) {
                info.eventType = NEW_FOLDER_CREATED_ON_SPECIFIED_FOLDER;
                return info;
                // _ = eventService.onNewFolderCreatedInSpecificFolderEvent(folderId);
            } else if (!isSepcificFolder) {
                info.eventType = NEW_FOLDER_CREATED;
                // info.isFolder = true;
                return info;
                // _ = eventService.onNewFolderCreatedEvent(folderId);
            }
        } else if (isExisitingFolder && isTrashed) {
            if (isSepcificFolder && parent == specFolderId.toString()) {
                info.eventType = FOLDER_DELETED_ON_SPECIFIED_FOLDER;
                // _ = eventService.onFolderDeletedInSpecificFolderEvent(folderId);
            } else if (!isSepcificFolder) {
                info.eventType = FOLDER_DELETED;
                // info.isFolder = true;
                return info;
                // _ = eventService.onFolderDeletedEvent(folderId);
            }
        } else if (isExisitingFolder && !isTrashed) {
            if (isSepcificFolder && parent == specFolderId.toString()) {
                info.eventType = FOLDER_UPDATED_ON_SPECIFIED_FOLDER;
                return info;
            } else if (!isSepcificFolder) {
                info.eventType = FOLDER_UPDATED;
                return info;
            }
        }
    } else {
        fail error("error in trash value");
    }
}

# Maps and identify file change events.
# + fileId - fileId that subjected to a change. 
# + driveClient - Http client for client connection.
# + return if unsucessful, returns error. Else EventInfo object
function identifyFileEvent(string fileId, drive:Client driveClient, json[] statusStore, 
                           boolean isSepcificFolder = false, string? specFolderId = ()) 
                           returns @tainted EventInfo|error? {
    EventInfo info = {};
    drive:File file = check driveClient->getFile(fileId, "createdTime,modifiedTime,trashed,parents");
    boolean isExisitingFile = check checkAvailability(fileId, statusStore);
    boolean? isTrashed = file?.trashed;
    string[]? parentList = file?.parents;
    string parent = EMPTY_STRING;
    if (parentList is string[] && parentList.length() > 0) {
        parent = parentList[0].toString();
    }
    if (isTrashed is boolean) {
        info.fileOrFolderId = fileId;
        if (!isExisitingFile && !isTrashed) {
            if (isSepcificFolder && parent == specFolderId.toString()) {
                info.eventType = NEW_FILE_CREATED_ON_SPECIFIED_FOLDER;
                return info;
                // _ = eventService.onNewFileCreatedInSpecificFolderEvent(fileId);
            } else if (!isSepcificFolder) {
                info.eventType = NEW_FILE_CREATED;
                return info;
                // _ = eventService.onNewFileCreatedEvent(fileId);
            }
        } else if (isExisitingFile && isTrashed) {
            if (isSepcificFolder && parent == specFolderId.toString()) {
                info.eventType = FILE_DELETED_ON_SPECIFIED_FOLDER;
                // info.onSpecifiedFolder = true;
                return info;
                // _ = eventService.onFileDeletedInSpecificFolderEvent(fileId);
            } else if (!isSepcificFolder) {
                info.eventType = FILE_DELETED;
                return info;
                // _ = eventService.onFileDeletedEvent(fileId);
            }
        } else if (isExisitingFile && !isTrashed) {
            if (isSepcificFolder && parent == specFolderId.toString()) {
                info.eventType = FILE_UPDATED_ON_SPECIFIED_FOLDER;
                return info;
                // _ = eventService.onFileDeletedInSpecificFolderEvent(fileId);
            } else if (!isSepcificFolder) {
                info.eventType = FILE_UPDATED;
                return info;
                // _ = eventService.onFileDeletedEvent(fileId);
            }
        }
    } else {
        fail error("error in trash value");
    }
}

# Get current status of a drive. 
# 
# + driveClient - Http client for Drive connection. 
# + optionalSearch - 'ListFilesOptional' object that is used during listing objects in drive.
# + curretStatus - JSON that carries the current status.
function getAllMetaData(drive:Client driveClient, drive:ListFilesOptional optionalSearch, json[] curretStatus) {
    stream<drive:File>|error res = driveClient->getFiles(optionalSearch);
    if (res is stream<drive:File>) {
        error? e = res.forEach(function(drive:File file) {
                                   json output = checkpanic file.cloneWithType(json);
                                    curretStatus.push(output);
                               });
    }
}

# Get current status of a drive. 
# 
# + driveClient - Http client for Drive connection. 
# + curretStatus - JSON that carries the current status / Empty JSON (optional).
# + resourceId - An opaque ID that identifies the resource being watched on this channel.
#                Stable across different API versions (optional).
# + return - If unsuccessful, return error.
function getCurrentStatusOfDrive(drive:Client driveClient, json[] curretStatus, string? resourceId = ()) 
                                 returns @tainted error? {
    curretStatus.removeAll();
    if (resourceId is ()) {
        drive:ListFilesOptional optionalSearch = {pageSize: 1000, q : "trashed = false"};
        getAllMetaData(driveClient, optionalSearch, curretStatus);
    } else {
        drive:File response = check driveClient->getFile(resourceId);
        json output = check response.cloneWithType(json);
        string query = "'" + resourceId + "' in parents";
        if (response?.mimeType.toString() == FOLDER) {
            drive:ListFilesOptional optionalSearch = {
                pageSize: 1000,
                q: query
            };
            getAllMetaData(driveClient, optionalSearch, curretStatus);
        } else {
            curretStatus.push(output);
        }
    }
    log:print(curretStatus.length().toString());
}

# Get current status of a resource. 
# 
# + driveClient - Http client for Drive connection.  
# + curretStatus - JSON that carries the current status of the file.
# + resourceId - An opaque ID that identifies the resource being watched on this channel.
#                Stable across different API versions.
# + return - If unsuccessful, return error.
function getCurrentStatusOfFile(drive:Client driveClient, json[] curretStatus, string resourceId) 
                                returns @tainted error? {
    curretStatus.removeAll();
    drive:File response = check driveClient->getFile(resourceId, "createdTime,modifiedTime,trashed");
    json output = check response.cloneWithType(json);
    curretStatus.push(output);
}

# Validate the existence of a particular resource in a JSON provided.
# 
# + itemID - Id that uniquely represents a resource. 
# + statusStore - JSON object to check the existence of the provided item.
# + return - If it is available, returns boolean(true). Else error.
isolated function checkAvailability(string itemID, json[] statusStore) returns boolean|error {
    boolean flag = false;
    foreach json item in statusStore {
        json|error id = item.id;
        if (id is json) {
            if (id.toString() == itemID) {
                flag = true;
                break;
            }
        } else {
            fail error("error in searching on local status");
        }
    }
    return flag;
}

# Validate for the existence of resources
# 
# + folderId - Id that uniquely represents a folder. 
# + driveClient - Drive connecter client.
# + return - If unsuccessful, return error.
function validateSpecificFolderExsistence(string folderId, drive:Client driveClient) returns @tainted error? {
    drive:File folder = check driveClient->getFile(folderId, 
    "createdTime,modifiedTime,trashed,viewedByMeTime,viewedByMe");
    if (folder?.trashed == true) {
        fail error("Specific folder/file with Id :" + folderId + "had been removed to trashed");
    }
}

# Checks for a modified resource.
# 
# + resourceId - An opaque ID that identifies the resource being watched on this channel.
#                Stable across different API versions. 
# + changeList - Record which maps the response from list changes request.
# + driveClient - Drive connecter client.
# + return - If unsuccessful, return error. Else EventInfo object
function mapEventForSpecificResource(string resourceId, drive:ChangesListResponse changeList, drive:Client driveClient, 
                                    json[] statusStore) returns @tainted EventInfo[]|error {
    drive:Change[]? changes = changeList?.changes;
    EventInfo[] events = [];
    if (changes is drive:Change[] && changes.length() > 0) {
        foreach drive:Change changeLog in changes {
            string fileOrFolderId = changeLog?.fileId.toString();
            drive:File fileOrFolder = check driveClient->getFile(fileOrFolderId);
            string? mimeType = fileOrFolder?.mimeType;
            if (mimeType is string && mimeType == FOLDER) {
                EventInfo? event = check identifyFolderEvent(fileOrFolderId, driveClient, statusStore, true, resourceId);
                if (event is EventInfo){
                    events.push(event);
                }
            } else {
                EventInfo? event = check identifyFileEvent(fileOrFolderId, driveClient, statusStore, true, resourceId);
                if (event is EventInfo){
                    events.push(event);
                }
            }
        }
    }
    return events;
}

# Checks for a modified resource.
# 
# + resourceId - An opaque ID that identifies the resource being watched on this channel.
#                Stable across different API versions. 
# + changeList - Record which maps the response from list changes request.
# + driveClient - Drive connecter client
# + return - If unsuccessfull returns error, Else EventInfo object
function mapFileUpdateEvents(string resourceId, drive:ChangesListResponse changeList, drive:Client driveClient, 
                             json[] statusStore) returns @tainted EventInfo[]|error {
    EventInfo[] events = [];
    drive:Change[]? changes = changeList?.changes;
    if (changes is drive:Change[] && changes.length() > 0) {
        foreach drive:Change changeLog in changes {
            string fileOrFolderId = changeLog?.fileId.toString();
            if (fileOrFolderId == resourceId) {
                drive:File file = check driveClient->getFile(fileOrFolderId, "createdTime,modifiedTime,trashed");
                json|error currentModifedTimeInStore = statusStore[0].modifiedTime;
                if (currentModifedTimeInStore is json) {
                    boolean? istrashed = file?.trashed;
                    boolean isModified = check checkforModificationAftertheLastOne(file?.modifiedTime.toString(), 
                    currentModifedTimeInStore.toString());
                    if (istrashed == true) {
                        EventInfo event = {eventType:FOLDER_DELETED, fileOrFolderId:fileOrFolderId};
                        events.push(event);
                        // _ = eventService.onFileDeletedEvent(fileOrFolderId); //return record event type (type:enum, fileid)
                    } else if (isModified) {
                        // _ = eventService.onFileUpdateEvent(fileOrFolderId);
                        EventInfo event = {eventType:FILE_UPDATED, fileOrFolderId:fileOrFolderId};
                        events.push(event);
                    }
                } else {
                    fail error("Error In json modified time of current status");
                }
            }
        }
    }
    return events;
}

# Checks for a modified resource.
# 
# + eventTime - Drive client connecter. 
# + lastRecordedTime - The Folder Id for the parent folder.
# + return - If it is modified, returns boolean(true). Else error.
isolated function checkforModificationAftertheLastOne(string eventTime, string lastRecordedTime) returns boolean|error {
    string timeFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    boolean isModified = false;
    string eventTimeFormated = regex:replaceAll(eventTime, "Z", "+0000");
    string lastRecordedFormated = regex:replaceAll(lastRecordedTime, "Z", "+0000");
    time:Time eventTimeUNIX = check time:parse(eventTimeFormated, timeFormat);
    time:Time lastRecordedTimeUNIX = check time:parse(lastRecordedFormated, timeFormat);
    time:Duration due = check time:getDifference(eventTimeUNIX, lastRecordedTimeUNIX);
    foreach int item in due {
        if (item < 0) {
            isModified = true;
            break;
        }
    }
    return isModified;
}

# Checking the MimeType to find folder. 
# 
# + driveClient - Drive client connecter. 
# + specificParentFolderId - The Folder Id for the parent folder.
# + return - If successful, returns boolean. Else error.
function checkMimeType(drive:Client driveClient, string specificParentFolderId) returns @tainted boolean|error {
    drive:File item = check driveClient->getFile(specificParentFolderId, "mimeType,trashed");
    if (item?.mimeType.toString() == FOLDER) {
        return true;
    } else {
        if (item?.trashed == true) {
            fail error("Already trashed file :" + specificParentFolderId);
        } else {
            return false;
        }

    }
}

# Stop all subscriptions for listening.
# + driveClient - Google drive client
# + channelUuid - UUID or other unique string you provided to identify this notification channel
# + watchResourceId - An opaque value that identifies the watched resource
# 
# + return - Returns error, if unsuccessful.
function stopWatchChannel(drive:Client driveClient, string channelUuid, string watchResourceId) returns @tainted error? {
    boolean|error response = driveClient->watchStop(channelUuid, watchResourceId);
    if (response is boolean) {
        log:print("Watch channel stopped");
        return;
    } else {
        log:print("Watch channel was not stopped");
        return response;
    }
}
