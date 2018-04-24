# File system variables
$BaseFilePath = "C:\sample-files"
$ProcessedFilePath = "$($BaseFilePath)\processed"

# Box variables
$BaseBoxFolderId = "BOX_BASE_FOLDER_ID"
$BoxUserEmail = "BOX_USER_EMAIL"
$BoxMetadataScope = "enterprise"
$BoxMetadataTemplateKey = "METADATA_TEMPLATE_KEY"

# SQL Server variables
$DatabaseName = "DATABASE_NAME"
$DatabaseServerInstance = "AZURE_INSTANCE_NAME.database.windows.net"
$DatabaseUsername = "DB_USERNAME"
$DatabasePassword = "DB_PWD"
$GetFilesQuery = "SELECT
    vids.SiteId,
    vids.VideoId,
    vids.Title,
    vids.Length,
    vids.Latitude,
    vids.Longitude,
    devices.SerialNumber,
    devices.Name,
    devices.FirmwareVersion,
    devices.ModelNumber,
    devices.WarrantyDate
    FROM dbo.Videos vids
    INNER JOIN dbo.Devices devices
    ON vids.SiteId = devices.SiteId"

# Query Azure SQL and loop through the results
Function Find-New-Files {
    Try {
        # Instantiate AzureSQL DB params
        $AzureDbParams = @{
            "Database" = $DatabaseName
            "ServerInstance" = $DatabaseServerInstance
            "Username" = $DatabaseUsername
            "Password" = $DatabasePassword
            "OutputSqlErrors" = $true
            "Query" = $GetFilesQuery
        }
        # Invoke the SQL cmdlet
        $QueryResults = Invoke-Sqlcmd @AzureDbParams

        # If the query results are null, then throw an exception
        If($QueryResults -eq $null) {
            throw [System.Exception]
        }
    }
    Catch {
        Write-Error "Failed to execute SQL query."
        break
    }

    # Loop through SQL results
    ForEach($Result in $QueryResults) {
        # Find or create sub folder
        $SubFolder = Get-Or-Create-Folder -ParentFolderId $BaseBoxFolderId -ChildFolderName $Result.Siteid
        Write-Output "Found sub folder with id: $($SubFolder.id) and name: $($SubFolder.name)"

        # Find or create current date folder
        $CurrentDateTime = Get-Date -Format "yyyy-MM-dd"
        $CurrentDateFolder = Get-Or-Create-Folder -ParentFolderId $SubFolder.id -ChildFolderName $CurrentDateTime
        Write-Output "Found folder with id: $($CurrentDateFolder.id) and name: $($CurrentDateFolder.name)" 

        # Build the file path from the base file constant and the file title from the SQL result
        Write-Output "Found file: $($Result.Title)" 
        $FilePath = "$($BaseFilePath)\$($Result.Title)"

        # Call Add-Box-File Function and pass in the file path parameter
        $BoxFile = Add-Box-File -FilePath $FilePath -ParentFolderId $CurrentDateFolder.id
        Write-Output "Successfully uploaded file with id $($BoxFile.id) and name $($BoxFile.name) and sha1: $($BoxFile.sha1)"
        
        # Get the before and after SHA1 hashes to confirm that all bytes were uploaded
        $FileHashBefore = Get-FileHash -Path $FilePath -Algorithm SHA1
        $FileHashAfter = $BoxFile.sha1
        Write-Output "Found file hash before: $($FileHashBefore.Hash) and after: $($FileHashAfter)"

        Try {
            # Check if the before and after file hashes match, else throw an exception
            If($FileHashBefore.Hash -eq $FileHashAfter) {
                Write-Output "File hashes match! Continue adding metadata..."
                
                # Get the Warranty Date and convert it to an RFC3339 date time string
                [datetime] $WarrantyDate = $Result.WarrantyDate
                $WarrantyDateRFC3339 = $WarrantyDate.ToString("yyyy-MM-dd'T'HH:mm:ssZ")

                # Call the Add-Box-File-Metadata and pass in the Box file id parameter
                $BoxMetadata = Add-Box-File-Metadata -BoxFileId $BoxFile.id `
                    -SiteId $Result.SiteId `
                    -VideoTitle $Result.Title `
                    -VideoLength $Result.Length `
                    -VideoLatitude $Result.Latitude `
                    -VideoLongitude $Result.Longitude `
                    -DeviceSerialNumber $Result.SerialNumber `
                    -DeviceName $Result.Name `
                    -DeviceFirmwareVersion $Result.FirmwareVersion `
                    -DeviceModelNumber $Result.ModelNumber `
                    -DeviceWarrantyDate $WarrantyDateRFC3339
                Write-Output "Added box metadata: $($BoxMetadata)"

                # If not null, move the successfully processed file to the processed folder
                If($BoxMetadata -ne $null) {
                    Move-Item -Path $FilePath -Destination $ProcessedFilePath
                    Write-Output "File processed successfully. Moving file from $($FilePath) to $($ProcessedFilePath)\$($Result.Title)"
                }
            }
            Else {
                throw [System.Exception]
            }
        }
        Catch {
            Write-Error "File hashes do not match."
        }
    }
}

