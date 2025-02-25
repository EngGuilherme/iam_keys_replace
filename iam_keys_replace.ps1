# Define the CSV output file
$outputFile = "iam_keys_report.csv"

# Check if the CSV file exists, if not, create it with headers
if (!(Test-Path $outputFile)) {
    "AccountId,UserName,AccessKeyId,CreateDate(DaysAgo),LastUsed(DaysAgo),Status,KeyState,KeysUpdated" | Out-File -FilePath $outputFile -Encoding utf8
}

# Get the AWS Account ID
$accountId = (aws sts get-caller-identity --query "Account" --output text)

# Get the date 90 days ago
$oldDate = (Get-Date).AddDays(-90)
$currentDate = Get-Date

# Get the list of IAM users
$users = (aws iam list-users --query "Users[*].UserName" --output json | ConvertFrom-Json)

# Loop through each user and fetch access keys
foreach ($user in $users) {
    Write-Host "Checking user: $user"
    
    # Get access keys for the user
    $keys = (aws iam list-access-keys --user-name $user --query "AccessKeyMetadata[*].[AccessKeyId,CreateDate,Status]" --output json | ConvertFrom-Json)

    foreach ($key in $keys) {
        $accessKeyId = $key[0]
        $createDate = Get-Date $key[1]
        $keyState = $key[2]  # Active or Inactive

        # Calculate the number of days since creation
        $daysSinceCreation = ($currentDate - $createDate).Days

        # Check if the key is older than 90 days
        if ($createDate -lt $oldDate) {
            $status = "Key older than 90 days"
            $keysUpdated = "Yes"

            # Rotate key: create a new one and deactivate the old one
            Write-Host "Rotating access key for $user..."
            $newKey = aws iam create-access-key --user-name $user | ConvertFrom-Json
            $newAccessKeyId = $newKey.AccessKey.AccessKeyId

            # Deactivate the old key
            aws iam update-access-key --access-key-id $accessKeyId --status Inactive --user-name $user
            Write-Host "Old key $accessKeyId deactivated."
        } else {
            $status = "Recent key"
            $keysUpdated = "No"
        }

        # Get last used date
        $lastUsedDateRaw = (aws iam get-access-key-last-used --access-key-id $accessKeyId --query "AccessKeyLastUsed.LastUsedDate" --output json | ConvertFrom-Json)

        if ($lastUsedDateRaw -and $lastUsedDateRaw -ne "None") {
            $lastUsedDate = Get-Date $lastUsedDateRaw
            $daysSinceLastUsed = ($currentDate - $lastUsedDate).Days
        } else {
            $lastUsedDate = "Never used"
            $daysSinceLastUsed = "N/A"
        }

        # Append results to CSV
        "$accountId,$user,$accessKeyId,$daysSinceCreation,$daysSinceLastUsed,$status,$keyState,$keysUpdated" | Out-File -FilePath $outputFile -Append -Encoding utf8
    }
}

Write-Host "Report updated: $outputFile"
