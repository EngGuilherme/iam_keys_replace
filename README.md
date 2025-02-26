# AWS IAM Access Key Rotation Script

## Overview
This PowerShell script retrieves all IAM users and their access keys, checks their creation and last used dates, and automatically rotates keys older than **90 days** by creating a new key and deactivating the old one. The data is logged into a CSV file for auditing purposes.

## Prerequisites
Before running this script, ensure you have the following:
- **AWS CLI** installed and configured
- **PowerShell** installed
- IAM permissions to list users, list access keys, create access keys, update access keys, and retrieve last-used data

## Installation
1. **Install AWS CLI** (if not already installed):
   - [Download AWS CLI](https://aws.amazon.com/cli/)
   - Verify installation:
     ```powershell
     aws --version
     ```

2. **Configure AWS CLI** with credentials:
   ```powershell
   aws configure
   ```
   Provide the following details when prompted:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region name (e.g., `us-east-1`)
   - Default output format (e.g., `json` or `text`)

3. **Verify IAM permissions**:
   Ensure your AWS user has the following permissions:
   ```json
   {
       "Effect": "Allow",
       "Action": [
           "iam:ListUsers",
           "iam:ListAccessKeys",
           "iam:GetAccessKeyLastUsed",
           "iam:CreateAccessKey",
           "iam:UpdateAccessKey"
       ],
       "Resource": "*"
   }
   ```

## Usage
1. **Save the script** as `iam_keys_replace.ps1`
2. **Run the script** in PowerShell:
   ```powershell
   powershell -ExecutionPolicy Bypass -File iam_keys_replace.ps1
   ```
3. The script will:
   - Retrieve IAM users and their access keys
   - Check key age and last usage
   - Rotate keys older than 90 days
   - Log details in `iam_keys_report.csv`

## Expected Output
### CSV File (`iam_keys_report.csv`)
The script generates a report with the following columns:
```csv
AccountId,UserName,OldAccessKeyId,CreateDate(DaysAgo),LastUsed(DaysAgo),Status,KeyState,NewAccessKeyId,NewSecretAccessKey
123456789012,user1,AKIA12345XYZ,120,30,Key older than 90 days,Inactive,N/A,N/A
123456789012,user2,AKIA67890ABC,45,2,Recent key,Active,N/A,N/A
```

## Notes
- If an access key is **older than 90 days**, a new one is created, and the old key is set to **Inactive**.
- **Inactive keys are NOT deleted** but can be manually removed if needed.
- You can modify the script to delete old keys instead of deactivating them.

## Troubleshooting
- **"AWS CLI not found"**: Ensure AWS CLI is installed and configured.
- **"Access Denied" errors**: Verify IAM user permissions.
- **Script not running**: If PowerShell execution is restricted, run:
  ```powershell
  Set-ExecutionPolicy Unrestricted -Scope Process
  ```