# Get Box User Id from an email address
Function Get-Box-User {
    Try {
        # Using the BoxCLI, search for managed users (-m) with an email address
        # Convert from JSON to an array of objects
        # And finally get the id of the first element
        # Else, throw an exception
        $BoxUserResults = box users search -m $BoxUserEmail | ConvertFrom-Json
        If($BoxUserResults.entries.Length -gt 0) {
            return $BoxUserResults.entries[0].id  
        }
        Else {
            throw [System.Exception]
        }
    }
    Catch {
        Write-Error "Failed to get Box user for email $($BoxUserEmail)."
        break
    }
}

Function Get-Or-Create-Folder {
    Param(
        [string] $ParentFolderId,
        [string] $ChildFolderName
    )

    Try {
        # Using the BoxCLI, list the items within a parent folder id
        # Covert from JSON to an array of objects
        $FolderExists = $false
        $BoxFolder = $null
        $BoxFolderItems = box folders list-items $ParentFolderId --as-user $BoxUserId --json | ConvertFrom-Json
        
        # Loop through the folder items
        # If the item.type = 'folder' AND is equal to the child folder name parameter, 
        # Set FolderExists = true and set the BoxFolder variable
        ForEach($Item in $BoxFolderItems.entries) {
            If($Item.type -eq "folder" -AND $Item.name -eq $ChildFolderName) {
                $FolderExists = $true
                $BoxFolder = $Item
            }
        }

        # Check if the folder does not exist
        If($FolderExists -eq $false) {
            # Using the BoxCLI, create a new folder for a given parent folder id and name
            $BoxFolder = box folders create $ParentFolderId $ChildFolderName --as-user $BoxUserId --json | ConvertFrom-Json
        } 

        # If the box folder is null, then throw an exception
        # Else, return the box folder
        If($BoxFolder -eq $null) {
            throw [System.Exception]
        } 
        Else {
            return $BoxFolder
        }
    }
    Catch {
        Write-Error "Failed to get or create folder with parent folder id: $($ParentFolderId) and child item name: $($ChildFolderName)."
        break
    }
}

# Add the file to Box 
Function Add-Box-File {
    Param(
        [string] $FilePath,
        [string] $ParentFolderId
    )

    Try {
        # Using the BoxCLI, upload to box from a file path to a parent folder id
        # And Convert from JSON to an object
        # If the box file is null, then throw an exception
        # Else, return the box file
        $BoxFile = box files upload $FilePath --parent-folder $ParentFolderId --as-user $BoxUserId | ConvertFrom-Json
        If($BoxFile -eq $null) {
            throw [System.Exception]
        } 
        Else {
            return $BoxFile
        }
    }
    Catch {
        Write-Error "Failed to upload file from path: $($FilePath) to Box parent folder id: $($ParentFolderId)."
        break
    }
}

# Add metadata to file in Box
Function Add-Box-File-Metadata {
    Param(
        [string] $BoxFileId,
        [string] $SiteId,
        [string] $VideoTitle,
        [string] $VideoLength,
        [string] $VideoLatitude,
        [string] $VideoLongitude,
        [string] $DeviceSerialNumber,
        [string] $DeviceName,
        [string] $DeviceFirmwareVersion,
        [string] $DeviceModelNumber,
        [string] $DeviceWarrantyDate
    )

    Try {
        # Using the BoxCLI, add file metadata for a given file id,
        # For a given metadata scope and for a given metadata template key
        # NOTE: Issue the "box metadata-template list" command to retrieve a list of metadata template and retrive the key
        $MetadataKV = "siteId=$($SiteId)&" +  
            "videoTitle=$($VideoTitle)&" +  
            "videoLength=$($VideoLength)&" +  
            "videoLatitude=$($VideoLatitude)&" +  
            "videoLongitude=$($VideoLongitude)&" +  
            "deviceSerialNumber=$($DeviceSerialNumber)&" +  
            "deviceName=$($DeviceName)&" +  
            "deviceFirmwareVersion=$($DeviceFirmwareVersion)&" +  
            "deviceModelNumber=$($DeviceModelNumber)&" +  
            "deviceWarrantyDate=$($DeviceWarrantyDate)"
        $BoxMetadata = box files metadata create $BoxFileId $BoxMetadataScope $BoxMetadataTemplateKey `
            --kv $MetadataKV --as-user $BoxUserId --json

        # If box metadata is null, then throw an exception
        # Else, return the box metadata
        If($BoxMetadata -eq $null) {
            throw [System.Exception]
        } 
        Else {
            return $BoxMetadata
        }
    }
    Catch {
        Write-Error "Failed to add metadata to Box file with id: $($BoxFileId)."
        break
    }
}

# Call Get-Box-User Function
$BoxUserId = Get-Box-User
Write-Output "Found Box user: $($BoxUserId)"

# Call Get-New-Files Function
Find-New-Files