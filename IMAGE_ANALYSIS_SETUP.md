# Image Analysis with OCR and Gemini Setup Guide

## Overview
The app now supports image upload, OCR text extraction, and AI-powered fake news detection using Google's Gemini API.

## Features Added

### 1. Image Upload
- Camera capture
- Gallery selection
- Automatic OCR text extraction
- Image preview with extracted text display

### 2. OCR Integration
- Uses Google ML Kit Text Recognition
- Extracts text from uploaded images
- Shows confidence scores and bounding boxes
- Displays extracted text in the UI

### 3. Gemini AI Analysis
- Analyzes text for misinformation
- Analyzes images for fake news
- Provides credibility scores
- Shows evidence, red flags, and recommendations
- Color-coded results based on credibility

## Setup Instructions

### 1. Get Gemini API Key
1. Go to [Google AI Studio](https://aistudio.google.com/)
2. Create a new project or select existing one
3. Generate an API key
4. Copy the API key

### 2. Configure Environment Variables
Create a `.env` file in the project root with:

```env
# Google Cloud APIs
GEMINI_API_KEY=your-gemini-api-key-here

# Enable image analysis
ENABLE_IMAGE_ANALYSIS=true
```

### 3. Update pubspec.yaml
The following dependencies have been added:
```yaml
# OCR & AI
google_mlkit_text_recognition: ^0.10.0
google_generative_ai: ^0.4.6
```

### 4. Run the App
```bash
flutter pub get
flutter run
```

## How to Use

### Image Analysis Workflow
1. **Upload Image**: Tap "Upload Media" button
2. **Select Source**: Choose camera or gallery
3. **OCR Processing**: App automatically extracts text
4. **View Extracted Text**: See the extracted text in the preview
5. **Analyze**: Tap "Check Credibility" to analyze with Gemini
6. **View Results**: See detailed analysis with:
   - Credibility score and level
   - Evidence analysis
   - Red flags (if any)
   - Recommendations
   - Source evidence
   - Further reading

### Analysis Results
- **Green**: High credibility (80%+)
- **Orange**: Medium credibility (60-79%)
- **Brown**: Low credibility (40-59%)
- **Red**: Potential misinformation detected

## Technical Details

### OCR Service (`lib/services/ocr_service.dart`)
- Extracts text from images using Google ML Kit
- Provides confidence scores
- Handles both XFile and Uint8List inputs

### Gemini Service (`lib/services/gemini_service.dart`)
- Analyzes text and images for misinformation
- Uses structured prompts for consistent results
- Handles both text and image analysis
- Provides detailed evidence and recommendations

### Updated Analysis Screen
- Enhanced UI for image upload and preview
- Shows extracted text from OCR
- Displays comprehensive analysis results
- Color-coded credibility indicators

## Troubleshooting

### Common Issues
1. **OCR not working**: Ensure camera permissions are granted
2. **Gemini API errors**: Check API key configuration
3. **No text extracted**: Try with clearer, higher resolution images
4. **Analysis fails**: Check internet connection and API key validity

### Permissions Required
- Camera access (for taking photos)
- Photo library access (for selecting images)
- Internet access (for Gemini API calls)

## API Limits
- Gemini API has usage limits based on your plan
- OCR processing is done locally on device
- Consider implementing caching for repeated analyses

## Security Notes
- API keys should be kept secure
- Consider using environment variables in production
- Image data is processed locally for OCR
- Only extracted text and image bytes are sent to Gemini API
