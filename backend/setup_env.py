#!/usr/bin/env python3
"""
Secure Environment Setup Script
Helps configure API keys and environment variables safely
"""

import os
import sys
from pathlib import Path
import getpass
import shutil
from typing import Optional


def print_header():
    """Print script header"""
    print("=" * 60)
    print("🔐 Secure Environment Configuration")
    print("=" * 60)
    print()


def check_firebase_service_account():
    key_path = os.getenv('FIREBASE_SERVICE_ACCOUNT', 'backend/serviceAccountKey.json')
    if not os.path.exists(key_path):
        print(f"[ERROR] Service account key not found: {key_path}")
        print("Please download your Firebase serviceAccountKey.json from the Firebase Console and place it at the above path.")
        return False
    else:
        print(f"[OK] Service account key found: {key_path}")
        return True


def check_env_file() -> bool:
    """Check if .env file exists"""
    return Path(".env").exists()


def backup_env_file():
    """Create backup of existing .env file"""
    if check_env_file():
        backup_path = Path(".env.backup")
        shutil.copy(".env", backup_path)
        print(f"✅ Backed up existing .env to .env.backup")


def read_env_example() -> dict:
    """Read the .env.example file and extract keys"""
    env_vars = {}
    example_file = Path(".env.example")
    
    if not example_file.exists():
        print("⚠️  .env.example file not found!")
        return env_vars
    
    with open(example_file, "r") as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if line and not line.startswith("#"):
                if "=" in line:
                    key, value = line.split("=", 1)
                    env_vars[key.strip()] = value.strip()
    
    return env_vars


def get_api_key_secure(prompt: str) -> str:
    """Securely get API key from user input"""
    return getpass.getpass(prompt)


def validate_gemini_api_key(api_key: str) -> bool:
    """Basic validation of Gemini API key format"""
    # Gemini API keys typically start with "AIza" and are 39 characters
    if not api_key:
        return False
    
    if len(api_key) != 39:
        print(f"⚠️  API key length is {len(api_key)}, expected 39 characters")
        return False
    
    if not api_key.startswith("AIza"):
        print("⚠️  API key should start with 'AIza'")
        return False
    
    return True


def test_gemini_connection(api_key: str) -> bool:
    """Test if the Gemini API key works"""
    try:
        import google.generativeai as genai
        
        # Configure with the provided API key
        genai.configure(api_key=api_key)
        
        # Try to initialize the model
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        # Test with a simple prompt
        response = model.generate_content("Say 'API key is working!' in exactly 4 words.")
        
        if response.text:
            print("✅ Gemini API key is valid and working!")
            return True
    except Exception as e:
        print(f"❌ API key test failed: {str(e)}")
        return False
    
    return False


def write_env_file(env_vars: dict):
    """Write environment variables to .env file"""
    with open(".env", "w") as f:
        # Add header
        f.write("# Environment Configuration for Misinformation Detection App\n")
        f.write("# Generated securely - DO NOT commit this file to version control\n\n")
        
        # Group related variables
        groups = {
            "Google Cloud Configuration": [
                "GOOGLE_CLOUD_PROJECT", "VERTEX_AI_REGION", 
                "DOCUMENT_AI_LOCATION", "STORAGE_BUCKET"
            ],
            "Environment": ["ENVIRONMENT", "PORT"],
            "API Keys": ["GEMINI_API_KEY"],
            "Firebase Configuration": ["FIREBASE_PROJECT_ID"],
            "Database Configuration": ["BIGQUERY_DATASET", "FIRESTORE_DATABASE"],
            "Security": ["JWT_SECRET_KEY", "CORS_ORIGINS"],
            "Logging": ["LOG_LEVEL", "ENABLE_STRUCTURED_LOGGING"],
            "Feature Flags": [
                "ENABLE_REAL_TIME_PROCESSING", "ENABLE_HARM_CLASSIFICATION",
                "ENABLE_ANALYTICS", "ENABLE_MULTILINGUAL_SUPPORT"
            ],
            "Rate Limiting": ["RATE_LIMIT_PER_MINUTE", "BURST_LIMIT"]
        }
        
        for group_name, keys in groups.items():
            f.write(f"# {group_name}\n")
            for key in keys:
                if key in env_vars:
                    f.write(f"{key}={env_vars[key]}\n")
            f.write("\n")
    
    print("✅ .env file created successfully")


