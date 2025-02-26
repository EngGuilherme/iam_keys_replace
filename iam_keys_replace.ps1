# Define the CSV output file
$outputFile = "iam_keys_report.csv"

# Check if the CSV file exists, if not, create it with headers
if (!(Test-Path $outputFile)) {
    "AccountId,UserName,OldAccessKeyId,CreateDate(DaysAgo),LastUsed(DaysAgo),Status,KeyState,NewAccessKeyId,NewSecretAccessKey" | Out-File -FilePath $outputFile -Encoding utf8
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

        # Get last used date
        $lastUsedDateRaw = (aws iam get-access-key-last-used --access-key-id $accessKeyId --query "AccessKeyLastUsed.LastUsedDate" --output json | ConvertFrom-Json)

        if ($lastUsedDateRaw -and $lastUsedDateRaw -ne "None") {
            $lastUsedDate = Get-Date $lastUsedDateRaw
            $daysSinceLastUsed = ($currentDate - $lastUsedDate).Days
        } else {
            $lastUsedDate = "Never used"
            $daysSinceLastUsed = "N/A"
        }

        # Check if the key was last used more than 90 days ago
        if (($daysSinceLastUsed -ne "N/A") -and ($daysSinceLastUsed -gt 90)) {
            Write-Host "Disabling unused key for user: $user"
            aws iam update-access-key --user-name $user --access-key-id $accessKeyId --status Inactive
            $keyState = "Inactive"
        }

        $newAccessKeyId = "N/A"
        $newSecretAccessKey = "N/A"

        # If the key is still active and older than 90 days, rotate it
        if ($keyState -eq "Active" -and $daysSinceCreation -gt 90) {
            Write-Host "Rotating old key for active user: $user"

            # Create a new access key
            $newKey = aws iam create-access-key --user-name $user | ConvertFrom-Json
            $newAccessKeyId = $newKey.AccessKey.AccessKeyId
            $newSecretAccessKey = $newKey.AccessKey.SecretAccessKey

            # Deactivate the old key
            aws iam update-access-key --user-name $user --access-key-id $accessKeyId --status Inactive
            $keyState = "Inactive"
        }

        # Append results to CSV
        "$accountId,$user,$accessKeyId,$daysSinceCreation,$daysSinceLastUsed,Checked,$keyState,$newAccessKeyId,$newSecretAccessKey" | Out-File -FilePath $outputFile -Append -Encoding utf8
    }
}

Write-Host "Report updated: $outputFile"
