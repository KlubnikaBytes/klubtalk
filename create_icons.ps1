$ErrorActionPreference = "Stop"

# Function to create a simple white notification icon PNG
function Create-NotificationIcon {
    param(
        [string]$OutputPath,
        [int]$Size = 96
    )
    
    Add-Type -AssemblyName System.Drawing
    
    # Create a new bitmap
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Set high quality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    # Fill transparent background
    $graphics.Clear([System.Drawing.Color]::Transparent)
    
    # Draw white bell shape
    $white = [System.Drawing.Color]::White
    $brush = New-Object System.Drawing.SolidBrush($white)
    
    # Bell body (simplified circle for now)
    $bellSize = $Size * 0.6
    $margin = ($Size - $bellSize) / 2
    $graphics.FillEllipse($brush, $margin, $margin, $bellSize, $bellSize)
    
    # Save as PNG
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Cleanup
    $graphics.Dispose()
    $bitmap.Dispose()
    $brush.Dispose()
    
    Write-Host "Created icon: $OutputPath"
}

# Create icons for all densities
$basePath = "android\app\src\main\res"

Create-NotificationIcon -OutputPath "$basePath\drawable\notification_icon.png" -Size 96
Create-NotificationIcon -OutputPath "$basePath\drawable-mdpi\notification_icon.png" -Size 48
Create-NotificationIcon -OutputPath "$basePath\drawable-hdpi\notification_icon.png" -Size 72
Create-NotificationIcon -OutputPath "$basePath\drawable-xhdpi\notification_icon.png" -Size 96
Create-NotificationIcon -OutputPath "$basePath\drawable-xxhdpi\notification_icon.png" -Size 144
Create-NotificationIcon -OutputPath "$basePath\drawable-xxxhdpi\notification_icon.png" -Size 192

Write-Host "`n✅ All notification icons created successfully!"
