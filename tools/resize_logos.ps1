# Resize all AFL logos to 512x512 canvas with transparent background
# Requires ImageMagick installed on Windows

$inputDir = "assets/logos"
$outputDir = "assets/logos_resized"

Write-Host "Scanning $inputDir for logo files..."

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Get-ChildItem $inputDir -Include *.png, *.PNG -File | ForEach-Object {
    $file = $_.FullName
    $filename = $_.Name

    Write-Host "Found file: $filename"

    magick "$file" -resize 512x512 `
        -gravity center `
        -background none `
        -extent 512x512 `
        "$outputDir/$filename"
}

Write-Host "Done! Resized logos saved to $outputDir"