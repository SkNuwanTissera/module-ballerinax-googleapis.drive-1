// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

class FileStream {
    private final http:Client httpClient;
    private string? pageToken;
    private ListFilesOptional optional = {};
    private File[] currentEntries = [];
    int index = 0;   

    isolated function init(http:Client httpClient, ListFilesOptional optional) {
        self.httpClient = httpClient;
        self.pageToken = EMPTY_STRING;
        self.currentEntries = checkpanic self.fetchFiles();
        self.optional = optional;
    }

    public isolated function next() returns @tainted record {|File value;|}|error? {
        if (self.index < self.currentEntries.length()) {
            record {|File value;|} file = {value: self.currentEntries[self.index]};
            self.index += 1;
            return file;
        }

        if (self.pageToken is string) {
            self.index = 0;
            self.currentEntries = check self.fetchFiles();
            record {|File value;|} file = {value: self.currentEntries[self.index]};
            self.index += 1;
            return file;
        }
    }

    isolated function fetchFiles() returns @tainted File[]|error {
        string drivePath = prepareUrlwithFileListOptional(self.optional);
        json resp = check sendRequest(self.httpClient, drivePath);
        FilesResponse|error filesResponse = resp.cloneWithType(FilesResponse);
        if (filesResponse is FilesResponse) {
            self.pageToken = filesResponse?.nextPageToken;
            return filesResponse.files;
        } else {
            return error(ERR_FILE_RESPONSE, filesResponse);
        }
    }
}
