# Walmart API Integration Setup Guide

This guide will walk you through setting up Walmart API integration with your EcoPantry app.

## Prerequisites

1. ✅ RSA key pair generated (public and private keys)
2. ⬜ Walmart Developer account
3. ⬜ Firebase project configured

## Step 1: Walmart Developer Portal Setup

### 1.1 Create Walmart Developer Account
1. Go to https://developer.walmart.com
2. Click **"Sign Up"** or **"Get Started"**
3. Complete the registration process
4. Verify your email address

### 1.2 Create an Application
1. Log in to the Walmart Developer Portal
2. Navigate to **"My Apps"** or **"Applications"**
3. Click **"Create New Application"**
4. Fill in the application details:
   - **Application Name**: EcoPantry (or your app name)
   - **Application Type**: Choose appropriate type
   - **Description**: Brief description of your app
   - **Environment**: Select **"Sandbox"** for testing

### 1.3 Upload Your Public Key
1. In your application settings, find the **"API Keys"** or **"Credentials"** section
2. Click **"Add Public Key"** or **"Upload Key"**
3. Upload the file: `walmart_public_key.pem` (generated earlier)
4. Or copy and paste the contents of the public key file

### 1.4 Get Your Consumer ID
1. After uploading the public key, you'll receive a **Consumer ID**
2. **IMPORTANT**: Copy this Consumer ID - you'll need it for Firebase setup
3. It should look something like: `7a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d`

## Step 2: Private Key Setup

### 2.1 Prepare Your Private Key
The private key needs to be formatted correctly for the app:

1. Open `walmart_private_key.pem` in a text editor
2. The key should look like this:
   ```
   -----BEGIN PRIVATE KEY-----
   MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCqi7CW85Pq+Ug4
   ZhpqMBkOFzsZtZ/Q+nQpQ68sN8ZADQ3AqayEDverAl+XqgZb0Wz6wwhL7GTaVPtW
   ... (multiple lines)
   -----END PRIVATE KEY-----
   ```

3. You need to convert this to a single-line format for Firebase:
   - Remove the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines
   - Remove all newlines (make it one continuous string)
   - Or keep it as-is with `\n` characters (Firebase accepts both)

**Recommended format for Firebase**: Keep the full PEM format including headers.

## Step 3: Firebase Configuration

### 3.1 Access Firebase Console
1. Go to https://console.firebase.google.com
2. Select your **EcoPantry** project
3. Navigate to **Firestore Database**

### 3.2 Create Walmart Configuration Document

1. In Firestore, navigate to the **`config`** collection
   - If it doesn't exist, create it

2. Create a new document with ID: **`walmart`**

3. Add the following fields:

   | Field Name     | Type   | Value                                           |
   |----------------|--------|-------------------------------------------------|
   | `consumer_id`  | string | Your Consumer ID from Walmart Developer Portal |
   | `private_key`  | string | Contents of `walmart_private_key.pem`          |
   | `environment`  | string | `sandbox` (or `production` when ready)         |

### 3.3 Document Structure Example

```javascript
{
  consumer_id: "7a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d",
  private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgk...\n-----END PRIVATE KEY-----",
  environment: "sandbox"
}
```

### 3.4 Security Rules

Update your `firestore.rules` to protect the Walmart credentials:

```javascript
match /config/{document} {
  // Only allow authenticated users to read config
  allow read: if request.auth != null;
  // Only allow writes from Firebase Admin SDK (backend)
  allow write: if false;
}
```

**IMPORTANT**: Never allow public access to the `/config` collection as it contains API credentials!

## Step 4: Test the Integration

### 4.1 In the EcoPantry App

1. Open the EcoPantry app
2. Navigate to **Settings** → **Grocery Stores** (or wherever the integration screen is)
3. Find the **Walmart** card
4. The status should show **"Connected"** with a green checkmark
5. Click **"Test Connection"** button
6. The app will search for "milk" products
7. If successful, you'll see a list of sample products

### 4.2 Troubleshooting Connection Issues

If the test fails, check:

- ✅ Consumer ID is correct in Firebase
- ✅ Private key matches the public key uploaded to Walmart
- ✅ Private key is in correct format (with BEGIN/END markers)
- ✅ Environment is set to "sandbox" in Firebase
- ✅ Your Walmart Developer account is active
- ✅ The public key was successfully uploaded to Walmart

## Step 5: Environment Management

### Sandbox vs Production

**Sandbox** (for development):
- Limited product catalog
- Test data only
- No real transactions
- Free to use
- Perfect for development and testing

**Production** (for live use):
- Full Walmart product catalog
- Real inventory data
- May have rate limits
- Requires approval from Walmart
- **Generate new keys** when moving to production

### Switching Environments

To switch from sandbox to production:

1. Generate a **new RSA key pair** (recommended for security)
2. Upload the new public key to Walmart Production environment
3. Get the new Consumer ID
4. Update Firebase `config/walmart` document:
   - Update `consumer_id` with new production Consumer ID
   - Update `private_key` with new private key
   - Change `environment` to `"production"`

## Security Best Practices

1. ✅ **Never commit private keys** to version control
2. ✅ **Store credentials only in Firebase** (server-side)
3. ✅ **Use environment variables** for local development
4. ✅ **Rotate keys periodically** (every 6-12 months)
5. ✅ **Monitor API usage** in Walmart Developer Portal
6. ✅ **Set up Firebase Security Rules** to protect config data
7. ✅ **Use separate keys** for sandbox and production

## API Usage Notes

### Current Implementation

The Walmart service currently supports:
- ✅ Product search by keyword
- ✅ Get product by item ID
- ✅ Authentication with RSA key pair
- ✅ Automatic signature generation

### Future Enhancements

Potential features to add:
- 📦 Order history sync
- 📦 Shopping cart integration
- 📦 Price tracking
- 📦 Inventory availability checks
- 📦 Store location finder

## Support & Documentation

- **Walmart API Docs**: https://developer.walmart.com/doc
- **Firebase Docs**: https://firebase.google.com/docs
- **EcoPantry Issues**: [Your GitHub repo issues]

## Files Generated

After setup, you should have these files in your project root:
- ✅ `walmart_public_key.pem` - Upload to Walmart, then can delete
- ⚠️ `walmart_private_key.pem` - **KEEP SECRET**, add to `.gitignore`

## .gitignore Entry

Add this to your `.gitignore`:

```
# Walmart API Keys
walmart_*.pem
```

---

## Quick Reference

### Firebase Document Path
```
config/walmart
```

### Required Fields
- `consumer_id` (string)
- `private_key` (string)
- `environment` (string: "sandbox" or "production")

### Test Command in App
Navigate to: **Grocery Stores** → **Walmart** → **Test Connection**

---

**Need Help?** Check the Walmart Developer Portal documentation or contact Walmart API support.