def setup_gitignore():
    """Ensure .env is in .gitignore"""
    gitignore_path = Path("../.gitignore")
    
    if not gitignore_path.exists():
        with open(gitignore_path, "w") as f:
            f.write("# Environment files\n")
            f.write(".env\n")
            f.write(".env.local\n")
            f.write(".env.*.local\n")
        print("✅ Created .gitignore with .env exclusion")
    else:
        with open(gitignore_path, "r") as f:
            content = f.read()
        
        if ".env" not in content:
            with open(gitignore_path, "a") as f:
                f.write("\n# Environment files\n")
                f.write(".env\n")
            print("✅ Added .env to .gitignore")


def main():
    """Main setup function"""

    print_header()
    env_vars = read_env_example()
    
    if not env_vars:
        print("❌ Could not read environment variables from .env.example")
        sys.exit(1)
    
    print("📝 Setting up environment variables...\n")
    
    # 1. Get Gemini API Key
    print("1️⃣ Gemini API Key Configuration")
    print("   Get your API key from: https://makersuite.google.com/app/apikey")
    print()
    
    while True:
        api_key = get_api_key_secure("   Enter your Gemini API Key (hidden): ")
        
        if not api_key:
            use_default = input("   No API key entered. Skip for now? (y/n): ").lower()
            if use_default == 'y':
                env_vars["GEMINI_API_KEY"] = "your-gemini-api-key-here"
                print("   ⚠️  Using placeholder - remember to update later!")
                break
        elif validate_gemini_api_key(api_key):
            print("   🔍 Testing API key...")
            if test_gemini_connection(api_key):
                env_vars["GEMINI_API_KEY"] = api_key
                break
            else:
                retry = input("   API key test failed. Try again? (y/n): ").lower()
                if retry != 'y':
                    env_vars["GEMINI_API_KEY"] = api_key
                    print("   ⚠️  API key saved but not verified")
                    break
        else:
            retry = input("   Invalid API key format. Try again? (y/n): ").lower()
            if retry != 'y':
                env_vars["GEMINI_API_KEY"] = "your-gemini-api-key-here"
                break
    
    print()
    
    # 2. Configure Project ID
    print("2️⃣ Google Cloud Project Configuration")
    project_id = input("   Enter your Google Cloud Project ID (or press Enter for default): ").strip()
    if project_id:
        env_vars["GOOGLE_CLOUD_PROJECT"] = project_id
        env_vars["FIREBASE_PROJECT_ID"] = project_id
        env_vars["STORAGE_BUCKET"] = f"{project_id}.appspot.com"
    
    print()
    
    # 3. Configure Environment
    print("3️⃣ Environment Configuration")
    env_choices = {"1": "development", "2": "staging", "3": "production"}
    print("   1) development (default)")
    print("   2) staging")
    print("   3) production")
    env_choice = input("   Select environment [1]: ").strip() or "1"
    env_vars["ENVIRONMENT"] = env_choices.get(env_choice, "development")
    
    print()
    
    # 4. Configure Security
    print("4️⃣ Security Configuration")
    print("   Generating secure JWT secret...")
    import secrets
    env_vars["JWT_SECRET_KEY"] = secrets.token_urlsafe(32)
    print("   ✅ Generated secure JWT secret")
    
    print()
    
    # Write the .env file
    write_env_file(env_vars)
    check_firebase_service_account()
    
    # Setup .gitignore
    setup_gitignore()
    
    print()
    print("🎉 Environment setup completed!")
    print()
    print("Next steps:")
    print("1. Review the .env file and update any placeholder values")
    print("2. Never commit the .env file to version control")
    print("3. For production, use Google Secret Manager instead")
    print("4. Run 'python test_gemini.py' to test your configuration")
    print()
    print("To update your API key later, run this script again or edit .env directly")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)