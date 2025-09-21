import firebase_admin
from firebase_admin import credentials, auth, firestore, storage
import os

# Load service account key from environment variable or file path
SERVICE_ACCOUNT_PATH = os.getenv('FIREBASE_SERVICE_ACCOUNT', 'serviceAccountKey.json')

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred, {
    'storageBucket': 'chicha-380b1.appspot.com'
})

firebase_auth = auth
firebase_db = firestore.client()
firebase_storage = storage.bucket()
