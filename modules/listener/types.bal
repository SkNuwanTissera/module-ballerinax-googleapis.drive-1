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

import ballerina/http;

# Watch request properties
#
# + address - The address where notifications are delivered for this channel.  
# + payload - A Boolean value to indicate whether payload is wanted.  
# + kind - Identifies this as a notification channel used to watch for changes to a resource, which is "api#channel".  
# + expiration - Date and time of notification channel expiration, expressed as a Unix timestamp, in milliseconds.  
# + id - A UUID or similar unique string that identifies this channel.  
# + type - The type of delivery mechanism used for this channel. Valid values are "web_hook" (or "webhook"). 
#          Both values refer to a channel where Http requests are used to deliver messages  
# + token - An arbitrary string delivered to the target address with each notification delivered over this channel.  
public type WatchRequestproperties record {
    string kind = "api#channel";
    string id;
    string 'type = "web_hook";
    string address;
    string token?;
    int? expiration?;
    boolean payload?;
};

# Record type that matches Change response.
#
# + resourceId - An opaque ID that identifies the resource being watched on this channel. 
#                Stable across different API versions.  
# + kind - Identifies this as a notification channel used to watch for changes to a resource, which is "api#channel".  
# + expiration - Date and time of notification channel expiration, expressed as a Unix timestamp, in milliseconds.  
# + id - A UUID or similar unique string that identifies this channel.  
# + resourceUri - A version-specific identifier for the watched resource.  
public type changeResponse record {
    string kind;
    string id;
    string resourceId;
    string resourceUri;
    int expiration;
};

# Record type used on Http listner initiation.
#
# + clientEP - The Http Client.  
# + isWatchAlive - Boolean value to handle isWatchAlive.  
# + startToken - The starting page token for listing changes.   
# + uuid - A universally unique identifier.  
public type InitiationDetail record {
    boolean isWatchAlive;
    string startToken;
    string uuid;
    http:Client clientEP;
};

# This type object 'OnEventService' with all Event funtions. 
public type OnEventService object {
    public isolated function onNewFolderCreatedEvent(string folderId);
    public isolated function onFolderDeletedEvent(string fileId);
    public isolated function onNewFileCreatedEvent(string folderId);
    public isolated function onFileDeletedEvent(string fileId);
    public isolated function onNewFileCreatedInSpecificFolderEvent(string fileId);
    public isolated function onNewFolderCreatedInSpecificFolderEvent(string folderId);
    public isolated function onFolderDeletedInSpecificFolderEvent(string folderId);
    public isolated function onFileDeletedInSpecificFolderEvent(string fileId);
    public isolated function onFileUpdateEvent(string fileId);
};

# Record type used to handle the Events
public type EventInfo record {
    EventType eventType?;
    string fileOrFolderId?;
    boolean isFolder = false;
    boolean onSpecifiedFolder = false;
};

# Represents event type
public enum EventType {
    NEW_FOLDER_CREATED_ON_SPECIFIED_FOLDER,
    NEW_FOLDER_CREATED,
    FOLDER_DELETED_ON_SPECIFIED_FOLDER,
    FOLDER_DELETED,
    NEW_FILE_CREATED_ON_SPECIFIED_FOLDER,
    NEW_FILE_CREATED,
    FILE_DELETED_ON_SPECIFIED_FOLDER,
    FILE_DELETED,
    FILE_UPDATED
}
