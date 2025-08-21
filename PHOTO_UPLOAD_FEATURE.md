# Photo Upload Feature for Itinerary Items

## Overview
This feature allows administrators to upload photos for individual itinerary items within package itineraries. Each itinerary item can now have an associated photo to provide visual context for travelers.

## Features

### Photo Upload
- **Supported Formats**: JPG, JPEG, PNG, GIF
- **File Size Limit**: 5MB per photo
- **Upload Methods**: 
  - Click to browse files
  - Drag and drop files
- **Storage**: Photos are stored in `priv/static/uploads/itinerary/`

### User Interface
- **Photo Display**: Shows current photo with 64x64px thumbnail
- **Upload Zone**: Drag & drop area with visual feedback
- **Photo Management**: 
  - Upload new photos
  - Remove existing photos
  - Preview before upload

### Technical Implementation

#### Live View Updates
- Added `allow_upload/3` for itinerary photos
- New event handlers:
  - `upload_itinerary_photo/3` - Handles photo uploads
  - `remove_itinerary_photo/3` - Removes photos
  - `cancel_upload/3` - Cancels uploads

#### Data Structure
- Itinerary items now include a `photo` field
- Photos are stored as file paths in the database
- Backward compatible with existing itineraries

#### File Handling
- Unique filename generation using timestamps and random bytes
- Automatic directory creation
- Error handling for upload failures

## Usage

### For Administrators
1. Navigate to Package Itinerary management
2. For each itinerary item, use the photo upload section
3. Drag & drop or click to select photos
4. Click "Upload Photo" to save
5. Use "Remove Photo" to delete existing photos

### File Management
- Photos are automatically organized in the uploads directory
- Filenames include timestamps for uniqueness
- Old photos are replaced when new ones are uploaded

## Security & Validation
- File type validation (images only)
- File size limits enforced
- Secure filename generation
- Upload directory isolation

## Future Enhancements
- Photo cropping/resizing
- Multiple photo support per item
- Photo gallery view
- Bulk photo upload
- Photo compression optimization

## Dependencies
- Phoenix LiveView uploads
- File system access for storage
- Image format validation
- Tailwind CSS for styling 