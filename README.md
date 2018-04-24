Box PowerShell Example
======================
This project provides an example PowerShell script to the following actions:
* Get a specifc user from Box.
* Query a Azure SQL database.
* Automatically create a Box folder structure from values in the SQL result set.
* Get a file from the local file system based on values in the SQL result set.
* Upload a file from the local file system to Box.
* Get the SHA1 file hash before and after the upload to Box and ensure they're the same.
* Add metadata to the file uploaded to Box with values in the SQL result set.
* Move the successfully processed file to a "processed" folder.


Installation Instructions
-------------------------
1. Install the [BoxCLI](https://developer.box.com/v2.0/docs/box-cli).
2. Create a new [metadata template](https://community.box.com/t5/How-to-Guides-for-Admins/Customizing-Metadata-Templates/ta-p/1671).
3. Clone or download the [GitHub repository](https://github.com/kylefernandadams/box-powershell-example):
```
git clone https://github.com/kylefernandadams/box-powershell-example
```
4. Modify following variables in the [box-powershell-example.ps1](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1) file.
    * [$BaseFilePath](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L2)
    * [$ProcessedFilePath](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L3)
    * [$BoxBaseFolderId](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L6)
    * [$BoxUserEmail](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L7)
    * [$BoxMetadataTemplateKey](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L9)
        * You can find the template key using the ```box metadata-template list ``` command.
    * [$DatabaseName](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L12)
    * [$DatabaseServiceInstance](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L13)
    * [$DatabaseUsername](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L14)
    * [$DatabasePassword](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L15)

    > CAUTION: Do not store your DB credentials in plaintext for production purposes. Please follow your organization's security guidelines and best practices. 
    > 
    > It is possible to get a `PSCredential` object and store it in an encrypted file using an example like the following.
    >
    > Store Credentials: ```Get-Credential | Export-Clixml -Path C:\my\path\${env:USERNAME}_cred.xml ```
    >
    > Retrieve Credentials: ```$Credentials = Import-Clixml -Path C:\my\path\${env:USERNAME}_cred.xml ``` 
    >
    > Get Username: ```$User = $Credentials.Username ```
    >
    > Get Password: ```$Password = $Credentials.GetNetworkCredential().Password ```
    >
    > CAUTION...AGAIN: $Password is not encrypted at this point in time so you may want to leave it in the credential object so it stays encrypted in memory. 

    * [$GetFilesQuery](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L16)
    * Modify the metadata retrieved from the [SQL result set](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L86). 
    * [Modify the metadata](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L91) from sent to the [Add-File-Metadata function](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L212). 
    * Modify the [metadta key values](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L231) in the [Add-File-Metadata function](https://github.com/kylefernandadams/box-powershell-example/blob/master/box-powershell-exampe.ps1#L212). 
        * You can find the metadata property keys using the ```box metadata-template list ``` command.

5. Run the PowerShell script
```
.\box-powershell-example.ps1
```
6. Example output
```
PS C:\powershell-demo> .\box-powershell-example.ps1
Found Box user: 385982796
Found sub folder with id: 48881865849 and name: 2402
Found folder with id: 48883422413 and name: 2018-04-23
Found file: sample-video-4.mp4
Successfully uploaded file with id 289481833770 and name sample-video-4.mp4 and sha1: b768f76080c2a04434a0931582548913ee35a016
Found file hash before: B768F76080C2A04434A0931582548913EE35A016 and after: b768f76080c2a04434a0931582548913ee35a016
File hashes match! Continue adding metadata...
Added box metadata: {   "siteId": "2402",   "videoTitle": "sample-video-4.mp4",   "videoLength": "0:47",   "videoLatitude": "31.766885",   "videoLongitude": "-106.451048",   "deviceSerialNumber": "5vghdw9usdmmn3h",   "deviceName": "Pam Beesley Axon Body 2",   "deviceFirmwareVersion": "5.1",   "deviceModelNumber": "AxonBody2",   "deviceWarrantyDate": "2020-04-30T09:00:00-04:00",   "$type": "boxCliSample-8b4b8e13-5f9b-4ae6-82e7-25d1ec7ef446",   "$parent": "file_289481833770",   "$id": "7e41f8ef-2cb2-4819-aba7-5de1f5e8e8db",   "$version": 0,   "$typeVersion": 0,   "$template": "boxCliSample",   "$scope": "enterprise_5105484" }
```



Disclaimer
----------
This script provided in this project is an open source example and should not be treated as an officially supported product. Use at your own risk. If you encounter any problems, please log an [issue](https://github.com/kylefernandadams/box-powershell-example/issues).


License
-------
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.