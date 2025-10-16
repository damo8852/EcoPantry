# Walmart API - Firebase Quick Setup

## What You Need to Add to Firebase

### Firebase Firestore Document

**Path**: `config/walmart`

**Fields to Add**:

```javascript
{
  "consumer_id": "YOUR_WALMART_CONSUMER_ID_HERE",
  "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_CONTENT_HERE\n-----END PRIVATE KEY-----",
  "environment": "sandbox"
}
```

## Step-by-Step Firebase Setup

### 1. Get Your Credentials Ready

You need two things from Walmart Developer Portal:
1. **Consumer ID** - You'll get this after uploading your public key to Walmart
2. **Private Key** - This is in the file `walmart_private_key.pem`

### 2. Add to Firebase Firestore

1. Go to: https://console.firebase.google.com
2. Select your EcoPantry project
3. Click **Firestore Database** in the left menu
4. Navigate to or create the **`config`** collection
5. Click **Add Document**
6. Set Document ID to: **`walmart`**
7. Add three fields:

   | Field          | Type   | Value                                    |
   |----------------|--------|------------------------------------------|
   | consumer_id    | string | Paste your Consumer ID from Walmart     |
   | private_key    | string | Paste contents of walmart_private_key.pem |
   | environment    | string | sandbox                                  |

8. Click **Save**

### 3. Private Key Format

When copying the private key, include **everything** from the .pem file:

```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCqi7CW85Pq+Ug4
ZhpqMBkOFzsZtZ/Q+nQpQ68sN8ZADQ3AqayEDverAl+XqgZb0Wz6wwhL7GTaVPtW
... (all the lines)
-----END PRIVATE KEY-----
```

> **Tip**: You can paste it as one long line or keep the line breaks - Firebase accepts both formats.

### 4. Security Rules

Make sure your `firestore.rules` protects the config:

```javascript
match /config/{document} {
  allow read: if request.auth != null;
  allow write: if false;
}
```

## Quick Test

After setting up Firebase:

1. Open your EcoPantry app
2. Go to **Grocery Stores** screen
3. Look for the **Walmart** card
4. It should show **"Connected"** with a green checkmark
5. Click **"Test Connection"**
6. You should see a list of milk products

## Troubleshooting

**"Setup Required" shown instead of "Connected"**:
- Check that you created the document at exactly `config/walmart`
- Verify all three fields are present: `consumer_id`, `private_key`, `environment`
- Make sure there are no extra spaces in the field names

**"Connection Failed" error**:
- Verify your Consumer ID is correct
- Check that the private key matches the public key you uploaded to Walmart
- Ensure you selected "Sandbox" environment in Walmart Developer Portal
- Make sure the private key includes the BEGIN and END markers

## What Gets Configured

### In Walmart Developer Portal:
✅ Upload `walmart_public_key.pem`  
✅ Get your Consumer ID  
✅ Select "Sandbox" environment  

### In Firebase:
✅ Create `config/walmart` document  
✅ Add `consumer_id` field  
✅ Add `private_key` field  
✅ Add `environment` field  

### In Your App:
✅ Already configured! Just test the connection.

---

**Done!** Once you complete the Firebase setup, your Walmart integration will be ready to use.

For detailed instructions, see: [WALMART_INTEGRATION_SETUP.md](WALMART_INTEGRATION_SETUP.md)

