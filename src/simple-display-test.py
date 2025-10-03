#!/usr/bin/env python3
"""
Simple Display Test for PiTFT 3.5"

This script tests the display by showing colored rectangles and text.
Requires: PIL (Python Imaging Library)

Usage: python3 simple-display-test.py
"""

import os
import sys

# Set framebuffer to use PiTFT
os.environ['FRAMEBUFFER'] = '/dev/fb1'

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Error: PIL not installed")
    print("Install with: sudo apt-get install python3-pil")
    sys.exit(1)

def test_display():
    """Test the PiTFT display with colors and text"""
    
    # Display dimensions for PiTFT 3.5"
    WIDTH = 480
    HEIGHT = 320
    
    print("PiTFT Display Test")
    print("==================")
    print(f"Display size: {WIDTH}x{HEIGHT}")
    print()
    
    # Create blank image
    image = Image.new('RGB', (WIDTH, HEIGHT), color='black')
    draw = ImageDraw.Draw(image)
    
    # Test 1: Colored rectangles
    print("Test 1: Drawing colored rectangles...")
    colors = [
        ('red', (255, 0, 0)),
        ('green', (0, 255, 0)),
        ('blue', (0, 0, 255)),
        ('yellow', (255, 255, 0)),
        ('cyan', (0, 255, 255)),
        ('magenta', (255, 0, 255)),
        ('white', (255, 255, 255))
    ]
    
    rect_width = WIDTH // len(colors)
    for i, (name, color) in enumerate(colors):
        x1 = i * rect_width
        x2 = (i + 1) * rect_width
        draw.rectangle([x1, 0, x2, HEIGHT // 2], fill=color)
        print(f"  - {name}")
    
    # Test 2: Text
    print("Test 2: Drawing text...")
    try:
        # Try to use a larger font
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
    except:
        # Fallback to default font
        font = ImageFont.load_default()
    
    # Draw text on black background
    text = "PiTFT 3.5\" Display Test"
    draw.text((10, HEIGHT // 2 + 20), text, fill='white', font=font)
    
    text2 = "480x320 Resolution"
    draw.text((10, HEIGHT // 2 + 60), text2, fill='cyan', font=font)
    
    # Test 3: Shapes
    print("Test 3: Drawing shapes...")
    # Circle
    draw.ellipse([50, HEIGHT // 2 + 100, 150, HEIGHT - 20], outline='green', width=3)
    # Rectangle
    draw.rectangle([170, HEIGHT // 2 + 100, 270, HEIGHT - 20], outline='yellow', width=3)
    # Line
    draw.line([290, HEIGHT // 2 + 100, 390, HEIGHT - 20], fill='red', width=3)
    
    # Save to framebuffer
    print("Displaying on PiTFT...")
    try:
        image.save('/dev/fb1')
        print("✓ Image displayed successfully!")
        print()
        print("The display should now show:")
        print("  - Colored stripes on top half")
        print("  - Text and shapes on bottom half")
        print()
        print("Press Ctrl+C to exit")
        
        # Keep the image displayed
        input()
        
    except Exception as e:
        print(f"✗ Error displaying image: {e}")
        print()
        print("Troubleshooting:")
        print("  1. Check if /dev/fb1 exists: ls /dev/fb1")
        print("  2. Try with sudo: sudo python3 simple-display-test.py")
        print("  3. Verify display is working: fbset -fb /dev/fb1")
        sys.exit(1)

if __name__ == '__main__':
    try:
        test_display()
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
